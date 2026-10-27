import java.io.File;
import net.bytebuddy.ByteBuddy;
import net.bytebuddy.agent.ByteBuddyAgent;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.dynamic.ClassFileLocator;
import net.bytebuddy.pool.TypePool;
import static net.bytebuddy.matcher.ElementMatchers.named;
import static net.bytebuddy.matcher.ElementMatchers.takesArguments;
import static net.bytebuddy.matcher.ElementMatchers.takesArgument;
import wtagarou.visuals.*;

/** Optional private engine-bytecode weaving. Does not boot or ship the game. */
public class EnginePlaytestAdviceTest {
    public static void main(String[] args) throws Exception {
        var inst=ByteBuddyAgent.install();
        var translate=Class.forName("me.zed_0xff.zombie_buddy.PatchTransformer")
                .getDeclaredMethod("transformPatchClass",Class.class,
                        java.lang.instrument.Instrumentation.class,int.class,boolean.class);
        translate.setAccessible(true);
        Class<?>[] patches={WolfSeatedLookPatch.class,CalloutPatch.class,
                WolfTrackPatch.class,WolfAttackMaskPatch.class,
                VehicleEntryPatch.class,WindowClimbPatch.class,GrappleOffsetPatch.class,MeleeRangePatch.class,CorpseThrowPatch.class,DebugConsolePatch.class,FurInsulationPatch.class};
        int[] arity={0,0,2,2,2,1,1,1,1,0,0};
        try(var locator=new ClassFileLocator.Compound(
                ClassFileLocator.ForJarFile.of(new File(args[0])),
                ClassFileLocator.ForClassLoader.ofSystemLoader())) {
            for(int i=0;i<patches.length;i++) {
                var advice=(Class<?>)translate.invoke(null,patches[i],inst,0,false);
                var patch=patches[i].getAnnotation(me.zed_0xff.zombie_buddy.Patch.class);
                var type=TypePool.Default.of(locator).describe(patch.className()).resolve();
                var target=named(patch.methodName()).and(takesArguments(arity[i]));
                if (patches[i]==WolfTrackPatch.class)
                    target=target.and(takesArgument(0,named("zombie.core.skinnedmodel.animation.StartAnimTrackParameters")));
                if (patches[i]==WindowClimbPatch.class)
                    target=target.and(takesArgument(0,named("zombie.iso.objects.IsoWindow")));
                if (patches[i]==GrappleOffsetPatch.class)
                    target=target.and(takesArgument(0,named("float")));
                if (patches[i]==CorpseThrowPatch.class)
                    target=target.and(takesArgument(0,named("zombie.inventory.ItemContainer")));
                if (patches[i]==MeleeRangePatch.class)
                    target=target.and(takesArgument(0,named("zombie.characters.IsoGameCharacter")));
                if(type.getDeclaredMethods().filter(target).size()!=1)
                    throw new AssertionError("Engine target changed: "+patch.methodName());
                new ByteBuddy().redefine(type,locator).visit(Advice.to(advice).on(target)).make();
            }
        }
        System.out.println("PASS: supplied engine accepts real seated-look, Callout, track, mask-transfer, vehicle-entry, window-climb, grapple-offset, melee-range, corpse-throw and debug-console advice.");
    }
}
