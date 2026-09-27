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
SBX_SUBNET=192.168.10.0/24

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
# Host-side NAT for the sandbox's own subnet: `runsc do` default mode is
# "sandbox" (a veth pair on the default 192.168.10.x subnet), but without
# this rule the sandbox's outbound IMDS traffic (source 192.168.10.x) is
# never masqueraded to the host's primary ENI IP and is dropped. Same
# idempotent -C||-A pattern as bootproofd-sandbox.sh; -w waits for the
# xtables lock (the bootproofd sandbox's iptables runs in the SAME execd
# wave and holds it briefly — a lock failure here would leave the sandbox
# without egress on an IMDS-only host). FAIL-OPEN per this script's
# contract — a NAT failure is logged, not fatal.
{
  iptables -w -t nat -C POSTROUTING -s "$SBX_SUBNET" -j MASQUERADE 2>/dev/null \
    || iptables -w -t nat -A POSTROUTING -s "$SBX_SUBNET" -j MASQUERADE
} || log "masquerade POSTROUTING $SBX_SUBNET failed (IMDS egress may be unavailable)"

# Two things are required for this sandbox to have real egress (IMDS on AWS),
# and neither alone is enough on this kernel (no CONFIG_USER_NS):
#
# (1) PATH. runsc inherits execd's environment, which has NO PATH. Its Go
#     subprocess setupNet execs "ip" via Go's default PATH, which resolves
#     /usr/bin/ip = busybox. busybox ip has no `netns`, so `ip netns add`
#     fails and setupNet errors out (or, when the default iface can't be read,
#     silently falls back to a fresh EMPTY netns with NO egress — exactly the
#     "no user-data" drop on an IMDS-only host). Exporting a PATH that puts
#     /usr/sbin (iproute2) first makes the veth + netns + MASQUERADE path
#     actually build.
# (2) --network=host. Once setupNet succeeds (veth up), conf.Network is still
#     the default "sandbox", so container.go's modifySpecForDirectfs (directfs
#     defaults ON) runs: it adds a USER namespace to the spec and reads
#     /proc/self/uid_map — which does not exist without CONFIG_USER_NS, so
#     sandbox creation dies with exit 128 ("failed to modify spec for
#     directfs: .../uid_map: no such file or directory"). --network=host
#     makes that function bail BEFORE the uid_map read (container.go:2155) and
#     the sandbox runs in the CURRENT user namespace (sandbox.go:1189) — the
#     same state the no-PATH fallback already booted rc=0 on. It keeps directfs
#     ON (so --force-overlay=false still writes host-visible) and still joins
#     the veth netns setupNet built, so egress is real.
#
# --network is a config flag (parsed before the subcommand); --ip is a do flag.
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

# --- (3) A default route must exist before `runsc do` -----------------------
# setupNet (do.go) resolves the egress device with `ip route list default`;
# this unit starts in the SAME execd wave as dhcp, and the DHCP lease (the
# default route) lands a couple of seconds after boot. If the route is not
# there yet, setupNet returns errNoDefaultInterface and `runsc do` SILENTLY
# falls back to a fresh EMPTY netns (no veth, no route, no egress): on an
# IMDS-only host (AWS) that is an instant "no user-data", and on QEMU the
# provisioner just burns its 120 s IMDS poll down to the local seed — a green
# chain that never touched the network. Bounded wait (90 s, 1 s interval); on
# timeout proceed anyway — this script is fail-open (the local seed still
# works on QEMU, and a route that never arrives means there is no network at
# all, which fails closed by itself).
i=0
while ! ip route list default 2>/dev/null | grep -q '^default'; do
  i=$((i + 1))
  if [ "$i" -ge 90 ]; then break; fi
  sleep 1
done
if [ "$i" -ge 90 ]; then
  log "no default route after 90 s; runsc will fall back to an egress-less netns"
fi

# The /etc/{resolv.conf,hostname,hosts} bind-mount destinations (which
# setupNet adds in the veth path) exist in the image rootfs — see the
# Containerfile note; on the read-only erofs a missing one is a gofer
# fatal (EROFS) that kills the sandbox at boot.
runsc --ignore-cgroups --network=host \
  do --cwd / --force-overlay=false \
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
