#!/bin/sh
# sysnet.sh — guest supervisor for the Qubes "sys-net" model, sn-6 FULL NIC
# ownership, on the go-branch gVisor build (3-patch runsc: xdp-1..3 in
# packages/user/gvisor).
#
# The execd unit `sysnet` (restart="always") runs THIS wrapper. It brings a
# gVisor sandbox up that owns the guest NIC's data plane via an AF_XDP
# redirect:
#
#   xdp_loader redirect -device <uplink>   (load + pin program/sockmap/link)
#   runsc create+start --EXPERIMENTAL-xdp=redirect:<uplink>
#
# The redirect_host XDP program sits on the uplink itself: XDP_PASSes tcp/22
# to the kernel stack (SSH stays reachable) and diverts every other class via
# bpf_redirect_map(sock_map) into the sandbox's sentry netstack. The sandbox
# netstack sources the guest's REAL lease address (the sentry scrapes the
# uplink's addr + routes + ARP at start), so its egress needs no NAT and is
# indistinguishable from guest traffic on the wire. There is no private netns,
# no veth, no holder: the sandbox IS the guest's egress point.
#
# WHY THIS WORKS (live-proven in-guest, 2026-09-29, QEMU booted disk):
#   xdp-2 (sentry-side): SetNetworkArgs configures XDP-redirect networks
#   SYNCHRONOUSLY (state=created) so the sentry's AF_XDP socket has its RX
#   ring before runsc's client inserts it into the pinned sockmap (the kernel
#   xskmap rejects an insert on a socket without an RX ring: -ENOBUFS). The
#   green run: create rc=0, start rc=0, in-sandbox probes to the SLIRP GW
#   (10.0.2.2:22) and the public internet (8.8.8.8:443) both PASS while this
#   SSH session stayed connected (the tcp/22 pass class), teardown restored
#   guest egress, 0 traps/#GP/CFI/UBSAN in dmesg.
#
# BUNDLE ROOTFS MECHANISM (the P4 rule, applied):
#   The booted rootfs is read-only erofs; a missing gofer bind target makes
#   the gofer O_CREAT a nonexistent path and die ("cannot read client sync
#   file: EOF"). The bundle is MINIMAL: busybox (static) + the three gofer
#   bind targets copied from the guest's /, plus the payload script.
#   --overlay2=none: the sentry reads bundle files straight off the
#   /run/sysnet filestore (no CoW, no copy of /).
#
# FLAGS (each load-bearing):
#   --network=sandbox : the real sentry netstack (runsc's default; stated
#     explicitly).
#   --TESTONLY-unsafe-nonroot : directfs wants a user namespace; the
#     hardened kernel has CONFIG_USER_NS off.
#   --overlay2=none, --ignore-cgroups : see the P4 record (erofs direct read;
#     nit's init leaves cgroup v2 with zero controllers).
#   PATH export : runsc inherits the unit env (NO PATH); /usr/sbin (iproute2)
#     must lead so setupNet's `ip` is not busybox.
#
# WEDGE (the one real foot-gun, accepted risk pending sn-6e route-flip agent):
#   the program sits on the uplink. If the sandbox dies before teardown, the
#   redirect class (everything non-tcp/22) drops — guest egress is dark
#   EXCEPT SSH (the tcp/22 pass class keeps the kernel stack). The liveness
#   monitor (3 consecutive failed polls) exits non-zero -> teardown detaches
#   the program + unbinds the pins -> execd respawns. Recovery is bounded
#   (~3 x 5 s poll + teardown).
#
# Shell discipline: /bin/sh here is brush — `wait <pid>` is unimplemented.
# This script backgrounds nothing; it polls `runsc list` for liveness.
set -u

DEV=""                       # the uplink (default-route device, set in 1)
CID=sysnet
RUNSC=/usr/bin/runsc
LOADER=/usr/bin/xdp_loader
STATE=/run/sysnet/runsc
B=/run/sysnet/bundle
PIN=""                       # /sys/fs/bpf/$DEV — derived in section 1 AFTER
                             # DEV is known (top-level $DEV expansion is empty)
LINK_WAIT=60                 # bounded wait for the uplink lease (dhcp unit)
SBX_WAIT=90                  # bounded wait for the sandbox to reach running

log()  { echo "sysnet: $*" >&2; }
fail() { log "$*"; exit 1; }

