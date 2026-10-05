# xdp-delta — stock redirect_host_ebpf.o vs the custom program

Record of the semantic deltas (v1 bidirectional :22, v2 sn-6e guard, v3
redirect-all) plus the byte-order bug fixes between the go-branch's prebuilt
program and this tree's `redirect_host_ebpf.o`.

## Artifacts

| object | sha256 |
|---|---|
| stock (go-branch prebuilt, `fetch/gvisor-…/tools/xdp/cmd/bpf/`) | `c41a89a00cb92e4c352ef05a3209952e79e04e0b55a9390e1a1820acbfd2b67d` |
| custom v1 (bidirectional :22) | `5ed1c528bba01bfbcb928fe40d5b993e0bac45f3a1f5ee24f402275496d700ca` |
| custom v2 (v1 + sn-6e empty-sockmap guard) | `566784adcfe73d57e1ae389a865acdd3eb3b7317f25193cebecafe27814eae17` |
| custom v3 (sn-7 redirect-all, no inspection) | `80ac96fbedc2976600085fa6b312f1855b739a5986302d2052cdc81f3da38860` |
| custom v4 (v3 + diagnostic counter map) | `ad656313c76f3c38444752fa8328676e794e28335aeb161324dbe7d3bc179fc2` |
| custom v5 (v4 + per-queue counter attribution, SHIPPED) | `b7eddf2be8d8250165f509ec1a094b71085508952da51455392aac490dac91d0` |

All objects: same map (`XSKMAP`, key 4 / value 4, max 1 entry), same symbols
(`xdp_prog`, `sock_map`), same inlined `bpf_redirect_map` call (helper id
0x33, redirect flags 2 = XDP_ABORTED-class into the map), same map type
SOCKMAP. The loader (`runsc` `//go:embed bpf/redirect_host_ebpf.o`) needs no
changes.

## Semantic delta: the :22 pass rule is bidirectional

Stock passes to the kernel ONLY `dstport == 22`. The kernel's own SSH TX
(SYN-ACK, banner — `srcport == 22`) is therefore redirected into the sandbox:
new SSH connections die at banner exchange (the sn-6 RST). This program adds
the `srcport == 22` leg, so the kernel keeps BOTH directions of its management
channel; everything else redirects to the sandbox exactly as stock does.

Disassembly (llvm-objdump -d), aligned at shared semantic points:

```
 insn   stock                                  custom
 -----  -------------------------------------  ------------------------------------
   4    r4 = *(u8*)(r2+0xc); r5 = *(u8*)(r2+0xd)   r4 = *(u16*)(r2+0xc)   ; ethertype
   -    r5 <<= 8; r5 |= r4                              (single LE u16 read)
  10    if r5 != 0x8  -> REDIRECT            if w4 != 0x8 -> REDIRECT  ; IPv4 gate
  14    r4 = *(u8*)(r2+0x17)                       r5 = *(u8*)(r2+0x17)  ; IP proto
  15    if r4 != 0x6  -> REDIRECT            if w5 != 0x6 -> REDIRECT  ; TCP gate
  19    r2 = *(u16*)(r2+0x24)                      r3 = *(u16*)(r4+0x0)   ; srcport (NEW read)
                                             17    if w3 == 0x1600 -> PASS      ; srcport==22 (NEW)
  19    if r2 == 0x1600 -> PASS                 r2 = *(u16*)(r2+0x24)
  20    (fall through -> REDIRECT)             19    if w2 == 0x1600 -> PASS    ; dstport==22
  21    REDIRECT: r2 = *(u32*)(r1+0x10);       20    REDIRECT: r2 = *(u32*)(r1+0x10)
  22        r1 = 0; r3 = 2; call 0x33                r1 = 0; w3 = 2; call 0x33
  26    exit                                  26    exit
```

The only new instruction is `if w3 == 0x1600 -> PASS` (the srcport leg). Every
other branch, offset, constant, and the redirect call are byte-equivalent in
semantics to stock.

## The byte-order bug class (root cause of the sn-6 banner RST)

x86 BPF reads `*(u16*)(ptr)` as a LITTLE-endian C u16. A `__be16` field whose
wire bytes are `hi lo` therefore reads as the value `lo hi` — i.e. the
byte-swapped (host-order) value. The correct comparison constant is
`bpf_htons(host_value)`:

