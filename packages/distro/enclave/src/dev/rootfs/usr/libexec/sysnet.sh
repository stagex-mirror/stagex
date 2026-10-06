#!/bin/sh
# sysnet.sh — guest supervisor for the Qubes "sys-net" model, sn-7: the
# kernel is FULLY offline. The gVisor netstack is the ONLY stack on the
# wire: it owns DHCP (rust-dhcp), ARP (GW MAC + answering for its lease
# IP), SSH (sshdt on :22), and all egress.
#
# The execd unit `sysnet` (restart="always") runs THIS wrapper. It brings a
# gVisor sandbox up that owns the guest NIC via an AF_XDP redirect:
#
#   xdp_loader redirect -device eth0    (load + pin program/sockmap/link)
#   runsc create+start --EXPERIMENTAL-xdp=redirect:eth0
#
# The v3 redirect program (packages/user/gvisor/bpf/redirect.c) inspects
# NOTHING: if the pinned sockmap is empty (sandbox dead / pre-start) it
# XDP_PASSes the frame to the kernel (the sn-6e death guard); otherwise it
# bpf_redirect_maps EVERY frame (ARP, IPv4, IPv6) into the sandbox's sentry
# netstack. The kernel carries no lease, no address, no route: it has
# nothing to do with any frame.
#
# WHY THE KERNEL GOES OFFLINE (sn-7 direction):
#   * the netstack does ARP itself (resolves the GW MAC for its own
#     default route, answers ARP for its lease IP) — the kernel's ARP
#     table would be a stale second source of truth;
#   * rust-dhcp applies the lease to the NETSTACK via rtnetlink
#     (RTM_NEWADDR/RTM_NEWROUTE) — the xdp-4 patch (0-or-1 uplink
#     address) lets the sandbox NIC start with no protocol address;
#
#   * BOOTSTRAP (load-bearing, root-caused Sep 1): the netstack cannot
#     route a limited broadcast (255.255.255.255) from a NIC with NO v4
#     address. rust-dhcp's DHCP socket is UDP (SO_BINDTODEVICE), so its
#     DISCOVER goes through FindRoute(id, localAddr=0, remote=
#     255.255.255.255) (pkg/tcpip/stack/stack.go:1611), which for a
#     broadcast needs nic.primaryEndpoint -> AcquireOutgoingPrimaryAddress
#     -> acquirePrimaryAddressRLocked — that iterates the NIC's a.primary
#     v4 list, EMPTY here, -> nil -> ErrNetworkUnreachable (stack.go:1640).
#     The kernel does this via an implicit on-link 0.0.0.0 broadcast route
#     that the netstack has no equivalent for. So the payload adds a
#     link-local v4 (169.254.2.2/16) to eth0 FIRST, which (a) gives
#     FindRoute a primary to route the DISCOVER from and (b) resolves
#     255.255.255.255 to the Ethernet broadcast MAC (arp.go ResolveStatic
#     Address, before any ARP) so the DISCOVER reaches slirp; slirp
#     replies (it reads the DHCP ciaddr=0.0.0.0, not the IP src). Once the
#     real lease lands the payload removes the LLA so the lease is the
#     sole egress source. rust-dhcp treats EEXIST on add_interface_ip as
#     benign, so the LLA never blocks the real lease.
#   * sshdt binds 0.0.0.0:22 INSIDE the netstack: host SSH (QEMU
#     hostfwd :2222 -> guest :22) arrives on the wire, is redirected
#     into the netstack by the program, and is served by the sandbox's
#     sshdt. The kernel never sees a single L4 packet.
#
# BUNDLE:
#   * rootfs = busybox (static) + dhcp-client + sshdt + the three musl
#     libs they NEEDED (ld-musl, libc.musl, libunwind) + the gofer bind
#     targets /etc/{resolv.conf,hostname,hosts} + a /root/.ssh
#     placeholder (bind-mounted over with the host dir).
#   * /root/.ssh is BIND-MOUNTED from the host (the enclaved daemon
#     writes /root/.ssh/authorized_keys there after consuming the
#     provisioner drop): a directory bind shows the file the moment it
#     lands, and the payload waits for it (fail-closed, no anonymous
#     auth) before exec'ing sshdt.
#   * /run is a tmpfs (sshdt's per-boot host key).
#   * capabilities: NET_ADMIN (+ NET_RAW) — rust-dhcp's rtnetlink
#     RTM_NEWADDR/RTM_NEWROUTE are gated on CAP_NET_ADMIN in the sentry
#     (pkg/sentry/socket/netlink/route/protocol.go).
#
# FLAGS (each load-bearing):
#   --network=sandbox : the real sentry netstack (runsc's default; stated
#     explicitly).
#   --TESTONLY-unsafe-nonroot : directfs wants a user namespace; the
#     hardened kernel has CONFIG_USER_NS off.
#   --overlay2=none, --ignore-cgroups : the P4 rule (erofs direct read;
#     nit's init leaves cgroup v2 with zero controllers).
#   PATH export : runsc inherits the unit env (NO PATH); /usr/sbin
#     (iproute2) must lead.
#
# DEATH RECOVERY (sn-6e guard, now covering ALL traffic): the kernel
# auto-removes the socket from the pinned sockmap on close; the program's
# empty-sockmap guard then XDP_PASSes the FULL wire to the kernel (no
# black hole) until the liveness monitor (3 consecutive failed polls)
# tears down and execd respawns — the fresh socket re-arms the redirect
# and the netstack re-DORA's. The kernel itself has no lease (offline),
# so recovery = respawn; the dark window is the respawn time.
#
# Shell discipline: /bin/sh here is brush — `wait <pid>` is unimplemented,
# and brush 0.4.0 does NOT set $! (v6: confirmed by direct test — v5's
# `kill -9 "$pr_pid"` was a no-op on an empty pid). So: NEVER `wait`, and
# find a real PID via `pgrep -x <comm>` + /proc/PID/cmdline match, then
# kill -9 that PID. The probe's own in-sandbox ops run under busybox ash
# (the bundle's /bin/sh), where $! and kill work normally.
#
# v6 (serial backpressure fix): the supervisor's own writes go to the tmpfs
# log file ($LOGF), NEVER straight to the serial; a single detached
# `tail -f` forwarder carries the file to the serial (>&2). A stalled
# serial capture can block a serial writer (the v5 final-stall vector —
# after the 5th wedged probe the console stopped advancing entirely);
# a write to tmpfs cannot. If the forwarder stalls, $LOGF still holds the
# ground truth. Serial load also drops ~95%: the full probe dump rides the
# forwarder, not the supervisor's direct writes.
set -u

DEV=eth0                       # pinned by net.ifnames=0 on the cmdline; the
                               # guest has exactly one data NIC. No lease-
                               # based discovery: the kernel is offline and
                               # has no route to discover from.
CID=sysnet
RUNSC=/usr/bin/runsc
LOADER=/usr/bin/xdp_loader
# v12: the ETHTOOL_SCHANNELS setter (see the uplink section below). The
# multi-queue RSS flap fix — collapses the uplink NIC to 1 RX queue so every
# inbound frame lands on queue 0 (the one gvisor binds its AF_XDP socket at).
ETHTOOL=/usr/bin/ethtool
STATE=/run/sysnet/runsc
B=/run/sysnet/bundle
PIN=/sys/fs/bpf/$DEV
SBX_WAIT=90                  # bounded wait for the sandbox to reach running
LOGF=/run/sysnet/log         # v6: supervisor log (tmpfs; never blocks)
WEDGE_LIMIT=5                # v6: consecutive wedged probes => netstack respawn
                             # (v5 wire data: after 5 wedges the netstack went
                             # persistently dark; the only in-guest reset is a
                             # full teardown + execd respawn)
WEDGE=0                      # v6: consecutive wedged-probe counter
# v8: data-plane watchdog (sn-7 flap chase, Oct 3 wire data
# i-086114e6199dd1c29): the flap is the netstack DATA PLANE (261 samples:
# dark windows were 100% TIMEOUT, zero RST) and it DEGRADES to a permanent
# dark. is_running (runsc list, process-based) never sees a wedged-but-alive
# netstack, so the WEDGE_LIMIT never fired and the face sat wedged forever.
# Fix: dpmon — a plain background process INSIDE the sandbox (never a runsc
# exec: the v5 wedge vector was the exec RPC channel) — does a real external
# TCP connect every 10 s and writes the result to $DPF (bind-mounted
# /run/sysnet, visible to the kernel). The kernel-side supervisor reads that
# FILE (no runsc, no netstack, nothing that can wedge) and respawns the
# sandbox on a SUSTAINED dark. A wedged netstack stops dpmon from writing
# (stale file) or fails the connect (fail file): both converge on
# "data-plane dark", which the supervisor can act on.
DPF=/run/sysnet/dp           # v8: dpmon status file (sandbox sees the same bind)
DP_LIMIT=24                  # v8: 24 consecutive dark checks (x 5 s loop = 120 s
                             # of continuous dark) => respawn. Above the longest
                             # observed SELF-RECOVERING window (~50 s, so those
                             # never pay the ~60-90 s respawn cost); far below
                             # the terminal dark (persisted 23 h un-recovered).
DP_STALE=30                  # v8: a dp file older than 30 s = dark (3 missed
                             # 10 s probes)
DPARK=0                      # v8: consecutive data-plane-dark counter (armed only)
DPHAVEN=0                    # v8: 1 once a FRESH "pass" has been observed. The
                             # watchdog fires ONLY on a healthy->sustained-dark
                             # transition: at boot dpmon writes "fail" (no
                             # lease/egress yet) for tens of seconds, and a
                             # slow boot must not count toward DP_LIMIT.
# v9: ESCALATION (sn-7 wire data, Oct 4: i-000e5ccf2f8fefb35 sat terminally
# dark 87 min (04:02->05:29 UTC, 222+ consecutive both-000 samples) and the
# v8 respawn CLEARED NOTHING — the wedge is in KERNEL-SIDE NIC/AF_XDP/ENI
# state that survives sentry death + sandbox recreation, so the exit-1 ->
# teardown -> execd respawn re-binds a fresh AF_XDP socket onto the same
# poisoned NIC and immediately re-wedges (a dark treadmill, no recovery
# blips). The only proven recovery is a FULL GUEST REBOOT (the manual
# `aws ec2 reboot-instances` at 05:29:59 cleared it in ~9 min; v7-obs's
# 23 h dark was likewise reboot-clearable). v9 therefore escalates: a
# SUSTAINED dark respawns the sandbox (one cheap chance); a SUSTAINED dark
# that persists into the NEXT generation (the wedge outlived a full
# teardown+respawn) does a full guest reboot.
GEN_START=0                  # v9: epoch at THIS generation's start (set at the
                             # supervisor-start line; each respawn is a new
                             # supervisor process, so this resets per gen).
