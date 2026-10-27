package wtagarou.visuals;

import java.lang.reflect.Method;
import java.util.Collections;
import java.util.Set;
import java.util.WeakHashMap;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Bulk forms (0.4.39): Crinos and Hispo do not fit through doors made for
 * people. Lua flags the character from the client visual refresh; two engine
 * funnels consult the flag, both evidenced in the private B42.21 jar:
 *
 *  - BaseVehicle.isEnterBlocked(IsoGameCharacter, int): the vanilla vehicle
 *    radial / ISEnterVehicle gate. A flagged character is always blocked.
 *  - IsoGameCharacter.climbThroughWindow(IsoWindow): before the climb, an
 *    OPEN, unbroken window is smashed through IsoWindow.WeaponHit(chr, null),
 *    the engine's own bare-handed smash (noise, glass, alarm, MP packet), and
 *    the climber takes the bare-handed cut (BodyDamage.setScratchedWindow +
 *    "PainFromGlassCut"), exactly like SmashWindowState with empty hands.
 *    Already smashed or destroyed windows pass untouched. The climb itself is
 *    never skipped.
 *
 * Reflection only; a missing method degrades to vanilla behaviour and is
 * counted, never mistaken for success.
 */
public final class BulkFormRuntime {
    private static final Set<Object> BULK =
            Collections.newSetFromMap(Collections.synchronizedMap(new WeakHashMap<>()));
    public static final AtomicLong entriesBlocked = new AtomicLong(), windowsSmashed = new AtomicLong(),
            climbsSeen = new AtomicLong(), failures = new AtomicLong();
    private static boolean loggedEntry, loggedWindow;
    static final String WINDOW_CLASS = "zombie.iso.objects.IsoWindow";
    static final String CUT_VOICE = "PainFromGlassCut";

    public static boolean set(Object character, boolean bulk) {
        if (character == null) return false;
        if (bulk) BULK.add(character); else BULK.remove(character);
        return true;
    }
    public static boolean isBulk(Object character) { return character != null && BULK.contains(character); }
    public static void clear(Object character) { if (character != null) BULK.remove(character); }

    /** OnExit of BaseVehicle.isEnterBlocked: keep a vanilla "blocked"; add ours. */
    public static boolean blockEntry(Object character, boolean vanilla) {
        if (vanilla) return true;
        if (!isBulk(character)) return false;
        entriesBlocked.incrementAndGet();
        if (!loggedEntry) {
            loggedEntry = true;
            System.out.println("[WTAGarou][BulkForm] vehicle entry refused for a Crinos/Hispo character");
        }
        return true;
    }

    static boolean isWindow(Object window) {
        if (window == null) return false;
        for (Class<?> c = window.getClass(); c != null; c = c.getSuperclass()) {
            if (WINDOW_CLASS.equals(c.getName()) || c.getSimpleName().equals("IsoWindow")) return true;
        }
        return false;
    }

    private static Method find(Class<?> type, String name, int params) {
        for (Class<?> c = type; c != null; c = c.getSuperclass()) {
            for (Method m : c.getDeclaredMethods()) {
                if (m.getName().equals(name) && m.getParameterCount() == params) {
                    m.setAccessible(true);
                    return m;
                }
            }
        }
        return null;
    }
    private static boolean bool(Object target, String name) throws Exception {
        Method m = find(target.getClass(), name, 0);
        return m != null && Boolean.TRUE.equals(m.invoke(target));
    }

    /** OnEnter of IsoGameCharacter.climbThroughWindow(IsoWindow). Returns true when glass was smashed. */
    public static boolean smashBeforeClimb(Object character, Object window) {
        if (!isBulk(character) || !isWindow(window)) return false;
        climbsSeen.incrementAndGet();
        try {
            if (bool(window, "isSmashed") || bool(window, "isDestroyed") || bool(window, "isBarricaded")) return false;
            Method hit = find(window.getClass(), "WeaponHit", 2);
            if (hit == null) { failures.incrementAndGet(); return false; }
            hit.invoke(window, character, null);
            if (!bool(window, "isSmashed") && !bool(window, "isDestroyed")) {
                Method smash = find(window.getClass(), "smashWindow", 0);
                if (smash != null) smash.invoke(window);
            }
            Method body = find(character.getClass(), "getBodyDamage", 0);
            Object bodyDamage = body == null ? null : body.invoke(character);
            Method cut = bodyDamage == null ? null : find(bodyDamage.getClass(), "setScratchedWindow", 0);
            if (cut != null) cut.invoke(bodyDamage);
            Method voice = find(character.getClass(), "playerVoiceSound", 1);
            if (voice != null) voice.invoke(character, CUT_VOICE);
            windowsSmashed.incrementAndGet();
            if (!loggedWindow) {
                loggedWindow = true;
                System.out.println("[WTAGarou][BulkForm] open window smashed before a Crinos/Hispo climb");
            }
            return true;
        } catch (Throwable t) {
            failures.incrementAndGet();
            System.out.println("[WTAGarou][BulkForm] window smash failed: " + t);
            return false;
        }
    }

    public static String status() {
        return "bulk=" + BULK.size() + " entriesBlocked=" + entriesBlocked.get() + " climbs=" + climbsSeen.get()
                + " windowsSmashed=" + windowsSmashed.get() + " failures=" + failures.get();
    }
}
