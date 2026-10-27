package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** 0.4.69: inside a charge the player's stumble type and the zombie's
 *  flinch type are both stored empty. */
@Patch(className="zombie.characters.IsoGameCharacter", methodName="setBumpType", warmUp=true)
public final class CrowdChargeBumpTypePatch {
    @Patch.OnEnter
    public static void enter(@Patch.This Object who,
                             @Patch.Argument(value=0, readOnly=false) String type) {
        type = CrowdChargeRuntime.filterBumpType(who, type);
    }
}