DPBOOT=300                   # v9: BOOT DEADLINE. The v8 'armed' model (DPHAVEN)
                             # never arms a generation that never passes egress
                             # (no lease -> dpmon all-fail -> DPHAVEN=0 forever
                             # -> the watchdog is unarmable -> infinite startup
                             # grace). A generation that has had NO fresh pass
                             # for 300 s is broken, not slow (a healthy gen
                             # passes within seconds of its lease). This closes
                             # the unarmable hole.
ESCF=/run/sysnet/esc         # v9: escalation counter. /run/sysnet is the host
                             # tmpfs (bind-mounted), so it PERSISTS across
                             # sandbox respawns (teardown does not clear it) but
                             # is WIPED on a full guest reboot (/run remounts)
                             # — exactly the persistence the escalation needs.
ESC_LIMIT=2                  # v9: after this many consecutive dark GENERATIONS
                             # (i.e. the wedge outlived a full teardown+respawn
                             # once), escalate from sandbox respawn to a full
                             # guest reboot. 1 = respawn; 2nd consecutive dark
                             # = reboot.
RBOVR=/home/sysnet-reboot-overflow  # v9: reboot-loop guard, PERSISTENT across
                             # reboots (LUKS /home on AWS; tmpfs on QEMU).
                             # Counts consecutive reboots with no healthy
                             # generation in between. A healthy gen clears it.
RBOVR_LIMIT=3                # v9: after this many consecutive reboots without
                             # a healthy period, STOP auto-rebooting (stay dark
                             # + loud plog alarm) instead of looping forever.
                             # An infinite reboot loop (guest reset every ~1-2
                             # min, wiping LUKS/NitroTPM sessions) is a worse
                             # liveness failure than a stable-dark + alarm.
PLOG=/home/sysnet-events.log # v9: PERSISTENT event log (LUKS /home on AWS;
                             # tmpfs on QEMU). The reboot that recovers a
                             # terminal dark wipes /run (tmpfs) — the dp file,
                             # the supervisor log, the esc counter all vanish
                             # in the very event that recovers them. The
                             # post-mortem must live here (best-effort writes;
                             # a failed write before /home is mounted is
                             # harmless).
# v13-supervisor (Oct 6 wire): the Oct 6 i-0e5a6d710e6bcc45e incident proved
# the whole recovery stack (dpmon read, dpark_check, escalation, reboot -f)
# lived in ONE shell loop (this file's main loop) — and that loop had WEDGED
# ~14.5 h BEFORE the netstack darked, so when the netstack went terminally
# dark there was NO live process left to run the escalation. The v8/v9 chain
# is correct; it just needs a live loop to run it. Fix: split the RECOVERY
# from the SUPERVISION. The main loop below keeps doing its rich work (runsc
# liveness, teardown, respawn, BPF counters, serial probes) and stamps a
# heartbeat each iteration. A SEPARATE minimal execd unit (sysnet-watchdog
# -> /usr/libexec/sysnet-watchdog.sh) owns the reboot: it only reads two
# files ($HB heartbeat staleness + $DPF data-plane dark) and calls reboot -f
# — NO runsc, NO pgrep, NO bpf(2), NO serial, nothing that can wedge with the
# main loop. If the main loop wedges, the heartbeat goes stale and the
# watchdog reboots the guest INDEPENDENTLY. The two are complementary: the
# main loop still does the CHEAP respawn (sandbox teardown, no reboot) for a
# process-level death or a self-recovering transient; the watchdog is the
# last-resort full reset that survives a wedged main loop.
HB=/run/sysnet/hb             # v13-supervisor: main-loop heartbeat (epoch).
                             # /run/sysnet is the host tmpfs bind — visible to
                             # both processes, wiped on guest reboot.
WDF=/run/sysnet/watchdog.log  # v13-supervisor: watchdog's own log (tmpfs).
# v11: BPF per-queue counter sampling (the multi-queue RSS discriminator).
# The v5 redirect object (packages/user/gvisor/bpf/redirect.c) carries a
# second ARRAY[16] map, bpf_counts = {u32 pass, u32 redirect} indexed by
# ctx->rx_queue_index; xdp-5 (xdp_loader) pins it at $PIN/redirect_counts.
# ENA invokes the program per RX queue, so slot N is queue N's own frame
# counter measured at the decision point. Every per-slot counter is
# MONOTONIC since the program load:
#   pass     = frames on that queue XDP_PASSed to the kernel (the
#              empty-sockmap guard fired — bpf_map_lookup_elem(&sock_map,
#              queue) returned NULL for that queue);
#   redirect = frames on that queue bpf_redirect_map'd into the sentry's
#              AF_XDP ring (gvisor binds its one socket at key 0, xdp.go:178).
# count_sample (below) reads the 16 slots with the kernel-side bpfcount
# reader (32 fields: p0 r0 p1 r1 ... p15 r15) and logs the per-slot DELTAS
# as two 16-slot comma-lists:
#   [bp] dp=<pass deltas q0..q15> dr=<redirect deltas q0..q15>
# The confirmation (c6a ENA = 2 RX queues, RSS 50/50): q0 redirect climbs,
# q1 pass climbs (queue 1 has no socket -> guard -> offline kernel -> drop),
# and q1 pass tracks the dark windows. If q0 alone shows both, the program
# ran single-queue and the pass frames are the sockmap-lifecycle variant.
# Kernel-side read (a bpf(2) syscall) — no runsc, no netstack, nothing that
# can wedge; best-effort: a missing pin (v3/v4 object or pre-attach) or an
# arity mismatch just logs one "absent" line.
BPCOUNT=/usr/bin/bpfcount
BPSTAT=/run/sysnet/bpstat     # v11: previous sample (32 fields: p0 r0 ...
                             # p15 r15); /run/sysnet is the host tmpfs bind —
                             # persists across sandbox respawns within a boot.
                             # Cleared in teardown (the pin dies with the
                             # program, so the counters restart at 0 and a
                             # stale sample would yield a bogus negative
                             # delta).
BPSEEN=0                     # v11: 1 once "absent" has been logged (noise cap)

# v6: writes go to the tmpfs log file, never to the serial (a stalled
# serial capture must not be able to block the supervisor). The detached
# forwarder (launched below, before the first log call) carries $LOGF to
# the serial; if it stalls, the file still holds the truth.
log()  { echo "sysnet: $*" >> "$LOGF" 2>/dev/null || true; }
fail() { log "$*"; exit 1; }
# v9: PERSISTENT event log (the post-mortem channel). /run (tmpfs) is wiped by
# the very reboot that recovers a terminal dark, so the dp file + supervisor
# log + esc counter all vanish in the recovery event. This log lives on /home
# (LUKS on AWS, tmpfs on QEMU) and records the dpmon pass/fail transitions and
# every supervisor start/teardown/escalation/reboot. BEST-EFFORT: every write
# is `2>/dev/null || true` — /home may not be mounted yet at the first boot
# lines, and a log write must NEVER block or fail the supervisor. Bounded to
# the last 1 MiB (a long-lived disk must not fill the volume). A single line
# per event (never the ~60-line probe dump — that stays in $LOGF).
plog() {
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$PLOG" 2>/dev/null || true
  ps=$(wc -c < "$PLOG" 2>/dev/null)
  [ -n "$ps" ] && [ "$ps" -gt 1000000 ] && {
    tail -c 500000 "$PLOG" > "$PLOG.tmp" 2>/dev/null \
      && cat "$PLOG.tmp" > "$PLOG" 2>/dev/null || true
    rm -f "$PLOG.tmp" 2>/dev/null || true
  }
}

# --- teardown (execd restarts us on non-zero exit) ----------------------------
# v6: teardown MUST NOT wedge on the data plane. It is the EXIT-trap path for
# the WEDGE_LIMIT respawn (exit 1 -> this trap -> execd restart="always"), so
# if teardown blocks on a runsc client RPC to a degraded sentry, the supervisor
# never exits, execd never respawns, and the recovery is dead. The two runsc
# calls here (list, delete) are bounded the NON-BLOCKING way — background,
# poll /proc, kill -9 at the deadline, never wait (the same proven fix as
# is_running/run_probe; `list` is a wire-proven wedge point, `delete` is the
# same client-RPC class). The load-bearing action is killing the sandbox init
# by EXACT PID (releases the AF_XDP bind so a respawn re-bind never EBUSY) —
# that is a plain kill(2), local and cannot wedge; it only needs the PID, which
# the bounded list provides if the sentry answers in time. If list does not
# answer (wedged), we still proceed: the supervisor exits, execd respawns, and
# the fresh process re-tears-down/re-creates — strictly better than the old
# "teardown wedges forever -> no respawn ever".
teardown() {
  # bounded `runsc list`: find the sandbox init PID (column 2) without waiting
  # on a possibly-wedged list client.
  tl_out=/tmp/.sysnet-td-list
  rm -f "$tl_out" 2>/dev/null
  "$RUNSC" --root="$STATE" --overlay2=none --ignore-cgroups list 2>/dev/null > "$tl_out" &
  tl_live=0; tl_pid=; j=0
  while [ "$j" -lt 3 ]; do
    tl_live=0
    for p in $(pgrep -x runsc 2>/dev/null); do
      cl=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null)
      case "$cl" in
        *"$STATE"*list*) case "$cl" in *exec*) ;; *) tl_live=1; tl_pid=$p;; esac;;
      esac
    done
    [ "$tl_live" -eq 0 ] && break
    sleep 1; j=$((j + 1))
  done
  [ "$tl_live" -eq 1 ] && kill -9 "$tl_pid" 2>/dev/null || true
  # kill the sandbox init by exact PID (releases the AF_XDP bind). A dead
  # sandbox's sentry survives `runsc delete`; this is what lets a respawn
  # re-bind without EBUSY. runsc list column 2 is the PID.
  for p in $(awk -v id="$CID" '$1==id{print $2}' "$tl_out" 2>/dev/null); do
    [ -n "$p" ] && kill -9 "$p" 2>/dev/null || true
  done
  # bounded `runsc delete -f`: client RPC, same wedge class as list.
  "$RUNSC" --root="$STATE" --overlay2=none --ignore-cgroups delete -f "$CID" \
    2>/dev/null &
  tl_live=0; tl_pid=; j=0
  while [ "$j" -lt 3 ]; do
    tl_live=0
    for p in $(pgrep -x runsc 2>/dev/null); do
      cl=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null)
      case "$cl" in
        *"$STATE"*delete*) case "$cl" in *exec*) ;; *) tl_live=1; tl_pid=$p;; esac;;
      esac
    done
    [ "$tl_live" -eq 0 ] && break
    sleep 1; j=$((j + 1))
  done
  [ "$tl_live" -eq 1 ] && kill -9 "$tl_pid" 2>/dev/null || true
  # detach + unpin: local, fast, safe. The program's empty-sockmap guard
  # already auto-PASSes to the kernel while the socket is gone; a lingering
  # program is dead weight.
  ip xdp off dev "$DEV" 2>/dev/null || true
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
  plog "teardown done (exit path; execd respawns)"
  # v10: the pinned counters die with the program; drop the previous sample
  # so the next generation's first sample reports absolute values, not a
  # negative delta.
  rm -f "$BPSTAT" 2>/dev/null || true
  tailf_cleanup
}
trap teardown EXIT
# signal-driven teardown: brush's EXIT-trap-on-signal behavior is not relied
# on. The teardown is idempotent (every step || true / re-checks).
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

