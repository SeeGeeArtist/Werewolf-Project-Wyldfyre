package wtagarou.visuals;

import java.util.*;
import java.lang.ref.WeakReference;

/** Render-only human-rig prototype. Never edits saved HumanVisual or inventory.
 * Static head/collar, plus (0.4.67) skinned digitigrade legs and an optional
 * tail that ride the body's own AnimationPlayer exactly like worn clothing
 * meshes do, without any inventory item behind them. */
public final class CrinosCosmetics {
    public static final String MODEL="WTAGarou_CrinosHead";
    /** 0.4.67: skinned sub-meshes (vanilla Bip01 rig) shipped in
     *  common/media/models_X/Skinned/Clothes/. Lower-case, forward-slash
     *  names are what PopTemplateManager hands ModelManager for clothing. */
    /** 0.4.94: unisex - one legs mesh and one tail mesh for both sexes (the
     *  author exports a single model; the vanilla body under them differs). */
    public static final String LEGS_MESH="media/models_x/skinned/clothes/wtagarou_crinoslegs";
    public static final String TAIL_MESH="media/models_x/skinned/clothes/wtagarou_crinostail";
    /** Mask set that hides the human legs/feet and extends the crotch/waist
     *  cut so the digitigrade mesh meets the body without a seam. */
    /** 42.20+: zombie.core.skinnedmodel.animation (0.4.67 named the pre-42.13
     *  advancedanimation package and the parts never mounted). */
    public static final String ANIM_PLAYER_CLASS="zombie.core.skinnedmodel.animation.AnimationPlayer";
    /** 0.4.90: own generated GLB meshes (tools/build_crinos_parts.py); the vanilla mask set applies. */
    public static final String MESH_EXT=".glb";
    private static final Map<Object,Profile> PROFILES=Collections.synchronizedMap(new WeakHashMap<>());
    private static final Map<Object,Mount> BODIES=Collections.synchronizedMap(new WeakHashMap<>());
    private static final Set<String> WARNED=java.util.concurrent.ConcurrentHashMap.newKeySet();
    /** legs / tail: Body/ texture names (0.4.94: the coat's CrinosBody_* sheet for the legs,
     *  the coat's Wolf_* sheet for the tail) or null. */
    public record Profile(String body,String head,String legs,String tail) {
        public Profile(String body,String head) { this(body,head,null,null); }
        public boolean hasLegs() { return legs!=null; }
        public boolean hasTail() { return tail!=null; }
    }
    private record Mount(WeakReference<Object> character,Profile profile) {}

