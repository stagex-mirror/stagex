#!/bin/sh
# sysnet.sh — guest supervisor for the Qubes "sys-net" model on the go-branch
# gVisor build (the 4-patch runsc: xdp-1..xdp-4 in packages/user/gvisor).
#
# The execd unit `sysnet` (restart="always") runs THIS wrapper. It brings a
# gVisor sandbox up as the guest's network face:
#
#   guest NIC (virtio) <-- the guest's own egress (dhcp default, NEVER touched)
#   veth pair inside netns $NS:
#     syso-ctr (192.168.57.2/24)  -- XDP redirect target, in $NS
#     syso-host (192.168.57.1/24) -- stays in the guest's main netns
#   sandbox runs in $NS with --network=host; the sentry binds the AF_XDP
#   socket to syso-ctr (xdp-4: BindSentry) and scrapes its addr/routes.
#   redirect_host XDP program on syso-ctr: tcp/22 -> kernel stack (SSH stays
#   reachable); everything else -> bpf_redirect_map(sock_map) -> AF_XDP
#   socket -> sentry netstack -> sandbox payload.
#
# WHY THIS SHAPE (oracle-proven, host-side, this tree):
#   oracle-v5.sh proved the exact data path frame by frame on this kernel:
#   [A] host->tcp/8080 delivered INSIDE the sandbox via XDP->sockmap->AF_XDP
#       (the sandbox owns no kernel interface; that is the only path);
#   [B] tcp/22 XDP_PASS class still reaches the kernel stack (class-selective);
#   [C] the same port that passed pre-program is diverted off the kernel stack
#       post-program. The 4th patch (xdp-4-redirect-bindsentry) is what makes
#   the bind succeed: the sentry registers UMEM + fill/completion/RX/TX rings
#   BEFORE bind(), so the kernel xsk_bind guard (no rings -> -EINVAL) passes.
#   A supervisor that "always falls back to host mode" would be wrong for this
#   build: the redirect path works. The fallback below is the SAFETY path for
#   a stale pinned program (wedge) or an unexpected bind failure, not the
#   expected path.
#
# BUNDLE ROOTFS MECHANISM (the P4 rule, applied):
#   The booted rootfs is read-only erofs and has no /etc/{resolv.conf,
#   hostname,hosts}; a missing gofer bind target makes the gofer O_CREAT a
#   nonexistent path and die ("cannot read client sync file: EOF"). The bundle
#   is therefore MINIMAL, the oracle-proven shape (oracle-bundle, ~4.4 MB):
#   busybox (static) + the three gofer bind targets copied from the guest's
#   /, plus the payload init script. --overlay2=none: the sentry reads bundle
#   files straight off the /run/sysnet filestore (no CoW, no copy of /).
#   --overlay2=none is the create+start spelling of the `do` --force-overlay=
#   false form; both were oracle-proven in-guest.
#
# FLAGS (each load-bearing, from the P4 + oracle record):
#   --network=host : runsc do/create still runs setupNet (MASQUERADE for
#     egress), but container.go bails out of modifySpecForDirectfs BEFORE the
#     /proc/self/uid_map read that needs CONFIG_USER_NS (absent in the
#     hardened kernel). Without it, directfs (default on) adds a user ns and
#     the spec fixup fails exit 128.
#   --overlay2=none: read the erofs rootfs directly (see above).
#   --ignore-cgroups: nit's init leaves cgroup v2 with ZERO controllers
#     enabled; cgroup setup would fail ("stat /sys/fs/cgroup/cpu: no such
#     file").
#   PATH export  : runsc inherits the unit env (NO PATH); Go execs `ip` via
#     its default PATH -> /usr/bin/ip. /usr/sbin (iproute2) must lead, else
#     setupNet's `ip` resolves to busybox (no netns) and runsc SILENTLY
#     falls back to an empty netns.
#
# WEDGE RULE (the one real foot-gun): runsc pins + attaches the redirect
# program to syso-ctr (in $NS). Once attached, every frame in the redirect
# class (everything non-tcp/22 arriving at syso-ctr) goes to the sockmap. If
# the sockmap holds NO bound socket (the sandbox died / never bound), those
# frames are dropped — i.e. the sandbox data path is dead, and only tcp/22
# (the XDP_PASS class) still reaches the kernel stack. The program does NOT
# sit on the guest's virtio NIC, so the guest's own egress is unaffected; the
# wedge is scoped to the sandbox path. Mitigations: the sandbox's AF_XDP
# socket is bound (rings registered) BEFORE the program takes effect, and the
# teardown / bind-failure path DETACHES the program (ip xdp off) so a stale
# pinned map can never blackhole a fresh run.
#
# NAMESPACES: `ip netns exec` unshares a FRESH mntns per call, so a bpffs
# mount is invisible across calls and runsc's mkdir /sys/fs/bpf/<iface>
# would ENOENT. A long-lived HOLDER sleep owns the netns mntns; every in-ns
# op goes through `nsenter -t $HOLDER -m -n` (holder mntns + netns, no
# unshare). ip netns exec / setsid fork, so the holder pid comes from
# `ip netns pids`, not $!.
#
# Shell discipline: /bin/sh here is brush — `wait <pid>` is unimplemented and
# a bare `wait` returns 0 regardless of the reaped job's status. This script
# backgrounds exactly one process (the netns holder sleep; it is killed via
# `ip netns pids`, never wait'd), uses no process substitution, and polls
# sandbox health with `runsc list`. Absolute in-guest paths throughout.
set -u

