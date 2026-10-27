package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** 0.4.69: IsoPlayer.pressedAttack() is the first call both the shove button
 *  and the attack button make after IsoPlayer.update stored meleePressed. */
@Patch(className="zombie.characters.IsoPlayer", methodName="pressedAttack", warmUp=true)
public final class CrinosSwingPatch {
    @Patch.OnEnter
    public static void enter(@Patch.This Object player) {
        CrinosSwingRuntime.onPressedAttack(player);
    }
}
