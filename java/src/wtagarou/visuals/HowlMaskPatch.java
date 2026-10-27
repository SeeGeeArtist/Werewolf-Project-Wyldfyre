package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** 0.4.69: head/neck-only howl. Runs on the same AnimationPlayer.play as
 *  WolfTrackPatch; both early-out for the other's forms. */
@Patch(className="zombie.core.skinnedmodel.animation.AnimationPlayer", methodName="play", warmUp=true)
public final class HowlMaskPatch {
    @Patch.OnEnter
    public static void enter(@Patch.This Object player, @Patch.Argument(0) Object params) {
        // play(String,...) overloads share the name: begin() ignores them.
        // Root layers ignore subLayerBoneWeights in AnimationPlayer.play;
        // exit() below puts the mask on the track in that case.
        HowlMaskRuntime.begin(player, params);
    }

    /** 0.4.70: the root layer ignores the mask in play(); apply it to the track. */
    @Patch.OnExit
    public static void exit(@Patch.This Object player, @Patch.Argument(0) Object params, @Patch.Return Object track) {
        HowlMaskRuntime.afterPlay(player, params, track);
    }
}
