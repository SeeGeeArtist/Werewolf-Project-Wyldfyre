package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;
@Patch(className="zombie.core.skinnedmodel.advancedanimation.AnimatedModel$AnimatedModelInstanceRenderData",
        methodName="transformToParent",warmUp=true)
public final class CrinosHeadwearPatch {
    @Patch.OnExit
    public static void exit(@Patch.This Object self,@Patch.Argument(0) Object parent) {
        CrinosHeadwear.transform(self,parent);
    }
}
