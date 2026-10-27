package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** 0.4.62: raw silver nitrate finishes in any vessel sitting in a hot container. See NitrateHeatRuntime. */
@Patch(className="zombie.inventory.InventoryItem", methodName="update", warmUp=true)
public final class NitrateHeatPatch {
    @Patch.OnExit
    public static void exit(@Patch.This Object item) {
        NitrateHeatRuntime.afterUpdate(item);
    }
}
