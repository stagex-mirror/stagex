#!/usr/bin/env bash
# verify-execd-stack.sh — the QEMU / any-host stack verifier for the shell-free
# execd enclave (Phase 4: nit -> execd PID 1, units lo / dhcp / enclaved /
# sshdt / bootproofd, no dash/ash/brush init, no rcS, no S??*, no .sh at boot).
#
# Usage: bash src/verify-execd-stack.sh <ip> [port]
#   ip    target host (default key: ~/.ssh/tpm-exploration.pem)
#   port  ssh port (default 22; QEMU hostfwd is 2222)
#
# Sections (each prints a PASS line; the first failing section names itself):
#   ssh           ssh reachable
#   zero-shell    no sh/ash/brush/dash, no *.sh running; PID 1 = execd (nit
#                 -> execd line); comm set = {execd, enclaved, sshdt,
#                 bootproofd, dhcp-client} (+ getty-or-none, lo already done);
#                 enclaved single process; sshdt + bootproofd present
#   socket        /run/enclaved/sock mode 600 in a 700 dir; ready file exists
#   face          `bootproof verify <ip> --direct --trust` (host release
#                 build, ~/Sources/bootproof): tpm_quote PROVEN, pcr_state
#                 PROVEN; memory_encryption PROVEN only on SNP hosts
#   luks          data disk attached  -> /home ext4 on /dev/mapper/home
#                 (LABEL=stagex-home); no data disk -> /home on tmpfs
#   dmesg         zero traps / general protection / CFI / UBSAN / BUG lines
#   userdata      /etc/hostname non-empty, /root/.ssh/authorized_keys non-empty
#
# Exit 0 with a final PASS line; nonzero with the failing section named.
set -u

IP="${1:?Usage: bash src/verify-execd-stack.sh <ip> [port]}"
PORT="${2:-22}"
KEY="${TPM_KEY:-$HOME/.ssh/tpm-exploration.pem}"
BOOTPROOF="${BOOTPROOF:-$HOME/Sources/bootproof/target/release/bootproof}"
# LD_LIBRARY_PATH for the host release build (musl libc + libunwind); the
# tss2 stack is dynamic.
BP_LIB="${BP_LIB:-$HOME/pip-live/usr/lib}"

ssh() { /usr/bin/ssh -i "$KEY" -p "$PORT" -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 root@"$IP" "$@"; }

section_fail() { echo "FAIL [$1]: $2" >&2; exit 1; }
section_pass() { echo "PASS [$1]"; }

# ---------------------------------------------------------------- ssh
echo "=== waiting for SSH on $IP:$PORT ==="
UP=0
for i in $(seq 1 60); do
  if ssh 'true' >/dev/null 2>&1; then UP=1; break; fi
  sleep 10
done
[ "$UP" = 1 ] || section_fail ssh "ssh never came up"
section_pass ssh

# ------------------------------------------------------------- zero-shell
echo "=== zero-shell audit ==="
# Busybox ps -eo pid,comm,args: pid comm args... (comm is the truncated
# command name — the load-bearing field for the zero-shell audit).
PS_OUT=$(ssh 'ps -eo pid,comm,args 2>/dev/null')
[ -n "$PS_OUT" ] || section_fail zero-shell "guest 'ps -eo pid,comm,args' returned nothing"
echo "$PS_OUT"

# No shells or shell scripts running (exclude this audit's own sshd command
# line, which carries the script text, and the ps process itself).
SHELL_HITS=$(echo "$PS_OUT" | grep -vE "^\s*$" \
  | grep -vE "ps -eo pid,comm,args|ps aux" \
  | grep -E "(^|[^[:alnum:]_.-])(sh|ash|brush|dash|busybox)([^[:alnum:]_.-]|$)|\.sh( |$)" \
  || true)
if [ -n "$SHELL_HITS" ]; then
  section_fail zero-shell "shell or *.sh process running:
$SHELL_HITS"
fi

# PID 1 = execd (nit execs it; after the execve PID 1's comm is execd).
P1COMM=$(echo "$PS_OUT" | awk '$1 == 1 {print $2; exit}')
[ "$P1COMM" = "execd" ] || section_fail zero-shell "PID 1 comm is '$P1COMM', expected execd"

