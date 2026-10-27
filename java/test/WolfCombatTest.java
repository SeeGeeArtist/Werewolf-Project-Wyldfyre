import java.util.*;
import java.lang.instrument.Instrumentation;
import net.bytebuddy.ByteBuddy;
import net.bytebuddy.agent.ByteBuddyAgent;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.dynamic.loading.ClassReloadingStrategy;
import static net.bytebuddy.matcher.ElementMatchers.named;
import wtagarou.visuals.*;
import zombie.core.skinnedmodel.ModelManager;

/** Contract tests with real ZombieBuddy annotation translation, NOT game tests. */
public class WolfCombatTest {
    static int checks;
    static void check(boolean ok,String text) { checks++; if(!ok) throw new AssertionError(text); }
    public static class Weapon {
        public boolean ranged;
        public boolean isRanged() { return ranged; }
    }
    public static class HandAction { public boolean overrideHandModels=true; }
    public static class Container { public String getCategory() { return "Container"; } }
    public static class Animator {
        public boolean fail;
        public int resets;
        public void OnAnimDataChanged(boolean reload) {
            if (fail) throw new IllegalStateException("reset failed");
            if (reload) throw new AssertionError("must preserve gameplay state");
            resets++;
        }
    }
    public static class Character {
        public int rebuilds;
        public boolean dead, forceGetUp;
        public boolean running,sprinting,moving;
        public String type="heavy";
        public Weapon weapon=new Weapon();
        public Object primaryItem=weapon;
        public Object secondaryItem;
        public Object getSecondaryHandItem() { return secondaryItem; }
        public boolean getVariableBoolean(String name) { return name.equals("forceGetUp") && forceGetUp; }
        public Object primaryHandModel, secondaryHandModel;
        public java.util.Stack<HandAction> actions=new java.util.Stack<>();
        public String overridePrimaryHandModel, overrideSecondaryHandModel;
        public java.util.Stack<HandAction> getCharacterActions() { return actions; }
        public Animator animator=new Animator();
        public Player maskPlayer;
        public Player getAnimationPlayer() { return maskPlayer; }
        public void resetModelNextFrame() { rebuilds++; }
        public Animator getAdvancedAnimator() { return animator; }
        public boolean isDead() { return dead; }
        // 0.4.40 corpse handling: dragging state / grapple flags.
        public boolean grappling, throwingIntoContainer;
        public String stateName="IdleState";
        public static final class State { final String n; State(String n){this.n=n;} public String getName(){ return n; } }
        public State getCurrentState() { return new State(stateName); }
        public boolean isGrappling() { return grappling; }
        public Object inventory=new Object();
        public Object getInventory() { return inventory; }
        public boolean isGrappleThrowIntoContainer() { return throwingIntoContainer; }
        public boolean isRunning() { return running; }
        public boolean isSprinting() { return sprinting; }
        public boolean isMoving() { return moving; }
        public Object getPrimaryHandItem() { return primaryItem; }
        public boolean canUseCurrentPoseForCorpse() { return true; }
        public boolean becomeCorpse() {
            check(ModelManager.instance.getBodyModel(this)==ModelManager.instance.human,"corpse uses human body");
            return canUseCurrentPoseForCorpse();
        }
        public String getVariableString(String name) {
            if (!name.equals("Weapon")) throw new AssertionError(name);
            return type;
        }
        public void onAnimPlayerCreated(Player player) {
            player.reparentedBoneBindings.add("human reparent");
            player.twistBones.add("human twist");
            player.counterRotationBone="human counter";
        }
    }
    public static class Params {
        public String animName="Bob_Attack1Hand01_Hit";
        public Object subLayerBoneWeights=new ArrayList<>(List.of(new Weight("Bip01_Spine"),new Weight("AbsentBone")));
        public String deferredBoneName="Translation_Data";
        public boolean useDeferredRotation=true;
        public Axis deferredBoneAxis=Axis.Y;
        public boolean isRagdoll;
        public boolean isReversed, isLooped;
    }
    public enum Axis { Y,Z }
    public static class Weight {
        public String boneName;
        public Weight(String name) { boneName=name; }
    }
    public static class Player {
        public Character character;
        public List<Object> reparentedBoneBindings=new ArrayList<>();
        public List<Object> twistBones=new ArrayList<>();
        public Object counterRotationBone;
        public boolean fail;
        public boolean playedReversed, playedLooped;
        public Character getIsoGameCharacter() { return character; }
        public Object getSkinningData() { return ModelManager.instance.wolf.tag; }
        public String play(Params params,Object layer) {
            playedReversed=params.isReversed; playedLooped=params.isLooped;
            List<?> mask=(List<?>)params.subLayerBoneWeights;
            if(mask==null) {
                // root layer: passthrough, nothing to assert about the mask
            } else if(WolfRuntime.isGaitClip(params.animName)) {
                check(mask.isEmpty(),"sub-layer gait track made inert: "+params.animName);
            } else {
                check(mask.size()==1,"sub-layer action track takes the whole body: "+params.animName);
                Object w=mask.get(0);
                check(w instanceof zombie.core.skinnedmodel.advancedanimation.AnimBoneWeight b
                        && "Bip01".equals(b.boneName) && b.weight==1.0f && b.includeDescendants,
                    "full-body mask is AnimBoneWeight(Bip01, 1.0) with descendants");
            }
            check(player_rigClean(this),"rig enforced on every wolf track start");
            check(params.deferredBoneName.equals("Translation_Data"),"human marker kept as deferred bone (human parity)");
            check(!params.useDeferredRotation,"raw wolf clip fallback: constant marker rotation must not suppress facing");
            if(fail) throw new IllegalArgumentException("track failure");
            return params.animName;
        }
        public String play(String name,boolean looped) { return name; }
    }
    static boolean player_rigClean(Player p) {
        return p.reparentedBoneBindings.isEmpty() && p.twistBones.isEmpty() && p.counterRotationBone==null;
    }
    public static class Swipe {
        public float OnAnimEvent_SetMeleeDelay(Object character,float delay) { return delay; }
        public float countdownSetter(float value) { return value; }
    }
    public static class Slot { public float finalScale=0.8f; public Object character; }
    public static class Script {
        public String name="WTAGarou_Harness";
        public float scale=1f; public Script(float s){ scale=s; }
    }
    public static class Instance {
        public Object character, model, tex="shared original";
        public Object animPlayer, data;
        public int parentBone;
        public String attachmentNameParent, attachmentNameSelf, parentBoneName;
        public float scale=1f;
        public Instance parent;
        public Script modelScript;
        public void reset() {
            character=null; model=null; parent=null; modelScript=null;
            attachmentNameParent=null; attachmentNameSelf=null; parentBoneName=null; scale=1f;
            animPlayer=null; data=null; parentBone=0;
        }
    }
    public static class RenderData { public Instance modelInstance=new Instance(); public Object tex="human texture"; }
    public static class Renderer {
        public int calls; public boolean checkScale=true;
        public Object DrawChar(Slot slot, RenderData data,boolean fail) {
            calls++;
            if(checkScale) {
                float expected=WolfRuntime.attachedToWolf(data.modelInstance,data.modelInstance.character) ? 0.8f : 0.648f;
                check(Math.abs(slot.finalScale-expected)<0.00001,"body normalized, gear matrix already scaled");
            }
            if(fail) throw new IllegalArgumentException("draw failure");
            return data.tex;
        }
    }
    /** Stand-ins for AnimatedModelInstanceRenderData / JOML Matrix4f: only the
     * calls the mouth transform makes are recorded. */
    public static class Matrix {
        public final java.util.List<String> calls=new java.util.ArrayList<>();
        public Matrix transpose() { calls.add("transpose"); return this; }
        public Matrix rotateXYZ(float x,float y,float z) { calls.add(String.format(java.util.Locale.ROOT,"rotateXYZ(%.4f,%.4f,%.4f)",x,y,z)); return this; }
        public Matrix translate(float x,float y,float z) { calls.add(String.format(java.util.Locale.ROOT,"translate(%.2f,%.2f,%.2f)",x,y,z)); return this; }
        public Matrix scale(float s) { calls.add(String.format(java.util.Locale.ROOT,"scale(%.2f)",s)); return this; }
        public Matrix scaleLocal(float s) { calls.add(String.format(java.util.Locale.ROOT,"scaleLocal(%.2f)",s)); return this; }
        public Matrix translateLocal(float x,float y,float z) { calls.add(String.format(java.util.Locale.ROOT,"translateLocal(%.2f,%.2f,%.2f)",x,y,z)); return this; }
    }
    public static class XfrmData {
        public Instance modelInstance; public Matrix xfrm=new Matrix();
        public Object properties;
        public float bakedScale;
        public String bakedBone;
        public XfrmData transformToParent(Object parent) {
            bakedScale=modelInstance.scale; bakedBone=modelInstance.parentBoneName;
            xfrm.calls.add("engine"); return this;
        }
    }
    public static class Node {
        public String animName="Bob_SitFurniture";
        public String getDeferredBoneName() { return "Bip01"; }
    }
    public static class MaskLayer { public Character character; }
    public static class MaskClip { public String name="Bob_Attack1Hand01_Miss"; }
    public static class MaskTrack {
        public MaskClip clip=new MaskClip();
        public List<?> weights;
        public int inits;
        public MaskClip getClip() { return clip; }
        public void setBoneWeights(List<?> value) { weights=value; }
        public void initBoneWeights(zombie.core.skinnedmodel.model.SkinningData skin) { inits++; }
    }
    public static class MaskNode {
        public MaskLayer animLayer=new MaskLayer();
        public void initTrackBoneWeights(MaskTrack track,boolean masked) {
            track.setBoneWeights(masked ? List.of(new Weight("Bip01_Spine")) : null);
        }
    }
    public static class Seating {
        public Object received;
        public void getTotalDeferredMovement(zombie.core.skinnedmodel.model.SkinningData data,
                                            Node node, Object result) {
            received=data;
        }
    }
    static void install(Instrumentation inst,Class<?> target,Class<?> patch,String method) throws Exception {
        installAll(inst,target,new Class<?>[]{patch},new String[]{method});
    }
    static void installAll(Instrumentation inst,Class<?> target,Class<?>[] patches,String[] methods) throws Exception {
        Class<?> transformer=Class.forName("me.zed_0xff.zombie_buddy.PatchTransformer");
        var transform=transformer.getDeclaredMethod("transformPatchClass",
                Class.class,Instrumentation.class,int.class,boolean.class);
        transform.setAccessible(true);
        var builder=new ByteBuddy().redefine(target);
        for (int i=0;i<patches.length;i++) {
            Class<?> advice=(Class<?>)transform.invoke(null,patches[i],inst,0,false);
            builder=builder.visit(Advice.to(advice).on(named(methods[i])));
        }
        builder.make().load(target.getClassLoader(),ClassReloadingStrategy.of(inst));
    }
    public static void main(String[] args) throws Exception {
        var inst=ByteBuddyAgent.install();
        installAll(inst,ModelManager.class,new Class<?>[]{BodyModelPatch.class,WolfDeathResetPatch.class},
                new String[]{"getBodyModel","Reset"});
        install(inst,Player.class,WolfTrackPatch.class,"play");
        installAll(inst,Character.class,new Class<?>[]{WolfRigPatch.class,WolfCorpsePatch.class,WolfCorpsePosePatch.class},
                new String[]{"onAnimPlayerCreated","becomeCorpse","canUseCurrentPoseForCorpse"});
        install(inst,Swipe.class,MeleeDelayPatch.class,"OnAnimEvent_SetMeleeDelay");
        install(inst,Renderer.class,DrawCharPatch.class,"DrawChar");
        install(inst,Seating.class,WolfSeatingPatch.class,"getTotalDeferredMovement");
        install(inst,XfrmData.class,MouthCarryPatch.class,"transformToParent");
        install(inst,Instance.class,WolfAttachmentResetPatch.class,"reset");
        install(inst,MaskNode.class,WolfAttackMaskPatch.class,"initTrackBoneWeights");
        var manager=ModelManager.instance;
        Character garou=new Character(), ordinary=new Character();
        check(!WolfAssets.inspect(null).ready && WolfAssets.inspect(null).detail.contains("lookup returned null"),
                "missing model separately identified");
        manager.wolf.failed=true;
        check(WolfAssets.inspect(manager.wolf).failed && WolfAssets.inspect(manager.wolf).detail.contains("FAILURE"),
                "failed model does not wait forever");
        manager.wolf.failed=false;
        var texture=manager.wolf.tex;
        manager.wolf.tex=null;
        check(WolfAssets.inspect(manager.wolf).failed && WolfAssets.inspect(manager.wolf).detail.contains("texture=null"),
                "missing texture separately identified");
        manager.wolf.tex=texture; texture.ready=false;
        check(!WolfAssets.inspect(manager.wolf).failed && WolfAssets.inspect(manager.wolf).detail.contains("texture state=EMPTY"),
                "asynchronous texture remains pending");
        texture.failed=true;
        check(WolfAssets.inspect(manager.wolf).failed,"failed texture distinguished from loading");
        texture.ready=true; texture.failed=false;
        var skinning=manager.wolf.tag; manager.wolf.tag=null;
        check(WolfAssets.inspect(manager.wolf).detail.contains("skinning data=null"),"absent rig diagnosed");
        manager.wolf.tag=skinning;
        String paths=WolfAssets.sources();
        check(paths.contains("model script=present") && paths.contains("animation rig=present"),"script registry checked");
        check(!paths.contains("MISSING") && !paths.contains("unavailable") && paths.contains("Wolf_idle.glb=exists"),
                "engine VFS probe resolves actual packaged assets");
        zombie.ZomboidFileSystem.instance.missing=true;
        check(WolfAssets.sources().contains("Wolf_idle.glb=MISSING"),"unresolved installation path reported");
        zombie.ZomboidFileSystem.instance.missing=false;
        Object script=zombie.scripting.ScriptManager.instance.script;
        zombie.scripting.ScriptManager.instance.script=null;
        check(WolfAssets.sources().contains("model script=MISSING"),"absent model script reported");
        zombie.scripting.ScriptManager.instance.script=script;
        check(manager.getBodyModel(garou)==manager.human,"unregistered player body unchanged");
        manager.wolf.ready=false;
        check(WTAGarouJava.setWolf(garou,true).equals("pending"),"async loading waits");
        check(WolfRuntime.status().contains("model state=EMPTY"),"pending status identifies exact asset stage");
        check(!WolfRuntime.active(garou),"pending never hides human");
        manager.wolf.ready=true;
        Object attackClip=manager.wolf.tag.animationClips.remove("Wolf_attack");
        check(WTAGarouJava.setWolf(garou,true).equals("pending"),"required clips preflight");
        check(WolfRuntime.status().contains("missing clips=[Wolf_attack]"),"missing clip named explicitly");
        check(WolfRuntime.status().contains("Wolf_attack.glb=exists"),"clip file distinguished from imported clip");
        manager.wolf.tag.animationClips.put("Wolf_attack",attackClip);
        check(WTAGarouJava.setWolf(garou,true).equals("wolf"),"activate ready model");
        check(manager.getBodyModel(garou)==manager.wolf,"body hook returns actual wolf model");
        check(manager.getBodyModel(ordinary)==manager.human,"other players unchanged");
        check(garou.rebuilds==1 && garou.animator.resets==1,"model and tracks rebuilt");
        check(!WolfRuntime.status().contains("MISSING") && !WolfRuntime.status().contains("missing clips"),
                "ready state clears old blockage");
        WTAGarouJava.setWolf(garou,true);
        check(garou.rebuilds==1,"idempotent activation");
        Player player=new Player(); player.character=garou;
        garou.onAnimPlayerCreated(player);
        check(player.reparentedBoneBindings.isEmpty() && player.twistBones.isEmpty()
            && player.counterRotationBone==null,"human skeleton overrides removed");
        Player humanPlayer=new Player(); humanPlayer.character=ordinary;
        ordinary.onAnimPlayerCreated(humanPlayer);
        check(humanPlayer.reparentedBoneBindings.size()==1,"ordinary rig untouched");
        for(String[] row : new String[][]{
            {"Bob_Walk","Wolf_walk"},{"Bob_Run","Wolf_run"},{"Bob_Sprint","Wolf_run_fourx"},
            {"Bob_Attack2H_Heavy01_Hit","Wolf_attack"},{"Bob_AttackFloorStab","Wolf_attack"},
            {"Bob_HitReaction","Wolf_hitreaction"},{"Bob_Drink","Wolf_eat"},
            {"Bob_SitGround","Wolf_Sit"},{"Bob_Death","Wolf_death"},{"Bob_Unknown","Wolf_idle"}}) {
            Params p=new Params();p.animName=row[0]; Object mask=p.subLayerBoneWeights;
            check(player.play(p,new Object()).equals(row[1]),"clip substitution "+row[0]);
            check(p.animName.equals(row[0]) && p.subLayerBoneWeights==mask
                    && p.deferredBoneName.equals("Translation_Data") && p.useDeferredRotation,"pooled parameters restored");
        }
        check(player.play("Bob_Direct",true).equals("Bob_Direct"),"String overload untouched");
        manager.wolf.tag.animationClips.put("Wolf_getup",new Object());
        Params reverseSit=new Params(); reverseSit.animName="Bob_SitOnGround";
        reverseSit.isReversed=true; reverseSit.isLooped=true;
        check(player.play(reverseSit,new Object()).equals("Wolf_getup"),"reversed sit selects authored get-up");
        check(!player.playedReversed && !player.playedLooped,"get-up plays forward once");
        check(reverseSit.isReversed && reverseSit.isLooped,"pooled reverse/loop flags restored");
        Params groundExit=new Params(); groundExit.animName="Bob_SitOnGroundEnd";
        check(player.play(groundExit,new Object()).equals("Wolf_getup"),"ground exit selects get-up");
        groundExit.animName="Bob_SitOnGround";
        garou.forceGetUp=true;
        check(player.play(groundExit,new Object()).equals("Wolf_getup"),"ground forceGetUp variable selects get-up");
        garou.forceGetUp=false;
        for(String name:new String[]{"Bob_SitGround_Out","Bob_SitGround_OutQuick"}) {
            groundExit.animName=name; groundExit.isReversed=true; groundExit.isLooped=true;
            check(player.play(groundExit,new Object()).equals("Wolf_getup"),"native ground exit alias: "+name);
            check(!player.playedReversed && !player.playedLooped,"same forward-once get-up as chair");
            check(groundExit.isReversed && groundExit.isLooped && groundExit.animName.equals(name),
                "native ground exit pooled parameters restored");
        }
        check(WolfRuntime.preferredClipFor("Bob_SitGround_EndDeath").equals("Wolf_death"),
            "seated death must never be mistaken for get-up");
        // Re-dirtied rig (missed/re-run onAnimPlayerCreated) is stripped again by the track hook.
        player.twistBones.add("human twist"); player.counterRotationBone="human counter";
        int before=WolfRuntime.rigEnforcedFromTrack;
        { Params p=new Params(); p.animName="Bob_Walk"; player.play(p,new Object()); }
        check(player_rigClean(player) && WolfRuntime.rigEnforcedFromTrack==before+1,"track hook re-enforces the wolf rig");
        { Params p=new Params(); p.animName="Bob_Walk"; player.play(p,new Object()); }
        check(WolfRuntime.rigEnforcedFromTrack==before+1,"clean rig costs no enforcement");
        // Root layer (null / empty mask) passes through untouched.
        { Params p=new Params(); p.animName="Bob_Walk"; p.subLayerBoneWeights=null;
          check(player.play(p,new Object()).equals("Wolf_walk"),"root layer null mask substitutes");
          check(p.subLayerBoneWeights==null,"root layer null mask restored"); }
        check(((List<?>)WolfRuntime.layerWeights(null,null,"Wolf_walk")).isEmpty(),"null source masks still suppress sublayer gait; engine ignores parameter on root");
        List<Object> empty=new ArrayList<>();
        check(WolfRuntime.layerWeights(empty,null,"Wolf_attack")==empty,"empty root mask passes through");
        check(((List<?>)WolfRuntime.layerWeights(List.of(new Weight("Bip01_Head")),null,"Wolf_run_fourx")).isEmpty(),
            "head-layer sprint is inert");
        check(((List<?>)WolfRuntime.layerWeights(List.of(new Weight("Bip01_Head")),null,"Wolf_run_V2")).isEmpty(),
            "head-layer walking-speed run variant is inert");
        check(((List<?>)WolfRuntime.layerWeights(List.of(new Weight("Bip01_Spine")),null,"Wolf_hitreaction")).size()==1,
            "hit reaction sub-layer takes the whole body");
        check(WolfRuntime.fullBodyWeights()==WolfRuntime.fullBodyWeights(),"full-body mask is built once");
        Params p=new Params(); Object mask=p.subLayerBoneWeights;player.fail=true;
        try { player.play(p,new Object()); throw new AssertionError("exception swallowed"); }
        catch(IllegalArgumentException expected) {
            check(p.animName.startsWith("Bob_") && p.subLayerBoneWeights==mask
                    && p.useDeferredRotation,"exception restores params");
        }
        Node node=new Node(); Seating seating=new Seating();
        manager.maleModel.tag.animationClips.put(node.animName,new Object());
        manager.maleModel.tag.boneIndices.put("Bip01",0);
        seating.getTotalDeferredMovement(manager.wolf.tag,node,new Object());
        check(seating.received==manager.maleModel.tag,"human seating query uses human motion data");
        check(!manager.wolf.tag.animationClips.containsKey(node.animName),"no human clip inserted into wolf skeleton");
        seating.getTotalDeferredMovement(manager.maleModel.tag,node,new Object());
        check(seating.received==manager.maleModel.tag,"ordinary seating data untouched");
        node.animName="Wolf_Sit";
        seating.getTotalDeferredMovement(manager.wolf.tag,node,new Object());
        check(seating.received==manager.wolf.tag,"existing native wolf clip not overridden");
        node.animName="Unknown_Clip";
        seating.getTotalDeferredMovement(manager.wolf.tag,node,new Object());
        check(seating.received==manager.wolf.tag,"unknown query not replaced with fabricated data");
        Slot slot=new Slot(); RenderData data=new RenderData(); Renderer renderer=new Renderer();
        data.modelInstance.character=garou;data.modelInstance.model=manager.wolf;
        WTAGarouJava.setScale(garou,1.35);
        check(renderer.DrawChar(slot,data,false)==manager.wolf.tex,"body uses wolf texture");
        check(data.tex==manager.wolf.tex && slot.finalScale==0.8f,"queued record retains texture; scale restored");
        check(data.modelInstance.tex.equals("shared original"),"shared instance texture untouched");
        Object sharedTexture=manager.wolf.tex;
        WTAGarouJava.setWolfCoat(data.modelInstance.character,"blonde");
        check(renderer.DrawChar(slot,data,false)==zombie.core.textures.Texture.blonde,"selected coat used in body render");
        check(manager.wolf.tex==sharedTexture,"coat never mutates shared model");
        WTAGarouJava.setWolfTexture(data.modelInstance.character,"media/textures/Body/WTAGarou_Wolf_Brown.png");
        check(renderer.DrawChar(slot,data,false)==zombie.core.textures.Texture.brown,"data-only future coat supported");
        WTAGarouJava.setWolfTexture(data.modelInstance.character,"../../evil.png");
        check(renderer.DrawChar(slot,data,false)==sharedTexture,"arbitrary path rejected");
        WTAGarouJava.setWolfCoat(data.modelInstance.character,"blonde");
        check(WolfCoats.texture(new Object(),sharedTexture)==sharedTexture,"unselected character stays original");
        zombie.core.textures.Texture.blonde.ready=false;
        check(renderer.DrawChar(slot,data,false)==sharedTexture,"pending texture falls back safely");
        zombie.core.textures.Texture.blonde.ready=true;
        WTAGarouJava.setWolfCoat(data.modelInstance.character,"default");
        check(renderer.DrawChar(slot,data,false)==sharedTexture,"original choice restores body texture");
        try { renderer.DrawChar(slot,data,true); throw new AssertionError("draw exception swallowed"); }
        catch(IllegalArgumentException expected) {
            check(data.modelInstance.tex.equals("shared original") && slot.finalScale==0.8f,
                    "exception restores scale without shared texture mutation");
        }
        data.modelInstance.model=new Object();int calls=renderer.calls;
        renderer.DrawChar(slot,data,false);
        check(renderer.calls==calls,"human gear is not drawn on wolf");
        data.modelInstance.character=null; slot.character=garou;
        renderer.DrawChar(slot,data,false);
        check(renderer.calls==calls,"unowned gear inherits wolf slot for hiding");
        data.modelInstance.attachmentNameParent="WTAGarou_Saddlebags";
        Instance body=new Instance(); body.character=garou; body.model=manager.wolf;
        data.modelInstance.parent=body;
        renderer.checkScale=false;
        renderer.DrawChar(slot,data,false);
        renderer.checkScale=true;
        check(renderer.calls==calls+1,"saddlebag attached at a WTAGarou_ attachment is drawn on the wolf");
        check(WolfRuntime.SADDLEBAG_BONE.equals(data.modelInstance.parentBoneName),
                "saddlebag is re-parented to the wolf spine bone (human body script has no WTAGarou_ attachment)");
        check(Math.abs(data.modelInstance.scale-1f/WolfRuntime.BODY_SCALE)<0.0001f,"saddlebag mesh compensated by 1/BODY_SCALE");
        check(WolfRuntime.isSaddlebag(data.modelInstance),"saddlebag instance registered for the WTAGarou.Saddlebag post-transform");
        // 0.4.22: the engine reuses the pooled instance and resets its scale
        // from the model script (0.6). The old once-per-instance rule left it
        // there ("tiny saddlebags"); now it is compensated again.
        data.modelInstance.scale=0.6f; data.modelInstance.modelScript=new Script(0.6f);
        renderer.checkScale=false;
        renderer.DrawChar(slot,data,false);
        renderer.checkScale=true;
        check(Math.abs(data.modelInstance.scale-0.6f/WolfRuntime.BODY_SCALE)<0.0001f,"a pooled instance reset to script scale is compensated again (0.4.22)");
        check(WolfRuntime.perfRecompensated.get()>=1,"re-compensation is counted");
        renderer.checkScale=false;
        renderer.DrawChar(slot,data,false);
        renderer.checkScale=true;
        check(Math.abs(data.modelInstance.scale-0.6f/WolfRuntime.BODY_SCALE)<0.0001f,"an unchanged compensated scale is left alone");
        // 0.4.24: the target is script scale / BODY_SCALE, whatever the field holds - never compounding.
        data.modelInstance.scale=0.6f/WolfRuntime.BODY_SCALE/WolfRuntime.BODY_SCALE;
        renderer.checkScale=false;
        renderer.DrawChar(slot,data,false);
        renderer.checkScale=true;
        check(Math.abs(data.modelInstance.scale-0.6f/WolfRuntime.BODY_SCALE)<0.0001f,"an over-compensated scale is pulled back to script/BODY_SCALE (0.4.24)");
        data.modelInstance.modelScript=new Script(0.125f); data.modelInstance.scale=0.125f;
        renderer.checkScale=false;
        renderer.DrawChar(slot,data,false);
        renderer.checkScale=true;
        check(Math.abs(data.modelInstance.scale-0.125f/WolfRuntime.BODY_SCALE)<0.0001f,"a pooled instance reused for another model takes that script's scale");
        calls=renderer.calls-1;   // the extra saddlebag draws above
        data.modelInstance.scale=1f; data.modelInstance.modelScript=null;
        data.modelInstance.attachmentNameParent="Bip01_Head";
        data.modelInstance.parentBoneName=null;
        renderer.DrawChar(slot,data,false);
        check(renderer.calls==calls+1 && data.modelInstance.parentBoneName==null,"gear on a human attachment stays hidden and untouched");
        data.modelInstance.attachmentNameParent=null;
        // Mouth carry: the primary-hand model is drawn from the jaw.
        Instance held=new Instance(); held.character=garou; held.model=new Object(); held.parentBoneName="Bip01_Prop1";
        held.attachmentNameParent="Bip01_Prop1"; held.parent=body; held.scale=0.9f;
        RenderData heldData=new RenderData(); heldData.modelInstance=held;
        garou.primaryHandModel=held;
        // 0.4.17: a sub-model hanging off the wolf is drawn with the body
        // normalization too (checkScale asserts 0.8*1.35*0.6) and its mesh
        // size is given back through ModelInstance.scale.
        renderer.checkScale=true;
        renderer.DrawChar(slot,heldData,false);
        check(renderer.calls==calls+2 && WolfRuntime.MOUTH_BONE.equals(held.parentBoneName),"primary-hand item drawn at the jaw bone");
        check(WolfRuntime.MOUTH_ATTACHMENT.equals(held.attachmentNameParent),"jaw item skips the human Bip01_Prop1 attachment");
        check(!held.attachmentNameParent.startsWith(WolfRuntime.VISIBLE_ATTACHMENT_PREFIX),"jaw attachment is not mistaken for a saddlebag");
        check(Math.abs(held.scale-0.9f/(WolfRuntime.BODY_SCALE*1.35f))<0.0001f,"jaw item cancels body and form scale");
        check(WolfRuntime.isMouthCarried(held),"jaw item registered for the mouth transform");
        check(slot.finalScale==0.8f,"slot scale restored after the sub-model draw");
        renderer.DrawChar(slot,heldData,false);
        check(Math.abs(held.scale-0.9f/(WolfRuntime.BODY_SCALE*1.35f))<0.0001f,"compensation is not applied twice");
        check(WolfRuntime.attachedToWolf(held,garou),"parent chain reaches the wolf body");
        Instance loose=new Instance(); loose.character=garou; loose.model=new Object();
        check(!WolfRuntime.attachedToWolf(loose,garou),"unparented gear is not attached to the wolf");
        // 0.4.17: after the engine transform, the jaw item gets the configured
        // local rotation (default 90 degrees about Y) between two transposes.
        XfrmData xd=new XfrmData(); xd.modelInstance=held;
        xd.transformToParent(new XfrmData());
        check(xd.xfrm.calls.equals(java.util.List.of("engine","transpose",
                String.format(java.util.Locale.ROOT,"rotateXYZ(%.4f,%.4f,%.4f)",0f,(float)(90*Math.PI/180),0f),"transpose")),
                "jaw item rotated 90 degrees about Y after the engine transform: "+xd.xfrm.calls);
        WTAGarouJava.setMouthCarryTransform(0,0,0, 0.1,0,-0.05);
        xd=new XfrmData(); xd.modelInstance=held; xd.transformToParent(new XfrmData());
        check(xd.xfrm.calls.equals(java.util.List.of("engine","transpose","translate(0.10,0.00,-0.05)","transpose")),
                "offset only when rotation is zero: "+xd.xfrm.calls);
        WTAGarouJava.setMouthCarryTransform(0,90,0, 0,0,0);
        xd=new XfrmData(); xd.modelInstance=loose; xd.transformToParent(null);
        check(xd.xfrm.calls.equals(java.util.List.of("engine")),"other sub-models are left alone");
        check(MouthCarryPatch.applied && MouthCarryPatch.status().contains("applied=true"),"mouth transform reports applied");
        renderer.checkScale=false;
        WTAGarouJava.setMouthCarry(false);
        held.parentBoneName="Bip01_Prop1";
        renderer.DrawChar(slot,heldData,false);
        check(renderer.calls==calls+3 && "Bip01_Prop1".equals(held.parentBoneName),"mouth carry off: held item hidden, bone untouched");
        WTAGarouJava.setMouthCarry(true);
        Instance offhand=new Instance(); offhand.character=garou; offhand.model=new Object();
        RenderData offData=new RenderData(); offData.modelInstance=offhand;
        renderer.DrawChar(slot,offData,false);
        check(renderer.calls==calls+3,"secondary-hand gear stays hidden without a rule");
        // 0.4.23 wolf slots: a hotbar item with a WTAGarou.WolfSlots rule is drawn on the wolf.
        WTAGarouJava.clearWolfSlots();
        Instance axe=new Instance(); axe.character=garou; axe.model=new Object(); axe.parent=body;
        axe.attachmentNameParent="back"; axe.attachmentNameSelf="back"; axe.parentBoneName=null; axe.scale=1f;
        RenderData axeData=new RenderData(); axeData.modelInstance=axe;
        renderer.DrawChar(slot,axeData,false);
        check(renderer.calls==calls+3 && "back".equals(axe.attachmentNameParent),"no rule: hotbar item hidden and untouched");
        check(WolfRuntime.slotStatus().contains("hiddenAttachments=[") && WolfRuntime.slotStatus().contains("back"),
                "the hidden attachment name is recorded for the Status button: "+WolfRuntime.slotStatus());
        WTAGarouJava.setWolfSlot("Back","Bip01_Spine2", 0,0,90, 0.08,0.18,0);
        renderer.DrawChar(slot,axeData,false);
        check(renderer.calls==calls+4,"rule present: hotbar item drawn on the wolf");
        check("Bip01_Spine2".equals(axe.parentBoneName),"hotbar item re-parented to the rule's bone");
        check("GarouSlot_back".equals(axe.attachmentNameParent),"human body attachment skipped (renamed) so the bone is used");
        check(Math.abs(axe.scale-1f/(WolfRuntime.BODY_SCALE*1.35f))<0.0001f,"hotbar item keeps original size in Hispo");
        check(WolfRuntime.isSlotItem(axe),"slot item registered for the post-transform");
        renderer.DrawChar(slot,axeData,false);
        check(renderer.calls==calls+5 && "GarouSlot_back".equals(axe.attachmentNameParent),"second draw: still visible, rule re-resolved from the renamed attachment");
        XfrmData ax=new XfrmData(); ax.modelInstance=axe; ax.transformToParent(new XfrmData());
        check(ax.xfrm.calls.equals(java.util.List.of("engine","transpose","translateLocal(0.08,0.18,0.00)",
                String.format(java.util.Locale.ROOT,"rotateXYZ(%.4f,%.4f,%.4f)",0f,0f,(float)(90*MouthCarryPatch.DEG)),"transpose")),
                "slot offset pre-multiplied (character space) then item-space rotation: "+ax.xfrm.calls);
        Instance scope=new Instance(); scope.character=garou; scope.model=new Object(); scope.parent=axe; scope.attachmentNameParent="scope";
        RenderData scopeData=new RenderData(); scopeData.modelInstance=scope;
        renderer.DrawChar(slot,scopeData,false);
        check(renderer.calls==calls+6 && scope.parentBoneName==null,"a weapon part rides with its visible parent, untouched");
        WTAGarouJava.setWolfSlot("secondary","Bip01_Spine2", 0,0,0, -0.08,0.10,0.15);
        garou.secondaryHandModel=offhand; offhand.parent=body; offhand.attachmentNameParent="Bip01_Prop2";
        renderer.DrawChar(slot,offData,false);
        check(renderer.calls==calls+7 && "Bip01_Spine2".equals(offhand.parentBoneName) && "GarouSlot_secondary".equals(offhand.attachmentNameParent),
                "secondary-hand item drawn under the 'secondary' rule");
        garou.secondaryHandModel=null;
        // 0.4.24: "<type>_back" (shovel_back, bag_back ...) resolves to the "back" rule by suffix; "secondary" never matches by suffix.
        check(WolfRuntime.slotRule("shovel_back")==WolfRuntime.slotRule("back") && WolfRuntime.slotRule("back")!=null,"shovel_back falls back to the Back rule");
        check(WolfRuntime.slotRule("holster_left")==null,"no rule, no suffix match: still hidden");
        check(WolfRuntime.slotRule("x_secondary")==null,"secondary is never matched by suffix");
        check(WolfRuntime.slotRule("wrench_left")==WolfRuntime.slotRule("belt_left")
                && WolfRuntime.slotRule("wrench_right")==WolfRuntime.slotRule("belt_right"),
                "wrench attachment aliases use corresponding belt rules");
        check(WolfRuntime.slotRule("meatcleaver_left")==WolfRuntime.slotRule("belt_left")
                && WolfRuntime.slotRule("meatcleaver_right")==WolfRuntime.slotRule("belt_right"),
                "logged cleaver attachment names use belt rules");
        WTAGarouJava.setWolfSlot("Back","Bip01_Spine2", 0,0,0, 0,0.2,0);
        WTAGarouJava.setWolfSlotPivot("Back", 0,0.25,0);
        WTAGarouJava.setWolfSlotPivot("shovel_back", 0,9,0);   // suffix match is not a rule of its own: ignored
        check(WolfRuntime.slotRule("Back").pivotY==0.25f && WolfRuntime.slotRule("Back").offY==0.2f,"pivot set on the existing rule, offset kept");
        Instance shovel=new Instance(); shovel.character=garou; shovel.model=new Object(); shovel.parent=body; shovel.attachmentNameParent="shovel_back";
        RenderData shovelData=new RenderData(); shovelData.modelInstance=shovel;
        renderer.DrawChar(slot,shovelData,false);
        check(renderer.calls==calls+8 && "GarouSlot_shovel_back".equals(shovel.attachmentNameParent),"shovel drawn through the suffix rule, renamed under its own name");
        renderer.DrawChar(slot,shovelData,false);
        check(renderer.calls==calls+9,"renamed suffix attachment resolves again on the next draw");
        XfrmData sh=new XfrmData(); sh.modelInstance=shovel; sh.transformToParent(new XfrmData());
        check(sh.xfrm.calls.equals(java.util.List.of("engine","transpose","translateLocal(0.00,0.20,0.00)","translate(-0.00,-0.25,-0.00)","transpose")),
                "pivot: mesh shifted by -pivot after the rotation so the grip point sits on the mount: "+sh.xfrm.calls);
        calls=renderer.calls-7;
        WTAGarouJava.setWolfSlotsEnabled(false);
        Instance knife=new Instance(); knife.character=garou; knife.model=new Object(); knife.parent=body; knife.attachmentNameParent="back";
        RenderData knifeData=new RenderData(); knifeData.modelInstance=knife;
        renderer.DrawChar(slot,knifeData,false);
        check(renderer.calls==calls+7 && knife.parentBoneName==null,"slots disabled: hotbar items hidden again");
        WTAGarouJava.setWolfSlotsEnabled(true);
        WTAGarouJava.clearWolfSlots();
        // Authored skinned harness replaces the rigid stand-in, not bag/cargo rules.
        Instance harness=new Instance(); harness.character=garou; harness.model=new Object(); harness.parent=body;
        harness.modelScript=new Script(1); body.animPlayer=new Player();
        harness.attachmentNameParent="WTAGarou_Harness"; harness.scale=1f;
        RenderData harnessData=new RenderData(); harnessData.modelInstance=harness;
        renderer.DrawChar(slot,harnessData,false);
        check(renderer.calls==calls+8 && harness.parentBoneName==null && harness.parentBone==-1,
                "skinned harness drawn without a rigid bone mount");
        check(harness.animPlayer==body.animPlayer && harness.data==manager.harness.tag
                && harness.model==manager.harness && harness.scale==1f,"own harness skin and shared animator, no rigid compensation");
        check(WolfRuntime.isHarness(harness) && !WolfRuntime.isSaddlebag(harness),"harness is not mistaken for the saddlebag");
        WTAGarouJava.setHarnessTransform(0,0,0, 0,0.05,0, 1.2);
        XfrmData hx=new XfrmData(); hx.modelInstance=harness; hx.transformToParent(new XfrmData());
        check(hx.xfrm.calls.equals(java.util.List.of("engine")),
                "legacy harness offset/scale ignored: "+hx.xfrm.calls);
        WTAGarouJava.setHarnessTransform(0,0,0, 0,0,0, 1);
        WTAGarouJava.setSaddlebagScale(1.3);
        WTAGarouJava.setSaddlebagTransform(0,0,0, 0,0,0);
        // First transform, BEFORE any DrawChar, with owner only on parent.
        Instance freshBag=new Instance(); freshBag.model=new Object(); freshBag.parent=body;
        freshBag.attachmentNameParent="WTAGarou_Saddlebags"; freshBag.modelScript=new Script(0.6f); freshBag.scale=0.6f;
        XfrmData sx=new XfrmData(); sx.modelInstance=freshBag; sx.transformToParent(new XfrmData());
        check(sx.bakedScale==1f && "Bip01_Spine2".equals(sx.bakedBone),
                "first transform bakes compensated scale and wolf bone before any draw");
        freshBag.scale=0.6f; freshBag.parentBoneName=null;
        XfrmData rebuilt=new XfrmData(); rebuilt.modelInstance=freshBag; rebuilt.transformToParent(new XfrmData());
        check(rebuilt.bakedScale==sx.bakedScale && rebuilt.bakedBone.equals(sx.bakedBone),
                "engine reset then transform has identical scale/bone, no first-frame drift");
        check(sx.xfrm.calls.equals(java.util.List.of("engine","transpose","scale(1.30)","transpose")),
                "saddlebag scale alone from WTAGarou.Saddlebag.scale: "+sx.xfrm.calls);
        WTAGarouJava.setSaddlebagScale(1);
        // Real parent data: final body-space scale belongs to the matrix,
        // independent of the engine's instanced/non-instanced shader choice.
        XfrmData parentData=new XfrmData(); parentData.modelInstance=body;
        XfrmData baked=new XfrmData(); baked.modelInstance=freshBag;
        baked.transformToParent(parentData);
        check(baked.xfrm.calls.equals(List.of("engine","transpose","scaleLocal(0.81)","transpose")),
                "Hispo body scale baked once into top-level bag matrix: "+baked.xfrm.calls);
        check(Math.abs(freshBag.scale*0.81f-0.6f*1.35f)<0.0001f,"bag grows with Hispo");
        Object gearScale=ScaleRuntime.begin(slot,newRender(freshBag));
        check(gearScale==null && slot.finalScale==0.8f,"gear draw never applies form/BODY_SCALE twice");
        WTAGarouJava.setScale(garou,1);
        baked=new XfrmData(); baked.modelInstance=freshBag; baked.transformToParent(parentData);
        check(baked.xfrm.calls.contains("scaleLocal(0.60)"),"Lupus matrix uses body normalization");
        WTAGarouJava.setScale(garou,1.35);
        // Recycle bag -> harness -> glasses. No stale role/offset may survive.
        freshBag.reset();
        check(!WolfRuntime.isSaddlebag(freshBag),"pool reset forgets saddlebag role");
        freshBag.parent=body; freshBag.model=new Object(); freshBag.modelScript=new Script(1);
        freshBag.attachmentNameParent="WTAGarou_Harness";
        baked=new XfrmData(); baked.modelInstance=freshBag; baked.transformToParent(parentData);
        check(WolfRuntime.isHarness(freshBag) && !WolfRuntime.isSaddlebag(freshBag),"reused bag becomes harness only");
        freshBag.reset();
        freshBag.parent=body; freshBag.model=new Object(); freshBag.modelScript=new Script(0.2f); freshBag.scale=0.2f;
        freshBag.attachmentNameParent="Bip01_Head";
        check(WolfRuntime.hideSubmodel(slot,newRender(freshBag)) && !WolfRuntime.isHarness(freshBag)
                && freshBag.scale==0.2f,"reused harness becomes hidden glasses without stale size/rotation");
        // Human preview parent belongs to the same character, but not wolf rig.
        Instance previewBody=new Instance(); previewBody.character=garou; previewBody.model=manager.human;
        freshBag.parent=previewBody; freshBag.attachmentNameParent="back";
        check(!WolfRuntime.hideSubmodel(slot,newRender(freshBag)) && freshBag.parentBoneName==null,
                "human preview clothing stays vanilla, not retargeted to wolf");
        WTAGarouJava.setWolfSlot("belt_left","Bip01_Spine2",0,0,0,0,0,0);
        check(WolfRuntime.slotRule("belt_left_screwdriver")==WolfRuntime.slotRule("belt_left"),
                "left belt item suffix resolves");
        WTAGarouJava.clearWolfSlots();
        // Stationary attacks include lower body even when source mask empty.
        Object emptyMask=new ArrayList<>();
        check(WolfAttackMasks.weightsFor(garou,"Wolf_attack",emptyMask)==WolfRuntime.fullBodyWeights(),
                "stationary attack expands empty source mask");
        garou.moving=true;
        check(WolfAttackMasks.weightsFor(garou,"Wolf_attack",emptyMask)==emptyMask,
                "moving/strafe attack mask is unchanged");
        garou.moving=false;
        garou.maskPlayer=player;
        MaskNode maskNode=new MaskNode(); maskNode.animLayer.character=garou;
        MaskTrack maskTrack=new MaskTrack();
        maskNode.initTrackBoneWeights(maskTrack,true);
        check(maskTrack.weights==WolfRuntime.fullBodyWeights() && maskTrack.inits==1,
                "real advice repairs upper-body mask after layer transfer");
        garou.moving=true;
        maskNode.initTrackBoneWeights(maskTrack,true);
        check(maskTrack.weights!=WolfRuntime.fullBodyWeights() && maskTrack.inits==1,
                "layer transfer leaves moving attack untouched");
        garou.moving=false;
        maskNode.initTrackBoneWeights(maskTrack,false);
        check(maskTrack.weights==null,"root layer remains unmasked");
        maskTrack.clip.name="Bob_Walk";
        maskNode.initTrackBoneWeights(maskTrack,true);
        check(maskTrack.inits==2 && maskTrack.weights.isEmpty(),"transferred gait layer remains inert instead of wagging forepaw");
        maskNode.animLayer.character=ordinary;
        maskTrack.clip.name="Bob_Attack1Hand01_Miss";
        maskNode.initTrackBoneWeights(maskTrack,true);
        check(maskTrack.inits==2,"human attack mask untouched");
        maskNode.animLayer.character=garou;
        for (String clip:new String[]{"Wolf_eat","Wolf_drink","Bob_EatFood","Bob_Drink",
                "WTAGarou_Player_Bob_EatFood|Wolf_eat|Translation_Data|0.69"}) {
            maskTrack.clip.name=clip;
            maskNode.initTrackBoneWeights(maskTrack,true);
            check(maskTrack.weights==WolfRuntime.fullBodyWeights(),"eating transfer owns hindquarters: "+clip);
            check(WolfAttackMasks.weightsFor(garou,clip,null)==WolfRuntime.fullBodyWeights(),
                    "eating starts full-body even with empty/null source");
        }
        maskTrack.clip.name="WTAGarou_Player_Bob_Idle_HeavyBreathing|Wolf_idle|Translation_Data|0.69";
        maskNode.initTrackBoneWeights(maskTrack,true);
        check(maskTrack.weights.isEmpty(),"heavy breathing remains inert even after a layer transfer");
        garou.dead=true;
        check(WolfAttackMasks.weightsFor(garou,"Wolf_eat",emptyMask)==emptyMask,"dead wolf eating mask untouched");
        garou.dead=false;
        check(WolfAttackMasks.weightsFor(garou,"Bob_Shove",emptyMask)==emptyMask,
                "non-eating utility/source masks keep previous behavior");
        garou.secondaryHandModel=offhand;
        garou.actions.push(new HandAction());
        check(WolfRuntime.hideSubmodel(slot,offData),"temporary reading/eating override prop hidden");
        garou.actions.clear();
        WTAGarouJava.setWolfSlot("secondary","Bip01_Spine2",0,0,0,0,0,0);
        check(!WolfRuntime.hideSubmodel(slot,offData),"ordinary secondary cargo returns after action");
        garou.secondaryItem=new Container();
        check(WolfRuntime.hideSubmodel(slot,offData),"held secondary container visual hidden");
        garou.secondaryItem=null;
        garou.primaryItem=new Container();
        check(WolfRuntime.hideSubmodel(slot,heldData),"held primary container visual hidden");
        garou.primaryItem=garou.weapon;
        garou.overrideSecondaryHandModel="bookhand";
        check(WolfRuntime.hideSubmodel(slot,offData),"explicit engine hand-model override also hidden");
        garou.overrideSecondaryHandModel=null;
        garou.secondaryHandModel=null;
        WTAGarouJava.clearWolfSlots();
        calls=renderer.calls-3;   // rebase for the assertions below
        renderer.checkScale=true;
        garou.primaryHandModel=null;
        Swipe swipe=new Swipe();
        check(swipe.OnAnimEvent_SetMeleeDelay(ordinary,30)==30,"ordinary recovery unchanged");
        WTAGarouJava.setCombatTiming(garou,true);
        // 0.4.58: garou is a registered wolf body here, so every carried item
        // (the October 13 electric guitar is "heavy") gets the single jaws cap.
        check(WolfRuntime.active(garou),"jaws cap scenario requires an active wolf body");
        for(String[] row:new String[][]{{"1handed","12"},{"2handed","12"},{"knife","12"},{"spear","12"},{"heavy","12"}}) {
            garou.type=row[0];
            check(swipe.OnAnimEvent_SetMeleeDelay(garou,30)==Float.parseFloat(row[1]),"jaws recovery independent of carried "+row[0]);
            check(swipe.OnAnimEvent_SetMeleeDelay(garou,0.5f)==0.5f,"never extends shorter recovery");
        }
        check(swipe.OnAnimEvent_SetMeleeDelay(garou,30)==CombatRuntime.JAWS_CAP,"jaws cap constant matches approved 1handed cap");
        garou.type="barehand";
        check(swipe.OnAnimEvent_SetMeleeDelay(garou,30)==12,"wolf body: engine type label irrelevant while an item is in the jaws");
        garou.type="heavy";garou.weapon.ranged=true;
        check(swipe.OnAnimEvent_SetMeleeDelay(garou,30)==30,"ranged excluded");
        garou.weapon.ranged=false;garou.dead=true;
        check(swipe.OnAnimEvent_SetMeleeDelay(garou,30)==30,"dead excluded");
        garou.dead=false;
        garou.primaryItem=new Object();
        var output=new java.io.ByteArrayOutputStream();
        var originalOut=System.out;
        try {
            System.setOut(new java.io.PrintStream(output));
            check(swipe.OnAnimEvent_SetMeleeDelay(garou,30)==30,"ComboItem-like non-weapon has no isRanged requirement");
        } finally { System.setOut(originalOut); }
        check(output.size()==0,"ordinary non-weapons must not throw/log recovery adapter unavailable");
        garou.primaryItem=null;
        check(swipe.OnAnimEvent_SetMeleeDelay(garou,30)==30,"empty hands leave vanilla recovery");
        garou.primaryItem=garou.weapon;
        check(swipe.OnAnimEvent_SetMeleeDelay(garou,30)==12,"real melee weapon in jaws uses the jaws cap");
        check(swipe.countdownSetter(29.375f)==29.375f,"countdown not repeatedly scaled");
        WTAGarouJava.clearScale(garou);
        check(WolfRuntime.active(garou),"scale clear independent");
        data.modelInstance.character=garou; data.modelInstance.model=manager.wolf;
        data.modelInstance.parent=null;
        Object normalized=ScaleRuntime.begin(slot,data);
        check(Math.abs(slot.finalScale-0.48f)<0.00001,"Lupus scale 1 still normalizes wolf mesh");
        ScaleRuntime.end(normalized);
        check(slot.finalScale==0.8f,"Lupus normalization restored exactly");
        data.modelInstance.model=manager.human;
        check(ScaleRuntime.begin(slot,data)==null && slot.finalScale==0.8f,
                "human fallback never gets wolf normalization");
        WTAGarouJava.clear(garou);
        check(!WolfRuntime.active(garou) && manager.getBodyModel(garou)==manager.human,"return to human");
        // 0.4.17: the first human draw of a compensated sub-model puts its
        // scale and attachment back exactly.
        renderer.checkScale=false;
        renderer.DrawChar(slot,heldData,false);
        renderer.checkScale=true;
        check(Math.abs(held.scale-0.9f)<0.0001f && "Bip01_Prop1".equals(held.attachmentNameParent) && !WolfRuntime.isMouthCarried(held),
                "back to human: jaw item scale and attachment restored");
        check(WolfRuntime.status().contains("human requested") && WolfRuntime.status().contains("registered wolves=0"),
                "human form no longer claims it is waiting to become wolf");
        check(swipe.OnAnimEvent_SetMeleeDelay(garou,30)==30,"clear unregisters combat");
        // Human-form Garou keep the approved per-weapon Skully caps (heavy=4).
        WTAGarouJava.setCombatTiming(garou,true);
        check(!WolfRuntime.active(garou),"human-form cap scenario requires no wolf body");
        for(String[] row:new String[][]{{"1handed","12"},{"2handed","12"},{"knife","1"},{"spear","8"},{"heavy","4"}}) {
            garou.type=row[0];
            check(swipe.OnAnimEvent_SetMeleeDelay(garou,30)==Float.parseFloat(row[1]),"human-form Skully recovery unchanged "+row[0]);
        }
        garou.type="barehand";
        check(swipe.OnAnimEvent_SetMeleeDelay(garou,30)==30,"human form: unmapped unarmed unchanged");
        garou.type="heavy";
        WTAGarouJava.setCombatTiming(garou,false);
        check(swipe.OnAnimEvent_SetMeleeDelay(garou,30)==30,"combat timing off again");
        check(garou.rebuilds==2,"restore rebuilds exactly once");
        check(WTAGarouJava.setWolf(garou,true).equals("wolf"),"reactivate before death regression");
        garou.dead=true;
        int resets=garou.animator.resets;
        WTAGarouJava.setScale(garou,1.35);
        WTAGarouJava.clear(garou);
        check(WolfRuntime.active(garou),"death retains wolf until native corpse handoff");
        check(WTAGarouJava.scaleFor(garou)==1.35f,"death retains Hispo size during collapse");
        check(garou.animator.resets==resets,"death callback never resets an updating track");
        WTAGarouJava.clear(garou);
        check(garou.animator.resets==resets,"repeated dead refresh never resets tracks");
        player.fail=false;
        Params death=new Params(); death.animName="Bob_Unknown"; death.isRagdoll=true;
        check(player.play(death,new Object()).equals("Wolf_death"),"dead player never selects wolf idle");
        check(death.isRagdoll && death.deferredBoneAxis==Axis.Y,"pooled ragdoll and axis restored");
        check(!garou.becomeCorpse(),"corpse does not stamp old wolf or fresh idle pose");
        check(!WolfRuntime.active(garou) && !WolfRuntime.corpseHandoff(garou),"handoff removes registration and scope");
        check(WTAGarouJava.scaleFor(garou)==1f,"human corpse no wolf scale");
        check(ordinary.canUseCurrentPoseForCorpse(),"ordinary corpse pose unchanged");
        // The explicit emergency wolf-off command still safely queues a reset.
        garou.dead=false; WTAGarouJava.setWolf(garou,true); garou.dead=true;
        resets=garou.animator.resets;
        WTAGarouJava.setWolf(garou,false);
        manager.Reset(garou);
        check(garou.animator.resets==resets+1,"queued native model rebuild flushes death reset");
        manager.Reset(garou);
        check(garou.animator.resets==resets+1,"death reset consumed exactly once");
        garou.dead=false;
        garou.animator.fail=true;
        check(WTAGarouJava.setWolf(garou,true).equals("failed") && !WolfRuntime.active(garou),
                "activation failure rolls back registry");
        check(manager.getBodyModel(garou)==manager.human,"failed activation remains human");
        System.out.println("PASS: "+checks+" Java wolf/combat assertions with real ZombieBuddy advice.");
    }
    static RenderData newRender(Instance instance) {
        RenderData data=new RenderData(); data.modelInstance=instance; return data;
    }
}
