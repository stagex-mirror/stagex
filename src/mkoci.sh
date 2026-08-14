#!/bin/sh
# mkoci.sh - Convert an extracted rootfs directory into a deterministic OCI image layout
#
# Usage: mkoci.sh <rootfs-dir> <oci-output-dir> <image-name> <version> [<architecture>] [<metadata.json>]
#
# Example: mkoci.sh out/rootfs/core-busybox out/oci/core-busybox stagex/core-busybox 1.35.0 amd64
#          mkoci.sh out/rootfs/pallet-go out/oci/pallet-go stagex/pallet-go 1.24 amd64 out/rootfs/pallet-go/metadata.json
#
# The rootfs tree is out/rootfs/{name}/{platform}/<filesystem>, where {platform}
# is a directory like "linux_amd64" or "linux_arm64". One OCI image manifest is
# produced per platform directory, so the resulting index.json is a proper
# multi-arch image index that can carry future architectures.
#
# Produces an OCI layout with the same structure as BuildKit's type=oci exporter:
#   index.json -> (one platform index per platform) -> image manifest -> config + layers
#
# Archives the *contents* of each platform directory at the layer root (not the
# platform dir itself). Baking the platform dir in as a stray top-level entry
# breaks base-image inheritance when the image is used as a build context
# (e.g. /etc/profile from core-profile would land at /linux_amd64/etc/profile).

set -eu

ROOTFS_DIR="${1}"
OCI_DIR="${2}"
IMAGE_NAME="${3}"
VERSION="${4}"
ARCHITECTURE="${5:-}"
# Handle "linux/amd64" format — extract just the arch
ARCHITECTURE="${ARCHITECTURE#*/}"
METADATA_FILE="${6:-}"
CREATED="${OCI_CREATED:-1970-01-01T00:00:01Z}"
EPOCH="${SOURCE_DATE_EPOCH:-1}"

# Platform directory name -> architecture
#   linux_amd64 -> amd64, linux_arm64 -> arm64, linux_riscv64 -> riscv64, ...
# Falls back to the ARCHITECTURE argument for a bare rootfs without platform dirs.
arch_from_dir() {
  printf '%s' "$1" | sed 's/^linux_//'
}

# Create OCI layout directory
rm -rf "$OCI_DIR"
mkdir -p "$OCI_DIR/blobs/sha256"

# Write oci-layout
printf '{"imageLayoutVersion":"1.0.0"}\n' > "$OCI_DIR/oci-layout"

# Build config section from metadata.json if available, otherwise empty
CONFIG_SECTION="{}"
if [ -n "$METADATA_FILE" ] && [ -f "$METADATA_FILE" ]; then
  CONFIG_SECTION=$(jq -c '{
    Env: (if .env then .env else [] end),
    Shell: (if .shell then .shell else null end),
    Entrypoint: (if .entrypoint then .entrypoint else null end),
    Cmd: (if .cmd then .cmd else null end),
    WorkingDir: (if .workingdir then .workingdir else null end)
  }' "$METADATA_FILE")
fi

# Collect platform directories present in the rootfs. If the argument named a
# single architecture and only that platform dir exists, use just it; otherwise
# build every linux_* platform directory found so index.json is multi-arch.
PLATFORM_DIRS=
if [ -d "$ROOTFS_DIR" ]; then
  for candidate in "$ROOTFS_DIR"/linux_*; do
    [ -d "$candidate" ] || continue
    if [ -n "$ARCHITECTURE" ]; then
      want="linux_${ARCHITECTURE}"
      if [ "$(basename "$candidate")" = "$want" ]; then
        PLATFORM_DIRS="$candidate"
        break
      fi
      continue
    fi
    PLATFORM_DIRS="${PLATFORM_DIRS} $candidate"
  done
fi
# No platform dirs at all: treat the rootfs dir itself as a single-platform root
if [ -z "$PLATFORM_DIRS" ]; then
  PLATFORM_DIRS="$ROOTFS_DIR"
fi

