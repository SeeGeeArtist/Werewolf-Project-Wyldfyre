package wtagarou.visuals;
import java.util.ArrayDeque;

/** Scoped to the synchronous WTAGarou transformation setter, not all actions. */
public final class ShiftNilGuard {
    private static final ThreadLocal<ArrayDeque<Object>> OWNERS=ThreadLocal.withInitial(ArrayDeque::new);
    public static void begin(Object character) {
        if (character==null) throw new IllegalArgumentException("missing shift owner");
        OWNERS.get().push(character);
    }
    public static void end() {
        ArrayDeque<Object> owners=OWNERS.get();
        if (!owners.isEmpty()) owners.pop();
        if (owners.isEmpty()) OWNERS.remove();
    }
    public static boolean skip(Object action,Object animation) {
        if (animation!=null || OWNERS.get().isEmpty()) return false;
        try { return Reflect.get(action,"chr")==OWNERS.get().peek(); }
        catch (ReflectiveOperationException error) { return false; }
    }
}
