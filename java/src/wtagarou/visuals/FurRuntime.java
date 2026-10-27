package wtagarou.visuals;

import java.util.Collections;
import java.util.Map;
import java.util.WeakHashMap;

/** Natural fur floor applied after native clothing calculation on every
 * thermal node. Native calculation resets insulation each tick, so this
 * cannot accumulate; removing the profile restores vanilla next tick. */
public final class FurRuntime {
    private static final Map<Object, Float> FLOORS =
            Collections.synchronizedMap(new WeakHashMap<>());
    public static long failures;

    public static boolean set(Object character, double floor) {
        if (character == null || !Double.isFinite(floor) || floor < 0 || floor > 1) return false;
        if (floor == 0) FLOORS.remove(character);
        else FLOORS.put(character, (float)floor);
        return true;
    }
    public static void clear(Object character) { FLOORS.remove(character); }
    public static void clearAll() { FLOORS.clear(); }
    public static void afterInsulation(Object node) {
        if (node == null || FLOORS.isEmpty()) return;
        try {
            Object part = Reflect.get(node, "bodyPart");
            Object character = Reflect.call(part, "getParentChar");
            Float floor = FLOORS.get(character);
            if (floor == null || Boolean.TRUE.equals(Reflect.call(character, "isDead"))) return;
            float multiplier = ((Number)Reflect.get(node, "insulationLayerMultiplierUi")).floatValue();
            float nativeValue = ((Number)Reflect.get(node, "insulation")).floatValue();
            // Engine UI: clamp(insulation * insulationLayerMultiplierUi, 0, 1).
            if (Float.isFinite(multiplier) && multiplier > 0 && Float.isFinite(nativeValue)) {
                Reflect.set(node, "insulation", Math.max(nativeValue, floor / multiplier));
            }
        } catch (Throwable failure) {
            if (failures++ == 0) System.err.println("[WTAGarou][Fur] insulation hook failed: " + failure);
        }
    }
}
