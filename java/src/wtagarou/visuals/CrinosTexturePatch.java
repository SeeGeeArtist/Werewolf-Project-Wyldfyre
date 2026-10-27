package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;
@Patch(className="zombie.core.skinnedmodel.model.ModelInstanceTextureCreator",methodName="init",warmUp=true)
public final class CrinosTexturePatch {
    @Patch.OnExit
    public static void exit(@Patch.This Object creator) {
        CrinosCosmetics.texture(creator);
    }
}
