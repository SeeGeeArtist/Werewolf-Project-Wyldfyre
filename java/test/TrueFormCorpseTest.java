import java.util.*;
import zombie.iso.objects.IsoDeadBody;
import zombie.core.skinnedmodel.visual.*;
import zombie.core.skinnedmodel.ModelManager;
import wtagarou.visuals.*;
import net.bytebuddy.agent.ByteBuddyAgent;

public class TrueFormCorpseTest {
    static int checks;
    static void check(boolean b,String s) { checks++; if(!b) throw new AssertionError(s); }
    public static class Params {
        public Object baseVisual,diedBoneTransforms,grappleable;
        public String animSetName="player",stateName="deadbody",primaryHandItem="Rifle",secondaryHandItem="Bag";
        public float trackTime=1;
        public boolean ragdollFall=true;
        public ArrayList<Object> itemVisuals=new ArrayList<>(List.of("Shirt"));
        public ArrayList<Object> attachedModelNames=new ArrayList<>(List.of("LootModel"));
        public void init(IsoDeadBody body) { baseVisual=body.visual; diedBoneTransforms=new Object(); grappleable=body; }
        public void init(String unrelated) { animSetName=unrelated; }
    }
    public static class Instance { public float scale=1; }
    public static class Animated {
        public String set="player";
        public Instance modelInstance=new Instance();
        public WolfCombatTest.Player player=new WolfCombatTest.Player();
        public String GetAnimSetName() { return set; }
        public Object getAnimationPlayer() { return player; }
        public void setModelData(Object visual,Object items) {}
    }
    public static void main(String[] args) throws Exception {
        var agent=ByteBuddyAgent.install();
        WolfCombatTest.install(agent,Params.class,TrueFormCorpsePatch.class,"init");
        WolfCombatTest.install(agent,Animated.class,TrueFormCorpseSizePatch.class,"setModelData");
        ModelManager.instance.wolf.tag.animationClips.put("Wolf_Sit_idle",new Object());
        ModelManager.instance.wolf.tag.animationClips.put("Wolf_getup",new Object());
        IsoDeadBody body=new IsoDeadBody();
        body.data.put("isGarou",true); body.data.put("trueForm","Lupus");
        body.data.put("wolfCoatTexture","media/textures/Body/WTAGarou_Wolf_Blonde.png");
        body.visual.bodyVisuals.add("Underwear");
        Params p=new Params(); p.init(body);
        check(p.baseVisual!=body.visual && p.baseVisual instanceof HumanVisual,"render snapshot, not saved human visual");
        HumanVisual snap=(HumanVisual)p.baseVisual;
        check(snap.model==ModelManager.instance.wolf && snap.script.equals("WTAGarou_Lupus"),"wolf model and script");
        check(snap.skin.equals("WTAGarou_Wolf_Blonde"),"saved selected coat used");
        check(snap.hair.equals("") && snap.beard.equals("") && snap.bodyVisuals.isEmpty(),"native bald/no-beard, no random hair or overlays");
        check(snap.color==zombie.core.ImmutableColor.white && body.visual.color==null,"fur uses neutral tint without changing saved human tone");
        check(body.visual.skin.equals("HumanSkin") && body.visual.hair.equals("HumanHair")
            && body.visual.bodyVisuals.size()==1,"saved human appearance untouched");
        check(p.itemVisuals.isEmpty() && p.attachedModelNames.isEmpty(),"render-only gear hidden");
        check(p.animSetName.equals(TrueFormCorpse.ANIM_SET) && p.trackTime==0
            && p.diedBoneTransforms==null && !p.ragdollFall && p.grappleable==null,"wolf dead pose ignores human ragdoll");
        check(p.primaryHandItem==null && p.secondaryHandItem==null,"no skewed held models on corpse");
        body.data.put("trueForm","Homid"); p=new Params(); p.init(body);
        check(p.baseVisual==body.visual && p.itemVisuals.size()==1,"Human-born corpse unchanged");
        body.data.put("trueForm","Lupus"); body.skeleton=true; p=new Params(); p.init(body);
        check(p.baseVisual==body.visual,"decomposed skeleton uses native fallback");
        body.skeleton=false; body.data.put("isGarou",false); p=new Params(); p.init(body);
        check(p.baseVisual==body.visual,"non-Garou corpse unchanged");
        body.data.put("isGarou",true);
        ModelManager.instance.wolf.ready=false; p=new Params(); p.init(body);
        check(p.baseVisual==body.visual && p.itemVisuals.size()==1,"pending wolf model leaves original corpse intact");
        ModelManager.instance.wolf.ready=true;
        zombie.core.textures.Texture.blonde.ready=false; p=new Params(); p.init(body);
        check(p.baseVisual==body.visual,"pending coat leaves original corpse intact");
        zombie.core.textures.Texture.blonde.ready=true;
        body.data.put("wolfCoatTexture","../../bad");
        check(TrueFormCorpse.coatPath(body).equals("media/textures/Body/WTAGarou_Wolf_Timber.png"),"reject arbitrary saved texture path");
        p.init("mannequin"); check(p.animSetName.equals("mannequin"),"other overload unchanged");
        Animated a=new Animated(); a.setModelData(null,null);
        check(a.modelInstance.scale==1,"ordinary atlas scale untouched");
        a.set=TrueFormCorpse.ANIM_SET; a.player.twistBones.add("human twist");
        a.setModelData(null,null);
        check(a.modelInstance.scale==WolfRuntime.BODY_SCALE && a.player.twistBones.isEmpty(),"corpse normalized to Lupus, rig clean");
        a.setModelData(null,null);
        check(a.modelInstance.scale==WolfRuntime.BODY_SCALE,"normalization never compounds");
        System.out.println("PASS: "+checks+" true-form corpse snapshot/ownership assertions; not an in-game render.");
    }
}
