#!/bin/sh
JDKHOME=/usr/lib/jvm/java-bootstrap
HOTSPOT="$JDKHOME/bin/java.hotspot"
TOOLSJAR="$JDKHOME/lib/tools.jar"
# Strip flags unsupported by javac 7; check for -bootclasspath
HAS_BCP=0
first=1
for a in "$@"; do
  case "$a" in
    -J*|-Werror) continue ;;
    -bootclasspath) HAS_BCP=1 ;;
  esac
  if [ "$first" = 1 ]; then set -- "$a"; first=0; else set -- "$@" "$a"; fi
done
[ "$first" = 1 ] && set --
# Force compilation bootclasspath to only rt.jar — prevents javac's own
# internal classes (Token, Scanner etc.) from shadowing OpenJDK 8 sources
if [ "$HAS_BCP" = 0 ]; then
  BCP="$JDKHOME/jre/lib/rt.jar"
  [ -f "$JDKHOME/jre/lib/jaxp.jar" ] && BCP="$BCP:$JDKHOME/jre/lib/jaxp.jar"
  set -- -bootclasspath "$BCP" "$@"
fi
LD_LIBRARY_PATH="$JDKHOME/jre/lib/amd64:$JDKHOME/jre/lib/amd64/server:${LD_LIBRARY_PATH:-}" \
  exec "$HOTSPOT" -Xmx2g -Xbootclasspath/p:"$TOOLSJAR" com.sun.tools.javac.Main "$@"
