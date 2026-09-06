// home — LUKS /home volume (TPM2 PCR-locked key) + unprivileged user setup.
//
// One-shot setup script (port of the S15home logic, QEMU/AWS-verified):
// two-stage PCR policy (seed 5,7 on first boot; full 4,5,7,9 after the
// firmware's first-boot drift settles), I/O deadlines on every disk step,
// fixed argon2id PBKDF (no cryptsetup benchmark), and setup_user (bind-
// mounted /etc/passwd + group, user from /run/userdata, its ssh keys).
//
// Depends on cloud-init-net: setup_user reads /run/userdata (home user
// name + keys) which it writes. Always exits 0 (fail-closed: on unseal
// failure /home stays the tmpfs and root SSH still works).
unit "home" {
  command = "/usr/libexec/home.sh"

  depends {
    units = ["cloud-init-net"]
  }

  health = { type = "oneshot" }
}
