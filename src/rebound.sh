#!/usr/bin/env bash
# rebound.sh — measured-boot re-BOUND automation (wardend security principle 9)
#
# The disk hash is a deterministic function of (commit, dirty): every phase that
# moves the tree (a pin bump, a source change, a patch) must end with a
# re-BOUND (byte-level verification) + attestation PROVEN.
#
# Modes:
#   rebound.sh disk                 CHECK — pass (no-op) when the tree has not
#                                  moved and the disk hash matches the binding;
#                                  FAIL (exit 1) when the tree moved without a
#                                  re-BOUND (stale disk hash) or when the same
#                                  (commit, dirty) produced a different disk
#                                  (non-deterministic build).
#   rebound.sh disk --bind          re-BOUND — (re)record the current
#                                  (commit, dirty) -> disk hash binding. The
#                                  determinism assertion still runs: if the tree
#                                  is unchanged but the disk bytes changed, fail.
#   rebound.sh attest --wire        attestation PROVEN on the deployed EC2
#                                  instance (public IP read from out/aws-ec2.tfvars);
#                                  requires tpm_quote=PROVEN + memory_encryption=PROVEN
#                                  (SEV-SNP host).
#   rebound.sh attest --qemu        attestation PROVEN on the QEMU boot (SSH
#                                  127.0.0.1:2222); requires tpm_quote=PROVEN;
#                                  memory_encryption=NOT PROVEN is expected (no
#                                  SEV-SNP in QEMU).
#   rebound.sh attest --host IP     manual target; add --sev-snp to require
#                                  memory_encryption=PROVEN.
#
# The attestation evidence channel is gate.txt (the seald gate result file,
# bind-mounted at /run/wardend/devices/gate.txt inside the sandbox; readable
# over SSH on both QEMU and the wire). The :443 frame face is the alternate
# channel but its round-trip is still open, so gate.txt is the source of truth.
#
# The binding lives in out/rebound/manifest.txt (gitignored, local state).
#
# Exit codes: 0 = pass (including no-op), 1 = fail, 2 = usage / missing input.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/out/rebound/manifest.txt"
SSH_KEY="${REBOUND_SSH_KEY:-$HOME/.ssh/tpm-exploration.pem}"
ATTEST_TIMEOUT="${REBOUND_ATTEST_TIMEOUT:-600}"   # seconds to wait for the gate
GATE_MAX_AGE="${REBOUND_GATE_MAX_AGE:-1800}"     # gate.txt freshness horizon

die()  { echo "rebound: $*" >&2; exit 1; }
usage() { echo "usage: rebound.sh disk [--bind] | attest --wire | attest --qemu | attest --host IP [--sev-snp]" >&2; exit 2; }

# --- the tree key: (commit, dirty) -------------------------------------------
# dirty = content hash of the build-relevant working-tree state, scoped to the
# paths that actually move the build: packages/ (Containerfiles, package.toml
# pins, gvisor patches), src/ (build scripts), Makefile. The scope EXCLUDES
# local state that is not a build input (.cargo/, scratch/, system, init, and
# the gitignored out/ + fetch/), so a log appended to scratch/ or cargo-cache
# churn does NOT move the tree key (no false STALE). "The tree moved" means a
# pin bump, a source change, or a patch — all of which live under the scope.
# dirty = status + diff (scoped) + the content of untracked build-relevant files.
BUILD_PATHS=(packages/ src/ Makefile package.toml)
tree_key() {
  local commit dirty
  commit="$(git -C "$ROOT" rev-parse HEAD)"
  # cd to $ROOT: the untracked-file paths from `git ls-files` are relative to
  # the repo root, so sha256sum must resolve them from there — not from the
  # caller's CWD (running from /tmp would make them unresolvable and the
  # untracked hash would silently degenerate, moving the tree key).
  dirty="$( cd "$ROOT" && {
    git status --porcelain -- "${BUILD_PATHS[@]}"
    git diff HEAD -- "${BUILD_PATHS[@]}"
    git ls-files -z --others --exclude-standard -- "${BUILD_PATHS[@]}" | xargs -0 -r sha256sum 2>/dev/null
  } | sha256sum | cut -d' ' -f1 )"
  echo "${commit}:${dirty:0:16}"
}

