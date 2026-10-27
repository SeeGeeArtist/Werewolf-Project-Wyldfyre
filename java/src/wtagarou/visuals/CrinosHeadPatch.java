package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;
@Patch(className="zombie.core.skinnedmodel.population.PopTemplateManager",methodName="populateCharacterModelSlot",warmUp=true)
public final class CrinosHeadPatch {
    @Patch.OnEnter
    public static void enter(@Patch.Argument(0) Object chr,@Patch.Argument(1) Object slot,
                             @Patch.Local("crinosFaceScope") Object previous) {
        CrinosCosmetics.addHead(chr,slot);
        previous=CrinosFaceVisuals.enterPopulation(chr,slot);
    }
    @Patch.OnExit(onThrowable=Throwable.class)
    public static void exit(@Patch.Local("crinosFaceScope") Object previous) {
        CrinosFaceVisuals.leave(previous);
    }
}
