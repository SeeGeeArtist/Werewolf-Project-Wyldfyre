package zombie.core.skinnedmodel.model;
import java.util.HashMap;
import java.util.Map;
import zombie.core.skinnedmodel.ModelManager;
/** TEST ONLY. */
public class AnimationAsset extends zombie.asset.Asset {
    public ModelManager.Data skinningData;
    public Map<String,Object> animationClips=new HashMap<>();
    public String modelManagerKey;
    public ModelManager.ModAnimations modAnimations;
    public static class AnimationAssetParams extends zombie.asset.AssetManager.AssetParams {
        public ModelMesh animationsMesh;
    }
}