| field    | wire bytes | LE u16 read | wrong compare (original) | correct compare | stock |
|----------|------------|-------------|--------------------------|-----------------|-------|
| ethertype| `08 00`    | **0x0008**  | `!= 0x0800` (redirected every IPv4 pkt) | `!= bpf_htons(0x0800)` = `!= 0x8` | `!= 0x8` |
| dstport  | `00 16`    | **0x1600**  | `== 0x0016` (never matched) | `== bpf_htons(22)` = `== 0x1600` | `== 0x1600` |

The ethertype bug was gating: with `!= 0x0800` every IPv4 packet (including
:22) redirected to the sandbox before the port test, so the port-only fix
still RST'd. Fixing both legs restores stock's exact wire semantics plus the
intended srcport delta.

## The sn-6e guard: empty-sockmap PASS (v2)

v1 had a wedge: when the sandbox sentry dies, the kernel auto-removes the
`sock_map` entry on socket close (`xsk_map_try_sock_delete`), and a
`bpf_redirect_map` into the now-EMPTY map fails (`__xsk_map_lookup_elem` →
NULL) and **DROPS the packet** — the redirect class goes dark for the
supervisor's teardown window (3 failed polls × 5 s). v2 closes the guard
inside the program itself (the data-plane authority):

```c
static int redirect(struct xdp_md *ctx)
{
  unsigned int key = ctx->rx_queue_index;
  if (bpf_map_lookup_elem(&sock_map, &key) == NULL)
    return XDP_ACT_PASS;              /* no socket: kernel keeps full egress */
  return bpf_redirect_map(&sock_map, key, XDP_XSKB);
}
```

Why in the program, not a userspace route-flip: the NULL lookup IS the
authoritative "no socket to redirect to" signal (the guest verifier allows
exactly `{redirect_map, map_lookup_elem}` on XSKMAP), so the reaction is
atomic — egress returns the instant the socket closes, and it re-arms the
instant a respawned sandbox re-inserts its socket. No route/ARP changes, no
userspace coordination, no race window. It also covers the pre-start window
(program attached, socket not yet inserted) where v1 blackholed.

Disassembly delta v1 → v2, per redirect site (5 inlined `redirect()` call
sites, all identical):

```
  v1                                   v2
  r2 = *(u32*)(r1+0x10)                r1 = *(u32*)(r1+0x10)
  r1 = 0; w3 = 2                        *(u32*)(r10-4) = r1         ; key on stack
  call 0x33                             r2 = r10-4; r1 = 0
  exit                                  call 0x1                    ; lookup
                                         r1 = r0; w0 = 2
                                         if r1 == 0 -> exit         ; empty -> PASS
                                         r2 = *(u32*)(r10-4)
                                         r1 = 0; w3 = 2
                                         call 0x33                  ; else redirect
                                         exit
```

The `call 0x1` (map_lookup_elem) → null-test → PASS leg is the ONLY addition;
the ethertype/IP/proto/port gates and the `call 0x33` redirect are unchanged
from v1 (and from stock, plus the srcport leg). 3× byte-deterministic:
`566784adcfe73d57e1ae389a865acdd3eb3b7317f25193cebecafe27814eae17`.

## XDP attach mode (NIC-dependent, load-bearing)

v2-era note (moot for v3 — see below: with no pass class left, the mode no
longer changes what the program does, only where the kernel's own TX is
hooked):

- virtio-net-pci -> **driver** mode (`ndo_bpf`): only RX is hooked; kernel TX
  is never diverted. The dstport leg alone suffices for RX, but the srcport
  leg is kept so the program is correct in BOTH modes.
- e1000 -> **generic** mode (`do_xdp_generic`): RX *and* TX are hooked; the
  srcport leg is then REQUIRED (the kernel's :22 SYN-ACK would otherwise be
  redirected).

Reproduce: `clang -O2 -target bpf -c bpf/redirect.c` (any clang emits these
bytes; the program uses no external header). For a byte-pinned build use the
pallet toolchain (the build image has no BPF-capable clang):

```
docker run --rm --entrypoint /bin/busybox -v <bpfdir>:/w \
  stagex/pallet-clang-gnu-busybox:localbuild \
  sh -c 'cd /w && /usr/bin/clang -O2 -target bpf -c redirect.c -o redirect_host_ebpf.o'
```

The source dir must contain ONLY `redirect.c` + `bpf_helpers.h` +
`bpf_endian.h`, and the source file MUST be named `redirect.c` (the ELF
FILE symbol embeds the source path). 3x-verified deterministic per version.

## sn-7 v3: redirect-all (kernel fully offline)

