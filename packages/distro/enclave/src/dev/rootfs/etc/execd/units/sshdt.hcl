// sshdt — the enclave SSH server (the only interactive surface; no getty).
//
// Direct binary call with explicit flags (no config file): port 22 on all
// interfaces, host key auto-generated in the /run/ssh tmpfs (per-boot,
// created by nit), public-key auth against /root/.ssh/authorized_keys.
//
// SECURITY: the flags are load-bearing. sshdt's built-in defaults are
// bind=127.0.0.1 (loopback only — AWS SSH dies) and an EMPTY
// authorized-keys list (which makes it auto-accept ANONYMOUS connections).
// This unit must therefore always pass --bind, --host-key and
// --authorized-keys explicitly.
//
// Fail-closed via the when-gate: the unit must not start without a key.
// enclaved (the sole writer of /root/.ssh/authorized_keys, from IMDS or
// the config drive) is the dependency; its ready file is written after the
// key write, so the gate is evaluated only once the keys either exist
// (start) or will never be (skip — dependents still proceed, port 22 stays
// closed). A unit that cannot start is marked finished, never a boot stall.
//
// restart="always" replaces the old nohup+pidfile dance.
unit "sshdt" {
  command = "/usr/bin/sshdt"
  args    = ["--no-config",
             "--port", "22",
             "--bind", "0.0.0.0",
             "--host-key", "/run/ssh/host_ed25519",
             "--authorized-keys", "/root/.ssh/authorized_keys"]

  when = {
    path_exists = ["/root/.ssh/authorized_keys"]
  }

  depends {
    units = ["enclaved"]
  }

  restart = "always"
  health  = { type = "standard" }
}
