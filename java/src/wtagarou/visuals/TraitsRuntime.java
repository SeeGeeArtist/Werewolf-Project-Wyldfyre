package wtagarou.visuals;

import java.util.Collections;
import java.util.Map;
import java.util.WeakHashMap;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Per-form body traits (0.4.13). Lua registers a profile per Garou; four
 * engine funnels consult it, all evidenced in the pinned B42.20.2 source:
 *
 *  - IsoPlayer.updateFootInjuries(): the barefoot scratch/cut loop for a
 *    character with no (or ruined) shoes. Skipped for paw forms.
 *  - IsoPlayer.updateMovementRates(): after the vanilla calculateWalkSpeed
 *    the "WalkSpeed"/"RunSpeed" animation variables (which DO drive player
 *    movement; IsoGameCharacter.speedMod is only read by zombie code) are
 *    multiplied per gait: sneak / walk / run / sprint.
 *  - IsoGameCharacter.getTurnDelta(): multiplied per form.
 *  - BodyDamage.JustAteFood(Food[, float]): the POISON stat added for an
 *    uncooked "dangerous" food is put back to its pre-meal value for a Garou.
 *    Rotten food and real poison are untouched.
 *
 * Reflection only; a missing method degrades to vanilla behaviour and is
 * counted, never mistaken for success.
 */
public final class TraitsRuntime {
    public static final class Profile {
        public boolean rawMeat, paws;
        public float walk = 1f, run = 1f, sprint = 1f, sneak = 1f, turn = 1f;
        boolean isIdentity() {
            return !rawMeat && !paws && walk == 1f && run == 1f && sprint == 1f && sneak == 1f && turn == 1f;
        }
    }

    private static final Map<Object, Profile> PROFILES =
            Collections.synchronizedMap(new WeakHashMap<>());
    public static final AtomicLong footInjuriesSkipped = new AtomicLong(), movementScaled = new AtomicLong(),
            turnsScaled = new AtomicLong(), poisonRestored = new AtomicLong(), failures = new AtomicLong();
    private static boolean loggedMovement, loggedFoot, loggedMeal;
    private static Object poisonStat;
    private static boolean poisonStatLooked;

    public static Profile profile(Object character) {
        return character == null ? null : PROFILES.get(character);
    }

    public static boolean set(Object character, boolean rawMeat, boolean paws,
                              double walk, double run, double sprint, double sneak, double turn) {
        if (character == null) return false;
        for (double v : new double[]{walk, run, sprint, sneak, turn}) {
            if (!Double.isFinite(v) || v < 0.1 || v > 5.0) return false;
        }
        Profile p = new Profile();
        p.rawMeat = rawMeat; p.paws = paws;
        p.walk = (float) walk; p.run = (float) run; p.sprint = (float) sprint;
        p.sneak = (float) sneak; p.turn = (float) turn;
        if (p.isIdentity()) PROFILES.remove(character); else PROFILES.put(character, p);
        return true;
    }
    public static void clear(Object character) { if (character != null) PROFILES.remove(character); }
    public static void clearAll() { PROFILES.clear(); }

    // ---- gait ------------------------------------------------------------

    /** Multiplier for the current gait. Sneak wins over walk; run/sprint are
     * never sneaking in the engine but are checked first for safety. */
    public static float gaitMultiplier(Profile p, boolean sneaking, boolean running, boolean sprinting) {
        if (p == null) return 1f;
        if (sprinting) return p.sprint;
        if (running) return p.run;
        if (sneaking) return p.sneak;
        return p.walk;
    }

    /** IsoPlayer.updateMovementRates exit: scale WalkSpeed/RunSpeed. */
    public static void afterMovementRates(Object character) {
        if (character == null || PROFILES.isEmpty()) return;
        Profile p = PROFILES.get(character);
        if (p == null) return;
        try {
            boolean sneaking = bool(character, "isSneaking");
            boolean running = bool(character, "isRunning");
            boolean sprinting = bool(character, "isSprinting");
            float mul = gaitMultiplier(p, sneaking, running, sprinting);
            float runMul = sprinting ? p.sprint : p.run;
            if (mul != 1f) scaleVariable(character, "WalkSpeed", mul);
            if (runMul != 1f) scaleVariable(character, "RunSpeed", runMul);
            movementScaled.incrementAndGet();
            if (!loggedMovement) {
                loggedMovement = true;
                System.out.println("[WTAGarou Java] movement multipliers active (WalkSpeed x" + mul + ", RunSpeed x" + runMul + ")");
            }
        } catch (ReflectiveOperationException | RuntimeException error) {
            failures.incrementAndGet();
            warn("movement", error);
        }
    }

