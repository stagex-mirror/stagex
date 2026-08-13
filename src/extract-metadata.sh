#!/bin/sh
# extract-metadata.sh - Extract Docker image config as metadata.json
#
# Usage: extract-metadata.sh <image-name> <output-path>
#
# Reads docker inspect output and extracts config fields
# (Env, Shell, Entrypoint, Cmd, WorkingDir, Labels) into a JSON file.

set -eu

IMAGE_NAME="${1:?Error: image name required}"
OUTPUT_FILE="${2:?Error: output path required}"

mkdir -p "${OUTPUT_FILE%/*}"

docker inspect "$IMAGE_NAME" | jq '{
  env: .[0].Config.Env,
  shell: .[0].Config.Shell,
  entrypoint: .[0].Config.Entrypoint,
  cmd: .[0].Config.Cmd,
  workingdir: .[0].Config.WorkingDir,
  labels: .[0].Config.Labels
}' > "$OUTPUT_FILE"