NS=syso-ns
VETH_HOST=syso-host
VETH_CTR=syso-ctr
SBX_IP=192.168.57.2/24
GW_IP=192.168.57.1
GW_NET=192.168.57.1/24
CID=sysnet
RUNSC=/usr/bin/runsc
STATE=/run/sysnet/runsc
B=/run/sysnet/bundle
PIN="/sys/fs/bpf/$VETH_CTR"
LINK_WAIT=60        # bounded wait for the uplink link (dhcp unit)
SBX_WAIT=90         # bounded wait for the sandbox to reach running
HOLDER=""

log()  { echo "sysnet: $*" >&2; }
fail() { log "$*"; exit 1; }

# --- teardown (execd restarts us on non-zero exit) ---------------------------
teardown() {
  # detach first: a pinned program with an unbound socket map drops the
  # redirect class (the wedge).
  ip netns exec "$NS" ip xdp off dev "$VETH_CTR" 2>/dev/null || true
  # delete the sandbox while the holder (its mntns) is still alive
  if [ -n "$HOLDER" ] && [ -d "/proc/$HOLDER" ]; then
    nsenter -t "$HOLDER" -m -n "$RUNSC" --root="$STATE" delete -f "$CID" \
      < /dev/null >/dev/null 2>&1 || true
  fi
  # MEASURED in the guest (kernel 7.2): `ip netns del` does NOT kill the
  # pids inside, and is REFUSED while any process holds the netns open.
  # So kill every in-ns pid first (holder, sentry, strays), then del, then
  # the veth. Killing the sentry also releases the AF_XDP device bind
  # (xsk_release) before the del, so a respawn re-bind never hits EBUSY.
  for p in $(ip netns pids "$NS" 2>/dev/null); do
    kill -9 "$p" 2>/dev/null || true
  done
  sleep 0.3
  ip netns del "$NS" 2>/dev/null || true
  ip link del "$VETH_HOST" 2>/dev/null || true
  # runsc also creates a per-sandbox netns named runsc-<sandbox PID> (the PID
  # is unpredictable). Identify OURS by the state root in the runsc process
  # cmdline and tear those down: kill their pids, then del the netns. Never
  # touches other sandboxes' runsc netns (e.g. bootproofd's).
  for p in $(pgrep -x runsc 2>/dev/null); do
    if tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | grep -q "$STATE"; then
      kill -9 "$p" 2>/dev/null || true
    fi
  done
  sleep 0.2
  for ns in $(ip netns list 2>/dev/null | awk '$1 ~ /^runsc-[0-9]+$/{print $1}'); do
    held=0
    for p in $(ip netns pids "$ns" 2>/dev/null); do
      if tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | grep -q "$STATE"; then held=1; fi
    done
    [ "$held" -eq 1 ] && { kill -9 $(ip netns pids "$ns" 2>/dev/null) 2>/dev/null; sleep 0.2; ip netns del "$ns" 2>/dev/null || true; }
  done
  # belt and braces: if the del still failed (a D-state pid), the next run's
  # section-2 entry cleanup retries the same kill-then-del sequence
  for p in $(ip netns pids "$NS" 2>/dev/null); do
    kill -9 "$p" 2>/dev/null || true
  done
  # bpffs pin cleanup (guest bpffs; kernel objects die with the netns, but the
  # pin PATHS persist per bpffs mount)
  rm -f "$PIN/redirect_ip_map" "$PIN/redirect_program" "$PIN/redirect_link" 2>/dev/null || true
  rmdir "$PIN" 2>/dev/null || true
  # NAT rule ownership: delete the sandbox-subnet MASQUERADE this unit added
  # (idempotent; a stale rule would NAT nothing once the netns is gone, but a
  # respawn must not accumulate duplicates either)
  iptables -t nat -D POSTROUTING -s "$SBX_IP" -j MASQUERADE 2>/dev/null || true
}
trap teardown EXIT
# explicit signal traps: brush's EXIT-trap-on-signal behavior is not relied on
# (measured concern: the holder died and the netns lingered in one run). A
# signal-driven teardown is idempotent (every step is || true / re-checks), so
# the EXIT trap running a second time is a no-op.
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

