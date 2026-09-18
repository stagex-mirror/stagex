// enclaved — the enclave host daemon: the single no-arg process that owns
// the attestation hardware (SEV-SNP /dev/sev-guest + TPM2 /dev/tpmrm0|/dev/tpm0).
//
// One process replaces the whole shell unit set:
//   - the bootproof evidence socket (/run/enclaved/sock) — bound FIRST,
//     before any boot work, so bootproofd (and a host-side
//     `bootproof verify <file>` capture) can collect nonce-bound evidence
//     while the rest of boot runs;
//   - tpm-rootfs (PCR 11 extend with SHA-256 of the raw system partition;
//     "SKIP no-partition" on the ESP-only unikernel disk, same
//     /run/tpm-rootfs.status format the shell script wrote);
//   - cloud-init (IMDS user-data direct, with the config-drive ISO mount
//     fallback; writes /run/userdata, /etc/hostname, /root/.ssh/authorized_keys);
//   - the LUKS /home volume (two-stage PCR policy, I/O deadlines, cryptsetup
//     luksFormat oracle on first boot, pure-Rust open path);
//   - the unprivileged user (from /run/userdata).
//
// NO RESTART: the exit is final by design (Restart default = No). The PCR 11
// extend must happen exactly once per boot — a crash respawn would double-
// extend and break the verifier's PCR 11 replay. If enclaved ever exits
// before its ready file, dependents see it as finished and proceed (sshdt's
// when-gate then fail-closes with no keys — the honest state).
//
// Depends on dhcp: the IMDS user-data fetch is bounded (120 s deadline,
// 5 s connect timeout) and never blocks boot, but starting after the lease
// means the first attempt can succeed instead of timing out.
//
// Readiness: health gates on /run/enclaved/ready, which enclaved writes
// AFTER the boot work (socket bound, pcr11 measured, userdata applied, disk
// + user done). sshdt depends on this unit and then evaluates its own
// fail-closed key gate, so it can only start once authorized_keys exist.
unit "enclaved" {
  command = "/usr/bin/enclaved"

  depends {
    units = ["dhcp"]
  }

  health = { type = "standard", provided_files = ["/run/enclaved/ready"] }
}
