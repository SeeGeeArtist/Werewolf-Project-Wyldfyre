package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

@Patch(className="zombie.CombatManager", methodName="applyDamage", warmUp=true)
public final class SilverBurnDamagePatch {
    @Patch.OnEnter
    public static void enter(@Patch.Argument(0) Object target,
            @Patch.Argument(value=1,readOnly=false) float damage) {
        damage=SilverBurnRuntime.damage(target,damage);
    }
}