# --- teardown (execd restarts us on non-zero exit) ----------------------------
teardown() {
  # kill the sentry by exact PID first (a dead sandbox's sentry survives
  # `runsc delete`; killing it releases the AF_XDP bind so a respawn re-bind
  # never hits EBUSY). runsc list column 2 is the PID.
  "$RUNSC" --root="$STATE" --overlay2=none --ignore-cgroups list 2>/dev/null \
    | awk -v id="$CID" '$1==id{print $2}' | while read -r p; do
      [ -n "$p" ] && kill -9 "$p" 2>/dev/null || true
    done
  "$RUNSC" --root="$STATE" --overlay2=none --ignore-cgroups delete -f "$CID" \
    2>/dev/null || true
  # detach + unpin BEFORE anything else: a pinned program with an empty
  # socket map drops the redirect class (the wedge).
  if [ -n "$DEV" ]; then
    ip xdp off dev "$DEV" 2>/dev/null || true
  fi
  rm -f "$PIN/redirect_ip_map" "$PIN/redirect_program" "$PIN/redirect_link" 2>/dev/null || true
  rmdir "$PIN" 2>/dev/null || true
  # runsc also creates a per-sandbox netns named runsc-<sandbox PID> (the PID
  # is unpredictable). Identify OURS by the state root in the runsc process
  # cmdline: kill its pids, then del. Never touches other sandboxes' runsc
  # netns (e.g. bootproofd's).
  for p in $(pgrep -x runsc 2>/dev/null); do
    if tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | grep -q "$STATE"; then
      kill -9 "$p" 2>/dev/null || true
    fi
  done
  sleep 0.3
  for ns in $(ip netns list 2>/dev/null | awk '$1 ~ /^runsc-[0-9]+$/{print $1}'); do
    held=0
    for p in $(ip netns pids "$ns" 2>/dev/null); do
      if tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | grep -q "$STATE"; then held=1; fi
    done
    [ "$held" -eq 1 ] && { kill -9 $(ip netns pids "$ns" 2>/dev/null) 2>/dev/null; sleep 0.2; ip netns del "$ns" 2>/dev/null || true; }
  done
  log "teardown done"
}
trap teardown EXIT
# signal-driven teardown: brush's EXIT-trap-on-signal behavior is not relied
# on. The teardown is idempotent (every step || true / re-checks).
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

# --- 0. preconditions ----------------------------------------------------------
[ -x "$RUNSC" ] || fail "runsc missing at $RUNSC"
[ -x "$LOADER" ] || fail "xdp_loader missing at $LOADER"
[ -x /usr/sbin/ip ] || fail "iproute2 ip missing (libelf?)"
mountpoint -q /sys/fs/bpf || mount -t bpf bpf /sys/fs/bpf 2>/dev/null || true
mountpoint -q /sys/fs/bpf || fail "bpffs unavailable (no /sys/fs/bpf mount)"
mkdir -p "$STATE" "$B/rootfs" || fail "mkdir run state failed"
# PATH for runsc (and its child sentry): /usr/sbin (iproute2) must lead.
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

# --- 1. wait for the egress device (bounded) -----------------------------------
# The dhcp unit owns the real NIC. The redirect program needs an up with the
# lease (the sentry scrapes the uplink's addr/routes at start). Bounded wait;
# on timeout exit NON-ZERO so the unit respawns and retries (the lease arrives
# seconds after boot).
find_egress() {
  ip route list default 2>/dev/null | head -1 | awk '{print $5}'
  ip route get 8.8.8.8 2>/dev/null | awk '/ dev /{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1); exit}'
}
i=0
while [ -z "$DEV" ] && [ "$i" -lt "$LINK_WAIT" ]; do
  i=$((i + 1)); sleep 1
  DEV=$(find_egress | head -1)
done
[ -n "$DEV" ] || fail "no egress device after ${LINK_WAIT}s (dhcp not up?)"
PIN="/sys/fs/bpf/$DEV"
log "uplink: $DEV"

# --- 2. clean stale state (idempotent entry) -----------------------------------
# stale pins from a wedged prior run: kill by state, detach + unpin, delete.
"$RUNSC" --root="$STATE" --overlay2=none --ignore-cgroups delete -f "$CID" \
  2>/dev/null || true
