// sshdt — the enclave SSH server (the only interactive surface; no getty).
//
// Direct binary call with explicit flags (no config file): port 22 on all
// interfaces, host key auto-generated in the /run/ssh tmpfs (per-boot,
// created by nit), public-key auth against the cloud-init-seeded
// /root/.ssh/authorized_keys.
//
// Fail-closed via the when-gate: sshdt auto-accepts anonymous connections
// when NO key is configured, so the unit must not start without a key.
// The gate is evaluated after both cloud-init units have finished, so the
// key (drive or metadata) is either present (start) or will never be
// (skip — dependents still proceed, port 22 stays closed). A unit that
// cannot start is marked finished, never a boot stall.
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
    units = ["cloud-init-drive", "cloud-init-net", "home"]
  }

  restart = "always"
  health  = { type = "standard" }
}
