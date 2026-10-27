import java.util.*;
import wtagarou.visuals.*;
import zombie.core.skinnedmodel.ModelManager;
import zombie.core.skinnedmodel.model.*;
import zombie.scripting.ScriptManager;

/** Reproduces the empty clip map from the user log. No native importer here. */
public class WolfClipLoaderTest {
    static int checks;
    static void check(boolean value,String why) { checks++; if(!value) throw new AssertionError(why); }
    static final String[] NAMES={"Wolf_idle","Wolf_walk","Wolf_run","Wolf_attack",
        "Wolf_hitreaction","Wolf_Sit","Wolf_eat","Wolf_death","Wolf_dead","Wolf_run_fourx","Wolf_Sit_idle","Wolf_getup","Wolf_howl"};
    static void complete(ModelManager manager) {
        for (String name:NAMES) {
            AnimationAsset asset=manager.modAnimations.get("WTAGarou").animationAssetMap
                    .get(("WTAGarouWolf/"+name).toLowerCase(Locale.ROOT));
            if(asset!=null) { asset.animationClips.put(name,new Object()); asset.ready=true; }
        }
    }
    public static void main(String[] args) throws Exception {
        ModelManager manager=ModelManager.instance;
        manager.wolf.tag.animationClips.clear();
        check(!WolfAssets.inspect(manager.wolf).ready,"reproduce clip count zero");
        WolfClipLoader.ensure(manager,manager.wolf);
        check(manager.loads==13,"all mapped wolf actions including sprint explicitly queued");
        check(manager.modAnimations.get("WTAGarou").priority==1,"active mod priority preserved");
        check(manager.wolf.tag.animationClips.isEmpty(),"no fabricated animation while async import pending");
        for(int i=0;i<50;i++) WolfClipLoader.ensure(manager,manager.wolf);
        check(manager.loads==13,"pending calls do not requeue or leak reference increments");
        complete(manager); // Native-ready assets without a repeated callback.
        WolfClipLoader.ensure(manager,manager.wolf);
        check(WolfAssets.inspect(manager.wolf).ready,"READY assets populate exact wolf map");
        check(manager.wolf.tag.animationClips.size()==13,"all mapped actions installed");
        for (String required:new String[]{"Wolf_death","Wolf_run_fourx"}) {
            Object clip=manager.wolf.tag.animationClips.remove(required);
            check(!WolfAssets.inspect(manager.wolf).ready,"death and sprint must be ready before wolf activation");
            manager.wolf.tag.animationClips.put(required,clip);
        }
        WolfCombatTest.Character character=new WolfCombatTest.Character();
        check(WTAGarouJava.setWolf(character,true).equals("wolf") && WolfRuntime.modelFor(character)==manager.wolf,
                "repaired map passes full player-body activation preflight");
        WTAGarouJava.setWolf(character,false);
        check(!WolfRuntime.active(character),"repaired wolf still restores human");
        WolfClipLoader.ensure(manager,manager.wolf);
        check(manager.loads==13,"complete map is idempotent");
        manager.wolf.tag.animationClips.clear();
        WolfClipLoader.ensure(manager,manager.wolf);
        check(WolfAssets.inspect(manager.wolf).ready && manager.loads==13,"cached clips restored without global reload");

        // A newly loaded rig must not reuse cached clips imported against the
        // previous skeleton's bone indices. Only the twelve namespaced assets reload.
        manager.wolf=new ModelManager.TestModel(); manager.wolf.tag.animationClips.clear();
        ScriptManager.instance.rig.modelMesh=manager.wolf.mesh;
        WolfClipLoader.ensure(manager,manager.wolf);
        check(AnimationAssetManager.instance.reloads==13,"wrong-skeleton cached assets explicitly reimported");
        check(manager.wolf.tag.animationClips.isEmpty(),"old bone indices never copied to new rig");
        complete(manager); WolfClipLoader.ensure(manager,manager.wolf);
        check(WolfAssets.inspect(manager.wolf).ready,"reimported clips accepted");
        check(manager.loads==13,"cache repair uses reload not duplicate registration");

        // Failed or malformed required assets fail closed, not a pretend-ready wolf.
        manager.wolf.tag.animationClips.remove("Wolf_attack");
        AnimationAsset attack=manager.modAnimations.get("WTAGarou").animationAssetMap.get("wtagarouwolf/wolf_attack");
        attack.failed=true;
        try { WolfClipLoader.ensure(manager,manager.wolf); throw new AssertionError("failed asset accepted"); }
        catch(IllegalStateException expected) { check(expected.getMessage().contains("required wolf animation failed"),"failed clip named"); }
        attack.failed=false; attack.animationClips.clear();
        try { WolfClipLoader.ensure(manager,manager.wolf); throw new AssertionError("empty import accepted"); }
        catch(IllegalStateException expected) { check(expected.getMessage().contains("without clip Wolf_attack"),"wrong embedded name rejected"); }
        attack.animationClips.put("Wolf_attack",new Object());
        WolfClipLoader.ensure(manager,manager.wolf);
        check(WolfAssets.inspect(manager.wolf).ready,"repaired asset can recover");

        manager.wolf.tag.animationClips.remove("Wolf_idle");
        Object oldMesh=ScriptManager.instance.rig.modelMesh;
        ScriptManager.instance.rig.modelMesh=new ModelMesh(new ModelManager.Data());
        try { WolfClipLoader.ensure(manager,manager.wolf); throw new AssertionError("mismatched rig accepted"); }
        catch(IllegalStateException expected) { check(expected.getMessage().contains("same skinning data"),"wrong rig rejected"); }
        ScriptManager.instance.rig.modelMesh=oldMesh;
        manager.modAnimations.get("WTAGarou").priority=-1;
        try { WolfClipLoader.ensure(manager,manager.wolf); throw new AssertionError("inactive mod accepted"); }
        catch(IllegalStateException expected) { check(expected.getMessage().contains("inactive"),"inactive registration respected"); }
        manager.modAnimations.clear();
        zombie.ZomboidFileSystem.instance.modIDs.clear();
        try { WolfClipLoader.ensure(manager,manager.wolf); throw new AssertionError("disabled mod accepted"); }
        catch(IllegalStateException expected) { check(expected.getMessage().contains("not an active mod"),"disabled mod never enabled by loader"); }
        System.out.println("PASS: "+checks+" explicit wolf clip loader assertions.");
    }
}
