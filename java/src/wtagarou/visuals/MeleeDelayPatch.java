package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

@Patch(className="zombie.ai.states.SwipeStatePlayer",
       methodName="OnAnimEvent_SetMeleeDelay", warmUp=true)
public final class MeleeDelayPatch {
    @Patch.OnEnter
    public static void enter(@Patch.Argument(0) Object character,
                             @Patch.Argument(value=1, readOnly=false) float delay) {
        delay = CombatRuntime.delay(character, delay);
    }
}
