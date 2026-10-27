package wtagarou.visuals;

import java.util.Collections;
import java.util.Map;
import java.util.WeakHashMap;
import java.util.concurrent.ThreadLocalRandom;

/**
 * 0.4.68: poise. Every flinch a player plays is a string stored with
 * {@code IsoGameCharacter.setHitReaction}: zombie attacks store it from
 * {@code BodyDamage.AddRandomDamageFromZombie} ("Bite"/"Scratch"/lunge names
 * plus a LEFT/RIGHT side, crawlers included), weapon and animal hits from
 * {@code IsoPlayer.hitConsequences} ("HitReaction"). Damage is rolled after
 * the string is stored, so clearing the string only removes the stagger.
 *
 * <p>Both callers are bracketed ({@link #beginHit}/{@link #endHit}) so the
 * setter is filtered ONLY inside a melee hit: vehicle hits, "EndDeath" (the
 * drag-down), "Floor", the shove "Defended" reactions and anything stored
 * outside a hit pass untouched, and a hit whose weapon is ranged
 * ({@code HandWeapon.isRanged}) is never filtered. A flagged character with
 * poise chance p shrugs the flinch off with probability p.
 */
public final class PoiseRuntime {
    private static final Map<Object, Float> POISE = Collections.synchronizedMap(new WeakHashMap<>());
    /** Victim currently inside a melee hit call (same thread as the setter). */
    private static final ThreadLocal<Object> MELEE_VICTIM = new ThreadLocal<>();
    public static volatile long shrugged, flinched, rangedKept, passed;
    private static boolean logged;

    private PoiseRuntime() {}

    public static boolean set(Object character, double chance) {
        if (character == null || !Double.isFinite(chance)) return false;
        if (chance <= 0) { POISE.remove(character); return true; }
        POISE.put(character, (float) Math.min(1.0, chance));
        return true;
    }
    public static void clear(Object character) { if (character != null) POISE.remove(character); }
    public static void clearAll() { POISE.clear(); }
    public static float chanceFor(Object character) {
        Float v = character == null ? null : POISE.get(character);
        return v == null ? 0f : v;
    }

    /** Entry of a hit call. {@code weapon} may be null (zombie attack). */
    public static void beginHit(Object victim, Object weapon) {
        if (victim == null || chanceFor(victim) <= 0f) return;
        if (weapon != null && isRanged(weapon)) { rangedKept++; return; }
        MELEE_VICTIM.set(victim);
    }
    public static void endHit(Object victim) {
        if (victim != null && MELEE_VICTIM.get() == victim) MELEE_VICTIM.remove();
    }
    static boolean insideMeleeHit(Object victim) { return victim != null && MELEE_VICTIM.get() == victim; }

    /** The value setHitReaction should store. */
    public static String filter(Object character, String reaction) {
        if (reaction == null || reaction.isEmpty()) return reaction;
        if (!insideMeleeHit(character)) return reaction;
        if (reaction.startsWith("EndDeath") || reaction.startsWith("Floor") || reaction.endsWith("Defended")) return reaction;
        float chance = chanceFor(character);
        if (chance <= 0f) return reaction;
        if (chance < 1f && ThreadLocalRandom.current().nextFloat() >= chance) { flinched++; return reaction; }
        shrugged++;
        if (!logged) {
            logged = true;
            System.out.println("[WTAGarou][Poise] melee flinch \"" + reaction + "\" shrugged off (chance=" + chance + ")");
        }
        return "";
    }

    /** 0.4.69: the climb lunge. Zombies flopping over a fence, through a
     *  window (ClimbOverFenceState / ClimbThroughWindowState "CheckAttack")
     *  or thrown out of one call {@code IsoGameCharacter.attackFromWindowsLunge},
     *  which stores no hit reaction: it sets the "stagger" bump, rolls a fall
     *  and reports "wasBumped" itself, so the setHitReaction filter never saw
     *  it ("the zombies that temporarily crawl after climbing over a fence"
     *  still staggered the Crinos). Same poise roll; true = skip the lunge. */
    public static volatile long lungesShrugged, lungesTaken;
    private static boolean loggedLunge;
    public static boolean shrugsLunge(Object character, Object zombie) {
        if (character == null) return false;
        float chance = chanceFor(character);
        if (chance <= 0f) return false;
        if (chance < 1f && ThreadLocalRandom.current().nextFloat() >= chance) { lungesTaken++; return false; }
        lungesShrugged++;
        if (!loggedLunge) {
            loggedLunge = true;
            System.out.println("[WTAGarou][Poise] climb lunge (fence/window flop) shrugged off (chance=" + chance + ")");
        }
        return true;
    }

    private static boolean isRanged(Object weapon) {
        try {
            Object r = Reflect.call(weapon, "isRanged");
            return r instanceof Boolean && (Boolean) r;
        } catch (ReflectiveOperationException e) {
            return false;
        }
    }
    public static String status() {
        return "poise registered=" + POISE.size() + "; shrugged=" + shrugged + "; flinched=" + flinched + "; ranged kept=" + rangedKept
                + "; climb lunges shrugged=" + lungesShrugged + "/" + (lungesShrugged + lungesTaken);
    }
}
