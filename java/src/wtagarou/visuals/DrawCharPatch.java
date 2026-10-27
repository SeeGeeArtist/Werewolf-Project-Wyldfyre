package wtagarou.visuals;

import me.zed_0xff.zombie_buddy.Patch;

@Patch(className = "zombie.core.skinnedmodel.model.Model",
        methodName = "DrawChar", warmUp = true)
public final class DrawCharPatch {
    @Patch.OnEnter(skipOn=true)
    public static boolean enter(@Patch.Argument(0) Object slot,
                             @Patch.Argument(1) Object renderData,
                             @Patch.Local("garouSavedScale") Object saved) {
        if (WolfRuntime.hideSubmodel(slot,renderData)) return true;
        saved = ScaleRuntime.begin(slot, renderData);
        WolfRuntime.applyTexture(renderData);
        return false;
    }

    @Patch.OnExit(onThrowable = Throwable.class)
    public static void exit(@Patch.Local("garouSavedScale") Object saved) {
        ScaleRuntime.end(saved);
    }
}