# --- v6: log file + the single detached serial forwarder -----------------------
# Must run before the first log()/fail() call below. The forwarder is a child
# of this script; on our exit it is orphaned to PID 1 (execd's reaper) and
# keeps running, so BOTH startup and teardown kill stale forwarders by the
# log path in their cmdline (never pgrep -f: it matches our own shell).
tailf_cleanup() {
  for p in $(pgrep -x tail 2>/dev/null); do
    case "$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null)" in
      *"$LOGF"*) kill -9 "$p" 2>/dev/null || true;;
    esac
  done
}
# bound the tmpfs log (a long-running supervisor would otherwise grow it into
# RAM). Truncate to the last 256 KiB once it passes 512 KiB. `tail -f` follows
# appends and, on shrink, rewinds to the new EOF, so the forwarder survives.
log_trim() {
  s=$(wc -c < "$LOGF" 2>/dev/null)
  [ -n "$s" ] && [ "$s" -gt 512000 ] && {
    tail -c 256000 "$LOGF" > "$LOGF.tmp" 2>/dev/null || true
    cat "$LOGF.tmp" > "$LOGF" 2>/dev/null || true
    rm -f "$LOGF.tmp" 2>/dev/null || true
  }
}
mkdir -p /run/sysnet 2>/dev/null || true
# v9: generation accounting. Each supervisor process is one generation: a
# fresh process means a fresh sandbox + fresh AF_XDP bind. GEN_START is the
# boot deadline's clock; the esc counter persists in /run/sysnet (host tmpfs
# — survives teardown, wiped on a full guest reboot); the RBOVR guard
# persists in /home (survives the reboot, so a reboot loop is detectable).
GEN_START=$(date -u +%s)
esc0=$(cat "$ESCF" 2>/dev/null); case "$esc0" in ''|*[!0-9]*) esc0=0;; esac
rbovr=$(cat "$RBOVR" 2>/dev/null); case "$rbovr" in ''|*[!0-9]*) rbovr=0;; esac
plog "supervisor start pid $$ esc=$esc0 rbovr=$rbovr"
echo "=== sysnet supervisor start $(date -u +%Y-%m-%dT%H:%M:%SZ) pid $$ ===" >> "$LOGF" 2>/dev/null || true
tailf_cleanup
tail -f "$LOGF" >&2 2>/dev/null &

# --- 0. preconditions ----------------------------------------------------------
[ -x "$RUNSC" ] || fail "runsc missing at $RUNSC"
[ -x "$LOADER" ] || fail "xdp_loader missing at $LOADER"
# v12: the queue-collapse tool (image regression -> the multi-queue RSS flap
# would silently reappear: q1 SYNs dropped at the door).
[ -x "$ETHTOOL" ] || fail "ethtool missing at $ETHTOOL"
[ -x /usr/sbin/ip ] || fail "iproute2 ip missing (libelf?)"
mountpoint -q /sys/fs/bpf || mount -t bpf bpf /sys/fs/bpf 2>/dev/null || true
mountpoint -q /sys/fs/bpf || fail "bpffs unavailable (no /sys/fs/bpf mount)"
mkdir -p "$STATE" "$B/rootfs" || fail "mkdir run state failed"
# PATH for runsc (and its child sentry): /usr/sbin (iproute2) must lead.
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

# --- 1. uplink: link UP, address/route OFF (the kernel is offline) -------------
# The uplink must be UP (xdp.go: FlagUp gate; the sentry needs the MAC) but
# carries NO IPv4 address and NO route: rust-dhcp owns the lease in the
# netstack, sshdt owns :22 in the netstack. Strip any lease a previous
# boot path left behind (defensive: a stale kernel addr would make the
# netstack the wrong IP authority).
ip link set "$DEV" up || fail "cannot bring $DEV up"
ip -4 addr flush dev "$DEV" 2>/dev/null || true
ip route flush dev "$DEV" 2>/dev/null || true
log "uplink: $DEV (link up, kernel offline)"

# --- 2. clean stale state (idempotent entry) -----------------------------------
"$RUNSC" --root="$STATE" --overlay2=none --ignore-cgroups delete -f "$CID" \
  2>/dev/null || true
ip xdp off dev "$DEV" 2>/dev/null || true
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
# v8: a fresh generation must not read the PREVIOUS generation's dp file
# (/run/sysnet is a host tmpfs that survives execd respawns): a stale fail/old
# file would hand the watchdog a head start toward DP_LIMIT. The new payload's
# dpmon recreates it within 10 s; until then its absence is startup grace
# (DPHAVEN=0 in dpark_check), not darkness.
rm -f "$DPF" 2>/dev/null || true
rm -f "$BPSTAT" 2>/dev/null || true   # v10: fresh generation, fresh counters

# --- 2b. collapse the uplink RX to queue 0 (v12: the multi-queue RSS fix) ------
# The chronic face-flap (root-caused on the live wire, Oct 5; v11 per-queue BPF
# counters, i-080664c2822b62628: slot0 pass=0/redirect=1465, slot1
# pass=788/redirect=0, 49%-dark face) is the ENA's 2-RX-queue RSS split:
# gvisor binds ONE AF_XDP socket at sockmap key 0 (runsc/sandbox/xdp.go:178,
# TODO(b/240191988)), ENA runs the XDP program per RX queue, so frames
# RSS-hashed to queue 1 hit the program with an EMPTY sockmap slot -> the
# sn-6e guard XDP_PASSes them to the fully-OFFLINE kernel -> dropped at the
# door. Each new inbound connection's 4-tuple hashes to q0/q1 ~50/50 -> ~50%
# of new SYNs never reach the netstack. That IS the flap.
#
# Fix: collapse the NIC to 1 RX queue so every inbound frame lands on queue 0
# (the one with the socket). The tool issues exactly the ioctl of
# `ethtool -L $DEV combined 1`: SIOCETHTOOL/ETHTOOL_SCHANNELS combined=1
# (packages/user/gvisor/ethtool.c). ENA does a full close/open + RSS table
# rebuild (ena_update_queue_count); virtio (QEMU, 1 queue) is a no-op.
#
# POSITION is load-bearing: the kernel's ethtool_set_channels checks
# netdev_queue_busy on the queues being REMOVED (ioctl.c) and -EINVALs if an
# AF_XDP socket leases one. So this must run BEFORE the XDP attach (section 4)
# -- here, where no socket exists yet (stale state was just torn down). It also
# must be before the sentry's bind, which re-arms the redirect at queue 0.
#
# The close/open drops the link briefly; wait for it to come back (the
# xdp_loader + sentry need the link UP + the MAC). Bounded: a carrier that
# never returns is a hard fail at the loader, not a supervisor hang.
log "collapse $DEV RX to 1 queue (v12 multi-queue RSS fix)"
if "$ETHTOOL" "$DEV" 1; then
  log "  $DEV combined=1 set"
  # Wait for the link to come back (bounded counter; no `seq` applet dep).
  st=""; c=0
  while [ "$c" -lt 20 ]; do
    st=$(ip -o link show "$DEV" 2>/dev/null | grep -oE 'state [A-Z]+' | awk '{print $2}')
    case "$st" in UP|UNKNOWN) break;; esac
    sleep 1; c=$((c + 1))
  done
  case "$st" in
    UP|UNKNOWN) log "  $DEV link back ($st)";;
    *) log "  WARNING: $DEV link not UP after 20 s (st=$st); proceeding (the loader will fail hard if it is unusable)";;
  esac
else
  log "  WARNING: ethtool $DEV 1 FAILED (rc=$?); the multi-queue RSS flap may persist (q1 SYNs dropped at the door)"
fi

# --- 3. bundle ------------------------------------------------------------------
# Minimal bundle rootfs. The two payloads are musl-DYNAMIC
# (PT_INTERP /lib/ld-musl-x86_64.so.1, NEEDED libc.musl + libunwind) —
# all three libs are staged into the bundle; musl finds them at the
# absolute PT_INTERP path + default /lib.
#
# /etc/{resolv.conf,hostname,hosts} MUST exist in the bundle: runsc setupNet
# bind-mounts host versions over them into the sandbox, and the gofer
# O_CREATs each mount point BEFORE the bind (P4 rule: a missing target on
# the read-only rootfs is a gofer fatal).
cat > "$B/config.json" <<'EOF'
{
  "ociVersion": "1.0.2",
  "process": {
    "args": ["/bin/busybox", "sh", "/sysnet-init.sh"],
    "env": ["PATH=/bin:/usr/bin:/sbin:/usr/sbin"],
    "cwd": "/",
    "capabilities": {
      "bounding":    ["CAP_NET_ADMIN", "CAP_NET_RAW"],
      "effective":   ["CAP_NET_ADMIN", "CAP_NET_RAW"],
      "permitted":   ["CAP_NET_ADMIN", "CAP_NET_RAW"],
      "inheritable": ["CAP_NET_ADMIN", "CAP_NET_RAW"]
    }
  },
  "root": { "path": "rootfs", "readonly": true },
  "hostname": "sysnet",
  "mounts": [
    { "type": "tmpfs", "source": "tmpfs", "destination": "/run",
      "options": ["mode=0755"] },
    { "type": "bind", "source": "/root/.ssh", "destination": "/root/.ssh",
      "options": ["rbind"] },
    { "type": "bind", "source": "/run/enclaved", "destination": "/run/enclaved",
      "options": ["rbind"] },
    { "type": "bind", "source": "/run/sysnet", "destination": "/run/sysnet",
      "options": ["rbind"] },
    { "type": "bind", "source": "/home/bootproof", "destination": "/home/bootproof",
      "options": ["rbind"] }
  ],
  "linux": {}
}
EOF
R="$B/rootfs"
mkdir -p "$R/bin" "$R/lib" "$R/etc" "$R/root/.ssh" "$R/run" 2>/dev/null \
  || fail "mkdir bundle rootfs failed"
# gofer bind targets (P4 rule)
for f in /etc/resolv.conf /etc/hostname /etc/hosts; do
  [ -f "$f" ] || fail "missing gofer bind target $f (image regression)"
  cp -f "$f" "$R$f" 2>/dev/null || fail "copy $f into bundle failed"
