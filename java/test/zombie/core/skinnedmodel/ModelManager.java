package zombie.core.skinnedmodel;
import java.util.HashMap;
import java.util.Map;
import zombie.core.skinnedmodel.model.Model;
import zombie.core.skinnedmodel.model.ModelMesh;
import zombie.core.skinnedmodel.model.AnimationAsset;

/** TEST ONLY. Not the game engine. */
public class ModelManager {
    public static final ModelManager instance = new ModelManager();
    public static class AssetState {
        public boolean ready=true, failed=false;
        public boolean isReady() { return ready && !failed; }
        public boolean isFailure() { return failed; }
        public String getState() { return failed ? "FAILURE" : ready ? "READY" : "EMPTY"; }
    }
    public static class Texture extends AssetState {}
    public static class Data extends zombie.core.skinnedmodel.model.SkinningData {
        public Map<String,Object> animationClips=new HashMap<>();
        public Map<String,Integer> boneIndices=new HashMap<>();
    }
    public static class TestModel extends Model {
        public boolean isStatic;
        public boolean ready=true;
        public boolean failed=false;
        public Texture tex=new Texture();
        public Data tag=new Data();
        public ModelMesh mesh=new ModelMesh(tag);
        public TestModel() {
            for (String name : new String[]{"Wolf_idle","Wolf_walk","Wolf_run","Wolf_attack",
                    "Wolf_hitreaction","Wolf_Sit","Wolf_eat","Wolf_death","Wolf_dead","Wolf_run_fourx"})
                tag.animationClips.put(name,new Object());
            tag.boneIndices.put("Bip01",0);
            tag.boneIndices.put("Bip01_Spine",1);
        }
        public boolean isReady() { return ready && !failed; }
        public boolean isFailure() { return failed; }
        public String getState() { return failed ? "FAILURE" : ready ? "READY" : "EMPTY"; }
    }
    public TestModel wolf=new TestModel();
    public TestModel crinosHead=new TestModel();
    public TestModel harness=new TestModel(), harnessCamo=new TestModel();
    public zombie.core.skinnedmodel.model.ModelInstance addStaticForcedTex(
            zombie.core.skinnedmodel.model.ModelInstance parent,String model,String self,String attachment,String tex) {
        if(!model.equals("WTAGarou_CrinosHead")
                || !(self.equals("mount") || self.equals("mount_direct")) || attachment!=null || tex!=null)
            throw new AssertionError("unexpected Crinos attachment");
        var inst=new zombie.core.skinnedmodel.model.ModelInstance();
        inst.parent=parent; inst.model=crinosHead;
        inst.attachmentNameSelf=self; inst.scale=.6f;
        parent.sub.add(inst); return inst;
    }
    public Model human=new Model();
    /** 0.4.67 fixtures: skinned clothing-style models keyed like the engine. */
    public final Map<String,TestModel> skinned=new HashMap<>();
    public final java.util.List<String> skinnedLoads=new java.util.ArrayList<>();
    public boolean skinnedReady=true;
    private String key(String mesh,String tex,boolean isStatic,String shader) { return mesh+"|"+tex+"|"+isStatic+"|"+shader; }
    public Model tryGetLoadedModel(String mesh,String tex,boolean isStatic,String shader,boolean logError) {
        return skinned.get(key(mesh,tex,isStatic,shader));
    }
    public Model getLoadedModel(String mesh,String tex,boolean isStatic,String shader) {
        return tryGetLoadedModel(mesh,tex,isStatic,shader,true);
    }
    public void loadAdditionalModel(String mesh,String tex,boolean isStatic,String shader) {
        if (isStatic || shader!=null) throw new AssertionError("legs/tail must load skinned, default shader");
        if (!mesh.startsWith("media/models_x/skinned/clothes/wtagarou_crinos") || !mesh.endsWith(".glb"))
            throw new AssertionError("unexpected skinned mesh "+mesh);
        if (!tex.startsWith("Body/WTAGarou_Crinos") && !tex.startsWith("Body/WTAGarou_Wolf_")) throw new AssertionError("unexpected part texture "+tex);
        skinnedLoads.add(mesh+"|"+tex);
        TestModel m=new TestModel(); m.ready=skinnedReady;
        skinned.put(key(mesh,tex,isStatic,shader),m);
    }
    public zombie.core.skinnedmodel.model.ModelInstance newAdditionalModelInstance(
            String mesh,String tex,zombie.characters.IsoGameCharacter chr,
            zombie.core.skinnedmodel.animation.AnimationPlayer anim,String shader) {
        Model m=tryGetLoadedModel(mesh,tex,false,shader,false);
        if (m==null) { loadAdditionalModel(mesh,tex,false,shader); m=tryGetLoadedModel(mesh,tex,false,shader,false); }
        var inst=new zombie.core.skinnedmodel.model.ModelInstance();
        inst.model=m; inst.character=chr; inst.animPlayer=anim; inst.meshName=mesh; inst.texName=tex;
        return inst;
    }
    public int getTextureFlags() { return 4; }
    public TestModel maleModel=new TestModel();
    public void Reset(Object character) {}
    public Map<String,ModAnimations> modAnimations=new HashMap<>();
    public int loads;
    public static final class ModAnimations {
        public final String modId;
        public int priority;
        public Map<String,AnimationAsset> animationAssetMap=new HashMap<>();
        public ModAnimations(String id) { modId=id; }
        public void setPriority(int value) { priority=value; }
        public boolean isActive() { return priority!=-1; }
    }
    private AnimationAsset loadAnim(String path, ModelMesh mesh, ModAnimations owner) {
        loads++;
        if (!path.startsWith("wtagarouwolf/")) throw new AssertionError("foreign path");
        if (mesh!=wolf.mesh || !owner.modId.equals("WTAGarou")) throw new AssertionError("foreign ownership");
        AnimationAsset asset=new AnimationAsset();
        asset.skinningData=mesh.skinningData;
        asset.modelManagerKey=path;
        asset.modAnimations=owner;
        owner.animationAssetMap.put(path,asset);
        return asset;
    }
    public Object getLoadedModel(String script) {
        if ("WTAGarou_Harness".equals(script)) return harness;
        if ("WTAGarou_Harness_Camo".equals(script)) return harnessCamo;
        if ("WTAGarou_CrinosHead".equals(script)) return crinosHead;
        if (!"WTAGarou_Lupus".equals(script)) throw new IllegalArgumentException(script);
        return wolf;
    }
    public Model getBodyModel(Object character) { return human; }
}
