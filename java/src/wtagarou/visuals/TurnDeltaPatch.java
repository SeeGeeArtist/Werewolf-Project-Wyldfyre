package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** Per-form turn-rate multiplier. IsoPlayer.getTurnDelta calls super, so this covers players. */
@Patch(className="zombie.characters.IsoGameCharacter", methodName="getTurnDelta", warmUp=true)
public final class TurnDeltaPatch {
    @Patch.OnExit
    public static void exit(@Patch.This Object character, @Patch.Return(readOnly=false) float delta) {
        delta = TraitsRuntime.turnDelta(character, delta);
    }
}
