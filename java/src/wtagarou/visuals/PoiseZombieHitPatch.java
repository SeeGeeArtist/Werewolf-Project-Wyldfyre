package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** 0.4.68: zombie attacks (BodyDamage.AddRandomDamageFromZombie(zombie,
 *  hitReaction, partIndex), standing and crawling alike) bracket the flinch
 *  filter for the body's parent character. */
@Patch(className="zombie.characters.BodyDamage.BodyDamage", methodName="AddRandomDamageFromZombie", warmUp=true)
public final class PoiseZombieHitPatch {
    @Patch.OnEnter
    public static void enter(@Patch.This Object body) {
        PoiseRuntime.beginHit(parent(body), null);
    }
    @Patch.OnExit
    public static void exit(@Patch.This Object body) {
        PoiseRuntime.endHit(parent(body));
    }
    public static Object parent(Object body) {
        try { return Reflect.call(body, "getParentChar"); }
        catch (ReflectiveOperationException e) { return null; }
    }
}
