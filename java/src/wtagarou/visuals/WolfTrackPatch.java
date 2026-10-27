package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

@Patch(className="zombie.core.skinnedmodel.animation.AnimationPlayer", methodName="play", warmUp=true)
public final class WolfTrackPatch {
    @Patch.OnEnter
    public static void enter(@Patch.This Object player, @Patch.Argument(0) Object params,
                             @Patch.Local("garouTrack") Object saved) {
        saved=WolfRuntime.beginTrack(player,params);
    }
    @Patch.OnExit(onThrowable=Throwable.class)
    public static void exit(@Patch.Local("garouTrack") Object saved) {
        WolfRuntime.endTrack(saved);
    }
}