    public static boolean valid(String name,String kind) {
        if (name==null) return false;
        // 0.4.69: the digitigrade legs mesh is UV-mapped on the vanilla body
        // atlas, so the coat's CrinosBody texture is its texture (the baked
        // CrinosLegs_* PNGs were redundant and are gone).
        if ("Legs".equals(kind) && name.matches("WTAGarou_CrinosBody_[A-Za-z0-9_-]+")) return true;
        // 0.4.94: the tail mesh is UV-mapped on the wolf atlas, so the coat's
        // Wolf texture is its texture (same sheet as the Crinos head).
        if ("Tail".equals(kind) && name.matches("WTAGarou_Wolf_[A-Za-z0-9_-]+")) return true;
        return name.matches("WTAGarou_Crinos"+kind+"_[A-Za-z0-9_-]+");
    }
    public static boolean validHead(String name) {
        // Keep legacy custom heads valid, but shipped heads now use wolf UVs.
        return valid(name,"Head")
                || (name!=null && name.matches("WTAGarou_Wolf_[A-Za-z0-9_-]+"));
    }
    /** 0.4.59: start loading the Crinos head model and the coat textures
     *  without mounting anything, so the first shift finds them ready.
     *  "ready" | "pending" | "failed" (invalid names). */
    public static String preload(String body,String head) {
        if (!valid(body,"Body") || !validHead(head)) return "failed";
        try {
            Object model=Reflect.call(manager(),"getLoadedModel",String.class,MODEL);
            boolean modelReady=model!=null && Boolean.TRUE.equals(Reflect.call(model,"isReady"))
                    && Boolean.TRUE.equals(Reflect.call(Reflect.get(model,"mesh"),"isReady"));
            boolean bodyReady=textureReady(body);
            boolean headReady=textureReady(head);
            return modelReady && bodyReady && headReady ? "ready" : "pending";
        } catch (ReflectiveOperationException | RuntimeException e) { warn("preload",e); return "failed"; }
    }
    public static String set(Object chr,boolean enabled,String body,String head) {
        return set(chr,enabled,body,head,null,null);
    }
    /** 0.4.67: legs / tail are Body/ texture names or null/"" for none. The
     *  skinned meshes are warmed here (async) and the request stays
     *  "pending" until they and their coat textures are resident, so a
     *  shift never shows a half-built body. */
    public static String set(Object chr,boolean enabled,String body,String head,String legs,String tail) {
        if (chr==null) return "failed";
        if (!enabled) { clear(chr); return "human"; }
        if (legs!=null && legs.isEmpty()) legs=null;
        if (tail!=null && tail.isEmpty()) tail=null;
        if (!valid(body,"Body") || !validHead(head)
                || (legs!=null && !valid(legs,"Legs")) || (tail!=null && !valid(tail,"Tail"))) { clear(chr); return "failed"; }
        Profile want=new Profile(body,head,legs,tail);
        if (want.equals(PROFILES.get(chr))) return "crinos";
        try {
            Object manager=manager();
            Object model=Reflect.call(manager,"getLoadedModel",String.class,MODEL);
            if (model==null || !Boolean.TRUE.equals(Reflect.call(model,"isReady"))
                    || !Boolean.TRUE.equals(Reflect.call(Reflect.get(model,"mesh"),"isReady"))
                    || !textureReady(body) || !textureReady(head)) return "pending";
            if (legs!=null && !skinnedReady(LEGS_MESH+MESH_EXT,"Body/"+legs)) return "pending";
            if (tail!=null && !skinnedReady(TAIL_MESH+MESH_EXT,"Body/"+tail)) return "pending";
            forgetCharacter(chr);
            PROFILES.put(chr,want);
            Reflect.call(chr,"resetModelNextFrame");
            refreshTextures(chr);
            CrinosFaceVisuals.reportSaved(chr,true);
            return "crinos";
        } catch (ReflectiveOperationException | RuntimeException e) {
            clear(chr); warn("activate",e); return "failed";
        }
    }
    private static Object manager() throws ReflectiveOperationException {
        return Class.forName("zombie.core.skinnedmodel.ModelManager").getField("instance").get(null);
    }
    static boolean isFemale(Object chr) {
        try { return Boolean.TRUE.equals(Reflect.call(chr,"isFemale")); }
        catch (ReflectiveOperationException | RuntimeException e) { return false; }
    }
    /** Start (once) and poll the async load of a skinned clothing-style mesh
     *  with the given Body/ texture, the same ModelManager key the engine
     *  uses for worn items. */
    private static boolean skinnedReady(String mesh,String tex) throws ReflectiveOperationException {
        Object manager=manager();
        Class<?>[] sig={String.class,String.class,boolean.class,String.class,boolean.class};
        Object model=Reflect.call(manager,"tryGetLoadedModel",sig,mesh,tex,false,null,false);
        if (model==null) {
            Reflect.call(manager,"loadAdditionalModel",new Class<?>[]{String.class,String.class,boolean.class,String.class},
                    mesh,tex,false,null);
            model=Reflect.call(manager,"tryGetLoadedModel",sig,mesh,tex,false,null,false);
        }
        return model!=null && Boolean.TRUE.equals(Reflect.call(model,"isReady"));
    }
    /** 0.4.67: warm legs/tail meshes + textures for one coat without mounting.
     *  The female flag is kept for the Lua call signature; meshes are unisex (0.4.94). */
    public static String preloadParts(String legs,String tail,boolean female) {
        if (legs!=null && legs.isEmpty()) legs=null;
        if (tail!=null && tail.isEmpty()) tail=null;
        if ((legs!=null && !valid(legs,"Legs")) || (tail!=null && !valid(tail,"Tail"))) return "failed";
        try {
            boolean ready=true;
            if (legs!=null && !skinnedReady(LEGS_MESH+MESH_EXT,"Body/"+legs)) ready=false;
            if (tail!=null && !skinnedReady(TAIL_MESH+MESH_EXT,"Body/"+tail)) ready=false;
            return ready ? "ready" : "pending";
        } catch (ReflectiveOperationException | RuntimeException e) { warn("preload parts",e); return "failed"; }
    }
    private static boolean textureReady(String name) throws ReflectiveOperationException {
        Object tex=textureWithFlags("media/textures/Body/"+name+".png");
        return tex!=null && Boolean.TRUE.equals(Reflect.call(tex,"isReady"));
    }
    private static Object textureWithFlags(String path) throws ReflectiveOperationException {
        int flags=((Number)Reflect.call(manager(),"getTextureFlags")).intValue();
        return Class.forName("zombie.core.textures.Texture")
                .getMethod("getSharedTexture",String.class,int.class).invoke(null,path,flags);
    }
    public static void clear(Object chr) {
        boolean wasActive=PROFILES.remove(chr)!=null;
        // Render references can delay ModelInstance.reset(). Invalidate now,
        // not only when native recycling eventually reaches the reset hook.
        forgetCharacter(chr);
        if (wasActive) try {
            Reflect.call(chr,"resetModelNextFrame");
            refreshTextures(chr);
            CrinosFaceVisuals.reportSaved(chr,false);
        }
        catch (ReflectiveOperationException | RuntimeException e) { warn("clear",e); }
    }
    private static void refreshTextures(Object chr) {
        try { Reflect.call(chr,"postUpdateModelTextures"); }
        catch (ReflectiveOperationException | RuntimeException e) { warn("texture refresh",e); }
    }
    private static void forgetCharacter(Object chr) {
        synchronized(BODIES) {
            BODIES.entrySet().removeIf(e -> e.getValue().character().get()==chr
                    || e.getValue().character().get()==null);
        }
    }
    private static Profile bodyProfile(Object body) {
        if(body==null) return null;
        Mount mount=BODIES.get(body);
        if(mount==null) return null;
        Object chr=mount.character().get();
        return chr!=null && mount.profile().equals(PROFILES.get(chr))
                && !WolfRuntime.active(chr) ? mount.profile() : null;
    }
    public static void clearAll() {
        Object[] all;
        synchronized(PROFILES) { all=PROFILES.keySet().toArray(); }
        for(Object chr:all) clear(chr);
    }
    public static void forget(Object instance) { BODIES.remove(instance); }
    public static boolean active(Object chr) { return chr!=null && PROFILES.containsKey(chr); }
    /** 0.4.69: digitigrade legs requested for this character (mounted or not). */
    public static boolean legsActive(Object chr) {
        Profile p=chr==null?null:PROFILES.get(chr);
        return p!=null && p.hasLegs() && !WolfRuntime.active(chr);
    }
    public static boolean ownsBody(Object body) { return bodyProfile(body)!=null; }
    /** Executed before vanilla hair/clothes population, on a fresh native slot. */
    public static void addHead(Object chr,Object slot) {
        Profile profile=PROFILES.get(chr);
        if (profile==null || WolfRuntime.active(chr)) return;
        try {
            Object body=Reflect.get(slot,"model");
            if (body==null || ownsBody(body)) return;
            Object anim=Reflect.get(body,"animPlayer");
            if (anim==null) return;
            int bone=((Number)Reflect.call(anim,"getSkinningBoneIndex",
                    new Class<?>[]{String.class,int.class},"Bip01_Head",-1)).intValue();
            if (bone<0) return; // no invisible human head if the mount cannot exist
            String mount=attachmentName();
            Object inst=Reflect.call(manager(),"addStaticForcedTex",
                    new Class<?>[]{Class.forName("zombie.core.skinnedmodel.model.ModelInstance"),
                            String.class,String.class,String.class,String.class},
                    body,MODEL,mount,null,null);
            if (inst==null) return;
            // Reuse the preflighted mesh; do not start a second async model
            // load merely to change coats. Texture belongs to this instance.
            Object tex=textureWithFlags("media/textures/Body/"+profile.head()+".png");
            Reflect.set(inst,"tex",tex);
            Reflect.set(inst,"parentBoneName","Bip01_Head");
            Reflect.set(inst,"parentBone",bone);
            Reflect.set(inst,"character",chr);
            Reflect.call(inst,"setOwner",Object.class,slot);
            @SuppressWarnings("unchecked") List<Object> subs=(List<Object>)Reflect.get(slot,"sub");
            subs.add(inst); // native addStaticForcedTex already added body.sub
            BODIES.put(body,new Mount(new WeakReference<>(chr),profile));
            addParts(chr,slot,body,anim,profile);
            Object scale=Reflect.get(inst,"scale");
            if (WARNED.add("fit:"+mount+":"+scale))
                System.out.println("[WTAGarou Java][CrinosFit] head mounted; attachment="+mount
                        +"; instance.scale="+scale+"; size comes from CrinosHead model script; body/form scale unchanged");
        } catch (ReflectiveOperationException | RuntimeException e) { warn("head mount",e); }
    }
    /** 0.4.67: skinned legs / tail as body sub-models. Mirrors
     *  PopTemplateManager.addClothingItem + postProcessNewItemInstance
     *  (newAdditionalModelInstance on the body's AnimationPlayer, then the
     *  parent/matrixModel/sub/owner wiring), minus the ItemVisual: there is
     *  no inventory item, so nothing can be unequipped, dropped or synced
     *  as clothing. The clothing path is the one the engine already runs
     *  for every worn FBX, including on remote players. */
    private static void addParts(Object chr,Object slot,Object body,Object anim,Profile profile) {
        if (!profile.hasLegs() && !profile.hasTail()) return;
        if (profile.hasLegs()) addSkinned(chr,slot,body,anim,LEGS_MESH+MESH_EXT,"Body/"+profile.legs(),"legs");
        if (profile.hasTail()) addSkinned(chr,slot,body,anim,TAIL_MESH+MESH_EXT,"Body/"+profile.tail(),"tail");
    }
    private static void addSkinned(Object chr,Object slot,Object body,Object anim,String mesh,String tex,String what) {
        try {
            Object inst=Reflect.call(manager(),"newAdditionalModelInstance",
                    new Class<?>[]{String.class,String.class,
                            Class.forName("zombie.characters.IsoGameCharacter"),
                            Class.forName(ANIM_PLAYER_CLASS),String.class},
                    mesh,tex,chr,anim,null);
            if (inst==null) { if (WARNED.add("part:"+what)) System.out.println("[WTAGarou Java][Crinos] "+what+" instance unavailable: "+mesh); return; }
            Reflect.set(inst,"depthBias",0f);
            Reflect.set(inst,"matrixModel",body);
            Reflect.set(inst,"tintR",1f); Reflect.set(inst,"tintG",1f); Reflect.set(inst,"tintB",1f);
            Reflect.set(inst,"parent",body);
            Reflect.set(inst,"animPlayer",anim);
            @SuppressWarnings("unchecked") List<Object> bodySubs=(List<Object>)Reflect.get(body,"sub");
            @SuppressWarnings("unchecked") List<Object> slotSubs=(List<Object>)Reflect.get(slot,"sub");
            bodySubs.add(0,inst);
            slotSubs.add(0,inst);
            Reflect.call(inst,"setOwner",Object.class,slot);
            if (WARNED.add("part-mounted:"+what))
                System.out.println("[WTAGarou Java][CrinosFit] "+what+" mounted as skinned body sub-model; mesh="+mesh+"; tex="+tex);
        } catch (ReflectiveOperationException | RuntimeException e) { warn(what+" mount",e); }
    }
    /** 0.4.67: worn footwear has no mesh while the digitigrade legs are on
     *  (the item stays worn and keeps its stats; only its model is skipped,
     *  the same effect ItemBodyLocation.setHideModel(SHOES) has for the
     *  original clothing-item version of these legs). */
    public static boolean hidesFootwear(Object chr,Object itemVisual) {
        if (chr==null || itemVisual==null) return false;
        Profile p=PROFILES.get(chr);
        if (p==null || !p.hasLegs() || WolfRuntime.active(chr)) return false;
        try {
            Object item=Reflect.call(itemVisual,"getScriptItem");
            if (item==null) return false;
            Object loc=Reflect.call(item,"getBodyLocation");
            boolean hide=isFootwearLocation(loc==null?null:String.valueOf(loc));
            if (hide && WARNED.add("footwear-skip")) System.out.println("[WTAGarou Java][CrinosFit] footwear mesh skipped at addClothingItem: "+loc);
            return hide;
        } catch (ReflectiveOperationException | RuntimeException e) { return false; }
    }
    /** 0.4.71: legwear has no place on the digitigrade legs either (texture
     *  layers paint on the human hips and the new thighs cut through them;
     *  Oct 18 screenshot). Hidden while the legs are on, item stays worn.
     *  Underwear is left alone. */
    public static boolean isLegwearLocation(String id) {
        if (id==null) return false;
        int colon=id.lastIndexOf(':');
        String name=(colon>=0?id.substring(colon+1):id).toLowerCase(java.util.Locale.ROOT);
        switch (name) {
            case "pants": case "pants_skinny": case "pantsextra": case "shortpants":
            case "skirt": case "longskirt": case "legs1": case "legs5":
                return true;
            default: return false;
        }
    }
    /** Legs profile of the body model instance (texture compositor scope). */
    public static boolean legsOnBody(Object body) {
        Profile p=bodyProfile(body);
        return p!=null && p.hasLegs();
    }
    public static boolean isFootwearLocation(String id) {
        if (id==null) return false;
        int colon=id.lastIndexOf(':');
        String name=colon>=0?id.substring(colon+1):id;
        return name.equalsIgnoreCase("Shoes") || name.equalsIgnoreCase("Socks");
    }
    public static boolean hasHead(Object slot) {
        try { return slot!=null && ownsBody(Reflect.get(slot,"model")); }
        catch (ReflectiveOperationException | RuntimeException e) { return false; }
    }
    /** Match the renderer's actual mode rather than assuming self inversion.
     * Both script mounts reproduce the old, user-confirmed placeholder pose
     * after converting the authored head's recorded Blender orientation. */
    public static String attachmentName() {
        try {
            boolean inverted=Class.forName("zombie.core.skinnedmodel.model.ModelInstanceRenderData")
                    .getField("invertAttachmentSelfTransform").getBoolean(null);
            return inverted ? "mount" : "mount_direct";
        } catch (ReflectiveOperationException | RuntimeException e) {
            warn("attachment mode unavailable; using inverse-fit mount",e);
            return "mount";
        }
    }
    /** All init overloads converge on chrData. Idempotent, no overload casts. */
    public static void texture(Object creator) {
        if (BODIES.isEmpty()) return;
        try {
            Object data=Reflect.get(creator,"chrData");
            Object body=Reflect.get(data,"modelInstance");
            Profile p=bodyProfile(body);
            if(p==null) return;
            String path="media/textures/Body/"+p.body()+".png";
            Reflect.set(data,"baseTexture",path);
            Object mask=Reflect.get(data,"mask");
            Class<?> part=Class.forName("zombie.core.skinnedmodel.model.CharacterMask$Part");
            Object head=part.getField("Head").get(null);
            Reflect.call(mask,"setPartVisible",new Class<?>[]{part,boolean.class},head,false);
            // Vanilla body textures leave this optional skirt/dress geometry
            // transparent. Our opaque fur swatch would reveal it as a tube.
            Object dress=part.getField("Dress").get(null);
            Reflect.call(mask,"setPartVisible",new Class<?>[]{part,boolean.class},dress,false);
            // 0.4.67: the digitigrade mesh replaces the human legs and feet
            // (parts 7,8,9,10). 0.4.90: the vanilla mask folder stays; our
            // own leg mesh starts just under the hip joint, so it overlaps
            // whatever stump the vanilla Crotch mask leaves.
            if (p.hasLegs()) {
                for (String leg:new String[]{"LeftLeg","LeftFoot","RightLeg","RightFoot"}) {
                    Object value=part.getField(leg).get(null);
                    Reflect.call(mask,"setPartVisible",new Class<?>[]{part,boolean.class},value,false);
                }
            }
            // Masking an otherwise naked body starts requiring mask PNGs.
            // Queue them exactly like native init, before asynchronous render.
            @SuppressWarnings("unchecked") List<Object> pending=(List<Object>)Reflect.get(creator,"texturesNotReady");
            String folder=(String)Reflect.get(data,"maskFolder");
            Object base=textureWithFlags(path);
            if(base!=null && !Boolean.TRUE.equals(Reflect.call(base,"isReady")) && !pending.contains(base)) pending.add(base);
            for(Object value:(Object[])part.getMethod("leaves").invoke(null)) {
                if(Boolean.TRUE.equals(Reflect.call(mask,"isPartVisible",part,value))) {
                    Object tex=textureWithFlags(folder+"/"+value+".png");
                    if(tex!=null && !Boolean.TRUE.equals(Reflect.call(tex,"isReady")) && !pending.contains(tex)) pending.add(tex);
                }
            }
            // A clothing hole must not restore the hidden human head.
            Object types=Reflect.call(head,"getBloodBodyPartTypes");
            boolean[] holes=(boolean[])Reflect.get(creator,"holeMask");
            for(Object type:(Object[])types) {
                int i=((Number)Reflect.call(type,"index")).intValue();
                if(i>=0 && i<holes.length) holes[i]=false;
            }
        } catch (ReflectiveOperationException | RuntimeException e) { warn("body texture",e); }
    }
    private static void warn(String stage,Exception e) {
        if(WARNED.add(stage)) System.out.println("[WTAGarou Java][Crinos] "+stage+": "+e);
    }
}
