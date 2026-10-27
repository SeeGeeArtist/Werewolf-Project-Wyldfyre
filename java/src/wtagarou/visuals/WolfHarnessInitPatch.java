package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;
@Patch(className="zombie.core.skinnedmodel.advancedanimation.AnimatedModel$AnimatedModelInstanceRenderData",
        methodName="initModel", warmUp=true)
public final class WolfHarnessInitPatch {
    // B42.21: init() has NO arguments and publishes an already-built palette.
    // initModel(ModelInstance, parentData) builds it, before the world-render
    // subclass copies model/tex. Prepare on entry to this base implementation.
    @Patch.OnEnter
    public static void enter(@Patch.Argument(0) Object instance) {
        WolfHarness.beforeInit(instance);
    }
}
