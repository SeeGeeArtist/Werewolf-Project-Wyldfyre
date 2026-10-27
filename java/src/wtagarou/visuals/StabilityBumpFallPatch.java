package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

@Patch(className="zombie.characters.IsoGameCharacter", methodName="setBumpFall", warmUp=true)
public final class StabilityBumpFallPatch {
    @Patch.OnEnter
    public static void enter(@Patch.This Object character,
                             @Patch.Argument(value=0, readOnly=false) boolean fall) {
        // 0.4.69: a crowd-charge collision never trips the charger.
        fall = StabilityRuntime.filter(character, CrowdChargeRuntime.filterBumpFall(character, fall), "bump fall");
    }
}
