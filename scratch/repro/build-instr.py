#!/usr/bin/env python3
"""Instrumented repro disk: swap the system erofs (instrumented regentd) into the
stock initrd, rebuild the UKI (.initrd/.cmdline swap), patch disk-instr.img FAT.
PE handling is generic: read the section table, keep layout, rewrite the file."""
import struct, subprocess, gzip, io, os, sys, hashlib

R = os.path.dirname(os.path.abspath(__file__))
os.chdir(R)
WARDEND = "/home/lrvick/Sources/wardend"

# ---------- 1. stock initrd cpio: replace the `system` member ----------
if not os.path.exists("stock-initrd.cpio"):
    with open("initrd", "rb") as f:
        open("stock-initrd.cpio", "wb").write(gzip.decompress(f.read()))
cpio = open("stock-initrd.cpio", "rb").read()

def cpio_parse(buf):
    members, off = [], 0
    while off + 110 <= len(buf):
        assert buf[off:off+6] == b"070701", f"bad magic at {off}"
        hdr = buf[off:off+110]
        f = [int(hdr[6+i*8:14+i*8], 16) for i in range(13)]
        namesize, filesize = f[11], f[6]
        name = buf[off+110:off+110+namesize-1].decode()
        doff = (off+110+namesize+3) & ~3
        members.append((name, f, buf[doff:doff+filesize]))
        off = (doff+filesize+3) & ~3
        if name == "TRAILER!!!":
            break
    return members

members = cpio_parse(cpio)
print("initrd members:", [(m[0], len(m[2]), oct(m[1][1])) for m in members])

BIN = os.path.join(WARDEND, "target/x86_64-unknown-linux-musl/release/regentd")
subprocess.run(["cp", BIN, "systree/usr/bin/regentd"], check=True)
if not os.environ.get("SKIP_EROFS"):
    subprocess.run(["sh", "-c", "echo lanosmonkey | sudo -S mkfs.erofs -z lz4 -U 8c1f0a2e-4b6d-4e8f-9a3c-5d7b9e1f2c4a system.ins systree > /dev/null"], check=True)
erofs = open("system.ins", "rb").read()
print("erofs:", len(erofs))

def cpio_member(name, f, data):
    # newc field order: ino mode uid gid nlink mtime filesize devmajor devminor rdev namesize chksum
    n = name.encode() + b"\0"
    f = list(f)
    f[6] = len(data)
    f[11] = len(n)
    f[12] = 0
    hdr = b"070701" + b"".join(b"%08X" % v for v in f)
    # The kernel's popc/newc reader (init/do_mounts.c, binfmt_cpio) advances to
    # data via ALIGN(4, off + 110 + namesize), i.e. padding is computed over
    # header+name TOGETHER, relative to the archive start. The 110-byte header
    # is NOT a multiple of 4 (110 % 4 == 2), so aligning the name alone
    # ((-len(n)) % 4) emits the wrong pad whenever (110+namesize) % 4 != 0 —
    # the kernel then hits "rootfs image is not initramfs (broken padding)",
    # falls back to the block ramdisk, and panics with unknown-block(0,0).
    return hdr + n + b"\0" * ((-(110 + len(n))) % 4) + data + b"\0" * ((-len(data)) % 4)

out = io.BytesIO()
swapped = False
trailer_f = [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 12, 0]
for name, f, data in members:
    if name == "TRAILER!!!":
        trailer_f = f
        continue
    if name.lstrip("./") == "system":
        data = erofs
        swapped = True
    out.write(cpio_member(name, f, data))
assert swapped, "no system member in initrd!"
out.write(cpio_member("TRAILER!!!", trailer_f, b""))
new_cpio = out.getvalue()
new_initrd = gzip.compress(new_cpio, 9, mtime=0)
open("new-initrd.gz", "wb").write(new_initrd)
print("new initrd.gz:", len(new_initrd))

# ---------- 2. rebuild UKI, generic PE section swap ----------
def align(v, a): return (v + a - 1) // a * a

data = open("BOOTX64.EFI", "rb").read()
pe = struct.unpack_from("<I", data, 0x3c)[0]
assert data[pe:pe+4] == b"PE\0\0"
coff = pe + 4
nsec = struct.unpack_from("<H", data, coff + 2)[0]
so = coff + 20
size_of_image = struct.unpack_from("<I", data, so + 56)[0]
sect_align = struct.unpack_from("<I", data, so + 32)[0]
file_align = struct.unpack_from("<I", data, so + 36)[0]
hdrsz = struct.unpack_from("<I", data, so + 60)[0]
taboff = coff + 20 + struct.unpack_from("<H", data, coff + 16)[0]
secs = []
for i in range(nsec):
    e = data[taboff + i*40: taboff + (i+1)*40]
    nm = e[:8].rstrip(b"\0").decode()
    vsize, vaddr, rawsize, rawptr = struct.unpack_from("<IIII", e, 8)
    chars = struct.unpack_from("<I", e, 36)[0]
    secs.append([nm, vsize, vaddr, rawsize, rawptr, chars])
