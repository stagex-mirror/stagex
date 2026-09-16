#!/bin/busybox ash
# home.sh —  LUKS /home volume (TPM2 PCR-locked key) + unprivileged user setup
#
# Key release + volume open are pure Rust (the `bootproof` binary:
# dmext/unseal commands). No tpm2_*, no cryptsetup, no lossetup in the
# open path. On-disk format stays standard LUKS2 (cryptsetup-oracle
# compatible; a human can open the same volume by hand). The first-boot
# luksFormat stays a cryptsetup oracle (the luks crate is read-only).
#
# TPM2 key protection, two-stage PCR policy:
#   PCR 4 (OVMF boot path) and PCR 9 (initrd/cmdline data) are NOT stable on
#   the very first boot of a fresh instance: the firmware's initial-boot
#   measurements differ from steady-state boots (verified on AWS: PCR4 and
#   PCR9 differ first boot vs reboot, while PCR5 and PCR7 are identical from
#   first boot onward). Sealing with the full policy on first boot would make
#   the key unsealable from boot two onwards. So:
#     seed: PCR 5+7  (boot-disk GPT + kernel; stable from first boot)
#     full: PCR 4+5+7+9 (bound on the second boot, when PCRs are stable)
#   The seed object stays resident as a fallback: after a firmware or
#   cmdline change the full policy fails closed but the seed still releases
#   the key (kernel + disk layout still verified).
#
# Behaviour, in order:
#  1. Find a candidate whole disk (not the root disk, not loop/ram/sr).
#  2. If it already carries a LUKS header: unseal the key (full policy first,
#     seed as fallback; migrate the seed to the full policy when the full
#     object does not exist yet), open the volume and mount it at /home.
#  3. Else if it is completely blank: first-boot setup — seal a fresh random
#     key to the TPM2 FIRST (seed policy), then LUKS2 format, ext4 inside,
#     mount. Sealing before any disk I/O means a crash or a stuck volume
#     between format and completion never loses the key: the next boot
#     unseals it and sees the real volume state. The full policy is applied
#     automatically on the next boot.
#  4. Always: make /etc/passwd and /etc/group writable (bind mount), create
#     the unprivileged user (default "user", or the name given on the first
#     user-data line "user <name>"), and install its SSH keys.
#
# Boot safety: a stuck step must not hold the boot. Every disk I/O step runs
# under a deadline; on expiry the step's process is killed and the boot
# proceeds (the key is kept for the next boot, see the blank-disk path). A
# stuck kernel thread may keep spinning after that — the instance stays
# reachable, and a stop/start (host migration) clears it.
#
# PBKDF: the format uses fixed argon2id parameters (--pbkdf-force-iterations
# 4, --pbkdf-memory 512000 KiB, --pbkdf-parallel = nproc) and SKIPS
# cryptsetup's benchmark. The benchmark (target 2 s, +/-5 % acceptance band)
# measured pathologically noisy per-run times on a fresh AWS Nitro boot: it
# ran ~131 min of measurement iterations before converging to the same
# values we pin here (t=4, m~500 MiB, 2 cpus), burning ~1.7 vCPU the whole
# time. On this fixed instance shape the benchmark buys nothing; fixed
# parameters make first boot complete in ~2 s.
#
# Fail-closed: if the TPM cannot unseal under either policy (e.g. the
# kernel or boot disk changed), the volume stays locked, /home remains the
# tmpfs from init, and the instance still boots with root SSH.

LUKS_LABEL="stagex-home"
MAPPED="/dev/mapper/home"
SEED_HANDLE="0x81010200"
SEED_PCRS="5,7"
FULL_HANDLE="0x81010201"
FULL_PCRS="4,5,7,9"
KEYFILE="/run/home-key"
USERDATA="/run/userdata"
FORMAT_LIMIT=900
OPEN_LIMIT=300
MKFS_LIMIT=900
E2FSCK_LIMIT=600
MOUNT_LIMIT=120

# NitroTPM intermittently enters failure states and recovers in seconds;
# retry TPM operations rather than failing the whole step. The last attempt
# leaves its stderr on the serial log so a persistent failure is diagnosable.
# Usage: tpm_retry <outfile> <cmd...>
tpm_retry() {
	local out="$1"; shift
	local tries=1
	while [ "$tries" -le 5 ]; do
		if [ "$tries" -eq 5 ]; then
			"$@" > "$out" 2>&1
			if [ "$?" -eq 0 ]; then
				return 0
			fi
			return 1
		fi
		if "$@" > "$out" 2>/dev/null; then
			return 0
		fi
		sleep 2
		tries=$(( tries + 1 ))
	done
	return 1
}

