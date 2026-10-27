package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** Fresh, untainted, unpoisoned raw food skips raw-food poison only.
 * Rotten, tainted and explicitly poisoned meals retain all native effects.
 * Unhappiness, boredom, frozen-food penalties and nutrition are untouched. */
@Patch(className="zombie.characters.BodyDamage.BodyDamage", methodName="JustAteFood", warmUp=true)
public final class RawMeatPatch {
    @Patch.OnEnter
    public static void enter(@Patch.This Object bodyDamage, @Patch.Argument(0) Object food,
                             @Patch.Local("garouMeal") Object saved) {
        saved = TraitsRuntime.beforeMeal(bodyDamage, food);
    }
    @Patch.OnExit(onThrowable=Throwable.class)
    public static void exit(@Patch.Local("garouMeal") Object saved) {
        TraitsRuntime.afterMeal(saved);
    }
}
