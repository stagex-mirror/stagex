#!/bin/sh
set -eux
CPU=$1
JVMDIR=/rootfs/usr/lib/jvm/java-1.5-gcj
mkdir -p $JVMDIR/bin $JVMDIR/lib $JVMDIR/jre/bin $JVMDIR/jre/lib/$CPU
mkdir -p $JVMDIR/include

mkdir -p /rootfs/usr/bin /rootfs/usr/lib /rootfs/usr/libexec /rootfs/usr/share/java

# Create classmap.db — maps Java class names to native implementations in libgcj.so
# Without this, gij-6 can't find native methods when running bytecode classes
DBDIR=/rootfs/usr/lib/gcj-6.4.0-6
mkdir -p $DBDIR
gcj-dbtool-6 -n $DBDIR/classmap.db
gcj-dbtool-6 -a $DBDIR/classmap.db /usr/share/java/libgcj-6.4.0.jar /usr/lib/libgcj.so.17
gcj-dbtool-6 -a $DBDIR/classmap.db /usr/share/java/libgcj-tools-6.4.0.jar /usr/lib/libgcj-tools.so.17
echo "classmap.db created with $(gcj-dbtool-6 -l $DBDIR/classmap.db | wc -l) entries"
cp -a /usr/bin/*-6 /rootfs/usr/bin/ 2>/dev/null || true
# Copy GCC 6 runtime libraries needed by gcj binaries
cp -a /usr/lib/libgcc_s.so* /rootfs/usr/lib/ 2>/dev/null || true
cp -a /usr/lib/libstdc++.so* /rootfs/usr/lib/ 2>/dev/null || true
cp -a /usr/lib/gcc /rootfs/usr/lib/ 2>/dev/null || true
cp -a /usr/libexec/gcc /rootfs/usr/libexec/ 2>/dev/null || true
cp -a /usr/lib/libgcj* /rootfs/usr/lib/ 2>/dev/null || true
cp -a /usr/lib/libgij* /rootfs/usr/lib/ 2>/dev/null || true
cp -a /usr/lib/security /rootfs/usr/lib/ 2>/dev/null || true
cp -a /usr/lib/logging.properties /rootfs/usr/lib/ 2>/dev/null || true
cp -a /usr/share/java /rootfs/usr/share/ 2>/dev/null || true

# Copy version-specific runtime libs to /usr/lib/ (needed for dynamic linker)
GCJLIBDIR=$(find /usr/lib/gcc -name '6.4.0' -type d | head -1)
if [ -n "$GCJLIBDIR" ]; then
  for lib in $GCJLIBDIR/libgcj*.so* $GCJLIBDIR/libgij*.so*; do
    [ -f "$lib" ] && cp -a "$lib" /rootfs/usr/lib/
  done
  # Also copy the jar files
  for jar in $GCJLIBDIR/*.jar; do
    [ -f "$jar" ] && cp -a "$jar" /rootfs/usr/share/java/ 2>/dev/null || true
  done
fi

gcj-6 -Wl,-Bsymbolic -findirect-dispatch \
  -o $JVMDIR/bin/ecj \
  --main=org.eclipse.jdt.internal.compiler.batch.Main \
  /ecj-4.9.jar -lgcj

# Symlinks use final paths (without /rootfs prefix)
JVMFINAL=/usr/lib/jvm/java-1.5-gcj
ln -sf /usr/bin/gij-6 $JVMDIR/bin/java
# javac wrapper: native ECJ needs -bootclasspath to find rt.jar
cat > $JVMDIR/bin/javac <<JAVACW
#!/bin/sh
exec $JVMFINAL/bin/ecj -bootclasspath $JVMFINAL/jre/lib/rt.jar "\$@"
JAVACW
chmod +x $JVMDIR/bin/javac
ln -sf /usr/bin/gjavah-6 $JVMDIR/bin/javah
ln -sf /usr/bin/grmic-6 $JVMDIR/bin/rmic
ln -sf /usr/bin/gjar-6 $JVMDIR/bin/jar
ln -sf /usr/bin/gkeytool-6 $JVMDIR/bin/keytool
ln -sf /usr/bin/gnative2ascii-6 $JVMDIR/bin/native2ascii
ln -sf /usr/bin/gij-6 $JVMDIR/jre/bin/java

GCJJAR=$(find /usr -name 'libgcj-6.4.0.jar' -path '*/share/java/*' | head -1)
[ -n "$GCJJAR" ] && cp "$GCJJAR" $JVMDIR/jre/lib/rt.jar
TOOLSJAR=$(find /usr -name 'libgcj-tools-6.4.0.jar' | head -1)
[ -n "$TOOLSJAR" ] && cp "$TOOLSJAR" $JVMDIR/lib/tools.jar
LIBJVM=$(find /usr -name 'libjvm.so' | head -1)
[ -n "$LIBJVM" ] && cp "$LIBJVM" $JVMDIR/jre/lib/$CPU/libjvm.so

for h in jni.h jni_md.h jawt.h jawt_md.h; do
  HEADER=$(find /usr -name "$h" -path '*/include/*' | head -1)
  [ -n "$HEADER" ] && cp "$HEADER" $JVMDIR/include/
done

mkdir -p /rootfs/usr/bin
for tool in java javac javah rmic jar keytool native2ascii; do
  ln -sf $JVMFINAL/bin/$tool /rootfs/usr/bin/$tool
done
