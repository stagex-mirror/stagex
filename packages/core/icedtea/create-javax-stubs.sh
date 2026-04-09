#!/bin/sh
# Create javax.tools stubs (Java 6 API not in Classpath 0.99)
set -eux
ECJ="$1"
BOOTCP="$2"

mkdir -p /tmp/javax-stubs/javax/tools

cat > /tmp/javax-stubs/javax/tools/FileObject.java <<'EOF'
package javax.tools;
public interface FileObject {
  java.net.URI toUri();
  String getName();
}
EOF

cat > /tmp/javax-stubs/javax/tools/JavaFileObject.java <<'EOF'
package javax.tools;
public interface JavaFileObject extends FileObject {
  enum Kind { SOURCE, CLASS, HTML, OTHER }
  Kind getKind();
}
EOF

cat > /tmp/javax-stubs/javax/tools/JavaFileManager.java <<'EOF'
package javax.tools;
public interface JavaFileManager {
  interface Location {}
}
EOF

cat > /tmp/javax-stubs/javax/tools/StandardJavaFileManager.java <<'EOF'
package javax.tools;
public interface StandardJavaFileManager extends JavaFileManager {}
EOF

cat > /tmp/javax-stubs/javax/tools/StandardLocation.java <<'EOF'
package javax.tools;
public enum StandardLocation implements JavaFileManager.Location {
  CLASS_OUTPUT, SOURCE_OUTPUT, CLASS_PATH, SOURCE_PATH,
  ANNOTATION_PROCESSOR_PATH, PLATFORM_CLASS_PATH
}
EOF

cat > /tmp/javax-stubs/javax/tools/DiagnosticListener.java <<'EOF'
package javax.tools;
public interface DiagnosticListener<S> { void report(Object d); }
EOF

cat > /tmp/javax-stubs/javax/tools/JavaCompiler.java <<'EOF'
package javax.tools;
public interface JavaCompiler { interface CompilationTask {} }
EOF

cat > /tmp/javax-stubs/javax/tools/ToolProvider.java <<'EOF'
package javax.tools;
public class ToolProvider { public static JavaCompiler getSystemJavaCompiler() { return null; } }
EOF

cat > /tmp/javax-stubs/javax/tools/Diagnostic.java <<'EOF'
package javax.tools;
public interface Diagnostic<S> { enum Kind { ERROR, WARNING, MANDATORY_WARNING, NOTE, OTHER } }
EOF

mkdir -p /tmp/javax-stubs-classes
$ECJ -source 1.5 -target 1.5 \
  -bootclasspath "$BOOTCP" \
  -d /tmp/javax-stubs-classes \
  /tmp/javax-stubs/javax/tools/*.java

cd /tmp/javax-stubs-classes
fastjar cf /usr/share/classpath/javax-tools-stubs.jar javax
# Also inject directly into glibj.zip so any bootclasspath works
fastjar uf "$BOOTCP" javax 2>/dev/null || true
echo "javax.tools stubs created: $(find /tmp/javax-stubs-classes -name '*.class' | wc -l) classes"
