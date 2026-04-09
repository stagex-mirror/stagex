import org.apache.tools.ant.Task;
public class GenStubs extends Task {
  public static class Ant extends Task {
    public void setFork(boolean f) {}
    public void setClasspath(String cp) {}
    public void setSourcefiles(String sf) {}
    public void setDir(java.io.File d) {}
    public void setIncludes(String i) {}
    public void setSrcdir(java.io.File d) {}
    public void setDestdir(java.io.File d) {}
    public void execute() { log("genstubs skipped (bootstrap)"); }
  }
  public void setFork(boolean f) {}
  public void setClasspath(String cp) {}
  public void setSrcdir(java.io.File d) {}
  public void setDestdir(java.io.File d) {}
  public void setIncludes(String i) {}
  public void execute() { log("genstubs skipped"); }
}
