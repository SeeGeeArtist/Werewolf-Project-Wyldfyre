package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** 0.4.62: after the item scripts are indexed, tag metal melee weapons wtagarou:coatable. See CoatableTagRuntime. */
@Patch(className="zombie.inventory.ItemTags", methodName="Init", warmUp=true)
public final class CoatableTagPatch {
    @Patch.OnExit
    public static void exit(@Patch.Argument(0) Object allItems) {
        CoatableTagRuntime.afterInit(allItems);
    }
}
