package wtagarou.visuals;

import me.zed_0xff.zombie_buddy.Patch;

/** 0.4.20: a wolf may carry a firearm in its jaws (WTAGarouSlots no longer
 * unequips it), but it has no trigger finger: while the direct wolf body is
 * active and the primary item is ranged, the attack press is swallowed.
 * Melee jaw carries and the empty-mouthed bite are untouched. */
@Patch(className="zombie.characters.IsoPlayer", methodName="pressedAttack", warmUp=true)
public final class JawsAttackPatch {
    public static volatile long swallowed;

    @Patch.OnEnter(skipOn=true)
    public static boolean enter(@Patch.This Object player) {
        return swallow(player);
    }

    /** Public for tests: true when the press must be dropped. */
    public static boolean swallow(Object player) {
        if (player == null || !WolfRuntime.active(player)) return false;
        try {
            Object weapon = Reflect.call(player, "getPrimaryHandItem");
            if (weapon == null) return false;
            if (Boolean.TRUE.equals(Reflect.call(weapon, "isRanged"))) { swallowed++; return true; }
        } catch (ReflectiveOperationException | RuntimeException ignored) {}
        return false;
    }
}
