import java.util.*;
public class jvmtiGen {
    public static void main(String[] args) throws Exception {
        String in = null, xsl = null, out = null;
        List<String> params = new ArrayList<String>();
        for (int i = 0; i < args.length; i++) {
            if (args[i].equals("-IN")) in = args[++i];
            else if (args[i].equals("-XSL")) xsl = args[++i];
            else if (args[i].equals("-OUT")) out = args[++i];
            else if (args[i].equals("-PARAM")) {
                // xsltproc expects param values to be XPath expressions; quote string literals
                String key = args[++i];
                String val = args[++i];
                params.add("--stringparam"); params.add(key); params.add(val);
            }
        }
        if (in == null || xsl == null || out == null) {
            System.err.println("usage: jvmtiGen -IN file -XSL file -OUT file [-PARAM key val]...");
            System.exit(1);
        }
        List<String> cmd = new ArrayList<String>();
        cmd.add("xsltproc"); cmd.add("--xinclude");
        cmd.addAll(params);
        cmd.add("-o"); cmd.add(out);
        cmd.add(xsl); cmd.add(in);
        Process p = new ProcessBuilder(cmd).inheritIO().start();
        System.exit(p.waitFor());
    }
}
