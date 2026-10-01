#!/bin/sh
# bootproofd witness (sn-7 / S3).
#
# bootproofd itself no longer runs here. The kernel is FULLY offline: the
# sn-6 model (bootproofd in its own `runsc do` sandbox + kernel DNAT of
# eth0:443) is impossible by construction — the wire never reaches the
# kernel netns, and the kernel has no default route to DNAT through.
#
# Instead bootproofd runs as a CO-TENANT inside the sysnet sandbox (the
# netstack is the only network face): the wire :443 arrives on eth0, the
# redirect program sends it to the netstack, and bootproofd binds
# 0.0.0.0:443 there — exactly like sshdt:22. /run/enclaved (evidence
# socket) and /home/bootproof (TLS identity) are bound into that sandbox;
# the sysnet payload owns the process (a backgrounded restart loop, so a
# dead face respawns without taking :22 down).
#
# THIS unit is the witness: it waits for the face to come up and then
# holds while it is alive. Health signal for execd = the witness being up.
# It checks via `runsc exec` (the runsc unix-socket API, not the network —
# works with the kernel offline): the process is running AND :443 answers
# on the netstack loopback. 3 consecutive failures -> exit 1 -> execd
# respawns the witness (the sysnet supervisor owns the actual recovery).
#
# Shell discipline: /bin/sh here is brush (no `wait <pid>`); this script
# runs no background jobs.

log() { echo "bootproofd-witness: $*" >&2; }
fail() { log "$*"; exit 1; }

RUNSC=/usr/bin/runsc
STATE=/run/sysnet/runsc
CID=sysnet

[ -x "$RUNSC" ] || fail "runsc missing at $RUNSC"

face_up() {
  "$RUNSC" --root="$STATE" --overlay2=none --ignore-cgroups exec "$CID" \
    /bin/busybox pgrep -x bootproofd >/dev/null 2>&1 || return 1
  "$RUNSC" --root="$STATE" --overlay2=none --ignore-cgroups exec "$CID" \
    /bin/busybox nc -z -w 3 127.0.0.1 443 >/dev/null 2>&1
}

# (1) Wait for the face (bounded). The sysnet sandbox starts in the same
# wave as enclaved; bootproofd inside it retries until the evidence socket
# exists, so this converges.
i=0
while ! face_up; do
  i=$((i + 1))
  if [ "$i" -ge 300 ]; then
    fail "bootproofd :443 face not up in the sysnet sandbox after 300 s (respawn and retry)"
  fi
  sleep 1
done
log "bootproofd :443 face up in the sysnet sandbox (co-tenant of the netstack)"

# (2) Witness loop: hold while the face is alive. 3 consecutive failures ->
# exit 1 -> execd respawns (the sysnet supervisor does the real recovery:
# teardown + redirect re-arm + re-DORA + bootproofd restart loop).
FAIL=0
while :; do
  sleep 30
  if face_up; then
    FAIL=0
  else
    FAIL=$((FAIL + 1))
    if [ "$FAIL" -ge 3 ]; then
      fail "bootproofd :443 face down (3 consecutive failed checks; sysnet supervisor owns recovery)"
    fi
  fi
done
