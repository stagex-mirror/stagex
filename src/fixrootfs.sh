#!/bin/bash
set -euo pipefail

# Post-process rootfs to fix BuildKit multi-platform symlinks and normalize timestamps
# Usage: fixrootfs.sh <rootfs_dir>

ROOTFS="${1:?Usage: fixrootfs.sh <rootfs_dir>}"

if [ ! -d "$ROOTFS" ]; then
  echo "Error: $ROOTFS is not a directory" >&2
  exit 1
fi

echo "Fixing symlinks and timestamps in $ROOTFS..."

# Find and fix absolute symlinks with /linux_* platform prefix
# These are created by BUILDKIT_MULTI_PLATFORM=1 but are broken when extracted as standalone rootfs
find "$ROOTFS" -type l | while IFS= read -r link; do
  target="$(readlink "$link")"
  
  # Check if target is an absolute path with /linux_* prefix (BuildKit multi-platform symlink)
  if [[ "$target" =~ ^/linux_[a-z0-9_]+(/.*)$ ]]; then
    # Strip the /linux_* prefix
    fixed="${BASH_REMATCH[1]}"
    if [ "$target" != "$fixed" ]; then
      rm "$link"
      ln -s "$fixed" "$link"
      echo "Fixed: $link -> $fixed"
    fi
  fi
done

# Deterministic, content-derived timestamps (BuildKit local-context cache fix).
#
# These dirs are fed to downstream `docker build` as local --build-context
# sources. BuildKit's local-context cache is PER-FILE, keyed on
# (path, size, mtime). The type=local exporter clamps every mtime to
# SOURCE_DATE_EPOCH (exported by src/global.mk), so a rebuilt dependency whose
# output is byte-identical in SIZE (e.g. a same-size binary swap) looked
# "unchanged" (same size + same epoch-1 mtime) and BuildKit served the STALE
# cached context, silently packing an old artifact into the disk.
#
# Fix: re-stamp every file's mtime to a DETERMINISTIC function of its content:
#   mtime = int(sha256(file)[:8], 16)  seconds since epoch (range 1970..2106)
# - changed content -> different mtime -> per-file cache MISS -> fresh context
# - unchanged content -> same mtime -> cache HIT (fast; and the hash IS the
#   content, so the served bytes are the right ones by construction)
# Symlinks are keyed by their target string (their "content"), which is stable
# across build contexts even when the target is outside this context.
#
# Disk determinism is unaffected: every packed artifact normalizes metadata at
# pack time (box-erofs --ignore-mtime --force-uid/gid=0; box-disk touches the
# cpio + ESP tree to SOURCE_DATE_EPOCH; provenance.spdx Created derives from
# SOURCE_DATE_EPOCH), so disk.img is a pure function of content.
python3 - "$ROOTFS" <<'PY'
import hashlib, os, sys
root = sys.argv[1]
for dirpath, _dirs, files in os.walk(root):
    for name in files:
        p = os.path.join(dirpath, name)
        try:
            if os.path.islink(p):
                data = os.readlink(p).encode()          # symlink "content" = target
            else:
                h = hashlib.sha256()
                with open(p, "rb") as f:                # regular file: hash bytes
                    for chunk in iter(lambda: f.read(1 << 20), b""):
                        h.update(chunk)
                data = None
                h8 = h.hexdigest()[:8]
                os.utime(p, ns=(int(h8, 16) * 10**9,) * 2)
                continue
            h8 = hashlib.sha256(data).hexdigest()[:8]   # symlink: hash target
            os.utime(p, ns=(int(h8, 16) * 10**9,) * 2, follow_symlinks=False)
        except OSError:
            pass
PY

# Remove stale intermediate-stage artifacts from type=local output with BUILDKIT_MULTI_PLATFORM=1
# Busybox rootfs (and other deps) contain stale "rootfs/" and "out/" dirs from their own builds;
# when copied into downstream build stages these cause "mv out/ /rootfs" to move out/ INTO /rootfs/
# instead of renaming it, producing /out/etc/... instead of /etc/...
if [ -d "$ROOTFS/rootfs" ]; then
  if [ -z "$(ls -A "$ROOTFS/rootfs" 2>/dev/null)" ] || [ -d "$ROOTFS/rootfs/out" ]; then
    # If rootfs/ is empty or only contains out/, remove it
    rm -rf "$ROOTFS/rootfs"
    echo "Removed stale rootfs/"
  fi
fi
if [ -d "$ROOTFS/out" ] && { [ -d "$ROOTFS/usr" ] || [ -d "$ROOTFS/etc" ]; }; then
  # Root-level usr/ or etc/ means content is already at root; out/ is a stale build-stage artifact
  rm -rf "$ROOTFS/out"
  echo "Removed stale out/"
fi

echo "Done."
