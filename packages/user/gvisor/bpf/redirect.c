// Custom AF_XDP "redirect" program for the sn-7 sys-net sandbox (Qubes
// sys-net face, full NIC ownership, kernel FULLY offline).
//
// v3 is the maximally simple program: NO ethertype gate, NO IP header parse,
// NO port tests. The netstack is the ONLY stack on the wire and it owns ARP
// too — the sentry resolves the GW MAC (ARP requests go out the AF_XDP
// socket, the GW's ARP replies must land in the sandbox, not the kernel) and
// answers ARP for its own lease IP. The kernel has no lease, no address,
// nothing to do.
//
// The whole body is:
//   if sock_map empty (bpf_map_lookup_elem == NULL)  -> XDP_PASS
//   else                                             -> bpf_redirect_map (ALL frames)
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
// Drop-in ABI vs the stock go-branch .o (unchanged from v1/v2):
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

static int redirect(struct xdp_md *ctx)
{
  // The sentry inserts its AF_XDP socket at key = ctx->rx_queue_index
  // (single-queue NIC: 0); bpf_redirect_map delivers the packet there.
  // Matches the stock program, which reads xdp_md+0x10 (rx_queue_index).
  unsigned int key = ctx->rx_queue_index;
  if (bpf_map_lookup_elem(&sock_map, &key) == NULL)
    return XDP_ACT_PASS; /* sn-6e guard: no socket -> kernel keeps the wire */
  return bpf_redirect_map(&sock_map, key, XDP_XSKB);
}

SEC("xdp")
int xdp_prog(struct xdp_md *ctx)
{
  return redirect(ctx); /* ALL frames, no inspection */
}
