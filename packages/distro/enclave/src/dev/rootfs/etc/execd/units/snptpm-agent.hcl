// snptpm-agent — SEV-SNP/TPM2 quote agent (HTTP :9003).
//
// Direct binary call, no args (it finds /dev/tpm0 or /dev/tpmrm0 itself;
// no tpm2-abrmd/D-Bus in this image). The kernel RM on /dev/tpmrm0 handles
// TPM concurrency.
//
// when-gate: with no TPM device present (some bare QEMU configs) the agent
// would exit at startup and restart="always" would flap it every second;
// skipping is the correct "no attestation hardware" state.
unit "snptpm-agent" {
  command = "/usr/bin/snptpm-agent"

  when = {
    any_path_exists = ["/dev/tpm0", "/dev/tpmrm0"]
  }

  depends {
    units = ["lo"]
  }

  restart = "always"
  health  = { type = "standard" }
}
