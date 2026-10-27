package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** Per-gait WalkSpeed/RunSpeed multipliers, applied after the vanilla calculation. */
@Patch(className="zombie.characters.IsoPlayer", methodName="updateMovementRates", warmUp=true)
public final class MovementRatePatch {
    @Patch.OnExit(onThrowable=Throwable.class)
    public static void exit(@Patch.This Object character) {
        TraitsRuntime.afterMovementRates(character);
    }
}
