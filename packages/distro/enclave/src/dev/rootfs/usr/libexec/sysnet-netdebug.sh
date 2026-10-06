#!/bin/busybox sh
# netdebug — REMOVABLE network debug channel (netstack co-tenant).
#
# Purpose: measure the gvisor netstack's REAL-WORLD egress cost (DNS + TCP
# connect + TLS + TTFB + upload throughput to S3, the in-region external
# endpoint) and ship a compact metrics log to S3 (stagex-netdebug) so the
# numbers survive a netstack wedge/dark. The uploader's own cadence is a
# liveness signal: if the S3 objects stop arriving, the netstack is wedged
# or dark; the gap between the last object and the next = the dark
# duration, and the last object shows the pre-wedge degradation.
#
# Why in the netstack: the kernel is fully offline (sn-7) -- rust-dhcp
# applies the lease to the netstack, the kernel netns has no IP/route, so
# only the netstack has egress. A kernel-side baseline is impossible here;
# the comparison baseline is a pre-sn-7 (kernel-online) instance hitting the
# same S3 endpoint (measured separately, not by this script).
#
# REMOVAL (the whole point -- throwaway debug tooling, not shipped
# behavior): delete this file + the `cp netdebug` staging block + the
# `( ... netdebug ... ) &` launch + the curl/lib staging lines in
# sysnet.sh. It is a background co-tenant; killing it (or the sandbox)
# removes it. It never blocks the payload (all curl calls are -m bounded;
# sleep is the busybox applet), and it degrades to a no-op when there are
# no IMDS credentials (QEMU has none).
#
# Credentials: the keeper carries the stagex-netdebug IAM instance profile
# (scoped s3:PutObject/ListBucket on stagex-netdebug only). Fetched via
# IMDSv2 in a bounded LLA-removal window (the VPC drops LLA-sourced IMDS
# SYNs -- the Oct 3 source-IP root cause; the via-GW route is already set
# by the payload). Refreshed periodically; a fetch failure is fail-open
# (S3 upload disabled, egress timing still runs).
#
# -k (no CA bundle staged): the unauthenticated latency probe treats a 403
# as HEALTHY (we went the full way through netstack + TLS + S3 and got an
# S3 response; a 000 is a wedge/dark). time_namelookup is split out so DNS
# cost is separable from the TCP/TLS round trip. This is a debug measurement,
# not a trust decision.

CURL=/bin/curl
BUCKET=stagex-netdebug
REGION=us-east-2
ENDPOINT=https://$BUCKET.s3.$REGION.amazonaws.com
MLOG=/run/netdebug/metrics.log
INTERVAL=10      # s between egress samples
UPLOAD_EVERY=30  # samples between S3 metric-log uploads (300 s)

/bin/busybox mkdir -p /run/netdebug 2>/dev/null
: > "$MLOG" 2>/dev/null || true
# boot generation marker: each sandbox (re)spawn gets a fresh counter so the
# S3 object keys are ordered and a respawn is visible as a new gen.
GEN=0
[ -f /run/netdebug/gen ] && GEN=$(cat /run/netdebug/gen 2>/dev/null)
case "$GEN" in ''|*[!0-9]*) GEN=0;; esac
GEN=$((GEN + 1))
echo "$GEN" > /run/netdebug/gen 2>/dev/null

# instance-id (from IMDS when available; the S3 object key). Fetched in the
# credential window below; falls back to a static label.
IID=i-unknown
# NOIMDS=1 once a probe shows the metadata service is absent (QEMU): then we
# never call get_creds again, so the LLA is never yanked for a doomed fetch.
NOIMDS=0