done
# binaries + musl runtime
cp -f /bin/busybox        "$R/bin/busybox"     || fail "copy busybox failed"
cp -f /usr/bin/dhcp-client "$R/bin/dhcp-client" || fail "copy dhcp-client failed"
cp -f /usr/bin/sshdt       "$R/bin/sshdt"       || fail "copy sshdt failed"
# bootproofd (S3 co-tenant): the netstack is the ONLY network face, so the
# :443 attestation face runs in THIS sandbox — the wire :443 arrives on
# eth0, the redirect program sends it to the netstack, bootproofd binds
# 0.0.0.0:443 (like sshdt:22). Its NEEDED libs (libc.musl + libunwind) are
# already staged above; PT_INTERP /lib/ld-musl-x86_64.so.1 is present.
cp -f /usr/bin/bootproofd  "$R/bin/bootproofd"  || fail "copy bootproofd failed"
chmod 755 "$R/bin/bootproofd" 2>/dev/null || true
# enclavectl (sn-7 provisioner-gap fix): the netstack is the ONLY stack with
# egress (the kernel netns is offline), so the IMDS user-data fetch must run
# INSIDE this sandbox. Its two NEEDED libs (libc.musl + libunwind) + the
# musl loader are already staged above for bootproofd; PT_INTERP
# /lib/ld-musl-x86_64.so.1 is present. It atomic-drops the blob to
# /run/enclaved/drop (bound rw above); the host enclaved daemon picks it up
# and writes /root/.ssh/authorized_keys.
cp -f /usr/bin/enclavectl  "$R/bin/enclavectl"  || fail "copy enclavectl failed"
chmod 755 "$R/bin/enclavectl" 2>/dev/null || true
# /home/bootproof bind source: the HOST dir (kernel-side), created here so
# runsc's gofer has a valid fd at `create` time. Which dir that fd points
# at depends on WHEN the kernel mounts LUKS over /home: sysnet depends on
# enclaved (the LUKS mounter, ready written after the mount), so on a data
# disk the host /home/bootproof lives on the persistent LUKS volume and the
# gofer fd follows it — the bootproof TLS identity then survives reboots
# (stable TOFU pin). On a no-disk boot it is the init tmpfs (identity
# re-mints, expected). The bundle rootfs also pre-creates /home/bootproof
# because the gofer O_CREATs a missing bind target and dies on a readonly
# fs (P4 rule); that placeholder is never the persistent store — only the
# host dir is. /run/enclaved + /run/sysnet need no host pre-creation:
# /run is the writable tmpfs, so the gofer creates them there.
mkdir -p "$R/home/bootproof" /run/enclaved /home/bootproof /run/sysnet 2>/dev/null \
  || fail "mkdir bootproofd bind targets failed"
cp -f /lib/ld-musl-x86_64.so.1  "$R/lib/" || fail "copy ld-musl failed"
cp -f /lib/libc.musl-x86_64.so.1 "$R/lib/" || fail "copy libc.musl failed"
cp -f /lib/libunwind.so.1        "$R/lib/" || fail "copy libunwind failed"
chmod 755 "$R/bin/busybox" "$R/bin/dhcp-client" "$R/bin/sshdt" 2>/dev/null || true
# busybox APPLET SYMLINKS (load-bearing): the payload + probe call bare
# `sleep`, `grep`, `sed`, `nc`, `kill`, `sh`, `ip` — a bare busybox binary
# without the /bin/<applet> symlinks has none of those, so `sleep 1` is
# "not found" and the 60-iteration lease-wait loop burns through in <1 s ->
# the payload exits 1 every ~15 s (3 x liveness poll) and crash-loops.
# Copy the guest's REAL /bin applet symlinks (each -> busybox) into the
# bundle; do NOT parse `busybox`'s usage text (that yields garbage names).
for f in /bin/*; do
  b=${f##*/}
  case "$b" in busybox) continue;; esac
  [ -L "$f" ] && ln -sf busybox "$R/bin/$b" 2>/dev/null || true
done
ln -sf busybox "$R/bin/sh" 2>/dev/null || true
ln -sf /bin/busybox "$R/sh" 2>/dev/null || true
# /root/.ssh bind target: the DIRECTORY bind shows the host's
# authorized_keys the moment enclaved writes it. The placeholder file is
# the gofer mount-point (must exist in the rootfs); it is shadowed by the
# bind and is never read.
: > "$R/root/.ssh/authorized_keys" 2>/dev/null || true
# host-side bind SOURCE must exist before runsc create (a missing source
# kills the sandbox at "cannot read client sync file: EOF").
mkdir -p /root/.ssh || fail "mkdir /root/.ssh (host) failed"
# payload: rust-dhcp owns the lease in the netstack; sshdt is the guest's
# only SSH server (fail-closed on the key, like the old kernel unit).
cat > "$R/sysnet-init.sh" <<'EOF'
#!/bin/busybox sh
# sysnet sandbox payload (sn-7): the netstack is the only stack on the wire.
# 0. LLA bootstrap (load-bearing): the netstack cannot originate a limited
#    broadcast (255.255.255.255) from a NIC with no v4 address (FindRoute
#    needs a primary endpoint -> ErrNetworkUnreachable; the kernel's implicit
#    on-link 0.0.0.0 broadcast route has no netstack equivalent). Add
#    169.254.2.2/16 to eth0 so rust-dhcp's DISCOVER has a source to route
#    from; 255.255.255.255 resolves to the broadcast MAC (ARP
#    ResolveStaticAddress) so it reaches slirp. Slirp replies to the DHCP
#    ciaddr (0.0.0.0), not the IP source. Removed once the real lease lands
#    so the lease is the sole egress source.
# 1. rust-dhcp (backgrounded child): DORA + T1/T2 renewals in-process; applies
#    the lease (addr, default route, DNS) to the netstack via rtnetlink
#    (CAP_NET_ADMIN). The netstack's AF_XDP NIC is named for the uplink.
#    stdout/stderr -> /run/dhcp.log (env_logger, default info): the sandbox's
#    own stdio is discarded by runsc start, so this file is the ground truth.
# 2. Bounded wait for the lease (169.254.2.2 GONE + a real inet on eth0): a
#    netstack with no lease has no identity, no egress, and no IMDS (AWS) —
#    fail (respawn -> re-DORA) rather than serve SSH with no address to
#    route to.
# 3. Bounded wait for the authorized key (fail-closed: an EMPTY key list makes
#    sshdt accept ANONYMOUS connections). The key is written by the host
#    enclaved daemon (config drive in QEMU, IMDS on AWS — which itself goes
#    through THIS netstack).
# 4. sshdt: the guest's only SSH server, bound 0.0.0.0:22 in the netstack.
echo "sysnet-payload: up"
# /run is a fresh tmpfs in the sandbox (no nit to pre-create /run/ssh):
# sshdt auto-generates its per-boot host key at /run/ssh/host_ed25519.
/bin/busybox mkdir -p /run/ssh 2>/dev/null || true
LLA=169.254.2.2
/bin/busybox ip -4 addr add "$LLA"/16 dev eth0 2>/dev/null || true
/bin/dhcp-client eth0 >/run/dhcp.log 2>&1 &
DHCP_PID=$!
i=0
# eth0 specifically: `ip -4 addr show | grep inet` matches LOOPBACK's
# 127.0.0.1/8 immediately (the netstack always has lo up), so the wait would
# exit in 0 iterations and the "no lease" fail path below would be dead code.
# The lease = a real inet on eth0 that is NOT the LLA: the LLA and the real
# lease COEXIST (multi-address works in the netstack — proven on the wire:
# both 169.254.2.2/16 and 10.0.2.15/24 present, default via 10.0.2.2 up).
# The LLA is NEVER removed: it is the netstack's permanent primary address,
# which is exactly what a re-DORA's DISCOVER needs to route after the lease
# is ever revoked (rust-dhcp undo_lease removes only the lease IP; with no
# primary left the netstack could not originate a new limited broadcast).
# It is harmless for real egress: the default route selects 10.0.2.15 as the
# source for non-local destinations; the LLA route serves 169.254.x only.
while :; do
  A=$(/bin/busybox ip -4 -o addr show eth0 2>/dev/null)
  if echo "$A" | grep 'inet ' | grep -qv "$LLA"; then break; fi
  sleep 1
  i=$((i + 1))
  [ "$i" -ge 90 ] && break
done
if echo "$A" | grep 'inet ' | grep -qv "$LLA"; then
  echo "sysnet-payload: eth0 lease acquired in netstack (LLA $LLA kept as re-DORA primary):"
  /bin/busybox ip -4 -o addr show eth0 2>/dev/null
  # LOAD-BEARING (root-caused on the wire, disk5): rust-dhcp's add_route sets
  # the gateway but NO output interface, so the netstack stored
  # "default via GW scope link" with oif=0 — visible in the probe dump, and
  # unusable for forwarding (B=8.8.8.8:443 FAIL while A=GW:22 PASS via the
  # link route). Re-add the default with the device; NLM_F_REPLACE is
  # synchronous netlink. GW from the dhcp log (NOT hardcoded: AWS has a
  # different gateway), not from a route parse (the stored one is the broken
  # oif-less one).
  GW=$(tail -n 50 /run/dhcp.log 2>/dev/null | grep -oE "Gateway: [0-9.]+" | tail -n 1 | awk '{print $2}')
  if [ -n "$GW" ]; then
    /bin/busybox ip -4 route replace default via "$GW" dev eth0 2>/dev/null || true
    echo "sysnet-payload: default route re-added with dev: $(/bin/busybox ip -4 route show 2>/dev/null | grep -E '^default')"
    # IMDS host-route (provisioner-gap fix, pitfall 17): the LLA 169.254.2.2/16
    # makes IMDS 169.254.169.254 ON-LINK to the netstack -> it ARPs for it and
    # never gets an answer (IMDS is hypervisor-virtualized, not L2-reachable)
    # -> the in-sandbox IMDS fetch hangs. A more-specific /32 via the GW forces
    # L3 through the GW MAC (already pinned permanent before the XDP attach)
    # so the in-netstack enclavectl below can reach the metadata service.
    /bin/busybox ip -4 route replace 169.254.169.254 via "$GW" dev eth0 2>/dev/null \
      || echo "sysnet-payload: WARNING: IMDS host-route add failed" >&2
  else
    echo "sysnet-payload: WARNING: no gateway in /run/dhcp.log; default route may lack a device (egress broken)" >&2
  fi
else
  echo "sysnet-payload: NO eth0 lease in netstack after 90 s" >&2
  echo "  eth0 addrs: $A" >&2
  echo "  dhcp log tail:" >&2
  /bin/busybox tail -n 30 /run/dhcp.log >&2 2>/dev/null
  kill "$DHCP_PID" 2>/dev/null
  exit 1
