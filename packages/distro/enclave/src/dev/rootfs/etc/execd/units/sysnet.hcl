// sysnet — the Qubes "sys-net" face, sn-7: the kernel is FULLY offline.
// The gVisor netstack is the ONLY stack on the wire: it owns DHCP
// (rust-dhcp), ARP, SSH (sshdt on :22), and all egress.
//
// Runs /usr/libexec/sysnet.sh (the supervisor). The sequence:
//   1. ip link set eth0 up + flush any kernel addr/route (the kernel is
//      offline: link up, no lease, no route).
//   2. xdp_loader redirect -device eth0 — load + pin the v3 redirect
//      program/sockmap/link under /sys/fs/bpf/eth0/ and attach (driver
//      mode on virtio-net). The program inspects NOTHING: empty sockmap
//      -> XDP_PASS (the sn-6e death guard, now covering ALL traffic);
//      otherwise redirect EVERY frame (ARP, IPv4, IPv6) to the sandbox.
//   3. runsc create+start --network=sandbox --EXPERIMENTAL-xdp=redirect:eth0
//      -net-raw --allow-packet-socket-write. The uplink has 0 IPv4
//      addresses, so xdp-4 (0-or-1 relaxation) lets the sandbox NIC start
//      empty; xdp-2 (sentry-side synchronous configure) guarantees the
//      AF_XDP RX ring before the sockmap insert.
//   4. In the sandbox: rust-dhcp does DORA and applies the lease to the
//      NETSTACK via rtnetlink (RTM_NEWADDR/RTM_NEWROUTE; CAP_NET_ADMIN),
//      doing ARP itself (AF_PACKET; CAP_NET_RAW via -net-raw + AF_PACKET
//      writes via --allow-packet-socket-write). sshdt binds 0.0.0.0:22 in
//      the netstack, fail-closed on the bound /root/.ssh/authorized_keys.
//
// Host SSH (QEMU hostfwd :2222 -> guest :22) arrives on the wire, is
// redirected into the netstack by the program, and is served by the
// sandbox's sshdt. The kernel never sees a single L4 packet: no lease, no
// address, no route, no ARP table of its own.
//
// DEATH RECOVERY (sn-6e guard, now covering ALL traffic): the kernel
// auto-removes the socket from the pinned sockmap on close; the guard then
// XDP_PASSes the full wire to the kernel (no black hole) until the
// supervisor's liveness monitor (3 consecutive failed polls) tears down
// (kill sentry by PID, delete sandbox, detach program, unpin) and execd
// respawns — the fresh socket re-arms the redirect and rust-dhcp re-DORA's.
//
// Depends on lo (not dhcp, sn-7): the kernel is offline and the lease is
// owned by the sandbox's netstack, so there is no kernel dhcp unit to
// depend on. eth0 exists at boot (net.ifnames=0 on the cmdline).
//
// restart="always": a dead sys-net face is respawned; the script's teardown
// is idempotent (kill sentry, delete, xdp off, unpin, kill+del the
// per-sandbox netns by state-root match — never touches other sandboxes'
// netns, e.g. bootproofd's), so a respawn is clean.

unit "sysnet" {
  script = "/usr/libexec/sysnet.sh"

  depends {
    units = ["lo"]
  }

  restart = "always"
  health  = { type = "standard" }
}
