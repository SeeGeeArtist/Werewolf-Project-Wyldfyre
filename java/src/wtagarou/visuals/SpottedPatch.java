package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** Drops a share of zombie sight checks against low-profile forms. */
@Patch(className="zombie.characters.IsoZombie", methodName="spotted", warmUp=true)
public final class SpottedPatch {
    @Patch.OnEnter(skipOn=true)
    public static boolean enter(@Patch.Argument(0) Object target, @Patch.Argument(1) boolean forced) {
        return StealthRuntime.skipSpot(target, forced);
    }
}
