import wtagarou.visuals.*;
import org.lwjgl.util.vector.Quaternion;
import zombie.core.skinnedmodel.model.SkinningBone;

/** Scoped input/pivot-hook tests. Not a rendered head-fit test. */
public class WolfSeatedLookTest {
    static int checks;
    static void check(boolean b,String why) { checks++; if(!b) throw new AssertionError(why); }
    public static class Character extends WolfCombatTest.Character {
        public boolean seated=true,look=true;
        public float horizontal=1f;
        public boolean isSittingOnFurniture() { return seated; }
        public boolean isHeadLookAround() { return look; }
        public float getHeadLookHorizontal() { return horizontal; }
        public float getHeadLookAngleMax() { return 0.348f; }
    }
    public static class Skin {
        public SkinningBone head=new SkinningBone();
        public Skin() { head.parent=new SkinningBone(); }
        public SkinningBone getBone(String name) {
            check(name.equals("Bip01_Head"),"only the head bone is requested");
            return head;
        }
    }
    public static class Player {
        public Character character=new Character();
        public Skin skin=new Skin();
        public int turns;
        public float y,w;
        public Object getIsoGameCharacter() { return character; }
        public Skin getSkinningData() { return skin; }
        private void applyTwistBone(SkinningBone bone,Quaternion q) {
            check(bone==skin.head && q.x==0 && q.z==0,"only head, model-space yaw, no body roll/pitch");
            turns++; y=q.y; w=q.w;
        }
        public void updateTwistBone() {}
    }
    public static void main(String[] args) throws Exception {
        var inst=net.bytebuddy.agent.ByteBuddyAgent.install();
        WolfCombatTest.install(inst,Player.class,WolfSeatedLookPatch.class,"updateTwistBone");
        Player p=new Player();
        p.updateTwistBone();
        check(p.turns==0,"human/Crinos rigs untouched");
        check(WTAGarouJava.setWolf(p.character,true).equals("wolf"),"fixture activates wolf");
        p.updateTwistBone();
        check(p.turns==1 && Math.abs(p.y-Math.sin(.348/2))<1e-6,"native normalized right-look scales to native angle");
        p.character.horizontal=-1; p.updateTwistBone();
        check(p.turns==2 && p.y<0 && Math.abs(p.w-Math.cos(.348/2))<1e-6,"left-look symmetric");
        p.character.horizontal=0; p.updateTwistBone();
        check(p.turns==2,"neutral sampled pose needs no accumulated twist undo");
        p.character.horizontal=1;
        p.character.seated=false; p.updateTwistBone(); p.character.seated=true;
        p.character.look=false; p.updateTwistBone(); p.character.look=true;
        p.character.forceGetUp=true; p.updateTwistBone(); p.character.forceGetUp=false;
        p.character.dead=true; p.updateTwistBone(); p.character.dead=false;
        check(p.turns==2,"standing, disabled look, getting up and death bypass head override");
        p.skin.head.parent=null; p.updateTwistBone();
        check(p.turns==2,"missing parent fails closed");
        p.skin.head=null; p.updateTwistBone();
        check(p.turns==2,"missing head fails closed");
        check(WolfSeatedLook.angle(Float.NaN,.348f)==0 && WolfSeatedLook.angle(1,Float.NaN)==0,
                "nonfinite input cannot poison bone matrices");
        check(Math.abs(WolfSeatedLook.angle(50,.348f)-.348f)<1e-6,"input clamped");
        System.out.println("PASS: "+checks+" scoped seated-look assertions; not a native render.");
    }
}
