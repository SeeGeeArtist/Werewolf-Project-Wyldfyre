package wtagarou.visuals;

import java.lang.reflect.Method;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.WeakHashMap;

/** Explicit, scoped bootstrap for the empty wolf clip map seen in 42.20.4.
 * Use ModelManager's normal asset registration/callbacks, not invented clips
 * or a global animation reload. Called on the game thread during preflight.
 * 0.4.70: Wolf_howl added -- this list is what populates the wolf rig's clip
 * map, so an authored clip missing from it is simply never loaded (the Oct
 * 18 "available=[...]" list lacked it and howls fell back to Wolf_eat). */
public final class WolfClipLoader {
    private static final String[] CLIPS = {"Wolf_idle","Wolf_walk","Wolf_run","Wolf_attack",
        "Wolf_hitreaction","Wolf_Sit","Wolf_eat","Wolf_death","Wolf_dead","Wolf_run_fourx","Wolf_Sit_idle","Wolf_getup","Wolf_howl"};
    private static final Map<Object,Map<String,Object>> REQUESTS=new WeakHashMap<>();
    private static volatile String status="not needed yet";

    @SuppressWarnings("unchecked")
    public static void ensure(Object manager, Object model) throws ReflectiveOperationException {
        if (model==null || !Boolean.TRUE.equals(Reflect.call(model,"isReady"))) return;
        Object skin=Reflect.get(model,"tag");
        if (skin==null) return;
        Map<String,Object> clips=(Map<String,Object>)Reflect.get(skin,"animationClips");
        if (clips==null) return;
        boolean complete=true;
        for (String clip:CLIPS) complete &= clips.get(clip)!=null;
        if (complete) { status="wolf clips ready"; return; }

        Class<?> scriptClass=Class.forName("zombie.scripting.ScriptManager");
        Object scripts=scriptClass.getField("instance").get(null);
        Object rig=Reflect.call(scripts,"getAnimationsMesh",String.class,"WTAGarou_Wolf");
        if (rig==null) throw new IllegalStateException("WTAGarou_Wolf animation rig absent");
        Object mesh=Reflect.get(rig,"modelMesh");
        if (mesh==null || !Boolean.TRUE.equals(Reflect.call(mesh,"isReady"))) return;
        // Do not import against one skeleton and insert into another.
        if (Reflect.get(model,"mesh")!=mesh || Reflect.get(mesh,"skinningData")!=skin)
            throw new IllegalStateException("wolf model and animation rig do not share the same skinning data");

        Class<?> meshClass=Class.forName("zombie.core.skinnedmodel.model.ModelMesh");
        Class<?> ownerClass=Class.forName("zombie.core.skinnedmodel.ModelManager$ModAnimations");
        Map<String,Object> owners=(Map<String,Object>)Reflect.get(manager,"modAnimations");
        Object owner=owners.get("WTAGarou");
        if (owner==null) {
            Object fs=Class.forName("zombie.ZomboidFileSystem").getField("instance").get(null);
            List<?> ids=(List<?>)Reflect.call(fs,"getModIDs");
            int index=ids.indexOf("WTAGarou");
            if (index<0) throw new IllegalStateException("WTAGarou is not an active mod");
            owner=ownerClass.getConstructor(String.class).newInstance("WTAGarou");
            Reflect.call(owner,"setPriority",int.class,index+1);
            owners.put("WTAGarou",owner);
        }
        if (!Boolean.TRUE.equals(Reflect.call(owner,"isActive")))
            throw new IllegalStateException("WTAGarou animation registration is inactive");
        Map<String,Object> registered=(Map<String,Object>)Reflect.get(owner,"animationAssetMap");
        Method load=manager.getClass().getDeclaredMethod("loadAnim",String.class,meshClass,ownerClass);
        load.setAccessible(true);
        Map<String,Object> requests=REQUESTS.computeIfAbsent(skin,k->new HashMap<>());
        int queued=0, ready=0;
        for (int i=0;i<CLIPS.length;i++) {
            String clip=CLIPS[i];
            if (clips.get(clip)!=null) { ready++; continue; }
            String path=("WTAGarouWolf/"+clip).toLowerCase(Locale.ROOT);
            Object asset=requests.get(path);
            if (asset==null) {
                asset=registered.get(path);
                if (asset==null) {
                    // Discovery may have skipped the folder; queue this known
                    // packaged path with the actual wolf skeleton.
                    asset=load.invoke(manager,path,mesh,owner);
                    queued++;
                }
                if (asset==null) throw new IllegalStateException("animation loader returned null: "+path);
                Object boundSkin=Reflect.get(asset,"skinningData");
                if (boundSkin!=skin) {
                    // Never relabel already-imported human bone indices as wolf.
                    // Correct only this mod's namespaced asset via native reimport.
                    Object params=Class.forName("zombie.core.skinnedmodel.model.AnimationAsset$AnimationAssetParams")
                            .getConstructor().newInstance();
                    Reflect.set(params,"animationsMesh",mesh);
                    Reflect.set(asset,"skinningData",skin);
                    Object loader=Class.forName("zombie.core.skinnedmodel.model.AnimationAssetManager")
                            .getField("instance").get(null);
                    loader.getClass().getMethod("reload",Class.forName("zombie.asset.Asset"),
                            Class.forName("zombie.asset.AssetManager$AssetParams")).invoke(loader,asset,params);
                    queued++;
                }
                requests.put(path,asset);
            }
            if (Boolean.TRUE.equals(Reflect.call(asset,"isFailure"))) {
                if (WolfAssets.required(clip)) throw new IllegalStateException("required wolf animation failed: "+path);
                continue; // Optional actions retain the established idle fallback.
            }
            if (Boolean.TRUE.equals(Reflect.call(asset,"isReady"))) {
                if (Reflect.get(asset,"skinningData")!=skin)
                    throw new IllegalStateException("wolf animation changed skeleton: "+path);
                Map<String,Object> imported=(Map<String,Object>)Reflect.get(asset,"animationClips");
                // A cached READY asset does not fire its completion callback
                // again; reinstall only the verified expected wolf clip.
                Object value=imported==null ? null : imported.get(clip);
                if (value!=null) { clips.put(clip,value); ready++; }
                else if (WolfAssets.required(clip)) throw new IllegalStateException("imported "+path+" without clip "+clip);
            }
        }
        String next="explicit wolf clips ready="+ready+"/"+CLIPS.length+"; tracked assets="+requests.size();
        if (!next.equals(status) || queued>0)
            System.out.println("[WTAGarou Java][WolfClips] "+next+"; queued this pass="+queued);
        status=next;
    }
    public static String status() { return status; }
}
