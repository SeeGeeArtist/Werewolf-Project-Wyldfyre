package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** Scales footstep noise per form; wolf forms play their own steps. */
@Patch(className="zombie.characters.IsoGameCharacter", methodName="DoFootstepSound", warmUp=true)
public final class FootstepPatch {
    @Patch.OnEnter(skipOn=true)
    public static boolean enter(@Patch.This Object character,
                                @Patch.Argument(value=0, readOnly=false) float volume) {
        float result = StealthRuntime.footstep(character, volume);
        if (result < 0f) return true;   // wolf path handled the step
        volume = result;
        return false;
    }
}
