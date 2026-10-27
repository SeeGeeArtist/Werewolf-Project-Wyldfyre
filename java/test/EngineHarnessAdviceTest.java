import java.io.File;
import net.bytebuddy.ByteBuddy;
import net.bytebuddy.agent.ByteBuddyAgent;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.dynamic.ClassFileLocator;
import net.bytebuddy.pool.TypePool;
import static net.bytebuddy.matcher.ElementMatchers.named;
import static net.bytebuddy.matcher.ElementMatchers.takesArguments;
import wtagarou.visuals.WolfHarnessInitPatch;
import wtagarou.visuals.WolfHarnessLoadPatch;

/** Optional: weave the real supplied class bytes, without loading game classes.
 * No native game boot, redistribution, or claim of rendered verification. */
public class EngineHarnessAdviceTest {
    public static void main(String[] args) throws Exception {
        var instrumentation=ByteBuddyAgent.install();
        var transformer=Class.forName("me.zed_0xff.zombie_buddy.PatchTransformer");
        var translate=transformer.getDeclaredMethod("transformPatchClass",
                Class.class,java.lang.instrument.Instrumentation.class,int.class,boolean.class);
        translate.setAccessible(true);
        try (var locator=new ClassFileLocator.Compound(
                ClassFileLocator.ForJarFile.of(new File(args[0])),
                ClassFileLocator.ForClassLoader.ofSystemLoader())) {
            for(Class<?> patchClass:new Class<?>[]{WolfHarnessInitPatch.class,WolfHarnessLoadPatch.class}) {
                var advice=(Class<?>)translate.invoke(null,patchClass,instrumentation,0,false);
                var patch=patchClass.getAnnotation(me.zed_0xff.zombie_buddy.Patch.class);
                var type=TypePool.Default.of(locator).describe(patch.className()).resolve();
                var target=named(patch.methodName()).and(takesArguments(
                        patchClass==WolfHarnessLoadPatch.class ? 5 : 2));
                if (type.getDeclaredMethods().filter(target).size()!=1)
                    throw new AssertionError("Expected exactly one B42 target: "+patch.methodName());
                new ByteBuddy().redefine(type,locator)
                        .visit(Advice.to(advice).on(target)).make();
            }
        }
        System.out.println("PASS: real ZombieBuddy harness advice weaves into supplied engine class bytes; not a game render.");
    }
}
