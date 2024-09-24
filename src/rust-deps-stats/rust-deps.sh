#!/bin/sh

set -eu

SCRIPTDIR="$(cd "$(dirname $0)"; pwd)"

docker build -t stagex-comparison-results -f "$SCRIPTDIR/Containerfile" "$SCRIPTDIR"
docker run --rm stagex-comparison-results cat /results-total.txt
