import org.joml.Matrix4f;
import org.joml.Vector3f;
import wtagarou.visuals.*;
import zombie.core.skinnedmodel.model.*;
import net.bytebuddy.agent.ByteBuddyAgent;

/** Real JOML arithmetic + real advice + native-shaped synthetic attachment.
 * Does NOT establish in-game hat fit or skinned-clothing compatibility. */
public class CrinosHeadwearMatrixTest {
    static int checks;
    static void check(boolean ok,String message) {
        checks++; if(!ok) throw new AssertionError(message);
    }
    static void close(float a,float b,String message) {
        check(Math.abs(a-b)<.0001f,message+": "+a+" != "+b);
    }
    public static class Properties {
        public final Matrix4f published=new Matrix4f();
        public void SetMatrix4(String name,Matrix4f matrix) { published.set(matrix); }
    }
    public static class Model { public boolean isStatic=true; }
    public static class Data {
        public ModelInstance modelInstance;
        public Matrix4f xfrm=new Matrix4f();
        public Properties properties=new Properties();
        public Data(ModelInstance instance) { modelInstance=instance; }
        public Data transformToParent(Data parent) {
            if(parent==null) return this;
            xfrm.set(parent.xfrm).transpose();
            ModelInstanceRenderData.applyBoneTransform(parent.modelInstance,"Bip01_Head",xfrm);
            // Stand-in self attachment and mesh/import transforms.
            xfrm.translate(.4f,.8f,-.3f).rotateXYZ(.2f,.7f,.4f).scale(modelInstance.scale);
            xfrm.transpose();
            return this;
        }
    }
    static ModelInstance item(ModelInstance body,Object visual,String bone) {
        ModelInstance item=new ModelInstance();
        item.parent=body; item.itemVisual=visual; item.parentBoneName=bone;
        item.model=new Model();
        item.scale=1.7f; return item;
    }
    public static void main(String[] args) throws Exception {
        var agent=ByteBuddyAgent.install();
        WolfCombatTest.install(agent,Data.class,CrinosHeadwearPatch.class,"transformToParent");
        var a=new CrinosCosmeticsTest.Character();
        var b=new CrinosCosmeticsTest.Character();
        var slot=new CrinosCosmeticsTest.Slot();
        var other=new CrinosCosmeticsTest.Slot();
        CrinosCosmetics.set(a,true,"WTAGarou_CrinosBody_Brown","WTAGarou_Wolf_Brown");
        CrinosCosmetics.set(b,true,"WTAGarou_CrinosBody_Brown","WTAGarou_Wolf_Brown");
        CrinosCosmetics.addHead(a,slot); CrinosCosmetics.addHead(b,other);
        Data parent=new Data(slot.model);
        // Parent rotation, translation, and scale all non-identity.
        parent.xfrm.translation(.3f,-.5f,.7f).rotateXYZ(.3f,.1f,.9f).scale(1.44f).transpose();
        for(String location:new String[]{"Hat","FullHat","Ears","EarTop","Eyes","LeftEye","RightEye","MaskEyes"}) {
            var worn=item(slot.model,CrinosFaceVisualsTest.visual("base:"+location),"Bip01_Head");
            check(CrinosHeadwear.eligible(worn,slot.model),"head clothing eligible "+location);
            Data data=new Data(worn);
            for(int pose=0;pose<8;pose++) {
                ModelInstanceRenderData.head.translation(.2f,1.6f,-.1f)
                        .rotateXYZ(.1f*pose,.2f*pose,-.1f*pose);
                Matrix4f pivot=new Matrix4f(parent.xfrm).transpose();
                ModelInstanceRenderData.applyBoneTransform(slot.model,"Bip01_Head",pivot);
                Vector3f origin=pivot.transformPosition(new Vector3f());
                Matrix4f nativeMatrix=new Matrix4f(pivot).translate(.4f,.8f,-.3f)
                        .rotateXYZ(.2f,.7f,.4f).scale(worn.scale);
                for(int repeat=0;repeat<3;repeat++) {
                    data.transformToParent(parent);
                    Matrix4f result=new Matrix4f(data.xfrm).transpose();
                    for(Vector3f vertex:new Vector3f[]{new Vector3f(),new Vector3f(1,2,3),
                            new Vector3f(-2,.3f,1)}) {
                        Vector3f expected=nativeMatrix.transformPosition(new Vector3f(vertex));
                        expected.sub(origin).mul(.6f).add(origin);
                        Vector3f actual=result.transformPosition(new Vector3f(vertex));
                        close(actual.x,expected.x,"head-relative x");
                        close(actual.y,expected.y,"head-relative y");
                        close(actual.z,expected.z,"head-relative z");
                    }
                    check(data.properties.published.equals(data.xfrm,.00001f),"instanced shader matrix updated");
                    close(worn.scale,1.7f,"native item scale never mutated");
                }
            }
        }
        check(!CrinosHeadwear.eligible(slot.sub.get(0),slot.model),"Crinos head not scaled twice");
        check(!CrinosHeadwear.eligible(item(slot.model,null,"Bip01_Head"),slot.model),"hair/weapon excluded");
        check(!CrinosHeadwear.eligible(item(slot.model,new Object(),"Bip01_Spine2"),slot.model),"body gear excluded");
        check(!CrinosHeadwear.eligible(item(slot.model,new Object(),null),slot.model),"skinned hoods excluded");
        var skinned=item(slot.model,new Object(),"Bip01_Head");
        ((Model)skinned.model).isStatic=false;
        check(!CrinosHeadwear.eligible(skinned,slot.model),"explicitly skinned model excluded even with a head mount");
        var glasses=item(slot.model,new Object(),"Bip01_Head");
        CrinosCosmetics.clear(a);
        check(!CrinosHeadwear.eligible(glasses,slot.model),"same retained body immediately restores normal size");
        check(CrinosHeadwear.eligible(item(other.model,new Object(),"Bip01_Head"),other.model),
                "another player's Crinos profile unaffected");
        Data restored=new Data(glasses); restored.transformToParent(parent);
        Matrix4f expected=new Matrix4f(parent.xfrm).transpose();
        ModelInstanceRenderData.applyBoneTransform(slot.model,"Bip01_Head",expected);
        expected.translate(.4f,.8f,-.3f).rotateXYZ(.2f,.7f,.4f).scale(glasses.scale).transpose();
        check(expected.equals(restored.xfrm,.00001f),"normal form native transform untouched");
        CrinosCosmetics.clearAll();
        System.out.println("PASS: "+checks+" real-JOML Crinos head-pivot/pose/advice/isolation checks.");
    }
}
