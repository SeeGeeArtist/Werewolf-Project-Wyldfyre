package wtagarou.visuals;

import java.util.Collections;
import java.util.Map;
import java.util.WeakHashMap;

/**
 * 0.4.72: per-form health pool, expressed as a damage-intake factor.
 *
 * <p>Vanilla overall health is derived every update from the body parts
 * ({@code BodyDamage.calculateOverallHealth}: 100 minus the weighted part
 * damage), and death is decided from that, so a bigger pool cannot be a
 * bigger number. Instead every ACUTE hit is scaled before it reaches a
 * part: {@code BodyPart.AddDamage(float)} is the funnel for weapon and
 * bullet hits ({@code BodyDamage.applyDamageFromWeapon}), zombie bites /
 * scratches / lacerations, falls, vehicle impacts and sleeping events.
 * Ongoing damage ({@code ReduceHealth} direct: bleeding, deep wounds,
 * infection, hunger) is untouched, so a mauled Crinos still bleeds out at
 * the human rate and still needs bandages.
 *
 * <p>Factor 0.4 = an effective 250-point pool against hits. A point-blank
 * shotgun on a player is roughly 5 pellets x Rand(2, 2.5) x 15 with head /
 * neck x4 and upper torso x2 (B42.20.2 DamageFromWeapon), about 235 on
 * average: a healthy Crinos survives the average blast with little left and
 * still dies to two head pellets.
 *
 * <p>Players own their own BodyDamage in multiplayer, so this runs on the
 * struck player's client; Lua registers the local player's form.
 */
public final class ToughnessRuntime {
    private static final Map<Object, Float> INTAKE = Collections.synchronizedMap(new WeakHashMap<>());
    public static volatile long scaled, passed;
    public static volatile float lastRaw, lastScaled;
    private static boolean logged;

    private ToughnessRuntime() {}

    /** factor in (0, 1]: fraction of each hit that lands. 1 or less-than-or-equal 0 clears. */
    public static boolean set(Object character, double factor) {
        if (character == null || !Double.isFinite(factor)) return false;
        if (factor <= 0 || factor >= 1.0) { INTAKE.remove(character); return true; }
        INTAKE.put(character, (float) factor);
        return true;
    }
    public static void clear(Object character) { if (character != null) INTAKE.remove(character); }
    public static void clearAll() { INTAKE.clear(); }
    public static float factorFor(Object character) {
        Float v = character == null ? null : INTAKE.get(character);
        return v == null ? 1f : v;
    }

    /** The value BodyPart.AddDamage should apply. */
    public static float scale(Object bodyPart, float val) {
        if (bodyPart == null || !(val > 0f)) return val;
        Object character = null;
        try { character = Reflect.get(bodyPart, "parentChar"); }
        catch (ReflectiveOperationException | RuntimeException e) { return val; }
        float factor = factorFor(character);
        if (factor >= 1f) { passed++; return val; }
        float out = val * factor;
        scaled++; lastRaw = val; lastScaled = out;
        if (!logged) {
            logged = true;
            System.out.println("[WTAGarou Java] first scaled hit: " + val + " -> " + out + " (intake " + factor + ")");
        }
        return out;
    }

    public static String status() {
        return "toughness: " + INTAKE.size() + " flagged, hits scaled=" + scaled + " passed=" + passed
                + (scaled > 0 ? " last " + lastRaw + "->" + lastScaled : "");
    }
}
