#!/bin/sh
HOTSPOT="/usr/lib/jvm/java-bootstrap/bin/java.hotspot"
first=1
for arg in "$@"; do
  case "$arg" in
    -d32|-d64) continue ;;
  esac
  if [ "$first" = 1 ]; then set -- "$arg"; first=0; else set -- "$@" "$arg"; fi
done
[ "$first" = 1 ] && set --
exec "$HOTSPOT" "$@"
