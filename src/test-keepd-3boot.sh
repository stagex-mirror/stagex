#!/bin/sh
# test-keepd-3boot.sh — the QEMU 3-boot LUKS lifecycle test.
#
# Drives the keepd LUKS state machine across THREE real QEMU boots on a
# persistent data disk, and verifies the state machine by reading the PCR
# policy out of the data disk's LUKS2 header (the authoritative, host-visible,
# persistent evidence — the custom `pcrs` JSON field cryptsetup ignores).
#
# The 3-boot table (the wire-proven prior art):
#
#   boot 1: blank data disk  -> format under the SEED policy (5,7)
#   boot 2: existing LUKS    -> MIGRATE seed -> full (add 4,5,7,9; delete 5,7)
#   boot 3: existing LUKS    -> clean OPEN (steady; no re-format, no re-migrate)
#
# After each boot we assert the data disk's PCR policy:
#
#   after boot 1: exactly {5,7}            (seed only)
#   after boot 2: exactly {4,5,7,9}        (full only; the seed slot is GONE)
#   after boot 3: exactly {4,5,7,9}        (still full; the UUID is UNCHANGED
#                                            from boot 2 — a re-format would
#                                            have minted a new UUID)
#
# The data disk is a BIND MOUNT (docker rm -f kills without flushing — we use a
# clean stop, never rm -f), and the QEMU startup does NOT reset it, so the LUKS
# volume persists across boots — that is the point.
#
# WHY NOT THE SERIAL CONSOLE? The keepd's lifecycle line ("keepd: first boot —
# formatted") is delivered through the bus to scribed (the per-unit store inside
# the sandbox), NOT to the serial console — so grepping `docker logs` for it
# never matches. The serial console DOES carry the warden's own status lines
# (the attest gate, the keepd's `up (secret derived)`, and the kernel's
# `EXT4-fs (dm-0)` mount), which we use as the liveness gate (proof the guest
# booted, the attest gate passed, and the LUKS volume opened + mounted). The
# state-machine PROOF itself is the data disk's PCR policy.
#
# The unit-level proof of the same state machine is the cargo test
# `keepd_3boot_drives_format_migrate_open_with_console_lines` in the keep crate
# (no QEMU needed). This script is the hardware-level repro.
#
# QEMU is launched DIRECTLY (replicating the `make qemu-start` docker-run flags)
# rather than through `make qemu-start`, because that target's SSH :2222 gate is
# flaky (documented gotcha: the serial log is the authoritative evidence, not
# SSH). We poll the serial console + the QMP socket instead. Reboots between
# boots are a QMP `system_reset` (the guest reboots in place; the QMP socket
# stays up; the LUKS writes are fsync'd + the data disk is a bind mount, so the
# header is durable across the reset).
#
# Usage:
#   ./src/test-keepd-3boot.sh
#
# Env overrides:
#   STAGEX_ROOT   (default: the parent of this script's dir)
#   QEMU_DATA_DISK (default: $STAGEX_ROOT/out/data.img)
#   QEMU_MEMORY   (default: 4G)
#   KEEP_BOOT_TIMEOUT_S (default: 600)
#
# Exit 0 on success (all three boots verified via the data disk); non-zero on any
# failure.

set -u

# --- Paths ---
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STAGEX_ROOT=${STAGEX_ROOT:-$(dirname -- "$SCRIPT_DIR")}
OUT_DIR="$STAGEX_ROOT/out"
DATA_DISK=${QEMU_DATA_DISK:-$OUT_DIR/data.img}
WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/keepd-3boot.XXXXXX")
BACKUP_IMG="$WORK_DIR/data.img.bak"
CON_NAME=${QEMU_CONTAINER_NAME:-keepd-3boot-test}
SSH_KEY=${QEMU_SSH_KEY:-$HOME/.ssh/tpm-exploration.pem}
BOOT_TIMEOUT_S=${KEEP_BOOT_TIMEOUT_S:-600}

