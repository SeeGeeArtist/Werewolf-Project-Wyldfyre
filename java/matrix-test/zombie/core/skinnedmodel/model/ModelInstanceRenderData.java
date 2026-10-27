package zombie.core.skinnedmodel.model;
import org.joml.Matrix4f;
/** TEST ONLY: same multiplication order as B42's native helper, with a
 * synthetic animated bone instead of booting the game. Never packaged. */
public final class ModelInstanceRenderData {
    public static boolean invertAttachmentSelfTransform;
    public static final Matrix4f head=new Matrix4f();
    public static void applyBoneTransform(ModelInstance parent,String bone,Matrix4f out) {
        if(!bone.equals("Bip01_Head")) throw new AssertionError(bone);
        head.mul(out,out);
    }
}
