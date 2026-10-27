package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** 0.4.69: ActionContext.reportEvent stores through this single method;
 *  the "wasBumped" that would enter BumpedState is swallowed inside a charge. */
@Patch(className="zombie.characters.action.ActionContextEvents", methodName="add", warmUp=true)
public final class CrowdChargeEventPatch {
    @Patch.OnEnter(skipOn=true)
    public static boolean enter(@Patch.Argument(0) String event) {
        return CrowdChargeRuntime.swallowEvent(event);
    }
}
