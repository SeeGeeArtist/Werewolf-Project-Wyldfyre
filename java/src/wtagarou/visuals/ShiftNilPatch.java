package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

@Patch(className="zombie.characters.CharacterTimedActions.BaseAction", methodName="setActionAnim", warmUp=true)
public final class ShiftNilPatch {
    @Patch.OnEnter(skipOn=true)
    public static boolean enter(@Patch.This Object action,@Patch.Argument(0) Object animation) {
        return ShiftNilGuard.skip(action,animation);
    }
}
