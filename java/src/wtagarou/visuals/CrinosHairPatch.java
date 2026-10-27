package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;
@Patch(className="zombie.core.skinnedmodel.population.PopTemplateManager",methodName="addHeadHair",warmUp=true)
public final class CrinosHairPatch {
    @Patch.OnEnter(skipOn=true)
    public static boolean enter(@Patch.Argument(1) Object slot) {
        return CrinosCosmetics.hasHead(slot);
    }
}