ip xdp off dev "$DEV" 2>/dev/null || true
# Drop the pinned permanent GW neighbor (re-pinned after attach below): a
# permanent entry must not survive a teardown, or a future boot on a changed
# uplink (different GW MAC) would forward the kernel's :22 TX to the wrong
# MAC. Re-attach re-resolves + re-pins.
GW_T=$(ip route show default 2>/dev/null | awk '/default/{print $3; exit}')
[ -n "$GW_T" ] && ip -4 neigh del "$GW_T" dev "$DEV" 2>/dev/null || true
rm -f "$PIN/redirect_ip_map" "$PIN/redirect_program" "$PIN/redirect_link" 2>/dev/null || true
rmdir "$PIN" 2>/dev/null || true
for ns in $(ip netns list 2>/dev/null | awk '$1 ~ /^runsc-[0-9]+$/{print $1}'); do
  for p in $(ip netns pids "$ns" 2>/dev/null); do
    if tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | grep -q "$STATE"; then
      kill -9 "$p" 2>/dev/null || true
    fi
  done
done
rm -rf "$STATE" "$B" 2>/dev/null || true
mkdir -p "$STATE" "$B/rootfs" || fail "mkdir bundle failed"

# --- 3. bundle ------------------------------------------------------------------
# Minimal bundle rootfs (busybox + the gofer bind targets):
#   * /etc/{resolv.conf,hostname,hosts} MUST exist in the bundle: runsc
#     setupNet bind-mounts host versions over them into the sandbox, and the
#     gofer O_CREATs each mount point BEFORE the bind — a missing file on the
#     read-only rootfs is a gofer fatal ("cannot read client sync file:
#     EOF"). The image ships all three (Containerfile common rootfs).
cat > "$B/config.json" <<EOF
{
  "ociVersion": "1.0.2",
  "process": {
    "args": ["/bin/busybox", "sh", "/sysnet-init.sh"],
    "env": ["PATH=/usr/sbin:/usr/bin:/sbin:/bin"],
    "cwd": "/",
    "capabilities": {}
  },
  "root": { "path": "rootfs", "readonly": true },
  "hostname": "sysnet",
  "mounts": [],
  "linux": {}
}
EOF
mkdir -p "$B/rootfs/bin" "$B/rootfs/etc" 2>/dev/null || fail "mkdir bundle rootfs failed"
for f in /etc/resolv.conf /etc/hostname /etc/hosts; do
  [ -f "$f" ] || fail "missing gofer bind target $f (image regression)"
  cp -f "$f" "$B/rootfs$f" 2>/dev/null || fail "copy $f into bundle failed"
done
# payload: keep the sandbox "running" and observable (runsc list). A real
# deployment replaces this with the guest's network-manager service.
cp -f /bin/busybox "$B/rootfs/bin/busybox" || fail "copy busybox into bundle failed"
chmod 755 "$B/rootfs/bin/busybox" 2>/dev/null || true
cat > "$B/rootfs/sysnet-init.sh" <<'EOF'
#!/bin/busybox sh
# sysnet sandbox payload: the sandbox owns the guest data plane in the
# sentry netstack; the kernel keeps only tcp/22 (the XDP_PASS class).
echo "sysnet-payload: up"
exec /bin/busybox sleep 1000000
EOF
chmod 755 "$B/rootfs/sysnet-init.sh" 2>/dev/null || true

# --- 4a. pin the uplink GW as a permanent neighbor (BEFORE XDP attach) ---------
# Once the redirect program is attached (driver mode on virtio-net; generic
# as the e1000 fallback), the kernel's own ARP is diverted into the sandbox,
# so the kernel can never (re)resolve the GW MAC on the wire. Pin the resolved GW MAC as PERMANENT first: the
# kernel's XDP_PASS class (tcp/22, both directions) still forwards off-link
# frames using this entry, so new SSH connections keep their SYN-ACK path.
# The sandbox keeps wire ARP for its own traffic (sentry-side, unaffected).
# Bounded wait for the initial resolution: the lease is seconds old and the
# kernel is resolving right now, pre-attach.
GW=$(ip route show default 2>/dev/null | awk '/default/{print $3; exit}')
GWMAC=""
if [ -z "$GW" ]; then
  log "warn: no default route yet; skipping GW pin"
