package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** 0.4.69: the first call separate() makes once a running player overlaps
 *  a character. Opens the crowd-charge scope (and knocks the zombie down). */
@Patch(className="zombie.characters.IsoGameCharacter", methodName="setBumpedChr", warmUp=true)
public final class CrowdChargeBumpedPatch {
    @Patch.OnEnter
    public static void enter(@Patch.This Object player, @Patch.Argument(0) Object other) {
        CrowdChargeRuntime.onBumped(player, other);
    }
}
