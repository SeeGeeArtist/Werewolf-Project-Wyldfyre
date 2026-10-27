package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

@Patch(className="zombie.characters.BodyDamage.Thermoregulator$ThermalNode",
       methodName="calculateInsulation", warmUp=true)
public final class FurInsulationPatch {
    @Patch.OnExit
    public static void exit(@Patch.This Object node) {
        FurRuntime.afterInsulation(node);
    }
}
