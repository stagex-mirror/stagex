#!/bin/sh
set -e

if [ "${1:-}" = "--worker" ]; then
    platform="${2}"
    line="${3?}"
    hash="${line%% *}"
    package="${line#* }"
    ref="stagex/${package}@sha256:${hash}"
    if [ -n "$platform" ]; then
        docker pull --platform "$platform" "${ref}"
    else
        docker pull "${ref}"
    fi
    rm -rf "out/${package}"
    mkdir -p "out/${package}"
    docker save "${ref}" | tar -xC "out/${package}"
    exit 0
fi

set -u
PLATFORM_ARG=""
if [ "${1:-}" = "--platform" ]; then
    PLATFORM_ARG="${2?}"
    shift 2
fi
date="$(date '+%F %T')"
cat digests/* | xargs -I {} -P $(nproc) "$0" --worker "$PLATFORM_ARG" "{}"
find out -type f -exec touch -d "$date" {} +