# The QMP socket (inside the container; reached via `docker exec` + `socat`).
QMP_SOCKET=/run/qemu-qmp.sock

# The PCR policies (the custom LUKS2 JSON field; the state-machine oracle).
SEED_PCRS="5,7"
FULL_PCRS="4,5,7,9"

# The LUKS2 JSON metadata window (offset BIN_HDR_LEN=4096, length JSON_LEN=12288)
# — the keep crate's `luks2` layout. The `pcrs` field is the custom label
# cryptsetup ignores; we read it directly.
JSON_OFF=4096
JSON_LEN=12288

log() { printf '[keepd-3boot] %s\n' "$*"; }
fail() { printf '[keepd-3boot] FAIL: %s\n' "$*" >&2; exit 1; }

# --- Cleanup (clean stop, never rm -f; restore the original data disk) ---
cleanup() {
  status=$?
  log "cleanup: stopping QEMU container (clean stop, not rm -f)"
  docker stop -t 15 "$CON_NAME" >/dev/null 2>&1 || true
  if [ -f "$BACKUP_IMG" ]; then
    log "cleanup: restoring original data disk"
    cp -f "$BACKUP_IMG" "$DATA_DISK" 2>/dev/null || true
  fi
  rm -rf "$WORK_DIR" 2>/dev/null || true
  return $status
}
trap cleanup EXIT INT TERM

# --- QMP helper (reached via `docker exec` + busybox `socat`) ---
#
# The container's busybox `nc` has no `-U` (unix) mode, so we use `socat`
# (present in the image). QMP is QEMU's OWN face (not the guest's), so the
# socket stays up across a `system_reset`; the guest reboots in place.
#
# QMP requires a capabilities handshake BEFORE any command: the server sends a
# greeting, the client must send `{"execute":"qmp_capabilities"}` and receive
# its return, and only then will it accept `system_reset`. A bare
# `system_reset` (no handshake) is refused with `CommandNotFound`. We send both
# commands in one socat session (the `-T 10` total timeout bounds it; the
# greeting + both replies arrive on stdout).
qmp_reset() {
  docker exec "$CON_NAME" sh -c \
    "printf '{\"execute\":\"qmp_capabilities\"}\\n{\"execute\":\"system_reset\"}\\n' | socat -T 10 - UNIX-CONNECT:'$QMP_SOCKET' 2>/dev/null"
}

# wait_console <since-epoch> <marker>: after a (re)boot, wait for the marker to
# appear in `docker logs --since <epoch>` (the logs from THIS boot onward — the
# epoch is captured before the reset, so a stale marker from a prior boot cannot
# satisfy the wait). Bounded.
wait_console() {
  since=$1
  want=$2
  start=$(date +%s)
  while [ $(( $(date +%s) - start )) -lt "$BOOT_TIMEOUT_S" ]; do
    if docker logs --since "$since" "$CON_NAME" 2>&1 | grep -qF "$want"; then
      return 0
    fi
    sleep 3
  done
  fail "console marker not seen within ${BOOT_TIMEOUT_S}s: `$want`"
}

# pcrs_of <disk-img>: the PCR policies on the data disk, one per line (the custom
# `pcrs` JSON field; empty = blank disk / no LUKS header).
pcrs_of() {
  dd if="$1" bs=1 skip="$JSON_OFF" count="$JSON_LEN" 2>/dev/null \
    | tr -d '\0' | grep -aoE '"pcrs":"[0-9,]*"' | grep -aoE '[0-9,]+' || true
}

# luks_uuid_of <disk-img>: the LUKS UUID (blkid; empty = no LUKS header).
luks_uuid_of() {
  blkid -s UUID -o value "$1" 2>/dev/null | head -1 || true
}

