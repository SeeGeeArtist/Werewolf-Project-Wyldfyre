package wtagarou.visuals;

import java.util.Collections;
import java.util.Map;
import java.util.WeakHashMap;
import java.util.concurrent.atomic.AtomicBoolean;

/** 0.4.58 (Wits W4): remembers which body part the engine actually wounded
 * with a weapon so Lua can burn that wound instead of a second random part.
 *
 * OnWeaponHitCharacter fires BEFORE BodyDamage.DamageFromWeapon picks the
 * part, so Lua defers one tick and then asks {@link #take}. A hit the
 * clothing absorbed never reaches applyDamageFromWeapon, leaves no record,
 * and therefore (by design) burns nothing: silver burns wounds, not coats.
 *
 * Records are per victim, overwrite each other, and expire; the engine's own
 * random part choice is never changed. */
public final class SilverHitRuntime {
    private static final Map<Object, long[]> HITS =
            Collections.synchronizedMap(new WeakHashMap<>());
    private static final AtomicBoolean WARNED = new AtomicBoolean();
    public static volatile boolean observed;

    /** Called from the BodyDamage.applyDamageFromWeapon advice. */
    public static void record(Object bodyDamage, int partIndex) {
        if (bodyDamage == null || partIndex < 0) return;
        try {
            Object character = Reflect.call(bodyDamage, "getParentChar");
            if (character == null) return;
            HITS.put(character, new long[]{partIndex, System.nanoTime()});
            observed = true;
        } catch (ReflectiveOperationException | RuntimeException error) {
            if (WARNED.compareAndSet(false, true))
                System.out.println("[WTAGarou Java] weapon-hit recorder unavailable: " + error);
        }
    }

    /** Returns and clears the recorded part index for this victim, or -1 when
     * nothing was recorded within maxAgeMillis. */
    public static int take(Object character, double maxAgeMillis) {
        if (character == null) return -1;
        long[] hit = HITS.remove(character);
        if (hit == null) return -1;
        double ageMillis = (System.nanoTime() - hit[1]) / 1_000_000.0;
        return ageMillis <= maxAgeMillis ? (int) hit[0] : -1;
    }

    public static void clearAll() { HITS.clear(); }
    public static int pending() { return HITS.size(); }
}
