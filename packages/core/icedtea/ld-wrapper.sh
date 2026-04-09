#!/bin/sh
# Fix version scripts with named versions for LLD compatibility
for arg in "$@"; do
  case "$arg" in
    --version-script=*)
      VSFILE="${arg#--version-script=}"
      [ -f "$VSFILE" ] && sed -i 's/^SUNWprivate_[0-9.]* {/{/' "$VSFILE"
      ;;
  esac
done
exec /usr/bin/ld.lld.real "$@"
