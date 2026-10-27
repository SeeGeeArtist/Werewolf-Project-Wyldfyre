package wtagarou.visuals;

import java.util.Collections;
import java.util.Set;
import java.util.WeakHashMap;
import java.util.concurrent.atomic.AtomicBoolean;

public final class CombatRuntime {
    private static final Set<Object> ENABLED =
            Collections.synchronizedSet(Collections.newSetFromMap(new WeakHashMap<>()));
    private static final AtomicBoolean WARNED = new AtomicBoolean();
    // InventoryItem also includes ComboItem, bags, lights, food, etc. The
    // September 21 log shows ComboItem reaching a melee event while held.
    private static final ClassValue<Boolean> WEAPON_API = new ClassValue<>() {
        protected Boolean computeValue(Class<?> type) {
            try { type.getMethod("isRanged"); return true; }
            catch (NoSuchMethodException ignored) { return false; }
        }
    };
    public static volatile boolean observed;
    /** Recovery cap (event units) for every jaw attack, equal to the approved
     * 1handed/2handed Garou cap. Human-form caps are unchanged. */
    public static final float JAWS_CAP = 12f;

    public static void enable(Object character, boolean enabled) {
        if (character == null) return;
        if (enabled) ENABLED.add(character); else ENABLED.remove(character);
    }
    public static void clearAll() { ENABLED.clear(); }

    /** These are animation-event delay units, NOT seconds. Values read from
     * Skully's five base XML nodes (floor variants inherit those nodes). */
    public static float cap(String weaponType) {
        if (weaponType == null) return -1;
        switch (weaponType.toLowerCase(java.util.Locale.ROOT)) {
            case "1handed": case "2handed": return 12;
            case "knife": return 1;
            case "spear": return 8;
            case "heavy": return 4;
            default: return -1;
        }
    }
    public static float delay(Object character, float original) {
        observed = true;
        if (!ENABLED.contains(character) || !Float.isFinite(original) || original <= 0) return original;
        try {
            if (Boolean.TRUE.equals(Reflect.call(character, "isDead"))) return original;
            Object weapon = Reflect.call(character, "getPrimaryHandItem");
            if (weapon == null || !WEAPON_API.get(weapon.getClass())) return original;
            if (Boolean.TRUE.equals(Reflect.call(weapon, "isRanged"))) return original;
            String type = (String) Reflect.call(character, "getVariableString", String.class, "Weapon");
            // 0.4.58: a wolf body bites with the same jaws whatever it carries.
            // The engine still classifies the carried item (an electric guitar
            // is "heavy"), and the heavy cap of 4 plus the short derived bite
            // clip produced the machine-gun Hispo guitar reported October 13.
            float cap = WolfRuntime.active(character) ? JAWS_CAP : cap(type);
            return cap < 0 ? original : Math.min(original, cap);
        } catch (ReflectiveOperationException | RuntimeException error) {
            if (WARNED.compareAndSet(false, true))
                System.out.println("[WTAGarou Java] recovery adapter unavailable: " + error);
            return original;
        }
    }
}