# Exact expected comm set: execd, enclaved, sshdt, bootproofd, dhcp-client
# (+ getty-or-none; lo is a oneshot ip applet that exits).
COMM_SET=$(echo "$PS_OUT" | awk 'NR>1 {print $2}' | sort -u | tr '\n' ' ')
echo "comms: $COMM_SET"
for c in execd enclaved sshdt bootproofd dhcp-client; do
  echo "$COMM_SET" | grep -qw "$c" || section_fail zero-shell "expected comm '$c' missing"
done
# No getty unit in the execd stack; if one is present, name it (informational).
echo "$COMM_SET" | grep -qw getty && echo "(note: getty present — not expected in the execd unit set)"

# enclaved: single process, NO RESTART by design (a respawn would double-
# extend PCR 11 and break the verifier's replay).
ENCLAVED_N=$(echo "$PS_OUT" | grep -w enclaved | grep -vE "grep|ps " | wc -l)
[ "$ENCLAVED_N" = "1" ] || section_fail zero-shell "enclaved process count is $ENCLAVED_N, expected exactly 1 (no-restart)"
section_pass zero-shell

# --------------------------------------------------------------- socket
echo "=== socket contract ==="
SOCK=$(ssh 'stat -c "%a %F" /run/enclaved/sock 2>/dev/null')
[ -n "$SOCK" ] || section_fail socket "/run/enclaved/sock missing"
echo "$SOCK" | grep -qE "^600 " || section_fail socket "sock mode is '$(echo "$SOCK" | cut -d" " -f1)', expected 600"
DIRMODE=$(ssh 'stat -c "%a" /run/enclaved 2>/dev/null')
[ "$DIRMODE" = "700" ] || section_fail socket "/run/enclaved dir mode is '$DIRMODE', expected 700"
ssh 'test -e /run/enclaved/ready' || section_fail socket "/run/enclaved/ready missing (enclaved not ready)"
section_pass socket

# ------------------------------------------------------------------ face
echo "=== bootproofd face (bootproof verify --direct --trust) ==="
if [ ! -x "$BOOTPROOF" ]; then
  section_fail face "bootproof client not found: $BOOTPROOF"
fi
# The client pins each target's daemon pubkey (TOFU + --pin: drift is a
# HARD failure). On AWS the identity lives on the persistent EBS /home, so
# the pin is stable and continuity is checked. On QEMU the identity is
# generated under the LUKS /home (or /root tmpfs), so it ROTATES whenever
# that storage is recreated — clear the localhost pin first so the verifier
# re-pins the current identity instead of false-failing on a legitimate
# rotation. Real targets keep their pins (a drift there is a signal).
PINFILE="$HOME/.config/bootproof/pins.json"
if [ "$IP" = "localhost" ] && [ -f "$PINFILE" ]; then
  python3 - "$PINFILE" <<'PY'
import json, sys
path = sys.argv[1]
d = json.load(open(path))
pins = d.get("pins", {})
removed = [k for k in list(pins) if k.split(":")[0] in ("localhost", "127.0.0.1")]
for k in removed:
    del pins[k]
json.dump(d, open(path, "w"), indent=2, sort_keys=True)
print(f"(cleared {len(removed)} stale localhost pin(s) — QEMU identity rotation)")
PY
fi
BP_OUT=$(env LD_LIBRARY_PATH="$BP_LIB" \
  "$BOOTPROOF" verify "$IP" --direct --trust --pin 2>&1)
echo "$BP_OUT" | grep -E "FACT|PROVEN|NOT PROVEN|error|Error" || echo "(no fact lines captured)"
# The client can exit nonzero on a NOT PROVEN row; judge from the table, not
# the rc. "NOT PROVEN" contains "PROVEN" as a substring — exclude it explicitly.
grep -E "^tpm_quote\s" <<<"$BP_OUT" | grep -v "NOT PROVEN" | grep -q "PROVEN" || \
  section_fail face "tpm_quote not PROVEN"
grep -E "^pcr_state\s" <<<"$BP_OUT" | grep -v "NOT PROVEN" | grep -q "PROVEN" || \
  section_fail face "pcr_state not PROVEN"
# memory_encryption: PROVEN only on SNP hosts. QEMU (swtpm, no /dev/sev-guest)
# reports NOT PROVEN with a reason — that is the CORRECT honest state.
ME=$(grep -E "^memory_encryption\s" <<<"$BP_OUT" || true)
if echo "$ME" | grep -v "NOT PROVEN" | grep -q "PROVEN"; then
  echo "memory_encryption PROVEN (SNP host)"
else
  echo "memory_encryption NOT PROVEN (no SNP channel — correct on QEMU swtpm)"