# Use the Resource-Manager char device first: on the NitroTPM /dev/tpm0
# (direct) intermittently wedges with 0x0902, while /dev/tpmrm0 stays
# reliable (verified on c6a; the RM driver also reclaims per-fd transient
# contexts on close). bootproof takes the device path directly.
if [ -c /dev/tpmrm0 ]; then
	TPM_DEV=/dev/tpmrm0
elif [ -c /dev/tpm0 ]; then
	TPM_DEV=/dev/tpm0
else
	TPM_DEV=
fi

# Attestation gate for key release: on an SEV-SNP host (/dev/sev-guest
# present) the full dual gate applies (in-process SNP proof + TPM PCR
# policy); where there is no SNP device (the QEMU dev loop) it degrades to
# TPM-only — the same detect()-based degradation as the node side.
BP_GATE=""
[ -c /dev/sev-guest ] || BP_GATE="--tpm-only"

# Open the LUKS volume at $1 as dm-crypt "home" (unmounted).
# Pure Rust (bootproof): unseal the persistent handle $2 under PCR policy
# $3 -> LUKS2 master key -> dm-crypt /dev/mapper/home. No --mount here: the
# mount (and the e2fsck / mkfs-recovery path) is mount_or_reformat's job,
# which needs the device open but not yet mounted. Returns 0 on success.
open_volume() {
	mkdir -p /dev/mapper
	[ -c /dev/mapper/control ] || mknod -m 600 /dev/mapper/control c 10 236
	bootproof unseal disk --device "$TPM_DEV" --handle "$2" --pcrs "$3" \
		$BP_GATE --name home "$1"
}

# Close the dm-crypt device "home" (failure-path cleanup). Best effort.
close_volume() {
	dmsetup remove home 2>/dev/null || true
}

# e2fsck, mount the opened volume at /home; on mount failure try a mkfs
# recovery (partially completed first boot: header written, mkfs never ran).
# Returns 0 on success; on final failure closes the volume and returns 1.
mount_or_reformat() {
	disk=$1
	run_io $E2FSCK_LIMIT e2fsck -y "$MAPPED" || true
	if run_io $MOUNT_LIMIT mount "$MAPPED" /home; then
		return 0
	fi
	printf "home: mount failed, trying mkfs recovery on %s\n" "$disk"
	if run_io $MKFS_LIMIT mkfs.ext4 -q -L home "$MAPPED" && \
		run_io $MOUNT_LIMIT mount "$MAPPED" /home; then
		printf "home: (reformatted filesystem on %s)\n" "$disk"
		return 0
	fi
	close_volume
	return 1
}

# Run $2 under a deadline of $1 seconds. The command runs in a background
# subshell (its output goes to $IOLOG); a command that blocks in
# uninterruptible I/O (stuck backing store) cannot be killed, so on expiry
# we abandon it and fail — the boot must not wait forever. Returns the
# command's exit code, or 124 on deadline expiry.
IOLOG="/run/s15-io.log"
run_io() {
	local limit="$1"; shift
	local now deadline pid rc
	: > "$IOLOG"
	"$@" > "$IOLOG" 2>&1 &
	pid=$!
	now=$(date +%s)
	deadline=$(( now + limit ))
	while :; do
		kill -0 "$pid" 2>/dev/null || break
		now=$(date +%s)
		if [ "$now" -ge "$deadline" ]; then
			printf "home: WARN: I/O deadline (%ss) exceeded, abandoning step\n" "$limit"
			# Kill the step so it cannot keep burning vCPUs after boot
			# continues. Do NOT wait: a process in uninterruptible I/O
			# (D state) cannot die yet and would block the boot; the
			# zombie is reaped by init when this script exits.
			kill -9 "$pid" 2>/dev/null
			return 124
		fi
		sleep 5
	done
	# Reap the step and return ITS exit status. `wait "$pid"` is the
	# correct POSIX form — but it MUST run under busybox ash (see the
	# shebang). /bin/sh is brush, and brush's wait builtin is broken for
	# this purpose: `wait "$pid"` is unimplemented (rc 99) and bare
	# `wait` returns 0 regardless of the job's status, which silently
	# turned every failed I/O step into a success (a false
	# "home: ok" with no volume open, and dead fail-closed recovery).
	wait "$pid"
	rc=$?
	return $rc
}

