package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** Hispo / Lupus melee reach (0.4.42). CombatManager's melee target and
 * hit-list range is HandWeapon.getMaxRange() x getRangeMod(character); this
 * scales the modifier for a flagged character's melee weapon only. */
@Patch(className="zombie.inventory.types.HandWeapon", methodName="getRangeMod", warmUp=true)
public final class MeleeRangePatch {
    @Patch.OnExit
    public static void exit(@Patch.This Object weapon, @Patch.Argument(0) Object character,
                            @Patch.Return(readOnly=false) float result) {
        result = MeleeRangeRuntime.scale(weapon, character, result);
    }
}
