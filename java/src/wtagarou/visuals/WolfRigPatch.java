package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;
@Patch(className="zombie.characters.IsoPlayer", methodName="onAnimPlayerCreated", warmUp=true)
public final class WolfRigPatch {
    @Patch.OnExit
    public static void exit(@Patch.This Object character, @Patch.Argument(0) Object player) {
        WolfRuntime.configureRig(character,player);
    }
}
