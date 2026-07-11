# Memory — 2026-07-10

## Completed
- box-grub package (RUN box pattern, script renamed to `box`)
- distro-server-dev refactored to build → box → package stages
- service category created (pallet-qemu → service-qemu)
- box category created
- distro-server-busybox with 6 stages: base, dev, system, system-dev, package, package-dev
  - `make vm` → server-busybox-dev, `make DISTRO=server-busybox vm` → bare bones
  - Both variants tested and booting
- Makefile: IMAGE → DISTRO variable, supports -dev suffix auto-mapping
- box-aws-ami scaffolded (S3 upload + AMI creation via OpenTofu)
- box-img created: StageX-built tool (busybox mkfs.ext2 + loop mount)
  - Converts local/home/ → out/<distro>-home.img
- Home disk support in QEMU VMs:
  - Guest mounts /dev/vdb → /home at boot
  - qemu-startup.sh passes QEMU_HOME as second virtio disk
  - sshd reads keys from /home/%u/.ssh/authorized_keys
  - local/ folder .gitignored for mutable state

## Todo
- [ ] Test SSH into dev variant with key in local/server-busybox-dev/home/root/.ssh/
- [ ] Test bare bones variant boots without home disk issues
- [ ] Copy qemu-startup.sh and init to server-dev (shared pattern)
- [ ] Add more distros (desktop, cloud, etc.)
- [ ] Test box-aws-ami with real AWS credentials
- [ ] Publish box-grub, box-img, service-qemu to Docker Hub

## Notes
- server-busybox-dev symlink needed for targets.py recognition
- box-img runs privileged for loop mount support
- Home disk is rw ext2, 64MB default
- The `box` pattern: any box package runs `RUN box` to assemble artifacts
