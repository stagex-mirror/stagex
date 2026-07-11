#!/usr/bin/sh
# qemu-startup.sh — backgrounds QEMU, keeps container alive

# --- Use build-time SSH key (embedded in image) ---
KEY="/ssh_host_key"

# --- Log file for QEMU output (visible via docker logs) ---
QEMU_LOG="/tmp/qemu.log"

# --- Serial console socket bridge ---
rm -f "${CONSOLE_SOCKET:-/run/qemu-console.sock}"
/usr/bin/socat UNIX-LISTEN:"${CONSOLE_SOCKET:-/run/qemu-console.sock}",fork,mode=0777 \
    TCP:127.0.0.1:"${CONSOLE_PORT:-4000}" &

# --- QMP socket ---
rm -f "${QMP_SOCKET:-/run/qemu-vm/qmp.sock}"
chmod 777 "${QMP_SOCKET:-/run/qemu-qmp.sock}" 2>/dev/null || true

# --- TPM (optional) ---
if [ "${QEMU_TPM:-1}" != "0" ]; then
    mkdir -p /tmp/tpm
    /usr/bin/swtpm socket \
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
QEMU_ARGS="$QEMU_ARGS -qmp unix:${QMP_SOCKET:-/run/qemu-qmp.sock},server,wait=off"

# --- Home disk (optional second virtio disk) ---
if [ -n "${QEMU_HOME:-}" ] && [ -e "${QEMU_HOME}" ]; then
    QEMU_ARGS="$QEMU_ARGS -drive file=${QEMU_HOME},format=raw,if=virtio,cache=writeback"
fi

NET_OPTS="user,id=net0,hostfwd=tcp:0.0.0.0:2222-:22"
if [ -n "${QEMU_NET_HOSTFWD:-}" ]; then
    NET_OPTS="$NET_OPTS,hostfwd=${QEMU_NET_HOSTFWD}"
fi
QEMU_ARGS="$QEMU_ARGS -netdev $NET_OPTS"
QEMU_ARGS="$QEMU_ARGS -device e1000,netdev=net0"

if [ "${QEMU_TPM:-1}" != "0" ]; then
    QEMU_ARGS="$QEMU_ARGS -chardev socket,id=chrtpm,path=/tmp/vtpm-sock"
    QEMU_ARGS="$QEMU_ARGS -tpmdev emulator,id=tpm0,chardev=chrtpm"
    QEMU_ARGS="$QEMU_ARGS -device tpm-tis,tpmdev=tpm0"
fi

if [ "${QEMU_KVM:-1}" = "1" ] && [ -e /dev/kvm ]; then
    QEMU_ARGS="$QEMU_ARGS -cpu host -accel kvm"
fi

# --- Launch QEMU in background ---
/usr/bin/qemu-system-x86_64 $QEMU_ARGS > "$QEMU_LOG" 2>&1 &

# --- Keep container alive; QEMU logs flow to docker logs ---
exec tail -f "$QEMU_LOG"
