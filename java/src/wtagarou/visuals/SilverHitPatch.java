package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** BodyDamage.applyDamageFromWeapon(int partIndex, float damage, int damageType, float pain)
 * is the single place a weapon wound lands on a chosen body part (B42.20.2).
 * Observe only; never alter the engine's choice or damage. */
@Patch(className="zombie.characters.BodyDamage.BodyDamage",
       methodName="applyDamageFromWeapon", warmUp=true)
public final class SilverHitPatch {
    @Patch.OnEnter
    public static void enter(@Patch.This Object bodyDamage, @Patch.Argument(0) int partIndex) {
        SilverHitRuntime.record(bodyDamage, partIndex);
    }
}
