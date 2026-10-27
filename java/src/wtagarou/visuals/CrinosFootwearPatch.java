package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;
/** 0.4.67: skip the worn-footwear mesh while the Crinos digitigrade legs are
 *  mounted. The item stays equipped; only PopTemplateManager's model for it
 *  is not built (null return, as for items with no model). */
@Patch(className="zombie.core.skinnedmodel.population.PopTemplateManager",methodName="addClothingItem",warmUp=true)
public final class CrinosFootwearPatch {
    @Patch.OnEnter(skipOn=true)
    public static boolean enter(@Patch.Argument(0) Object chr,@Patch.Argument(2) Object itemVisual) {
        return CrinosCosmetics.hidesFootwear(chr,itemVisual);
    }
}
