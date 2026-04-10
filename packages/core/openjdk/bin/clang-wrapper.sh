#!/bin/sh
# Thin clang wrapper that strips GCC-only flags baked into spec.gmk by configure.
# No path inspection — the compiler split handles routing explicitly.
LINKING=1; first=1
for arg in "$@"; do
  case "$arg" in
    -fno-lifetime-dse|-fpch-deps|-fno-devirtualize|-fno-strict-overflow) continue ;;
    -c|-E|-S) LINKING= ;;
  esac
  if [ "$first" = 1 ]; then set -- "$arg"; first=0; else set -- "$@" "$arg"; fi
done
[ "$first" = 1 ] && exec clang
WFLAGS="-Wno-error -Wno-implicit-function-declaration -Wno-int-conversion -Wno-incompatible-pointer-types"
[ -n "$LINKING" ] && set -- "$@" -Wl,--undefined-version -Wl,--allow-multiple-definition
exec clang $WFLAGS "$@"
