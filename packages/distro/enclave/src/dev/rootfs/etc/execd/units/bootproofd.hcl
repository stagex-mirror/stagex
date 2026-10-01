// bootproofd — the attestation HTTP/TLS face (sn-7: co-tenant of the netstack).
//
// One process knows HTTP/TLS on this system: `bootproofd` listens on
// 0.0.0.0:443 (TLS, /health + /info + /attestation) and routes every
// challenge to enclaved's Unix socket (/run/enclaved/sock). It does NOT
// touch the attestation hardware itself — enclaved owns /dev/tpmrm0 and
// /dev/sev-guest; bootproofd is a thin TLS router.
//
// sn-7 placement: the kernel is FULLY offline, so the sn-6 model (bootproofd
// in its own `runsc do` sandbox + a kernel DNAT of eth0:443) is impossible —
// the wire never reaches the kernel netns. bootproofd instead runs as a
// co-tenant INSIDE the sysnet sandbox (the netstack is the only network
// face): the wire :443 arrives on eth0, the redirect program sends it to
// the netstack, and bootproofd binds 0.0.0.0:443 there, exactly like
// sshdt:22. The sysnet payload owns the process (a backgrounded restart
// loop; /run/enclaved + /home/bootproof are bound into the sandbox).
//
// This unit is the WITNESS (usr/libexec/bootproofd-sandbox.sh): it waits
// for the face to come up (runsc exec: process running + :443 answering on
// the netstack loopback) and holds while it is alive. execd's health here
// is "witness up" — deliberately NOT provided_sockets=tcp:0.0.0.0:443,
// because that socket lives in the netstack, which the guest kernel's
// loopback cannot reach (kernel offline). The wire reachability of :443 is
// verified from outside the guest (host TLS probe to the lease IP).
//
// TLS identity: /home/bootproof (the LUKS ext4 volume when a data disk is
// present, the tmpfs otherwise); on first contact the host pins the
// daemon's pubkey (TOFU), stable across reboots while /home is the
// persistent LUKS volume.
//
// Depends on enclaved: the evidence socket must be bound before bootproofd
// can serve (its restart loop retries until it is; the witness then holds).
//
// restart="always": the witness is respawned if it dies; the sysnet
// supervisor owns the actual face recovery (teardown + redirect re-arm +
// re-DORA + the in-sandbox bootproofd restart loop).

unit "bootproofd" {
  script = "/usr/libexec/bootproofd-sandbox.sh"

  depends {
    units = ["enclaved", "sysnet"]
  }

  restart = "always"
  health  = { type = "standard" }
}
