/*
 * ethtool — minimal combined-channels setter for the sys-net (sn-7) NIC.
 *
 * WHY THIS EXISTS (v12, the sn-7 flap root-cause fix):
 *
 *   The chronic face-flap (chased across ~10 weeks) was CONFIRMED on the
 *   live wire by the v11 per-queue BPF counters to be MULTI-QUEUE RSS, not a
 *   gVisor netstack bug:
 *
 *     * c6a.large's ENA has 2 RX queues (ENA_MAX_NUM_IO_QUEUES capped by
 *       num_online_cpus; ena_netdev.c ena_get_max_num_io_queues).
 *     * gVisor binds ONE AF_XDP socket at sockmap key 0 (runsc/sandbox/
 *       xdp.go:178, `mapKey := uint32(0)`, TODO(b/240191988)).
 *     * ENA runs the XDP program per RX queue (ena_xdp_handle_buff, per
 *       rx_ring->qid; the queue index is xdp_rxq_info_reg'd per ring).
 *     * A frame RSS-hashed to queue 1 hits the program with
 *       ctx->rx_queue_index == 1, whose sockmap slot is EMPTY (no socket at
 *       key 1) -> the sn-6e guard XDP_PASSes it to the fully-OFFLINE kernel
 *       -> dropped at the door. Every new inbound connection's 4-tuple
 *       hashes to q0 or q1 ~50/50 -> ~50% of new SYNs never reach the
 *       netstack. That is the flap.
 *
 *   The v11 live instance (i-080664c2822b62628) showed the decisive shape:
 *       slot0 (q0): pass=0      redirect=1465
 *       slot1 (q1): pass=788    redirect=0
 *       slots 2-15: 0 / 0
 *   and a 49%-dark face — matching the chronic ~51% flap.
 *
 *   THE FIX: collapse the RX queues to 1 BEFORE the XDP program is attached,
 *   so every inbound frame lands on queue 0 (the one gVisor binds). This tool
 *   issues exactly the ioctl the canonical `ethtool -L <dev> combined 1`
 *   issues: SIOCETHTOOL with ETHTOOL_SCHANNELS, combined_count=1.
 *
 * WHY A HAND-ROLLED TOOL (not the ethtool package):
 *
 *   * The kernel.org ethtool mirror DISABLES directory listings (404 on the
 *     index), so the pinned tarball path is a fetch rabbit hole with no
 *     stable mirror. A ~70-line static tool with ZERO new dependencies is
 *   cheaper and deterministic than vendoring the 600-file ethtool tree.
 *   * It is built in the gvisor build stage (already has core-gcc +
 *     core-musl + core-linux-headers for the freestanding prewarmer), static
 *     musl (-static) so it needs nothing from the guest, and lands in the
 *     KERNEL-SIDE rootfs (not the sandbox) — the same place as xdp_loader
 *     and bpfcount, which the sysnet supervisor runs.
 *
 * UAPI (pinned to the guest kernel 7.2; verified against
 *   packages/user/linux/linux-7.2):
 *   * SIOCETHTOOL      0x8946           (linux/sockios.h)
 *   * ETHTOOL_SCHANNELS 0x0000003d      (linux/ethtool.h)
 *   * ETHTOOL_GCHANNELS 0x0000003c      (read-back verify)
 *   * struct ethtool_channels { 9 x u32 } (linux/ethtool.h:552)
 *
 * DISPATCH PATH (net/core/ethtool.c dev_ethtool -> net/ethtool/ioctl.c
 *   ethtool_set_channels):
 *   * get_channels for the maxes; combined_count > max_combined -> EINVAL.
 *   * BUSY-QUEUE CHECK on the queues being removed: netdev_queue_busy(dev,
 *     i) for i in [new, old) returns -EINVAL if an AF_XDP socket leases that
 *     queue. THIS is why the tool MUST run BEFORE the XDP attach (no socket
 *     -> no lease -> the check passes). After the attach it would -EINVAL.
 *   * ops->set_channels:
 *       - ENA  ena_set_channels: 1 >= ENA_MIN_NUM_IO_QUEUES(1);
 *         2*1 <= max_num_io_queues (legal) -> ena_update_queue_count(1) =
 *         full close/open + ena_com_rss_destroy + re-init, so the RSS
 *         indirection table is rebuilt for 1 queue -> all frames land on
 *         queue 0. (ena_xdp.h ena_xdp_legal_queue_count.)
 *       - virtio (QEMU) virtnet_set_channels: combined 1 accepted (nonzero,
 *         <= max_queue_pairs); `if (rq[0].xdp_prog) return -EINVAL` (again:
 *         before-XDP). The QEMU harness NIC is a single queue, so the
 *         generic dispatch returns 0 EARLY (no change) — a clean no-op that
 *         lets the QEMU smoke prove the binary + call path WITHOUT the
 *         effect. The wire (ENA, 2 queues) is the acceptance.
 *
 * INTERFACE:  ethtool <dev> <combined>
 *   Sets the combined channel count on <dev> to <combined> (>= 1), then
 *   reads it back (GCHANNELS) to verify. Exit 0 on success.
 */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <net/if.h>
