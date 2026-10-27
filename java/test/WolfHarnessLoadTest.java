import java.util.HashMap;
import java.util.Map;
import net.bytebuddy.agent.ByteBuddyAgent;
import wtagarou.visuals.WolfHarnessLoadPatch;

/** Reproduces B42's two cache levels: Model key includes static/texture, mesh
 * key does not. Async mesh import params are fixed by the first request.
 * A fixture, not the native importer or an in-game render. */
public class WolfHarnessLoadTest {
    static int checks;
    static void check(boolean value,String why) { checks++; if(!value) throw new AssertionError(why); }
    public static class Mesh {
        final boolean staticImport;
        final Object skin;
        boolean ready;
        Mesh(boolean isStatic) { staticImport=isStatic; skin=isStatic ? null : new Object(); }
    }
    public static class Model {
        final Mesh mesh;
        final boolean isStatic;
        Model(Mesh mesh,boolean isStatic) { this.mesh=mesh; this.isStatic=isStatic; }
    }
    public static class Loader {
        public final Map<String,Mesh> meshes=new HashMap<>();
        public final Map<String,Model> models=new HashMap<>();
        public int scriptRequests,nativeCalls;
        public boolean fail;
        public Model getLoadedModel(String script) {
            scriptRequests++;
            if(fail) throw new IllegalStateException("fixture unavailable script");
            return load(script,false);
        }
        private Model load(String script,boolean isStatic) {
            if(script.startsWith("Base.")) script=script.substring(5);
            String mesh=script.startsWith("WTAGarou_Harness") ? "WTAGarou/WTAGarou_Harness" : script;
            String key=script+";static="+isStatic;
            Model model=models.get(key);
            if(model==null) {
                Mesh cached=meshes.computeIfAbsent(mesh,path -> new Mesh(isStatic));
                model=new Model(cached,isStatic); models.put(key,model);
            }
            return model;
        }
        // Control: the native loader requests the static model first.
        public Model nativeCarrier(String script) { nativeCalls++; return load(script,true); }
        public Model addStaticForcedTex(Object parent,String script,String self,String attachment,String tex) {
            return nativeCarrier(script);
        }
    }
    public static void main(String[] args) throws Exception {
        var control=new Loader();
        var staticFirst=control.nativeCarrier("WTAGarou_Harness");
        var broken=control.getLoadedModel("WTAGarou_Harness");
        check(!broken.isStatic && broken.mesh==staticFirst.mesh && broken.mesh.skin==null,
                "reproduce .34: nonstatic MODEL still shares a static-imported MESH with no skin");
        var patch=WolfHarnessLoadPatch.class.getAnnotation(me.zed_0xff.zombie_buddy.Patch.class);
        check("addStaticForcedTex".equals(patch.methodName()),"preload at carrier owning path");
        WolfCombatTest.install(ByteBuddyAgent.install(),Loader.class,WolfHarnessLoadPatch.class,patch.methodName());
        for(String first:new String[]{"WTAGarou_Harness","WTAGarou_Harness_Camo",
                "Base.WTAGarou_Harness","Base.WTAGarou_Harness_Camo"}) {
            var loader=new Loader();
            var carrier=loader.addStaticForcedTex(null,first,"self","WTAGarou_Harness",null);
            check(loader.scriptRequests==1 && loader.nativeCalls==1,"preload once, native allocation still runs");
            check(carrier.isStatic && !carrier.mesh.staticImport && carrier.mesh.skin!=null,
                    "native carrier cannot poison the harness mesh cache");
            check(!carrier.mesh.ready,"preload need not wait for async import completion");
            carrier.mesh.ready=true;
            var black=loader.getLoadedModel("WTAGarou_Harness");
            var camo=loader.getLoadedModel("WTAGarou_Harness_Camo");
            check(black.mesh==camo.mesh && black.mesh.skin!=null,"Black/Camo share the skin-preserving mesh");
            check(!black.isStatic && !camo.isStatic,"final render models remain skinned");
        }
        for(String other:new String[]{"WTAGarou_Saddlebags","WTAGarou_Saddlebags_Camo",
                "WTAGarou_CrinosHead","Hammer","WTAGarou_Harness_NotAllowed"}) {
            var loader=new Loader();
            var model=loader.addStaticForcedTex(null,other,null,null,null);
            check(loader.scriptRequests==0 && loader.nativeCalls==1 && model.mesh.staticImport,
                    "non-harness loader untouched: "+other);
        }
        var failure=new Loader(); failure.fail=true;
        failure.addStaticForcedTex(null,"WTAGarou_Harness",null,null,null);
        check(failure.nativeCalls==1,"preload error is contained; native loader is not globally replaced");
        System.out.println("PASS: "+checks+" harness static-first cache/preload/isolation assertions; not a game render.");
    }
}
