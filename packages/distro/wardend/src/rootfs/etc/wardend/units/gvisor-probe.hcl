# gvisor-probe: DEV-ONLY escape hatch. A container-moat co-tenant (root, host
# `/`, busybox) that runs the stock-runsc forensic probe and forces output to
# /dev/console. Its job: answer Q1 — does STOCK runsc boot ANY sandbox in this
# guest, independent of wardend's gvisor moat? The wedged units (seald/scribe/
# posternd) do not gate this; the container moat is proven working (dhcp uses
# it). Remove once the gvisor wedge is root-caused.
name    = "gvisor-probe"
command = ["/usr/libexec/gvisor-probe.sh"]
rootfs  = { type = "dir", path = "/" }
oneshot = true
restart = "no"