MANIFESTS=
for LAYER_ROOT in $PLATFORM_DIRS; do
  base="$(basename "$LAYER_ROOT")"
  case "$base" in
    linux_*) PLATFORM_ARCH="$(arch_from_dir "$base")" ;;
    *)       PLATFORM_ARCH="${ARCHITECTURE:-$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/;s/riscv64/riscv64/;s/armv7l/arm/;s/armv6l/arm/;s/i[3456]86/386/')}" ;;
  esac

  # Create deterministic layer tarball per platform
  LAYER_TAR="$OCI_DIR/blobs/sha256/layer.tar"
  tar --sort=name \
      --mtime="@${EPOCH}" \
      --owner=0 --group=0 \
      --numeric-owner \
      --xattrs \
      --xattrs-include='security.*' \
      -cf "$LAYER_TAR" \
      -C "$LAYER_ROOT" .
  LAYER_DIGEST="sha256:$(sha256sum "$LAYER_TAR" | cut -d' ' -f1)"

  # Compress layer (gzip -n for deterministic headers, -9 for max compression)
  gzip -n -9 < "$LAYER_TAR" > "${LAYER_TAR}.gz"
  LAYER_GZ_DIGEST="sha256:$(sha256sum "${LAYER_TAR}.gz" | cut -d' ' -f1)"
  LAYER_SIZE=$(wc -c < "${LAYER_TAR}.gz")
  rm -f "$LAYER_TAR"
  mv "${LAYER_TAR}.gz" "$OCI_DIR/blobs/sha256/${LAYER_GZ_DIGEST#sha256:}"

  # Build per-platform image config
  CONFIG_FILE="$OCI_DIR/blobs/sha256/config.json"
  jq -nc \
      --arg created "$CREATED" \
      --arg arch "$PLATFORM_ARCH" \
      --argjson cfg "$CONFIG_SECTION" \
      --arg diff "$LAYER_DIGEST" \
      --arg image "$IMAGE_NAME" \
      --arg version "$VERSION" \
      '{created:$created,architecture:$arch,os:"linux",config:$cfg,rootfs:{type:"layers",diff_ids:[$diff]},history:[{created:$created,created_by:("stagex rootfs-to-oci "+$image+":"+$version)}]}' \
      > "$CONFIG_FILE"
  CONFIG_DIGEST="sha256:$(sha256sum "$CONFIG_FILE" | cut -d' ' -f1)"
  CONFIG_SIZE=$(wc -c < "$CONFIG_FILE")
  mv "$CONFIG_FILE" "$OCI_DIR/blobs/sha256/${CONFIG_DIGEST#sha256:}"

  # Build per-platform image manifest
  MANIFEST_FILE="$OCI_DIR/blobs/sha256/manifest.json"
  printf '{"schemaVersion":2,"mediaType":"application/vnd.oci.image.manifest.v1+json","config":{"mediaType":"application/vnd.oci.image.config.v1+json","digest":"%s","size":%s},"layers":[{"mediaType":"application/vnd.oci.image.layer.v1.tar+gzip","digest":"%s","size":%s,"annotations":{"buildkit/rewritten-timestamp":"1"}}],"annotations":{"containerd.io/distribution.source.docker.io":"%s","org.opencontainers.image.created":"%s","org.opencontainers.image.version":"%s"}}' \
      "$CONFIG_DIGEST" "$CONFIG_SIZE" "$LAYER_GZ_DIGEST" "$LAYER_SIZE" "$IMAGE_NAME" "$CREATED" "$VERSION" \
      > "$MANIFEST_FILE"
  MANIFEST_DIGEST="sha256:$(sha256sum "$MANIFEST_FILE" | cut -d' ' -f1)"
  MANIFEST_SIZE=$(wc -c < "$MANIFEST_FILE")
  mv "$MANIFEST_FILE" "$OCI_DIR/blobs/sha256/${MANIFEST_DIGEST#sha256:}"

  # Build per-platform index (one per platform, mirroring BuildKit layout)
  PLATFORM_INDEX="$OCI_DIR/blobs/sha256/platform-index.json"
  printf '{"schemaVersion":2,"mediaType":"application/vnd.oci.image.index.v1+json","manifests":[{"mediaType":"application/vnd.oci.image.manifest.v1+json","digest":"%s","size":%s,"platform":{"architecture":"%s","os":"linux"}}]}' \
      "$MANIFEST_DIGEST" "$MANIFEST_SIZE" "$PLATFORM_ARCH" \
      > "$PLATFORM_INDEX"
  PLATFORM_INDEX_SIZE=$(wc -c < "$PLATFORM_INDEX")
  PLATFORM_DIGEST="sha256:$(sha256sum "$PLATFORM_INDEX" | cut -d' ' -f1)"
  mv "$PLATFORM_INDEX" "$OCI_DIR/blobs/sha256/${PLATFORM_DIGEST#sha256:}"

  # Collect manifest entries for the top-level index
  if [ -n "$MANIFESTS" ]; then
    MANIFESTS="${MANIFESTS},"
  fi
  MANIFESTS="${MANIFESTS}{\"mediaType\":\"application/vnd.oci.image.index.v1+json\",\"digest\":\"${PLATFORM_DIGEST}\",\"size\":${PLATFORM_INDEX_SIZE},\"platform\":{\"architecture\":\"${PLATFORM_ARCH}\",\"os\":\"linux\"}}"
done

# Build top-level multi-arch index.json
printf '{"schemaVersion":2,"mediaType":"application/vnd.oci.image.index.v1+json","manifests":[%s],"annotations":{"io.containerd.image.name":"%s:%s","org.opencontainers.image.created":"%s","org.opencontainers.image.ref.name":"%s"}}' \
    "$MANIFESTS" "$IMAGE_NAME" "$VERSION" "$CREATED" "$VERSION" \
    > "$OCI_DIR/index.json"
INDEX_DIGEST="sha256:$(sha256sum "$OCI_DIR/index.json" | cut -d' ' -f1)"

echo "OCI layout created: $OCI_DIR"
echo "  Platforms: $(echo $PLATFORM_DIRS | wc -w)"
for LAYER_ROOT in $PLATFORM_DIRS; do
  base=$(basename "$LAYER_ROOT")
  case "$base" in
    linux_*) echo "  - $base" ;;
    *)       echo "  - $ROOTFS_DIR" ;;
  esac
done
echo "  Index: ${INDEX_DIGEST}"
