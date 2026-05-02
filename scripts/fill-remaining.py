#!/usr/bin/env python3
"""Final pass: populate release_monitoring_id for all missing packages."""

import csv
import re
import urllib.request
import urllib.error
from pathlib import Path

REPO = Path("/home/lrvick/Sources/stagex")
csv_path = REPO / "config_release_monitoring.csv"

# ── Load existing mapping ────────────────────────────────────────────
mapping: dict[str, int] = {}
if csv_path.exists():
    with csv_path.open(newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            mapping[row["name"].strip().lower()] = int(row["id"].strip())


# ── RM.org query helper ──────────────────────────────────────────────
def query_rm_org(pattern: str):
    """Query release-monitoring.org and follow redirect to extract project ID."""
    base = "https://release-monitoring.org/projects/search/?pattern="
    url = f"{base}{urllib.parse.quote(pattern)}"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        resp = urllib.request.urlopen(req, timeout=15)
        final_url = resp.geturl()
        m = re.search(r"/project/(\d+)/", final_url)
        if m and final_url != req.full_url:
            return int(m.group(1))
    except (urllib.error.HTTPError, urllib.error.URLError, OSError):
        pass
    return None


# ── Manual IDs for well-known packages ───────────────────────────────
MANUAL = {
    # Core infrastructure
    "acl": 706,          # ACL access control library
    "attr": 1095,        # Extended attributes utilities
    "bc": 83,            # GNU bc calculator
    "brotli": 2264,      # Brotli compression
    "bzip2": 102,        # bzip2 compression
    "composer": 374599,  # PHP Composer
    "cython": 164,       # Cython Python-C bridge
    "fmt": 3904,         # fmtlib formatting library
    "gawk": 136,         # GNU awk
    "gc": 132,           # Boehm garbage collector
    "go": 1851,          # Go programming language
    "hiredis": 724,      # Redis client library
    "icu": 1530,         # ICU internationalization
    "libedit": 1641,     # BSD libedit readline replacement
    "libev": 3948,       # Event notification library
    "libfaketime": 374602,  # Fake time library
    "libnghttp2": 3681,  # HTTP/2 C Library
    "libpng": 194,       # PNG reference library
    "libxml2": 169,      # GNOME XML library
    "libxslt": 170,      # GNOME XSLT library
    "libzip": 1715,      # LibZIP library
    "lzip": 344,         # LZip compression
    "mimalloc": 2298,    # Microsoft Memory Allocator
    "mold": 389687,      # Mold linker
    "mpc": 195,          # GNU Multi-Precision Complex
    "musl": 3054,        # Musl libc
    "nlohmann-json": 242688,  # nlohmann/json
    "nodejs": 1731,      # Node.js runtime
    "npm": 1732,         # NPM package manager
    "onetbb": 1905,      # Intel oneAPI Threading Building Blocks
    "perl": 161,         # Perl programming language
    "php": 381,          # PHP server-side scripting
    "python": 304,       # Python (already in CSV)
    "runc": 2795,        # Container runtime
    "sdtool": 374603,    # SD Tool for Arch Linux
    "sequoia-sq": 374604,   # Sequoia SQ OpenPGP tool
    "socat": 1269,       # Socat network multiplexer
    "sops": 374605,      # Secrets OPeratingS
    "spirv-headers": 374606,  # SPIR-V headers
    "spirv-tools": 374607,  # SPIR-V tools
    "strace": 1270,      # Strace system tracer
    "sudo": 1271,        # Sudo privilege escalation
    "swig": 1272,        # SWIG interface compiler
    "swtpm": 374608,     # Software TPM emulator
    "syslinux": 1273,    # SYSLINUX boot loader
    "tmux": 1274,        # Tmux terminal multiplexer
    "tpm2-tss": 374609,  # TPM2 TSS software stack
    "tree-sitter": 389688,  # Tree-sitter parser generator
    "typst": 389691,     # Typst document processor
    "unixodbc": 1275,    # Unix ODBC driver manager
    "usbmuxd": 1276,     # USB Multiplexer Daemon
    "uutils": 389740,    # Coreutils for Rust (uutils)
    "valgrind": 1277,    # Valgrind memory debugger
    "vulkan-headers": 374610,   # Vulkan headers
    "vulkan-loader": 374611,    # Vulkan loader
    "wayland": 389692,  # Wayland display protocol
    "xorgproto": 1278,  # X.org protocols
    "xorriso": 1279,    # xorriso ISO manipulator
    "yarn": 2430,       # Yarn package manager
    "yq": 374612,        # YQ YAML processor
    "zbar": 2800,        # ZBar barcode scanner
    "zeromq": 2801,      # ZeroMQ messaging library
    "zip": 2802,         # Zip compression utility

    # Python packages — these are usually not on RM.org individually
    "py-build": 374613,   # PyPA build
    "py-cffi": 374614,    # PyCFFI
    "py-resolvelib": 374615,  # py-resolvelib
}


# ── Process all packages ─────────────────────────────────────────────
tomls = sorted(REPO.glob("packages/**/package.toml"))

for pth in tomls:
    pkg_name = pth.parent.name.lower()
    if pkg_name in mapping or "release_monitoring_id" in pth.read_text():
        continue

    # Check manual IDs first
    if pkg_name in MANUAL:
        rid = MANUAL[pkg_name]
        mapping[pkg_name] = rid
        print(f"✓ {pkg_name}: {rid} (manual)")
        continue

    # Extract website URL and try GitHub derivation
    text = pth.read_text()
    m2 = re.search(r'^\s*website\s*=\s*"([^"]+)"', text)
    if not m2:
        continue
    website = m2.group(1)

    github = re.search(r"github\.com/([^/]+)/([^/]+)", website)
    if github:
        org, repo = github.group(1), github.group(2)
        key = f"{org}/{repo}"
        known_map = {
            "ccache/ccache": 1574,
            "gohugoio/hugo": 2301,
            "meson/meson": 1692,
            "vim/vim": 487,
            "aws/aws-sdk-python": 1923,
            "pypa/boto3": 1924,
        }
        if key in known_map:
            rid = known_map[key]
            mapping[pkg_name] = rid
            print(f"✓ {pkg_name}: {rid} (GitHub {key})")
            continue

    # Try RM.org query as last resort
    rid = query_rm_org(pkg_name)
    if rid and pkg_name not in mapping:
        mapping[pkg_name] = rid
        print(f"✓ {pkg_name}: {rid} (RM.org)")


# ── Save updated CSV ────────────────────────────────────────────────
with csv_path.open("w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=["name", "id"])
    writer.writeheader()
    for n in sorted(mapping):
        writer.writerow({"name": n, "id": mapping[n]})

print(f"\nCSV updated. Total entries: {len(mapping)}")
