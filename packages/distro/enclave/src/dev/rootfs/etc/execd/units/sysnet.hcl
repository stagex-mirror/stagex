// sysnet — the Qubes "sys-net" face, sn-6 FULL NIC ownership: a gVisor
// sandbox owning the guest NIC's data plane via an AF_XDP redirect
// (3-patch runsc: xdp-1..3 in packages/user/gvisor).
//
// Runs /usr/libexec/sysnet.sh (the supervisor). The sequence:
//   1. xdp_loader redirect -device <uplink> — load + pin the
//      redirect program/sockmap/link under /sys/fs/bpf/<uplink>/ and attach
//      the program (driver mode on virtio-net; generic as the e1000 fallback).
//      The program XDP_PASSes tcp/22 to the
//      kernel stack (SSH stays reachable) and diverts every other class via
//      bpf_redirect_map(sock_map) into the sandbox's sentry netstack.
//   2. runsc create+start --network=sandbox --EXPERIMENTAL-xdp=redirect:<uplink>.
//      The sentry scrapes the uplink's addr/routes/ARP, and (xdp-2,
//      sentry-side) its AF_XDP socket is configured SYNCHRONOUSLY at
//      SetNetworkArgs — before runsc's client inserts it into the pinned
//      sockmap — so the kernel's xskmap RX-ring guard (-ENOBUFS) passes.
//
// The sandbox netstack sources the guest's REAL lease address (scraped at
// start), so its egress needs no NAT: the sandbox IS the guest's egress
// point. There is no private netns and no veth.
//
// WEDGE (accepted risk, pending the sn-6e route-flip agent): the program
// sits on the uplink. If the sandbox dies, the redirect class
// (everything non-tcp/22) drops — guest egress is dark EXCEPT SSH. The
// supervisor's liveness monitor (3 consecutive failed polls) exits
// non-zero -> teardown (kill sentry by PID, delete sandbox, detach program,
// unpin) -> execd respawns. Recovery is bounded (~15 s + teardown).
//
// Depends on dhcp: the supervisor resolves the uplink from the default
// route the dhcp unit installed; without it the sandbox is up but dark,
// and the script exits non-zero (bounded wait, respawn).
//
// restart="always": a dead sys-net face is respawned; the script's teardown
// is idempotent (kill sentry, delete, xdp off, unpin, kill+del the
// per-sandbox netns by state-root match — never touches other sandboxes'
// netns, e.g. bootproofd's), so a respawn is clean.

unit "sysnet" {
  script = "/usr/libexec/sysnet.sh"

  depends {
    units = ["dhcp"]
  }

  restart = "always"
  health  = { type = "standard" }
}
