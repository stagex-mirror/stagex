/* SPDX-License-Identifier: (LGPL-2.1 OR BSD-2-Clause) */
/* Minimal vendored bpf_endian.h — self-contained, no kernel header.
 *
 * The enclave guest is x86_64 (always little-endian), so ntohs/htons are
 * __builtin_bswap16. No <linux/types.h> include, no __BYTE_ORDER probe: the
 * program only ever builds for the x86_64 guest kernel, so the LE branch is
 * the only correct one and hardcoding it keeps the .o a pure function of the
 * package source. */
#ifndef __BPF_ENDIAN_MIN_H
#define __BPF_ENDIAN_MIN_H

#define bpf_htons(x) __builtin_bswap16(x)
#define bpf_ntohs(x) __builtin_bswap16(x)
#define bpf_htonl(x) __builtin_bswap32(x)
#define bpf_ntohl(x) __builtin_bswap32(x)

#endif
