#!/bin/sh
# Bootstrap javah — generates stub JNI headers from class names
# Real javah reads .class files; this just creates headers with #include <jni.h>
OUTDIR="" OUTFILE="" CLASSES="" SKIP=""
for arg in "$@"; do
  if [ -n "$SKIP" ]; then SKIP=""; continue; fi
  case "$arg" in
    -d) SKIP=d; shift; OUTDIR="$2" ;;
    -o) SKIP=o; shift; OUTFILE="$2" ;;
    -classpath|-cp|-bootclasspath) SKIP=1 ;;
    -jni|-force|-v|-verbose) ;;
    -*) ;;
    *) CLASSES="$CLASSES $arg" ;;
  esac
done
# Re-parse to get -d/-o values correctly (positional)
OUTDIR="" OUTFILE=""
PREV=""
for arg in "$@"; do
  case "$PREV" in
    -d) OUTDIR="$arg" ;;
    -o) OUTFILE="$arg" ;;
  esac
  PREV="$arg"
done
# Collect class names (non-flag args)
CLASSES=""
PREV=""
for arg in "$@"; do
  case "$PREV" in -d|-o|-classpath|-cp|-bootclasspath) PREV="$arg"; continue ;; esac
  case "$arg" in -*) ;; *) CLASSES="$CLASSES $arg" ;; esac
  PREV="$arg"
done
for cls in $CLASSES; do
  # Convert java.security.AccessController -> java_security_AccessController
  hname=$(echo "$cls" | sed 's/\./_/g')
  if [ -n "$OUTFILE" ]; then
    dest="$OUTFILE"
  elif [ -n "$OUTDIR" ]; then
    dest="$OUTDIR/${hname}.h"
  else
    dest="${hname}.h"
  fi
  mkdir -p "$(dirname "$dest")"
  cat > "$dest" <<HEOF
/* DO NOT EDIT - bootstrap javah stub for $cls */
#include <jni.h>
HEOF
done
