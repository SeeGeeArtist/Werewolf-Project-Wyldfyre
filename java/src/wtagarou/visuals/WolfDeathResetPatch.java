package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** Flush only our deferred death cleanup, before the native queued rebuild. */
@Patch(className="zombie.core.skinnedmodel.ModelManager", methodName="Reset", warmUp=true)
public final class WolfDeathResetPatch {
    @Patch.OnEnter
    public static void enter(@Patch.Argument(0) Object character) {
        WolfRuntime.beforeModelReset(character);
    }
}
