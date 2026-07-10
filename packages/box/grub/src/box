#!/usr/bin/sh
# grub-box.sh — assembles /rootfs into /disk.img with GRUB EFI boot
set -eux

# --- Inputs ---
ROOTFS_DIR="/rootfs"
KERNEL="${ROOTFS_DIR}/boot/vmlinuz"
INITRAMFS="${ROOTFS_DIR}/boot/initramfs"
GRUB_CFG="${ROOTFS_DIR}/boot/grub/grub.cfg"
HOSTNAME_FILE="${ROOTFS_DIR}/etc/hostname"

# --- Output ---
DISK="/disk.img"

# --- Prepare ISO layout ---
ISO="iso"
rm -rf "$ISO"
mkdir -p "$ISO/boot/grub" "$ISO/efi/boot"

# Copy kernel and initramfs
cp "$KERNEL" "$ISO/boot/vmlinuz"
cp "$INITRAMFS" "$ISO/boot/initramfs"

# Copy grub config
if [ -f "$GRUB_CFG" ]; then
    cp "$GRUB_CFG" "$ISO/boot/grub/grub.cfg"
else
    cat > "$ISO/boot/grub/grub.cfg" <<EOF
set timeout=2
menuentry "Linux Stagex" {
    echo "Loading kernel..."
    linux /boot/vmlinuz init=/init console=tty0 console=ttyS0,115200 console=ttyS1,115200 earlyprintk=serial,ttyS0,115200 ro loglevel=7 hostname=${HOSTNAME_FILE:-sxos}
    echo "Loading initramfs..."
    initrd /boot/initramfs
    echo "Booting..."
}
EOF
fi

# --- Build GRUB EFI image ---
cat > grub_early.cfg <<EOF
search --set=root --fs-uuid sxos
configfile /boot/grub/grub.cfg
EOF

grub-mkimage \
    --config="grub_early.cfg" \
    --prefix="/boot/grub" \
    --output="$ISO/efi/boot/bootx64.efi" \
    --format="x86_64-efi" \
    --compression="xz" \
    all_video \
    disk \
    part_gpt \
    part_msdos \
    linux \
    boot \
    echo \
    normal \
    configfile \
    search \
    search_label \
    efi_gop \
    fat \
    iso9660 \
    gzio \
    serial \
    terminal

# Create EFI fat image for GRUB
mformat -i "$ISO/boot/grub/efi.img" -C -f 1440 -N 0 ::
mcopy -i "$ISO/boot/grub/efi.img" -ms "$ISO/efi" ::

# --- Create user partition ---
dd if=/dev/zero bs=1M count=10 >> user.img
mformat -v user -i user.img -N 0 ::

# --- Build ISO (disk image) ---
xorrisofs \
    -output "$DISK" \
    -full-iso9660-filenames \
    -joliet \
    -rational-rock \
    -sysid LINUX \
    -volid "sxos" \
    -eltorito-boot boot/grub/efi.img \
    -no-emul-boot \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -follow-links \
    -append_partition 3 0xb user.img \
    "$ISO/"

# Cleanup
rm -rf "$ISO" user.img grub_early.cfg

echo "disk.img created: $(du -h "$DISK" | cut -f1)"
