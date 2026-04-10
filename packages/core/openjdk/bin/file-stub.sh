#!/bin/sh
for arg in "$@"; do
  case "$arg" in -*) continue ;; esac
  if head -c4 "$arg" 2>/dev/null | grep -q ELF; then echo "$arg: ELF 64-bit LSB"
  else echo "$arg: data"; fi
done
