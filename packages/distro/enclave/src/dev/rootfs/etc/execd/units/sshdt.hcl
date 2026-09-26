// sshdt — the enclave SSH server (the only interactive surface; no getty).
//
// Direct binary call with explicit flags (no config file): port 22 on all
// interfaces, host key auto-generated in the /run/ssh tmpfs (per-boot,
// created by nit), public-key auth against /root/.ssh/authorized_keys.
//
// SECURITY: the flags are load-bearing. sshdt's built-in defaults are
// bind=127.0.0.1 (loopback only — AWS SSH dies) and an EMPTY
// authorized-keys list (which makes it auto-accept ANONYMOUS connections).
// The script must therefore always pass --bind, --host-key and
// --authorized-keys explicitly, and must never exec sshdt at all unless
// the key file exists.
//
// Bounded wait, not a skip-gate: the host daemon writes
// /root/.ssh/authorized_keys ASYNCHRONOUSLY after consuming the provisioner
// drop, so a `when = { path_exists = [...] }` gate could be evaluated (and
// SKIP the unit) before the key lands — port 22 then stays closed forever.
// The inline script instead polls for the key up to 120 s (sleep 1 between
// checks, no background jobs — brush's `wait` is broken). If the key
// appears, it execs the sshdt command verbatim. If 120 s elapse with no
// key it exits non-zero: FAIL-CLOSED — sshdt never starts without a key
// (no anonymous auth) — and restart="always" respawns the unit, which
// re-waits for another bounded window.
//
// restart="always" replaces the old nohup+pidfile dance.
unit "sshdt" {
  script = <<SCRIPT
#!/bin/sh
# Bounded wait for the provisioned key (up to 120 s, sleep 1 between
# checks). No background jobs: brush's `wait` builtin is unreliable.
KEY=/root/.ssh/authorized_keys
i=0
while [ ! -f "$KEY" ] && [ "$i" -lt 120 ]; do
  sleep 1
  i=$((i + 1))
done
if [ ! -f "$KEY" ]; then
  echo "sshdt: no authorized_keys after 120 s; refusing to start (fail-closed)" >&2
  exit 1
fi
exec /usr/bin/sshdt --no-config --port 22 --bind 0.0.0.0 --host-key /run/ssh/host_ed25519 --authorized-keys /root/.ssh/authorized_keys
SCRIPT

  depends {
    units = ["enclaved"]
  }

  restart = "always"
  health  = { type = "standard" }
}
