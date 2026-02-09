#!/bin/sh
set -e

if [ "${1:-}" = "--worker" ]; then
    line="${2?}"
    hash="${line%% *}"
    package="${line#* }"
    ref="stagex/${package}@sha256:${hash}"
    docker pull "${ref}"
    rm -rf "out/${package}"
    mkdir -p "out/${package}"
    docker save "${ref}" | tar -xC "out/${package}"
    exit 0
fi

set -u
date="$(date '+%F %T')"
cat digests/* | xargs -I {} -P $(nproc) "$0" --worker "{}"
find out -type f -exec touch -d "$date" {} +
