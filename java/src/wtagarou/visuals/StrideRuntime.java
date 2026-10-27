package wtagarou.visuals;

import java.util.Collections;
import java.util.Map;
import java.util.Set;
import java.util.WeakHashMap;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

/** 0.4.60: root-motion stride scale for the scaled bipeds (Glabro, Crinos).
 *
 * Player locomotion is animation root motion: AnimationPlayer accumulates the
 * deferred-movement bone's translation and IsoPlayer.getDeferredMovement(Vector2,
 * boolean) hands it to doDeferredMovement every frame (B42.20.2; vanilla's own
 * invisible-sprint cheat scales the same vector there). Drawing the model
 * 1.44x bigger stretches the visible stride 1.44x but leaves that translation
 * alone, so the feet slide. Scaling the vector by the model scale makes the
 * ground covered match the stride again. WalkSpeed/RunSpeed (TraitsRuntime)
 * still set the cadence, so net speed = cadence x stride.
 *
 * Only locomotion states are scaled: climbs, falls, get-ups, hit reactions,
 * attacks, emotes and seated poses keep vanilla root motion, because their
 * authored translation has to land on world geometry. */
public final class StrideRuntime {
    private static final Map<Object, Float> FACTOR = Collections.synchronizedMap(new WeakHashMap<>());
    private static final AtomicBoolean WARNED = new AtomicBoolean();
    public static final AtomicLong scaled = new AtomicLong(), skipped = new AtomicLong();
    /** One console line per locomotion state the first time it is scaled. */
    static final Set<String> LOGGED_STATES = java.util.concurrent.ConcurrentHashMap.newKeySet();
    /** AI states whose root motion is plain walking/running. 0.4.69: B42.20.2
     *  registers the player's "movement"/"run"/"sprint" states as
     *  zombie.ai.states.player.PlayerMovementState; PlayerActionsState is only
     *  the "actions" state now, so without this entry an ordinary walk, jog or
     *  sprint was never scaled (only strafing while aiming was), which is the
     *  Crinos foot slide seen in the 0.4.68 playtest. */
    static final Set<String> LOCOMOTION = Set.of("PlayerMovementState", "PlayerActionsState", "PlayerStrafeState",
            "PlayerAimState", "PathFindState", "WalkTowardState", "PlayerDraggingCorpse");

    public static boolean set(Object character, double factor) {
        if (character == null || !Double.isFinite(factor)) return false;
        float f = (float) Math.max(0.5d, Math.min(2.5d, factor));
        if (Math.abs(f - 1f) < 1e-4f) FACTOR.remove(character); else FACTOR.put(character, f);
        return true;
    }
    public static float factor(Object character) {
        Float f = character == null ? null : FACTOR.get(character);
        return f == null ? 1f : f;
    }
    public static void clear(Object character) { if (character != null) FACTOR.remove(character); }
    public static void clearAll() { FACTOR.clear(); }

    /** Pure decision: scale when the state's simple class name is a locomotion state. */
    public static boolean locomotion(String stateClassName) {
        return stateClassName != null && LOCOMOTION.contains(stateClassName);
    }

    /** IsoPlayer.getDeferredMovement(Vector2 result, boolean reset) exit. */
    public static void afterDeferredMovement(Object character, Object result) {
        if (character == null || result == null || FACTOR.isEmpty()) return;
        float f = factor(character);
        if (f == 1f) return;
        try {
            Object state = Reflect.call(character, "getCurrentState");
            if (state == null || !locomotion(state.getClass().getSimpleName())) { skipped.incrementAndGet(); return; }
            float x = ((Number) Reflect.get(result, "x")).floatValue();
            float y = ((Number) Reflect.get(result, "y")).floatValue();
            if (x == 0f && y == 0f) return;
            Reflect.set(result, "x", x * f);
            Reflect.set(result, "y", y * f);
            scaled.incrementAndGet();
            String stateName = state.getClass().getSimpleName();
            if (LOGGED_STATES.add(stateName))
                System.out.println("[WTAGarou Java][Stride] root motion x" + f + " in " + stateName
                        + " (scaled biped: ground covered now matches the drawn stride)");
        } catch (Throwable t) {
            if (WARNED.compareAndSet(false, true))
                System.out.println("[WTAGarou Java] stride adapter unavailable (vanilla root motion kept): " + t);
        }
    }

    public static String status() {
        return "stride: " + FACTOR.size() + " character(s), " + scaled.get() + " frames scaled, " + skipped.get() + " non-locomotion frames left alone";
    }
}
