package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** The mesh cache is keyed by mesh name, NOT the Model's isStatic key.
 * Request the skinned mesh before addStaticForcedTex can cache a static import.
 * Keep native allocation, parent/owner bookkeeping and other items untouched. */
@Patch(className="zombie.core.skinnedmodel.ModelManager",
        methodName="addStaticForcedTex", warmUp=true)
public final class WolfHarnessLoadPatch {
    @Patch.OnEnter
    public static void enter(@Patch.This Object manager, @Patch.Argument(1) String script) {
        WolfHarness.beforeCarrierLoad(manager,script);
    }
}
