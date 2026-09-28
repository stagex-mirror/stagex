// sysnet — the Qubes "sys-net" face: a gVisor sandbox owning the guest's
// data plane via an AF_XDP redirect (4-patch runsc, xdp-1..4).
//
// Runs /usr/libexec/sysnet.sh (the oracle-derived supervisor): builds a
// veth pair (syso-host in the main netns, syso-ctr in a private netns),
// starts a long-lived gVisor sandbox in that netns with
// --EXPERIMENTAL-xdp=redirect:syso-ctr (xdp-4 BindSentry: the sentry
// registers UMEM + rings, THEN binds — the kernel xsk_bind guard passes),
// and installs the redirect_host XDP program on syso-ctr. The program
// XDP_PASSes tcp/22 to the netns kernel stack (SSH stays reachable) and
// diverts every other class via bpf_redirect_map(sock_map) into the
// sandbox's netstack. The guest's own egress (the virtio NIC) is NOT
// touched by the program; the L3 flush routes the redirect class through
// the sandbox netstack only AFTER the sandbox is confirmed running (the
// wedge rule: a pinned program with an empty socket map drops frames
// into nowhere — never install it before the AF_XDP socket is bound).
//
// Depends on dhcp: the supervisor resolves the egress device from the
// default route the dhcp unit installed; without it the sandbox is up
// but dark, and the script exits non-zero (bounded wait, respawn).
//
// restart="always": a dead sys-net face is respawned; the script's
// teardown detaches the program, deletes the sandbox, kills and removes
// the netns, and unbinds the pins before exit, so a respawn is clean. A
// persistent bind failure is a build regression — the script exits
// non-zero and retries; it never leaves the guest without egress (the
// pre-existing L3 stays intact on every failure path).

unit "sysnet" {
  script = "/usr/libexec/sysnet.sh"

  depends {
    units = ["dhcp"]
  }

  restart = "always"
  health  = { type = "standard" }
}
