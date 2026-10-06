#!/bin/sh
# sysnet-watchdog.sh — v13-supervisor (Oct 6 wire): the INDEPENDENT
# last-resort recovery for the sys-net face.
#
# THE INCIDENT THIS EXISTS FOR: on the v12 instance i-0e5a6d710e6bcc45e the
# sysnet supervisor loop (sysnet.sh) wedged ~14.5 h BEFORE the netstack went
# terminally dark (NetworkOut -> 0, face :443/:22 dark). The v8/v9 recovery
# chain (dp-dark >= 120 s -> sandbox respawn; dark into the next generation
# -> full guest reboot via `reboot -f`) is verified present in the image —
# but it runs INSIDE the wedged loop, so when the netstack finally darked
# there was no live process left to execute it. 45+ minutes dark, no
# recovery, CPU flat, until a manual `aws ec2 reboot-instances`.
#
# THE FIX (split recovery from supervision): the sysnet.sh main loop keeps
# its rich work (runsc liveness, teardown, cheap respawn, BPF counters,
# serial diagnostics) and stamps a heartbeat file each iteration. THIS
# script is a SEPARATE execd unit (sysnet-watchdog) that owns the reboot. It
# reads exactly TWO files and calls `reboot -f`:
#   /run/sysnet/dp  — dpmon's data-plane status ("<epoch> pass|fail"),
#                     written inside the sandbox (independent of the
#                     supervisor), bind-mounted to the kernel;
#   /run/sysnet/hb  — the supervisor loop's heartbeat (epoch), stamped at
#                     the top of every main-loop iteration.
# No runsc, no pgrep, no bpf(2), no serial writes, no wait on any child:
# there is nothing here that can wedge the way the main loop did. If the
# supervisor wedges, $hb goes stale and the watchdog reboots the guest
# INDEPENDENTLY. If the netstack goes terminally dark (dp stale/fail), the
# watchdog reboots even if the supervisor's own escalation somehow does not
# run.
#
# RELATIONSHIP TO THE v8/v9 CHAIN (complementary, not redundant): the
# supervisor's DP_LIMIT=24 (120 s) still does the CHEAP recovery (sandbox
# teardown + execd respawn, no reboot) for process-level deaths and
# self-recovering transients — that is strictly cheaper than a guest reset
# and stays. The watchdog fires at a LATER horizon (dp dark >= 360 s, or
# hb stale >= 600 s): above the worst-case cost of one full cheap-respawn
# cycle (~260 s: 120 s detection + ~10 s teardown + ~90-120 s pre-loop +
# DORA), so a healthy respawn never pays the reboot; far below the terminal
# dark (which persisted 45 min to 23 h across the wire incidents). When the
# supervisor is alive it usually reaches its own esc>=2 `reboot -f` first
# (~390 s of dark); when the supervisor is wedged, THIS is the recovery.
#
# ARMED MODEL (same discipline as v9): the watchdog only fires after it has
# itself observed a FRESH dp "pass" (egress working) since its own start,
# plus a 600 s boot grace. A broken-from-boot generation (no lease, no
# egress) must not accumulate toward a reboot storm — the supervisor's
# DPBOOT=300 s boot deadline owns that path. A fresh pass ALSO clears the
# reboot-loop guard (a healthy period is exactly what it counts the absence
# of).
#
# REBOOT-LOOP GUARD: /home/sysnet-wd-overflow (persistent across reboots:
# LUKS /home on AWS, tmpfs on QEMU) counts consecutive reboots fired by THIS
# watchdog with no healthy dp pass in between. After 3, STOP rebooting
# (a guest reset every ~4 min, wiping LUKS/NitroTPM sessions, is a worse
# liveness failure than a stable dark) and stay dark with a loud, persistent
# alarm. Firing reboots spend guard budget (the safe direction); any later
# healthy pass clears it and normal operation resumes.
#
# POSIX sh (the guest /bin/sh is brush): no arrays, no `wait <pid>`, no $!,
# no process children at all — the loop body is date/read/test/sleep/file
# writes only.

DPF=/run/sysnet/dp
HB=/run/sysnet/hb
WDF=/run/sysnet/watchdog.log
PLOG=/home/sysnet-events.log
WDOVR=/home/sysnet-wd-overflow

WD_HB_STALE=${WD_HB_STALE:-600}  # supervisor heartbeat older than this = the
                  # loop is dead (loop period ~5-30 s incl. bounded children;
                  # 600 s is ~20x the worst-case iteration and above the whole
                  # pre-loop setup of a fresh generation, ~180 s). Env
                  # overridable (QEMU test uses a short horizon).
WD_DARK=${WD_DARK:-540}       # seconds of continuous data-plane dark (armed)
                  # -> reboot. MUST stay above the worst case of the
                  # supervisor's CHEAP respawn cycle so a healthy respawn
                  # never pays the reboot: 120 s (DP_LIMIT detection) + ~10 s
                  # teardown + ~120-150 s fresh-gen pre-loop (ethtool/
                  # link-back/bundle/create/start) + DORA to first fresh pass
                  # (~30-60 s) = ~390 s. 540 s is +150 s over that. Far below
                  # any terminal dark (45 min to 23 h across the wire
                  # incidents). When the supervisor is alive its own esc>=2
                  # reboot (~470 s) usually lands first; when the supervisor
                  # is wedged, THIS is the recovery. Env overridable.
