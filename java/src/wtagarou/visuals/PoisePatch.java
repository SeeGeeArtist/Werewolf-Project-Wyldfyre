package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** 0.4.68: the flinch setter. Filtered only while PoiseRuntime has the
 *  character bracketed inside a melee hit (see the two bracket patches). */
@Patch(className="zombie.characters.IsoGameCharacter", methodName="setHitReaction", warmUp=true)
public final class PoisePatch {
    @Patch.OnEnter
    public static void enter(@Patch.This Object character,
                             @Patch.Argument(value=0, readOnly=false) String reaction) {
        reaction = PoiseRuntime.filter(character, reaction);
    }
}
