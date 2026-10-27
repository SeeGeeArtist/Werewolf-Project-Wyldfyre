package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.implementation.bytecode.assign.Assigner;
// Raw advice is supported by ZombieBuddy. Its simplified AllArguments wrapper
// does not expose DYNAMIC assignment needed for heterogeneous init overloads.
@Patch(className="zombie.core.skinnedmodel.model.ModelInstanceTextureCreator",methodName="init",warmUp=true,isAdvice=true)
public final class CrinosTextureScopePatch {
    @Advice.OnMethodEnter
    public static void enter(@Advice.AllArguments(readOnly=false,typing=Assigner.Typing.DYNAMIC) Object[] args,
                             @Advice.Local("crinosFaceTextureScope") Object previous) {
        previous=CrinosFaceVisuals.enterTexture(args);
        args=CrinosFaceVisuals.textureArguments(args);
    }
    @Advice.OnMethodExit(onThrowable=Throwable.class)
    public static void exit(@Advice.Local("crinosFaceTextureScope") Object previous) {
        CrinosFaceVisuals.leave(previous);
    }
}
