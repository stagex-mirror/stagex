#!/bin/sh
# bootproofd-sandbox.sh — run bootproofd inside a gVisor (runsc) sandbox.
#
# The execd unit `bootproofd` (restart="always") runs THIS wrapper; it ends
# in `exec runsc ... do ... /usr/bin/bootproofd`, so execd's restart policy
# and liveness floor apply to the runsc process. On a volume-source or DNAT
# failure we log to stderr and exit NON-ZERO so the unit respawns — a 0 exit
# would mask the failure (unlike the oneshot provisioner, this is a long-lived
# service wrapper).
#
# RUNSC FORM (oracle-proven in-guest): --root / (default) +
# --force-overlay=false + two volume bridges.
#
# Two oracle rounds settled each flag:
#   (1) A staged-subdir --root + --force-overlay=false SIGSEGVs the sentry
#       (rc 139/128) for any payload, while --root / works. So there is NO
#       staging: the payload resolves its PT_INTERP and NEEDED libs against
#       the real / on the host.
#   (2) With the DEFAULT CoW overlay (all:memory), writes through the volume
#       bridges never reach the host. The persistent TLS identity must land
#       in /home/bootproof on the host, so overlay=none is REQUIRED, not a
#       workaround.
#
# Isolation note (deliberate, documented): --force-overlay=false gives the
# sandbox write access to the host root filesystem (do.go WARNING). The
# security boundary is gVisor itself (sentry + kernel seccomp) plus the
# daemon-side distrust model (everything crossing /run/enclaved is
# re-verified). The overlay would only have hidden sandbox writes from the
# host — which is exactly what broke the identity persistence.
#
#   The bind-mount SOURCES must exist on the host BEFORE runsc mounts them —
#   a missing source kills sandbox creation (the sentry dies, the host sees
#   "cannot read client sync file: EOF"). Two sources, both pre-created here:
#     /run/enclaved   — evidence channel; owned by enclaved (created at boot).
#     /home/bootproof — persistent TLS identity (the TOFU pin). On the LUKS
#                       /home (AWS, data disk) it persists across boots; on
#                       the tmpfs /home (QEMU, no data disk) it is recreated
#                       each boot. `mkdir -p` is idempotent either way.
#
# Network: `runsc do` default mode = sandbox (a veth pair + host iptables NAT).
# The sandbox is given a stable IP and we DNAT inbound :443 on eth0 to it, so
# the host's TLS attestation face reaches the sandboxed bootproofd.
#
# IP: 192.168.11.2 (host veth peer 192.168.11.3 = calculatePeerIP). Distinct
# from the provisioner's default 192.168.10.2: both `runsc do` sandboxes
# depend only on enclaved, so they start in the same wave and would otherwise
# collide on the shared 192.168.10.2/.3 veth peer.
#
# argv of the daemon: bootproofd takes NO arguments (crates/bootproofd/
# src/main.rs — --listen defaults to 0.0.0.0:443, --state to /home/bootproof,
# --socket to /run/enclaved/sock).
#
# Shell discipline: /bin/sh here is brush — `wait <pid>` is unimplemented and
# a bare `wait` returns 0 regardless of the reaped job's status. This script
# runs NO background jobs.
set -u

SBX_IP=192.168.11.2
SBX_SUBNET=192.168.11.0/24
BIN=/usr/bin/bootproofd

log() { echo "bootproofd-sandbox: $*" >&2; }
fail() { log "$*"; exit 1; }

# --- (a) Host-side volume sources must exist for the bind mounts ----------
mkdir -p /run/enclaved || fail "mkdir /run/enclaved failed"
mkdir -p /home/bootproof || fail "mkdir /home/bootproof failed"

# --- (b) DNAT inbound :443 on eth0 -> sandbox; masquerade sandbox subnet.
# Idempotent: -C (check) before -A (append).
{
  iptables -t nat -C PREROUTING -i eth0 -p tcp --dport 443 \
    -j DNAT --to-destination "$SBX_IP:443" 2>/dev/null \
    || iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 443 \
    -j DNAT --to-destination "$SBX_IP:443"
} || fail "DNAT PREROUTING eth0:443 -> $SBX_IP:443 failed (no iptables/nat?)"

{
  iptables -t nat -C POSTROUTING -s "$SBX_SUBNET" -j MASQUERADE 2>/dev/null \
    || iptables -t nat -A POSTROUTING -s "$SBX_SUBNET" -j MASQUERADE
} || fail "masquerade POSTROUTING $SBX_SUBNET failed"

# --- (c) Exec the locked runsc form. Two flags are load-bearing for egress
# (see provision.sh for the full oracle record; same kernel constraint, no
# CONFIG_USER_NS):
#   --network=host : do.go still runs setupNet (veth + netns + MASQUERADE for
#     egress — the DNAT above lands on it), but container.go:2155 then bails
#     out of modifySpecForDirectfs BEFORE the /proc/self/uid_map read (which
#     needs CONFIG_USER_NS and is absent), and the sandbox runs in the current
#     user namespace (sandbox.go:1189). Without it, directfs (default ON)
#     adds a USER namespace + reads uid_map -> exit 128 "failed to modify spec
#     for directfs". Without the PATH below, setupNet's `ip` resolves to busybox
#     (no netns) -> silent fallback to an empty netns -> the :443 face has no
#     egress.
#   PATH export   : runsc inherits execd's env (NO PATH); Go execs `ip` via its
#     default PATH -> /usr/bin/ip = busybox. /usr/sbin (iproute2) must lead.
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

# --- (d) A default route must exist before `runsc do` -----------------------
# setupNet (do.go) resolves the egress device with `ip route list default`.
# This unit starts in the SAME execd wave as dhcp, and the DHCP lease (the
# default route) lands a couple of seconds after boot. Without the route,
# setupNet returns errNoDefaultInterface and `runsc do` SILENTLY falls back
# to a fresh EMPTY netns: the sentry binds :443 in a netns with no veth and
# no route, so the host's DNAT (eth0:443 -> 192.168.11.2) blackholes — the
# attestation face is up but unreachable. Bounded wait (90 s, 1 s interval);
# on timeout exit NON-ZERO so execd respawns (restart="always") and retries —
# the DHCP lease arrives a few seconds after boot, so this converges on the
# first or second attempt.
i=0
while ! ip route list default 2>/dev/null | grep -q '^default'; do
  i=$((i + 1))
  if [ "$i" -ge 90 ]; then break; fi
  sleep 1
done
if [ "$i" -ge 90 ]; then
  fail "no default route after 90 s; runsc would fall back to an egress-less netns (respawn and retry)"
fi

exec /usr/bin/runsc --ignore-cgroups --network=host do \
  --ip "$SBX_IP" \
  --cwd / \
  --force-overlay=false \
  --volume /run/enclaved:/run/enclaved \
  --volume /home/bootproof:/home/bootproof \
  "$BIN"
