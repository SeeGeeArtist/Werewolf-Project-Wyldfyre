package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

@Patch(className="zombie.characters.IsoGameCharacter", methodName="setKnockedDown", warmUp=true)
public final class StabilityKnockdownPatch {
    @Patch.OnEnter
    public static void enter(@Patch.This Object character,
                             @Patch.Argument(value=0, readOnly=false) boolean knockedDown) {
        knockedDown = StabilityRuntime.filter(character, knockedDown, "knockdown");
    }
}
