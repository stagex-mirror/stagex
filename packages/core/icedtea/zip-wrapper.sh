#!/bin/sh
# Translate zip flags to fastjar
# Usage: zip [flags] output.zip dir1 dir2 ...
OUTFILE=""
ARGS=""
for arg in "$@"; do
  case "$arg" in
    -*) ;; # skip flags like -q -r -9 etc
    *) if [ -z "$OUTFILE" ]; then OUTFILE="$arg"; else ARGS="$ARGS $arg"; fi ;;
  esac
done
if [ -z "$OUTFILE" ]; then exit 0; fi
if [ -f "$OUTFILE" ]; then
  fastjar uf "$OUTFILE" $ARGS 2>/dev/null || true
else
  fastjar cf "$OUTFILE" $ARGS 2>/dev/null || true
fi