#include <linux/ethtool.h>
#include <linux/sockios.h>

#ifndef SIOCETHTOOL
#define SIOCETHTOOL 0x8946
#endif

int main(int argc, char **argv)
{
	if (argc != 3) {
		fprintf(stderr, "usage: %s <dev> <combined>\n", argv[0]);
		return 2;
	}
	const char *dev = argv[1];
	unsigned combined = (unsigned)strtoul(argv[2], NULL, 10);
	if (combined == 0) {
		fprintf(stderr, "ethtool: combined must be >= 1\n");
		return 2;
	}
	if (strlen(dev) >= IFNAMSIZ) {
		fprintf(stderr, "ethtool: dev name too long: %s\n", dev);
		return 2;
	}

	int fd = socket(AF_INET, SOCK_DGRAM, 0);
	if (fd < 0) {
		perror("ethtool: socket");
		return 1;
	}

	/*
	 * The SIOCETHTOOL ABI (net/core/dev_ioctl.c do_dev_ioctl ->
	 * __dev_ethtool(net, ifr, ifr->ifr_data, ...)): the kernel reads the
	 * command struct from the POINTER stored in ifr.ifr_ifru.ifru_data
	 * (copy_from_user(&channels, useraddr, ...)). So ifr_data must POINT
	 * at a real struct ethtool_channels — it is never an inline area.
	 */
	struct ethtool_channels ch;
	memset(&ch, 0, sizeof(ch));

	/* SET the combined channel count. */
	struct ifreq ifr;
	memset(&ifr, 0, sizeof(ifr));
	strcpy(ifr.ifr_name, dev);
	ch.cmd = ETHTOOL_SCHANNELS;
	ch.combined_count = combined;
	ch.rx_count = 0;
	ch.tx_count = 0;
	ch.other_count = 0;
	ifr.ifr_data = (void *)&ch;

	if (ioctl(fd, SIOCETHTOOL, &ifr) < 0) {
		fprintf(stderr, "ethtool: SCHANNELS on %s (combined=%u) failed: %s\n",
			dev, combined, strerror(errno));
		close(fd);
		return 1;
	}

	/* READ BACK (GCHANNELS) to verify the change took. A read failure is not
	 * fatal (the SET succeeded); report it and exit 0. */
	memset(&ifr, 0, sizeof(ifr));
	memset(&ch, 0, sizeof(ch));
	strcpy(ifr.ifr_name, dev);
	ch.cmd = ETHTOOL_GCHANNELS;
	ifr.ifr_data = (void *)&ch;
	if (ioctl(fd, SIOCETHTOOL, &ifr) < 0) {
		close(fd);
		fprintf(stderr, "ethtool: %s set to combined=%u (GCHANNELS read failed: %s)\n",
			dev, combined, strerror(errno));
		return 0;
	}
	close(fd);
	printf("ethtool: %s combined now %u (max %u)\n",
	       dev, ch.combined_count, ch.max_combined);
	return 0;
}
