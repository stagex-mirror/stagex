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
- `core-busybox` has subpackage `busybox-init` → target is `core-busybox-init`, not `core-busybox`
- The `core-busybox-init` image holds init scripts (S03dhcpcd, S06cloud-init-net, etc.)
- To update init scripts: rebuild `core-busybox-init`, then rebuild dependent distros

### EC2 AMI Pipeline
- Build: `make distro-busybox-dev`
- Extract: `docker run --rm --entrypoint cat stagex/distro-busybox-dev:local /disk.img > out2/disk.img`
- Import: `docker run --rm -e AMI_NAME=... -e AWS_REGION=us-east-1 -e DISK_IMAGE=/disk.img -e AWS_ACCESS_KEY_ID=... -e AWS_SECRET_ACCESS_KEY=... -v out2/disk.img:/disk.img:ro stagex/box-aws-ami:local /usr/bin/box`
- Kernel config option is `CONFIG_ENA_ETHERNET=y` (not `CONFIG_ENA` — renamed in kernel 7.0)
- Kernel config option `CONFIG_NET_VENDOR_AMAZON=y` must be set for ENA driver

## Current Focus: Networking Debug (lance/distros branch)
- Cloud-init net script (S06) reaches AWS metadata at 169.254.169.254
- dhcpcd moved to S03 to start BEFORE cloud-init scripts
- Wait loop increased from 10s to 20s for slower EC2 boot
- Kernel has e1000, e1000e, and virtio_net built-in
- QEMU uses e1000 NIC with user-mode networking + SSH forwarding on port 2222
