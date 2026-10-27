package wtagarou.visuals;

import me.zed_0xff.zombie_buddy.Patch;

/** A weak key is not a lifetime token: ModelInstance objects are pooled. */
@Patch(className="zombie.core.skinnedmodel.model.ModelInstance", methodName="reset", warmUp=true)
public final class WolfAttachmentResetPatch {
    @Patch.OnEnter
    public static void enter(@Patch.This Object instance) {
        WolfRuntime.forgetSubmodel(instance);
        CrinosCosmetics.forget(instance);
    }
}