    private static void scaleVariable(Object character, String name, float mul) throws ReflectiveOperationException {
        Object current = Reflect.call(character, "getVariableFloat", new Class<?>[]{String.class, float.class}, name, 1f);
        float value = current instanceof Number n ? n.floatValue() : 1f;
        Reflect.call(character, "setVariable", new Class<?>[]{String.class, float.class}, name, value * mul);
    }

    // ---- turning ---------------------------------------------------------

    public static float turnDelta(Object character, float vanilla) {
        if (character == null || PROFILES.isEmpty()) return vanilla;
        Profile p = PROFILES.get(character);
        if (p == null || p.turn == 1f) return vanilla;
        turnsScaled.incrementAndGet();
        return vanilla * p.turn;
    }

    // ---- paws ------------------------------------------------------------

    /** IsoPlayer.updateFootInjuries enter: true skips the vanilla loop. */
    public static boolean skipFootInjuries(Object character) {
        if (character == null || PROFILES.isEmpty()) return false;
        Profile p = PROFILES.get(character);
        if (p == null || !p.paws) return false;
        footInjuriesSkipped.incrementAndGet();
        if (!loggedFoot) {
            loggedFoot = true;
            System.out.println("[WTAGarou Java] barefoot injury loop skipped for a paw form");
        }
        return true;
    }

    // ---- raw meat --------------------------------------------------------

    /** BodyDamage.JustAteFood enter: remember the poison stat, or null when
     * this meal is not a Garou eating dangerous uncooked food. */
    public static Object beforeMeal(Object bodyDamage, Object food) {
        if (bodyDamage == null || food == null || PROFILES.isEmpty()) return null;
        try {
            Object character = Reflect.call(bodyDamage, "getParentChar");
            Profile p = character == null ? null : PROFILES.get(character);
            if (p == null || !p.rawMeat) return null;
            if (!isDangerousUncooked(food)) return null;
            Object stats = Reflect.call(character, "getStats");
            Object stat = poisonStat();
            if (stats == null || stat == null) return null;
            Object value = Reflect.call(stats, "get", new Class<?>[]{stat.getClass()}, stat);
            return value instanceof Number ? new Object[]{stats, stat, ((Number) value).floatValue()} : null;
        } catch (ReflectiveOperationException | RuntimeException error) {
            failures.incrementAndGet();
            warn("meal", error);
            return null;
        }
    }

    /** BodyDamage.JustAteFood exit: put the poison stat back. */
    public static void afterMeal(Object saved) {
        if (!(saved instanceof Object[] s) || s.length != 3) return;
        try {
            Reflect.call(s[0], "set", new Class<?>[]{s[1].getClass(), float.class}, s[1], s[2]);
            poisonRestored.incrementAndGet();
            if (!loggedMeal) {
                loggedMeal = true;
                System.out.println("[WTAGarou Java] raw meat eaten by a Garou: food poisoning suppressed");
            }
        } catch (ReflectiveOperationException | RuntimeException error) {
            failures.incrementAndGet();
            warn("meal restore", error);
        }
    }

    static boolean isDangerousUncooked(Object food) throws ReflectiveOperationException {
        return bool(food, "isbDangerousUncooked") && !bool(food, "isCooked")
                && !bool(food, "isRotten") && !bool(food, "isTainted")
                && ((Number)Reflect.call(food,"getPoisonPower")).intValue()<=0;
    }

    private static Object poisonStat() {
        if (poisonStatLooked) return poisonStat;
        poisonStatLooked = true;
        try {
            Class<?> type = Class.forName("zombie.characters.CharacterStat");
            poisonStat = type.getField("POISON").get(null);
        } catch (ReflectiveOperationException | RuntimeException error) {
            failures.incrementAndGet();
            warn("CharacterStat.POISON", error);
        }
        return poisonStat;
    }

    private static boolean bool(Object target, String method) throws ReflectiveOperationException {
        Object value = Reflect.call(target, method);
        return value instanceof Boolean b && b;
    }

    private static void warn(String what, Throwable error) {
        if (failures.get() <= 5) {
            System.out.println("[WTAGarou Java] traits " + what + " unavailable: " + error);
        }
    }

    public static String status() {
        return "traits profiles=" + PROFILES.size() + ", foot injuries skipped=" + footInjuriesSkipped.get()
                + ", movement scaled=" + movementScaled.get() + ", turns scaled=" + turnsScaled.get()
                + ", poison restored=" + poisonRestored.get() + ", failures=" + failures.get();
    }
}