# --- the canonical disk ------------------------------------------------------
# The distro build produces out/rootfs/distro-wardend-dev-img/linux_amd64/disk.img;
# out/disk.img is the copy extracted for the AMI import. The canonical disk is
# the distro-built one (falling back to the extracted copy); when BOTH exist
# they must be byte-identical (what reaches the AMI is the built disk).
BUILT_DISK="$ROOT/out/rootfs/distro-wardend-dev-img/linux_amd64/disk.img"
EXTRACTED_DISK="$ROOT/out/disk.img"
canonical_disk() {
  if [ -f "$BUILT_DISK" ]; then echo "$BUILT_DISK"; return; fi
  if [ -f "$EXTRACTED_DISK" ]; then echo "$EXTRACTED_DISK"; return; fi
  return 1
}

disk_hash_of() { sha256sum "$1" | cut -d' ' -f1; }

manifest_get() { # manifest_get <key>
  [ -f "$MANIFEST" ] || return 0
  sed -n "s/^$1=//p" "$MANIFEST" | head -n1
}

write_manifest() { # write_manifest <tree_key> <disk_hash> <disk_path>
  mkdir -p "$(dirname "$MANIFEST")"
  {
    echo "tree_key=$1"
    echo "disk_hash=$2"
    echo "disk_path=$3"
    echo "bound_at=$(date +%s)"
  } > "$MANIFEST"
}

# --- disk check / re-BOUND ---------------------------------------------------
cmd_disk() {
  local bind=0
  [ "${1:-}" = "--bind" ] && bind=1

  local disk
  disk="$(canonical_disk || true)"
  if [ -z "$disk" ]; then
    echo "rebound: no disk.img built yet — no-op (nothing to bind)"
    exit 0
  fi

  local th dh
  th="$(tree_key)"
  dh="$(disk_hash_of "$disk")"

  # byte-level BOUND: when both the distro-built disk and the extracted
  # out/disk.img exist, they must be identical (what reaches the AMI is the
  # built disk, byte for byte).
  if [ -f "$BUILT_DISK" ] && [ -f "$EXTRACTED_DISK" ]; then
    if [ "$(disk_hash_of "$EXTRACTED_DISK")" != "$dh" ]; then
      die "out/disk.img does not match the distro-built disk (extracted copy is stale; re-run the aws-ami extraction)"
    fi
  fi

  local mtk mdh
  mtk="$(manifest_get tree_key)"
  mdh="$(manifest_get disk_hash)"

  if [ -z "$mtk" ]; then
    write_manifest "$th" "$dh" "$disk"
    echo "rebound: initial binding recorded: tree=$th disk=$dh"
    exit 0
  fi

  if [ "$mtk" = "$th" ]; then
    # same (commit, dirty): the disk bytes must not have changed.
    if [ "$mdh" != "$dh" ]; then
      die "NON-DETERMINISTIC: same (commit, dirty)=$th produced a different disk (bound=$mdh now=$dh)"
    fi
    if [ "$bind" = 1 ]; then
      write_manifest "$th" "$dh" "$disk"
      echo "rebound: re-BOUND ok (tree unchanged, disk identical): tree=$th disk=$dh"
    else
      echo "rebound: BOUND (tree unchanged, disk identical): tree=$th disk=$dh"
    fi
    exit 0
  fi

  # the tree moved since the last binding
  if [ "$bind" = 1 ]; then
    write_manifest "$th" "$dh" "$disk"
    echo "rebound: re-BOUND: tree moved ($mtk -> $th); new binding recorded: disk=$dh"
    exit 0
  fi
  die "STALE: tree moved ($mtk -> $th) but the re-BOUND was not run (disk hash $dh is not bound to the current tree); run 'make rebound-bind' after the rebuild"
}

