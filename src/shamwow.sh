#!/usr/bin/env bash

set -euo pipefail

# Ensure all arguments are provided
if [ $# -ne 2 ]; then
  echo "Usage: $0 <category> <package-name>"
  echo "Example: $0 user cython"
  exit 1
fi

CATEGORY="$1"
PACKAGE="$2"
OUTDIR="out/${PACKAGE}"
CONTAINERFILE="packages/${CATEGORY}/${PACKAGE}/Containerfile"

# Check if the containerfile exists
if [ ! -f "${CONTAINERFILE}" ]; then
  echo "Error: Containerfile not found at ${CONTAINERFILE}"
  exit 1
fi

# Find COPY --from= lines in the build stage
mapfile -t lines < <(grep -n '^COPY --from=' "${CONTAINERFILE}")

if [ ${#lines[@]} -eq 0 ]; then
  echo "No COPY --from= lines found in ${CONTAINERFILE}"
  exit 0
fi

DIGEST_TARGET="digests-${CATEGORY}-${PACKAGE}"

# Capture baseline digest
echo "Building baseline digest..."
baseline_digest=$(make NOCACHE=1 "${DIGEST_TARGET}")

for entry in "${lines[@]}"; do
  lineno=$(echo "$entry" | cut -d: -f1)
  original_line=$(sed -n "${lineno}p" "${CONTAINERFILE}")

  echo "Testing line ${lineno}: ${original_line}"

  # Comment out the line
  sed -i "${lineno}s/^/# TEMP_COMMENTED: /" "${CONTAINERFILE}"

  # Clean build output
  echo "Cleaning ${OUTDIR}..."
  rm -rf "${OUTDIR}"

  # Try to build
  echo "Building package '${PACKAGE}'..."
  if ! make "${PACKAGE}"; then
    echo "Build failed with line ${lineno} commented. Reverting."
    sed -i "${lineno}s/^# TEMP_COMMENTED: //" "${CONTAINERFILE}"
    continue
  fi

  # Check digest matches baseline
  new_digest=$(make NOCACHE=1 "${DIGEST_TARGET}")
  if [ "${new_digest}" = "${baseline_digest}" ]; then
    echo "Build succeeded and digest unchanged for line ${lineno}."
  else
    echo "Build succeeded but digest changed for line ${lineno}. Reverting."
    sed -i "${lineno}s/^# TEMP_COMMENTED: //" "${CONTAINERFILE}"
  fi
done

echo "Done testing COPY --from lines in ${PACKAGE}."