else
  i=0
  while [ -z "$GWMAC" ] && [ "$i" -lt 15 ]; do
    GWMAC=$(ip -4 neigh show "$GW" dev "$DEV" 2>/dev/null | awk '{print $3; exit}')
    [ -z "$GWMAC" ] && ping -c 1 -W 1 "$GW" >/dev/null 2>&1
    i=$((i + 1)); sleep 1
  done
  if [ -n "$GWMAC" ]; then
    ip -4 neigh replace "$GW" dev "$DEV" lladdr "$GWMAC" nud permanent 2>/dev/null || true
    log "GW $GW pinned permanent ($GWMAC)"
  else
    log "warn: GW $GW unresolved after 15s; kernel off-link egress may lag until re-resolution"
  fi
fi

# --- 4. pin the redirect program on the uplink (loader) -------------------------
# xdp_loader loads + pins program/sockmap/link under /sys/fs/bpf/<dev>/ and
# attaches the program (driver mode on virtio-net; generic as the e1000
# fallback). The runsc client's sentry will insert
# its bound AF_XDP socket into the pinned map at start — the sentry-side
# synchronous configure (xdp-2) guarantees the RX ring exists by then.
log "pin redirect on $DEV"
"$LOADER" redirect -device "$DEV" || fail "xdp_loader redirect failed"
[ -e "$PIN/redirect_ip_map" ] || fail "redirect map not pinned"

# --- 5. runsc create + start (redirect mode) ------------------------------------
# create+start (not `do`): keeps the sandbox a supervised long-lived service
# the unit can poll and teardown can delete.
log "create (redirect:$DEV)"
"$RUNSC" --root="$STATE" --overlay2=none --ignore-cgroups --TESTONLY-unsafe-nonroot \
  --network=sandbox --EXPERIMENTAL-xdp="redirect:$DEV" \
  create --bundle "$B" "$CID" < /dev/null >/dev/null 2>&1
CRE=$?
[ "$CRE" -eq 0 ] || { log "create rc=$CRE"; exit 1; }
log "start (redirect:$DEV)"
"$RUNSC" --root="$STATE" --overlay2=none --ignore-cgroups --TESTONLY-unsafe-nonroot \
  --network=sandbox --EXPERIMENTAL-xdp="redirect:$DEV" \
  start "$CID" < /dev/null >/dev/null 2>&1
STA=$?

# --- 6. start-failure safety path ------------------------------------------------
# If start failed (e.g. the sockmap insert), a pinned program with an EMPTY
# socket map would blackhole the redirect class. Detach + unpin now; the
# non-zero exit makes execd respawn and retry.
if [ "$STA" -ne 0 ];
  then
    log "start rc=$STA: wedge recovery (detach + unpin)"
    ip xdp off dev "$DEV" 2>/dev/null || true
    rm -f "$PIN/redirect_ip_map" "$PIN/redirect_program" "$PIN/redirect_link" 2>/dev/null || true
    rmdir "$PIN" 2>/dev/null || true
    exit 1
  fi

# --- 7. wait for running (bounded; poll runsc list) ------------------------------
is_running() {
  "$RUNSC" --root="$STATE" --overlay2=none --ignore-cgroups list 2>/dev/null \
    | awk -v id="$CID" '$1==id{print $3}' | grep -qi running
}
i=0
while [ "$i" -lt "$SBX_WAIT" ]; do
  is_running && break
  i=$((i + 1)); sleep 1
done
if is_running; then
  log "sandbox $CID running (redirect:$DEV — full NIC ownership)"
else
  log "sandbox not running after ${SBX_WAIT}s"
  exit 1
fi