for s in secs:
    print(" sec", s[0], f"vsize={s[1]:x} vaddr={s[2]:x} rawptr={s[4]:x} chars={s[5]:x}")

cmdline = open("cmdline", "rb").read().strip() + b"\0"
cmdline = cmdline[:max(16, align(len(cmdline), 16))] or cmdline
repl = {".initrd": new_initrd, ".cmdline": cmdline}

# contents per section, new sizes
contents = []
for s in secs:
    if s[0] in repl:
        contents.append(repl[s[0]])
    else:
        contents.append(data[s[4]:s[4]+s[3]] if s[3] else b"")

# new file layout: headers, new section table, sections at file_align
head = bytearray(data[:taboff])
new_off = align(max(taboff + nsec*40, hdrsz), file_align)
layout = []
off = new_off
for s, c in zip(secs, contents):
    if c:
        layout.append(off)
        off += align(len(c), file_align)
    else:
        layout.append(0)

total_off = off
tab = b""
for s, off_, c in zip(secs, layout, contents):
    s[1] = len(c) if c else s[1]
    rawsz = align(len(c), file_align) if c else 0
    tab += s[0].encode().ljust(8, b"\0") + struct.pack(
        "<IIIIIIHHI", s[1], s[2], rawsz, off_, 0, 0, 0, 0, s[5])
struct.pack_into("<I", head, coff + 20 + 56,
                 max(s[2] + align(s[1], sect_align) for s in secs))
outb = bytearray(head) + tab + b"\0" * (total_off - (taboff + len(tab)))
for off_, c in zip(layout, contents):
    if c:
        outb[off_:off_+len(c)] = c
open("BOOTX64.ins", "wb").write(bytes(outb))
print("UKI:", len(outb))

# verify round-trip
d2 = open("BOOTX64.ins", "rb").read()
p2 = struct.unpack_from("<I", d2, 0x3c)[0]; c2 = p2 + 4
n2 = struct.unpack_from("<H", d2, c2 + 2)[0]
o2 = struct.unpack_from("<H", d2, c2 + 16)[0]
for i in range(n2):
    e = d2[c2+20+o2+i*40: c2+20+o2+(i+1)*40]
    nm = e[:8].rstrip(b"\0").decode()
    vsize, vaddr, rawsize, rawptr = struct.unpack_from("<IIII", e, 8)
    if nm == ".initrd":
        gz = d2[rawptr:rawptr+vsize]
        assert gz[:2] == b"\x1f\x8b"
        cp = gzip.decompress(gz)
        # Fail closed: walk the emitted cpio with the KERNEL's own advance
        # formula ((off + 110 + namesize + 3) & ~3 for the data offset, then
        # (doff + filesize + 3) & ~3 for the next record). A count of "070701"
        # bytes passes even when the padding is off by 2 and the kernel will
        # reject the archive; a strict walk does not lie.
        off, seen = 0, 0
        while off + 110 <= len(cp):
            assert cp[off:off+6] == b"070701", (
                f"cpio broken padding: no magic at {off} (kernel would reject the initrd)")
            namesize = int(cp[off+94:off+102], 16)
            filesize = int(cp[off+54:off+62], 16)
            name = cp[off+110:off+110+namesize-1].decode()
            doff = (off + 110 + namesize + 3) & ~3
            off = (doff + filesize + 3) & ~3
            seen += 1
            if name == "TRAILER!!!":
                break
        assert seen >= 3 and name == "TRAILER!!!", f"cpio walk incomplete (records={seen})"
        print("UKI verify ok: initrd cpio walks clean to TRAILER", len(cp))
    if nm == ".cmdline":
        cs = d2[rawptr:rawptr+vsize].rstrip(b"\0").decode()
        print("cmdline:", cs[:100])

# ---------- 3. patch disk-instr.img ESP FAT ----------
# Use a loop mount (mtools FAT math on this image was unreliable).
import shutil, hashlib
shutil.copyfile("disk-instr.img", "disk-instrumented.img")
subprocess.run(["sh", "-c",
    "echo lanosmonkey | sudo -S mount -o loop,rw,offset=1048576 disk-instrumented.img /mnt/esp-ins && "
    "echo lanosmonkey | sudo -S cp BOOTX64.ins /mnt/esp-ins/EFI/BOOT/BOOTX64.EFI && sync && "
    "echo lanosmonkey | sudo -S umount /mnt/esp-ins"], check=True)
print("WROTE disk-instrumented.img", hashlib.sha256(open("disk-instrumented.img","rb").read()).hexdigest()[:16])
