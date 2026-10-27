package wtagarou.visuals;

import java.lang.reflect.Method;

/** Furniture Ctrl-look uses native smoothed head input, NOT humanoid spine
 * twists or human look-pose clips. Runs after pose sampling, before palettes. */
public final class WolfSeatedLook {
    private static final ClassValue<Method> APPLY = new ClassValue<>() {
        protected Method computeValue(Class<?> type) {
            try {
                Method m=type.getDeclaredMethod("applyTwistBone",
                        Class.forName("zombie.core.skinnedmodel.model.SkinningBone"),
                        Class.forName("org.lwjgl.util.vector.Quaternion"));
                m.setAccessible(true);
                return m;
            } catch (ReflectiveOperationException e) { throw new IllegalStateException(e); }
        }
    };
    private static final ThreadLocal<Object> QUAT = new ThreadLocal<>();
    private static boolean logged;
    public static float angle(float input, float max) {
        if (!Float.isFinite(input) || !Float.isFinite(max) || max<=0) return 0;
        return Math.max(-1f,Math.min(1f,input))*Math.min(max,0.7f);
    }
    public static void apply(Object player) {
        try {
            Object character=Reflect.call(player,"getIsoGameCharacter");
            if (!WolfRuntime.active(character)
                    || Boolean.TRUE.equals(Reflect.call(character,"isDead"))
                    || !Boolean.TRUE.equals(Reflect.call(character,"isSittingOnFurniture"))
                    || !Boolean.TRUE.equals(Reflect.call(character,"isHeadLookAround"))
                    || Boolean.TRUE.equals(Reflect.call(character,"getVariableBoolean",String.class,"forceGetUp")))
                return;
            float yaw=angle(((Number)Reflect.call(character,"getHeadLookHorizontal")).floatValue(),
                    ((Number)Reflect.call(character,"getHeadLookAngleMax")).floatValue());
            if (Math.abs(yaw)<0.0001f) return;
            Object skin=Reflect.call(player,"getSkinningData");
            Object head=Reflect.call(skin,"getBone",String.class,"Bip01_Head");
            if (head==null || Reflect.get(head,"parent")==null) return;
            Object q=QUAT.get();
            if (q==null) {
                q=Class.forName("org.lwjgl.util.vector.Quaternion").getConstructor().newInstance();
                QUAT.set(q);
            }
            Reflect.set(q,"x",0f); Reflect.set(q,"y",(float)Math.sin(yaw/2));
            Reflect.set(q,"z",0f); Reflect.set(q,"w",(float)Math.cos(yaw/2));
            // Native helper rotates around model-space up at the head's own
            // pivot and converts back through the parent. Authored pitch,
            // head position, hips and paws are preserved. No shared asset edit.
            APPLY.get(player.getClass()).invoke(player,head,q);
            if (!logged) {
                logged=true;
                System.out.println("[WTAGarou Java] seated wolf Ctrl-look active (head only; native smoothed input)");
            }
        } catch (ReflectiveOperationException | RuntimeException error) {
            WolfRuntime.warn("seated head look",error);
        }
    }
}
