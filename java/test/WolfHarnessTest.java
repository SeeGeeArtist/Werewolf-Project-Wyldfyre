import wtagarou.visuals.*;
import zombie.core.skinnedmodel.ModelManager;
import net.bytebuddy.agent.ByteBuddyAgent;

/** Loader/palette-order and ownership tests with fixtures, not a game render. */
public class WolfHarnessTest {
    static int checks;
    static void check(boolean ok,String why) { checks++; if(!ok) throw new AssertionError(why); }
    public static class Palette {
        public Object model,skin,anim,tex;
        public boolean published;
        public void initModel(WolfCombatTest.Instance instance, Palette parent) {
            model=instance.model; skin=instance.data; anim=instance.animPlayer;
        }
        // Matches B42.21: a separate no-argument publishing stage.
        public Palette init() { published=true; return this; }
    }
    public static class WorldPalette extends Palette {
        public Object cachedModel, cachedTex;
        @Override public void initModel(WolfCombatTest.Instance instance, Palette parent) {
            super.initModel(instance,parent);
            cachedModel=instance.model; cachedTex=instance.tex;
        }
    }
    public static void main(String[] args) throws Exception {
        var instrumentation=ByteBuddyAgent.install();
        var patch=WolfHarnessInitPatch.class.getAnnotation(me.zed_0xff.zombie_buddy.Patch.class);
        check("initModel".equals(patch.methodName()),"hook is not the no-argument init publisher");
        WolfCombatTest.install(instrumentation,Palette.class,WolfHarnessInitPatch.class,patch.methodName());
        WolfCombatTest.install(instrumentation,WolfCombatTest.Instance.class,WolfAttachmentResetPatch.class,"reset");
        var chr=new WolfCombatTest.Character();
        var manager=ModelManager.instance;
        check(WTAGarouJava.setWolf(chr,true).equals("wolf"),"fixture wolf ready");
        var body=new WolfCombatTest.Instance();
        body.character=chr; body.model=manager.wolf; body.animPlayer=new Object();
        var harness=new WolfCombatTest.Instance();
        harness.parent=body; harness.model=new Object(); harness.animPlayer=new Object();
        harness.data=new Object(); harness.attachmentNameSelf="WTAGarou_Harness";
        harness.attachmentNameParent="WTAGarou_Harness"; harness.parentBoneName="Bip01_Spine2";
        harness.parentBone=18; harness.modelScript=new WolfCombatTest.Script(1);
        Object originalModel=harness.model, originalAnim=harness.animPlayer, originalSkin=harness.data;
        var palette=new WorldPalette();
        palette.initModel(harness,null);
        check(WolfHarness.initObserved && palette.model==manager.harness,"skinned asset selected BEFORE palette init");
        check(!palette.published && palette.cachedModel==manager.harness
                && palette.cachedTex==manager.harness.tex,"world subclass caches corrected model and texture");
        palette.init();
        check(palette.published,"no-argument publisher remains native");
        check(palette.skin==manager.harness.tag && palette.skin!=manager.wolf.tag,"retain own bind poses/joint mapping");
        check(palette.anim==body.animPlayer,"share body animator");
        check(harness.parentBone==-1 && harness.parentBoneName==null && harness.attachmentNameSelf==null,
                "clear numeric/name mount and self attachment");
        body.animPlayer=new Object(); palette.initModel(harness,null);
        check(palette.anim==body.animPlayer,"body animator rebuild picked up without stale caching");
        harness.modelScript.name="Base.WTAGarou_Harness_Camo"; palette.initModel(harness,null);
        check(palette.model==manager.harnessCamo && harness.tex==manager.harnessCamo.tex,"Camo loads skinned variant");
        check(manager.harness.tag!=manager.wolf.tag,"shared source models unchanged");
        for(float form:new float[]{1.15f,1.55f}) {
            WTAGarouJava.setScale(chr,form);
            check(WolfHarness.prepare(harness) && harness.scale==1,"no inverse body or form compensation");
        }
        WolfHarness.restore(harness);
        check(harness.model==originalModel && harness.animPlayer==originalAnim && harness.data==originalSkin,
                "restore original native carrier");
        check(harness.parentBone==18 && "Bip01_Spine2".equals(harness.parentBoneName)
                && "WTAGarou_Harness".equals(harness.attachmentNameSelf),"restore all attachment fields");
        manager.harnessCamo.isStatic=true;
        check(!WolfHarness.prepare(harness) && harness.model==originalModel,"reject a static model without skinning");
        manager.harnessCamo.isStatic=false;
        manager.harnessCamo.mesh.ready=false;
        check(!WolfHarness.prepare(harness) && harness.model==originalModel,"pending asset leaves carrier untouched");
        manager.harnessCamo.mesh.ready=true;
        check(WolfHarness.prepare(harness),"pending asset retries");
        harness.reset(); harness.model=new Object(); Object reused=harness.model;
        WolfHarness.restoreAll();
        check(harness.model==reused && harness.animPlayer==null,"pool reset discards, never restores stale fields");
        harness.parent=body; harness.attachmentNameParent="WTAGarou_Harness";
        harness.modelScript=new WolfCombatTest.Script(1); harness.modelScript.name="arbitrary";
        check(!WolfHarness.prepare(harness) && harness.model==reused,"unallowlisted script rejected");
        harness.modelScript.name="WTAGarou_Harness"; body.model=manager.human;
        check(!WolfHarness.prepare(harness) && harness.model==reused,"human previews untouched");
        body.model=manager.wolf; body.animPlayer=null;
        check(!WolfHarness.prepare(harness),"missing wolf animator does not create a human/independent animator");
        body.animPlayer=new Object();
        check(WolfHarness.prepare(harness),"wolf animator recovers");
        WTAGarouJava.setWolf(chr,false);
        check(harness.model==reused,"wolf deactivation restores carrier");
        System.out.println("PASS: "+checks+" skinned-harness loader/palette/pooling assertions; not an in-game render.");
    }
}