fi
# bootproofd co-tenant (S3): started here, not by a kernel-side unit — the
# kernel is offline and cannot reach the netstack's :443, so the sn-6 model
# (own sandbox + kernel DNAT) is impossible by construction. The restart
# loop retries until the enclaved evidence socket exists (enclaved binds it
# seconds after boot); bootproofd takes no args (defaults: --listen
# 0.0.0.0:443, --state /home/bootproof, --socket /run/enclaved/sock — both
# bound into this sandbox above).
( while :; do /bin/bootproofd >>/run/bootproofd.log 2>&1; sleep 2; done ) &
# provisioner-gap fix (Oct 3 wire finding: 330 s death/respawn loop on the
# live wire — the kernel-side provisioner's --network=host netns is the one
# sn-7 took OFFLINE, so its IMDS fetch has no egress, authorized_keys never
# lands, and the key-wait below expires every generation). The netstack is
# the ONLY stack with egress, so the fetch runs HERE: enclavectl provision
# (no args; staged above) does the full IMDSv2+IMDSv1 chain (bounded 120 s
# deadline, no unbounded connects) with the seed fallback (QEMU), then
# atomic-drops the blob to /run/enclaved/drop (bound rw above) — the host
# enclaved daemon (kernel-side, no egress needed) picks it up within 2 s and
# writes /root/.ssh/authorized_keys. Backgrounded like the other co-tenants:
# a one-shot, its own deadline bounds it; the 300 s key-wait below already
# covers its runtime. stdout/stderr -> /run/enclavectl.log (the sandbox stdio
# is discarded by runsc start). FAIL-OPEN: if it never lands the drop, the
# key-wait expires and the sandbox respawns (the pre-fix behavior).
#
# SOURCE-IP FIX (Oct 3 wire root cause, 142-generation :9004 capture + gvisor
# source): the LLA 169.254.2.2/16 is a permanent eth0 primary (the re-DORA
# bootstrap). gvisor's source selection (acquirePrimaryAddressRLocked,
# addressable_endpoint_state.go) picks the NIC primary with the LONGEST
# matching prefix for the destination, so for a dest in 169.254.0.0/16 (IMDS)
# the LLA (16-bit match) BEATS the lease (0-bit) and EVERY IMDS SYN goes out
# the wire sourced from 169.254.2.2 -- a link-local that is NOT the ENI's
# IP. The AWS VPC/metadata path drops it (deterministic: 142/142 generations
# with the correct via-GW route present; route selection is
# longest-prefix-first so the L3 path was already right). QEMU never
# reproduces it: slirp does not validate source IPs; the VPC does. The
# source is chosen from the NIC's primary ADDRESSES, independent of the route
# table, so the only levers are (a) remove the LLA primary or (b) a source
# hint. The source-hint path is DEAD for this payload: the netstack input
# parser (localRoute, netstack/stack.go) honors RTA_SRC (-> SourceHint, which
# "takes precedent over prefix matching" in acquirePrimaryAddressRLocked), but
# busybox 1.38's `ip route src ADDR` emits RTA_PREFSRC (iproute.c:414; its
# RTA_SRC branch is #if 0 dead code) and RTA_PREFSRC falls into the parser's
# default -> ErrNotSupported ("RTNETLINK answers: Not supported", proven live
# in the sandbox). iproute2 (the one emitter that sends RTA_SRC) is not in the
# sysnet sandbox rootfs (/usr/sbin/ip not found). So the fix is to make the
# LLA not a primary for the fetch's duration: remove it, run enclavectl,
# re-add it. The re-DORA path re-adds the LLA at the top of every payload run
# anyway (see above), so a crash inside the window is not a permanent loss.
( /bin/busybox ip -4 addr del "$LLA"/16 dev eth0 2>/dev/null || true
  /bin/enclavectl provision >>/run/enclavectl.log 2>&1 &
  # Bounded wait for enclavectl (the v5 discipline: background + poll /proc,
  # never waitpid a child that could wedge; brush's `wait <pid>` is broken
  # anyway, rc 99). enclavectl's own 120 s deadline is the expected bound;
  # the 150 s poll is the kill fallback if it ever exceeds it. `pgrep -x`
  # matches comm exactly (the subshell's comm is "sh", never self-matches).
  j=0
  while /bin/busybox pgrep -x enclavectl >/dev/null 2>&1; do
    sleep 1
    j=$((j + 1))
    if [ "$j" -ge 150 ]; then /bin/busybox pkill -9 -x enclavectl 2>/dev/null || true; break; fi
  done
  # Re-add the LLA no matter how enclavectl exited (fail-open re-DORA).
  # EEXIST (a respawn already re-added it) is harmless -- || true.
  /bin/busybox ip -4 addr add "$LLA"/16 dev eth0 2>/dev/null || true
) &
# v7 obs channel (Oct 2 wire finding): the serial console is NOT a reliable
# window into the supervisor — on the live wire the console froze at
# 40206 B (below the 64KB cap) for 40+ min while the sandbox/netstack stayed
# ALIVE (attestation PROVEN, :443 serving), so /run/sysnet/log was the only
# ground truth and it was unreachable without SSH (provisioner gap). This
# serves the HOST /run/sysnet dir (the supervisor's log file lives there,
# bind-mounted above) over plain HTTP on :9004, INSIDE the netstack: the
# redirect program diverts every frame class to the sandbox (v3 has no pass
# class), so host :9004 -> netstack -> this httpd, no BPF change. Static
# file server only (busybox httpd -h), no shell, no upload: `curl
# http://<ip>:9004/log` reads the supervisor's live log from the wire.
( while :; do /bin/busybox httpd -p 0.0.0.0:9004 -h /run/sysnet >>/run/httpd.log 2>&1; sleep 2; done ) &
# v8: data-plane monitor (see sysnet-dpmon.sh above). Background co-tenant
# like the others: it probes external egress, so until the lease lands the
# connect fails and the file says "fail" — that is startup, not a wedge
# (the armed dpark_check model ignores dark until the first healthy pass).
# Starting it here (before the key-wait) means the file exists from the
# earliest useful moment.
( /bin/busybox sh /sysnet-dpmon.sh >>/run/dpmon.log 2>&1 ) &
i=0
while [ ! -s /root/.ssh/authorized_keys ] && [ "$i" -lt 300 ]; do
  sleep 1
  i=$((i + 1))
done
if [ ! -s /root/.ssh/authorized_keys ]; then
  echo "sysnet-payload: no authorized_keys after 300 s" >&2
  kill "$DHCP_PID" 2>/dev/null
  exit 1
fi
# foreground: when sshdt exits the payload exits -> sandbox stops -> execd
# respawns (the shell, still init, reaps the backgrounded dhcp-client).
/bin/sshdt --no-config --port 22 --bind 0.0.0.0 \
  --host-key /run/ssh/host_ed25519 \
  --authorized-keys /root/.ssh/authorized_keys
EOF
chmod 755 "$R/sysnet-init.sh" 2>/dev/null || true
# probe script (runsc exec after start; must exist BEFORE create so the
# gofer can serve it). The sandbox's own stdio is discarded by runsc start,
# so THIS exec is the only way netstack state reaches the serial. It is the
# diagnostic: eth0 lease (the load-bearing assumption), routes, authorized
# key, in-netstack sshdt banner (isolates netstack-vs-XDP/hostfwd). It does
# NO wire `nc` (v4): the wire probes (A/B/C) were removed after four
# instances froze the console at a wire probe in a netstack flap window,
# unreapable even by SIGKILL. LOCAL ops only (to the netstack's own IP /
# files), which cannot hang. Egress/flap is measured host-side.
# eth0-specific lease check: `ip -4 addr show | grep inet` matches loopback's
# 127.0.0.1/8 immediately (netstack always has lo up) and would falsely report
# a lease.
cat > "$R/sysnet-probe.sh" <<'EOF'
#!/bin/busybox sh
echo "  [sbx] diag"
echo "  [sbx] eth0 inet:"
/bin/busybox ip -4 -o addr show eth0 2>/dev/null | sed 's/^/    /' || echo "    (none)"
if ! /bin/busybox ip -4 -o addr show eth0 2>/dev/null | grep -q 'inet '; then
  echo "    ^^ NO eth0 LEASE (rust-dhcp did not apply the lease to the netstack)"
