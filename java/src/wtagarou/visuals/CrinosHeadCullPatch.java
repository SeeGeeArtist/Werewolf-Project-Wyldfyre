package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

@Patch(className="zombie.core.skinnedmodel.advancedanimation.AnimatedModel$AnimatedModelInstanceRenderData",
        methodName="initMatrixPalette",warmUp=true)
public final class CrinosHeadCullPatch {
    @Patch.OnExit
    public static void exit(@Patch.This Object data) { CrinosHeadCull.afterPalette(data); }
}
