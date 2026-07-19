# StageX Project Memory

## AI Assistant Notes

### Critical: Binary Data Output
- **NEVER pipe binary data to stdout** in bash commands — causes session crashes (provider timeout). Use `xxd`, `hexdump`, or redirect to file.

## Build / Test Commands
- Build distro: `pallet build` (uses Pallet container builder)
- Build all: `pallet build --all`
- QEMU test: `docker exec -it qemu-busybox-dev run ssh`

## Current Focus: Networking Debug (lance/distros branch)
- Cloud-init net script (S06) reaches AWS metadata at 169.254.169.254
- dhcpcd moved to S03 to start BEFORE cloud-init scripts
- Wait loop increased from 10s to 20s for slower EC2 boot
- Kernel has e1000, e1000e, and virtio_net built-in
- QEMU uses e1000 NIC with user-mode networking + SSH forwarding on port 2222