fi
echo "  [sbx] routes:"
/bin/busybox ip route show 2>/dev/null | sed 's/^/    /'
echo "  [sbx] rust-dhcp log (last 12):"
/bin/busybox tail -n 12 /run/dhcp.log 2>/dev/null | sed 's/^/    /' || echo "    (no /run/dhcp.log)"
IP=$(/bin/busybox ip -4 -o addr show eth0 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
echo "  [sbx] bootproofd :443 (co-tenant):"
/bin/busybox pgrep -x bootproofd >/dev/null 2>&1 && echo "    running" || echo "    NOT RUNNING"
/bin/busybox tail -n 3 /run/bootproofd.log 2>/dev/null | sed 's/^/    /'
echo "    :443 banner (3 bytes, hex):"
/bin/busybox nc -w 3 "$IP" 443 </dev/null 2>/dev/null | head -c 3 | od -An -tx1 | sed 's/^/      /' || echo "      (nc failed)"
K=/root/.ssh/authorized_keys
if [ -s "$K" ]; then echo "  [sbx] authorized_keys: present ($(wc -c < "$K") bytes)"; else echo "  [sbx] authorized_keys: ABSENT (sshdt not started yet)"; fi
echo "  [sbx] enclavectl provision (in-netstack provisioner):"
/bin/busybox pgrep -x enclavectl >/dev/null 2>&1 && echo "    running (IMDS chain in progress; 120 s deadline)" || echo "    done (or not started)"
# Source-IP state (Oct 3 wire root cause, 142-gen :9004 capture): WITH the LLA
# present the netstack source-selects it for 169.254.0.0/16 dests (longest
# prefix) -> IMDS SYNs go out from a non-ENI link-local and the VPC drops them.
# The fix removes the LLA for the fetch's duration; report which state now.
/bin/busybox ip -4 -o addr show eth0 2>/dev/null | grep -q "169.254.2.2" && echo "    LLA present (IMDS SYNs would be LLA-sourced -- pre-fix state)" || echo "    LLA removed (IMDS SYNs lease-sourced)"
/bin/busybox tail -n 6 /run/enclavectl.log 2>/dev/null | sed 's/^/    /' || echo "    (no /run/enclavectl.log)"
D=/run/enclaved/drop
if [ -s "$D" ]; then echo "    drop: pending ($(wc -c < "$D") bytes)"; else echo "    drop: absent (applied, rejected, or not yet delivered)"; fi
IP=$(/bin/busybox ip -4 -o addr show eth0 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
if [ -n "$IP" ]; then
  echo "  [sbx] in-netstack sshdt banner from $IP:22 (first 40 bytes):"
  /bin/busybox nc -w 4 "$IP" 22 </dev/null 2>/dev/null | head -c 40 | sed 's/^/    /'
  echo
fi
# NO wire `nc` probes here (A = GW:22, B = 8.8.8.8:443, and the earlier
# C = IMDS are all GONE — v4, Oct 2). Wire-proven across FOUR instances
# (gen-1 @ A, v1 @ C, v2 @ C, v3 @ A, disk 31c38a88): any in-sandbox
# WIRE op landing in a netstack data-plane flap window hangs in an
# uninterruptible wait that NOT even `timeout -s KILL` on the outer
# `runsc exec` can reap (the runsc client sits in a kernel D-state on
# the exec RPC the sentry can't complete), so the single-threaded
# supervisor + serial console freeze while the netstack face stays
# ALIVE + flapping. C was the worst (IMDS is on-link in the
# 169.254.2.2/16 -> ARP blackhole, hung every time) but A (a
# reachable GW) froze identically once C was gone. LOCAL in-sandbox
# ops — the `nc`s to the netstack's OWN lease IP above, the file
# reads, the banners — completed in every cycle including the frozen
# ones, so they stay: they are the in-guest flap visibility. The
# egress/flap signal is measured HOST-side (the `:443` 200/000 probe),
# not from a periodic in-sandbox wire probe.
EOF
chmod 755 "$R/sysnet-probe.sh" 2>/dev/null || true
# v8: the data-plane monitor (see the DP_* globals). A plain background
# process INSIDE the sandbox — deliberately NOT a runsc exec (the v5 wedge
# vector was the exec RPC channel; a background child wedging costs nothing,
# it just stops updating the file). ONE probe: a real external TCP connect
# to 8.8.8.8:443. It is a ROUND TRIP — the SYN goes OUT the uplink (TX path:
# netstack -> wire) and the SYN-ACK must come BACK IN (RX path: wire ->
# redirect socket -> netstack). So it catches every wedge mode the wire data
# shows (TX wedge, RX fill-ring stall, sockmap drop): any of them breaks the
# round trip -> the connect fails or hangs. A HANG is the expected wedge
# signature (nc -w does NOT bound a blocked connect, pitfall 20) — a hung
# dpmon stops writing -> the file goes STALE -> the kernel-side supervisor
# counts dark -> respawn. Staleness is the bound, not the probe.
# EGRESS-ONLY (no SELF :443 probe): egress is a superset signal. It has no
# co-tenant dependency (a SELF probe to bootproofd:443 would false-dark while
# bootproofd is still retrying at boot) and it tests the actual WIRE path in
# both directions (a SELF connect only tests the netstack's local loopback).
# A 120 s continuous-dark threshold (DP_LIMIT) also absorbs any transient
# upstream blip to 8.8.8.8 (a false respawn is cheap + safe; teardown +
# recreate is the only in-guest reset anyway).
# The result file is /run/sysnet/dp — the SAME bind-mounted dir the kernel
# uses for the supervisor log (v7-obs: writes through this bind are visible
# on both sides, proven on the wire). Format: "<epoch> <pass|fail>".
cat > "$R/sysnet-dpmon.sh" <<'EOF'
#!/bin/busybox sh
DP=/run/sysnet/dp
while :; do
  # pass = AT LEAST ONE external target reachable (a single upstream outage
  # must not false-trigger the watchdog; a wedge breaks the path to ALL of
  # them). nc -w does not bound a blocked connect (pitfall 20): a wedge that
  # hangs the connect hangs dpmon here -> the file goes stale -> dark.
  if /bin/busybox nc -z -w 8 8.8.8.8 443 2>/dev/null \
    || /bin/busybox nc -z -w 8 1.1.1.1 443 2>/dev/null; then
    res=pass
  else
    res=fail
  fi
  # Atomic publish (tmp + rename): the supervisor and the :9004 httpd read
  # $DP from other processes — a plain `> "$DP"` (truncate + write) has a
  # window where a concurrent reader sees an empty file. Empty is harmless
  # (dpark_check treats it as "no fresh pass" and the next read resets), but
  # rename(2) closes it for free.
  echo "$(date -u +%s) $res" > "$DP.tmp" 2>/dev/null && mv -f "$DP.tmp" "$DP" 2>/dev/null
  sleep 10
done
EOF
chmod 755 "$R/sysnet-dpmon.sh" 2>/dev/null || true

# --- 4. pin the redirect program on the uplink (loader) -------------------------
# xdp_loader loads + pins program/sockmap/link under /sys/fs/bpf/eth0/ and
# attaches the program (driver mode on virtio-net). The v3 program redirects
# EVERY frame once the sentry's AF_XDP socket is in the map; the empty-
# sockmap guard keeps the pre-start / sandbox-death windows safe.
log "pin redirect on $DEV"
"$LOADER" redirect -device "$DEV" || fail "xdp_loader redirect failed"
[ -e "$PIN/redirect_ip_map" ] || fail "redirect map not pinned"

# --- 5. runsc create + start (redirect mode) ------------------------------------
# create+start (not `do`): a supervised long-lived service the unit can poll
# and teardown can delete. The uplink has 0 IPv4 addresses (kernel offline):
# xdp-4 relaxes the 1-address requirement so the sandbox NIC starts empty.
#
# --host-uds=open is LOAD-BEARING for the S3 co-tenant evidence channel:
# bootproofd (in the sandbox) connects to enclaved's kernel-side collect
# socket at /run/enclaved/sock (a bind-mounted host UDS). A Unix stream
# connect() routes through the gofer's CONNECT RPC (fsgofer lisafs.go
# Connect), which REFUSES with EPERM unless --host-uds permits open; the
# sentry flattens that EPERM to ECONNREFUSED (gofer/socket.go newSender).
# Default is `none`, so without this flag the co-tenant's evidence path is
# dead (`collect daemon unreachable ... NOT PROVEN`, /attestation
# evidence:[]). The bundle binds no other host UDS (erofs root is RO, no
# sockets), so the surface is exactly the enclaved collect socket.
#
# -net-raw + -allow-packet-socket-write are LOAD-BEARING for rust-dhcp:
#   * its ARP (arp crate: arp_probe/announce_address) opens AF_PACKET
#     SOCK_RAW, gated on CAP_NET_RAW (pkg/sentry/socket/netstack/
#     provider.go) — and runsc STRIPS CAP_NET_RAW from the spec unless
#     -net-raw is passed (runsc/config/flags.go:162, default false,
#     loader.go:545 specutils.Capabilities(EnableRaw, ...));
#   * AF_PACKET WRITES (the ARP announce on lease apply) additionally fail
#     unless -allow-packet-socket-write (flags.go:163, default false).
#   * rtnetlink RTM_NEWADDR/RTM_NEWROUTE (the lease apply) needs CAP_NET_ADMIN
#     (pkg/sentry/socket/netlink/route/protocol.go) — carried by the bundle
#     capabilities. Without these three, rust-dhcp gets no lease -> no
#     egress -> no SSH.
log "create (redirect:$DEV)"
"$RUNSC" --root="$STATE" --overlay2=none --ignore-cgroups --TESTONLY-unsafe-nonroot \
  --network=sandbox --EXPERIMENTAL-xdp="redirect:$DEV" -net-raw \
  --allow-packet-socket-write --host-uds=open \
  create --bundle "$B" "$CID" < /dev/null >/dev/null 2>&1
CRE=$?
[ "$CRE" -eq 0 ] || { log "create rc=$CRE"; exit 1; }
log "start (redirect:$DEV)"
"$RUNSC" --root="$STATE" --overlay2=none --ignore-cgroups --TESTONLY-unsafe-nonroot \
  --network=sandbox --EXPERIMENTAL-xdp="redirect:$DEV" -net-raw \
  --allow-packet-socket-write --host-uds=open \
  start "$CID" < /dev/null >/dev/null 2>&1
STA=$?

# --- 6. start-failure safety path ------------------------------------------------
# If start failed, the program is attached with an EMPTY socket map. The
# guard (sn-6e) keeps that safe (auto-PASS to the kernel) — but the kernel
# is offline, so the data plane is dark until respawn. Detach + unpin now;
# the non-zero exit makes execd respawn from a clean state.
if [ "$STA" -ne 0 ];
  then
    log "start rc=$STA: detach + unpin (guard PASSes to the offline kernel)"
    ip xdp off dev "$DEV" 2>/dev/null || true
    rm -f "$PIN/redirect_ip_map" "$PIN/redirect_program" "$PIN/redirect_link" 2>/dev/null || true
    rmdir "$PIN" 2>/dev/null || true
    exit 1
  fi

# --- 7. wait for running (non-blocking; poll runsc list) ------------------------
# v5 (Oct 2): NEITHER runsc child (exec NOR list) may ever be WAITED ON.
# Wire-proven across FIVE instances (gen-1@A, v1@C, v2@C, v3@A, v4@plain-echo):
# when the sentry/netstack data plane is in a bad window, the runsc client
# wedges in a kernel wait on the exec/list RPC and NEVER EXITS — so both
# `timeout` (which blocks in waitpid AFTER sending the signal) and a bare
# `wait` block the supervisor forever, freezing liveness + serial console.
# v4 (local-only probe, zero wire ops, frozen at a plain echo) killed the
# "wire-nc is the vector" hypothesis: the vector is the SYNCHRONOUS WAIT on
# a wedged runsc child. The fix is structural: background the runsc child,
# poll /proc/PID (non-blocking), kill -9 at the deadline. A wedged probe
# then costs at most a leaked zombie — the supervisor never blocks on it.
# (The `timeout -s KILL` backstop inside run_probe stays: it SIGKILLs the
# client at the deadline even if our own kill raced; we just never wait.)
# v6: the v5 body used `rl_pid=$!` to bound the list child — but brush does
# NOT set $! (empty), so /proc/$rl_pid was always true (a FIXED 5 s per call,
# doubling the liveness-loop period) and `kill -9 ""` was a no-op (leaked
# runsc-list zombies). The verdict (awk over $rl_out) was still correct, but
# the latency + leak were real. Same fix as run_probe: find the REAL pid via
# `pgrep -x runsc` + a cmdline that carries our state root AND the `list`
# subcommand (NOT `exec` — that is run_probe's child, a different sandbox
# call), poll /proc non-blocking, kill -9 the real pid at the deadline.
is_running() {
  rl_out=/tmp/.sysnet-list
  rm -f "$rl_out" 2>/dev/null
  "$RUNSC" --root="$STATE" --overlay2=none --ignore-cgroups \
    list 2>/dev/null > "$rl_out" &
  j=0
  while [ "$j" -lt 5 ]; do
    rl_live=0
    for p in $(pgrep -x runsc 2>/dev/null); do
      cl=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null)
      case "$cl" in
        *"$STATE"*list*) case "$cl" in *exec*) ;; *) rl_live=1; rl_pid=$p;; esac;;
      esac
    done
    [ "$rl_live" -eq 0 ] && break
    sleep 1; j=$((j + 1))
  done
  [ "$rl_live" -eq 1 ] && kill -9 "$rl_pid" 2>/dev/null || true
  awk -v id="$CID" '$1==id{print $3}' "$rl_out" 2>/dev/null | grep -qi running
}
# run_probe: the ONLY path from the sandbox to the serial (the sandbox's own
# stdio is discarded by runsc start). Bounded the NON-BLOCKING way (v5):
# background, poll /proc, kill -9 at the deadline — the supervisor NEVER
# waitpids the probe, so a wedged exec channel (the v1-v4 console-freeze
# vector) cannot freeze liveness or the console again.
# v6: (a) the probe's output goes to $LOGF (tmpfs), NOT the serial — the ~60
#      line dump was the supervisor's largest single serial writer and the
#      v5 final-stall vector (serial backpressure); it now rides the detached
#      forwarder. (b) brush does not set $!, so v5's kill -9 "$pr_pid" was a
#      NO-OP (empty pid) and its "kill -9" log line fired unconditionally
#      ([ -d /proc/ ] is always true). The actual bound was `timeout -s KILL`.
#      v6 finds the REAL pid via `pgrep -x runsc` + the probe script in the
#      cmdline and kills it, and the log line is now honest (fires only when a
#      probe is actually still alive at the deadline). A fast probe breaks the
#      poll loop early (probe gone) and logs no wedge; only a probe alive at
#      every poll up to ~19s (just under the 20s `timeout -s KILL`) counts.
run_probe() {
  timeout -s KILL 20 "$RUNSC" --root="$STATE" --overlay2=none --ignore-cgroups \
    exec "$CID" /bin/busybox sh /sysnet-probe.sh >> "$LOGF" 2>&1 &
  j=0
  while [ "$j" -lt 20 ]; do
    probe_live=0
    for p in $(pgrep -x runsc 2>/dev/null); do
      tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | grep -q 'sysnet-probe.sh' && { probe_live=1; probe_pid=$p; }
    done
    [ "$probe_live" -eq 0 ] && break
    sleep 1; j=$((j + 1))
  done
  if [ "$probe_live" -eq 1 ]; then
    WEDGE=$((WEDGE + 1))
    log "probe still running after 20 s: kill -9 (wedged exec channel; wedge $WEDGE/$WEDGE_LIMIT; supervisor continues)"
    kill -9 "$probe_pid" 2>/dev/null || true
  else
    WEDGE=0
    log_trim
  fi
  [ "$WEDGE" -ge "$WEDGE_LIMIT" ] && {
    log "WEDGE_LIMIT ($WEDGE_LIMIT) consecutive wedged probes: respawning the netstack (exit -> teardown)"
    exit 1
  }
}
# v8: data-plane dark check (see the DP_* globals). Reads the dp file the
# sandbox's dpmon writes (bind-mounted /run/sysnet) — NO runsc, NO netstack,
# so THIS path cannot wedge (the whole point: the process-based is_running
# cannot see a wedged-but-alive netstack, but a stale/fail dp file can).
# Armed model (DPHAVEN): a FRESH "pass" (< DP_STALE s old) sets DPHAVEN=1
# and returns light; with no fresh pass the check returns light until the
# face has been healthy at least once (boot: dpmon writes "fail" for tens of
# seconds before the lease/egress land — that is not a wedge, it is startup)
# and dark afterwards (healthy -> sustained dark = the terminal state the
# Oct 3 wire data showed, 23 h unrecovered). File format "<epoch> <pass|
# fail>"; the epoch (not the fs mtime) is the age source, so a bind-mount
# mtime quirk can't mask staleness. Returns 0=light, 1=dark.
dpark_check() {
  dp_now=$(date -u +%s)
  dp_e=""; dp_st=""
  [ -s "$DPF" ] && read -r dp_e dp_st < "$DPF" 2>/dev/null || true
  case "$dp_e" in
    ''|*[!0-9]*) : ;;  # corrupt/unreadable -> fall through to the armed check
    *)
      [ "$dp_st" = "pass" ] && [ $(( dp_now - dp_e )) -le "$DP_STALE" ] && {
        [ "$DPHAVEN" -eq 0 ] && plog "dpmon first pass (egress healthy)"
        DPHAVEN=1
        # v9: the wedge is gone (a fresh egress round trip just succeeded), so
        # the escalation count for THIS boot is void and the reboot-loop guard
        # clears too (a healthy period is exactly what RBOVR counts the ABSENCE
        # of). esc is the host tmpfs — cleared here, and by the reboot itself.
        echo 0 > "$ESCF" 2>/dev/null || true
        rm -f "$RBOVR" 2>/dev/null || true
        return 0
      }
      ;;
  esac
  [ "$DPHAVEN" -eq 0 ] && {
    # v9: BOOT DEADLINE (DPBOOT). The armed model (DPHAVEN) never arms a
    # generation that never passes egress — no lease -> dpmon all-fail ->
    # DPHAVEN stays 0 -> infinite startup grace, the watchdog unarmable.
    # 300 s without a single fresh pass is broken, not slow (a healthy gen
    # passes within seconds of its lease; the whole boot is well under 300 s).
    # GEN_START is always > 0 (set at supervisor start, date +%s).
    [ $(( dp_now - GEN_START )) -ge "$DPBOOT" ] && return 1
    return 0   # startup grace (under the deadline)
  }
  return 1                           # was healthy, no fresh pass: dark
}
# v11: sample the v5 per-queue BPF counter map (see the BPCOUNT globals).
# Kernel-side read only -- bpfcount does a bpf(2) BPF_MAP_LOOKUP_ELEM on the
# pinned redirect_counts map; no runsc, no netstack, nothing that can wedge.
# Called every liveness iteration (~5 s) so the per-5 s deltas line up with
# the dp watchdog's timeline and the host's dark-window probe.
#
# bpfcount emits 32 space-separated u32s: for each RX queue slot 0..15, the
# pass counter then the redirect counter (p0 r0 p1 r1 ... p15 r15). ENA runs
# the program per RX queue, so slot N is queue N's own frame counter at the
# decision point -- the multi-queue RSS discriminator. The confirmation line
# (gvisor binds one socket at key 0 on a 2-queue ENA): q0 redirect climbs,
# q1 pass climbs (queue 1 has no socket -> the sn-6e guard XDP_PASSes it to
# the offline kernel -> dropped). Logs the DELTAS as two 16-slot comma-lists:
#   [bp] dp=<pass deltas q0..q15> dr=<redirect deltas q0..q15>
# (machine-parseable; the host-side monitor correlates these with face state).
# Best-effort: a missing pin (v3/v4 object, or pre-attach) logs a single
# "absent" line (BPSEEN cap) and never blocks or fails the supervisor.
count_sample() {
  [ -x "$BPCOUNT" ] || return 0
  # v13-supervisor (Oct 6 wire): the Oct 6 i-0e5a6d710e6bcc45e incident — the
  # supervisor loop wedged ~14.5 h before the netstack darked, and the
  # console's LAST line was a count_sample [bp] line. count_sample is the
  # loop's ONE synchronous external process (bpfcount does a bpf(2)
  # BPF_MAP_LOOKUP_ELEM; a bpf(2) blocked in the kernel is exactly the
  # waitpid-class wedge). It is DIAGNOSTIC, not load-bearing — so it goes off
  # the blocking path the same way run_probe/is_running do: background it,
  # poll /proc non-blocking, kill -9 at the deadline, NEVER wait on it. A
  # wedged bpfcount now costs at most a leaked zombie, not the supervisor.
  bp_out=/tmp/.sysnet-bp
  rm -f "$bp_out" 2>/dev/null
  "$BPCOUNT" "$PIN/redirect_counts" > "$bp_out" 2>/dev/null &
  bp_live=0; bp_pid=""; j=0
  while [ "$j" -lt 3 ]; do
    bp_live=0
    for p in $(pgrep -x bpfcount 2>/dev/null); do
      bp_live=1; bp_pid=$p
    done
    [ "$bp_live" -eq 0 ] && break
    sleep 1; j=$((j + 1))
  done
  [ "$bp_live" -eq 1 ] && kill -9 "$bp_pid" 2>/dev/null || true
  bp_cur=$(cat "$bp_out" 2>/dev/null)
  case "$bp_cur" in
    ''|*[!0-9\ ]*) bp_cur="" ;;  # incomplete/garbage read -> absent
  esac
  # Validate the whole line is exactly 32 all-digit space-separated fields.
  # (The v4 object emits 2 fields; a mismatched count means the running
  # program and the bpfcount binary disagree -> treat as absent, log once.)
  bp_n=0; bp_ok=1; bp_tok=""
  for bp_tok in $bp_cur; do
    case "$bp_tok" in
      *[!0-9]*) bp_ok=0;;
    esac
    bp_n=$(( bp_n + 1 ))
  done
  if [ "$bp_ok" -ne 1 ] || [ "$bp_n" -ne 32 ]; then
    [ "$BPSEEN" -eq 0 ] && { log "  [bp] redirect_counts absent or wrong arity (got $bp_n fields; v3/v4 object, not attached, or binary mismatch)"; BPSEEN=1; }
    return 0
  fi
  BPSEEN=1
  bp_prev=""
  [ -s "$BPSTAT" ] && bp_prev=$(cat "$BPSTAT" 2>/dev/null)
  if [ -n "$bp_prev" ]; then
    # Compute per-slot deltas; emit two comma-lists. A field count mismatch
    # (program reload -> counters reset) -> log a reset line, no deltas.
    bp_np=0; bp_pok=1
    for bp_tok in $bp_prev; do
      case "$bp_tok" in
        *[!0-9]*) bp_pok=0;;
      esac
      bp_np=$(( bp_np + 1 ))
    done
    if [ "$bp_pok" -ne 1 ] || [ "$bp_np" -ne 32 ]; then
      log "  [bp] counters reset (program reload or arity change)"
    else
      # Pairwise delta in POSIX sh (the guest /bin/sh is brush; NO arrays,
      # NO ${@:2}): the old tokens sit in the function's positional args,
      # the new tokens iterate the loop, one shift per slot. Slot k is pass
      # (even) or redirect (odd). set -- inside a function touches only the
      # function's positionals (count_sample takes none).
      set -- $bp_prev
      bp_dp_list=""; bp_dr_list=""
      bp_k=0
      for bp_c in $bp_cur; do
        bp_p=${1:-0}
        shift || true
        bp_d=$(( bp_c - bp_p ))
        [ "$bp_d" -lt 0 ] && bp_d=0   # counter reset on that slot (reload)
        if [ $(( bp_k % 2 )) -eq 0 ]; then
          bp_dp_list="${bp_dp_list}${bp_d},"
        else
          bp_dr_list="${bp_dr_list}${bp_d},"
        fi
        bp_k=$(( bp_k + 1 ))
      done
      bp_dp_list=${bp_dp_list%,}; bp_dr_list=${bp_dr_list%,}
      log "  [bp] dp=$bp_dp_list dr=$bp_dr_list"
    fi
  fi
  echo "$bp_cur" > "$BPSTAT" 2>/dev/null || true
}
i=0
while [ "$i" -lt "$SBX_WAIT" ]; do
  is_running && break
  i=$((i + 1)); sleep 1
