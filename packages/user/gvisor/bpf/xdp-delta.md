# xdp-delta — stock redirect_host_ebpf.o vs the custom bidirectional program

Record of the one semantic delta (plus two byte-order bug fixes) between the
go-branch's prebuilt program and this tree's `redirect_host_ebpf.o`.

## Artifacts

| object | sha256 |
|---|---|
| stock (go-branch prebuilt, `fetch/gvisor-…/tools/xdp/cmd/bpf/`) | `c41a89a00cb92e4c352ef05a3209952e79e04e0b55a9390e1a1820acbfd2b67d` |
| custom (this tree, `bpf/redirect_host_ebpf.o`) | `5ed1c528bba01bfbcb928fe40d5b993e0bac45f3a1f5ee24f402275496d700ca` |

Both objects: same map (`XSKMAP`, key 4 / value 4, max 1 entry), same symbols
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

## XDP attach mode (NIC-dependent, load-bearing)

- virtio-net-pci -> **driver** mode (`ndo_bpf`): only RX is hooked; kernel TX
  is never diverted. The dstport leg alone suffices for RX, but the srcport
  leg is kept so the program is correct in BOTH modes.
- e1000 -> **generic** mode (`do_xdp_generic`): RX *and* TX are hooked; the
  srcport leg is then REQUIRED (the kernel's :22 SYN-ACK would otherwise be
  redirected).

Reproduce: `clang -O2 -target bpf -c bpf/redirect.c` (any clang emits these
bytes; the program uses no external header) — 3x verified deterministic.