# --- IMDS credentials (bounded LLA-removal window, same trick as enclavectl) ---
# Returns 0 on success (AKID/SEC/STOK/IID set), 1 otherwise (fail-open). The
# LLA is removed for the fetch's duration and re-added on every exit path
# (fail-open re-DORA primary). On the very first instance-id probe: if IMDS is
# absent (QEMU, no ENI role) that single 5 s timeout sets NOIMDS so we stop
# churning the LLA -- the other three curls are skipped too (no 20 s window).
get_creds() {
  # belt-and-suspenders on top of the i>=13 deferral: never open the LLA
  # window while enclavectl's own provision (the CRITICAL authorized_keys
  # path) is in flight -- both delete/re-add the LLA, and overlapping
  # windows would drop each other's IMDS SYNs.
  /bin/busybox pgrep -x enclavectl >/dev/null 2>&1 && return 1
  AKID= SEC= STOK=
  /bin/busybox ip -4 addr del 169.254.2.2/16 dev eth0 2>/dev/null
  IID=$($CURL -s -m 5 http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)
  if [ -z "$IID" ]; then
    NOIMDS=1
    /bin/busybox ip -4 addr add 169.254.2.2/16 dev eth0 2>/dev/null
    return 1
  fi
  case "$IID" in i-*) : ;; *) IID=i-unknown;; esac
  TOK=$($CURL -s -m 5 -X PUT "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
  ROLE=$($CURL -s -m 5 -H "X-aws-ec2-metadata-token: $TOK" \
        http://169.254.169.254/latest/meta-data/iam/security-credentials/ 2>/dev/null)
  CREDS=$($CURL -s -m 5 -H "X-aws-ec2-metadata-token: $TOK" \
        "http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE" 2>/dev/null)
  # re-add the LLA no matter what (fail-open re-DORA primary; EEXIST is a no-op)
  /bin/busybox ip -4 addr add 169.254.2.2/16 dev eth0 2>/dev/null
  [ -n "$CREDS" ] || return 1
  AKID=$(echo "$CREDS" | grep -oE '"AccessKeyId": *"[^"]+"'  | sed 's/.*:"\([^"]*\)"/\1/')
  SEC=$(echo  "$CREDS" | grep -oE '"SecretAccessKey": *"[^"]+"' | sed 's/.*:"\([^"]*\)"/\1/')
  STOK=$(echo  "$CREDS" | grep -oE '"Token": *"[^"]+"' | sed 's/.*:"\([^"]*\)"/\1/')
  [ -n "$AKID" ] && [ -n "$SEC" ]
}

# one bounded egress sample: full HTTPS round trip to the S3 endpoint (the
# unauthenticated 403 = the healthy full-path signal; a 000 = wedge/dark).
sample() {
  now=$(date -u +%s)
  t=$($CURL -sk -o /dev/null -m 15 \
      -w "nl=%{time_namelookup} ct=%{time_connect} tls=%{time_appconnect} ttfb=%{time_starttransfer} tot=%{time_total} code=%{http_code}" \
      "$ENDPOINT/" 2>/dev/null)
  echo "$now egress $t dp=$(cat /run/sysnet/dp 2>/dev/null)" >> "$MLOG" 2>/dev/null
}

# one bounded throughput sample: a 1 MiB PUT through the netstack (measures
# the full uplink, not just a handshake). Only when we have credentials.
put() {
  [ -n "$AKID" ] || return 0
  now=$(date -u +%s)
  # 1 MiB of a fixed byte, awk-generated (content is irrelevant to a
  # throughput measurement; avoids depending on a /dev/zero node in the
  # sandbox). Generated once at the top of the window, reused.
  [ -s /run/netdebug/payload.bin ] || awk 'BEGIN{for(i=0;i<1048576;i++) printf "a"}' \
    > /run/netdebug/payload.bin 2>/dev/null
  r=$($CURL -sk -o /dev/null -m 30 --aws-sigv4 "aws:amz:$REGION:s3" \
      -u "$AKID:$SEC" --header "x-amz-security-token:$STOK" \
      -w "spd_kbps=%{speed_upload} tot=%{time_total} code=%{http_code}" \
      --upload-file /run/netdebug/payload.bin \
      "$ENDPOINT/put/$IID/gen$GEN/$now.bin" 2>/dev/null)
  echo "$now put 1048576 $r" >> "$MLOG" 2>/dev/null
}

# ship the accumulated metrics log to S3, then truncate. The upload cadence
# is the liveness signal; a successful upload truncates so each object is a
# ~300 s window.
upload() {
  [ -n "$AKID" ] || return 0
  [ -s "$MLOG" ] || return 0
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  $CURL -sk -o /dev/null -m 30 --aws-sigv4 "aws:amz:$REGION:s3" \
    -u "$AKID:$SEC" --header "x-amz-security-token:$STOK" \
    --upload-file "$MLOG" \
    "$ENDPOINT/netdebug/$IID/gen$GEN/$ts.log" 2>/dev/null \
    && : > "$MLOG" 2>/dev/null
}

# The egress samples hit S3 (a public IP), which the netstack SOURCES from
# the lease (the LLA 169.254.2.2 only matches 169.254.0.0/16 dests), so they
# do NOT need the LLA-removal window and start immediately. Only the IMDS
# credential fetch needs the window (IMDS is in 169.254.0.0/16 -> LLA-sourced
# unless removed). The first credential fetch is deferred past enclavectl's
# own 120 s LLA window: both delete/re-add the LLA, and if netdebug removed
# it while enclavectl was mid-fetch, enclavectl's IMDS SYNs would be
# LLA-sourced and dropped, failing the CRITICAL authorized_keys path. At
# sample 13 (~130 s) enclavectl is done. Fail-open throughout: no creds ->
# egress timing only.
echo "netdebug: up gen=$GEN (egress sampling started; S3 upload after creds)"
i=0
while :; do
  sample
  i=$((i + 1))
  # first credential fetch, deferred past enclavectl's LLA window (see above);
  # once IMDS is found absent (NOIMDS) it is never retried -- no LLA churn.
  [ -z "$AKID" ] && [ "$NOIMDS" -eq 0 ] && [ "$i" -ge 13 ] && get_creds \
    && echo "netdebug: creds fetched gen=$GEN iid=$IID (S3 upload enabled)"
  # one throughput sample per upload window (not every 10 s -- S3 storage)
  [ $(( i % UPLOAD_EVERY )) -eq 0 ] && put
  upload
  # refresh credentials every ~180 samples (~30 min; they last ~6 h)
  [ "$NOIMDS" -eq 0 ] && [ "$i" -ge 13 ] && [ $(( i % 180 )) -eq 0 ] && get_creds
  /bin/busybox sleep "$INTERVAL" 2>/dev/null || sleep "$INTERVAL"
done
