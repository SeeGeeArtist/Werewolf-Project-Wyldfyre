package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;
@Patch(className="zombie.core.skinnedmodel.advancedanimation.AnimatedModel",methodName="setModelData",warmUp=true)
public final class TrueFormCorpseSizePatch {
    @Patch.OnExit
    public static void exit(@Patch.This Object animated) { TrueFormCorpse.size(animated); }
}
