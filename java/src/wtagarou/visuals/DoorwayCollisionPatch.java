package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** 0.4.68: a tall form at a doorway. IsoGridSquare.testCollideAdjacent is the
 *  player movement collision funnel (IsoMovingObject: last.testCollideAdjacent
 *  (this, dx, dy, dz)); an upright tall LOCAL player walking across a doorway
 *  edge is refused, a running one ducks (sneak forced, restored a tile past). */
@Patch(className="zombie.iso.IsoGridSquare", methodName="testCollideAdjacent", warmUp=true)
public final class DoorwayCollisionPatch {
    @Patch.OnExit
    public static void exit(@Patch.This Object square, @Patch.Argument(0) Object mover,
                            @Patch.Argument(1) int dx, @Patch.Argument(2) int dy, @Patch.Argument(3) int dz,
                            @Patch.Return(readOnly=false) boolean collided) {
        collided = DoorwayRuntime.collide(square, mover, dx, dy, dz, collided);
    }
}