# --- attestation PROVEN ------------------------------------------------------
fetch_gate() { # fetch_gate <host> <port> -> echoes the last line of gate.txt
  local host=$1 port=$2
  ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
      -o UserKnownHostsFile=/dev/null -i "$SSH_KEY" \
      "root@$host" -p "$port" \
      'tail -n1 /run/wardend/devices/gate.txt 2>/dev/null' 2>/dev/null
}

# --- gate.txt line validation (pure; the unit-testable core) -------------------
# check_gate <line> <sev_snp> — exits 0 only when the line is a fresh, passing
# gate with tpm_quote=PROVEN (and memory_encryption=PROVEN when sev_snp=1).
check_gate() {
  local line=$1 sev_snp=$2
  local epoch verdict
  epoch="$(echo "$line" | awk '{print $1}')"
  verdict="$(echo "$line" | awk '{print $2}')"
  [ "$verdict" = "pass" ] || { echo "GATE FAIL: $line"; return 1; }
  local now=$(( $(date +%s) ))
  [ $(( now - epoch )) -le "$GATE_MAX_AGE" ] || { echo "gate.txt is STALE (age $(( now - epoch ))s > ${GATE_MAX_AGE}s): $line"; return 1; }
  echo "$line" | grep -q 'tpm_quote=PROVEN' || { echo "tpm_quote is not PROVEN: $line"; return 1; }
  if [ "$sev_snp" = 1 ]; then
    echo "$line" | grep -q 'memory_encryption=PROVEN' || { echo "memory_encryption is not PROVEN (SEV-SNP expected): $line"; return 1; }
  fi
  return 0
}

cmd_attest() {
  local host="" port=22 sev_snp=0
  case "${1:-}" in
    --wire)
      local tfvars="$ROOT/out/aws-ec2.tfvars"
      [ -f "$tfvars" ] || { echo "rebound: no out/aws-ec2.tfvars — run 'make aws-ec2-deploy' first" >&2; exit 2; }
      host="$(grep '^public_ip' "$tfvars" | cut -d'"' -f2)"
      [ -n "$host" ] || { echo "rebound: no public_ip in $tfvars" >&2; exit 2; }
      sev_snp=1
      ;;
    --qemu) host=127.0.0.1; port=2222 ;;
    --host)
      [ -n "${2:-}" ] || usage
      host=$2; shift 2
      while [ $# -gt 0 ]; do
        case "$1" in
          --sev-snp) sev_snp=1 ;;
        esac
        shift
      done
      ;;
    *) usage ;;
  esac
  [ -f "$SSH_KEY" ] || { echo "rebound: SSH key $SSH_KEY not found (set REBOUND_SSH_KEY)" >&2; exit 2; }

  echo "rebound: attestation check on $host:$port (sev_snp=$sev_snp; up to ${ATTEST_TIMEOUT}s for the gate)"
  local deadline=$(( $(date +%s) + ATTEST_TIMEOUT ))
  local line=""
  while [ "$(date +%s)" -lt "$deadline" ]; do
    line="$(fetch_gate "$host" "$port" || true)"
    if [ -n "$line" ]; then break; fi
    sleep 10
  done
  [ -n "$line" ] || die "no gate.txt on $host:$port after ${ATTEST_TIMEOUT}s (seald not up, or the face is down)"

  if ! check_gate "$line" "$sev_snp"; then
    die "attestation gate not PROVEN on $host: $line"
  fi
  if [ "$sev_snp" != 1 ]; then
    # QEMU: memory_encryption=NOT PROVEN (degraded) is expected (no SEV-SNP)
    echo "rebound: QEMU mode — memory_encryption degrade is expected (no SEV-SNP)"
  fi

  echo "rebound: ATTESTATION PROVEN on $host: $line"
}

case "${1:-}" in
  disk)    shift; cmd_disk "${1:-}" ;;
  attest)  shift; cmd_attest "$@" ;;
  *)       usage ;;
esac
