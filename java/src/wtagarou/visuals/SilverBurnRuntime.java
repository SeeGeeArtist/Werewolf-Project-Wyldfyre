package wtagarou.visuals;

import java.util.*;

/** Reduce only vanilla's constant unbandaged burn tick inside DamageUpdate.
 * Never modify burn time, washing, bandages, healing, or external hit damage. */
public final class SilverBurnRuntime {
    private static final Map<Object,Float> FACTORS=Collections.synchronizedMap(new WeakHashMap<>());
    private static final ThreadLocal<Scope> CURRENT=new ThreadLocal<>();
    public record Scope(Object part, float expected, float factor) {}
    public static void set(Object part,double factor) {
        if (part==null || !Double.isFinite(factor) || factor<0 || factor>1) return;
        if (factor==1) FACTORS.remove(part); else FACTORS.put(part,(float)factor);
    }
    public static Object begin(Object part) {
        Scope previous=CURRENT.get();
        CURRENT.remove();
        Float factor=FACTORS.get(part);
        if (factor!=null) try {
            if (((Number)Reflect.call(part,"getBurnTime")).floatValue()>0
                    && Boolean.FALSE.equals(Reflect.call(part,"bandaged"))) {
                Object time=Class.forName("zombie.GameTime").getMethod("getInstance").invoke(null);
                float expected=3.75f*((Number)Reflect.call(part,"getDamageScaler")).floatValue()
                    *((Number)Reflect.call(time,"getMultiplier")).floatValue();
                CURRENT.set(new Scope(part,expected,factor));
            }
        } catch (ReflectiveOperationException | RuntimeException error) { WolfRuntime.warn("silver burn damage",error); }
        return previous;
    }
    public static void end(Object previous) {
        if (previous instanceof Scope s) CURRENT.set(s); else CURRENT.remove();
    }
    public static float damage(Object part,float amount) {
        Scope scope=CURRENT.get();
        // Other wound constants differ (bleeding, bites, cuts, bullet, fracture).
        // Exact float expression matches the supplied 42.21 bytecode.
        if(scope==null || scope.part()!=part || amount!=scope.expected()) return amount;
        try {
            float partHealth=((Number)Reflect.call(part,"getHealth")).floatValue();
            Object chr=Reflect.call(part,"getParentChar");
            Object bd=Reflect.call(chr,"getBodyDamage");
            float overall=((Number)Reflect.call(bd,"getOverallBodyHealth")).floatValue();
            // Only this exact silver BURN tick is nonlethal. Never refund HP,
            // heal, or cap a bite/bullet/bleeding/fire/external damage call.
            return Math.max(0f,Math.min(amount*scope.factor(),
                    Math.min(partHealth-5f,overall-20f)));
        } catch(ReflectiveOperationException | RuntimeException e) {
            WolfRuntime.warn("silver nonlethal guard",e);
            return 0f; // fail safe for the identified silver tick, not all damage
        }
    }
}
