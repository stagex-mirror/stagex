// provisioner — run enclavectl provision in a gVisor sandbox after enclaved
// has done its boot work.
//
// Oneshot: execd runs the script body via /bin/sh -c. There is NO staging:
// the sandbox runs the host's own /usr/bin/enclavectl against the host /
// (default --root), and the provisioned result lands in the daemon's drop
// file (/run/enclaved/drop) through the shared /run/enclaved volume. The
// script carries the LOCKED, in-guest-proven invocation:
//
//   runsc --ignore-cgroups do --cwd / --force-overlay=false \
//     --volume /run/enclaved:/run/enclaved /usr/bin/enclavectl provision
//
// --force-overlay=false is REQUIRED (with the default all:memory overlay the
// drop write is trapped in RAM and never reaches the host); see the header
// in provision.sh for the full oracle record + the deliberate isolation note.
//
// Depends on enclaved: the daemon must be up (ready file written,
// userdata seeded at /run/enclaved/userdata.seed) before provisioning
// runs — the sandboxed provisioner talks to the daemon through the shared
// /run/enclaved volume.
//
// FAIL-OPEN: the script always exits 0 (every failure is logged to stderr
// and swallowed), so a provision failure never stalls the DAG and never
// blocks sshdt/bootproofd. No restart: a oneshot's exit is final (Restart
// default = No), same shape as enclaved — provisioning happens exactly
// once per boot.
unit "provisioner" {
  script = "/usr/libexec/provision.sh"

  depends {
    units = ["enclaved"]
  }

  health = { type = "oneshot" }
}
