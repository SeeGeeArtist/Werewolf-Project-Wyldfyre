package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** 0.4.69: fence/window climb lunges stagger through their own path
 *  (no hit reaction string). Skipped whole when poise holds: no stagger, no
 *  fall roll, no lunge-hit cue; the lunge does no damage of its own. */
@Patch(className="zombie.characters.IsoGameCharacter", methodName="attackFromWindowsLunge", warmUp=true)
public final class PoiseLungePatch {
    @Patch.OnEnter(skipOn=true)
    public static boolean enter(@Patch.This Object character, @Patch.Argument(0) Object zombie) {
        return PoiseRuntime.shrugsLunge(character, zombie);
    }
}
