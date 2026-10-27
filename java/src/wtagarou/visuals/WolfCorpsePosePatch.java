package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** Never stamp a wolf skeleton (or fresh human idle) into the human corpse.
 * Leaving diedBoneTransforms absent selects the engine's native dead-body pose. */
@Patch(className="zombie.characters.IsoGameCharacter", methodName="canUseCurrentPoseForCorpse", warmUp=true)
public final class WolfCorpsePosePatch {
    @Patch.OnExit
    public static void exit(@Patch.This Object character,@Patch.Return(readOnly=false) boolean usePose) {
        if (WolfRuntime.corpseHandoff(character)) usePose=false;
    }
}
