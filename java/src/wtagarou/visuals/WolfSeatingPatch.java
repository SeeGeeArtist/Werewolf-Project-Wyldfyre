package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;
import zombie.core.skinnedmodel.model.SkinningData;

@Patch(className="zombie.seating.SeatingManager", methodName="getTotalDeferredMovement", warmUp=true)
public final class WolfSeatingPatch {
    @Patch.OnEnter
    public static void enter(@Patch.Argument(value=0, readOnly=false) SkinningData data,
                             @Patch.Argument(1) Object node) {
        data = (SkinningData) WolfRuntime.seatingData(data, node);
    }
}
