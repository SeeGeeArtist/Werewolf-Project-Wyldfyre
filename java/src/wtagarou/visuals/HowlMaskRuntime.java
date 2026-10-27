package wtagarou.visuals;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

/** 0.4.69: the howl plays the vanilla Drink action node, whose sub-layer
 *  mask raises the left arm. While WTAGarou_HowlMask is set (Lua: Glabro and
 *  Crinos howls) the drink track's bone weights become "Bip01 0, Bip01_Neck 1
 *  (+descendants)", so the head and neck still tilt back but the arms, torso
 *  and legs keep whatever the locomotion layer is doing (idle, walk, ...)
 *  -- or, on the root layer (standing still), hold their last pose; see
 *  afterPlay.
 *
 *  AnimationTrack.initBoneWeights zeroes every bone, then applies each
 *  binding as max(weight); a root layer ignores sub-layer weights entirely,
 *  so this cannot touch the gait track. The 42.21 layer-transfer path
 *  (LiveAnimNode.initTrackBoneWeights) re-applies the node's own mask, so
 *  it is repaired there as well. Lupus/Hispo are WolfRuntime's: the wolf
 *  rig shares the Bip01_Neck/Bip01_Head names, but the human clip stores
 *  absolute local rotations for an upright spine, which on a horizontal
 *  wolf spine points the muzzle forward and down, not up - that form needs
 *  an authored Wolf_howl clip (wired as an optional clip). */
public final class HowlMaskRuntime {
    public static final String VARIABLE="WTAGarou_HowlMask";
    public static final String[] KEEP={"Bip01_Neck"};
    public static final String ROOT="Bip01";
    public static final AtomicLong masked=new AtomicLong(), repairs=new AtomicLong();
    private static final AtomicBoolean LOGGED=new AtomicBoolean(), WARNED=new AtomicBoolean();
    private static volatile List<Object> weights;

    private HowlMaskRuntime() {}

    public static boolean howling(Object character) {
        if (character==null) return false;
        try { return Boolean.TRUE.equals(Reflect.call(character,"getVariableBoolean",new Class<?>[]{String.class},VARIABLE)); }
        catch (ReflectiveOperationException | RuntimeException e) { return false; }
    }

    /** The drink/eat action clips; never gaits, aims or carries. */
    public static boolean isActionClip(String animName) {
        if (animName==null) return false;
        String n=animName.toLowerCase(Locale.ROOT);
        return n.contains("drink") || n.contains("eat");
    }

    public static List<Object> headNeckWeights() throws ReflectiveOperationException {
        List<Object> cached=weights;
        if (cached!=null) return cached;
        var ctor=Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimBoneWeight").getConstructor(String.class,float.class);
        List<Object> list=new ArrayList<>();
        list.add(ctor.newInstance(ROOT,0f));          // every skinned bone off (descendants included)
        for (String bone:KEEP) list.add(ctor.newInstance(bone,1f)); // neck + head back on
        weights=cached=List.copyOf(list);
        return cached;
    }

    /** AnimationPlayer.play(StartAnimTrackParameters, AnimLayer) enter. */
    public static boolean begin(Object player,Object params) {
        if (params==null || params instanceof String || player==null) return false;
        try {
            Object character=Reflect.call(player,"getIsoGameCharacter");
            if (!howling(character) || WolfRuntime.active(character)) return false;
            if (!isActionClip(String.valueOf(Reflect.get(params,"animName")))) return false;
            Reflect.set(params,"subLayerBoneWeights",headNeckWeights());
            masked.incrementAndGet();
            if (LOGGED.compareAndSet(false,true))
                System.out.println("[WTAGarou Java][Howl] drink track masked to Bip01_Neck+Bip01_Head for the howl (arms keep the locomotion layer)");
            return true;
        } catch (ReflectiveOperationException | RuntimeException e) {
            if (WARNED.compareAndSet(false,true)) System.out.println("[WTAGarou Java][Howl] mask unavailable: "+e);
            return false;
        }
    }

    /** AnimationPlayer.play(StartAnimTrackParameters, AnimLayer) exit.
     *  0.4.70: play() applies params.subLayerBoneWeights ONLY on a sub-layer;
     *  on the root layer it calls track.setBoneWeights(null), full body. A
     *  standing howl runs the Drink node on the root layer (the sub-layer
     *  copy only exists while moving), which is why the Oct 18 Crinos still
     *  raised its arm with "drink track masked" in the log. When the params
     *  carry our mask and the new track ended up unmasked, the mask is put
     *  on the track directly. Bones the mask leaves at zero keep the pose
     *  of the previous frame (AnimationPlayer blends the remaining weight
     *  from boneTransforms[]), so the arms hold still instead of rising.
     *  Shared by the human drink mask and the wolf's Wolf_howl mask, which
     *  both pass the same cached list. */
    public static final AtomicLong rootMasks=new AtomicLong();
    public static boolean afterPlay(Object player,Object params,Object track) {
        if (params==null || params instanceof String || track==null || player==null) return false;
        try {
            List<Object> mask=weights;
            if (mask==null || Reflect.get(params,"subLayerBoneWeights")!=mask) return false;
            if (Boolean.TRUE.equals(Reflect.call(track,"hasBoneMask"))) return false;   // sub-layer: play() applied it
            Object skin=Reflect.call(player,"getSkinningData");
            if (skin==null) return false;
            Reflect.call(track,"setBoneWeights",List.class,mask);
            Reflect.call(track,"initBoneWeights",Class.forName("zombie.core.skinnedmodel.model.SkinningData"),skin);
            rootMasks.incrementAndGet();
            if (ROOT_LOGGED.compareAndSet(false,true))
                System.out.println("[WTAGarou Java][Howl] root-layer howl track masked directly (standing howl; play() only masks sub-layers)");
            return true;
        } catch (ReflectiveOperationException | RuntimeException e) {
            if (WARNED.compareAndSet(false,true)) System.out.println("[WTAGarou Java][Howl] root mask unavailable: "+e);
            return false;
        }
    }
    private static final AtomicBoolean ROOT_LOGGED=new AtomicBoolean();

    /** LiveAnimNode.initTrackBoneWeights exit (layer transfer re-applied the node mask). */
    public static boolean afterTransfer(Object node,Object track,boolean useMasks) {
        if (!useMasks || node==null || track==null) return false;
        try {
            Object layer=Reflect.get(node,"animLayer");
            if (layer==null || !Boolean.TRUE.equals(Reflect.call(layer,"isSubLayer"))) return false;
            Object character=Reflect.get(layer,"character");
            if (!howling(character) || WolfRuntime.active(character)) return false;
            Object clip=Reflect.call(track,"getClip");
            if (clip==null || !isActionClip(String.valueOf(Reflect.get(clip,"name")))) return false;
            Object skin=Reflect.call(layer,"getSkinningData");
            if (skin==null) return false;
            Reflect.call(track,"setBoneWeights",List.class,headNeckWeights());
            Reflect.call(track,"initBoneWeights",Class.forName("zombie.core.skinnedmodel.model.SkinningData"),skin);
            repairs.incrementAndGet();
            return true;
        } catch (ReflectiveOperationException | RuntimeException e) {
            if (WARNED.compareAndSet(false,true)) System.out.println("[WTAGarou Java][Howl] transfer mask unavailable: "+e);
            return false;
        }
    }
}