# --- 0. preconditions --------------------------------------------------------
[ -x "$RUNSC" ] || fail "runsc missing at $RUNSC"
[ -x /usr/sbin/ip ] || fail "iproute2 ip missing (libelf?)"
mountpoint -q /sys/fs/bpf || mount -t bpf bpf /sys/fs/bpf 2>/dev/null || true
mountpoint -q /sys/fs/bpf || fail "bpffs unavailable (no /sys/fs/bpf mount)"
mkdir -p "$STATE" "$B" || fail "mkdir run state failed"
# PATH for runsc (and its child sentry): /usr/sbin (iproute2) must lead.
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

# --- 1. wait for the egress device (bounded) ----------------------------------
# The dhcp unit owns the real NIC; the sandbox netstack's egress must resolve
# the SAME device setupNet would (ip route). Without it the sandbox is up but
# dark. Bounded wait; on timeout exit NON-ZERO so the unit respawns and
# retries (the lease arrives seconds after boot).
find_egress() {
  # 1) the default-route device (what runsc do's setupNet resolves)
  ip route list default 2>/dev/null | head -1 | awk '{print $5}'
  # 2) the device the kernel WOULD use (ARP-suppressed, no traffic sent)
  ip route get 8.8.8.8 2>/dev/null | awk '/ dev /{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1); exit}'
  # one line only: first non-empty wins
}
UPLINK=$(find_egress | head -1)
i=0
while [ -z "$UPLINK" ] && [ "$i" -lt "$LINK_WAIT" ]; do
  i=$((i + 1)); sleep 1
  UPLINK=$(find_egress | head -1)
done
[ -n "$UPLINK" ] || fail "no egress device after ${LINK_WAIT}s (dhcp not up?)"
log "egress device: $UPLINK"

# --- 2. clean stale state (idempotent entry) ----------------------------------
if [ -n "$(ip netns list 2>/dev/null | awk -v n="$NS" '$1==n')" ]; then
  for p in $(ip netns pids "$NS" 2>/dev/null); do kill "$p" 2>/dev/null || true; done
  sleep 0.3
  ip netns del "$NS" 2>/dev/null || true
fi
ip link del "$VETH_HOST" 2>/dev/null || true
# stale pins from a wedged prior run: detach + unpin BEFORE re-running
ip xdp off dev "$VETH_CTR" 2>/dev/null || true
if [ -e "$PIN" ]; then
  rm -f "$PIN/redirect_ip_map" "$PIN/redirect_program" "$PIN/redirect_link" 2>/dev/null || true
  rmdir "$PIN" 2>/dev/null || true
