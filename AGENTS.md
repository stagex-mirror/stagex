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

### Distro package layout (Aug 18-19 refactor, lance/distros)
- Distro subpackages split three ways per variant: **default** = live layout (rootfs contents + `/boot` with the three boot objects [vmlinuz, initramfs, cmdline] — no UKI in the live layout); `docker run` gives a shell on the booted filesystem. **`-img`** = scratch + `/disk.img` (box-disk takes the full live layout and does all the packing). **`-vm`** = service-qemu + `/disk.img`.
- `box-uki` (packages/box/uki) is a **pure function**: (vmlinuz, initramfs, cmdline [, os-release]) → the final EFI layout containing ONLY the UKI at `EFI/BOOT/BOOTX64.EFI` (ukify + systemd-stub; deterministic, same inputs → same bytes). If os-release is omitted, ukify 260.2 auto-falls back to the build image's `/etc/os-release` — box-disk always passes the distro's own file explicitly.
- `box-disk` (packages/box/disk) is the single disk assembler, orchestrating the inner boxes: box-uki on `/boot/*` → ESP tree → FAT boot.img sized exactly to the UKI (busybox mcopy: `mcopy -sm $ESP/EFI ::/` puts the tree at the FAT root — copying `$ESP` itself nests it under `::/esp`), box-erofs → system.img (live layout minus `/boot`), box-gpt → GPT `disk.img`.
- **ESP/disk sizing (Aug 20):** the ESP is sized to the UKI, not a fixed 512 MiB. **Always FAT32 with 4 KiB clusters** (padded to FAT32's 65525-cluster minimum, ~256 MiB). UKI volume serial pinned (`-i 0x53544147`). `box-gpt` derives the ESP partition size from the boot.img file; ESP-only (unikernel) disk = ESP + 2 MiB tail for the alternate GPT header. **Why not FAT16:** an earlier revision used FAT16 with 16 KiB clusters for UKIs under 1 GiB, and it booted in QEMU (edk2 202508) but **never booted on AWS Nitro UEFI** (instance sat `running`, no serial output, no status checks, port 22 closed) — the old Nitro firmware does not boot that ESP. The pre-UKI AWS-working image used FAT32, and FAT32/4KiB ESPs boot on AWS (verified Aug 20: port 22 open ~45 s after launch). Enclave disk.img: 528 → **259 MiB** (257 MiB ESP).
- The booted system **never mounts the ESP** (no `/boot`, no vfat mount in the guest): rcS/initramfs write progress markers by raw `dd` seeks to the ESP tail. So the final ESP legitimately contains only the UKI (kernel/initrd/cmdline live inside it, verified byte-identical in [2]).
- `box-grub` with `TREE_ONLY=1` leaves the ESP tree at /boot + /efi instead of packing a FAT image (embed distro still uses the default packing path; embed is a separate GRUB/limine flow).
- Consumers of disk.img use the `-img` subpackage: `make distro-enclave-dev-img`, `out/rootfs/distro-enclave-dev-img/linux_amd64/disk.img`; aws-ami extracts via plain `cp` from the local export (the -img image has no command, so `docker create` on it fails).
- erofs images are NOT bit-deterministic across builds (internal NIDs/layout differ), so any measurement pin over the erofs bytes changes per build; the binding stays valid because local artifacts and the live system come from the same build. The UKI itself IS bit-deterministic for fixed inputs (same kernel/initrd/cmdline/osrel/stub → same bytes, e.g. `c913d89c…` across rebuilds in disk mode). Note: in unikernel mode the initrd embeds the erofs, so the UKI changes per build too.
- **Re-verified after restructure:** disk with UKI-only ESP boots QEMU and `verify-binding --uki` → **VERDICT: BOUND** (PCR4/5/9/11 pins unchanged from the pre-restructure BOUND run).

### Unikernel enclaves (Aug 19, lance/distros)
- Enclaves run fully from RAM: `box-disk` with `UNIKERNEL=1` packs the OS as erofs, wraps it as `/system` inside a tiny cpio (5 static klibc utils + `init-loop` as `/init`), and uses that cpio as the UKI's `.initrd`. The kernel unpacks it to RAM; `/init` does `losetup /dev/loop0 /system` + `mount -t erofs` + `pivot_root`. The disk is ESP-only — pure firmware boot target, storage optional.
- Live layout `/boot` = `{vmlinuz, cmdline}` (no initramfs; `uki-cmdline-uk`, no `root=`/`rootwait`).
- Attestation: the ENTIRE OS is inside the measured `.initrd` UKI section → SNP kernel/initrd/cmdline digests + PCR9 UKI event-log replay cover the whole system. The PCR11 system-partition channel is obsolete for enclaves (no partition exists). `S54tpm-rootfs` needs a guard (no `/dev/xvda2` at boot).
- QEMU-verified: `/` = `/dev/loop0` (erofs in RAM), `losetup -a` = `/dev/loop0: 0 /system`, only `vda1` (ESP), tinyssh up.
- kernel only accepts cpio as initrd — raw erofs can't be the `.initrd`; the cpio is the minimal wrapper (one file entry). `initerofs` (LKML 2025-12-31, unmerged) would pin the initrd region for the VM's lifetime and force a writable overlayfs root — rejected for enclaves.
- **AWS-verified (Aug 20): VERDICT: BOUND on live us-east-2 c6a.large** (SEV-SNP + NitroTPM). `verify-binding --uki --no-part`: [2] `.linux`/`.initrd`/`.cmdline` sections byte-match local artifacts (whole OS bound via the measured `.initrd`), [3] PCR4 replay==live, [4] all 12 stub section digests == log + PCR11 replay==live (no partition extend — `--no-part`), [4b] PCR9 predicted, [5] all other PCRs replay==live, [7] SNP v5 report echoes our 64-byte nonce. `S54tpm-rootfs` correctly no-ops (`SKIP no-partition`). `--no-part` replaces the `--disk`/partition-2 path for ESP-only images.
- **Boot regression hit (Aug 20):** first AWS deploy of the unikernel disk never booted (running, no serial, no status checks) — root cause was the FAT16/16KiB ESP; switched to FAT32/4KiB and it booted in ~45 s. QEMU (edk2 202508) booted the FAT16 ESP fine, so **AWS Nitro firmware is the stricter gate — an ESP layout change must be re-tested on AWS, not just QEMU**.

### Completed: SEV-SNP/TPM2 Byte-Level Binding (Aug 15-18, lance/distros)
- **VERDICT: BOUND** — `src/verify-binding` proves SNP + TPM2 attestations describe the same kernel/initrd/cmdline/rootfs on live us-east-2 c6a.large (SEV-SNP + NitroTPM).
- **TPM channel (byte level):** TCG 2.0 crypto-agile event log (dumped from `/dev/mem` at `TPMEventLog=` addr) parsed by `src/elscan.rs`; PCR9 "Linux initrd" + "LOADED_IMAGE::LoadOptions" events are emitted by the kernel's own EFI stub (so their digests == SHA256/384 of our exact initramfs/cmdline); GRUB `tpm` module (added to `packages/box/grub/src/box` module list) measures vmlinuz into the log; full PCR9 replay from zero == live EK-quoted PCR 9.
- **Rootfs channel:** `S54tpm-rootfs` init script extends PCR 11 with SHA256 of raw system partition (erofs, read-only so late measurement is equivalent). Verifier hashes the same partition region of local `disk.img` and checks extend(0, h) == live PCR 11. Partition geometry is deterministic from `box-gpt`: system starts LBA 1050624 (513 MiB), ends at last 1 MiB-aligned boundary; live geometry from `/sys/block/<disk>/<part>/{start,size}` (note: partitions are under the disk dir, NOT flat in /sys/block).
- **Pitfalls hit:** (1) NitroTPM intermittently enters failure states ("commands not being accepted because of a TPM failure") and recovers in seconds — TPM operations at boot need retries; (2) init scripts must be mode 755 (files created by editors default to 644 and rcS `$i start` fails silently — this silently killed S53snptpm-agent and S54tpm-rootfs once); (3) `docker load` of the OCI layout does NOT re-tag `:local` — always `docker tag <new-id> stagex/distro-enclave-dev:{2026.03.0,local}` or the AMI pipeline extracts a stale disk; (4) `chmod` on sources doesn't update mtime, so Makefile sentinels say "nothing to be done" — `rm -rf out/rootfs/distro-enclave-dev out/oci/distro-enclave-dev` to force rebuild; (5) busybox `ls -d A B` prints nothing if B is missing (unlike GNU).
- **Pipeline:** `make distro-enclave-dev` → `make oci-distro-enclave-dev` → `env -C out/oci/distro-enclave-dev tar -cf - . | docker load` → manual `docker tag` → `make aws-ami-deploy` → `make aws-ec2-deploy` → `sh /tmp/verify-new-instance.sh <ip>` (fetches pcrs/cmdline/event log/SNP report/partition geometry, runs verify-binding).
- **Known cosmetic bug (not fixed):** rcS `mark()` NVMe disk-name derivation `${mi_n%?}` yields `nvme0n1p` for `nvme0n1p1`, so rcS boot markers land at the 32 MB fallback seek instead of the ESP tail (initramfs markers are correct).

### Completed: UKI firmware-direct boot + BOUND on QEMU & AWS (Aug 19, lance/distros)
- **Boot model (no GRUB):** firmware boots `\EFI\BOOT\BOOTX64.EFI` directly; the PE entry is `systemd-stub` (assembled by `ukify`), which loads `.linux`, reads `.cmdline`, and handovers to the kernel. GRUB is gone from the enclave trust path.
- **PCR semantics (verified in source + QEMU + AWS):** **PCR4** = OVMF boot-path markers (action strings + boot-option device path), NOT a hash of the UKI — the byte-level UKI binding is carried by section decomposition + PCR11. **PCR5** = OVMF `Tcg2MeasureGptTable` (92-byte GPT header + `u32 count` + `u32 0` + valid non-zero-GUID entries) PLUS an unlogged OVMF boot-order extend → checked by its logged GPT event, excluded from blind replay. **PCR11** = stub measures each UKI section (name+NUL, then data, stub enum order, skipping `.pcrsig`) + `S54tpm-rootfs` `extend(SHA256(system partition))`. **PCR9** = kernel `LOADED_IMAGE::LoadOptions` (`SHA256(UTF-16LE(cmdline)+\x00\x00)`) + `Linux initrd` (`SHA256` of the stub's **combined** initrd = ALIGN4(`.initrd`) + the stub's `.extra/os-release` cpio when `.osrel` present).
- **VERDICT: BOUND on BOTH QEMU and live AWS** (us-east-2 c6a.large, SEV-SNP + NitroTPM, NVMe). `src/verify-binding --uki` reworked: [2] PE-section decomposition (VirtualSize semantics), [3] PCR4 replay==live + PCR5 GPT==local disk, [4] PCR11 predicted section digests + replay+rootfs-extend==live, [4b] PCR9 LoadOptions+initrd predicted, [5] full replay of all other PCRs.
- **SNP report parser fixed for v5 ABI layout** (was off): version@0x00, policy@0x08, vmpl@0x2C, report_data@0x50, measurement(SHA-384)@0x90, sig@0x2A0 (512B). Added `--snp-nonce <file>`: the report's `report_data` must echo back the 64-byte nonce we supplied — an anti-replay freshness proof (QEMU's zeroed dummy report auto-skips).
- **`snpguest` gotchas:** arg order is `snpguest report <out> <in>` (report path FIRST, nonce/request file SECOND) — the reverse of the old script; and pass `-v 0` (guest runs at VMPL0, snpguest defaults to VMPL1).
- **AWS reachability incident (resolved):** a launched c6a can sit `running` with `reachability=failed` and no SSH for hours while VPC/SG/NACL/ENI all look correct — it was a transient host/network issue (the prior known-good GRUB instance died the same way). `reboot-instances` did NOT fix it; `stop-instances` → `start-instances` (migrates to a fresh Nitro host) did. SEV-SNP instances have **encrypted console output** (no boot visibility); to get a readable console, launch the same AMI with `EC2_ENABLE_SEV_SNP=false` (c6a still auto-provisions NitroTPM for `TpmSupport` AMIs — no `--enable-tpm` CLI flag exists).
- **Verify pipeline (UKI):** `make distro-enclave-dev-img` → keep `out/disk.img` in sync with `out/rootfs/distro-enclave-dev-img/linux_amd64/disk.img` → `make aws-ami-deploy` → `make aws-ec2-deploy` → `sh /tmp/verify-uki-instance.sh <ip>` (waits for SSH, retries `tpm2_pcrread`, dumps event log from a 4K-aligned window before `TPMEventLog`, uploads a fresh 64-byte nonce, `snpguest report -v 0`, reads `/run/tpm-rootfs.status` + `/sys/block/<disk>/<part2>` geometry, runs `verify-binding --uki … --snp-nonce`). QEMU (`qemu-dev`, ssh -p 2222) is the fast iteration path and stays green.

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