# wait_policy <since-epoch> <expected-...>: after the console liveness gate, wait
# for the data disk's PCR policy to settle to the expected set (the keepd's
# LUKS writes are fsync'd, so once the marker is up the policy is durable; a
# short settle covers the in-flight write). Bounded.
wait_policy() {
  since=$1
  shift
  want_count=$1
  shift
  start=$(date +%s)
  while [ $(( $(date +%s) - start )) -lt "$BOOT_TIMEOUT_S" ]; do
    # A short settle: the header write is fsync'd before the daemon's `up` line,
    # but a trailing page-cache flush can lag a beat.
    sleep 2
    got=$(pcrs_of "$DATA_DISK")
    got_count=$(printf '%s\n' "$got" | grep -cE '[0-9]' || true)
    if [ "$got_count" -eq "$want_count" ]; then
      # Every expected policy present, nothing else.
      ok=1
      for w in "$@"; do
        printf '%s\n' "$got" | grep -qxF "$w" || ok=0
      done
      if [ "$ok" = "1" ]; then
        return 0
      fi
    fi
  done
  printf '[keepd-3boot] data-disk policy: got:\n'
  printf '%s\n' "$got" | sed 's/^/[keepd-3boot]   /'
  fail "data-disk PCR policy did not settle to the expected set within ${BOOT_TIMEOUT_S}s (expected: $*)"
}

# --- Pre-flight ---
command -v docker >/dev/null 2>&1 || fail "docker not found"
docker image inspect stagex/service-qemu:local >/dev/null 2>&1 \
  || fail "stagex/service-qemu:local image not built (run the qemu image build first)"
[ -f "$STAGEX_ROOT/out/disk.img" ] || fail "no out/disk.img (run the distro build first)"
[ -f "$SSH_KEY" ] || fail "SSH key not found: $SSH_KEY"
[ -f "$DATA_DISK" ] || fail "data disk not found: $DATA_DISK"
command -v blkid >/dev/null 2>&1 || fail "blkid not found (needed to read the LUKS UUID)"

# Back up the original data disk (the test clobbers it; we restore on exit).
log "backing up original data disk -> $BACKUP_IMG"
cp -f "$DATA_DISK" "$BACKUP_IMG" || fail "backup failed"

# Create a FRESH zeroed data disk (truncate -s 0 then truncate -s 1G).
log "creating fresh zeroed data disk (1G)"
truncate -s 0 "$DATA_DISK" || fail "truncate -s 0 failed"
truncate -s 1G "$DATA_DISK" || fail "truncate -s 1G failed"

# --- QEMU launch (direct; no SSH gate) ---
#
# Replicates the `make qemu-start` docker-run flags (minus the flaky SSH wait).
# The cloud-init config drive is (re)generated from the SSH key (the same box
# step the make target runs), then the QEMU container is launched detached.
launch_qemu() {
  log "generating cloud-init config drive (box)"
  USER_DATA=""
  if [ -f "$SSH_KEY" ]; then
    USER_DATA=$(ssh-keygen -y -f "$SSH_KEY")
  fi
  rm -f "$OUT_DIR/cloud.img"
  docker run --rm --privileged \
    -e "USER_DATA=$USER_DATA" \
    -e "SSH_KEY=$SSH_KEY" \
    -v "$OUT_DIR":/out \
    -v "$STAGEX_ROOT/packages/service/qemu/src/box":/usr/bin/box \
    --entrypoint /bin/sh \
    stagex/service-qemu:local -c 'chmod +x /usr/bin/box && /usr/bin/box' \
    || fail "cloud-init config drive generation failed"
  [ -f "$OUT_DIR/cloud.img" ] || fail "cloud.img was not produced"
  [ -f "$OUT_DIR/cloud-iso.img" ] || fail "cloud-iso.img was not produced"

  # Stop any prior container (clean stop, not rm -f).
  docker stop -t 15 "$CON_NAME" >/dev/null 2>&1 || true
  docker rm "$CON_NAME" >/dev/null 2>&1 || true

  log "launching QEMU (direct; no SSH gate)"
  docker run -d --name "$CON_NAME" --privileged --network host \
    -v "$STAGEX_ROOT/out/disk.img":/input/disk.img \
    -v "$OUT_DIR/cloud.img":/input/cloud.img \
    -v "$OUT_DIR/cloud-iso.img":/input/cloud-iso.img \
    -v "$STAGEX_ROOT/packages/service/qemu/src/qemu-startup.sh":/usr/bin/qemu-startup.sh \
    -e QEMU_MEMORY="${QEMU_MEMORY:-4G}" \
    -e QEMU_DISK=/input/disk.img \
    -e QEMU_CLOUD=/input/cloud.img \
    -e QEMU_CLOUD_ISO=/input/cloud-iso.img \
    -v "$DATA_DISK":/input/data.img -e QEMU_DATA_DISK=/input/data.img \
    --entrypoint /bin/sh \
    stagex/service-qemu:local -c 'chmod +x /usr/bin/qemu-startup.sh && exec /usr/bin/qemu-startup.sh' \
    || fail "docker run (QEMU launch) failed"
}

