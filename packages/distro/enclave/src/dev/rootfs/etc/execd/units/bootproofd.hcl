// bootproofd — the sole HTTP face over the enclaved evidence socket.
//
// One process knows HTTP/TLS on this system: `bootproofd` listens on
// 0.0.0.0:443 (TLS, /health + /info + /attestation) and routes every
// challenge to enclaved's Unix socket (/run/enclaved/sock). It does NOT
// touch the attestation hardware itself — enclaved owns /dev/tpmrm0 and
// /dev/sev-guest; bootproofd is a thin TLS router. The narrow `bootproof`
// CLI is the offline/file path (verify <file>); the remote path is
// `bootproof verify <ip> --direct --trust` against this service.
//
// Self-sufficient: it creates its own state dir (/home/bootproof — the
// LUKS ext4 volume when a data disk is present, the tmpfs otherwise) for
// the TLS identity, so no `pre` unit is needed. On first contact the host
// pins the daemon's pubkey (TOFU), which is stable across reboots as long
// as /home is the persistent LUKS volume.
//
// Depends on enclaved: the evidence socket must be bound (step 1 of
// enclaved's startup, before its ready file) and the boot work done.
//
// restart="always": a dead HTTP face must not be a single point of
// failure; the socket it serves unlinks its stale copy before binding, so
// a respawn is safe.
unit "bootproofd" {
  command = "/usr/bin/bootproofd"

  depends {
    units = ["enclaved"]
  }

  restart = "always"
  health  = { type = "standard", provided_sockets = ["tcp:0.0.0.0:443"] }
}
