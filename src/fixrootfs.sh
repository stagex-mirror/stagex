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

# Normalize all timestamps to SOURCE_DATE_EPOCH (1 second after Unix epoch)
# This ensures reproducible builds regardless of when files were created
find "$ROOTFS" -depth -exec touch -h -d "1970-01-01 00:00:01" {} +

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
