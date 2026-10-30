#!/usr/bin/env python3
# The capstone DNS server (the slirp upstream for the QEMU guest's DNS poll).
#
# The guest's DNS poller queries the slirp forwarder (10.0.2.3), which
# forwards to the CONTAINER's resolver (this server, via /etc/resolv.conf).
# This server answers the capstone A record (udunit.lrvick.dev ->
# 10.0.2.15, the guest's lease IP) so the poll sees PointsToSelf; every
# other query is forwarded to 1.1.1.1 (the real resolver) and the response
# is relayed back. The A record is the external DNS dependency the capstone
# flow needs (the DNS poll -> ACME sign via seald -> cert -> :443 vhost).
import socket
import struct
import sys

TARGET = "10.0.2.15"          # the guest's lease IP (PointsToSelf)
FORWARD = ("1.1.1.1", 53)     # the real resolver (everything else)
BIND = ("0.0.0.0", 53)         # the slirp nameserver (slirp always queries port 53; the server runs as root)


def name_to_bytes(name: bytes) -> bytes:
    # The query name (the label chain) as it appears in the wire (the
    # question section). We match on the decoded form, so this is just a
    # helper to skip past the question to find the answer insertion point.
    return name


def decode_name(data: bytes, off: int):
    # Decode a DNS name (with pointer-following) starting at `off`.
    labels = []
    seen = off
    while off < len(data):
        ln = data[off]
        if ln == 0:
            off += 1
            break
        if ln & 0xC0 == 0xC0:
            # A pointer (the last 14 bits are the offset).
            if off + 1 >= len(data):
                break
            ptr = off + 2
            off = (ln & 0x3F) << 8 | data[off + 1]
            seen = ptr
            continue
        if off + 1 + ln > len(data):
            break
        labels.append(data[off + 1:off + 1 + ln].decode("latin-1"))
        off += 1 + ln
    return ".".join(labels).lower(), seen


def build_answer(query: bytes) -> bytes:
    # Rebuild the response: the header (QD=1, AN=1, RCODE=0) + the question
    # (copied verbatim) + a single A answer (the target IP).
    txid = query[:2]
    # The header (2 flags + QD=1 + AN=1 + NS=0 + AR=0 + RCODE=0).
    header = txid + struct.pack(">HHHHH", 0x8180, 1, 1, 0, 0)
    # The question (from offset 12 to the end of the name, + 4 bytes for the
    # QTYPE/QCLASS). We locate the end of the question name by walking it.
    off = 12
    while off < len(query):
        ln = query[off]
        if ln == 0:
            off += 1
            break
        if ln & 0xC0 == 0xC0:
            off += 2
            break
        off += 1 + ln
    question = query[12:off + 4]
    # The answer: the name (a pointer to the question name at offset 12) +
    # the A record (QTYPE=1, QCLASS=1, TTL=300, RDLENGTH=4, the 4-byte IP).
    name_ptr = struct.pack(">H", 0xC00C)
    rdata = socket.inet_aton(TARGET)
    answer = name_ptr + struct.pack(">HHIH", 1, 1, 300, 4) + rdata
    return header + question + answer


def main():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(BIND)
    print(f"capstone-dns: listening on {BIND[1]} (udunit.lrvick.dev -> {TARGET})", flush=True)
    while True:
        data, addr = sock.recvfrom(4096)
        if len(data) < 16:
            continue
        name, _ = decode_name(data, 12)
        print(f"capstone-dns: query {name} from {addr}", flush=True)
        if name == "udunit.lrvick.dev" or name.endswith(".udunit.lrvick.dev"):
            sock.sendto(build_answer(data), addr)
        else:
            # Forward to the real resolver + relay the response back.
            fwd = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            fwd.settimeout(3.0)
            try:
                fwd.sendto(data, FORWARD)
                resp, _ = fwd.recvfrom(4096)
                sock.sendto(resp, addr)
            except OSError:
                # A forward timeout (the real resolver is unreachable): a
                # SERVFAIL, not a hang (the poller treats it as a NoAnswer).
                txid = data[:2]
                sock.sendto(txid + struct.pack(">HHHHH", 0x8183, 1, 0, 0, 0) + data[12:], addr)
            finally:
                fwd.close()


if __name__ == "__main__":
    main()
