package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** 0.4.44: a grappled body thrown into a container (trunk, seat, trailer).
 *  Marks the thrower so WolfRuntime plays the deposit clip as corpse
 *  handling (idle pose, no deferred rotation). Own-inventory stows are
 *  ignored inside markThrow. */
@Patch(className="zombie.characters.IsoGameCharacter", methodName="throwGrappledIntoInventory", warmUp=true)
public final class CorpseThrowPatch {
    @Patch.OnEnter
    public static void enter(@Patch.This Object character, @Patch.Argument(0) Object container) {
        WolfGrappleRuntime.markThrow(character, container);
    }
}
