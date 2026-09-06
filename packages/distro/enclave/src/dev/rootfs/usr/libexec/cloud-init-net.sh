#!/bin/sh
# cloud-init-net.sh — seed hostname + ssh keys from the cloud metadata service.
#
# Ported verbatim from the S06cloud-init-net init script (QEMU/AWS-
# verified). Runs after dhcp has a lease. Fetches hostname (IMDSv1 then
# instance-id fallback) and user-data (IMDSv1, then IMDSv2 token) and
# keeps the raw user-data at /run/userdata for the home unit (home user
# name + keys).
#
# Always exits 0: a slow or absent metadata service must not break boot.

HOSTNAME_FILE="/etc/hostname"
KEYS_FILE="/root/.ssh/authorized_keys"
META="http://169.254.169.254"

printf "Cloud-init (net): starting\n" >&2

# Fix routing: dummy/ifb interfaces hijack 169.254.0.0/16 metadata route
busybox ip link delete dummy0 2>/dev/null || true
busybox ip link delete ifb0 2>/dev/null || true
busybox ip link delete ifb1 2>/dev/null || true

printf "Cloud-init (net): removed bogus interfaces\n" >&2

# Wait for network (up to 30s)
printf "Cloud-init (net): waiting for network..." >&2
for i in $(seq 1 30); do
	ping -c 1 -W 1 "$META" >/dev/null 2>&1 && break
	sleep 1
done
printf "ok\n" >&2

# Fetch hostname if not set (try IMDSv1 first, simpler)
if [ ! -s "$HOSTNAME_FILE" ]; then
	h=$(wget -qO- --timeout=5 "$META/latest/meta-data/hostname" 2>/dev/null | head -c 64)
	if [ -z "$h" ]; then
		h=$(wget -qO- --timeout=5 "$META/latest/meta-data/instance-id" 2>/dev/null | head -c 64)
	fi
	if [ -n "$h" ]; then
		hostname "$h"
		echo "$h" > "$HOSTNAME_FILE"
		printf "Cloud-init (net): hostname=%s\n" "$h" >&2
	fi
fi

# Always try to fetch user-data for ssh keys
printf "Cloud-init (net): checking keys file...\n" >&2
if [ ! -s "$KEYS_FILE" ]; then
	# Try IMDSv1 first (no token), then IMDSv2
	data=""
	data=$(wget -qO- --timeout=5 "$META/latest/user-data" 2>/dev/null)
	if [ -z "$data" ]; then
		# Try IMDSv2 token
		TOKEN=$(wget -qO- --timeout=3 --post-data="300" "$META/latest/api/token" 2>/dev/null)
		if [ -n "$TOKEN" ]; then
			data=$(wget -qO- --timeout=5 --header="X-aws-ec2-metadata-token: $TOKEN" "$META/latest/user-data" 2>/dev/null)
		fi
	fi
	if [ -n "$data" ]; then
		chmod 700 /root/.ssh
		# Only key lines belong in authorized_keys (user-data is the SSH key;
		# the filter is defensive in case anything else is ever appended).
		# Write the file ONLY if the filter matched a line: sshdt's start
		# gate is file-existence, and an empty authorized_keys would make
		# sshdt fall back to anonymous auth (open SSH).
		KLINES=$(printf '%s\n' "$data" | grep -E '^(ssh-|ecdsa-|sk-|comment=)')
		if [ -n "$KLINES" ]; then
			mkdir -p /root/.ssh
			printf '%s\n' "$KLINES" > "$KEYS_FILE"
			chmod 600 "$KEYS_FILE"
		fi
		# Keep the raw user-data for the home unit (home user name + keys).
		printf '%s\n' "$data" > /run/userdata
		printf "Cloud-init (net): user-data fetched (%d bytes)\n" "${#data}" >&2
	else
		printf "Cloud-init (net): no user-data available\n" >&2
	fi
else
	printf "Cloud-init (net): keys file already exists (%d bytes)\n" "$(wc -c < "$KEYS_FILE")" >&2
fi

printf "Cloud-init (net): done\n" >&2
exit 0
