#!/bin/sh
# v2
set -eu
cd /jdk8u-jdk8u412-ga

# Apply musl patches
for patch in /patches/openjdk8-*.patch; do
	[ -f "$patch" ] && patch -p1 < "$patch" || true
done

export JAVA_HOME=/usr/lib/jvm/java-7-openjdk
export PATH=${JAVA_HOME}/bin:${PATH}
export CC=/usr/bin/gcc
export CXX=/usr/bin/g++

# GCC wrapper (clang masquerading as gcc for OpenJDK 8 configure)
cat > /usr/bin/gcc <<'GCCW'
#!/bin/sh
for arg in "$@"; do
  case "$arg" in
    --version) printf "gcc (StageX) 4.9.0\nCopyright (C) 2014 Free Software Foundation, Inc.\n"; exit 0 ;;
    -dumpversion) echo "4.9.0"; exit 0 ;;
    -dumpmachine) echo "x86_64-unknown-linux-musl"; exit 0 ;;
    -dumpspecs) echo ""; exit 0 ;;
  esac
done
LINKING=1; first=1
for arg in "$@"; do
  case "$arg" in -fno-lifetime-dse|-fpch-deps|-fno-devirtualize) continue ;; -c|-E|-S) LINKING= ;; esac
  if [ "$first" = 1 ]; then set -- "$arg"; first=0; else set -- "$@" "$arg"; fi
done
[ "$first" = 1 ] && exec clang
[ -n "$LINKING" ] && set -- "$@" -Wl,--undefined-version
exec clang "$@"
GCCW
chmod +x /usr/bin/gcc

cat > /usr/bin/g++ <<'GPPW'
#!/bin/sh
for arg in "$@"; do
  case "$arg" in
    --version) printf "g++ (StageX) 4.9.0\nCopyright (C) 2014 Free Software Foundation, Inc.\n"; exit 0 ;;
    -dumpversion) echo "4.9.0"; exit 0 ;;
    -dumpmachine) echo "x86_64-unknown-linux-musl"; exit 0 ;;
    -dumpspecs) echo ""; exit 0 ;;
  esac
done
LINKING=1; first=1
for arg in "$@"; do
  case "$arg" in -fno-lifetime-dse|-fpch-deps|-fno-devirtualize) continue ;; -c|-E|-S) LINKING= ;; esac
  if [ "$first" = 1 ]; then set -- "$arg"; first=0; else set -- "$@" "$arg"; fi
done
[ "$first" = 1 ] && exec clang++
[ -n "$LINKING" ] && set -- "$@" -Wl,--undefined-version
exec clang++ "$@"
GPPW
chmod +x /usr/bin/g++
ln -sf gcc /usr/bin/cc
ln -sf g++ /usr/bin/c++

# file(1) stub
cat > /usr/bin/file <<'FILEW'
#!/bin/sh
for arg in "$@"; do
  case "$arg" in -*) continue ;; esac
  if head -c4 "$arg" 2>/dev/null | grep -q ELF; then
    echo "$arg: ELF 64-bit LSB"
  else
    echo "$arg: data"
  fi
done
FILEW
chmod +x /usr/bin/file

# zip/unzip stubs
cat > /usr/bin/zip <<'ZIPW'
#!/bin/sh
OUT=""; ARGS=""
for a in "$@"; do
  case "$a" in -[qr0-9]*) ;; -*) ;; *) if [ -z "$OUT" ]; then OUT="$a"; else ARGS="$ARGS $a"; fi ;; esac
done
[ -n "$OUT" ] && [ -n "$ARGS" ] && { [ -f "$OUT" ] && fastjar uf "$OUT" $ARGS 2>/dev/null || fastjar cf "$OUT" $ARGS 2>/dev/null; }
exit 0
ZIPW
chmod +x /usr/bin/zip
if ! command -v unzip >/dev/null 2>&1; then
  cat > /usr/bin/unzip <<'UZW'
#!/bin/sh
for a in "$@"; do case "$a" in -*);; *) [ -f "$a" ] && fastjar xf "$a" 2>/dev/null; break ;; esac; done
UZW
  chmod +x /usr/bin/unzip
fi

# Stub headers for CUPS, ALSA, fontconfig
mkdir -p /usr/include/cups /usr/include/alsa /usr/include/fontconfig
echo 'typedef int cups_dest_t;' > /usr/include/cups/cups.h
echo 'typedef int ppd_file_t;' > /usr/include/cups/ppd.h
printf '#ifndef __ALSA_H\n#define __ALSA_H\ntypedef unsigned long snd_pcm_uframes_t;\n#endif\n' > /usr/include/alsa/asoundlib.h
printf '#ifndef _FC_H\n#define _FC_H\ntypedef int FcBool;\n#endif\n' > /usr/include/fontconfig/fontconfig.h

# Test boot JDK
echo "=== Testing java ==="
$JAVA_HOME/bin/java -version 2>&1 || echo "java -version FAILED"
echo "=== Testing javac ==="
echo 'class T {}' > /tmp/T.java
$JAVA_HOME/bin/javac /tmp/T.java 2>&1 && echo "javac OK" || echo "javac FAILED"
echo "=== Testing java runtime ==="
$JAVA_HOME/bin/java -cp /tmp T 2>&1 && echo "java runtime OK" || echo "java runtime FAILED (expected with JamVM)"

# Configure
bash configure \
	--with-boot-jdk=${JAVA_HOME} \
	--with-jvm-variants=server \
	--with-debug-level=release \
	--with-extra-cflags="-fPIC -Wno-error -Wno-deprecated" \
	--with-extra-cxxflags="-fPIC -Wno-error -Wno-deprecated" \
	--with-extra-ldflags="-Wl,--undefined-version" \
	--with-zlib=system \
	--with-giflib=bundled \
	--with-freetype-include=/usr/include \
	--with-freetype-lib=/usr/lib \
	--disable-headful \
	--with-x=/no/x11

echo "=== Configure complete ==="
