package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;
import zombie.core.skinnedmodel.visual.ItemVisuals;
@Patch(className="zombie.core.skinnedmodel.visual.HumanVisual",methodName="getBodyVisuals",warmUp=true,strictMatch=true)
public final class CrinosBodyVisualsPatch {
    @Patch.OnExit
    public static void exit(@Patch.Return(readOnly=false) ItemVisuals result) {
        result=CrinosFaceVisuals.bodySnapshot(result);
    }
}
