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

### Current Blocker: Config Drive (ISO CD-ROM)
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
