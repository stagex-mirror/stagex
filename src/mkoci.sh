#!/usr/bin/env bash
# mkoci.sh - Convert an extracted rootfs directory into a deterministic OCI image layout
#
# Usage: mkoci.sh <rootfs-dir> <oci-output-dir> <image-name> <version> [<architecture>]
#
# Example: mkoci.sh out/rootfs/core-busybox out/oci/core-busybox stagex/core-busybox 1.35.0 amd64
#
# Produces an OCI layout with the same structure as BuildKit's type=oci exporter:
#   index.json → platform index → image manifest → config + layers

set -euo pipefail

ROOTFS_DIR="${1:?Error: rootfs directory required}"
OCI_DIR="${2:?Error: OCI output directory required}"
IMAGE_NAME="${3:?Error: image name required (e.g. stagex/core-busybox)}"
VERSION="${4:?Error: version required}"
ARCHITECTURE="${5:-$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/;s/riscv64/riscv64/;s/armv7l/arm/;s/armv6l/arm/;s/i[3456]86/386/')}"
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
rm -f "$LAYER_TAR"  # Remove uncompressed to save space

# Build image config
CONFIG_FILE="$OCI_DIR/blobs/sha256/config.json"
printf '{"created":"%s","architecture":"%s","os":"linux","config":{},"rootfs":{"type":"layers","diff_ids":["%s"]},"history":[{"created":"%s","created_by":"stagex rootfs-to-oci %s:%s"}]}' \
    "$CREATED" "$ARCHITECTURE" "$LAYER_DIGEST" "$CREATED" "$IMAGE_NAME" "$VERSION" \
    > "$CONFIG_FILE"
CONFIG_DIGEST="sha256:$(sha256sum "$CONFIG_FILE" | cut -d' ' -f1)"
CONFIG_SIZE=$(wc -c < "$CONFIG_FILE")

# Build image manifest
MANIFEST_FILE="$OCI_DIR/blobs/sha256/manifest.json"
printf '{"schemaVersion":2,"mediaType":"application/vnd.oci.image.manifest.v1+json","config":{"mediaType":"application/vnd.oci.image.config.v1+json","digest":"%s","size":%s},"layers":[{"mediaType":"application/vnd.oci.image.layer.v1.tar+gzip","digest":"%s","size":%s,"annotations":{"buildkit/rewritten-timestamp":"1"}}],"annotations":{"containerd.io/distribution.source.docker.io":"%s","org.opencontainers.image.created":"%s","org.opencontainers.image.version":"%s"}}' \
    "$CONFIG_DIGEST" "$CONFIG_SIZE" "$LAYER_GZ_DIGEST" "$LAYER_SIZE" "$IMAGE_NAME" "$CREATED" "$VERSION" \
    > "$MANIFEST_FILE"
MANIFEST_DIGEST="sha256:$(sha256sum "$MANIFEST_FILE" | cut -d' ' -f1)"
MANIFEST_SIZE=$(wc -c < "$MANIFEST_FILE")

# Build platform index (intermediate index, matches BuildKit multi-platform structure)
PLATFORM_INDEX="$OCI_DIR/blobs/sha256/platform-index.json"
printf '{"schemaVersion":2,"mediaType":"application/vnd.oci.image.index.v1+json","manifests":[{"mediaType":"application/vnd.oci.image.manifest.v1+json","digest":"%s","size":%s,"platform":{"architecture":"%s","os":"linux"}}]}' \
    "$MANIFEST_DIGEST" "$MANIFEST_SIZE" "$ARCHITECTURE" \
    > "$PLATFORM_INDEX"
PLATFORM_DIGEST="sha256:$(sha256sum "$PLATFORM_INDEX" | cut -d' ' -f1)"

# Build index.json
printf '{"schemaVersion":2,"mediaType":"application/vnd.oci.image.index.v1+json","manifests":[{"mediaType":"application/vnd.oci.image.index.v1+json","digest":"%s","size":%s,"annotations":{"io.containerd.image.name":"%s:%s","org.opencontainers.image.created":"%s","org.opencontainers.image.ref.name":"%s"}}]}' \
    "$PLATFORM_DIGEST" "$(wc -c < "$PLATFORM_INDEX")" "$IMAGE_NAME" "$VERSION" "$CREATED" "$VERSION" \
    > "$OCI_DIR/index.json"

echo "OCI layout created: $OCI_DIR"
echo "  Platform: linux/${ARCHITECTURE}"
echo "  Layer: ${LAYER_GZ_DIGEST} (${LAYER_SIZE} bytes)"
echo "  Config: ${CONFIG_DIGEST}"
echo "  Manifest: ${MANIFEST_DIGEST}"
