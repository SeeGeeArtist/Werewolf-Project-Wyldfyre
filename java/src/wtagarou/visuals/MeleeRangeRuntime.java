package wtagarou.visuals;

import java.util.Collections;
import java.util.Map;
import java.util.WeakHashMap;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

/** Per-character melee range multiplier, set from Lua per form (0.4.42:
 * "Hispo and lupus should have more melee attack range. 30% increased"). */
public final class MeleeRangeRuntime {
    private static final Map<Object, Float> MULT = Collections.synchronizedMap(new WeakHashMap<>());
    private static final AtomicBoolean LOGGED = new AtomicBoolean(), WARNED = new AtomicBoolean();
    public static final AtomicLong scaled = new AtomicLong();

    public static boolean set(Object character, double multiplier) {
        if (character == null || !Double.isFinite(multiplier)) return false;
        float m = (float) Math.max(0.5d, Math.min(3d, multiplier));
        if (Math.abs(m - 1f) < 1e-4f) MULT.remove(character); else MULT.put(character, m);
        return true;
    }
    public static float multiplier(Object character) {
        Float m = character == null ? null : MULT.get(character);
        return m == null ? 1f : m;
    }
    public static void clear(Object character) { if (character != null) MULT.remove(character); }

    public static float scale(Object weapon, Object character, float result) {
        float m = multiplier(character);
        if (m == 1f || !Float.isFinite(result)) return result;
        try {
            if (Boolean.TRUE.equals(Reflect.call(weapon, "isRanged"))) return result;
        } catch (Throwable t) {
            if (WARNED.compareAndSet(false, true))
                System.out.println("[WTAGarou Java] melee range adapter unavailable: " + t);
            return result;
        }
        scaled.incrementAndGet();
        if (LOGGED.compareAndSet(false, true))
            System.out.println("[WTAGarou Java][Melee] range mod " + result + " x " + m + " for wolf-form melee");
        return result * m;
    }
    public static String status() { return "melee range scaled=" + scaled.get() + "; flagged=" + MULT.size(); }
}
