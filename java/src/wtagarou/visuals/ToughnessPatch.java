package wtagarou.visuals;

import me.zed_0xff.zombie_buddy.Patch;

/** 0.4.72: scale every acute hit by the character's form intake factor. */
@Patch(className="zombie.characters.BodyDamage.BodyPart", methodName="AddDamage", warmUp=true)
public final class ToughnessPatch {
    @Patch.OnEnter
    public static void enter(@Patch.This Object bodyPart,
                             @Patch.Argument(value=0, readOnly=false) float val) {
        val = ToughnessRuntime.scale(bodyPart, val);
    }
}
