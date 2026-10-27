package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** Crinos and Hispo cannot climb into a vehicle seat (0.4.39). */
@Patch(className="zombie.vehicles.BaseVehicle", methodName="isEnterBlocked", warmUp=true)
public final class VehicleEntryPatch {
    @Patch.OnExit
    public static void exit(@Patch.Argument(0) Object character,
                            @Patch.Return(readOnly=false) boolean blocked) {
        blocked = BulkFormRuntime.blockEntry(character, blocked);
    }
}
