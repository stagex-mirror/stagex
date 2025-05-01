#!/bin/sh

# This program checks if a manifest on a remote needs to be updated when compared to a local version.
# This should be run prior to pushing a new image, to ensure the image actually needs to be pushed.
# If the program exits successfully, the manifest exists, and does not need to be pushed.
# USAGE: sh src/has-manifest.sh stagex/bootstrap-stage0:sx2025.04.0 ./out/bootstrap-stage0

# NOTE: Do not set pipefail to maintain POSIX compatibility, but also to ensure
# not having a manifest on the remote doesn't result in an exit.
set -eux
REMOTE="$1"
LOCAL="$2"

manifest_digest_file="$(jq -er '.manifests[0].digest' "$LOCAL/index.json" | tr ':' '/')"
manifest_digest="$(jq -er '.manifests[0].digest' "$LOCAL/blobs/$manifest_digest_file")"
# fail-safe: if the command fails, and jq can't make valid output, it will not
# compare to the local image, and we will continue to the push stage.
remote_digest="$(docker manifest inspect "$REMOTE" | jq -r '.manifests[0].digest')"

if test ! "$manifest_digest" = "$remote_digest"; then
  # assume the container is tagged and ready to push
  echo "Pushing... $REMOTE"
  while ! docker push "$REMOTE"; do
    echo "Retrying... $REMOTE"
  done
fi
