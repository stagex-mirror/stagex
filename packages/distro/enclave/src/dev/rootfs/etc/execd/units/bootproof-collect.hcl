// bootproof-collect — the SOLE process that touches the attestation
// hardware (/dev/tpm0, /dev/sev-guest). Listens on a UDS; the sandboxed
// `bootproof attest` node (unit: bootproof) routes every challenge here
// instead of opening devices itself (gVisor forbids device reads — the
// daemon runs OUTSIDE the sandbox, the node INSIDE).
//
// If the daemon is down the node degrades to honest NOT PROVEN (no
// fallback, no device read by the node). So this unit is what makes the
// hardware channels provable at all: no unit, no evidence.
//
// pre: the socket dir must exist on the live /run tmpfs.
// when-gate: no attestation hardware -> skip (restart="always" would flap).
unit "bootproof-collect" {
  command = "/usr/bin/bootproof"
  args    = ["collect", "--socket", "/run/bootproof/collect.sock"]
  pre     = [["/usr/bin/mkdir", "-p", "/run/bootproof"]]

  when = {
    any_path_exists = ["/dev/tpm0", "/dev/tpmrm0", "/dev/sev-guest"]
  }

  depends {
    units = ["lo"]
  }

  restart = "always"
  health  = { type = "standard" }
}
