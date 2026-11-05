#!/bin/sh
# gvisor-probe.sh — WARDEND-FIDELITY wedge reproduction + forensics (v5).
# Established: Q1 stock runsc boots (rc=0, full flags on create AND start,
# output redirected to FILES). wardend's units all wedge identically:
#   - start client parked in ppoll on the sentry control socket
#   - sentry ALIVE at the 30s deadline, sentry.log EMPTY (log goes to stderr)
#   - wardend SIGQUIT'd the sentry: NO traceback on serial => sentry stderr
#     is the un-drained capture PIPE, not the console.
# wardend's exact argv (from the console WEDGE client argv line):
#   create: root --platform=systrap --overlay2=none --ignore-cgroups
#           --TESTONLY-unsafe-nonroot --debug --alsologtostderr <netflags>
#           --log=... create --bundle ... <unit>   (child fd1/2 = CAPTURE PIPE)
#   start:  root --debug <netflags> start <unit>   (stdout=.start.out,
#           stderr=/dev/console)
# This probe replays BOTH legs exactly, with the capture fifo held on the
# probe shell's fd 3. Leg A never reads fd3 (wardend condition); leg B drains.
# On a wedge: dump the sentry per-thread wchan, SIGQUIT it, THEN read fd3 =>
# the Go goroutine dump lands on the serial console. Decisive:
#   A rc=124 + B rc=0  => capture-pipe wedge CONFIRMED, fix = drain during boot
#   both wedge         => argv-faithful wedge WITHOUT pipe-fill => the dump
#                         names the real internal block
RUNSC=/usr/bin/runsc
exec >/dev/console 2>&1
PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH
say() { echo "PROBE: $*"; }
dump1() { # dump1 label file maxbytes
  [ -f "$2" ] || { say "$1: (absent)"; return; }
  say "$1 [$(wc -c <"$2") bytes]: $(head -c "$3" "$2" | tr '\n' '|')"
}
rm -rf /run/wardend/probe; mkdir -p /run/wardend/probe
# Wardend's own wedged units leave stale sentries that poison pgrep; kill them
# (wardend's respawn loop is starved anyway at this point in boot).
kill -9 $(pgrep -f gvisor_sentry) 2>/dev/null
sleep 1
# wardend's network flags for an offline unit (the .netflags replay):
NET="--network=none --character-device-policy=passthrough"

R=/run/wardend/probe/rootfs; mkdir -p "$R/bin"
cp /bin/busybox "$R/bin/busybox"
printf '#!/bin/busybox sh\necho PROBE_INIT_UP\nsleep 300\n' > "$R/bin/init"
chmod +x "$R/bin/init" "$R/bin/busybox"
# config.json via heredoc (empirically proven in Q1; the long-printf variant
# landed truncated in the guest and produced a spurious FetchSpec failure).
cat > /run/wardend/probe/config.json <<EOCFG
{
  "ociVersion": "1.0.2",
  "process": {"terminal": false, "user": {"uid": 0, "gid": 0},
    "args": ["/bin/init"], "env": ["PATH=/bin:/usr/bin"], "cwd": "/"},
  "root": {"path": "rootfs", "readonly": false},
  "hostname": "probe",
  "mounts": [
    {"destination": "/proc", "type": "proc", "source": "proc"},
    {"destination": "/sys", "type": "sysfs", "source": "sysfs"},
    {"destination": "/dev", "type": "tmpfs", "source": "tmpfs"}
  ],
  "linux": {"namespaces": [{"type": "pid"}, {"type": "network"},
    {"type": "mount"}, {"type": "ipc"}, {"type": "uts"}],
    "capabilities": {"bounding": [], "effective": [], "permitted": [], "inheritable": []},
    "resources": {}}
}
EOCFG

leg() { # leg NAME drain|block
  L=$1; D=$2
  P=/run/wardend/probe/$L; mkdir -p "$P/bundle/rootfs"
  cp /run/wardend/probe/config.json "$P/bundle/config.json"
  mount --rbind "$R" "$P/bundle/rootfs" 2>/dev/null || mount --bind "$R" "$P/bundle/rootfs"
  mkfifo "$P.fifo" 2>/dev/null
  exec 3<>"$P.fifo"          # fd3 = capture pipe, held by THIS shell
  if [ "$D" = drain ]; then
    timeout 70 cat <&3 >"$P/drain.out" 2>/dev/null &
  fi
  # Leg 1: wardend's EXACT create argv; client fd1/2 -> the pipe (dup2 shape).
  timeout 30 "$RUNSC" --root="$P" --platform=systrap --overlay2=none --ignore-cgroups --TESTONLY-unsafe-nonroot --debug --alsologtostderr $NET --log="$P/sentry.log" create --bundle "$P/bundle" c >&3 2>&1
  say "[$L] create rc=$? (output went down the pipe)"
  sleep 1
  # Leg 2: wardend's EXACT start argv (stdout only -> file; stderr -> console).
  timeout 40 "$RUNSC" --root="$P" --debug $NET start c >"$P/start.out"
  SR=$?
  SP=$(pgrep -f gvisor_sentry | tail -1)
  say "[$L] start rc=$SR sentry=${SP:-none} drainbytes=$(wc -c <"$P/drain.out" 2>/dev/null)"
  dump1 "[$L] start.out" "$P/start.out" 400
  if [ "$SR" = 124 ]; then
    for T in /proc/$SP/task/*; do
      say "[$L] thread $T state=$(awk '{print $3}' $T/stat 2>/dev/null) wchan=$(cat $T/wchan 2>/dev/null)"
    done
    kill -QUIT "$SP" 2>/dev/null
    sleep 3
    timeout 3 cat <&3 >"$P/dump.out" 2>/dev/null
    say "[$L] === goroutine dump: $(wc -c <"$P/dump.out") bytes ==="
    head -c 600 "$P/dump.out" | tr '\n' '~'; echo ""
    say "[$L] --- tail ---"
    tail -c 2400 "$P/dump.out" | tr '\n' '~'; echo ""
  fi
  dump1 "[$L] sentry.log" "$P/sentry.log" 300
  kill -9 "$SP" 2>/dev/null
  exec 3>&-
  timeout 10 "$RUNSC" --root="$P" delete --force c >/dev/null 2>&1
  umount -l "$P/bundle/rootfs" 2>/dev/null
  pkill -f "$L/drain.out" 2>/dev/null
}

say "===== LEG A: wardend argv, pipe NOT drained (expect WEDGE if pipe) ====="
leg a block
say "===== LEG B: wardend argv, pipe drained (expect BOOT if pipe) ====="
leg b drain
say "===== PROBE COMPLETE ====="
