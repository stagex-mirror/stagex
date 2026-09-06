// tpm-rootfs — bind the TPM channel to the root filesystem (PCR 11).
//
// One-shot setup script (port of the S54tpm-rootfs logic, QEMU/AWS-
// verified): extends PCR 11 with SHA-256 of the raw system partition.
// On the current ESP-only (unikernel) disk there is no system
// partition, so the script detects that and writes
// /run/tpm-rootfs.status = "SKIP no-partition" — the byte-level rootfs
// binding on such disks is carried by the measured UKI .initrd instead.
//
// Always exits 0: a TPM problem must never break boot.
unit "tpm-rootfs" {
  command = "/usr/libexec/tpm-rootfs.sh"

  depends {
    units = ["lo"]
  }

  health = { type = "oneshot" }
}