fi
section_pass face

# ------------------------------------------------------------------ luks
echo "=== LUKS /home ==="
HOMEFS=$(ssh 'stat -f -c %T /home 2>/dev/null')
HOMEMNT=$(ssh 'mount | grep -E " /home " || true')
echo "fstype: $HOMEFS"
echo "$HOMEMNT"
case "$HOMEFS" in
  ext2/ext3|ext4)
    # stat -f %T reports "ext2/ext3" for ext4 volumes.
    echo "data disk attached — expecting ext4 on /dev/mapper/home, LUKS LABEL=stagex-home"
    echo "$HOMEMNT" | grep -q "/dev/mapper/home" || \
      section_fail luks "/home is ext4 but not on /dev/mapper/home: $HOMEMNT"
    # The LUKS label (stagex-home) lives in the LUKS2 header on the backing
    # whole disk; /dev/mapper/home is the UNCRYPTED device, whose LABEL is
    # the ext4 label (home). Find the backing disk: the whole block device
    # that is not the root disk.
    LUKS_LABEL=$(ssh '
      root=$(awk "\$2==\"/\" {print \\$1; exit}" /proc/mounts)
      for d in /sys/block/*; do
        n=$(basename $d)
        case $n in loop*|ram*|zram*|sr*|dm-*) continue;; esac
        [ -e $d/size ] || continue
        whole=$n
        case $n in nvme*) whole=$(echo $n | sed -E "s/p[0-9]+$//");;
                   sd*|hd*|vd*) whole=$(echo $n | sed -E "s/[0-9]+$//");; esac
        [ "$whole" = "$(basename $(echo $root | sed -E "s/\\//; s/p[0-9]+$//; s/[0-9]+$//"))" ] && continue
        l=$(blkid -s LABEL -o value /dev/$n 2>/dev/null)
        [ -n "$l" ] && { echo $l; break; }
      done' 2>/dev/null)
    [ "$LUKS_LABEL" = "stagex-home" ] || section_fail luks "LUKS LABEL on backing disk is '$LUKS_LABEL', expected stagex-home"
    ;;
  tmpfs)
    echo "no data disk — /home on tmpfs is the correct fail-soft state"
    ;;
  *)
    section_fail luks "/home fstype is '$HOMEFS', expected ext4 (data disk) or tmpfs (none)"
    ;;
esac
section_pass luks

# ----------------------------------------------------------------- dmesg
echo "=== dmesg ==="
TRAPS=$(ssh 'dmesg | grep -iE "trap|general protection|CFI: (violation|bad)|UBSAN|BUG:" | grep -v "report a bug" || true')
if [ -n "$TRAPS" ]; then
  section_fail dmesg "traps/CFI/UBSAN/BUG lines:
$TRAPS"
fi
section_pass dmesg

# --------------------------------------------------------------- userdata
echo "=== userdata ==="
# /etc is the read-only erofs root, so /etc/hostname is NOT a reliable
# artifact: enclaved applies the hostname via sethostname(2) and keeps the
# raw blob at /run/userdata (writable tmpfs). Check the live hostname and
# the retained blob, not the RO file.
RUNHOST=$(ssh 'hostname 2>/dev/null')
[ -n "$RUNHOST" ] || section_fail userdata "live hostname (sethostname) empty"
UDLEN=$(ssh 'wc -c < /run/userdata 2>/dev/null | tr -d " "' || echo 0)
[ "${UDLEN:-0}" -ge 1 ] 2>/dev/null || section_fail userdata "/run/userdata blob missing (enclaved userdata leg did not run)"
# The first line of the blob should be the hostname it applied.
BLOBHN=$(ssh 'head -1 /run/userdata 2>/dev/null')
[ "$BLOBHN" = "$RUNHOST" ] || echo "(note: blob first line '$BLOBHN' != live hostname '$RUNHOST' — acceptable if the key line leads the blob)"
AKS=$(ssh 'wc -l < /root/.ssh/authorized_keys 2>/dev/null | tr -d " "' || echo 0)
[ "${AKS:-0}" -ge 1 ] 2>/dev/null || section_fail userdata "/root/.ssh/authorized_keys empty (sshdt when-gate would fail-close; ssh is up so the key must exist)"
section_pass userdata

# ------------------------------------------------------------------ done
echo "=================================================="
echo "PASS: execd stack verified on $IP:$PORT"
echo "=================================================="
exit 0
