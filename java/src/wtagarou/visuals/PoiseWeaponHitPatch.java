package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** 0.4.68: weapon / animal hits on a player (IsoPlayer.hitConsequences(weapon,
 *  wielder, ignoreDamage, damage, remote)) bracket the flinch filter; a ranged
 *  weapon never enters the bracket. */
@Patch(className="zombie.characters.IsoPlayer", methodName="hitConsequences", warmUp=true)
public final class PoiseWeaponHitPatch {
    @Patch.OnEnter
    public static void enter(@Patch.This Object victim, @Patch.Argument(0) Object weapon) {
        PoiseRuntime.beginHit(victim, weapon);
    }
    @Patch.OnExit
    public static void exit(@Patch.This Object victim) {
        PoiseRuntime.endHit(victim);
    }
}
