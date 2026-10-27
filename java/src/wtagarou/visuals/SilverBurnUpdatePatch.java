package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

@Patch(className="zombie.characters.BodyDamage.BodyPart", methodName="DamageUpdate", warmUp=true)
public final class SilverBurnUpdatePatch {
    @Patch.OnEnter
    public static void enter(@Patch.This Object part,@Patch.Local("silverScope") Object previous) {
        previous=SilverBurnRuntime.begin(part);
    }
    @Patch.OnExit(onThrowable=Throwable.class)
    public static void exit(@Patch.Local("silverScope") Object previous) { SilverBurnRuntime.end(previous); }
}
