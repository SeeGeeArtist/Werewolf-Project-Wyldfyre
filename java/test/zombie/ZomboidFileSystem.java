package zombie;
import java.io.File;

/** Resolves the actual packaged files for the read-only diagnostic test. */
public class ZomboidFileSystem {
    public static final ZomboidFileSystem instance=new ZomboidFileSystem();
    public boolean missing;
    public java.util.List<String> modIDs=new java.util.ArrayList<>(java.util.List.of("WTAGarou"));
    public java.util.List<String> getModIDs() { return modIDs; }
    public String getString(String path) {
        if (missing) return new File(System.getProperty("wtagarou.test.root"),"MISSING/"+path).getPath();
        return new File(System.getProperty("wtagarou.test.root"),"common/"+path).getPath();
    }
}