fi
rm -rf "$STATE" "$B" 2>/dev/null || true
mkdir -p "$STATE" "$B/rootfs" || fail "mkdir bundle failed"

# --- 3. bundle ----------------------------------------------------------------
# Minimal bundle rootfs, the oracle-proven shape (oracle-bundle: 4.4 MB,
# busybox + the gofer bind targets):
#   * /etc/{resolv.conf,hostname,hosts} MUST exist in the bundle: with
#     --network=host runsc's setupNet bind-mounts host versions over them into
#     every sandbox, and the gofer O_CREATs each mount point BEFORE the bind —
#     a missing file on the read-only rootfs is a gofer fatal
#     ("cannot read client sync file: EOF"). The image ships all three
#     (Containerfile common rootfs), so copy them from / into the bundle.
#   * payload = busybox (the guest's own /bin/busybox — static enough for
#     this minimal bundle; ldd-checked at runtime) + sysnet-init.sh.
#   * --overlay2=none: the sentry reads bundle files straight off the
#     /run/sysnet filestore (no CoW, no copy of / — a GB-scale tar would
#     defeat the bit-determinism pins and buy nothing, since the payload is
#     self-contained).
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
mkdir -p "$B/rootfs/bin" "$B/rootfs/etc" "$B/rootfs/usr/sbin" "$B/rootfs/usr/bin" \
  "$B/rootfs/sbin" "$B/rootfs/lib" 2>/dev/null || fail "mkdir bundle rootfs failed"
# gofer bind targets (the P4 rule)
for f in /etc/resolv.conf /etc/hostname /etc/hosts; do
  [ -f "$f" ] || fail "missing gofer bind target $f (image regression)"
  cp -f "$f" "$B/rootfs$f" 2>/dev/null || fail "copy $f into bundle failed"
done
# payload: the sandbox's network front. It owns the guest's data plane in the
# sentry netstack; the kernel keeps only tcp/22 (the XDP_PASS class). A real
# deployment replaces this with the guest's network-manager service.
cp -f /bin/busybox "$B/rootfs/bin/busybox" || fail "copy busybox into bundle failed"
chmod 755 "$B/rootfs/bin/busybox" 2>/dev/null || true
cat > "$B/rootfs/sysnet-init.sh" <<'EOF'
#!/bin/busybox sh
# sysnet sandbox payload: keep the sandbox "running" and observable
# (runsc list). The minimal bundle has NO /bin/sh (busybox only), so the
# shebang targets busybox directly. The sentry already scraped the veth
# addr/routes at start.
echo "sysnet-payload: up"
exec /bin/busybox sleep 1000000
EOF
chmod 755 "$B/rootfs/sysnet-init.sh" 2>/dev/null || true

# --- 4. topology (oracle-proven shape) ----------------------------------------
ip netns add "$NS" || fail "netns add $NS failed"
ip link add "$VETH_HOST" type veth peer name "$VETH_CTR" \
  || fail "veth add failed"
ip link set "$VETH_CTR" netns "$NS" || fail "veth move failed"
ip link set "$VETH_HOST" up || fail "veth host up failed"
ip addr add "$GW_NET" dev "$VETH_HOST" || fail "veth host addr failed"
# Holder: owns the netns mntns (bpffs + runsc state) across nsenter calls.
# The one backgrounded process in this script (oracle-proven): it must outlive
# this line, so it is &-launched and reaped by teardown (ip netns pids kill),
# never wait'd.
ip netns exec "$NS" sleep 100000 >/dev/null 2>&1 &
sleep 1
HOLDER=$(ip netns pids "$NS" 2>/dev/null | head -1)
[ -n "$HOLDER" ] && [ -d "/proc/$HOLDER" ] || fail "holder dead"
nsenter -t "$HOLDER" -m -n sh -c "mountpoint -q /sys/fs/bpf || mount -t bpf bpf /sys/fs/bpf" \
  || fail "bpffs mount in holder failed"
