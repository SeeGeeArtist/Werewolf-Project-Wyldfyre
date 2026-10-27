package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** Paw forms skip the vanilla barefoot scratch/cut loop. */
@Patch(className="zombie.characters.IsoPlayer", methodName="updateFootInjuries", warmUp=true)
public final class FootInjuryPatch {
    @Patch.OnEnter(skipOn=true)
    public static boolean enter(@Patch.This Object character) {
        return TraitsRuntime.skipFootInjuries(character);
    }
}
