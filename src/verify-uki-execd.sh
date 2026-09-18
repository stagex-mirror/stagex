#!/bin/sh
# verify-uki-execd.sh — full verify-binding flow for the execd enclave on AWS.
# Usage: sh src/verify-uki-execd.sh <public-ip>
# Collects: PCRs, TPM event log (from /dev/mem at TPMEventLog=), UKI (mcopy
# from ESP), SNP v5 report with fresh 64-byte nonce, then runs
# verify-binding --uki --no-part.
#
# The capture itself lives in src/verify-execd-common.sh (shared with
# src/verify-execd-aws.sh) — this script is the thin entry point.
set -e
IP="${1:?Usage: sh src/verify-uki-execd.sh <public-ip>}"
KEY="$HOME/.ssh/tpm-exploration.pem"
ssh() { /usr/bin/ssh -i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 root@"$IP" "$@"; }
export IP KEY

. "$(dirname "$0")/verify-execd-common.sh"

wait_for_ssh
W=$(mktemp -d)
capture "$W"

echo "=== verify-binding ==="
# Run verify-binding from this repo (the scripts sit in src/ alongside it).
REPO="$(cd "$(dirname "$0")/.." && pwd)"
"$REPO/src/verify-binding" \
  --log "$W/eventlog.bin" \
  --pcrs "$W/pcrs.txt" \
  --snp "$W/snp-report.bin" \
  --snp-nonce "$W/nonce.bin" \
  --uki "$W/uki/BOOTX64.EFI" \
  --no-part
echo "=== work dir: $W ==="