nsenter -t "$HOLDER" -m -n ip link set lo up || fail "ns lo up failed"
nsenter -t "$HOLDER" -m -n ip link set "$VETH_CTR" up || fail "ns veth up failed"
nsenter -t "$HOLDER" -m -n ip addr add "$SBX_IP" dev "$VETH_CTR" \
  || fail "ns veth addr failed"
# The sandbox netstack egresses via the veth peer: give $NS a default through
# it so the sentry (which scrapes veth-ctr addr + routes at start) routes
# external destinations out to the main netns, which then uses the dhcp
# default to reach the real uplink. This is what makes the sandbox a live
# egress point rather than a dead-end.
nsenter -t "$HOLDER" -m -n ip route replace default via "$GW_IP" dev "$VETH_CTR" \
  || fail "ns default route failed"
# Deterministic L2 both ways (no CAP_NET_RAW/ping in the payload path).
MACNS=$(nsenter -t "$HOLDER" -m -n ip link show "$VETH_CTR" | awk '/link\/ether/{print $2}')
MACH=$(ip link show "$VETH_HOST" | awk '/link\/ether/{print $2}')
ip neigh add "${SBX_IP%/*}" lladdr "$MACNS" dev "$VETH_HOST" nud permanent 2>/dev/null || true
nsenter -t "$HOLDER" -m -n ip neigh add "$GW_IP" lladdr "$MACH" dev "$VETH_CTR" nud permanent 2>/dev/null || true
# Main-netns L3 for the veth subnet: the connected /24 route appears with the
# veth up+addr (automatic). The main-netns default (the dhcp lease) is NEVER
# touched by this script: the redirect program sits on syso-ctr in $NS, so
# the guest's uplink egress is orthogonal to the sandbox data path.
log "topology ready (holder $HOLDER; host $GW_IP / ns ${SBX_IP%/*}, ns default via $GW_IP)"

# --- 5. runsc create + start (redirect mode, in the netns) --------------------
# The redirect path is the HAPPY path on the 4-patch build (xdp-4 BindSentry:
# the sentry registers UMEM+rings then binds). No `runsc do`: create+start
# keeps the sandbox as a supervised long-lived service the unit can poll and
# teardown can delete.
log "create (redirect:$VETH_CTR)"
nsenter -t "$HOLDER" -m -n "$RUNSC" --root="$STATE" --overlay2=none --ignore-cgroups \
  --network=host --EXPERIMENTAL-xdp="redirect:$VETH_CTR" \
  create --bundle "$B" "$CID" < /dev/null >/dev/null 2>&1
CRE=$?
if [ "$CRE" -ne 0 ];
  then log "create rc=$CRE"; exit 1; fi
log "start (redirect:$VETH_CTR)"
nsenter -t "$HOLDER" -m -n "$RUNSC" --root="$STATE" --overlay2=none --ignore-cgroups \
  --network=host --EXPERIMENTAL-xdp="redirect:$VETH_CTR" \
  start "$CID" < /dev/null >/dev/null 2>&1
STA=$?

# --- 6. bind-failure / wedge safety path --------------------------------------
# If start failed, a pinned program with an EMPTY socket map would blackhole
# the redirect class. Detach it and unpin BEFORE anything else. The guest's
# own egress (dhcp default on the virtio NIC) was never touched, so the guest
# stays connected; the EXIT trap tears down netns/veth/pins, and the non-zero
# exit makes execd respawn and retry the redirect path (a persistent bind
# failure is a build regression, not a state to settle for).
if [ "$STA" -ne 0 ];
  then
    log "start rc=$STA: wedge recovery (detach stale program, unpin)"
    ip netns exec "$NS" ip xdp off dev "$VETH_CTR" 2>/dev/null || true
    if [ -e "$PIN" ]; then
      rm -f "$PIN/redirect_ip_map" "$PIN/redirect_program" "$PIN/redirect_link" 2>/dev/null || true
      rmdir "$PIN" 2>/dev/null || true
    fi
    log "fallback: guest egress intact (dhcp default); sandbox not up (will retry)"
    exit 1
  fi

