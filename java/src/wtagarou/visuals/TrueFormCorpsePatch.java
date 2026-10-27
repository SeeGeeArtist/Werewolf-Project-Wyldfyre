package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;
@Patch(className="zombie.core.skinnedmodel.DeadBodyAtlas$BodyParams",methodName="init",warmUp=true)
public final class TrueFormCorpsePatch {
    @Patch.OnExit
    public static void exit(@Patch.This Object params,@Patch.Argument(0) Object body) {
        TrueFormCorpse.prepare(params,body);
    }
}