v3 is the maximally simple program: **no ethertype gate, no IP header parse,
no port tests**. The netstack is the ONLY stack on the wire and it owns ARP
too — the sentry resolves the GW MAC (ARP requests go out the AF_XDP socket,
the GW's ARP replies must land in the sandbox, not the kernel) and answers
ARP for its own lease IP. The kernel has no lease, no address, nothing to do.

The whole body is:

```c
if (bpf_map_lookup_elem(&sock_map, &key) == NULL)  return XDP_ACT_PASS;  // sn-6e guard
return bpf_redirect_map(&sock_map, key, XDP_XSKB);                        // ALL frames
```

| class | v2 | v3 |
|---|---|---|
| malformed (<14 B) | XDP_PASS (kernel drops) | **redirect (sandbox)** — no inspection; the sentry's parser drops malformed |
| ARP (GW replies, requests) | redirect (sandbox) | redirect (sandbox) — now the netstack's ARP authority |
| every IP frame, any class | redirect except :22 (PASS) | **redirect (sandbox)** — the :22 pass class is gone |
| sandbox socket absent (guard) | XDP_PASS (recovery) | XDP_PASS (recovery) — unchanged, now covers ALL traffic |

The sn-6e guard is byte-for-byte the same code (same key convention,
`key = ctx->rx_queue_index`) and now covers everything: sandbox dead ->
kernel auto-removes the sockmap entry -> NULL lookup -> XDP_PASS hands the
full wire back to the kernel (recovery path) until the supervisor respawns
the sandbox and the re-inserted socket re-arms the redirect. It still covers
the pre-start window. No frame bytes are ever dereferenced, so no bounds
check is needed.

### insn-level delta v2 -> v3

v2 is 80 insns (0x280 B, 5 inlined `redirect()` sites); v3 is 16 insns
(0x80 B, 1 site). The 16-byte `ll` map-pointer insns occupy two slot numbers
in the v3 column (slots 5-6 and 12-13).

```
 insn   v2                                          v3
 -----  ------------------------------------------  ------------------------------------
   0    w0 = 0x2  (PASS preload, DCE'd in v3)       0   r1 = *(u32*)(r1+0x10)  ; rx_queue_index
   1    r3 = *(u32*)(r1+0x4)                        1   *(u32*)(r10-0x4) = r1   ; key on stack
   2    r2 = *(u32*)(r1+0x0)                        2   r2 = r10
   3    r4 = r2                                     3   r2 += -0x4
   4    r4 += 0xe                                   4   r1 = 0x0 ll            ; map ptr (16 B)
   5    if r4 > r3 -> PASS (malformed)               6   call 0x1                 ; lookup
   6    r4 = *(u16*)(r2+0xc) ; ethertype            7   r1 = r0
   7    if w4 == 0x8 -> IPv4 gate                   8   w0 = 0x2
   8    REDIRECT site A (non-IPv4): ...             9   if r1 == 0 -> +5         ; empty -> PASS (guard)
   19   r4 = r2; r4 += 0x22                        10   r2 = *(u32*)(r10-0x4)
   21   if r4 <= r3 -> keep                        11   r1 = 0x0 ll            ; map ptr (16 B)
   22   REDIRECT site B (IP bounds): ...           13   w3 = 0x2
   33   r5 = *(u8*)(r2+0x17) ; IP proto            14   call 0x33                 ; redirect
   34   if w5 == 0x6 -> TCP gate                   15   exit
   35   REDIRECT site C (non-TCP): ...
   46   r5 = r2; r5 += 0x36
   48   if r5 <= r3 -> keep
   49   REDIRECT site D (TCP bounds): ...
   60   r3 = *(u16*)(r4+0x0) ; srcport
   61   if w3 == 0x1600 -> PASS  (GONE)
   62   r2 = *(u16*)(r2+0x24) ; dstport
   63   if w2 == 0x1600 -> PASS  (GONE)
   64   REDIRECT site E (fallthrough): ...
   79   exit
```

Removed (everything in between): the data/data_end reads + eth bounds check,
the ethertype read + IPv4 gate (insns 1-7), the IP-proto read + TCP gate
(33-34), the IP/TCP header-bounds checks (19-21, 46-48), the srcport read +
`if w3 == 0x1600 -> PASS` (60-61), the dstport read +
`if w2 == 0x1600 -> PASS` (62-63), 4 of the 5 inlined `redirect()` sites,
and the `w0 = 0x2` PASS preload (nothing PASSes except the guard anymore).
Added: nothing. The surviving guard (`call 0x1` -> null-test -> `w0 = 0x2`
exit) and redirect (`r1 = 0; w3 = 2; call 0x33`) are byte-identical to v2's
redirect site E — verified at the byte level: `v3[0x00..0x80] == v2[0x200..0x280]`
with zero differing bytes (the guard's branch is a relative `+5` in both, so
even the immediate matches; only the absolute target address differs).

### Verifier surface (unchanged vs v2/stock)

- Helpers: exactly `map_lookup_elem` (`call 0x1`) and `redirect_map`
  (`call 0x33`) — the guest kernel's allowed set on XSKMAP; no `callx`, no
  new relocations (`.relxdp`: 6 `R_BPF_64_64 sock_map` -> 2, one per
  helper call site).
- Map section: byte-identical 20-byte `bpf_map_def` (type 0x11/XSKMAP,
  key 4, value 4, max 1) in section `maps`; symbols `xdp_prog`, `sock_map`,
  `__license` unchanged — the runsc `//go:embed` loader needs no changes.
- Register usage: r1 (ctx) -> r0 (return), r10 frame for the key, nothing
  else; the null-tested lookup result is never dereferenced (verifier-safe
  as in v2). No memory accesses at all beyond the ctx read.

3x byte-deterministic (pallet clang 22.1.8, clean source dir):
`80ac96fbedc2976600085fa6b312f1855b739a5986302d2052cdc81f3da38860`.

## v4 — diagnostic counter map (the Oct 4 flap discriminator)

v4 = v3 + a second map. The data path is UNCHANGED (the guard + the
redirect, same branches, same call order); the only additions are two
counters and the map that holds them:

```c
struct bpf_counts_val { unsigned int pass; unsigned int redirect; };

struct bpf_map_def SEC("maps") bpf_counts = {
  .type = 2,                /* BPF_MAP_TYPE_ARRAY */
  .key_size = 4, .value_size = 8, .max_entries = 1,
};
```

On the two exit paths, before returning, the program does
`bpf_map_lookup_elem(&bpf_counts, &0)` and increments `pass` (the guard
fired: `sock_map` lookup returned NULL) or `redirect`
(`bpf_redirect_map` called). Both are monotonic since program load.

Why in-program (not a kprobe/tracepoint): the counter must observe the
EXACT decision point (guard-null vs redirect) with zero sampling error,
and a per-frame `map_lookup_elem` on an ARRAY is a verifier-cheap direct
access. A 32-bit increment is a plain read-modify-write in XDP context;
concurrent-queue increments can lose counts under contention, but a LOSE
cannot flip the direction (which counter moves), which is all the
discriminator needs.

Verifier surface: adds `map_lookup_elem` on a second map (the guest
kernel already allows `map_lookup_elem` on XSKMAP, and ARRAY lookups are
universally allowed). No new helpers, no memory writes to frame bytes,
the counter-pointer result is only field-written (verifier-tracked,
fixed-size value).

Loader change (xdp-5): `xdp_loader` loads the object as a full
`ebpf.NewCollection` (was `LoadAndAssign`) and pins `bpf_counts` at
`/sys/fs/bpf/<iface>/redirect_counts` (best-effort: a v3 object without
the map still loads + pins its sockmap/program/link). The pin dies with
the program (teardown unpin + the program's own unload).

Reader (bpfcount): a small static Go binary in the kernel-side rootfs
(cilium/ebpf `LoadPinnedMap` + `LookupBytes(0)`, prints `pass
redirect`). The sys-net supervisor samples it every liveness iteration
(~5 s) and logs the DELTAS to the tmpfs log (`:9004` + the serial
forwarder).

The discriminator (the Oct 4 flap): during a host-visible dark window,
`pass` climbing with `redirect` flat => inbound frames are
guard-PASSED to the offline kernel => the sockmap LOST its socket entry
(gvisor sentry AF_XDP socket lifecycle — the bug, with the in-kernel
proof). `redirect` climbing with `pass` flat => inbound frames ARE
reaching the sentry ring and the drop is ring/netstack-side.

3x byte-deterministic (pallet clang 22.1.8, source dir with
`redirect.c` + `bpf_helpers.h` + `bpf_endian.h`):
`ad656313c76f3c38444752fa8328676e794e28335aeb161324dbe7d3bc179fc2`.

## v5 — per-queue counter attribution (the multi-queue RSS discriminator)

v5 = v4 with the counter map widened from a single pair to a per-RX-queue
ARRAY[16], indexed by `ctx->rx_queue_index`. The data path is STILL
unchanged (same guard, same redirect, same call order, same `call 0x33`
inlined); the only delta vs v4 is that the counter slot is now the frame's
own queue instead of a constant 0, plus a bounds check on the key.

```c
struct bpf_counts_val { unsigned int pass; unsigned int redirect; };

struct bpf_map_def SEC("maps") bpf_counts = {
  .type = 2,                /* BPF_MAP_TYPE_ARRAY */
  .key_size = 4, .value_size = 8, .max_entries = 16,  /* v4 was 1 */
};

/* v5: count a frame for its own RX queue (slot = ctx->rx_queue_index). */
static void count(unsigned int q, int is_pass) {
  if (q < 16) {                          /* bounds the ARRAY key for the verifier */
    unsigned int ckey = q;
    struct bpf_counts_val *cv =
        (struct bpf_counts_val *)bpf_map_lookup_elem(&bpf_counts, &ckey);
    if (cv) { if (is_pass) cv->pass += 1; else cv->redirect += 1; }
  }
}
```

On the guard path `count(key, 1)`, on the redirect path `count(key, 0)` —
`key = ctx->rx_queue_index` (the same value already used for the
`sock_map` lookup and the `bpf_redirect_map` call). A frame on queue N >= 16
is still redirected/passed correctly; it is simply not counted (the guard
only bounds the counter lookup, not the data path).

Why per-queue (the decisive upgrade over v4): the v10 data (v4's single
pair) killed the naive sockmap-lifecycle hypothesis — `redirect` kept
climbing at ~85% of the up-rate *during* darks, so the socket had not left
the map and inbound frames WERE reaching the sentry ring. But the observed
`pass` share was only 6.7-11%, far below the ~50% a clean 2-queue 50/50
RSS split would predict if every queue-1 frame guard-PASSED. The missing
variable is WHICH queue each frame lands on, and only a per-queue counter
measures it.

The program is the per-queue RX counter because ENA runs it per queue:
`ena_netdev.c` `ena_xdp_handle_buff` (:1178) is called per `rx_ring->qid` in
the per-queue NAPI poll, and `ena_xdp.c` registers each ring's
`xdp_rxq_info` with its own queue index (`xdp_rxq_info_reg(..., rx_ring->qid,
...)`, :200), so `ctx->rx_queue_index` in the program is the exact queue. No
sysfs needed (`CONFIG_NET_SYSFS` is off in the enclave kernel; there is no
`/sys/class/net/eth0/queues/` tree). This is measured at the decision point
with zero sampling error, unlike an `rpackets` sampler that would also miss
the guard-vs-redirect split.

Prediction (the multi-queue RSS hypothesis — gvisor binds ONE AF_XDP socket
at key 0, `runsc/sandbox/xdp.go:178`, on a 2-queue ENA):
  slot 0: `redirect` climbing, `pass` ~0   (queue 0 has the socket)
  slot 1: `pass` climbing,   `redirect` ~0 (queue 1 has no socket; the sn-6e
                                                guard XDP_PASSes it to the
                                                offline kernel -> dropped)
  and the per-window slot-1 `pass` rate tracks the dark windows.
If instead slot 0 alone shows BOTH `pass` and `redirect` climbing (slot 1
~0), the program is running on a single queue and the `pass` frames are the
sockmap-lifecycle variant (a socket that left the map while frames kept
arriving). Either way the per-queue split is the discriminator v4 could not
give.

Verifier surface: identical to v4 (same `map_lookup_elem` on the counter
map, same `call 0x33` redirect) plus a `if w2 > 0xf` bounds check on the key
before the counter lookup — a plain 32-bit compare, no new helpers, no frame
byte access. The insn delta vs v4 is exactly: `rx_queue_index` loaded once
into `w2` and reused for the guard lookup, the counter key, and the
redirect; both counter branches gain the `> 0xf` guard; `call 0x1` (guard
lookup) and `call 0x33` (redirect) are byte-identical to stock.

Reader (bpfcount): unchanged ABI surface (still
`LoadPinnedMap` + per-key `LookupBytes`), now reads all 16 slots and prints
32 fields: `p0 r0 p1 r1 ... p15 r15`. The sys-net supervisor `count_sample`
validates the 32-field arity (a v4 object's 2-field output or a missing pin
logs one "absent" line, BPSEEN cap), then logs the per-slot DELTAS as two
16-slot comma-lists:
  `[bp] dp=<pass deltas q0..q15> dr=<redirect deltas q0..q15>`
(the pairwise delta is computed in POSIX sh — the guest `/bin/sh` is brush,
no arrays — by `set -- $bp_prev` + a `shift` per slot).

3x byte-deterministic (pallet clang 22.1.8, source dir with
`redirect.c` + `bpf_helpers.h` + `bpf_endian.h`):
`b7eddf2be8d8250165f509ec1a094b71085508952da51455392aac490dac91d0`.
