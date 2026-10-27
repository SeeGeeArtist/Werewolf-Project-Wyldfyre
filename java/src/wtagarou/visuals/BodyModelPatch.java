package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;
import zombie.core.skinnedmodel.model.Model;

@Patch(className="zombie.core.skinnedmodel.ModelManager", methodName="getBodyModel", warmUp=true)
public final class BodyModelPatch {
    @Patch.OnExit
    public static void exit(@Patch.Argument(0) Object character,
                            @Patch.Return(readOnly=false) Model model) {
        WolfRuntime.bodyHookObserved = true;
        Object wolf = WolfRuntime.modelFor(character);
        if (wolf != null) model = (Model) wolf;
    }
}
