#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(dirname "$0")"

log() {
	echo "$@" > /dev/stderr
}

# Fetch the latest repository state
# Needed for gen-version.sh
log "Fetching latest repository state"
echo git fetch

if test "${1:-0}" = "0"; then
	RELEASE="$("$SCRIPT_DIR"/gen-version.sh)"
	echo "Using generated release version: ${RELEASE}"
fi

# Ensure we're on the `staging` branch
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if test ! "$(git rev-parse --abbrev-ref HEAD)" = "staging"; then
	log "Current branch appears to be: ${CURRENT_BRANCH}, not 'staging'"
	exit 1
fi

# Create a new branch, if it does not exist
echo git switch -c "release/$RELEASE"
