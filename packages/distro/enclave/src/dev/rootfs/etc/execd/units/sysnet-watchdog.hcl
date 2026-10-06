// sysnet-watchdog — v13-supervisor (Oct 6 wire): the INDEPENDENT last-resort
// recovery for the sys-net face. The Oct 6 i-0e5a6d710e6bcc45e incident
// proved the whole recovery chain (data-plane dark -> respawn -> reboot -f)
// ran INSIDE the sysnet supervisor loop — and that loop had wedged ~14.5 h
// before the netstack went terminally dark, so the recovery had no live
// process left to run it. The watchdog owns the reboot in a SEPARATE
// process (no runsc/pgrep/bpf/serial on its path: nothing that can wedge
// with the supervisor). It reboots the guest when (a) the data plane has
// been dark >= 540 s (armed) or (b) the supervisor's heartbeat has been
// stale >= 600 s — the second trigger is the Oct 6 failure mode (healthy
// netstack, dead supervisor).
//
// The supervisor (sysnet unit) stays the primary recovery: its 120 s
// DP_LIMIT does the CHEAP sandbox respawn (no reboot) for process-level
// deaths and transients. The watchdog is the later-horizon last resort; the
// two are complementary, and a fresh dp pass clears the watchdog's
// reboot-loop guard.

unit "sysnet-watchdog" {
  script = "/usr/libexec/sysnet-watchdog.sh"

  depends {
    units = ["lo"]
  }

  restart = "always"
  health  = { type = "standard" }
}
