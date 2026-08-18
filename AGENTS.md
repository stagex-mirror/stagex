# StageX Project Memory

## AI Assistant Notes

### Critical: Binary Data Output
- **NEVER pipe binary data to stdout** in bash commands — causes session crashes (provider timeout). Use `xxd`, `hexdump`, or redirect to file.

## Build / Test Commands
- Build distro: `pallet build` (uses Pallet container builder)
- Build all: `pallet build --all`
- QEMU test: `docker exec -it qemu-busybox-dev run ssh`

### Critical: Build Cache Rules
- **NEVER use `NOCACHE=1`** unless intentionally rebuilding the entire tree — it passes `--no-cache` to every `docker build`, destroying all Docker BuildKit cache across all packages.
- **NEVER delete `out/*/` directories** unless you accept a full rebuild — the Makefile depends on OCI layouts at `out/{stage}-{name}/index.json` as build targets. Deleting them breaks dependency resolution.
- **To force a single target rebuild:** only remove that target's output dir, e.g. `rm -rf out/distro-busybox-dev && make distro-busybox-dev`. Leave dependency dirs (`out/core-busybox`, `out/user-linux-server`, etc.) intact.
- **Docker BuildKit is content-addressed:** if source files change, only affected stages rebuild automatically (no NOCACHE needed).

### Subpackages
- `core-busybox` busybox-init subpackage removed (scripts moved to distro)

### EC2 AMI Pipeline
- Build: `make distro-busybox-dev`
- Extract: `docker run --rm --entrypoint cat stagex/distro-busybox-dev:local /disk.img > out2/disk.img`
- Import: `docker run --rm -e AMI_NAME=... -e AWS_REGION=us-east-1 -e DISK_IMAGE=/disk.img -e AWS_ACCESS_KEY_ID=... -e AWS_SECRET_ACCESS_KEY=... -v out2/disk.img:/disk.img:ro stagex/box-aws-ami:local /usr/bin/box`
- Kernel config option is `CONFIG_ENA_ETHERNET=y` (not `CONFIG_ENA` — renamed in kernel 7.0)
- Kernel config option `CONFIG_NET_VENDOR_AMAZON=y` must be set for ENA driver

## Current Focus: SSH and Config Drive (lance/distros branch)

