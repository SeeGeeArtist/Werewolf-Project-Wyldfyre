package wtagarou.visuals;

import java.util.Collections;
import java.util.Map;
import java.util.HashSet;
import java.util.Set;
import java.util.WeakHashMap;

/** Converts only our attached-item carrier to a skinned, body-space instance.
 * StaticModel on an InventoryItem routes through a static loader in native
 * ModelManager; a static=false script alone is not sufficient for that route.
 * Never mutate a shared Model, skeleton, texture or AnimationPlayer. */
public final class WolfHarness {
    private static final String[] FIELDS = {
        "model", "data", "tex", "animPlayer", "parentBoneName",
        "parentBone", "attachmentNameSelf", "scale"
    };
    private static final Map<Object,Object[]> ORIGINAL =
            Collections.synchronizedMap(new WeakHashMap<>());
    public static volatile boolean initObserved;
    private static int logs;
    private static int scaleLogs;
    private static float lastScale=Float.NaN;
    private static final Set<String> REPORTED = Collections.synchronizedSet(new HashSet<>());

    /** Constant reason keys keep repeated render checks from flooding console. */
    private static boolean waiting(String reason, Object detail) {
        if (REPORTED.add(reason)) System.out.println("[WTAGarou Java][Harness] waiting: "
                +reason+"; "+detail);
        return false;
    }

    private static String harnessScript(String name) {
        if (name==null) return null;
        if (name.startsWith("Base.")) name=name.substring(5);
        return name.equals("WTAGarou_Harness") || name.equals("WTAGarou_Harness_Camo") ? name : null;
    }

    public static void noteScale(float factor) {
        if (factor!=lastScale && scaleLogs<8) {
            lastScale=factor; scaleLogs++;
            System.out.println("[WTAGarou Java][Harness] skinned draw scale="+factor
                    +"; same body normalization/form scale; no static matrix scaling");
        }
    }

    /** Must run before the FIRST static carrier load, even in a preview.
     * AssetManager.load reuses mesh-name entries regardless of new params;
     * changing Model.isStatic later cannot recover discarded skin data.
     * Requesting an asynchronous skinned load is enough to claim the cache
     * entry. Never reload/mutate a shared mesh or borrow the wolf's skin data. */
    public static void beforeCarrierLoad(Object manager, String script) {
        String name=harnessScript(script);
        if (name==null) return;
        try {
            Object model=Reflect.call(manager,"getLoadedModel",String.class,name);
            if (model==null) { waiting("preload missing model",name); return; }
            if (REPORTED.add("preload "+name))
                System.out.println("[WTAGarou Java][Harness] skinned mesh requested BEFORE static carrier: "+name);
        } catch (ReflectiveOperationException | RuntimeException error) {
            WolfRuntime.warn("harness mesh preload",error);
        }
    }

    public static boolean carrier(Object instance) throws ReflectiveOperationException {
        return instance!=null && WolfRuntime.HARNESS_ATTACHMENT.equals(
                Reflect.get(instance,"attachmentNameParent"));
    }

    /** Called BEFORE render-data init takes its skin-transform palette.
     * Native getSkinTransforms(harness.tag) remaps the harness joint order;
     * substituting wolf.tag would silently assign weights to wrong bones. */
    public static boolean prepare(Object instance) {
        try {
            if (!carrier(instance)) { restore(instance); return false; }
            Object body=Reflect.get(instance,"parent");
            if (body==null) return waiting("parent", "carrier has no parent");
            Object character=Reflect.get(body,"character");
            if (!WolfRuntime.active(character)
                    || Reflect.get(body,"model")!=WolfRuntime.modelFor(character)) {
                restore(instance);
                return waiting("wolf body", "parent is not the active wolf model");
            }
            Object anim=Reflect.get(body,"animPlayer");
            if (anim==null) return waiting("animator", "wolf animator is not ready");
            Object script=Reflect.get(instance,"modelScript");
            String rawName=script==null ? "" : String.valueOf(Reflect.get(script,"name"));
            String name=harnessScript(rawName);
            if (name==null) {
                restore(instance);
                return waiting("script", "unexpected modelScript.name="+rawName);
            }
            Object manager=Class.forName("zombie.core.skinnedmodel.ModelManager").getField("instance").get(null);
            Object model=Reflect.call(manager,"getLoadedModel",String.class,name);
            if (model==null || !Boolean.TRUE.equals(Reflect.call(model,"isReady")))
                return waiting("model", name);
            if (Boolean.TRUE.equals(Reflect.get(model,"isStatic")))
                return waiting("static model", name+" must load static=false");
            Object mesh=Reflect.get(model,"mesh"), skin=Reflect.get(model,"tag"), tex=Reflect.get(model,"tex");
            if (mesh==null || skin==null || tex==null
                    || !Boolean.TRUE.equals(Reflect.call(mesh,"isReady"))
                    || !Boolean.TRUE.equals(Reflect.call(tex,"isReady")))
                return waiting("mesh/skin/texture", name+" mesh="+(mesh!=null)
                        +" skin="+(skin!=null)+" texture="+(tex!=null)
                        +" meshSkin="+(mesh!=null && Reflect.get(mesh,"skinningData")!=null));
            if (!ORIGINAL.containsKey(instance)) {
                // Preflight every field before changing anything.
                Object[] values=new Object[FIELDS.length];
                for (int i=0;i<FIELDS.length;i++) values[i]=Reflect.get(instance,FIELDS[i]);
                ORIGINAL.put(instance,values);
                if (logs++<8) System.out.println("[WTAGarou Java][Harness] skinned "+name
                        +"; own skin data; shared wolf animator; no rigid mount");
            }
            Reflect.set(instance,"model",model);
            Reflect.set(instance,"data",skin);
            Reflect.set(instance,"tex",tex);
            Reflect.set(instance,"animPlayer",anim);
            Reflect.set(instance,"parentBoneName",null);
            Reflect.set(instance,"parentBone",-1);
            Reflect.set(instance,"attachmentNameSelf",null);
            // Mesh and bone coordinates already match the authored wolf.
            // BODY_SCALE * form scale is applied once by ScaleRuntime,
            // like the wolf body. A skinned shader does not consume xfrm.
            Reflect.set(instance,"scale",1f);
            return true;
        } catch (ReflectiveOperationException | RuntimeException error) {
            restore(instance);
            WolfRuntime.warn("skinned harness",error);
            return false;
        }
    }
    public static void beforeInit(Object instance) {
        if (!initObserved) {
            initObserved=true;
            System.out.println("[WTAGarou Java][Harness] initModel hook reached before skin palette");
        }
        try { if (carrier(instance) || ORIGINAL.containsKey(instance)) prepare(instance); }
        catch (ReflectiveOperationException | RuntimeException error) { WolfRuntime.warn("harness init",error); }
    }
    public static void restore(Object instance) {
        Object[] values=ORIGINAL.remove(instance);
        if (values==null) return;
        for (int i=0;i<FIELDS.length;i++) try { Reflect.set(instance,FIELDS[i],values[i]); }
        catch (ReflectiveOperationException | RuntimeException error) { WolfRuntime.warn("harness restore",error); }
    }
    public static void restoreAll() {
        Object[] instances;
        synchronized (ORIGINAL) { instances=ORIGINAL.keySet().toArray(); }
        for (Object instance:instances) restore(instance);
    }
    /** Pool reset has already replaced the fields: discard, never restore. */
    public static void forget(Object instance) { ORIGINAL.remove(instance); }
}
