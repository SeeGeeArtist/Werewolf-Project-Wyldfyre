import zombie.asset.Asset;
import zombie.asset.AssetManager;
import zombie.asset.AssetPath;
import zombie.asset.AssetType;

/** Executes the supplied engine's actual AssetManager.load/cache implementation.
 * Only the leaf asset/import task is synthetic; no Assimp/OpenGL or game boot. */
public class EngineAssetCacheTest {
    static int checks;
    static void check(boolean value,String why) { checks++; if(!value) throw new AssertionError(why); }
    static class Params extends AssetManager.AssetParams {
        final boolean isStatic;
        Params(boolean value) { isStatic=value; }
    }
    static class Mesh extends Asset {
        static final AssetType TYPE=new AssetType("WTAGarouCacheTest");
        final boolean staticImport;
        Mesh(AssetPath path,AssetManager manager,Params params) {
            super(path,manager); staticImport=params.isStatic;
        }
        public AssetType getType() { return TYPE; }
    }
    static class Manager extends AssetManager {
        int created,started;
        protected Asset createAsset(AssetPath path,AssetParams params) {
            created++; return new Mesh(path,this,(Params)params);
        }
        protected void destroyAsset(Asset asset) {}
        protected void startLoading(Asset asset) { started++; }
        void complete(Asset asset) { onLoadingSucceeded(asset); }
    }
    public static void main(String[] args) {
        for(boolean firstStatic:new boolean[]{true,false}) {
            var manager=new Manager();
            var first=(Mesh)manager.load(new AssetPath("WTAGarou/WTAGarou_Harness"),new Params(firstStatic));
            var pending=(Mesh)manager.load(new AssetPath("WTAGarou/WTAGarou_Harness"),new Params(!firstStatic));
            check(first==pending && manager.created==1 && manager.started==1,
                    "pending cache reuses first request, not new import params");
            check(pending.staticImport==firstStatic,"first request fixes import mode while pending");
            manager.complete(first);
            check(first.isReady(),"native asset ready transition");
            var ready=(Mesh)manager.load(new AssetPath("WTAGarou/WTAGarou_Harness"),new Params(!firstStatic));
            check(first==ready && ready.staticImport==firstStatic && manager.created==1,
                    "ready mesh also ignores later opposite import params");
        }
        System.out.println("PASS: "+checks+" real-engine AssetManager cache assertions; synthetic leaf asset, no native import/render.");
    }
}
