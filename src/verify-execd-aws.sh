#!/usr/bin/env bash
# verify-execd-aws.sh — the AWS leg for the shell-free execd enclave (Phase 4).
#
# Usage: bash src/verify-execd-aws.sh <ip>
#   ip  the live instance's public IP (re-fetch after any stop/start — the IP
#       changes)
#
# Layers, in order (first failing section names itself):
#   capture   reuse src/verify-execd-common.sh (PCRs + page-aligned event-log
#             dump + UKI-from-ESP + fresh 64-byte SNP nonce + snpguest v5
#             report) — the same flow src/verify-uki-execd.sh uses, no
#             duplication
#   bound     src/verify-binding --uki --no-part => VERDICT: BOUND (UKI
#             section digests, PCR 0/1/2/3/6/7/9 replay==live, PCR9
#             predicted, PCR11 no-partition, SNP nonce echo)
#   stack     src/verify-execd-stack.sh (zero-shell audit, socket contract,
#             bootproofd face: tpm_quote PROVEN + pcr_state PROVEN +
#             memory_encryption PROVEN on SNP hosts, LUKS, dmesg, userdata)
#   handles   LUKS full-policy: tpm2_getcap handles-persistent must show BOTH
#             0x81010200 (seed, pcrs 5,7) and 0x81010201 (full, pcrs
#             4,5,7,9) — the two-stage migration landed
#
# Exit 0 with a final PASS line; nonzero with the failing section named.
set -u

IP="${1:?Usage: bash src/verify-execd-aws.sh <ip>}"
KEY="${TPM_KEY:-$HOME/.ssh/tpm-exploration.pem}"
SRC="$(cd "$(dirname "$0")" && pwd)"
REPO="$(dirname "$SRC")"

ssh() { /usr/bin/ssh -i "$KEY" -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 root@"$IP" "$@"; }
export IP KEY

. "$SRC/verify-execd-common.sh"

section_fail() { echo "FAIL [$1]: $2" >&2; exit 1; }
section_pass() { echo "PASS [$1]"; }

# ------------------------------------------------------------ capture+bound
wait_for_ssh || section_fail capture "ssh never came up"

W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT

capture "$W" || section_fail capture "event-log / PCR / SNP capture failed"

echo "=== verify-binding (UKI) ==="
"$REPO/src/verify-binding" \
  --log "$W/eventlog.bin" \
  --pcrs "$W/pcrs.txt" \
  --snp "$W/snp-report.bin" \
  --snp-nonce "$W/nonce.bin" \
  --uki "$W/uki/BOOTX64.EFI" \
  --no-part || section_fail bound "verify-binding not BOUND (exit nonzero)"
section_pass bound

# ------------------------------------------------------------------- stack
echo "=== stack verifier ==="
bash "$SRC/verify-execd-stack.sh" "$IP" \
  || section_fail stack "verify-execd-stack.sh failed"
section_pass stack

# ------------------------------------------------------------- full handles
echo "=== LUKS full-policy persistent handles ==="
HANDLES=$(ssh 'TCTI=device:/dev/tpmrm0 tpm2_getcap handles-persistent 2>/dev/null || TCTI=device:/dev/tpm0 tpm2_getcap handles-persistent 2>/dev/null || true')
echo "$HANDLES"
echo "$HANDLES" | grep -q "0x81010200" || \
  section_fail handles "0x81010200 (seed, pcrs 5,7) not in handles-persistent"
echo "$HANDLES" | grep -q "0x81010201" || \
  section_fail handles "0x81010201 (full, pcrs 4,5,7,9) not in handles-persistent — migration did not land"
section_pass handles

# -------------------------------------------------------------------- done
echo "=================================================="
echo "PASS: AWS execd enclave verified on $IP"
echo "  capture: PCRs + page-aligned event log + UKI + SNP nonce"
echo "  bound:   VERDICT: BOUND (verify-binding --uki --no-part)"
echo "  stack:   zero-shell + socket + bootproofd PROVEN + LUKS + dmesg + userdata"
echo "  handles: 0x81010200 + 0x81010201 (two-stage full policy)"
echo "=================================================="
exit 0