WD_STALE=${WD_STALE:-30}      # a dp file older than 30 s = not a fresh pass
                  # (3 missed 10 s dpmon probes) — same constant as the
                  # supervisor
WD_BOOT_GRACE=${WD_BOOT_GRACE:-600} # no firing in the first 600 s after THIS
                  # process starts (env overridable for QEMU test)
WDOVR_LIMIT=${WDOVR_LIMIT:-3} # consecutive watchdog reboots without a healthy
                  # period

log() {
  echo "watchdog: $*" >> "$WDF" 2>/dev/null || true
  echo "watchdog: $*" >> "$PLOG" 2>/dev/null || true
}

WSTART=$(date -u +%s)
WDHAVEN=0
DPDARK=0
log "start pid $$ wdstart=$WSTART hb-stale=$WD_HB_STALE dark=$WD_DARK"

while :; do
  now=$(date -u +%s)

  # boot grace: give the whole system (supervisor pre-loop + DORA) room
  [ $(( now - WSTART )) -ge "$WD_BOOT_GRACE" ] || { sleep 10; continue; }

  # --- data-plane state (dpmon file; written in the sandbox, not by the
  # supervisor) -------------------------------------------------------------
  dp_fresh=0
  dp_e=""; dp_st=""
  [ -s "$DPF" ] && read -r dp_e dp_st < "$DPF" 2>/dev/null
  case "$dp_e" in
    ''|*[!0-9]*) : ;;
    *)
      [ "$dp_st" = "pass" ] && [ $(( now - dp_e )) -le "$WD_STALE" ] && dp_fresh=1
      ;;
  esac
  if [ "$dp_fresh" -eq 1 ]; then
    [ "$WDHAVEN" -eq 0 ] && log "armed (first fresh dp pass; now=$now)"
    WDHAVEN=1
    DPDARK=0
    if [ -f "$WDOVR" ]; then
      rm -f "$WDOVR" 2>/dev/null || true
      log "reboot-loop guard cleared (healthy dp pass)"
    fi
  elif [ "$WDHAVEN" -eq 1 ]; then
    # armed + no fresh pass: accumulate continuous dark (10 s loop period)
    DPDARK=$(( DPDARK + 10 ))
  fi

  # --- supervisor heartbeat (MUST be checked even when dp is fresh: the
  # Oct 6 wedge had a healthy netstack serving :443 with a dead supervisor —
  # dp stays "pass" while hb goes stale; the two signals are independent) --
  hb_age=999999
  hb_e=$(cat "$HB" 2>/dev/null)
  case "$hb_e" in
    ''|*[!0-9]*) : ;;
    *)
      hb_age=$(( now - hb_e ))
      [ "$hb_age" -lt 0 ] && hb_age=999999
      ;;
  esac

  # --- fire decision (armed only; the two triggers are independent) -------
  fire=""
  [ "$WDHAVEN" -eq 1 ] && [ "$DPDARK" -ge "$WD_DARK" ] && \
    fire="data plane dark ${DPDARK}s (dp: $(cat "$DPF" 2>/dev/null))"
  [ -z "$fire" ] && [ "$WDHAVEN" -eq 1 ] && [ "$hb_age" -ge "$WD_HB_STALE" ] && \
    fire="supervisor heartbeat stale ${hb_age}s (hb: ${hb_e:-absent})"
  [ -n "$fire" ] || { sleep 10; continue; }

  # --- reboot-loop guard ----------------------------------------------------
  ovr=0
  o=$(cat "$WDOVR" 2>/dev/null)
  case "$o" in ''|*[!0-9]*) : ;; *) ovr=$o ;; esac
  if [ $(( ovr + 1 )) -gt "$WDOVR_LIMIT" ]; then
    log "ALARM reboot-loop guard: $(( ovr + 1 )) consecutive reboots without a healthy period ($fire): NOT rebooting (staying dark + alarm)"
    DPDARK=0
    sleep 30
    continue
  fi
  echo $(( ovr + 1 )) > "$WDOVR" 2>/dev/null || true
  log "FIRING: $fire -> FULL GUEST REBOOT (wd ovr=$(( ovr + 1 ))/$WDOVR_LIMIT)"
  sync 2>/dev/null || true
  # reboot -f = the reboot(2) syscall (RB_FORCE): bypasses init/nit/execd,
  # resets the guest (the supervisor runs root in the init ns; this unit
  # does too), clearing the kernel-side NIC/AF_XDP/ENI state a sandbox
  # respawn cannot reach.
  reboot -f 2>/dev/null || log "reboot -f FAILED (rc=$?): backing off"
  sleep 30
done
