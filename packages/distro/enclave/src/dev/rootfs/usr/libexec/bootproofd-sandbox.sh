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

# --- (c) Exec the locked runsc form: --root / (default), overlay=none
# (required for host-visible identity writes — see header), both volume
# bridges.
exec /usr/bin/runsc --ignore-cgroups do \
  --ip "$SBX_IP" \
  --cwd / \
  --force-overlay=false \
  --volume /run/enclaved:/run/enclaved \
  --volume /home/bootproof:/home/bootproof \
  "$BIN"