setup_user() {
	local home_user="user" first
	if [ -s "$USERDATA" ]; then
		first=$(head -1 "$USERDATA")
		case "$first" in
			"user "*) home_user=${first#"user "} ;;
		esac
	fi
	# /etc lives on the read-only rootfs: bind-mount writable copies.
	# Idempotent: skip what is already bound (re-runs must not fail).
	mkdir -p /run/etc
	if ! grep -q " /etc/passwd " /proc/mounts; then
		[ -f /run/etc/passwd ] || cp /etc/passwd /run/etc/passwd
		mount --bind /run/etc/passwd /etc/passwd
	fi
	if ! grep -q " /etc/group " /proc/mounts; then
		[ -f /run/etc/group ] || cp /etc/group /run/etc/group
		mount --bind /run/etc/group /etc/group
	fi
	if ! grep -q "^$home_user:" /etc/passwd 2>/dev/null; then
		addgroup -g 1000 "$home_user" >/dev/null 2>&1 || true
		adduser -D -u 1000 -G "$home_user" -h "/home/$home_user" "$home_user"
	fi
	mkdir -p "/home/$home_user/.ssh"
	if [ -s "$USERDATA" ]; then
		grep -E '^(ssh-|ecdsa-|sk-|comment=)' "$USERDATA" \
			> "/home/$home_user/.ssh/authorized_keys"
	fi
	chown -R "$home_user" "/home/$home_user"
	chmod 700 "/home/$home_user/.ssh"
	[ -f "/home/$home_user/.ssh/authorized_keys" ] && \
		chmod 600 "/home/$home_user/.ssh/authorized_keys"
	printf "home: user %s ready (home=%s)\n" "$home_user" "/home/$home_user"
}

# Map any mounted block device to its whole-disk name. Loop devices are
# resolved to their backing file first, so a loop-mounted root (erofs) is
# attributed to the physical disk it lives on.
#   nvme0n1p2 -> nvme0n1   vda1 -> vda   loop0 -> <backing disk>
whole_disk() {
	local dev="${1#/dev/}" backing
	case "$dev" in
		loop[0-9]*)
			backing=$(cat "/sys/block/$dev/loop/backing_file" 2>/dev/null)
			[ -n "$backing" ] && dev="${backing#/dev/}"
			;;
	esac
	case "$dev" in
		nvme*n*p[0-9]*) printf '%s' "${dev%p[0-9]*}" ;;
		[sv]d?[0-9]*)   printf '%s' "${dev%[0-9]}" ;;
		*)              printf '%s' "$dev" ;;
	esac
}

