import java.nio.*;
import java.util.*;
import net.bytebuddy.agent.ByteBuddyAgent;
import wtagarou.visuals.*;
import zombie.core.skinnedmodel.model.ModelInstance;

/** Real woven advice, native-shaped per-render palette copies, no GL boot.
 * Proves scope/matrix/lifetime invariants, not on-screen depth correctness. */
public class CrinosHeadCullTest {
    static int checks;
    static void check(boolean ok,String why) { checks++; if(!ok) throw new AssertionError(why); }
    static void close(float a,float b,String why) { check(Math.abs(a-b)<.00001f,why+": "+a+" != "+b); }
    public static class Pose {
        public float m03=.3f,m13=1.6f,m23=-.2f;
    }
    public static class Skin {
        public Map<String,Integer> boneIndices=new HashMap<>();
        public Skin() { boneIndices.put("Bip01_Head",2); }
    }
    public static class Model {
        public boolean isStatic;
        public Skin tag=new Skin();
    }
    public static class Animator extends CrinosCosmeticsTest.Animator {
        public boolean ready=true;
        public Pose pose=new Pose();
        public float[] shared=matrices();
        public boolean isReady() { return ready; }
        public float[] getSkinTransforms(Skin skin) { return shared; }
        public Pose getModelTransformAt(int bone) {
            check(bone==index,"pose uses animator index, not mesh palette index");
            return pose;
        }
    }
    public static class Data {
        public ModelInstance modelInstance;
        public FloatBuffer matrixPalette=ByteBuffer.allocateDirect(4*16*4)
                .order(ByteOrder.nativeOrder()).asFloatBuffer();
        public boolean matrixPaletteValid;
        public float[] published;
        public void initMatrixPalette() {
            matrixPaletteValid=false;
            Animator anim=(Animator)modelInstance.animPlayer;
            Model model=(Model)modelInstance.model;
            if(anim.isReady() && !model.isStatic) {
                matrixPalette.clear();
                matrixPalette.put(anim.getSkinTransforms(model.tag));
                matrixPalette.flip();
                matrixPaletteValid=true;
            }
        }
        public void publish() {
            // Publication copies the already-corrected render palette.
            published=new float[matrixPalette.limit()];
            matrixPalette.duplicate().get(published);
        }
    }
    static float[] matrices() {
        float[] out=new float[64];
        for(int i=0;i<4;i++) {
            int n=i*16;
            // Nontrivial rotation/scale and translation, stored as native
            // LWJGL matrices with row translation (transposed on upload).
            out[n]=0; out[n+1]=1; out[n+2]=0; out[n+3]=.1f*i;
            out[n+4]=-1; out[n+5]=0; out[n+6]=0; out[n+7]=1.2f+i;
            out[n+8]=0; out[n+9]=0; out[n+10]=1.4f; out[n+11]=-.3f*i;
            out[n+15]=1;
        }
        return out;
    }
    static float[] point(float[] m,int bone,float x,float y,float z) {
        int n=bone*16;
        return new float[]{m[n]*x+m[n+1]*y+m[n+2]*z+m[n+3],
                m[n+4]*x+m[n+5]*y+m[n+6]*z+m[n+7],
                m[n+8]*x+m[n+9]*y+m[n+10]*z+m[n+11]};
    }
    static float[] values(FloatBuffer b) {
        float[] a=new float[b.limit()];
        b.duplicate().position(0).get(a);
        return a;
    }
    static Data data(ModelInstance body) { Data d=new Data(); d.modelInstance=body; return d; }
    static CrinosCosmeticsTest.Slot slot() {
        var s=new CrinosCosmeticsTest.Slot();
        s.model.model=new Model(); s.model.animPlayer=new Animator();
        return s;
    }
    public static void main(String[] args) throws Exception {
        var agent=ByteBuddyAgent.install();
        WolfCombatTest.install(agent,Data.class,CrinosHeadCullPatch.class,"initMatrixPalette");
        var a=new CrinosCosmeticsTest.Character();
        var b=new CrinosCosmeticsTest.Character();
        var s=slot(); var other=slot();
        CrinosCosmetics.set(a,true,"WTAGarou_CrinosBody_Brown","WTAGarou_Wolf_Brown");
        CrinosCosmetics.addHead(a,s);
        Animator anim=(Animator)s.model.animPlayer;
        float[] saved=anim.shared.clone();
        Data d=data(s.model);
        for(int pose=0;pose<8;pose++) {
            anim.pose.m03=.1f*pose; anim.pose.m13=1.6f+.2f*pose; anim.pose.m23=-.1f*pose;
            for(int repeat=0;repeat<3;repeat++) {
                d.initMatrixPalette();
                check(d.matrixPalette.position()==0 && d.matrixPalette.limit()==64,"native cursor/limit unchanged");
                d.publish();
                float[] result=values(d.matrixPalette);
                check(Arrays.equals(result,d.published),"instanced publication sees corrected matrix");
                check(Arrays.equals(saved,anim.shared),"shared animation pose/skin matrices unmodified");
                for(int i=0;i<64;i++) if(i<32 || i>=48)
                    check(Float.floatToIntBits(saved[i])==Float.floatToIntBits(result[i]),"other bones byte-identical");
                float[] pivot={anim.pose.m03,anim.pose.m13,anim.pose.m23};
                for(float[] p:new float[][]{{0,0,0},{1,2,3},{-1,.4f,2}}) {
                    float[] old=point(saved,2,p[0],p[1],p[2]);
                    float[] now=point(result,2,p[0],p[1],p[2]);
                    for(int axis=0;axis<3;axis++)
                        close(now[axis],pivot[axis]+.001f*(old[axis]-pivot[axis]),"contract about animated pivot");
                }
            }
        }
        // Head, hat, or skinned clothing that shares the animator must remain
        // native: only the registered root body receives the correction.
        var gear=new ModelInstance(); gear.parent=s.model; gear.model=new Model(); gear.animPlayer=anim;
        Data accessory=data(gear); accessory.initMatrixPalette();
        check(Arrays.equals(saved,values(accessory.matrixPalette)),"shared-animator accessory palette unchanged");
        var head=(ModelInstance)s.sub.get(0);
        float headScale=head.scale;
        d.initMatrixPalette();
        close(head.scale,headScale,"replacement head scale untouched");
        check(head.parentBone==5 && head.parentBoneName.equals("Bip01_Head"),"head mount untouched");
        Data human=data(other.model); human.initMatrixPalette();
        check(Arrays.equals(saved,values(human.matrixPalette)),"unregistered human unaffected");
        CrinosCosmetics.set(b,true,"WTAGarou_CrinosBody_Brown","WTAGarou_Wolf_Brown");
        CrinosCosmetics.addHead(b,other);
        human.initMatrixPalette();
        check(!Arrays.equals(saved,values(human.matrixPalette)),"second active Crinos corrected independently");
        CrinosCosmetics.clear(a);
        d.initMatrixPalette();
        check(Arrays.equals(saved,values(d.matrixPalette)),"same-body human restoration on next native rebuild");
        human.initMatrixPalette();
        check(!Arrays.equals(saved,values(human.matrixPalette)),"first player's exit does not restore second");

        CrinosCosmetics.set(a,true,"WTAGarou_CrinosBody_Brown","WTAGarou_Wolf_Brown");
        var invalid=slot(); CrinosCosmetics.addHead(a,invalid);
        var bad=data(invalid.model); Animator badAnim=(Animator)invalid.model.animPlayer;
        ((Model)invalid.model.model).tag.boneIndices.clear(); bad.initMatrixPalette();
        check(Arrays.equals(saved,values(bad.matrixPalette)),"missing mesh head index leaves palette native");
        ((Model)invalid.model.model).tag.boneIndices.put("Bip01_Head",999); bad.initMatrixPalette();
        check(Arrays.equals(saved,values(bad.matrixPalette)),"out of range mesh index ignored");
        ((Model)invalid.model.model).tag.boneIndices.put("Bip01_Head",2);
        badAnim.index=-1; bad.initMatrixPalette();
        check(Arrays.equals(saved,values(bad.matrixPalette)),"missing animator head ignored");
        badAnim.index=5; badAnim.pose.m03=Float.NaN; bad.initMatrixPalette();
        check(Arrays.equals(saved,values(bad.matrixPalette)),"nonfinite pivot ignored");
        badAnim.ready=false; bad.matrixPalette.put(saved).flip(); bad.initMatrixPalette();
        check(!bad.matrixPaletteValid && Arrays.equals(saved,values(bad.matrixPalette)),"unready palette not edited");

        FloatBuffer direct=FloatBuffer.wrap(saved.clone()); direct.position(7); direct.mark();
        check(CrinosHeadCull.contract(direct,2,1,2,3),"valid contraction");
        direct.reset(); check(direct.position()==7 && direct.limit()==64,"mark and cursor preserved");
        check(!CrinosHeadCull.contract(direct.asReadOnlyBuffer(),2,1,2,3),"readonly fails closed");
        check(!CrinosHeadCull.contract(direct,-1,1,2,3),"negative index fails closed");
        FloatBuffer malformed=FloatBuffer.wrap(saved.clone()); malformed.put(44,1);
        float[] before=values(malformed);
        check(!CrinosHeadCull.contract(malformed,2,1,2,3),"unknown matrix convention fails closed");
        check(Arrays.equals(before,values(malformed)),"invalid matrix not partly modified");
        CrinosCosmetics.clearAll();
        System.out.println("PASS: "+checks+" Crinos hidden-head palette/advice/isolation/restoration checks; no GPU render.");
    }
}
