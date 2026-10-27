import wtagarou.visuals.*;
import net.bytebuddy.ByteBuddy;
import net.bytebuddy.agent.ByteBuddyAgent;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.dynamic.loading.ClassReloadingStrategy;
import static net.bytebuddy.matcher.ElementMatchers.named;

/** Fake render objects test our contract, not game compatibility. The
 * annotation transformation uses the actual bundled ZombieBuddy JAR. */
public class ScaleTest {
    public static class Slot { public float finalScale = 1; public Object character; }
    public static class Instance { public Object character; }
    public static class Data { public Instance modelInstance = new Instance(); }
    public static class Renderer {
        public float DrawChar(Slot slot, Data data, boolean fail) {
            if (fail) throw new IllegalArgumentException("simulated draw failure");
            return slot.finalScale;
        }
    }
    static int checks;
    static void check(boolean condition, String message) {
        checks++;
        if (!condition) throw new AssertionError(message);
    }
    static void close(float actual, float expected, String message) {
        check(Math.abs(actual - expected) < 0.00001f, message + ": " + actual);
    }
    public static void main(String[] args) throws Exception {
        Object garou = new Object(), human = new Object();
        Slot slot = new Slot();
        Data data = new Data();
        data.modelInstance.character = garou;
        check(!WTAGarouJava.setScale(null, 1.5), "null rejected");
        check(!WTAGarouJava.setScale(garou, Double.NaN), "NaN rejected");
        check(!WTAGarouJava.setScale(garou, 20), "out of range rejected");
        check(WTAGarouJava.setScale(garou, 1.55), "Crinos accepted");
        for (int i = 0; i < 100; i++) {
            Object saved = ScaleRuntime.begin(slot, data);
            close(slot.finalScale, 1.55f, "Crinos draw");
            ScaleRuntime.end(saved);
            close(slot.finalScale, 1, "no cumulative growth");
        }
        data.modelInstance.character = human;
        Object saved = ScaleRuntime.begin(slot, data);
        close(slot.finalScale, 1, "unregistered human unaffected");
        ScaleRuntime.end(saved);
        data.modelInstance.character = null;
        slot.character = garou;
        saved = ScaleRuntime.begin(slot, data);
        close(slot.finalScale, 1.55f, "gear inherits slot owner");
        ScaleRuntime.end(saved);
        data.modelInstance.character = garou;
        slot.finalScale = 0.8f;
        saved = ScaleRuntime.begin(slot, data);
        close(slot.finalScale, 1.24f, "existing base preserved");
        ScaleRuntime.end(saved);
        close(slot.finalScale, 0.8f, "exact base restored");
        WTAGarouJava.clear(garou);
        close(WTAGarouJava.scaleFor(garou), 1, "death/clear resets");
        check(WTAGarouJava.setScale(garou, 1), "Homid accepted");
        check(ScaleRuntime.begin(slot, data) == null, "Homid no-op");
        WTAGarouJava.setScale(garou, 1.15);
        saved = ScaleRuntime.begin(slot, data);
        close(slot.finalScale, 0.92f, "Glabro");
        ScaleRuntime.end(saved);
        WTAGarouJava.setScale(garou, 1.45);
        saved = ScaleRuntime.begin(slot, data);
        close(slot.finalScale, 1.16f, "Hispo");
        ScaleRuntime.end(saved);
        check(ScaleRuntime.begin(null, data) == null, "null slot safe");
        check(ScaleRuntime.begin(slot, null) == null, "null data safe");

        // Validate actual @Patch.Local translation and exception cleanup.
        var instrumentation = ByteBuddyAgent.install();
        Class<?> transformer = Class.forName("me.zed_0xff.zombie_buddy.PatchTransformer");
        var transform = transformer.getDeclaredMethod("transformPatchClass",
                Class.class, java.lang.instrument.Instrumentation.class, int.class, boolean.class);
        transform.setAccessible(true);
        Class<?> advice = (Class<?>) transform.invoke(
                null, DrawCharPatch.class, instrumentation, 0, false);
        check(advice.getDeclaredMethods().length == 2, "advice available");
        new ByteBuddy().redefine(Renderer.class)
                .visit(Advice.to(advice).on(named("DrawChar")))
                .make().load(Renderer.class.getClassLoader(),
                        ClassReloadingStrategy.of(instrumentation));
        Renderer renderer = new Renderer();
        close(renderer.DrawChar(slot, data, false), 1.16f, "patched draw sees scale");
        close(slot.finalScale, 0.8f, "patched normal exit restores");
        try {
            renderer.DrawChar(slot, data, true);
            throw new AssertionError("draw exception swallowed");
        } catch (IllegalArgumentException expected) {
            close(slot.finalScale, 0.8f, "patched exceptional exit restores");
        }
        WTAGarouJava.clearAll();
        close(WTAGarouJava.scaleFor(garou), 1, "clearAll");
        // A changed game layout should stop scaling, not log every frame.
        ScaleRuntime.begin(new Object(), data);
        check(ScaleRuntime.disabled, "unknown layout disables hook");
        check(ScaleRuntime.begin(slot, data) == null, "disabled hook stays no-op");
        System.out.println("PASS: " + checks + " Java assertions, including real ZombieBuddy annotation translation.");
    }
}
