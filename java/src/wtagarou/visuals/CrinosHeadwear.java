package wtagarou.visuals;

/** Render-only contraction around the animated head pivot. Never changes
 * model scripts, inventory, the Crinos head, or shared animation bones. */
public final class CrinosHeadwear {
    public static final float SCALE=.6f;
    private static final Class<?>[] XYZ={float.class,float.class,float.class};
    private static final ThreadLocal<Object[]> SCRATCH=new ThreadLocal<>();
    private static volatile boolean reported, warned;

    public static boolean eligible(Object item,Object body) {
        if(item==null || !CrinosCosmetics.ownsBody(body)) return false;
        try {
            // Native static clothing is mounted by attachBone. Skinned hoods
            // have no parentBoneName and must not shrink their torso geometry.
            return Reflect.get(item,"parent")==body
                    && "Bip01_Head".equals(Reflect.get(item,"parentBoneName"))
                    && Boolean.TRUE.equals(Reflect.get(Reflect.get(item,"model"),"isStatic"))
                    && Reflect.call(item,"getItemVisual")!=null;
        } catch(ReflectiveOperationException | RuntimeException e) { return false; }
    }

    public static void transform(Object data,Object parentData) {
        if(data==null || parentData==null) return;
        try {
            Object body=Reflect.get(parentData,"modelInstance");
            Object item=Reflect.get(data,"modelInstance");
            if(!eligible(item,body)) return;
            Object anim=Reflect.get(body,"animPlayer");
            if(anim==null || ((Number)Reflect.call(anim,"getSkinningBoneIndex",
                    new Class<?>[]{String.class,int.class},"Bip01_Head",-1)).intValue()<0) return;
            Class<?> matrixType=Class.forName("org.joml.Matrix4f");
            Class<?> matrixInterface=Class.forName("org.joml.Matrix4fc");
            Object[] scratch=SCRATCH.get();
            if(scratch==null) {
                scratch=new Object[]{matrixType.getConstructor().newInstance(),
                        matrixType.getConstructor().newInstance()};
                SCRATCH.set(scratch);
            }
            Object pivot=scratch[0], adjusted=scratch[1];
            Object original=Reflect.get(data,"xfrm");
            // Recreate the native parent+head transform BEFORE the item's
            // self attachment/import matrix. Its origin is the requested pivot.
            Reflect.call(pivot,"set",matrixInterface,Reflect.get(parentData,"xfrm"));
            Reflect.call(pivot,"transpose");
            Class.forName("zombie.core.skinnedmodel.model.ModelInstanceRenderData")
                    .getMethod("applyBoneTransform",
                            Class.forName("zombie.core.skinnedmodel.model.ModelInstance"),
                            String.class,matrixType).invoke(null,body,"Bip01_Head",pivot);
            float x=((Number)Reflect.call(pivot,"m30")).floatValue();
            float y=((Number)Reflect.call(pivot,"m31")).floatValue();
            float z=((Number)Reflect.call(pivot,"m32")).floatValue();
            Reflect.call(adjusted,"set",matrixInterface,original);
            contract(adjusted,x,y,z);
            // The instanced shader copies this matrix before transformToParent.
            // Publish the corrected copy as well as the conventional draw path.
            Object properties=Reflect.get(data,"properties");
            if(properties!=null)
                Reflect.call(properties,"SetMatrix4",
                        new Class<?>[]{String.class,matrixType},"transform",adjusted);
            Reflect.call(original,"set",matrixInterface,adjusted);
            if(!reported) {
                reported=true;
                System.out.println("[WTAGarou Java][CrinosHeadwear] rigid head clothing scaled 0.6 around Bip01_Head; native item scales unchanged");
            }
        } catch(ReflectiveOperationException | RuntimeException e) {
            if(!warned) {
                warned=true;
                System.out.println("[WTAGarou Java][CrinosHeadwear] leaving native transform unchanged: "+e);
            }
        }
    }

    /** x' = pivot + 0.6*(x-pivot). Includes attachment translations, unlike
     * simply changing ModelInstance.scale. Input/output are native transposed. */
    public static void contract(Object matrix,float x,float y,float z)
            throws ReflectiveOperationException {
        Reflect.call(matrix,"transpose");
        Reflect.call(matrix,"scaleLocal",float.class,SCALE);
        Reflect.call(matrix,"translateLocal",XYZ,(1-SCALE)*x,(1-SCALE)*y,(1-SCALE)*z);
        Reflect.call(matrix,"transpose");
    }
}
