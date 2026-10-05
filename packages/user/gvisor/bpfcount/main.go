// Command bpfcount reads the v5 redirect diagnostic counter map and prints
// the per-queue frame counters on stdout, space-separated:
//
//	<p0> <r0> <p1> <r1> ... <p15> <r15>
//
// 32 numbers: for each RX queue slot 0..15, the pass counter then the
// redirect counter. It loads the map that xdp_loader pinned at
// /sys/fs/bpf/<iface>/redirect_counts (argv[1], else
// /sys/fs/bpf/eth0/redirect_counts).
//
// The v5 map is an ARRAY[16] of {u32 pass, u32 redirect} indexed by
// ctx->rx_queue_index — the multi-queue RSS discriminator. ENA invokes the
// program per RX queue, so each slot is that queue's own frame counter
// measured at the exact decision point:
//
//   q0: redirect climbing, pass ~0   -> queue 0 has the sentry socket
//   q1: pass climbing,   redirect ~0 -> queue 1 has no socket; the sn-6e
//                                       guard XDP_PASSes every queue-1 frame
//                                       to the offline kernel (DROPPED)
//
// Both per-slot counters are monotonic since the program was loaded into the
// kernel. The sys-net supervisor samples this every liveness iteration and
// logs the per-slot DELTAS.
//
// The reader is intentionally dependency-light (cilium/ebpf only, no libc:
// CGO_ENABLED=0) so it builds static and lands in the kernel-side rootfs
// where the supervisor runs it. It is NOT on the sandbox boot path.
package main

import (
	"encoding/binary"
	"fmt"
	"os"

	"github.com/cilium/ebpf"
)

// slots must match the v5 program's bpf_counts ARRAY bound (COUNT_SLOTS).
const slots = 16

func main() {
	path := "/sys/fs/bpf/eth0/redirect_counts"
	if len(os.Args) > 1 {
		path = os.Args[1]
	}

	m, err := ebpf.LoadPinnedMap(path, nil)
	if err != nil {
		// An older object (no counter map) leaves no pin here; the
		// supervisor tolerates a non-zero exit and logs no counters.
		fmt.Fprintf(os.Stderr, "bpfcount: %v\n", err)
		os.Exit(1)
	}
	defer m.Close()

	var out [slots * 2]int
	for q := 0; q < slots; q++ {
		b, err := m.LookupBytes(uint32(q))
		if err != nil {
			fmt.Fprintf(os.Stderr, "bpfcount: slot %d: %v\n", q, err)
			os.Exit(1)
		}
		if len(b) < 8 {
			fmt.Fprintf(os.Stderr, "bpfcount: short slot %d (%d bytes)\n", q, len(b))
			os.Exit(1)
		}
		out[q*2] = int(binary.LittleEndian.Uint32(b[0:4]))     // pass
		out[q*2+1] = int(binary.LittleEndian.Uint32(b[4:8]))   // redirect
	}
	for i, n := range out {
		if i > 0 {
			fmt.Print(" ")
		}
		fmt.Print(n)
	}
	fmt.Println()
}
