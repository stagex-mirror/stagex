/* SPDX-License-Identifier: (LGPL-2.1 OR BSD-2-Clause) */
/* Vendored BPF ABI, fully self-contained — NO kernel header included.
 *
 * WHY VENDOR (the reason this program builds identically on any toolchain):
 *   1. The map-type enum is position-dependent and the build image's
 *      linux/bpf.h is a DIFFERENT revision from the guest kernel's. The .o is
 *      loaded by the GUEST kernel (stagex enclave kernel 7.2), so the map type
 *      byte baked into it must equal the guest's value. The stock go-branch
 *      .o bakes 0x11 (17), which is BPF_MAP_TYPE_XSKMAP in the guest kernel —
 *      the map type bpf_redirect_map() uses to deliver a packet to a bound
 *      AF_XDP socket. We pin 17 directly.
 *   2. The redirect helper must inlined to `call 0x33` (BPF_FUNC_redirect_map
 *      = 51), the stock .o's call target. A function-pointer constant folds
 *      the call; an asm()-named static function instead emits a broken `callx`
 *      relocation the verifier rejects.
 *   3. The multi-byte wire fields (ethertype, TCP ports) are __be16 on the wire;
 *      clang reads *(u16*)(ptr) as a LITTLE-endian C u16, so compare against
 *      bpf_htons(host value): port 22 -> 0x1600, IPv4 ethertype -> 0x0008.
 *      (Comparing the raw network-order values 0x0016/0x0800 is the bug that
 *      made the program redirect :22 -- and, at the ethertype, every IPv4
 *      packet -- into the sandbox.)
 *
 * Values verified against packages/user/linux/linux-7.2/include/uapi/.
 */
#ifndef __BPF_XDP_REDIRECT_MIN_H
#define __BPF_XDP_REDIRECT_MIN_H

#define SEC(name) __attribute__((section(name), used))

/* Legacy bpf_map_def: 5 x u32, 20 bytes, BTF-free. The go-branch's prebuilt
 * .o and cilium/ebpf's no-BTF path both read the map as this raw struct, so a
 * drop-in must use it (the BTF __uint style is 32 bytes and would not match). */
struct bpf_map_def {
  unsigned int type;
  unsigned int key_size;
  unsigned int value_size;
  unsigned int max_entries;
  unsigned int flags;
};

/* --- ABI constants, pinned to the guest kernel 7.2 UAPI --- */

/* enum bpf_map_type: XSKMAP = 17 (0x11) in the guest kernel — the stock byte. */
#define XDP_XSKMAP_TYPE 17u

/* enum xdp_action: XDP_PASS = 2. (XDP_REDIRECT = 4 is a RETURN value, not a
 * flags argument.) */
#define XDP_ACT_PASS 2u

/* bpf_redirect_map(map, index, flags): the only flag that delivers a packet
 * to a bound AF_XDP socket is XDP_XSKB = 2 — the stock .o passes 2 (w3=0x2). */
#define XDP_XSKB 2u

/* BPF_FUNC_redirect_map = 51 (0x33). Declared as a function-pointer constant
 * so clang folds `bpf_redirect_map(...)` into an inlined `call 0x33`. */
static int (*bpf_redirect_map)(void *map, unsigned int index,
                               unsigned int flags) = (void *)51;

/* struct xdp_md (guest 7.2): data@0, data_end@4, data_meta@8,
 * ingress_ifindex@12, rx_queue_index@16, egress_ifindex@20. */
struct xdp_md {
  unsigned int data;
  unsigned int data_end;
  unsigned int data_meta;
  unsigned int ingress_ifindex;
  unsigned int rx_queue_index;
  unsigned int egress_ifindex;
};

/* --- standard wire-format headers (raw network byte order) --- */

#define ETH_P_IP 0x0800u /* IPv4 ethertype, network order */
#define IP_PROTO_TCP 6u  /* IPPROTO_TCP */

struct ethhdr {
  unsigned char h_dest[6];
  unsigned char h_source[6];
  unsigned short h_proto; /* ethertype, network order */
};

struct iphdr {
  unsigned char ihl : 4, version : 4;
  unsigned char tos;
  unsigned short tot_len;
  unsigned short id;
  unsigned short frag_off;
  unsigned char ttl;
  unsigned char protocol; /* 6 = TCP */
  unsigned short check;
  unsigned int saddr;
  unsigned int daddr;
};

struct tcphdr {
  unsigned short source; /* __be16 on the wire; port 22 == bpf_htons(22) */
  unsigned short dest;
  unsigned int seq;
  unsigned int ack_seq;
  unsigned char doff : 4, fin : 1, syn : 1, rst : 1, psh : 1, ack : 1,
              urg : 1, ece : 1, cwr : 1;
  unsigned short window;
  unsigned short check;
  unsigned short urg_ptr;
};

#endif