done
if is_running; then
  log "sandbox $CID running (redirect:$DEV — kernel fully offline)"
else
  log "sandbox not running after ${SBX_WAIT}s"
  exit 1
fi

# --- 7b. boot-time self-test (logged to serial; no SSH needed) ------------------
# The kernel is offline and the netstack owns everything. Expected outcomes:
#   (a) kernel side:
#       eth0 has NO inet address (the lease lives in the netstack) and NO
#       route; any kernel TCP egress (10.0.2.2:22, 8.8.8.8:443) FAILS —
#       every frame is redirected into the netstack and the kernel owns no
#       socket to receive the reply. (These two kernel-side `nc`s run in
#       the kernel netns with NO route + NO address, so they fail INSTANTLY
#       with "Network is unreachable" — they cannot hang; the wire-hang
#       vector is in-sandbox netstack ops only, and the in-sandbox probe
#       no longer does any wire ops (v4).)
#   (b) in-sandbox netstack (run_probe, LOCAL diagnostics only — no wire
#       `nc`, see the probe script header):
#       eth0 lease, routes, rust-dhcp log, bootproofd status + :443 banner
#       (to the netstack's OWN lease IP — local, cannot hang), the
#       authorized_keys landing, and the in-netstack sshdt banner (also to
#       the netstack's own IP — local, cannot hang).
#   (c) host SSH (the money shot) is verified from the host harness:
#       hostfwd :2222 -> guest :22 lands on the WIRE, is redirected into
#       the netstack by the program, and is served by the sandbox's sshdt.
log "self-test: kernel offline"
KADDR=$(ip -4 -o addr show dev "$DEV" 2>/dev/null)
if [ -z "$KADDR" ]; then
  log "  [kern] eth0: no inet address (offline, as designed)"
