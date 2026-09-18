# verify-execd-common.sh — shared capture flow for the execd enclave verify legs.
#
# Sourced by:
#   src/verify-uki-execd.sh  (AWS event-log / PCR / SNP capture + verify-binding)
#   src/verify-execd-aws.sh  (the Phase-4 AWS leg: capture + BOUND + stack + handles)
#
# Expects the caller to define:
#   IP  — target host (the old script sets it from $1)
# and to run under `set -e` (capture fails the caller on a hard error).
#
# capture W:
#   $W/pcrs.txt       tpm2_pcrread (TCTI tpmrm0, fallback tpm0)
#   $W/eventlog.bin   TPM event log from /dev/mem, page-aligned dd of the
#                     exact [TPMEventLog, TPMFinalLog] region (the log starts
#                     AT TPMEventLog — a backward window ends before it).
#                     Supersedes the old bs=1 dump (~25 min over ssh).
#   $W/esp.raw        ESP carve-out of the boot disk (LBA 2048, 256 MiB)
#   $W/uki/BOOTX64.EFI the UKI, mcopy'd out of the ESP
#   $W/nonce.bin      fresh 64-byte SNP nonce
#   $W/snp-report.bin snpguest v5 report (returns 1 + empty file when the
#                     host has no /dev/sev-guest, e.g. QEMU swtpm)

# --- wait_for_ssh ----------------------------------------------------------
wait_for_ssh() {
  echo "=== waiting for SSH on $IP ==="
  UP=0
  for i in $(seq 1 60); do
    if ssh 'true' >/dev/null 2>&1; then UP=1; break; fi
    sleep 10
  done
  [ "$UP" = 1 ] || { echo "SSH never came up"; return 1; }
  echo "SSH up"
}

# --- capture W -------------------------------------------------------------
capture() {
  local W="$1"

  echo "=== dmesg traps ==="
  ssh 'dmesg | grep -iE "trap|general protection|CFI: |UBSAN|BUG:" | grep -v "report a bug"' || echo "(none)"

  echo "=== PCRs ==="
  ssh 'TCTI=device:/dev/tpmrm0 tpm2_pcrread' > "$W/pcrs.txt" 2>/dev/null || \
    ssh 'TCTI=device:/dev/tpm0 tpm2_pcrread' > "$W/pcrs.txt"
  head -4 "$W/pcrs.txt"

  echo "=== enclaved PCR11 status ==="
  ssh 'cat /run/tpm-rootfs.status 2>/dev/null || echo "(no tpm-rootfs status)"'

  echo "=== TPM event log from /dev/mem (page-aligned) ==="
  local EV FL EVADDR FLADDR OFF PAGES
  EV=$(ssh 'dmesg | grep -oE "TPMEventLog=0x[0-9a-f]+" | head -1 | cut -d= -f2')
  [ -n "$EV" ] || { echo "ERROR: no TPMEventLog= in dmesg"; return 1; }
  FL=$(ssh 'dmesg | grep -oE "TPMFinalLog=0x[0-9a-f]+" | head -1 | cut -d= -f2')
  echo "TPMEventLog=$EV  TPMFinalLog=${FL:-unset}"
  # The event log STARTS at TPMEventLog (the Spec ID event sits ~41 bytes in)
  # and runs to TPMFinalLog. Read the EXACT log region, page-aligned forward:
  # a backward 32 MiB window ends before the log starts (no Spec ID), and a
  # large forward read overshoots TPMFinalLog into sparse/SNP-reserved
  # memory, which wedges the guest (unreachable until stop/start). Cap the
  # page count: the log is a few hundred KiB; 1024 pages (4 MiB) is ample.
  EVADDR=$(python3 -c "print(int('$EV',16)//4096*4096)")
  if [ -n "$FL" ]; then
    FLADDR=$(python3 -c "print((int('$FL',16)+4095)//4096*4096)")
    PAGES=$(( (FLADDR - EVADDR) / 4096 + 1 ))
    [ "$PAGES" -gt 1024 ] && PAGES=1024
    [ "$PAGES" -lt 1 ] && PAGES=1
  else
    PAGES=256
  fi
  OFF="$EVADDR"
  ssh "dd if=/dev/mem bs=4096 skip=$((OFF/4096)) count=$PAGES 2>/dev/null | base64 -w0" \
    | base64 -d > "$W/eventlog.bin"
  ls -la "$W/eventlog.bin"

  echo "=== UKI from ESP (LBA 2048, first 256 MiB of boot disk) ==="
  # Boot disk = the disk carrying the ESP (partition 1). FIRST block device
  # on both AWS (nvme0n1) and QEMU (vda); the LUKS data disk is attached
  # second (nvme1n1 / vdb). Enumerate explicitly — no globs (the guest's
  # minimal sh doesn't nullglob, so patterns leak as literals).
  local BOOTDISK
  BOOTDISK=$(ssh '
for d in nvme0n1 vda; do
  [ -b /dev/$d ] || continue
  case $d in
    nvme*) child=/sys/block/$d/${d}p1 ;;
    *)     child=/sys/block/$d/${d}1 ;;
  esac
  [ -e "$child" ] && { echo $d; break; }
done')
  [ -n "$BOOTDISK" ] || { echo "ERROR: no boot disk found"; return 1; }
  echo "boot disk: $BOOTDISK"
  ssh "dd if=/dev/$BOOTDISK bs=512 skip=2048 count=524288 2>/dev/null | base64 -w0" \
    | base64 -d > "$W/esp.raw"
  mkdir -p "$W/uki"
  busybox mcopy -i "$W/esp.raw" ::/EFI/BOOT/BOOTX64.EFI "$W/uki/BOOTX64.EFI" 2>/dev/null || \
    mcopy -i "$W/esp.raw" ::/EFI/BOOT/BOOTX64.EFI "$W/uki/BOOTX64.EFI"
  ls -la "$W/uki/BOOTX64.EFI"

  echo "=== SNP report with fresh nonce ==="
  head -c 64 /dev/urandom > "$W/nonce.bin"
  base64 -w0 "$W/nonce.bin" | ssh "base64 -d > /tmp/nonce.bin"
  if ssh 'TCTI=device:/dev/tpmrm0 snpguest report -v 0 /tmp/snp-report.bin /tmp/nonce.bin 2>/dev/null || snpguest report -v 0 /tmp/snp-report.bin /tmp/nonce.bin 2>/dev/null'; then
    ssh 'base64 -w0 /tmp/snp-report.bin' | base64 -d > "$W/snp-report.bin"
    ls -la "$W/snp-report.bin"
  else
    : > "$W/snp-report.bin"
    echo "(no /dev/sev-guest — no SNP report; QEMU swtpm path)"
    return 1
  fi
}
