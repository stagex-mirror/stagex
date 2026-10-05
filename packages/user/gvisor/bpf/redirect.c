// Custom AF_XDP "redirect" program for the sn-7 sys-net sandbox (Qubes
// sys-net face, full NIC ownership, kernel FULLY offline).
//
// v5 = v4 + PER-QUEUE counter attribution (the multi-queue RSS experiment).
//
// v3 is the maximally simple program: NO ethertype gate, NO IP header parse,
// NO port tests. The netstack is the ONLY stack on the wire and it owns ARP
// too — the sentry resolves the GW MAC (ARP requests go out the AF_XDP
// socket, the GW's ARP replies must land in the sandbox, not the kernel) and
// answers ARP for its own lease IP. The kernel has no lease, no address,
// nothing to do.
//
// The whole body is:
//   if sock_map empty for this queue (bpf_map_lookup_elem == NULL) -> XDP_PASS
//   else                                                           -> bpf_redirect_map (ALL frames)
//
// The sn-6e guard is unchanged and now covers ALL traffic: sandbox dead ->
// kernel auto-removes the map entry on socket close (xsk_map_try_sock_delete)
// -> NULL lookup -> XDP_PASS hands the full wire back to the kernel (the
// recovery path) until the supervisor respawns the sandbox and the
// re-inserted socket re-arms the redirect. It also covers the pre-start
// window (program attached, socket not yet inserted), where v1 blackholed.
//
// The program never dereferences frame bytes, so no bounds check is needed;
// every frame (ARP, IPv4, IPv6, ...) is handed to the sandbox as-is.
//
// v5 PER-QUEUE DIAGNOSTIC (the multi-queue RSS experiment):
//   bpf_counts: ARRAY[16] of {unsigned int pass, unsigned int redirect},
//     indexed by ctx->rx_queue_index.
//
// Why this is the decisive instrument (vs v4's single pair): the v10 data
// showed redirect CLIMBING during darks (~85% of the up-rate) while the pass
// share was only 6.7-11% — far below the ~50% a clean 2-queue 50/50 RSS
// split would predict if every queue-1 frame guard-PASSED. The missing
// variable is WHICH queue each frame lands on.
//
// ENA (the AWS c6a NIC) invokes THIS program per RX queue: ena_netdev.c
// ena_xdp_handle_buff (:1178) runs per rx_ring->qid, and each ring registers
// its xdp_rxq_info with its own queue index (ena_xdp.c :200,
// xdp_rxq_info_reg(..., rx_ring->qid, ...)), so ctx->rx_queue_index in the
// program IS the per-queue RX counter measured at the exact decision point —
// no sysfs needed (CONFIG_NET_SYSFS is off in the enclave kernel).
//
// Prediction if the multi-queue RSS hypothesis is correct (gvisor binds one
// AF_XDP socket at key 0, xdp.go:178, on a 2-queue ENA):
//   slot 0: redirect climbing, pass ~0     (queue 0 has the socket)
//   slot 1: pass climbing,   redirect ~0   (queue 1 has no socket -> guard)
// and the per-window pass rate in slot 1 tracks the dark windows.
//
// If instead slot 0 shows BOTH pass and redirect climbing (and slot 1 stays
// ~0), the program is running on a single queue and the pass frames are
// something else (guard firing on a socket that left the map while frames
// keep arriving — the sockmap-lifecycle variant).
//
// Both per-slot counters are monotonic since program load; the supervisor
// logs per-slot deltas. (Atomicity: a 32-bit increment in XDP context is a
// plain read-modify-write; concurrent increments across queues can lose
// counts under contention, but a LOSE of counts cannot create a false
// per-queue attribution — the discriminator is directional, not exact.)
//
// Drop-in ABI vs the stock go-branch .o (unchanged from v1..v3):
//   - same map: legacy bpf_map_def, XSKMAP (byte 0x11 in the guest kernel),
//     key4/val4/max1, section "maps";
//   - same symbols: xdp_prog (section "xdp"), sock_map;
//   - same redirect: bpf_redirect_map(&sock_map, rx_queue_index, XDP_XSKB),
//     inlined to `call 0x33` exactly like the stock object;
//   - same guard: bpf_map_lookup_elem(&sock_map, key)==NULL -> XDP_ACT_PASS,
//     key = ctx->rx_queue_index (the v2 map-key convention).
// so runsc/sandbox/xdp.go's LoadAndAssign (ebpf:"xdp_prog", ebpf:"sock_map")
// needs zero Go changes. All ABI constants (incl. the bpf_map_type pin) are
// vendored + pinned to the guest kernel in bpf_helpers.h — this file uses no
// kernel bpf.h at all.
#include "bpf_helpers.h"
#include "bpf_endian.h"

char __license[] SEC("license") = "GPL";

struct bpf_map_def SEC("maps") sock_map = {
  .type = XDP_XSKMAP_TYPE, /* 17 (0x11) in the guest kernel; the stock byte */
  .key_size = sizeof(unsigned int),
  .value_size = sizeof(unsigned int),
  .max_entries = 1,
  .flags = 0,
};

/* v5: per-queue diagnostic counters. ARRAY (type 2), 16 slots of an 8-byte
 * value each, indexed by ctx->rx_queue_index. 16 covers ENA on any instance
 * size up to 16 queues (ena_netdev: max_num_io_queues = min(online_cpus,
 * hw max)); the guest verifier accepts the fixed bound as the array key
 * limit. A frame on queue N >= 16 is still redirected/passed correctly —
 * it just is not counted (the key bounds-check guards the lookup only). */
struct bpf_counts_val {
  unsigned int pass;
  unsigned int redirect;
};

#define COUNT_SLOTS 16u

struct bpf_map_def SEC("maps") bpf_counts = {
  .type = 2, /* BPF_MAP_TYPE_ARRAY */
  .key_size = sizeof(unsigned int),
  .value_size = sizeof(struct bpf_counts_val),
  .max_entries = COUNT_SLOTS,
  .flags = 0,
};

/* v5: count a frame for its own RX queue (slot = ctx->rx_queue_index), if
 * that slot exists in the counter map. */
static void count(unsigned int q, int is_pass)
{
  if (q < COUNT_SLOTS) {
    unsigned int ckey = q;
    struct bpf_counts_val *cv =
        (struct bpf_counts_val *)bpf_map_lookup_elem(&bpf_counts, &ckey);
    if (cv) {
      if (is_pass)
        cv->pass += 1;
      else
        cv->redirect += 1;
    }
  }
}

static int redirect(struct xdp_md *ctx)
{
  // The sentry inserts its AF_XDP socket at key = ctx->rx_queue_index
  // (single-queue NIC: 0); bpf_redirect_map delivers the packet there.
  // Matches the stock program, which reads xdp_md+0x10 (rx_queue_index).
  unsigned int key = ctx->rx_queue_index;
  if (bpf_map_lookup_elem(&sock_map, &key) == NULL) {
    /* sn-6e guard: no socket for THIS queue -> kernel keeps the frame */
    count(key, 1);
    return XDP_ACT_PASS;
  }
  count(key, 0);
  return bpf_redirect_map(&sock_map, key, XDP_XSKB);
}

SEC("xdp")
int xdp_prog(struct xdp_md *ctx)
{
  return redirect(ctx); /* ALL frames, no inspection */
}