start() {
	local d part data_disk=""
	# Whole-disk names of everything currently mounted (following loop
	# devices back to the physical disk). The root disk is identified this
	# way even when / is a loop-mounted erofs image.
	local mounted="" mounted_disks="" rootsrc
	mounted=$(awk '{print $1}' /proc/mounts 2>/dev/null | sed 's|^/dev/||' | tr '\n' ' ')
	for m in $mounted; do
		local md
		md=$(whole_disk "$m")
		case " $mounted_disks " in
			*" $md "*) ;;
			*) mounted_disks="$mounted_disks $md" ;;
		esac
	done
	rootsrc=$(awk '$2=="/" {print $1; exit}' /proc/mounts 2>/dev/null | sed 's|^/dev/||')
	local root_disk=""
	[ -n "$rootsrc" ] && root_disk=$(whole_disk "$rootsrc")
	for d in /dev/nvme*n* /dev/sd? /dev/vd[!a]; do
		[ -b "$d" ] || continue
		part=${d##*/}
		case "$part" in
			*p[0-9]*) continue ;;
		esac
		# A whole-disk data volume (blank or LUKS) has no partitions, while a
		# boot disk always exposes at least one (ESP + system). Skip any disk
		# that has partitions: this identifies the root disk even when / is a
		# loop-mounted erofs and the physical disk never appears in
		# /proc/mounts. Partition child names: nvme0n1p1 for nvme, vda1 for
		# sd/vd (checked by name — the "device" symlink also carries a dev
		# file and must not count as a partition). Skip trivially small
		# disks (e.g. a 512-byte cloud placeholder) too.
		hp=0
		case "$part" in
			nvme*n*)
				for child in /sys/block/$part/${part}p[0-9]*; do
					[ -e "$child" ] && { hp=1; break; }
				done
				;;
			*)
				for child in /sys/block/$part/${part}[0-9]*; do
					[ -e "$child" ] && { hp=1; break; }
				done
				;;
		esac
		[ "$hp" = 1 ] && continue
		size=$(cat /sys/block/$part/size 2>/dev/null)
		[ -n "$size" ] && [ "$size" -lt 2048 ] && continue
		case " $mounted_disks $root_disk " in
			*" $part "*) continue ;;
		esac
		data_disk=$d
		break
	done

	if [ -n "$data_disk" ]; then
		local sig=""
		sig=$(blkid -o value -s TYPE "$data_disk" 2>/dev/null | head -1)
		case "$sig" in
			crypto_LUKS)
				if [ -z "$TPM_DEV" ]; then
					printf "home: locked (no TPM; /home stays tmpfs)\n"
				elif run_io $OPEN_LIMIT open_volume "$data_disk" "$FULL_HANDLE" "$FULL_PCRS"; then
					if mount_or_reformat "$data_disk"; then
						printf "home: ok (luks %s, pcrs %s)\n" "$data_disk" "$FULL_PCRS"
					else
						close_volume
						printf "home: locked (mount failed; /home stays tmpfs)\n"
					fi
				elif run_io $OPEN_LIMIT open_volume "$data_disk" "$SEED_HANDLE" "$SEED_PCRS"; then
					# Second-boot migration: re-seal the same key under the full
					# policy. bootproof unseals the seed and seals the full in
					# ONE process — the key bytes never touch the shell.
					# Idempotent (no-op once the full handle already exists).
					migrated=0
					if tpm_retry /dev/null bootproof dmext migrate \
							--device "$TPM_DEV" --from-pcrs "$SEED_PCRS" \
							--to-pcrs "$FULL_PCRS" $BP_GATE \
							"$SEED_HANDLE" "$FULL_HANDLE"; then
						migrated=1
					else
						migrated=2
					fi
					if mount_or_reformat "$data_disk"; then
						if [ "$migrated" = 1 ]; then
							printf "home: ok (luks %s, seed pcrs %s, migrated to pcrs %s)\n" \
								"$data_disk" "$SEED_PCRS" "$FULL_PCRS"
						else
							printf "home: ok (luks %s, seed pcrs %s)\n" \
								"$data_disk" "$SEED_PCRS"
						fi
					else
						close_volume
						printf "home: locked (mount failed; /home stays tmpfs)\n"
					fi
					[ "$migrated" = 2 ] && \
						printf "home: WARN: migration to pcrs %s failed (seed still opens)\n" "$FULL_PCRS"
				else
					printf "home: locked (TPM unseal failed; /home stays tmpfs)\n"
				fi
				;;
			"")
				# Blank disk: first-boot setup. The full PCR policy cannot be
				# used yet (PCR 4 and 9 drift on first boot), so the key is
				# sealed under the seed policy; the full policy is applied on
				# the next boot. The key is sealed BEFORE any disk I/O so a
				# crash or a stuck volume mid-setup never loses it: the next
				# boot unseals it and heals the volume (mkfs recovery) or
				# re-formats it (which replaces the sealed key below).
				umask 077
				if [ -n "$TPM_DEV" ] && \
						dd if=/dev/urandom of="$KEYFILE" bs=32 count=1 >/dev/null 2>&1 && \
						tpm_retry /dev/null bootproof dmext seal \
							--device "$TPM_DEV" --pcrs "$SEED_PCRS" \
							"@$KEYFILE" --persistent "$SEED_HANDLE" --out /dev/null; then
					# Fixed PBKDF parameters, no benchmark (see header): the
					# benchmark's +/-5 % convergence loop ran for ~131 min on
					# one fresh AWS boot before settling on exactly these values.
					pbkdf_cpus=$(nproc 2>/dev/null)
					case "$pbkdf_cpus" in ''|*[!0-9]*) pbkdf_cpus=1 ;; esac
					if run_io $FORMAT_LIMIT cryptsetup luksFormat --type luks2 \
							--label "$LUKS_LABEL" --batch-mode --key-file "$KEYFILE" \
							--pbkdf-force-iterations 4 --pbkdf-memory 512000 \
							--pbkdf-parallel "$pbkdf_cpus" "$data_disk" && \
						run_io $OPEN_LIMIT open_volume "$data_disk" "$SEED_HANDLE" "$SEED_PCRS" && \
						run_io $MKFS_LIMIT mkfs.ext4 -q -L home "$MAPPED" && \
						run_io $MOUNT_LIMIT mount "$MAPPED" /home; then
						rm -f "$KEYFILE"
						printf "home: ok (formatted %s, seed pcrs %s; full pcrs %s apply next boot)\n" \
							"$data_disk" "$SEED_PCRS" "$FULL_PCRS"
					else
						# Format/open/mkfs/mount failed (or the backing store is
						# stuck). Keep the sealed key: if the LUKS header made it
						# to disk, the next boot unseals it and completes the
						# setup (mkfs recovery). If the disk is still blank, the
						# next boot re-formats and replaces the sealed key.
						close_volume
						rm -f "$KEYFILE"
						printf "home: WARN: setup incomplete on %s, key kept for next boot — stop/start clears a stuck volume\n" "$data_disk"
					fi
				else
					rm -f "$KEYFILE"
					printf "home: setup failed on %s (keygen or TPM seal failed)\n" "$data_disk"
				fi
				;;
			*)
				printf "home: skipped (%s has %s)\n" "$data_disk" "$sig"
				;;
		esac
	else
		printf "home: no data disk\n"
	fi

	setup_user
	return 0
}



# One-shot (execd oneshot unit): run the setup once, always exit 0.
start
exit 0