### Completed
- **tinyssh migration** — replaced openssh with tinyssh (~100KB vs ~3MB). Uses tcpsvd for TCP listener (tinysshd doesn't daemonize). Key dir at `/run/tinyssh/keys/`, reads `authorized_keys` from there.
- **busybox-init consolidation** — init scripts moved from `core-busybox-init` subpackage into `packages/distro/busybox/src/rootfs/etc/init.d/`
- **toybox update** — 0.8.13 → 0.8.14
- **README distros section** — added planned distro table
- **tmpfs mounts in init** — /run, /tmp, /var/log, /var/run, /var/tmp, /etc/keys, /root

### Completed: TPM2/SEV-SNP Attestation (July 30 - Aug 5, lance/distros)
- **TPM2 attestation on AWS EC2** — Successfully verified on c6a.large. PCR 7 matches between local QEMU and AWS: `65CAF8DD1E0EA7A6347B635D2B379C93B9A1351EDC2AFC3ECDA700E534EB3068`. AWS NitroTPM v2.0 via `/dev/tpmrm0`.
- **rust-keylime agent** — Replaced Python keylime with rust-keylime v0.2.10 (8.7MB binary). Added `skip_registration` patch for standalone mode. Keylime serves TPM2 quotes over HTTP port 9002. `src/verify-enclave` script for remote verification.
- **coconut-svsm** — Added as `enclave-sev-snp` distro variant replacing swtpm with coconut-svsm for SEV-SNP e-vTPM. S50coconut-svsm init script detects `/dev/sev-guest`.
- **core-rust bare-metal target** — Added `x86_64-unknown-none` std library (subpackage `libstd-x86_64-none`). Enables coconut-svsm to compile no_std without rustup. Build stage uses `FROM build AS build-rust-libstd-x86_64-none` to preserve cache.
- **cbindgen** — Added as `user-cbindgen` (packages/user/cbindgen/).
- **AWS EC2 box** — Updated to OpenTofu with built-in AWS provider. Added `enable_tpm = true` and `enable_sev_snp = true`. Fixed AMI creation (`role_name="vmimport"`). Automated pipeline: `make aws-ami-deploy` → `make aws-ec2-deploy` → `make aws-keylime-test`.

### Completed: SEV-SNP/TPM2 Byte-Level Binding (Aug 15-18, lance/distros)
- **VERDICT: BOUND** — `src/verify-binding` proves SNP + TPM2 attestations describe the same kernel/initrd/cmdline/rootfs on live us-east-2 c6a.large (SEV-SNP + NitroTPM).
- **TPM channel (byte level):** TCG 2.0 crypto-agile event log (dumped from `/dev/mem` at `TPMEventLog=` addr) parsed by `src/elscan.rs`; PCR9 "Linux initrd" + "LOADED_IMAGE::LoadOptions" events are emitted by the kernel's own EFI stub (so their digests == SHA256/384 of our exact initramfs/cmdline); GRUB `tpm` module (added to `packages/box/grub/src/box` module list) measures vmlinuz into the log; full PCR9 replay from zero == live EK-quoted PCR 9.
- **Rootfs channel:** `S54tpm-rootfs` init script extends PCR 11 with SHA256 of raw system partition (erofs, read-only so late measurement is equivalent). Verifier hashes the same partition region of local `disk.img` and checks extend(0, h) == live PCR 11. Partition geometry is deterministic from `box-gpt`: system starts LBA 1050624 (513 MiB), ends at last 1 MiB-aligned boundary; live geometry from `/sys/block/<disk>/<part>/{start,size}` (note: partitions are under the disk dir, NOT flat in /sys/block).
- **Pitfalls hit:** (1) NitroTPM intermittently enters failure states ("commands not being accepted because of a TPM failure") and recovers in seconds — TPM operations at boot need retries; (2) init scripts must be mode 755 (files created by editors default to 644 and rcS `$i start` fails silently — this silently killed S53snptpm-agent and S54tpm-rootfs once); (3) `docker load` of the OCI layout does NOT re-tag `:local` — always `docker tag <new-id> stagex/distro-enclave-dev:{2026.03.0,local}` or the AMI pipeline extracts a stale disk; (4) `chmod` on sources doesn't update mtime, so Makefile sentinels say "nothing to be done" — `rm -rf out/rootfs/distro-enclave-dev out/oci/distro-enclave-dev` to force rebuild; (5) busybox `ls -d A B` prints nothing if B is missing (unlike GNU).
- **Pipeline:** `make distro-enclave-dev` → `make oci-distro-enclave-dev` → `env -C out/oci/distro-enclave-dev tar -cf - . | docker load` → manual `docker tag` → `make aws-ami-deploy` → `make aws-ec2-deploy` → `sh /tmp/verify-new-instance.sh <ip>` (fetches pcrs/cmdline/event log/SNP report/partition geometry, runs verify-binding).
- **Known cosmetic bug (not fixed):** rcS `mark()` NVMe disk-name derivation `${mi_n%?}` yields `nvme0n1p` for `nvme0n1p1`, so rcS boot markers land at the 32 MB fallback seek instead of the ESP tail (initramfs markers are correct).

### Stale (Aug 18): Config Drive (ISO CD-ROM)
- **OpenStack-style config drive** — ISO9660 CD-ROM with `hostname` and `authorized_keys`, attached via `-drive ... if=none,media=cdrom` + `-device virtio-scsi-pci` + `-device scsi-cd`
- SSH works end-to-end (tinysshd connects, key exchange succeeds) but auth fails because config drive never mounts
- **Root cause:** kernel detects CD-ROM (`sr 0:0:0:0: [sr0]`), SR driver registers, major 11 "sr" in `/proc/devices`, but `/sys/block/sr0` never created. Block device registration silently fails.
- **Verified configs (built kernel):** CONFIG_SCSI=y, CONFIG_BLK_DEV=y, CONFIG_BLK_DEV_SR=y, CONFIG_CDROM=y, CONFIG_ISO9660_FS=y, CONFIG_SCSI_VIRTIO=y, CONFIG_SCSI_LOWLEVEL=y — all correct
- Tried: IDE CD-ROM, AHCI SATA CD-ROM, virtio-scsi CD-ROM, -cdrom flag, PIIX3 IDE — same result. Not a QEMU args issue.
- Likely kernel bug/incompatibility in minimal config where SR driver sees device but never creates block device sysfs entry

### Next Steps
- Switch config drive from ISO CD-ROM to virtio-blk ext4 disk (same file structure, guaranteed working)
- Or continue debugging kernel (likely need CONFIG_IKCONFIG_PROC working to verify running config)

### QEMU Test
- `make qemu-start` — starts VM, waits for SSH on port 2222
- Logs visible via `docker logs qemu-dev` (QEMU serial → container stdout)
- SSH key: `~/.ssh/tpm-exploration.pem`
