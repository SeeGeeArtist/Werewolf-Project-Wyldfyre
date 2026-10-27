package wtagarou.visuals;

import java.util.Collections;
import java.util.Set;
import java.util.WeakHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/** 0.4.20 diagnostic for the "pocket knife as big as a building" report
 * (September 26 playtest: a belt-attached knife drawn huge in Crinos after a
 * forced shift out of Lupus, slightly large in Glabro). Nothing is changed;
 * a sub-model whose render transform carries an abnormal scale is described
 * once in the console so the next playtest names the cause. */
public final class SubmodelDiag {
    public static final float MIN_OK = 0.5f, MAX_OK = 2.5f;
    public static final int MAX_LINES = 8;
    private static final Set<Object> SEEN = Collections.newSetFromMap(new WeakHashMap<>());
    private static final AtomicInteger LINES = new AtomicInteger();

    /** Column-vector length of the render transform's first axis. */
    public static float axisScale(float m00, float m01, float m02) {
        return (float) Math.sqrt(m00 * m00 + m01 * m01 + m02 * m02);
    }
    public static boolean abnormal(float axis) {
        return !(axis >= MIN_OK && axis <= MAX_OK);
    }

    static void check(Object instance, Object renderData, Object slot, Object character, float factor) {
        if (instance == null || LINES.get() >= MAX_LINES) return;
        try {
            Object parent = Reflect.get(instance, "parent");
            if (parent == null) return;                       // body, not a sub-model
            Object xfrm = Reflect.get(renderData, "xfrm");
            if (xfrm == null) return;
            float axis = axisScale(number(Reflect.get(xfrm, "m00")), number(Reflect.get(xfrm, "m01")),
                    number(Reflect.get(xfrm, "m02")));
            if (!abnormal(axis)) return;
            synchronized (SEEN) { if (!SEEN.add(instance)) return; }
            if (LINES.incrementAndGet() > MAX_LINES) return;
            Object model = Reflect.get(instance, "model");
            Object parentModel = Reflect.get(parent, "model");
            System.out.println("[WTAGarou Java][SubmodelDiag] abnormal sub-model scale " + axis
                    + ": model=" + name(model) + " parentModel=" + name(parentModel)
                    + " instance.scale=" + Reflect.get(instance, "scale")
                    + " parent.scale=" + Reflect.get(parent, "scale")
                    + " parentBoneName=" + Reflect.get(instance, "parentBoneName")
                    + " attachmentParent=" + Reflect.get(instance, "attachmentNameParent")
                    + " attachmentSelf=" + Reflect.get(instance, "attachmentNameSelf")
                    + " wolfActive=" + WolfRuntime.active(character)
                    + " mouthCarried=" + WolfRuntime.isMouthCarried(instance)
                    + " formFactor=" + factor
                    + " slotFinalScale=" + Reflect.get(slot, "finalScale"));
        } catch (ReflectiveOperationException | RuntimeException ignored) {}
    }
    private static float number(Object value) { return value instanceof Number n ? n.floatValue() : 0f; }
    private static String name(Object model) {
        if (model == null) return "null";
        try { Object n = Reflect.get(model, "name"); if (n != null) return String.valueOf(n); }
        catch (ReflectiveOperationException | RuntimeException ignored) {}
        return model.getClass().getSimpleName();
    }
}
