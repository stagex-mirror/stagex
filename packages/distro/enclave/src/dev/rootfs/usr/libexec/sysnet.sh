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
# Shell discipline: /bin/sh here is brush — `wait <pid>` is unimplemented.
# This script backgrounds nothing; it polls `runsc list` for liveness.
set -u

DEV=eth0                       # pinned by net.ifnames=0 on the cmdline; the
                               # guest has exactly one data NIC. No lease-
                               # based discovery: the kernel is offline and
                               # has no route to discover from.
CID=sysnet
RUNSC=/usr/bin/runsc
LOADER=/usr/bin/xdp_loader
STATE=/run/sysnet/runsc
B=/run/sysnet/bundle
PIN=/sys/fs/bpf/$DEV
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
  # detach + unpin: the program's empty-sockmap guard already auto-PASSes to
  # the kernel while the socket is gone; a lingering program is dead weight.
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
# /home/bootproof mount point: a real dir in the (readonly) bundle rootfs —
# the gofer O_CREATs a missing bind target and dies on a readonly fs (P4
# rule). /run/enclaved needs no placeholder: /run is the writable tmpfs, so
# the gofer creates it there. Host-side sources: enclaved owns /run/enclaved
# (mkdir -p is idempotent); /home/bootproof persists on the LUKS volume,
# is recreated on tmpfs /home (QEMU) — both idempotent.
mkdir -p "$R/home/bootproof" /run/enclaved /home/bootproof 2>/dev/null \
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
# key, in-netstack sshdt banner (isolates netstack-vs-XDP/hostfwd), egress.
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
IP=$(/bin/busybox ip -4 -o addr show eth0 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
if [ -n "$IP" ]; then
  echo "  [sbx] in-netstack sshdt banner from $IP:22 (first 40 bytes):"
  /bin/busybox nc -w 4 "$IP" 22 </dev/null 2>/dev/null | head -c 40 | sed 's/^/    /'
  echo
fi
echo "  [sbx] A (GW 10.0.2.2:22): "
/bin/busybox nc -z -w 5 10.0.2.2 22 && echo "PASS" || echo "FAIL"
echo "  [sbx] B (8.8.8.8:443): "
/bin/busybox nc -z -w 6 8.8.8.8 443 && echo "PASS" || echo "FAIL"
EOF
chmod 755 "$R/sysnet-probe.sh" 2>/dev/null || true

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
#       socket to receive the reply.
#   (b) in-sandbox netstack:
#       A = 10.0.2.2:22 -> the GW's sshd is SLIRP's; the sandbox netstack
#         owns the lease, so this PASSes (the netstack is a full client).
#       B = 8.8.8.8:443 -> the netstack's egress; PASS.
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
if /bin/busybox nc -z -w 4 10.0.2.2 22 2>/dev/null; then
  log "  [kern] 10.0.2.2:22: PASS (UNEXPECTED — the kernel has a route/addr?)"
else
  log "  [kern] 10.0.2.2:22: FAIL (expected: kernel offline, no route to send)"
fi
if /bin/busybox nc -z -w 6 8.8.8.8 443 2>/dev/null; then
  log "  [kern] 8.8.8.8:443: PASS (UNEXPECTED — the kernel has a route/addr?)"
else
  log "  [kern] 8.8.8.8:443: FAIL (expected: kernel offline, no route to send)"
fi
log "self-test: in-sandbox netstack"
# the probe script was staged into the bundle rootfs before create (RO fs:
# it can only be changed now by rebuilding the bundle).
"$RUNSC" --root="$STATE" --overlay2=none --ignore-cgroups exec "$CID" \
  /bin/busybox sh /sysnet-probe.sh 2>&1 | sed 's/^/  /' >&2

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
  # periodic netstack diagnostic (every ~20 s): the only path from the sandbox
  # to the serial. Captures the eth0 lease (the load-bearing assumption), the
  # key landing, and the in-netstack sshdt banner.
  [ $((i % 4)) -eq 0 ] && is_running && "$RUNSC" --root="$STATE" --overlay2=none --ignore-cgroups exec "$CID" \
    /bin/busybox sh /sysnet-probe.sh 2>&1 | sed 's/^/  /' >&2
done
log "supervisor exit (liveness horizon reached; unit will respawn)"
exit 0
