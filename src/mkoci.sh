#!/bin/sh
# mkoci.sh - Convert an extracted rootfs directory into a deterministic OCI image layout
#
# Usage: mkoci.sh <rootfs-dir> <oci-output-dir> <image-name> <version> [<architecture>] [<metadata.json>]
#
# Example: mkoci.sh out/rootfs/core-busybox out/oci/core-busybox stagex/core-busybox 1.35.0 amd64
#          mkoci.sh out/rootfs/pallet-go out/oci/pallet-go stagex/pallet-go 1.24 amd64 out/rootfs/pallet-go/metadata.json
#
# Produces an OCI layout with the same structure as BuildKit's type=oci exporter:
#   index.json -> platform index -> image manifest -> config + layers

set -eu

ROOTFS_DIR="${1}"
OCI_DIR="${2}"
IMAGE_NAME="${3}"
VERSION="${4}"
ARCHITECTURE="${5:-$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/;s/riscv64/riscv64/;s/armv7l/arm/;s/armv6l/arm/;s/i[3456]86/386/')}"
# Handle "linux/amd64" format — extract just the arch
ARCHITECTURE="${ARCHITECTURE#*/}"
METADATA_FILE="${6:-}"
CREATED="${OCI_CREATED:-1970-01-01T00:00:01Z}"
EPOCH="${SOURCE_DATE_EPOCH:-1}"

# Create OCI layout directory
rm -rf "$OCI_DIR"
mkdir -p "$OCI_DIR/blobs/sha256"

# Write oci-layout
printf '{"imageLayoutVersion":"1.0.0"}\n' > "$OCI_DIR/oci-layout"

# Create deterministic layer tarball
LAYER_TAR="$OCI_DIR/blobs/sha256/layer.tar"
tar --sort=name \
    --mtime="@${EPOCH}" \
    --owner=0 --group=0 \
    --numeric-owner \
    --xattrs \
    --xattrs-include='security.*' \
    -cf "$LAYER_TAR" \
    -C "$ROOTFS_DIR" .

LAYER_DIGEST="sha256:$(sha256sum "$LAYER_TAR" | cut -d' ' -f1)"

# Compress layer (gzip -n for deterministic headers, -9 for max compression)
gzip -n -9 < "$LAYER_TAR" > "${LAYER_TAR}.gz"
LAYER_GZ_DIGEST="sha256:$(sha256sum "${LAYER_TAR}.gz" | cut -d' ' -f1)"
LAYER_SIZE=$(wc -c < "${LAYER_TAR}.gz")
rm -f "$LAYER_TAR"

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

# Build image config
CONFIG_FILE="$OCI_DIR/blobs/sha256/config.json"
printf '{"created":"%s","architecture":"%s","os":"linux","config":%s,"rootfs":{"type":"layers","diff_ids":["%s"]},"history":[{"created":"%s","created_by":"stagex rootfs-to-oci %s:%s"}]}' \
    "$CREATED" "$ARCHITECTURE" "$CONFIG_SECTION" "$LAYER_DIGEST" "$CREATED" "$IMAGE_NAME" "$VERSION" \
    > "$CONFIG_FILE"
CONFIG_DIGEST="sha256:$(sha256sum "$CONFIG_FILE" | cut -d' ' -f1)"
CONFIG_SIZE=$(wc -c < "$CONFIG_FILE")
mv "$CONFIG_FILE" "$OCI_DIR/blobs/sha256/${CONFIG_DIGEST#sha256:}"

# Build image manifest
MANIFEST_FILE="$OCI_DIR/blobs/sha256/manifest.json"
printf '{"schemaVersion":2,"mediaType":"application/vnd.oci.image.manifest.v1+json","config":{"mediaType":"application/vnd.oci.image.config.v1+json","digest":"%s","size":%s},"layers":[{"mediaType":"application/vnd.oci.image.layer.v1.tar+gzip","digest":"%s","size":%s,"annotations":{"buildkit/rewritten-timestamp":"1"}}],"annotations":{"containerd.io/distribution.source.docker.io":"%s","org.opencontainers.image.created":"%s","org.opencontainers.image.version":"%s"}}' \
    "$CONFIG_DIGEST" "$CONFIG_SIZE" "$LAYER_GZ_DIGEST" "$LAYER_SIZE" "$IMAGE_NAME" "$CREATED" "$VERSION" \
    > "$MANIFEST_FILE"
MANIFEST_DIGEST="sha256:$(sha256sum "$MANIFEST_FILE" | cut -d' ' -f1)"
MANIFEST_SIZE=$(wc -c < "$MANIFEST_FILE")
mv "$MANIFEST_FILE" "$OCI_DIR/blobs/sha256/${MANIFEST_DIGEST#sha256:}"

# Build platform index
PLATFORM_INDEX="$OCI_DIR/blobs/sha256/platform-index.json"
printf '{"schemaVersion":2,"mediaType":"application/vnd.oci.image.index.v1+json","manifests":[{"mediaType":"application/vnd.oci.image.manifest.v1+json","digest":"%s","size":%s,"platform":{"architecture":"%s","os":"linux"}}]}' \
    "$MANIFEST_DIGEST" "$MANIFEST_SIZE" "$ARCHITECTURE" \
    > "$PLATFORM_INDEX"
PLATFORM_INDEX_SIZE=$(wc -c < "$PLATFORM_INDEX")
PLATFORM_DIGEST="sha256:$(sha256sum "$PLATFORM_INDEX" | cut -d' ' -f1)"
mv "$PLATFORM_INDEX" "$OCI_DIR/blobs/sha256/${PLATFORM_DIGEST#sha256:}"

# Rename layer to digest-based name
mv "$OCI_DIR/blobs/sha256/layer.tar.gz" "$OCI_DIR/blobs/sha256/${LAYER_GZ_DIGEST#sha256:}"

# Build index.json
printf '{"schemaVersion":2,"mediaType":"application/vnd.oci.image.index.v1+json","manifests":[{"mediaType":"application/vnd.oci.image.index.v1+json","digest":"%s","size":%s,"annotations":{"io.containerd.image.name":"%s:%s","org.opencontainers.image.created":"%s","org.opencontainers.image.ref.name":"%s"}}]}' \
    "$PLATFORM_DIGEST" "$PLATFORM_INDEX_SIZE" "$IMAGE_NAME" "$VERSION" "$CREATED" "$VERSION" \
    > "$OCI_DIR/index.json"

echo "OCI layout created: $OCI_DIR"
echo "  Platform: linux/${ARCHITECTURE}"
echo "  Layer: ${LAYER_GZ_DIGEST} (${LAYER_SIZE} bytes)"
echo "  Config: ${CONFIG_DIGEST}"
echo "  Manifest: ${MANIFEST_DIGEST}"
