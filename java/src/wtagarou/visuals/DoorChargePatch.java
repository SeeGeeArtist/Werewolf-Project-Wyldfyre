package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** 0.4.68: Crinos sprint charge. IsoMovingObject.checkHitWall is where a
 *  sprinting local player's collision becomes the "collideWithWall" stumble;
 *  it is skipped when the tall form has just charged a closed wooden door
 *  (reported to Lua -> server, which breaks it) or a climbable window (the
 *  climb is started here; WindowClimbPatch smashes the glass first). */
@Patch(className="zombie.iso.IsoMovingObject", methodName="checkHitWall", warmUp=true)
public final class DoorChargePatch {
    @Patch.OnEnter(skipOn=true)
    public static boolean enter(@Patch.This Object mover) {
        return DoorwayRuntime.charge(mover);
    }
}
