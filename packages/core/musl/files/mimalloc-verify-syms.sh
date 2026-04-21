#!/bin/sh
# Extract symbol list from mimalloc object for verification

OBJ="$1"

if [ -z "$OBJ" ]; then
	echo "Usage: $0 <mimalloc.o>"
	exit 1
fi

nm -g --defined-only "$OBJ" | awk '{print $3}' | grep -v '^__mi_' | grep -v '^mi_' | sort -u
