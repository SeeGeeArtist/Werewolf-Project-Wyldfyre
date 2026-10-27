package wtagarou.visuals;

import java.util.Map;

/** Corpse atlas snapshots only. Never modifies saved HumanVisual, corpse loot,
 * player death timing, reanimation, or the living animation graph. */
public final class TrueFormCorpse {
    public static final String ANIM_SET="WTAGarouCorpse";
    private static Object value(Object table,String key) throws ReflectiveOperationException {
        return table==null ? null : Reflect.call(table,"rawget",Object.class,key);
    }
    public static boolean wolfBorn(Object body) throws ReflectiveOperationException {
        Object data=value(Reflect.call(body,"getModData"),"WTAGarou");
        return Boolean.TRUE.equals(value(data,"isGarou")) && "Lupus".equals(value(data,"trueForm"));
    }
    public static String coatPath(Object body) throws ReflectiveOperationException {
        Object data=value(Reflect.call(body,"getModData"),"WTAGarou");
        Object saved=value(data,"wolfCoatTexture");
        if(saved instanceof String path &&
                path.matches("media/textures/Body/WTAGarou_Wolf(?:_[A-Za-z0-9_-]+)?\\.png")) return path;
        return "media/textures/Body/WTAGarou_Wolf_Timber.png";
    }
    /** All init overloads are woven; only a real dead-body input is eligible. */
    public static void prepare(Object params,Object body) {
        if(body==null || !body.getClass().getName().equals("zombie.iso.objects.IsoDeadBody")) return;
        try {
            if(!wolfBorn(body) || Boolean.TRUE.equals(Reflect.call(body,"isSkeleton"))) return;
            Object manager=Class.forName("zombie.core.skinnedmodel.ModelManager").getField("instance").get(null);
            Object model=Reflect.call(manager,"getLoadedModel",String.class,"WTAGarou_Lupus");
            WolfClipLoader.ensure(manager,model);
            if(model==null || !Boolean.TRUE.equals(Reflect.call(model,"isReady"))
                    || !Boolean.TRUE.equals(Reflect.call(Reflect.get(model,"mesh"),"isReady"))) return;
            Map<?,?> clips=(Map<?,?>)Reflect.get(Reflect.get(model,"tag"),"animationClips");
            if(!clips.containsKey("Wolf_dead")) return;
            String path=coatPath(body);
            Object texture=Class.forName("zombie.core.textures.Texture").getMethod("getSharedTexture",String.class).invoke(null,path);
            if(texture==null || !Boolean.TRUE.equals(Reflect.call(texture,"isReady"))) return;
            Class<?> human=Class.forName("zombie.core.skinnedmodel.visual.HumanVisual");
            Class<?> base=Class.forName("zombie.core.skinnedmodel.visual.BaseVisual");
            Class<?> owner=Class.forName("zombie.core.skinnedmodel.visual.IHumanVisual");
            Object snapshot=human.getConstructor(owner).newInstance(body);
            Reflect.call(snapshot,"copyFrom",base,Reflect.get(params,"baseVisual"));
            Reflect.call(snapshot,"setForceModel",Class.forName("zombie.core.skinnedmodel.model.Model"),model);
            Reflect.call(snapshot,"setForceModelScript",String.class,"WTAGarou_Lupus");
            Reflect.call(snapshot,"setSkinTextureName",String.class,path.substring("media/textures/Body/".length(),path.length()-4));
            // Null/unknown styles are randomized by HumanVisual getters.
            // Empty is native bald/no-beard, not a request for random hair.
            Reflect.call(snapshot,"setHairModel",String.class,"");
            Reflect.call(snapshot,"setBeardModel",String.class,"");
            Class<?> color=Class.forName("zombie.core.ImmutableColor");
            Reflect.call(snapshot,"setSkinColor",color,color.getField("white").get(null));
            Reflect.call(Reflect.call(snapshot,"getBodyVisuals"),"clear");
            // Preflight every changed field before touching the render request.
            for(String f:new String[]{"baseVisual","animSetName","stateName","trackTime","diedBoneTransforms",
                    "primaryHandItem","secondaryHandItem","itemVisuals","attachedModelNames","grappleable","ragdollFall"})
                Reflect.field(params.getClass(),f);
            Reflect.call(Reflect.get(params,"itemVisuals"),"clear");
            Reflect.call(Reflect.get(params,"attachedModelNames"),"clear");
            Reflect.set(params,"baseVisual",snapshot);
            Reflect.set(params,"animSetName",ANIM_SET);
            Reflect.set(params,"stateName","deadbody");
            Reflect.set(params,"trackTime",0f);
            Reflect.set(params,"diedBoneTransforms",null); // never apply a human ragdoll to wolf bones
            Reflect.set(params,"primaryHandItem",null);
            Reflect.set(params,"secondaryHandItem",null);
            Reflect.set(params,"grappleable",null);
            Reflect.set(params,"ragdollFall",false);
        } catch(ReflectiveOperationException | RuntimeException e) { WolfRuntime.warn("true-form corpse snapshot",e); }
    }
    /** Native atlas has its own AnimatedModel, separate from DrawChar scaling. */
    public static void size(Object animated) {
        try {
            if(!ANIM_SET.equals(Reflect.call(animated,"GetAnimSetName"))) return;
            Object instance=Reflect.get(animated,"modelInstance");
            if(instance!=null) Reflect.set(instance,"scale",WolfRuntime.BODY_SCALE);
            WolfRuntime.enforceRig(Reflect.call(animated,"getAnimationPlayer"));
        } catch(ReflectiveOperationException | RuntimeException e) { WolfRuntime.warn("true-form corpse size",e); }
    }
}