# wait_guest_up <since-epoch>: the liveness gate — the guest booted, the attest
# gate passed, the keepd derived its secret, and the LUKS volume opened +
# mounted (the kernel's `EXT4-fs (dm-0)` line). Bounded.
wait_guest_up() {
  since=$1
  wait_console "$since" "GATE PASS"
  wait_console "$since" "up (secret derived"
  wait_console "$since" "EXT4-fs (dm-0)"
}

# --- BOOT 1: blank disk -> format (seed PCR policy) ---
log "BOOT 1: launching QEMU with a blank data disk (expect: format under seed policy $SEED_PCRS)"
launch_qemu
SINCE1=$(date +%s)
wait_guest_up "$SINCE1"
log "BOOT 1 liveness OK (guest up, gate passed, volume mounted)"
wait_policy "$SINCE1" 1 "$SEED_PCRS"
log "BOOT 1 OK: data disk PCR policy = $SEED_PCRS (seed only)"

# --- BOOT 2: existing LUKS -> migrate (seed -> full PCR policy) ---
log "BOOT 2: rebooting (expect: migrate seed -> full policy $FULL_PCRS; seed slot deleted)"
SINCE2=$(date +%s)
qmp_reset
wait_guest_up "$SINCE2"
log "BOOT 2 liveness OK"
wait_policy "$SINCE2" 1 "$FULL_PCRS"
# The seed slot must be GONE (the migration deleted it) — the policy set is
# exactly the full policy, so a lingering seed would have failed wait_policy.
log "BOOT 2 OK: data disk PCR policy = $FULL_PCRS (full only; seed $SEED_PCRS deleted)"

# --- BOOT 3: existing LUKS (full) -> clean open (steady state) ---
# The LUKS UUID is captured AFTER boot 2: a steady-state boot must NOT re-format
# (a re-format mints a new UUID). The UUID after boot 3 must be unchanged.
UUID_B2=$(luks_uuid_of "$DATA_DISK")
[ -n "$UUID_B2" ] || fail "no LUKS UUID after boot 2 (expected a LUKS volume)"
log "BOOT 3: rebooting (expect: clean open, steady state; no re-format)"
SINCE3=$(date +%s)
qmp_reset
wait_guest_up "$SINCE3"
log "BOOT 3 liveness OK"
wait_policy "$SINCE3" 1 "$FULL_PCRS"
UUID_B3=$(luks_uuid_of "$DATA_DISK")
[ "$UUID_B3" = "$UUID_B2" ] \
  || fail "boot 3 re-formatted the volume (UUID changed: $UUID_B2 -> $UUID_B3)"
log "BOOT 3 OK: data disk PCR policy = $FULL_PCRS (steady; UUID unchanged $UUID_B3)"

# --- Final summary (the state machine, proven on the data disk) ---
log "SUCCESS: the 3-boot LUKS lifecycle is reproducible on QEMU (verified via the data disk)"
log "  boot 1: blank -> format  -> policy $SEED_PCRS"
log "  boot 2: seeded -> migrate -> policy $FULL_PCRS (seed deleted)"
log "  boot 3: full -> open    -> policy $FULL_PCRS (steady; UUID stable)"
exit 0
