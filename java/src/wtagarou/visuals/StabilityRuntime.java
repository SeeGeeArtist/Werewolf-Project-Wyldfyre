package wtagarou.visuals;

import java.util.Collections;
import java.util.Map;
import java.util.WeakHashMap;
import java.util.concurrent.ThreadLocalRandom;

/**
 * Mass-based knockdown resistance. Lua registers a per-character chance
 * (0..1) that a knockdown or bump-fall is shrugged off; the two engine
 * setters below are the single funnel for zombie hits, crawler lunges,
 * sprint trips and drunk stumbles (IsoGameCharacter.setKnockedDown /
 * setBumpFall). Staggers and hit reactions are untouched: only the FALL is
 * refused, so a Crinos still flinches but stays on its feet.
 */
public final class StabilityRuntime {
    private static final Map<Object, Float> STABILITY =
            Collections.synchronizedMap(new WeakHashMap<>());
    public static volatile long refused, allowed;
    private static boolean logged;

    public static boolean set(Object character, double chance) {
        if (character == null || !Double.isFinite(chance)) return false;
        if (chance <= 0) { STABILITY.remove(character); return true; }
        STABILITY.put(character, (float) Math.min(1.0, chance));
        return true;
    }
    public static void clear(Object character) { if (character != null) STABILITY.remove(character); }
    public static void clearAll() { STABILITY.clear(); }
    public static float chanceFor(Object character) {
        Float value = character == null ? null : STABILITY.get(character);
        return value == null ? 0f : value;
    }

    /** Returns the value the engine should actually store. */
    public static boolean filter(Object character, boolean falling, String kind) {
        if (!falling) return false;
        float chance = chanceFor(character);
        if (chance <= 0f) { StealthRuntime.onFall(character); return true; }
        boolean refuse = chance >= 1f || ThreadLocalRandom.current().nextFloat() < chance;
        if (refuse) {
            refused++;
            if (!logged) {
                logged = true;
                System.out.println("[WTAGarou Java] stability refused a " + kind + " (chance=" + chance + ")");
            }
            return false;
        }
        allowed++;
        StealthRuntime.onFall(character);
        return true;
    }
    public static String status() {
        return "stability registered=" + STABILITY.size() + "; falls refused=" + refused + "; allowed=" + allowed;
    }
}
