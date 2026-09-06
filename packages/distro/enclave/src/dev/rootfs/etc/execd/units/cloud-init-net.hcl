// cloud-init-net — seed hostname + ssh keys from the cloud metadata service.
//
// One-shot setup script (port of the S06cloud-init-net logic): after dhcp
// has a lease, fetch hostname (IMDSv1 then instance-id) and user-data
// (IMDSv1, then IMDSv2 token). Keeps the raw user-data at /run/userdata
// for the home unit (home user name + keys).
//
// Always exits 0: a slow or absent metadata service must not break boot.
// On QEMU (no metadata) it just times out and exits.
unit "cloud-init-net" {
  command = "/usr/libexec/cloud-init-net.sh"

  depends {
    units = ["dhcp"]
  }

  health = { type = "oneshot" }
}
