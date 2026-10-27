package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** A Crinos/Hispo climbing an open, unbroken window smashes it first (0.4.39). */
@Patch(className="zombie.characters.IsoGameCharacter", methodName="climbThroughWindow", warmUp=true)
public final class WindowClimbPatch {
    @Patch.OnEnter
    public static void enter(@Patch.This Object character, @Patch.Argument(0) Object window) {
        BulkFormRuntime.smashBeforeClimb(character, window);
    }
}
