package zombie.entity.components.fluids;
import java.util.HashMap;
/** Test stub: the vanilla Fluid registry shape NitrateHeatRuntime reflects on (static Get(String)). */
public final class Fluid {
    private static final HashMap<String, Fluid> byName = new HashMap<>();
    public final String name;
    private Fluid(String name) { this.name = name; }
    public static Fluid Get(String name) { return byName.get(name); }
    public static Fluid define(String name) { return byName.computeIfAbsent(name, Fluid::new); }
    public static void reset() { byName.clear(); }
    @Override public String toString() { return name; }
}
