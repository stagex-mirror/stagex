package genstubs;

import java.io.*;

/**
 * No-op GenStubs replacement for bootstrap builds.
 * Creates minimal stub files for JDK classes that langtools needs.
 * The real GenStubs uses javac API which may not work during bootstrap.
 */
public class GenStubs {
    public static void main(String[] args) throws Exception {
        String stubsDir = null;
        String sourcePath = null;
        int i = 0;
        while (i < args.length) {
            if ("-s".equals(args[i]) && i + 1 < args.length) {
                stubsDir = args[++i];
            } else if ("-sourcepath".equals(args[i]) && i + 1 < args.length) {
                sourcePath = args[++i];
            } else if (!args[i].startsWith("-")) {
                // Class name to stub
                if (stubsDir != null) {
                    createStub(stubsDir, sourcePath, args[i]);
                }
            }
            i++;
        }
    }

    static void createStub(String stubsDir, String sourcePath, String className) throws Exception {
        // Try to copy from source path first
        if (sourcePath != null) {
            String relPath = className.replace('.', '/') + ".java";
            String[] paths = sourcePath.split(":");
            for (String sp : paths) {
                File src = new File(sp, relPath);
                if (src.exists()) {
                    File dst = new File(stubsDir, relPath);
                    dst.getParentFile().mkdirs();
                    copyFile(src, dst);
                    return;
                }
            }
        }
        // Generate minimal stub
        String relPath = className.replace('.', '/') + ".java";
        File dst = new File(stubsDir, relPath);
        dst.getParentFile().mkdirs();
        int lastDot = className.lastIndexOf('.');
        String pkg = lastDot > 0 ? className.substring(0, lastDot) : "";
        String name = lastDot > 0 ? className.substring(lastDot + 1) : className;
        PrintWriter pw = new PrintWriter(new FileWriter(dst));
        if (pkg.length() > 0) pw.println("package " + pkg + ";");
        pw.println("public class " + name + " {}");
        pw.close();
    }

    static void copyFile(File src, File dst) throws Exception {
        FileInputStream fis = new FileInputStream(src);
        FileOutputStream fos = new FileOutputStream(dst);
        byte[] buf = new byte[8192];
        int n;
        while ((n = fis.read(buf)) > 0) fos.write(buf, 0, n);
        fis.close();
        fos.close();
    }
}
