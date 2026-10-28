import java.util.List;
import java.util.TreeSet;

/** 0.4.98: Main must preload every @Patch target before ZombieBuddy installs
 * the patches (see Main.java). The jar scan and the fallback list must agree. */
public final class PatchTargetsTest {
    public static void main(String[] args) throws Exception {
        java.lang.reflect.Method scan = Class.forName("wtagarou.visuals.Main").getDeclaredMethod("patchTargets");
        scan.setAccessible(true);
        @SuppressWarnings("unchecked") TreeSet<String> scanned = (TreeSet<String>) scan.invoke(null);
        java.lang.reflect.Field field = Class.forName("wtagarou.visuals.Main").getDeclaredField("PATCH_TARGETS");
        field.setAccessible(true);
        TreeSet<String> listed = new TreeSet<>(List.of((String[]) field.get(null)));
        if (!scanned.equals(listed)) {
            TreeSet<String> onlyScanned = new TreeSet<>(scanned); onlyScanned.removeAll(listed);
            TreeSet<String> onlyListed = new TreeSet<>(listed); onlyListed.removeAll(scanned);
            throw new AssertionError("PATCH_TARGETS out of date; add " + onlyScanned + " remove " + onlyListed);
        }
        if (scanned.size() < 30) throw new AssertionError("suspiciously few patch targets: " + scanned.size());
        for (String n : new String[]{"zombie.core.skinnedmodel.ModelManager", "zombie.core.skinnedmodel.visual.HumanVisual",
                "zombie.core.skinnedmodel.animation.AnimationPlayer"})
            if (!scanned.contains(n)) throw new AssertionError("missing target " + n);

        java.lang.reflect.Method pre = Class.forName("wtagarou.visuals.Main").getDeclaredMethod("preloadPatchTargets", Iterable.class);
        pre.setAccessible(true);
        @SuppressWarnings("unchecked") List<String> missing = (List<String>) pre.invoke(null, scanned);
        // No engine on the test classpath: every target is reported missing, nothing throws.
        if (missing.size() != scanned.size()) {
            TreeSet<String> loaded = new TreeSet<>(scanned); loaded.removeAll(missing);
            System.out.println("note: targets resolvable from stubs: " + loaded);
        }
        @SuppressWarnings("unchecked") List<String> none = (List<String>) pre.invoke(null, List.of("java.lang.String"));
        if (!none.isEmpty()) throw new AssertionError("String should preload");
        System.out.println("PatchTargetsTest: " + scanned.size() + " targets, scan == list, preload tolerant: OK");
    }
}