# --- 7. wait for running (bounded; poll runsc list, oracle-proven) ------------
# runsc list column 3 is the state (oracle used exactly this). No wait/pid.
is_running() {
  nsenter -t "$HOLDER" -m -n "$RUNSC" --root="$STATE" list 2>/dev/null \
    | awk -v id="$CID" '$1==id {print $3}' | grep -qi running
}
i=0
while [ "$i" -lt "$SBX_WAIT" ]; do
  is_running && break
  i=$((i + 1)); sleep 1
done
if is_running; then
  log "sandbox $CID running (redirect mode)"
else
  log "sandbox not running after ${SBX_WAIT}s"
  exit 1
fi

# --- 8. L3 flush (ONLY now: socket map populated, sandbox bound) --------------
# Reassert the sandbox egress route INSIDE $NS (default via the veth peer) and
# re-pin the neighbor. The main-netns default (the dhcp lease) is NEVER
# touched: the redirect program sits on syso-ctr, so the guest's uplink egress
# is orthogonal to the redirect class. Safe now: the AF_XDP socket is bound
# (sentry registered the rings at start), so frames in the redirect class have
# a live destination instead of a black hole.
nsenter -t "$HOLDER" -m -n ip route replace default via "$GW_IP" dev "$VETH_CTR" \
  2>/dev/null || true
ip neigh replace "${SBX_IP%/*}" lladdr "$MACNS" dev "$VETH_HOST" nud permanent 2>/dev/null || true
# NAT the sandbox subnet in the main netns. The sandbox netstack sources
# $SBX_IP (the private veth subnet), and runsc --network=host adds NO
# MASQUERADE for it (setupNet only NATs its own managed veth subnets, which
# do not exist here). Without this rule the guest uplink (SLIRP/EVS) sees an
# off-subnet source address and drops the flow — sandbox egress is dark
# while guest egress is fine (the guest already sources its lease addr).
# Proven in-guest (2026-09-28): Leg C (sandbox -> 10.0.2.2:22 through the
# uplink) fails without, passes with, and non-22 (SLIRP DNS 53) is reachable
# too. Idempotent: check, then append. Owned by this unit — teardown deletes.
iptables -t nat -C POSTROUTING -s "$SBX_IP" -j MASQUERADE 2>/dev/null \
  || iptables -t nat -A POSTROUTING -s "$SBX_IP" -j MASQUERADE \
  || log "MASQUERADE for $SBX_IP failed (sandbox egress will be dark)"
log "L3 flushed (ns default via $GW_IP dev $VETH_CTR; main default untouched; nat for $SBX_IP)"

# --- 9. supervised lifetime ----------------------------------------------------
# Long-lived: hold the unit's process alive while the sandbox runs; if it dies
# (sentry crash, OOM), exit non-zero so execd respawns the whole supervisor
# (teardown + redirect retry). Poll runsc list (is_running); the only
# backgrounded process is the holder (killed via ip netns pids, never wait'd).
i=0; FAIL=0
while [ "$i" -lt 360000 ]; do
  sleep 5
  # liveness: N CONSECUTIVE failed polls before declaring death. A single
  # failed runsc list (transient state-root contention with concurrent
  # probes/inspect, seen live) must not tear down a healthy sandbox: the
  # teardown+rebuild cycle is expensive and briefly orphans the data plane.
  if is_running; then
    FAIL=0
  else
    FAIL=$((FAIL + 1))
    [ "$FAIL" -ge 3 ] && { log "sandbox left running (3 consecutive failed polls)"; exit 1; }
  fi
  # holder liveness: if the holder died, the netns mntns (runsc state) is gone
  [ -d "/proc/$HOLDER" ] || { log "holder dead"; exit 1; }
  i=$((i + 1))
done
log "supervisor exit (liveness horizon reached; unit will respawn)"
exit 0
