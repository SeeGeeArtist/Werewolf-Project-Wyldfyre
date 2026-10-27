package wtagarou.visuals;

import me.zed_0xff.zombie_buddy.Patch;

/** Build 42.21 re-applies the human node mask when an existing node moves
 * between layers, after our AnimationPlayer.play preparation has finished. */
@Patch(className="zombie.core.skinnedmodel.advancedanimation.LiveAnimNode",
        methodName="initTrackBoneWeights", warmUp=true)
public final class WolfAttackMaskPatch {
    @Patch.OnExit
    public static void exit(@Patch.This Object node, @Patch.Argument(0) Object track,
                            @Patch.Argument(1) boolean useMasks) {
        WolfAttackMasks.afterTransfer(node, track, useMasks);
    }
}
