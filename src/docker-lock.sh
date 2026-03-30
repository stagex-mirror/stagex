#!/bin/sh
LOCKFILE=/tmp/stagex-build.lock
exec 200>"$LOCKFILE"
flock -x 200
exec "$@"
