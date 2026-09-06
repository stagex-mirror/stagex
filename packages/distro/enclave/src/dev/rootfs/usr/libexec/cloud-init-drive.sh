#!/bin/sh
# cloud-init-drive.sh — seed hostname + ssh keys from a config drive.
#
# Ported verbatim from the S05cloud-init-drive init script (QEMU/AWS-
# verified): ISO9660 config drive on a CD-ROM (OpenStack standard), with a
# raw-text fallback on a second virtio-blk. No device present -> "no
# device" and exit 0 (cloud-init-net takes over over the wire).

HOSTNAME_FILE="/etc/hostname"
KEYS_FILE="/root/.ssh/authorized_keys"

# Skip if hostname already set
[ -s "$HOSTNAME_FILE" ] && { printf "Cloud-init (drive): skip\n"; exit 0; }

# Method 1: try ISO config drive on CD-ROM (OpenStack standard)
mkdir -p /tmp/cfg
for dev in /dev/sr0 /dev/sr1 /dev/cdrom /dev/hdc /dev/hdd; do
	[ -e "$dev" ] || continue
	if mount -t iso9660 -o ro "$dev" /tmp/cfg 2>/dev/null; then
		# Only write the key file if it actually holds a key line: sshdt's
		# start gate is file-existence, and an empty authorized_keys would
		# make sshdt fall back to anonymous auth (open SSH).
		if [ -f /tmp/cfg/authorized_keys ] && \
		   grep -qE '^(ssh-|ecdsa-|sk-|comment=)' /tmp/cfg/authorized_keys; then
			mkdir -p /root/.ssh
			cp /tmp/cfg/authorized_keys "$KEYS_FILE"
			chmod 600 "$KEYS_FILE"
		fi
		if [ -f /tmp/cfg/hostname ]; then
			h=$(head -1 /tmp/cfg/hostname)
			[ -n "$h" ] && hostname "$h" && printf '%s\n' "$h" > "$HOSTNAME_FILE"
		fi
		umount /tmp/cfg 2>/dev/null
		rmdir /tmp/cfg 2>/dev/null
		printf "Cloud-init (drive): ok (iso %s)\n" "$dev"
		exit 0
	fi
done

# Method 2: try raw text config on virtio-blk (fallback). Scan every virtio
# whole disk, not just the first: the raw cloud drive's position depends on
# whether a data disk is also attached (vdb with none, vdc with one). The
# boot disk (vda) and the LUKS data disk both fail the ssh-* magic check, so
# scanning them is harmless.
for dev in /dev/vd? /dev/xvd?; do
	[ -e "$dev" ] || continue
	HEAD=$(dd if="$dev" bs=4 count=1 2>/dev/null | tr -d '\0')
	case "$HEAD" in
		ssh-*)
			DATA=$(dd if="$dev" bs=1024 count=1 2>/dev/null)
			KEY=$(printf '%s' "$DATA" | head -1)
			HOSTNAME=$(printf '%s' "$DATA" | sed -n '2p')
			[ -n "$KEY" ] && mkdir -p /root/.ssh && printf '%s\n' "$KEY" > "$KEYS_FILE" && chmod 600 "$KEYS_FILE"
			[ -n "$HOSTNAME" ] && hostname "$HOSTNAME" && printf '%s\n' "$HOSTNAME" > "$HOSTNAME_FILE"
			printf "Cloud-init (drive): ok (raw %s)\n" "$dev"
			exit 0
			;;
	esac
done

printf "Cloud-init (drive): no device\n"
exit 0
