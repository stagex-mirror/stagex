#!/bin/sh
# provision — run enclavectl provision in a gVisor sandbox, after enclaved
# is up. The provisioned result lands in the daemon's drop file via the
# shared /run/enclaved volume.
#
# RUNSC FORM (oracle-proven in-guest): --root / (default) +
# --force-overlay=false + the /run/enclaved volume bridge.
#
# Two oracle rounds settled each flag:
#   (1) A staged-subdir --root + --force-overlay=false SIGSEGVs the sentry
#       (rc 139/128) for any payload, while --root / works for both static
#       and dynamic payloads. So there is NO staging: the payload resolves
#       its PT_INTERP and NEEDED libs against the real /.
#   (2) With the DEFAULT CoW overlay, the sandbox's write of /run/enclaved/drop
#       never reaches the host (the daemon never sees the file; the provision
#       reports "drop: absent" host-side). Only with --force-overlay=false
#       does the drop file land on the host. So overlay=false is REQUIRED by
#       the design, not a workaround.
#
# Isolation note (deliberate, documented): --force-overlay=false gives the
# sandbox write access to the host root filesystem (do.go WARNING). The
# security boundary is NOT the filesystem overlay — it is gVisor itself
# (sentry + kernel seccomp), plus the daemon's distrust model: every blob
# crosses via the 0700 /run/enclaved dir, and the daemon RE-VERIFIES
# everything from the content-addressed store (measure-before-apply,
# PCR11 golden pin) before applying anything. The sandbox is untrusted code
# either way; the overlay would only have hidden its writes from us, which
# is exactly what broke the evidence channel.
#
# FAIL-OPEN: this script ALWAYS exits 0. Every failure is logged to stderr
# (which execd forwards to the serial console) and swallowed — provisioning
# is best-effort and must never stall the execd DAG or wedge the box.
#
# brush-compatible by construction: /bin/sh in the guest is brush. No
# background jobs, no `wait`.
set -u

DROP=/run/enclaved/drop

log() {
  printf 'provision: %s\n' "$*" >&2
}

# The shared evidence volume: /run/enclaved is owned by enclaved on the host.
# It must exist before runsc bind-mounts it (it does — enclaved created it
# before this unit started). Nothing to stage.

# The locked, oracle-proven invocation: --root / (default), overlay=none
# (required: with the default all:memory overlay the drop write is trapped
# in RAM and never reaches the host — see the header note), /run/enclaved
# volume bridge. enclavectl provision reads the daemon's evidence socket +
# userdata.seed through /run/enclaved and writes the provisioned result to
# /run/enclaved/drop.
runsc --ignore-cgroups do --cwd / --force-overlay=false \
  --volume /run/enclaved:/run/enclaved /usr/bin/enclavectl provision
rc=$?
log "runsc: exit $rc"

# --- leak cleanup ----------------------------------------------------------
# `runsc do` removes its veth pair (ve-<cid>/vp-<cid>, cid = runsc-%06d,
# unique per invocation) on the happy path. The janitor is scoped to this
# invocation's OWN subnet (the default 192.168.10.x, which no other unit
# uses — the bootproofd sandbox runs 192.168.11.x): a broad ve-*/vp-* sweep
# would tear the LIVE bootproofd sandbox veth out from under it.
for veth in $(ip -4 link show 2>/dev/null | grep -Eo 've-[0-9a-f]+|vp-[0-9a-f]+' | sort -u); do
  if ip -4 -o addr show dev "$veth" 2>/dev/null | grep -q '192\.168\.10\.'; then
    log "cleanup: removing leaked veth $veth"
    ip link del "$veth" 2>/dev/null || log "cleanup: ip link del $veth failed"
  fi
done

# --- final: drop file for the daemon ---------------------------------------
if [ -e "$DROP" ]; then
  size=$(wc -c < "$DROP" 2>/dev/null)
  log "drop: present, size ${size:-unknown} bytes"
else
  log "drop: absent (enclaved will see nothing to consume)"
fi

exit 0
