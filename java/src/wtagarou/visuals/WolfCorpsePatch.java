package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

@Patch(className="zombie.characters.IsoGameCharacter", methodName="becomeCorpse", warmUp=true)
public final class WolfCorpsePatch {
    @Patch.OnEnter
    public static void enter(@Patch.This Object character) { WolfRuntime.beforeCorpse(character); }
    @Patch.OnExit(onThrowable=Throwable.class)
    public static void exit(@Patch.This Object character) { WolfRuntime.afterCorpse(character); }
}
