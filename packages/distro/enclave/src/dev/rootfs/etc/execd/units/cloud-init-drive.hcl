// cloud-init-drive — seed hostname + ssh keys from a config drive.
//
// One-shot setup script (port of the S05cloud-init-drive logic,
// QEMU-verified): ISO9660 config drive on a CD-ROM (OpenStack standard),
// with a raw-text fallback on a second virtio-blk. No device present ->
// "no device" and exit 0 (cloud-init-net takes over over the wire).
//
// No depends: it reads /dev/sr0 (devtmpfs) and mounts into /tmp, both
// present before execd starts, so it is a wave-1 unit.
unit "cloud-init-drive" {
  command = "/usr/libexec/cloud-init-drive.sh"

  health = { type = "oneshot" }
}
