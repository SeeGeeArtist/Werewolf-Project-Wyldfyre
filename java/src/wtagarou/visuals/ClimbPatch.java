package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** 0.4.80: compress the scaled bipeds' climb arc (ClimbRuntime). Runs when
 * AnimationPlayer has the frame's model-space bone transforms ready and is
 * about to mark the skin palettes dirty: UpdateSkinTransforms is the one
 * call shared by the standard and the shared-skeleton animation paths. */
@Patch(className="zombie.core.skinnedmodel.animation.AnimationPlayer", methodName="UpdateSkinTransforms", warmUp=true, strictMatch=true)
public final class ClimbPatch {
    @Patch.OnEnter
    public static void enter(@Patch.This Object player) { ClimbRuntime.apply(player); }
}
