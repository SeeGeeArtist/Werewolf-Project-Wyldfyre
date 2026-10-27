package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** 0.4.60: scale player root motion by the form's stride factor (StrideRuntime).
 * IsoPlayer overrides getDeferredMovement(Vector2, boolean) and vanilla scales the
 * same vector there for its invisible-sprint cheat, so this is the proven lever. */
@Patch(className="zombie.characters.IsoPlayer", methodName="getDeferredMovement", warmUp=true)
public final class StridePatch {
    @Patch.OnExit(onThrowable=Throwable.class)
    public static void exit(@Patch.This Object player, @Patch.Argument(0) Object result) {
        StrideRuntime.afterDeferredMovement(player, result);
    }
}
