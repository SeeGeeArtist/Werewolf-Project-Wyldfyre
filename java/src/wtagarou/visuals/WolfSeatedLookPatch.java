package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;
@Patch(className="zombie.core.skinnedmodel.animation.AnimationPlayer", methodName="updateTwistBone", warmUp=true, strictMatch=true)
public final class WolfSeatedLookPatch {
    @Patch.OnExit
    public static void exit(@Patch.This Object player) { WolfSeatedLook.apply(player); }
}
