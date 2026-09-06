// bootproof — the attestation daemon (dual channel: NitroTPM + SEV-SNP).
//
// Direct binary call: `bootproof attest` serves the nonce-challenge
// attestation bundle over TLS on 0.0.0.0:443, paired with the host-side
// `bootproof verify <ip> --direct --trust --pin`. It opens the TPM device
// directly (no abrmd) and shells out to snpguest for the SNP report.
//
// State (TLS identity + TPM keys) must persist for pin stability: it lives
// in /home/bootproof (LUKS ext4) — hence the depends on home, so the
// volume is mounted (or known to be tmpfs) before the identity is first
// written. Without a data disk /home is the tmpfs and the identity is
// regenerated per boot (pin changes, same as the old S55 fallback).
//
// pre: ensure the state dir exists on whichever /home is live.
// when-gate: no TPM device -> skip (restart="always" would just flap).
unit "bootproof" {
  command = "/usr/bin/bootproof"
  args    = ["attest", "--listen", "0.0.0.0:443", "--state", "/home/bootproof"]
  pre     = [["/usr/bin/mkdir", "-p", "/home/bootproof"]]

  when = {
    any_path_exists = ["/dev/tpm0", "/dev/tpmrm0"]
  }

  depends {
    units = ["lo", "home"]
  }

  restart = "always"
  health  = { type = "standard" }
}
