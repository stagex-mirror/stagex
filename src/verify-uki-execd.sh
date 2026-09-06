#!/bin/sh
# verify-uki-execd.sh — full verify-binding flow for the execd enclave on AWS.
# Usage: sh src/verify-uki-execd.sh <public-ip>
# Collects: PCRs, TPM event log (from /dev/mem at TPMEventLog=), UKI (mcopy
# from ESP), SNP v5 report with fresh 64-byte nonce, tpm-rootfs status, then
# runs verify-binding --uki --no-part.
set -e
IP="${1:?Usage: sh src/verify-uki-execd.sh <public-ip>}"
KEY="$HOME/.ssh/tpm-exploration.pem"
W=$(mktemp -d)
ssh() { /usr/bin/ssh -i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 root@"$IP" "$@"; }

echo "=== waiting for SSH on $IP ==="
UP=0
for i in $(seq 1 60); do
  if ssh 'true' >/dev/null 2>&1; then UP=1; break; fi
  sleep 10
done
[ "$UP" = 1 ] || { echo "SSH never came up"; exit 1; }
echo "SSH up"

echo "=== dmesg traps ==="
ssh 'dmesg | grep -iE "trap|general protection|CFI: |UBSAN|BUG:" | grep -v "report a bug"' || echo "(none)"

echo "=== unit/daemon state ==="
ssh 'ps | grep -E "sshdt|snptpm|bootproof|dhcp|execd" | grep -v grep'
ssh 'cat /run/tpm-rootfs.status 2>/dev/null || echo "(no tpm-rootfs status)"'

echo "=== PCRs ==="
ssh 'TCTI=device:/dev/tpmrm0 tpm2_pcrread' > "$W/pcrs.txt" || \
ssh 'TCTI=device:/dev/tpm0 tpm2_pcrread' > "$W/pcrs.txt"
head -4 "$W/pcrs.txt"

echo "=== TPM event log from /dev/mem ==="
EV=$(ssh 'dmesg | grep -oE "TPMEventLog=0x[0-9a-f]+" | head -1 | cut -d= -f2')
echo "TPMEventLog=$EV"
# 4K-aligned window before the event log (32 MiB)
OFF=$(python3 -c "print((int('$EV',16)//4096)*4096 - 33554432)")
[ "$OFF" -lt 0 ] && OFF=0
ssh "dd if=/dev/mem bs=1 skip=$OFF count=33554432 2>/dev/null | base64 -w0" | base64 -d > "$W/eventlog.bin"
ls -la "$W/eventlog.bin"

echo "=== UKI from ESP (LBA 2048, first 256 MiB of boot disk) ==="
# Boot disk = the whole disk that carries the ESP (partition 1). It is the
# FIRST block device on both AWS (nvme0n1) and QEMU (vda); the LUKS data disk
# is attached second (nvme1n1 / vdb). Enumerate explicitly — no globs (the
# guest's minimal sh doesn't nullglob, so patterns leak as literals).
BOOTDISK=$(ssh '
for d in nvme0n1 vda; do
  [ -b /dev/$d ] || continue
  case $d in
    nvme*) child=/sys/block/$d/${d}p1 ;;
    *)     child=/sys/block/$d/${d}1 ;;
  esac
  [ -e "$child" ] && { echo $d; break; }
done')
[ -n "$BOOTDISK" ] || { echo "ERROR: no boot disk found"; exit 1; }
echo "boot disk: $BOOTDISK"
ssh "dd if=/dev/$BOOTDISK bs=512 skip=2048 count=524288 2>/dev/null | base64 -w0" | base64 -d > "$W/esp.raw"
mkdir -p "$W/uki"
busybox mcopy -i "$W/esp.raw" ::/EFI/BOOT/BOOTX64.EFI "$W/uki/BOOTX64.EFI" 2>/dev/null || \
  mcopy -i "$W/esp.raw" ::/EFI/BOOT/BOOTX64.EFI "$W/uki/BOOTX64.EFI"
ls -la "$W/uki/BOOTX64.EFI"

echo "=== SNP report with fresh nonce ==="
head -c 64 /dev/urandom > "$W/nonce.bin"
base64 -w0 "$W/nonce.bin" | ssh "base64 -d > /tmp/nonce.bin"
ssh 'TCTI=device:/dev/tpmrm0 snpguest report -v 0 /tmp/snp-report.bin /tmp/nonce.bin 2>/dev/null || snpguest report -v 0 /tmp/snp-report.bin /tmp/nonce.bin 2>/dev/null'
ssh 'base64 -w0 /tmp/snp-report.bin' | base64 -d > "$W/snp-report.bin"
ls -la "$W/snp-report.bin"

echo "=== verify-binding ==="
# Run verify-binding from this repo (the script sits in src/ alongside it).
REPO="$(cd "$(dirname "$0")/.." && pwd)"
"$REPO/src/verify-binding" \
  --log "$W/eventlog.bin" \
  --pcrs "$W/pcrs.txt" \
  --snp "$W/snp-report.bin" \
  --snp-nonce "$W/nonce.bin" \
  --uki "$W/uki/BOOTX64.EFI" \
  --no-part
echo "=== work dir: $W ==="
