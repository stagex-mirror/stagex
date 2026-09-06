// dhcp — IPv4 DHCP client (rust-dhcp), the only network daemon.
//
// Direct binary call: dhcp-client <iface> runs IPv4 DORA, does T1/T2
// renewal in-process, and applies the lease (address, default route, DNS)
// via rtnetlink. It brings the interface up itself. Being IPv4-only by
// design it never touches the kernel DHCPv6/IPv6 parse path that raised
// the spurious #GP on dhcpcd (the 60-min-offline bug) — no workaround
// needed.
//
// restart="always" replaces the old S04rust-dhcp-watchdog: a dead client
// is respawned after 1 s. `net.ifnames=0` pins the name to eth0.
unit "dhcp" {
  command = "/usr/bin/dhcp-client"
  args    = ["eth0"]

  depends {
    units = ["lo"]
  }

  restart = "always"
  health  = { type = "standard" }
}
