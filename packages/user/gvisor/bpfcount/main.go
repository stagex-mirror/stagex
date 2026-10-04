// Command bpfcount reads the v4 redirect diagnostic counter map and prints
// the two monotonic frame counters on stdout, space-separated:
//
//	<pass> <redirect>
//
// It loads the map that xdp_loader pinned at /sys/fs/bpf/<iface>/
// redirect_counts (argv[1], else /sys/fs/bpf/eth0/redirect_counts).
//
// pass     = frames XDP_PASSed to the kernel (the sn-6e empty-sockmap guard
//            fired: bpf_map_lookup_elem(&sock_map) returned NULL).
// redirect = frames bpf_redirect_map'd to the sentry's AF_XDP ring.
//
// Both are monotonic since the program was loaded into the kernel. The
// sys-net supervisor samples this every probe cycle and logs the DELTAS —
// the Oct 4 flap discriminator. During a host-visible dark window:
//   pass climbing, redirect flat      -> inbound frames guard-PASSED to the
//                                       offline kernel; the sockmap lost its
//                                       socket entry (gvisor sentry socket
//                                       lifecycle). This is the bug.
//   redirect climbing, pass flat      -> inbound frames ARE reaching the
//                                       sentry ring; the drop is ring /
//                                       netstack-side, not the guard.
//
// The reader is intentionally dependency-light (cilium/ebpf only, no libc:
// CGO_ENABLED=0) so it builds static and lands in the kernel-side rootfs
// where the supervisor runs it. It is NOT on the sandbox boot path.
package main

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"os"

	"github.com/cilium/ebpf"
)

func main() {
	path := "/sys/fs/bpf/eth0/redirect_counts"
	if len(os.Args) > 1 {
		path = os.Args[1]
	}

	m, err := ebpf.LoadPinnedMap(path, nil)
	if err != nil {
		// The v3 object (no counter map) leaves no pin here; the supervisor
		// tolerates a non-zero exit and simply logs no counters.
		fmt.Fprintf(os.Stderr, "bpfcount: %v\n", err)
		os.Exit(1)
	}
	defer m.Close()

	// The map value is {uint32 pass, uint32 redirect}; read it as raw
	// bytes to avoid any struct-marshaling ambiguity.
	b, err := m.LookupBytes(uint32(0))
	if err != nil {
		fmt.Fprintf(os.Stderr, "bpfcount: lookup: %v\n", err)
		os.Exit(1)
	}
	if len(b) < 8 {
		fmt.Fprintf(os.Stderr, "bpfcount: short value (%d bytes): % x\n", len(b), bytes.TrimLeft(b, "\x00"))
		os.Exit(1)
	}
	pass := binary.LittleEndian.Uint32(b[0:4])
	redirect := binary.LittleEndian.Uint32(b[4:8])
	fmt.Printf("%d %d\n", pass, redirect)
}