# --- 7b. boot-time self-test (logged to serial; no SSH needed) ------------------
# Proves the data plane on THIS boot. The bidirectional :22 rule (PASS when
# EITHER port is 22) implies a clean ownership split — the kernel is the :22
# authority (management/SSH), the sandbox is the data-plane authority (all
# non-:22). The expected outcomes, and the mechanism for each:
#   (a) in-sandbox netstack (the sentry; egress via the AF_XDP socket on the
#       uplink):
#         A = 10.0.2.2:22 (sandbox as a :22 CLIENT) -> EXPECTED FAIL. The
#           sandbox's :22 SYN TXes fine, but the GW's reply carries srcport 22
#           so on RX it XDP_PASSes to the KERNEL, not back to the sandbox — the
#           sandbox never sees the ACK. This is the rule working, NOT a defect
#           (the sandbox is a data-plane server, never a :22 client). A PASS
#           here would be the regression: it would mean the :22 return path is
#           leaking to the sandbox instead of the kernel.
#         B = 8.8.8.8:443 (sandbox non-:22 egress)  -> EXPECTED PASS. Neither
#           port is 22, so the reply redirects back to the sandbox: the sandbox
#           owns the non-:22 data plane.
#   (b) guest-kernel egress:
#         10.0.2.2:22 -> EXPECTED PASS. The kernel's :22 SYN TXes (driver mode
#           does not hook egress), and the reply (srcport 22) XDP_PASSes back
#           to the kernel. This is the management channel the host harness also
#           verifies end-to-end.
#         8.8.8.8:443 -> EXPECTED FAIL. The kernel's non-:22 reply (no port 22)
#           redirects into the sandbox, so the kernel's non-:22 plane is dark —
#           the sandbox owns it.
log "self-test: in-sandbox probes"
cat > "$B/rootfs/sysnet-probe.sh" <<'EOF'
#!/bin/busybox sh
echo "  [sbx] A (GW 10.0.2.2:22, sandbox-as-:22-client): "
/bin/busybox nc -z -w 6 10.0.2.2 22 && echo "  [sbx] A: PASS (UNEXPECTED — :22 return path leaking to the sandbox?)" || echo "  [sbx] A: FAIL (expected — the kernel owns the :22 return path)"
echo "  [sbx] B (8.8.8.8:443, sandbox data plane): "
/bin/busybox nc -z -w 8 8.8.8.8 443 && echo "  [sbx] B: PASS" || echo "  [sbx] B: FAIL"
EOF
chmod 755 "$B/rootfs/sysnet-probe.sh" 2>/dev/null || true
"$RUNSC" --root="$STATE" --overlay2=none --ignore-cgroups exec "$CID" \
  /bin/busybox sh /sysnet-probe.sh 2>&1 | sed 's/^/  /' >&2
log "self-test: guest kernel egress"
# (a) on-link, dst :22  -> should PASS (dstport==22 passes the XDP even on egress).
if /bin/busybox nc -z -w 4 10.0.2.2 22 2>/dev/null; then
  log "  [kern] 10.0.2.2:22 (on-link, dst22): PASS"
else
  log "  [kern] 10.0.2.2:22 (on-link, dst22): FAIL"
fi
# (b) off-link, dst :443 -> the redirect class. With the bidirectional program
#     this is EXPECTED to FAIL on the kernel side: the kernel's non-:22 traffic
#     is deliberately handed to the sandbox (full NIC ownership — the sandbox
#     owns the data plane, the kernel keeps only :22). The exact mechanism
#     depends on the attach mode xdp_loader lands in:
#       * driver mode (virtio-net): the kernel's :443 SYN TXes fine, but the
#         return traffic (SYN-ACK, srcport 443) is diverted on RX -> the
#         connect times out.
#       * generic mode (e1000 fallback): do_xdp_generic hooks egress too, so
#         the :443 SYN itself is redirected into the sandbox.
#     Either way the kernel's non-:22 plane is not usable; a PASS here would
#     mean the attach did not take effect.
#     The management channel itself (new SSH conns) is verified from the host
#     by the boot harness, not here: it needs the kernel's :22 class (both
#     directions) to pass, which is the custom program's bidirectional rule
#     (the stock dstport-only program broke exactly that).
if /bin/busybox nc -z -w 6 8.8.8.8 443 2>/dev/null; then
  log "  [kern] 8.8.8.8:443 (off-link, dst443): PASS (kernel egress NOT diverted — attach not in effect?)"
else
  log "  [kern] 8.8.8.8:443 (off-link, dst443): FAIL (expected: kernel non-:22 egress diverted to the sandbox)"
fi

# --- 8. supervised lifetime -------------------------------------------------------
# Hold the unit's process alive while the sandbox runs; if it dies (sentry
# crash, OOM), exit non-zero so execd respawns (teardown + redirect retry).
# N CONSECUTIVE failed polls before declaring death: a single transient
# runsc list miss (state-root contention) must not orphan the data plane.
i=0; FAIL=0
while [ "$i" -lt 360000 ]; do
  sleep 5
  if is_running; then
    FAIL=0
  else
    FAIL=$((FAIL + 1))
    [ "$FAIL" -ge 3 ] && { log "sandbox dead (3 consecutive failed polls)"; exit 1; }
  fi
  i=$((i + 1))
done
log "supervisor exit (liveness horizon reached; unit will respawn)"
exit 0
