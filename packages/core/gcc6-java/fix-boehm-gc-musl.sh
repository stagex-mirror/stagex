#!/bin/sh
# Fix Boehm GC for musl libc
# Equivalent to Alpine's boehm-gc-musl.patch
set -eux
cd "$1"  # GCC source root

# 1. gcconfig.h: replace glibc version checks with unconditional 1
# This enables SEARCH_FOR_DATA_START and LINUX_STACKBOTTOM on musl
awk '{
  gsub(/defined\(__GLIBC__\) && __GLIBC__ >= 2/, "1 /* musl */")
  gsub(/defined\(__GLIBC__\)&& __GLIBC__>=2/, "1 /* musl */")
  print
}' boehm-gc/include/private/gcconfig.h > boehm-gc/include/private/gcconfig.h.tmp
mv boehm-gc/include/private/gcconfig.h.tmp boehm-gc/include/private/gcconfig.h

# 2. dyn_load.c: enable dl_iterate_phdr on non-glibc (musl has it)
# Show what the actual pattern looks like
grep -n 'GLIBC' boehm-gc/dyn_load.c | head -5
# Try multiple patterns to match
awk '{
  gsub(/__GLIBC__ > 2 \|\| \(__GLIBC__ == 2 && __GLIBC_MINOR__ >= 2\)/, "1 /* musl */")
  gsub(/__GLIBC__ > 2/, "1 /* musl-a */")
  print
}' boehm-gc/dyn_load.c > boehm-gc/dyn_load.c.tmp
mv boehm-gc/dyn_load.c.tmp boehm-gc/dyn_load.c

# 3. os_dep.c: prevent glibc-specific sigcontext.h include
# (Already handled by _ASM_X86_SIGCONTEXT_H define in Containerfile)

# Verify
echo "gcconfig.h musl fixes: $(grep -c 'musl' boehm-gc/include/private/gcconfig.h)"
echo "dyn_load.c musl fixes: $(grep -c 'musl' boehm-gc/dyn_load.c)"