else
  log "  [kern] eth0: UNEXPECTED kernel address: $KADDR"
fi
KRT=$(ip route show dev "$DEV" 2>/dev/null)
if [ -z "$KRT" ]; then
  log "  [kern] eth0: no routes (offline, as designed)"
else
  log "  [kern] eth0: UNEXPECTED kernel routes: $KRT"
fi
# The kernel probes FAIL for the real kernel-offline reason: with no address
# and no route the kernel cannot even construct a SYN (no source IP, no route)
# — "Network is unreachable". It is NOT that the SYN is redirected (the kernel
# never sends one). Either way the kernel's L4 plane is dark.
if timeout -s KILL 10 /bin/busybox nc -z -w 4 10.0.2.2 22 2>/dev/null; then
  log "  [kern] 10.0.2.2:22: PASS (UNEXPECTED — the kernel has a route/addr?)"
else
  log "  [kern] 10.0.2.2:22: FAIL (expected: kernel offline, no route to send)"
fi
if timeout -s KILL 10 /bin/busybox nc -z -w 6 8.8.8.8 443 2>/dev/null; then
  log "  [kern] 8.8.8.8:443: PASS (UNEXPECTED — the kernel has a route/addr?)"
else
  log "  [kern] 8.8.8.8:443: FAIL (expected: kernel offline, no route to send)"
fi
log "self-test: in-sandbox netstack"
# the probe script was staged into the bundle rootfs before create (RO fs:
# it can only be changed now by rebuilding the bundle). BOUNDED (run_probe):
# a hung probe must not freeze the supervisor (see run_probe's comment).
run_probe

# --- 8. supervised lifetime -------------------------------------------------------
# Hold the unit's process alive while the sandbox runs; if it dies (sentry
# crash, OOM), exit non-zero so execd respawns (teardown + redirect retry).
# N CONSECUTIVE failed polls before declaring death: a single transient
# runsc list miss (state-root contention) must not orphan the data plane.
i=0; FAIL=0
while [ "$i" -lt 360000 ]; do
  # v13-supervisor: heartbeat FIRST, before anything that can block (is_running
  # backgrounds runsc; run_probe the probe; count_sample bpfcount; the periodic
  # probe the exec channel). If ANY of those wedges mid-iteration, this
  # stamp never recurs and the separate watchdog (sysnet-watchdog.sh) sees a
  # stale $HB and reboots the guest — the recovery that was dead with the
  # loop on Oct 6. A plain tmpfs write: it cannot wedge the loop.
  date -u +%s > "$HB" 2>/dev/null || true
  sleep 5
  if is_running; then
    FAIL=0
  else
    FAIL=$((FAIL + 1))
    [ "$FAIL" -ge 3 ] && { log "sandbox dead (3 consecutive failed polls)"; exit 1; }
  fi
  # v8: data-plane watchdog (see the DP_* globals + dpark_check). This is the
  # liveness signal that is_running CANNOT provide: a wedged-but-alive
  # netstack still reports "running" to runsc list (the Oct 3 terminal-dark
  # failure — 23 h un-recovered), but its dp file goes stale/fail. DP_LIMIT
  # consecutive dark checks (120 s of continuous dark) => a recovery action.
  #
  # v9: ESCALATION (the Oct 4 wire data: i-000e5ccf2f8fefb35, 87 min terminal
  # dark, the v8 respawn cleared NOTHING — 222 consecutive 000 samples, no
  # recovery blips). The terminal wedge is in KERNEL-SIDE NIC/AF_XDP/ENI
  # state: it survives sentry death + sandbox recreation, so a respawn
  # re-binds a fresh AF_XDP socket onto the same poisoned NIC and
  # immediately re-wedges. The only proven recovery is a FULL GUEST REBOOT
  # (the manual reboot cleared it in ~9 min). Model: esc (host tmpfs —
  # survives teardown, wiped by the reboot) counts consecutive dark
  # generations. esc 1 = the wedge may be transient: one cheap respawn.
  # esc >= ESC_LIMIT = it outlived a full teardown+respawn: reboot the
  # guest. RBOVR (persistent /home — survives the reboot) caps consecutive
  # reboots without a healthy period (reboot-loop guard).
  if dpark_check; then
    DPARK=0
  else
    DPARK=$((DPARK + 1))
    [ "$DPARK" -ge "$DP_LIMIT" ] && {
      esc=$(cat "$ESCF" 2>/dev/null); case "$esc" in ''|*[!0-9]*) esc=0;; esac
      esc=$((esc + 1))
      echo "$esc" > "$ESCF" 2>/dev/null || true
      if [ "$esc" -ge "$ESC_LIMIT" ]; then
        rbovr=$(cat "$RBOVR" 2>/dev/null); case "$rbovr" in ''|*[!0-9]*) rbovr=0;; esac
        if [ $((rbovr + 1)) -gt "$RBOVR_LIMIT" ]; then
          # v9: REBOOT-LOOP GUARD. rbovr+1 consecutive reboots with no
          # healthy generation between them: STOP rebooting — a reboot storm
          # (guest reset every ~2-4 min, wiping LUKS/NitroTPM sessions) is a
          # worse liveness failure than a stable-dark + a loud, persistent
          # alarm. Alarm to plog (/home, survives) + serial, then respawn
          # (exit 1) so the watchdog stays armed: if any future generation
          # goes healthy, dpmon's first pass clears RBOVR and normal
          # operation resumes.
          log "ALARM: reboot-loop guard — $((rbovr + 1)) consecutive reboots without a healthy period (last dp: $(cat "$DPF" 2>/dev/null)): NOT rebooting; staying dark + alarm (respawning to keep the watchdog armed)"
          plog "ALARM reboot-loop guard: rbovr=$rbovr consecutive reboots, dark persists, no further reboots (respawn only)"
          exit 1
        fi
        newrbovr=$((rbovr + 1))
        echo "$newrbovr" > "$RBOVR" 2>/dev/null || true
        plog "data plane dark $DPARK checks (esc=$esc >= $ESC_LIMIT, wedge outlived a full respawn): FULL GUEST REBOOT rbovr=$newrbovr/$RBOVR_LIMIT last=$(cat "$DPF" 2>/dev/null)"
        log "data plane dark $DPARK consecutive checks (>= $((DPARK * 5)) s; esc=$esc/$ESC_LIMIT — the wedge outlived a full teardown+respawn): escalating to a FULL GUEST REBOOT (rbovr=$newrbovr/$RBOVR_LIMIT; last dp: $(cat "$DPF" 2>/dev/null))"
        # Make the durable state (plog + rbovr on LUKS /home) hit the disk
        # before the reset.
        sync 2>/dev/null || true
        # reboot -f = the reboot(2) syscall (RB_FORCE): it bypasses
        # init/nit/execd entirely (root in the init ns has CAP_SYS_BOOT) and
        # the kernel resets the VM — clearing the kernel-side NIC/AF_XDP/ENI
        # state a sandbox respawn cannot reach. If it fails, fall through to
        # the sandbox respawn (exit 1) — the guard above already consumed the
        # attempt (safe direction: failing reboots spend guard budget).
        reboot -f 2>/dev/null || log "reboot -f FAILED (rc=$?): falling back to sandbox respawn"
        exit 1
      fi
      log "data plane dark $DPARK consecutive checks (>= $((DPARK * 5)) s continuous; last: $(cat "$DPF" 2>/dev/null)): respawning the sandbox (exit -> teardown) [esc=$esc/$ESC_LIMIT]"
      exit 1
    }
  fi
  i=$((i + 1))
  # periodic netstack diagnostic (every ~20 s): the only path from the sandbox
  # to the serial. Captures the eth0 lease (the load-bearing assumption), the
  # key landing, and the in-netstack sshdt banner. BOUNDED (run_probe) so a
  # hung probe can never freeze the liveness loop or the console again.
  [ $((i % 4)) -eq 0 ] && is_running && run_probe
  # v10: sample the v4 BPF pass/redirect counters every liveness iteration
  # (~5 s) -- the flap discriminator (see count_sample). Kernel-side, cannot
  # wedge; a missing pin is a single logged "absent", never a stall.
  count_sample
done
log "supervisor exit (liveness horizon reached; unit will respawn)"
exit 0
