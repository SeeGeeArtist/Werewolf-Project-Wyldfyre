package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** Dragged corpse sits further ahead of a wolf-form grappler (0.4.40). */
@Patch(className="zombie.core.skinnedmodel.BaseGrappleable", methodName="setGrapplePosOffsetForward", warmUp=true)
public final class GrappleOffsetPatch {
    @Patch.OnEnter
    public static void enter(@Patch.This Object grappleable,
                             @Patch.Argument(value=0, readOnly=false) float forward) {
        forward = WolfGrappleRuntime.offsetForward(grappleable, forward);
    }
}
