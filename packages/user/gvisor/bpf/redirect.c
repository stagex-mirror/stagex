// Custom AF_XDP "redirect" program for the sn-6 sys-net sandbox (Qubes
// sys-net face, full NIC ownership).
//
// Replaces the go-branch's prebuilt redirect_host_ebpf.o. The stock program
// is a direction-agnostic, dstport-only filter (PASS iff IPv4 TCP dstport==22
// else redirect), which kills the guest kernel's own TX: its SSH SYN-ACK /
// banner (srcport 22, dstport ephemeral) and its ARP get redirected into the
// sandbox, so new SSH connections to the kernel die at banner exchange.
//
// This program keeps the kernel's bidirectional tcp/22 management channel
// alive (PASS when EITHER port is 22) and redirects everything else to the
// sandbox's AF_XDP socket. It is a faithful drop-in of the stock .o:
//   - same map: legacy bpf_map_def, XSKMAP (byte 0x11 in the guest kernel),
//     key4/val4/max1, section "maps";
//   - same symbols: xdp_prog (section "xdp"), sock_map;
//   - same redirect: bpf_redirect_map(&sock_map, rx_queue_index, XDP_XSKB),
//     inlined to `call 0x33` exactly like the stock object;
//   - one semantic delta: PASS also when TCP SRCPORT==22 (the kernel's own
//     SSH TX). Everything else is byte-equivalent logic.
// so runsc/sandbox/xdp.go's LoadAndAssign (ebpf:"xdp_prog", ebpf:"sock_map")
// needs zero Go changes. All ABI constants are vendored + pinned to the guest
// kernel (bpf_helpers.h) — this file uses no kernel bpf.h at all.
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

static int redirect(struct xdp_md *ctx)
{
  // The sentry inserts its AF_XDP socket at key = ctx->rx_queue_index
  // (single-queue NIC: 0); bpf_redirect_map delivers the packet there.
  // Matches the stock program, which reads xdp_md+0x10 (rx_queue_index).
  return bpf_redirect_map(&sock_map, ctx->rx_queue_index, XDP_XSKB);
}

SEC("xdp")
int xdp_prog(struct xdp_md *ctx)
{
  void *data = (void *)(long)ctx->data;
  void *data_end = (void *)(long)ctx->data_end;

  struct ethhdr *eth = data;
  if ((void *)(eth + 1) > data_end)
    return XDP_ACT_PASS; /* malformed -> let the kernel drop it */
  if (eth->h_proto != bpf_htons(ETH_P_IP)) /* IPv4: wire 0x08 0x00, LE u16 0x0008 */
    return redirect(ctx); /* ARP, IPv6, ... -> sandbox */

  struct iphdr *ip = (void *)(eth + 1);
  if ((void *)(ip + 1) > data_end)
    return redirect(ctx);
  if (ip->protocol != IP_PROTO_TCP) /* 6 = TCP */
    return redirect(ctx); /* UDP/ICMP/... -> sandbox */

  struct tcphdr *tcp = (void *)(ip + 1);
  if ((void *)(tcp + 1) > data_end)
    return redirect(ctx);

  // THE FIX: bidirectional :22. Stock only checked dstport. The port fields
  // are __be16 on the wire; read as a C u16 on this little-endian guest, port
  // 22 is bpf_htons(22) = 0x1600 (NOT 0x0016 — that would match port 5632).
  // Pass when EITHER side is 22 so the kernel keeps both directions of its SSH
  // management channel. (The dstport leg alone suffices in driver mode where
  // the kernel TX is not XDP-hooked; the srcport leg covers generic mode,
  // where do_xdp_generic hooks egress too and the SYN-ACK would otherwise be
  // redirected into the sandbox.)
  if (tcp->source == bpf_htons(22) || tcp->dest == bpf_htons(22))
    return XDP_ACT_PASS; /* kernel keeps its SSH management channel */

  return redirect(ctx);
}
