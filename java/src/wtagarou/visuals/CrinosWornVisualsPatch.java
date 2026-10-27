package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;
import zombie.core.skinnedmodel.visual.ItemVisuals;
@Patch(className="zombie.characters.IsoPlayer",methodName="getItemVisuals",warmUp=true,strictMatch=true)
public final class CrinosWornVisualsPatch {
    @Patch.OnExit
    public static void exit(@Patch.Argument(0) ItemVisuals snapshot) {
        CrinosFaceVisuals.filterSnapshot(snapshot);
    }
}
