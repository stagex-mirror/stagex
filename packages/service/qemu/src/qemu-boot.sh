#!/usr/bin/sh
# qemu-boot.sh — assembles and launches qemu-system-x86_64 from env vars
#
# Env vars (all optional, shown defaults):
#   QEMU_MEMORY=8G
#   QEMU_DISK=/disk.img
#   QEMU_CONFIG=/config.img        (empty = skip)
#   QEMU_BIOS=/usr/share/edk2/OvmfPkg/OVMF.fd
#   QEMU_DISPLAY=none              (none | curses)
#   QEMU_SERIAL=telnet:0.0.0.0:4000,server,nowait
#   CONSOLE_PORT=4000                 (telnet serial port)
#   CONSOLE_SOCKET=/run/qemu-console.sock  (unix socket bridge to serial)
#   QEMU_TPM=1                    (0 = skip TPM)
#   QEMU_VSOCK_CID=3              (0 = skip vsock)
#   QEMU_KVM=1                    (0 = never force KVM)
#   QEMU_NET_HOSTFWD=             (hostfwd rules, e.g. tcp::22-:22)
#
# Any remaining args are passed verbatim to qemu-system-x86_64.

set -e

# --- Serial console Unix socket ---
# socat bridge keeps QEMU telnet serial open from boot, exposes it as Unix socket
: "${CONSOLE_SOCKET:=/run/qemu-console.sock}"
: "${CONSOLE_PORT:=4000}"
rm -f "${CONSOLE_SOCKET}"
socat UNIX-LISTEN:"${CONSOLE_SOCKET}",fork,mode=0777 \
    TCP:127.0.0.1:"${CONSOLE_PORT}" &

# --- TPM ---
if [ "${QEMU_TPM:-1}" != "0" ]; then
    mkdir -p /tmp/tpm
    swtpm socket \
        --tpmstate dir=/tmp/tpm \
        --ctrl type=unixio,path=/tmp/vtpm-sock \
        --tpm2 &
    sleep 1
fi

# --- Build QEMU args ---
QEMU_ARGS="-m ${QEMU_MEMORY:-8G}"
QEMU_ARGS="$QEMU_ARGS -machine q35,kernel-irqchip=split"
QEMU_ARGS="$QEMU_ARGS -drive file=${QEMU_DISK:=/disk.img},format=raw,if=virtio"
QEMU_ARGS="$QEMU_ARGS -bios ${QEMU_BIOS:=/usr/share/edk2/OvmfPkg/OVMF.fd}"
QEMU_ARGS="$QEMU_ARGS -display none"
QEMU_ARGS="$QEMU_ARGS -chardev stdio,id=console"
QEMU_ARGS="$QEMU_ARGS -serial chardev:console"
QEMU_ARGS="$QEMU_ARGS -serial telnet:0.0.0.0:${CONSOLE_PORT:-4000},server,nowait"

# Network
NET_OPTS="user,id=net0"
if [ -n "${QEMU_NET_HOSTFWD:-}" ]; then
    NET_OPTS="$NET_OPTS,hostfwd=${QEMU_NET_HOSTFWD}"
fi
QEMU_ARGS="$QEMU_ARGS -netdev $NET_OPTS"
QEMU_ARGS="$QEMU_ARGS -device e1000,netdev=net0"

# Config drive (optional)
if [ -n "${QEMU_CONFIG:-}" ] && [ -e "${QEMU_CONFIG}" ]; then
    QEMU_ARGS="$QEMU_ARGS -drive file=${QEMU_CONFIG},format=raw,if=virtio"
fi

# vhost-vsock (optional)
if [ "${QEMU_VSOCK_CID:-0}" != "0" ]; then
    QEMU_ARGS="$QEMU_ARGS -device vhost-vsock-pci,guest-cid=${QEMU_VSOCK_CID}"
fi

# TPM (optional)
if [ "${QEMU_TPM:-1}" != "0" ]; then
    QEMU_ARGS="$QEMU_ARGS -chardev socket,id=chrtpm,path=/tmp/vtpm-sock"
    QEMU_ARGS="$QEMU_ARGS -tpmdev emulator,id=tpm0,chardev=chrtpm"
    QEMU_ARGS="$QEMU_ARGS -device tpm-tis,tpmdev=tpm0"
fi

# KVM (optional)
if [ "${QEMU_KVM:-1}" = "1" ] && [ -e /dev/kvm ]; then
    QEMU_ARGS="$QEMU_ARGS -cpu host --accel kvm"
fi

# Pass through user args
if [ $# -gt 0 ]; then
    QEMU_ARGS="$QEMU_ARGS $@"
fi

exec /usr/bin/qemu-system-x86_64 $QEMU_ARGS
