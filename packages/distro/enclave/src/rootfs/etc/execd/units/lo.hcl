// lo — bring up loopback.
//
// Nothing else on this system brings up 127.0.0.1, and every in-guest
// service (sshdt, snptpm-agent, bootproof, tpm2-tools) needs it. A DOWN
// loopback masquerades as a network/daemon failure, so this is the first
// unit execd starts; everything else depends on it.
//
// Direct binary call (busybox ip applet) — no shell wrapper. If it fails,
// the unit is marked failed and dependents still proceed (a failed unit
// reports ready), so a loopback problem degrades but does not stall boot.
unit "lo" {
  command = "/usr/bin/ip"
  args    = ["link", "set", "lo", "up"]
  health  = { type = "oneshot" }
}
