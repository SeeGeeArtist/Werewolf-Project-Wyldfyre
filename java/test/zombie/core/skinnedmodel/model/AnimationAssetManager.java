package zombie.core.skinnedmodel.model;
import zombie.asset.Asset;
import zombie.asset.AssetManager;
/** TEST ONLY. Records targeted reimports rather than simulating real GLB import. */
public class AnimationAssetManager {
    public static final AnimationAssetManager instance=new AnimationAssetManager();
    public int reloads;
    public void reload(Asset base, AssetManager.AssetParams params) {
        AnimationAsset asset=(AnimationAsset)base;
        AnimationAsset.AnimationAssetParams animationParams=(AnimationAsset.AnimationAssetParams)params;
        if (asset.skinningData!=animationParams.animationsMesh.skinningData)
            throw new AssertionError("reload must target wolf skin");
        asset.ready=false; asset.failed=false; asset.animationClips.clear();
        reloads++;
    }
}
