package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** 0.4.69: 42.21 re-applies the node's own mask on a layer transfer. */
@Patch(className="zombie.core.skinnedmodel.advancedanimation.LiveAnimNode",
        methodName="initTrackBoneWeights", warmUp=true)
public final class HowlMaskTransferPatch {
    @Patch.OnExit
    public static void exit(@Patch.This Object node, @Patch.Argument(0) Object track,
                            @Patch.Argument(1) boolean useMasks) {
        HowlMaskRuntime.afterTransfer(node, track, useMasks);
    }
}
