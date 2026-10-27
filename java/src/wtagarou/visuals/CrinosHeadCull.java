package wtagarou.visuals;

import java.nio.FloatBuffer;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/** Transparency is not geometry removal. Suppress the hidden human head in
 * this body's render-copy skinning palette, not the shared animation pose.
 * Keeping a tiny nonzero basis avoids singular normal transforms. */
public final class CrinosHeadCull {
    public static final float HIDDEN_HEAD_SCALE=.001f;
    private static final Set<String> REPORTED=ConcurrentHashMap.newKeySet();

    /** Runs after native skin matrices are copied, before init() publishes
     * MatrixPalette to the instanced shader. Native init rebuilds this copy
     * each time; never edit AnimationPlayer.getSkinTransforms() matrices. */
    public static void afterPalette(Object data) {
        if(data==null) return;
        try {
            Object body=Reflect.get(data,"modelInstance");
            if(!CrinosCosmetics.ownsBody(body)) return;
            Object model=Reflect.get(body,"model");
            if(model==null || Boolean.TRUE.equals(Reflect.get(model,"isStatic"))
                    || !Boolean.TRUE.equals(Reflect.get(data,"matrixPaletteValid"))) return;
            Object skin=Reflect.get(model,"tag");
            if(skin==null) return;
            Object map=Reflect.get(skin,"boneIndices");
            // Mesh-palette index can differ from the animator's bone index.
            if(!(map instanceof Map<?,?> indices)
                    || !(indices.get("Bip01_Head") instanceof Number meshIndex)) return;
            Object anim=Reflect.get(body,"animPlayer");
            if(anim==null) return;
            int poseIndex=((Number)Reflect.call(anim,"getSkinningBoneIndex",
                    new Class<?>[]{String.class,int.class},"Bip01_Head",-1)).intValue();
            if(poseIndex<0) return;
            Object pose=Reflect.call(anim,"getModelTransformAt",int.class,poseIndex);
            if(pose==null) return;
            // B42 HelperFunctions.getPosition reads m03/m13/m23. The native
            // LWJGL .store() buffer is transposed at shader upload.
            float x=((Number)Reflect.get(pose,"m03")).floatValue();
            float y=((Number)Reflect.get(pose,"m13")).floatValue();
            float z=((Number)Reflect.get(pose,"m23")).floatValue();
            Object buffer=Reflect.get(data,"matrixPalette");
            if(!(buffer instanceof FloatBuffer palette)
                    || !contract(palette,meshIndex.intValue(),x,y,z)) return;
            if(REPORTED.add("applied"))
                System.out.println("[WTAGarou Java][CrinosHeadCull] hidden human head contracted in body render palette only; scale="
                        +HIDDEN_HEAD_SCALE+"; shared pose, replacement head and accessories unchanged");
        } catch(ReflectiveOperationException | RuntimeException e) {
            if(REPORTED.add("layout"))
                System.out.println("[WTAGarou Java][CrinosHeadCull] leaving native palette unchanged: "+e);
        }
    }

    /** Contract the skin matrix output around the animated bone pivot:
     * p' = pivot + scale*(skin*p - pivot). Absolute access preserves the
     * buffer's position, limit, and mark used by native shader publication. */
    public static boolean contract(FloatBuffer palette,int bone,float x,float y,float z) {
        if(palette==null || palette.isReadOnly() || bone<0
                || bone>=palette.limit()/16
                || !Float.isFinite(x) || !Float.isFinite(y) || !Float.isFinite(z)) return false;
        int start=bone*16;
        for(int i=0;i<16;i++) if(!Float.isFinite(palette.get(start+i))) return false;
        // Refuse an unexpected storage layout rather than transposing by guess.
        if(palette.get(start+12)!=0f || palette.get(start+13)!=0f
                || palette.get(start+14)!=0f || palette.get(start+15)!=1f) return false;
        float s=HIDDEN_HEAD_SCALE;
        float tx=x+s*(palette.get(start+3)-x);
        float ty=y+s*(palette.get(start+7)-y);
        float tz=z+s*(palette.get(start+11)-z);
        // Only the three linear columns and translation of the head matrix.
        for(int i=0;i<12;i++) if(i%4!=3) palette.put(start+i,palette.get(start+i)*s);
        palette.put(start+3,tx);
        palette.put(start+7,ty);
        palette.put(start+11,tz);
        return true;
    }
}
