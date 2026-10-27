package wtagarou.visuals;

import java.io.File;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;

/** Read-only asset preflight. Never force readiness, replace a skeleton or
 * borrow human clips merely to make the pending indicator disappear. */
public final class WolfAssets {
    private static final String[] REQUIRED = {
        "Wolf_idle", "Wolf_walk", "Wolf_run", "Wolf_attack", "Wolf_run_fourx", "Wolf_death"
    };
    public static boolean required(String clip) {
        for (String name:REQUIRED) if (name.equals(clip)) return true;
        return false;
    }
    public static final class Check {
        public final boolean ready, failed;
        public final String detail;
        Check(boolean ready, boolean failed, String detail) {
            this.ready=ready; this.failed=failed; this.detail=detail;
        }
    }
    private static Check blocked(Object asset, String label) throws ReflectiveOperationException {
        boolean failure=Boolean.TRUE.equals(Reflect.call(asset,"isFailure"));
        return new Check(false,failure,label+" state="+Reflect.call(asset,"getState"));
    }
    public static Check inspect(Object model) throws ReflectiveOperationException {
        if (model==null) return new Check(false,false,"model lookup returned null: WTAGarou_Lupus");
        if (!Boolean.TRUE.equals(Reflect.call(model,"isReady"))) {
            Check result=blocked(model,"model");
            Object mesh=Reflect.get(model,"mesh");
            return new Check(false,result.failed,result.detail+"; mesh="+
                    (mesh==null ? "null" : Reflect.call(mesh,"getState")));
        }
        Object texture=Reflect.get(model,"tex");
        if (texture==null) return new Check(false,true,"model ready; texture=null (Body/WTAGarou_Wolf_Timber)");
        if (!Boolean.TRUE.equals(Reflect.call(texture,"isReady"))) {
            Check result=blocked(texture,"texture");
            return new Check(false,result.failed,"model ready; "+result.detail);
        }
        Object data=Reflect.get(model,"tag");
        if (data==null) return new Check(false,true,"model/texture ready; skinning data=null");
        Object value=Reflect.get(data,"animationClips");
        if (!(value instanceof Map<?,?>))
            return new Check(false,true,"model/texture ready; animationClips is not a map");
        Map<?,?> clips=(Map<?,?>)value;
        List<String> missing=new ArrayList<>();
        for (String name:REQUIRED) if (clips.get(name)==null) missing.add(name);
        if (!missing.isEmpty()) {
            List<String> available=new ArrayList<>();
            for (Object name:clips.keySet()) available.add(String.valueOf(name));
            Collections.sort(available);
            int total=available.size();
            if (total>20) available=new ArrayList<>(available.subList(0,20));
            return new Check(false,false,"model/texture/skinning ready; missing clips="+missing+
                    "; clip count="+total+"; available="+available+(total>20 ? " (first 20)" : ""));
        }
        return new Check(true,false,"model, texture, skinning and required clips ready");
    }

    /** Called only on a changed blockage, not every frame/retry. Resolution
     * goes through the engine VFS; File only checks its resolved local path. */
    public static String sources() {
        StringBuilder result=new StringBuilder();
        try {
            Class<?> cls=Class.forName("zombie.scripting.ScriptManager");
            Object scripts=cls.getField("instance").get(null);
            Object script=Reflect.call(scripts,"getModelScript",String.class,"WTAGarou_Lupus");
            Object rig=Reflect.call(scripts,"getAnimationsMesh",String.class,"WTAGarou_Wolf");
            result.append("model script=").append(script==null ? "MISSING" : "present");
            result.append("; animation rig=").append(rig==null ? "MISSING" : "present");
            if (rig!=null) {
                Object mesh=Reflect.get(rig,"modelMesh");
                result.append("; rig mesh=").append(mesh==null ? "null" : Reflect.call(mesh,"getState"));
            }
        } catch (ReflectiveOperationException | RuntimeException error) {
            result.append("script probe unavailable: ").append(error);
        }
        try {
            Class<?> cls=Class.forName("zombie.ZomboidFileSystem");
            Object fs=cls.getField("instance").get(null);
            for (String path:new String[]{
                    "media/models_X/Skinned/WTAGarou_Wolf.glb",
                    "media/textures/Body/WTAGarou_Wolf_Timber.png",
                    "media/anims_X/WTAGarouWolf/Wolf_idle.glb",
                    "media/anims_X/WTAGarouWolf/Wolf_walk.glb",
                    "media/anims_X/WTAGarouWolf/Wolf_run.glb",
                    "media/anims_X/WTAGarouWolf/Wolf_attack.glb"}) {
                Object resolved=Reflect.call(fs,"getString",String.class,path);
                boolean exists=resolved instanceof String && new File((String)resolved).isFile();
                result.append("; ").append(path).append("=").append(exists ? "exists: " : "MISSING: ").append(resolved);
            }
        } catch (ReflectiveOperationException | RuntimeException error) {
            result.append("; VFS probe unavailable: ").append(error);
        }
        return result.toString();
    }
}
