import java.util.*;
import wtagarou.visuals.*;
import zombie.core.skinnedmodel.ModelManager;

/** Deterministic math and advice tests, not a native renderer. */
public class WolfPlayerClipsTest {
    static int checks;
    static void check(boolean value,String why) { checks++; if(!value) throw new AssertionError(why); }
    static void close(float a,float b,String why) { check(Math.abs(a-b)<0.0001f,why+": "+a+" != "+b); }
    public static class Vec {
        public float x,y,z;
        public Vec() {}
        public Vec(float x,float y,float z) { this.x=x;this.y=y;this.z=z; }
    }
    public static class Frame {
        public int bone;
        public String boneName;
        public float time;
        public Vec position=new Vec();
        public Vec rotation=new Vec();
        public Vec scale=new Vec(1,1,1);
        public Frame() {}
        public Frame(int bone,float time,float x,float y,float z) {
            this.bone=bone;this.boneName=bone==0?"Bip01":"Bip01_Spine";
            this.time=time;position=new Vec(x,y,z);
        }
        public void set(Frame f) {
            bone=f.bone;boneName=f.boneName;time=f.time;
            position=new Vec(f.position.x,f.position.y,f.position.z);
            rotation=new Vec(f.rotation.x,f.rotation.y,f.rotation.z);
            scale=new Vec(f.scale.x,f.scale.y,f.scale.z);
        }
        public static Frame lerp(Frame a,Frame b,float time,Frame out) {
            float t=(time-a.time)/(b.time-a.time);
            out.set(a);out.time=time;
            out.position=new Vec(a.position.x+(b.position.x-a.position.x)*t,
                    a.position.y+(b.position.y-a.position.y)*t,a.position.z+(b.position.z-a.position.z)*t);
            return out;
        }
    }
    public static class Clip {
        public final float duration;
        public final Frame[] frames;
        public final String name;
        public Clip(float duration,List<Frame> frames,String name,boolean keep) {
            this.duration=duration;this.frames=frames.toArray(new Frame[0]);this.name=name;
        }
        public float getDuration() { return duration; }
        public Frame[] getKeyframes() { return frames; }
        public Frame[] getBoneFramesAt(int bone) {
            return Arrays.stream(frames).filter(f->f.bone==bone).toArray(Frame[]::new);
        }
    }
    public static class Action {
        public Object chr;
        public int calls;
        public void setActionAnim(String text) { calls++; }
        public void setActionAnim(WolfCombatTest.Axis action) { action.toString();calls++; }
    }
    public static class Player {
        public WolfCombatTest.Character character;
        public List<Object> reparentedBoneBindings=new ArrayList<>();
        public List<Object> twistBones=new ArrayList<>();
        public Object counterRotationBone;
        public Object getIsoGameCharacter() { return character; }
        public Object getSkinningData() { return ModelManager.instance.wolf.tag; }
        public Clip play(WolfCombatTest.Params params,Object layer) {
            check(params.deferredBoneName.equals("Translation_Data"),"human marker bone kept (human parity)");
            check(params.deferredBoneAxis==WolfCombatTest.Axis.Y,"human axis kept untouched");
            check(params.useDeferredRotation,"human deferred rotation flag kept for derived clips");
            check(((List<?>)params.subLayerBoneWeights).isEmpty(),"masked sub-layer gait track is inert on the wolf");
            return (Clip)ModelManager.instance.wolf.tag.animationClips.get(params.animName);
        }
    }
    static Frame at(int bone,float time,float x,float y,float z,String name) {
        Frame f=new Frame(bone,time,x,y,z); f.boneName=name; return f;
    }
    public static void main(String[] args) throws Exception {
        var manager=ModelManager.instance;
        var wolfSkin=manager.wolf.tag; var humanSkin=manager.maleModel.tag;
        // Wolf rig: Bip01=0, Bip01_Spine=1, Translation_Data=2. Human: Translation_Data=2.
        wolfSkin.boneIndices.put("Translation_Data",2);
        humanSkin.boneIndices.put("Translation_Data",2);
        // Wolf_walk: 1 s, marker travels 1.0 forward (+z), root has a baked
        // travel too (pre-bake asset) plus a vertical bob that must survive.
        Clip wolf=new Clip(1,List.of(new Frame(0,0,0,3,0),new Frame(0,0.5f,0,4,5),new Frame(0,1,0,3,10),
                new Frame(1,0,7,8,9),new Frame(1,1,8,9,10),
                at(2,0,0.5f,0,0.25f,"Translation_Data"),at(2,1,0.5f,0,1.25f,"Translation_Data")),"Wolf_walk",true);
        for (float[] direction:new float[][]{{0,2},{0,-2},{2,0},{-2,0},{2,2},{-2,2},{2,-2},{-2,-2}}) {
            float x=direction[0], z=direction[1];
            // Human strafe: 2 s, marker travels (x,z) -> speed |(x,z)|/2 per second.
            Clip human=new Clip(2,List.of(at(2,0,0,0,0,"Translation_Data"),
                    at(2,1,x/4,0,z/4,"Translation_Data"),at(2,2,x,0,z,"Translation_Data")),"Bob_Strafe",true);
            float renderScale=0.6f;
            Clip derived=(Clip)WolfPlayerClips.derive(wolf,human,wolfSkin,humanSkin,"Translation_Data","Bob_Strafe",renderScale);
            float humanSpeed=(float)Math.hypot(x,z)/2f;
            float expected=1.0f*renderScale/humanSpeed*WolfPlayerClips.cycleSlowdown;
            close(derived.duration,expected,"stride-matched duration: wolf stride*scale / human speed x slowdown");
            check(derived.name.equals("Bob_Strafe"),"player track identity retained");
            Frame[] root=derived.getBoneFramesAt(0);
            for (Frame f:root) { close(f.position.x,0,"root x held"); close(f.position.z,0,"root z held in place"); }
            check(Arrays.stream(root).anyMatch(f->f.position.y==4),"wolf vertical bob retained");
            close(root[root.length-1].time,expected,"wolf pose retimed to derived duration");
            Frame[] marker=derived.getBoneFramesAt(2);
            check(marker.length==3,"exactly the human marker frames drive movement");
            check(marker[0].boneName.equals("Translation_Data"),"marker keeps its own name");
            close(marker[0].position.x,0.5f,"wolf marker rest offset kept (x)");
            close(marker[0].position.z,0.25f,"wolf marker rest offset kept (z)");
            float k=expected/2f;
            close(marker[2].position.x-marker[0].position.x,x*k,"human direction (x) retained, speed preserved");
            close(marker[2].position.z-marker[0].position.z,z*k,"human direction (z) retained, speed preserved");
            close((marker[2].position.z-marker[0].position.z)/derived.duration,z/2f,"movement speed equals human clip speed even with the pose slowed");
            close(marker[1].position.x-marker[0].position.x,x/4*k,"human movement curve, not constant speed");
            // 0.4.22: MARKER_AT_ORIGIN drops the wolf marker's rest offset; deltas unchanged.
            WolfPlayerClips.markerAtOrigin=true;
            Clip atOrigin=(Clip)WolfPlayerClips.derive(wolf,human,wolfSkin,humanSkin,"Translation_Data","Bob_Strafe",renderScale);
            WolfPlayerClips.markerAtOrigin=false;
            Frame[] om=atOrigin.getBoneFramesAt(2);
            close(om[0].position.x,0f,"marker at origin (x)"); close(om[0].position.z,0f,"marker at origin (z)");
            close(om[2].position.x-om[0].position.x,x*k,"origin marker keeps the human deltas");
            Frame[] spine=derived.getBoneFramesAt(1);
            close(spine[1].position.z,10,"non-root wolf pose never replaced with human pose");
            close(wolf.getBoneFramesAt(0)[2].position.z,10,"source wolf clip not mutated");
            close(human.getBoneFramesAt(2)[2].position.x,x,"source human clip not mutated");
        }
        // Idle/turn: no gait in either clip -> native wolf duration, deltas copied 1:1 in time ratio.
        Clip idle=new Clip(3,List.of(at(2,0,0,0,0,"Translation_Data"),at(2,3,0.05f,0,0,"Translation_Data")),"Bob_Idle",true);
        Clip wolfIdle=new Clip(4,List.of(new Frame(0,0,0,3,0),new Frame(0,4,0,3,0)),"Wolf_idle",true);
        Clip derivedIdle=(Clip)WolfPlayerClips.derive(wolfIdle,idle,wolfSkin,humanSkin,"Translation_Data","Bob_Idle",0.6f);
        close(derivedIdle.duration,4,"non-locomotion keeps native wolf duration");
        // 0.4.22: the stride-matched clock is multiplied by cycleSlowdown (default 2).
        close(WolfPlayerClips.cycleSlowdown,2.0f,"default gait slowdown is 2x");
        close(WolfPlayerClips.derivedDuration(0.5f,2.0f,0.7f,2.1f,0.6f),2.0f*0.6f/3f*2.0f,"run stride match, slowed 2x");
        WolfPlayerClips.cycleSlowdown=1.0f;
        close(WolfPlayerClips.derivedDuration(0.5f,2.0f,0.7f,2.1f,0.6f),2.0f*0.6f/3f,"run stride match at 1x");
        WolfPlayerClips.cycleSlowdown=2.0f;
        close(WolfPlayerClips.derivedDuration(0.5f,2.0f,0.7f,0.01f,0.6f),0.5f,"turn shuffle keeps wolf clock (slowdown does not apply)");
        // 0.4.20: a looping marker that snaps back on its last key still has a stride.
        List<Object> loop=new ArrayList<>(List.of(at(2,0,0,0,0,"Translation_Data"),at(2,1,3,0,0,"Translation_Data"),
                at(2,2,0,0,0,"Translation_Data")));
        close(WolfPlayerClips.stride(loop),3f,"stride is the largest displacement, not first-to-last");
        Clip loopHuman=new Clip(2,loop.stream().map(o->(Frame)o).toList(),"Bob_Run",true);
        Clip derivedLoop=(Clip)WolfPlayerClips.derive(wolf,loopHuman,wolfSkin,humanSkin,"Translation_Data","Bob_Run",0.6f);
        close(derivedLoop.duration,1.0f*0.6f/1.5f*2.0f,"snap-back run clip is stride-matched x2 slowdown (was native wolf duration)");
        check(WolfPlayerClips.lastDiag.contains("Bob_Run"),"gait diagnostic describes the derivation");
        // 0.4.24: transitions keep the human clock and marker travel 1:1.
        check(WolfPlayerClips.isTransition("Bob_RunToStop") && WolfPlayerClips.isTransition("Bob_IdleToRun")
                && WolfPlayerClips.isTransition("Bob_WalkToTurn180L") && WolfPlayerClips.isTransition("Bob_IdleToWalk180R")
                && WolfPlayerClips.isTransition("Bob_RunTurnL"),"transition names recognised");
        check(!WolfPlayerClips.isTransition("Bob_Run") && !WolfPlayerClips.isTransition("Bob_Walk") && !WolfPlayerClips.isTransition("Bob_StrafeLeft")
                && !WolfPlayerClips.isTransition("Bob_Sprint") && !WolfPlayerClips.isTransition("Bob_Idle"),"cycles are not transitions");
        Clip stopHuman=new Clip(1.0f,List.of(at(2,0,0,0,0,"Translation_Data"),at(2,0.5f,0,0,0.6f,"Translation_Data"),at(2,1.0f,0,0,0.811f,"Translation_Data")),"Bob_RunToStop",true);
        WolfPlayerClips.cycleSlowdown=1.2f;
        Clip derivedStop=(Clip)WolfPlayerClips.derive(wolf,stopHuman,wolfSkin,humanSkin,"Translation_Data","Bob_RunToStop",0.6f);
        close(derivedStop.duration,1.0f,"RunToStop keeps the human 1.0 s (was stretched to the 4 s cap)");
        Frame[] stopMarker=Arrays.stream(derivedStop.frames).filter(f->f.bone==2).toArray(Frame[]::new);
        close(stopMarker[stopMarker.length-1].position.z-stopMarker[0].position.z,0.811f,"marker travel is 1:1 with the human clip (no coasting)");
        close(stopMarker[stopMarker.length-1].time,1.0f,"marker keys end with the human clip");
        long tiles=Arrays.stream(derivedStop.frames).filter(f->f.bone==0 && f.time==0f).count();
        check(tiles==1 && Arrays.stream(derivedStop.frames).anyMatch(f->f.bone==0 && f.time>0.6f && f.time<=1.0f),
                "wolf cycle tiled across the stop at its native cadence: "+derivedStop.frames.length);
        check(WolfPlayerClips.lastDiag.contains("transition"),"diagnostic names the transition path");
        WolfPlayerClips.transitionsKeepHumanTiming=false;
        Clip derivedStopOld=(Clip)WolfPlayerClips.derive(wolf,stopHuman,wolfSkin,humanSkin,"Translation_Data","Bob_RunToStop",0.6f);
        check(Math.abs(derivedStopOld.duration-1.0f)>0.01f,"toggle off restores the stride-matched clock (not the human 1.0 s)");
        WolfPlayerClips.transitionsKeepHumanTiming=true;
        WolfPlayerClips.cycleSlowdown=2.0f;
        // 0.4.20: bite / grab reactions map to the short wolf flinch, never the 4 s idle.
        Clip attack=new Clip(1.0f,Arrays.asList(wolf.frames),"Wolf_attack",true);
        for (float slowdown:new float[]{1f,1.2f,3f}) {
            WolfPlayerClips.cycleSlowdown=slowdown;
            Clip bite=(Clip)WolfPlayerClips.derive(attack,stopHuman,wolfSkin,humanSkin,"Translation_Data","Bob_Attack1Hand01_Hit",0.6f);
            close(bite.duration,1f/1.5f,"attack clock independent of gait slowdown "+slowdown);
        }
        WTAGarouJava.setWolfAttackSpeed(2);
        Clip fastBite=(Clip)WolfPlayerClips.derive(attack,stopHuman,wolfSkin,humanSkin,"Translation_Data","Bob_Attack",0.6f);
        close(fastBite.duration,0.5f,"attack-only speed setting");
        WTAGarouJava.setWolfAttackSpeed(1.5);
        WTAGarouJava.setWolfStompSpeed(0.75);
        Clip stomp=(Clip)WolfPlayerClips.derive(attack,stopHuman,wolfSkin,humanSkin,"Translation_Data","Bob_Stomp",0.6f);
        close(stomp.duration,1f/0.75f,"stomp speed independent of bite and gait");
        Clip stamp=(Clip)WolfPlayerClips.derive(attack,stopHuman,wolfSkin,humanSkin,"Translation_Data","Bob_Attack2HStamp",0.6f);
        close(stamp.duration,1f/0.75f,"native Stamp spelling uses stomp speed, not bite speed");
        check(WolfRuntime.clipFor("Bob_Stamp").equals("Wolf_attack"),"Stamp alias maps to wolf attack");
        Clip windowHuman=new Clip(0.7f,List.of(at(2,0,0,0,0,"Translation_Data"),
                at(2,0.7f,0,0,0,"Translation_Data")),"Bob_OpenWindow",true);
        for (String name:new String[]{"Bob_OpenWindow","Bob_CloseWindow","Bob_WindowStruggle",
                "Bob_ClimbFenceEnd","Bob_ClimbWindowFinish","Bob_Vault","Bob_FenceToIdle"}) {
            Clip window=(Clip)WolfPlayerClips.derive(wolf,windowHuman,wolfSkin,humanSkin,"Translation_Data",name,0.6f);
            close(window.duration,0.7f,"window action keeps native event clock: "+name);
        }
        WTAGarouJava.setWolfStompSpeed(1);
        Clip getup=new Clip(0.25f,List.of(new Frame(0,0,0,0,0),new Frame(0,0.25f,0,1,0),
                at(2,0,0,0,0,"Translation_Data"),at(2,0.25f,0,0,0,"Translation_Data")),"Wolf_getup",true);
        Clip rise=(Clip)WolfPlayerClips.derive(getup,stopHuman,wolfSkin,humanSkin,"Translation_Data","Bob_SitToIdle",0.6f);
        close(rise.duration,stopHuman.duration,"get-up keeps human transition duration");
        check(Arrays.stream(rise.frames).filter(f->f.bone==0).count()==2,"get-up pose occurs once, never tiled back into sit");
        WolfPlayerClips.cycleSlowdown=2f;
        check(WolfPlayerClips.furnitureRoot("Bob_Seated_SitDown","Bip01"),"chair root case recognised");
        check(!WolfPlayerClips.furnitureRoot("Bob_Death","Bip01"),"death path excluded from chair guard");
        humanSkin.animationClips.put("Bob_Seated_SitDown",stopHuman);
        wolfSkin.animationClips.put("Wolf_Sit",wolf);
        check(WolfPlayerClips.adapt(wolfSkin,"Bob_Seated_SitDown","Wolf_Sit","Bip01",0.6f).equals("Wolf_Sit"),
                "chair clip never replaces the wolf skinned root with human root keys");
        for (String n:new String[]{"Bob_BiteFront","Bob_Bitten_Back","Bob_GrabbedFront","Bob_ZombieReact","Bob_StaggerBack","Bob_KnockedDown","Bob_ShotFront"})
            check(WolfRuntime.clipFor(n).equals("Wolf_hitreaction"),"reaction clip maps to Wolf_hitreaction: "+n);
        check(WolfRuntime.clipFor("Bob_AttackHit").equals("Wolf_attack"),"attack still wins over hit");
        check(WolfRuntime.clipFor("Bob_Idle").equals("Wolf_idle"),"idle stays idle");
        check(WolfRuntime.clipFor("Bob_Idle_HeavyBreathing").equals("Wolf_idle"),"heavy breathing is not eating");
        check(WolfRuntime.clipFor("Bob_EatFood").equals("Wolf_eat"),"actual eating still maps to eat");
        // 0.4.24: crouch/sneak idles are idles (they fell into Wolf_walk and walked in place).
        check(WolfRuntime.clipFor("Bob_SneakIdle").equals("Wolf_idle") && WolfRuntime.clipFor("Bob_IdleCrouch").equals("Wolf_idle"),"sneak idle is an idle, not a walk");
        check(WolfRuntime.preferredClipFor("Bob_SneakIdle").equals("Wolf_idle_crouch"),"sneak idle prefers the optional crouch idle");
        check(WolfRuntime.clipFor("Bob_IdleToWalk180L").equals("Wolf_walk"),"IdleToWalk180 is a turn transition, not an idle");
        // 0.4.64: backing up plays the walk in reverse unless an authored Wolf_walk_back exists.
        check(WolfRuntime.preferredClipFor("Bob_WalkBwdAim").equals("Wolf_walk_back") && WolfRuntime.clipFor("Bob_WalkBwdAim").equals("Wolf_walk"),"Bob_WalkBwdAim prefers Wolf_walk_back and falls back to Wolf_walk");
        check(WolfRuntime.isBackwardWalk("bob_walkbwdaim") && WolfRuntime.isBackwardWalk("Bob_WalkBack") && !WolfRuntime.isBackwardWalk("Bob_Walk") && !WolfRuntime.isBackwardWalk("Bob_Strafe_Left") && !WolfRuntime.isBackwardWalk(null),"backward-walk names: bwd/back + walk only");
        check(WolfRuntime.reverseForBackwardWalk("Bob_WalkBwdAim","Wolf_walk") && WolfRuntime.reverseForBackwardWalk("Bob_WalkBwdAim","Wolf_sneak"),"fallback gait plays reversed when backing up (paws track the direction of travel)");
        check(!WolfRuntime.reverseForBackwardWalk("Bob_WalkBwdAim","Wolf_walk_back"),"an authored Wolf_walk_back plays forwards as authored");
        check(!WolfRuntime.reverseForBackwardWalk("Bob_Walk","Wolf_walk") && !WolfRuntime.reverseForBackwardWalk("Bob_Strafe_Left","Wolf_walk") && !WolfRuntime.reverseForBackwardWalk("Bob_WalkBwdAim","Wolf_idle") && !WolfRuntime.reverseForBackwardWalk(null,"Wolf_walk"),"forward walk, sideways strafe, idle, null: never reversed");
        check(WolfRuntime.reverseForBackwardWalk("Bob_WalkBwdDrag_Person","Wolf_walk"),"the drag-backwards node also qualifies (the drag path already reversed it)");
        check(WolfRuntime.clipFor("Bob_SneakWalk").equals("Wolf_walk") && WolfRuntime.preferredClipFor("Bob_SneakWalk").equals("Wolf_sneak"),"sneak walk -> Wolf_sneak -> Wolf_walk");
        check(WolfRuntime.clipFor("Bob_SitGroundIdle").equals("Wolf_Sit") && WolfRuntime.preferredClipFor("Bob_SitGroundIdle").equals("Wolf_Sit_idle"),"sit loop prefers Wolf_Sit_idle");
        check(WolfRuntime.preferredClipFor("Bob_SitOnGroundEnd").equals("Wolf_getup"),"ground exit gets authored reversed clip");
        check(WolfRuntime.clipFor("Bob_RunToStop").equals("Wolf_run"),"RunToStop falls back to the run cycle");
        check(WolfRuntime.clipFor("Bob_ClimbFence").equals("Wolf_idle") && WolfRuntime.preferredClipFor("Bob_ClimbFence").equals("Wolf_climb"),"climb prefers Wolf_climb");
        check(WolfRuntime.clipFor("Bob_Drink").equals("Wolf_eat"),"drink falls back to eat");
        java.util.Map<String,Object> loaded=new java.util.HashMap<>(); loaded.put("Wolf_sneak",new Object()); loaded.put("Wolf_walk",new Object());
        check(WolfRuntime.resolveClip("Wolf_sneak",loaded).equals("Wolf_sneak") && WolfRuntime.resolveClip("Wolf_strafe",loaded).equals("Wolf_walk"),"resolve uses the authored clip when loaded, else the packaged one");
        for (String k:WolfRuntime.OPTIONAL_FALLBACK.keySet()) check(!WolfRuntime.resolveClip(k,java.util.Collections.emptyMap()).startsWith("Wolf_")==false
                && !WolfRuntime.OPTIONAL_FALLBACK.containsKey(WolfRuntime.resolveClip(k,java.util.Collections.emptyMap())),"every optional clip resolves to a packaged clip: "+k);
        check(SubmodelDiag.abnormal(30f) && SubmodelDiag.abnormal(0.1f) && !SubmodelDiag.abnormal(1.25f) && !SubmodelDiag.abnormal(0.6f),
                "sub-model diagnostic thresholds");
        close(SubmodelDiag.axisScale(0f,3f,4f),5f,"axis scale is the column length");
        var inst=net.bytebuddy.agent.ByteBuddyAgent.install();
        WolfCombatTest.install(inst,Player.class,WolfTrackPatch.class,"play");
        manager.wolf.tag.animationClips.put("Wolf_walk",wolf);
        Clip human=new Clip(2,List.of(at(2,0,0,0,0,"Translation_Data"),at(2,2,-2,0,0,"Translation_Data")),"Bob_StrafeLeft",true);
        humanSkin.animationClips.put("Bob_StrafeLeft",human);
        Player p=new Player();p.character=new WolfCombatTest.Character();
        p.character.running=true;
        check(WolfRuntime.gaitFor(p.character,"Bob_Walk").equals("Wolf_walk"),"run KEY state never upgrades a walk-named clip");
        p.character.sprinting=true;
        check(WolfRuntime.gaitFor(p.character,"Bob_Walk").equals("Wolf_walk"),"sprint flag never upgrades a walk-named clip");
        check(WolfRuntime.gaitFor(p.character,"Bob_Sprint").equals("Wolf_run_fourx"),"sprint clip name selects sprint pose");
        check(WolfRuntime.gaitFor(p.character,"Bob_Run").equals("Wolf_run"),"run clip name selects jog pose");
        check(WolfRuntime.gaitFor(p.character,"Bob_Attack").equals("Wolf_attack"),"sprint flag cannot replace an attack");
        check(WolfRuntime.gaitFor(p.character,"Bob_HitReaction").equals("Wolf_hitreaction"),"run flag cannot hide hit reaction");
        p.character.running=false;p.character.sprinting=false;
        check(WolfRuntime.gaitFor(p.character,"Bob_StrafeLeft").equals("Wolf_walk"),"strafe pose is a walk pose");
        check(!JawsAttackPatch.swallow(p.character),"human body: attack press passes");
        check(WTAGarouJava.setWolf(p.character,true).equals("wolf"),"activate for full adapter test");
        WolfCombatTest.Params seated=new WolfCombatTest.Params();
        seated.animName="Bob_Seated_SitDown"; seated.deferredBoneName="Bip01";
        Object savedChair=WolfRuntime.beginTrack(p,seated);
        check(savedChair!=null && seated.animName.equals("Wolf_Sit")
                && seated.deferredBoneName.equals("Translation_Data") && !seated.useDeferredRotation,
                "chair uses authored wolf pose and unskinned movement marker, no human root rotation");
        WolfRuntime.endTrack(savedChair);
        check(seated.animName.equals("Bob_Seated_SitDown") && seated.deferredBoneName.equals("Bip01")
                && seated.useDeferredRotation,"chair guard restores pooled parameters");
        // 0.4.40: corpse pickup / lay-down plays the head-down Wolf_eat pose,
        // retimed to the human clip (no human root keys), rotation guarded.
        wolfSkin.boneIndices.put("Bip01_Tail",3);
        Clip eat=new Clip(4,List.of(new Frame(0,0,0,3,0),new Frame(0,4,0,3,0),
                new Frame(1,0,7,8,9),new Frame(1,2,7,2,9),new Frame(1,4,7,8,9),
                new Frame(3,0,1,0,0),new Frame(3,0.5f,-1,0,0),new Frame(3,1,1,0,0),new Frame(3,1.5f,-1,0,0),new Frame(3,4,1,0,0),
                at(2,0,0.5f,0,0.25f,"Translation_Data"),at(2,4,0.5f,0,0.25f,"Translation_Data")),"Wolf_eat",true);
        manager.wolf.tag.animationClips.put("Wolf_eat",eat);
        for (String name:new String[]{"Bob_PickUp_Person_FromOnBack","Bob_PickUp_Person_FromOnFront",
                "Bob_PickUp_Person_OnBackLegs","Bob_PutDown_Person_FromOnBack",
                "Bob_LayDown_Person_OnBack","Bob_LayDown_Person_OnFront"}) {
            check(WolfPlayerClips.corpseHandling(name),"corpse utility pose recognised: "+name);
            check(WolfRuntime.clipFor(name).equals("Wolf_eat"),"corpse lift/lower maps to Wolf_eat: "+name);
            humanSkin.animationClips.put(name,stopHuman);
            manager.wolf.tag.animationClips.put("Wolf_idle",wolf);
            seated.animName=name; seated.deferredBoneName="Bip01"; seated.useDeferredRotation=true;
            Object saved=WolfRuntime.beginTrack(p,seated);
            check(saved!=null && seated.animName.startsWith("WTAGarou_Player_") && seated.animName.contains("Wolf_eat")
                    && seated.deferredBoneName.equals("Translation_Data") && !seated.useDeferredRotation,
                    "corpse lift/lower plays a retimed Wolf_eat on the unskinned marker with deferred rotation off");
            Clip pose=(Clip)manager.wolf.tag.animationClips.get(seated.animName);
            close(pose.duration,stopHuman.duration,"corpse pose retimed to the human action length");
            Frame[] poseMarker=pose.getBoneFramesAt(2);
            check(poseMarker.length==2 && poseMarker[0].position.z==0.25f && poseMarker[1].position.z==0.25f,
                    "corpse pose keeps the wolf's own resting marker (no human root keys)");
            check(WTAGarouJava.isCorpseHandling(p.character),"corpse clip start is visible to the Lua bite filter");
            Frame[] tailKeys=pose.getBoneFramesAt(3);
            check(tailKeys.length==2 && tailKeys[0].position.x==1 && tailKeys[1].position.x==1
                    && tailKeys[0].time==0 && Math.abs(tailKeys[1].time-pose.duration)<1e-5f,
                    "0.4.42: tail holds its first Wolf_eat key for the whole corpse action (no wag)");
            check(pose.getBoneFramesAt(1).length==3,"rest of the eat pose still animates");
            WolfRuntime.endTrack(saved);
            check(seated.animName.equals(name) && seated.deferredBoneName.equals("Bip01")
                    && seated.useDeferredRotation,"corpse guard restores pooled parameters");
        }
        check(!WolfPlayerClips.corpseHandling("Bob_Death") && !WolfPlayerClips.corpseHandling("Bob_PickUp_Item")
                && !WolfPlayerClips.corpseHandling("Bob_LayDown") && !WolfPlayerClips.corpseHandling("Bob_LayDown_Sleep"),
                "own death and ordinary item handling excluded from corpse guard");
        check(WolfPlayerClips.corpseHandling("Bob_Throw_Person_IntoContainer") && WolfPlayerClips.corpsePose("Bob_Throw_Person_IntoContainer").equals("Wolf_idle")
                && WolfRuntime.clipFor("Bob_Throw_Person_IntoContainer").equals("Wolf_idle"),"a corpse throw is guarded but stays idle");
        // 0.4.40: dragging a corpse walks the wolf gait pose backwards; the
        // human marker (direction/speed) is untouched; idle while dragging is guarded.
        {
            WolfCombatTest.Params drag=new WolfCombatTest.Params();
            drag.animName="Bob_StrafeLeft"; drag.deferredBoneName="Translation_Data"; drag.useDeferredRotation=true;
            Clip forward=p.play(drag,new Object());
            p.character.stateName="PlayerDraggingCorpse";
            check(WolfGrappleRuntime.isDragging(p.character) && WTAGarouJava.isCorpseHandling(p.character),"dragging state recognised");
            Clip reversed=p.play(drag,new Object());
            check(reversed!=forward,"dragging derives its own (reversed) clip");
            Frame[] spineF=forward.getBoneFramesAt(1), spineR=reversed.getBoneFramesAt(1);
            check(spineF[0].position.x==7 && spineR[0].position.x==8 && spineR[spineR.length-1].position.x==7,
                    "wolf pose keys play backwards while dragging");
            Frame[] mF=forward.getBoneFramesAt(2), mR=reversed.getBoneFramesAt(2);
            check(mR[mR.length-1].position.x==mF[mF.length-1].position.x && mR[0].position.x==mF[0].position.x,
                    "human movement marker untouched (direction and speed match the human clip)");
            check(drag.useDeferredRotation,"gait while dragging keeps the human deferred rotation");
            humanSkin.animationClips.put("Bob_Idle",idle);
            drag.animName="Bob_Idle"; drag.deferredBoneName="Translation_Data"; drag.useDeferredRotation=true;
            Object savedIdle=WolfRuntime.beginTrack(p,drag);
            check(drag.animName.startsWith("WTAGarou_Player_"),"idle while dragging is still a derived clip");
            check(savedIdle!=null && !drag.useDeferredRotation,"stationary clip while dragging: deferred rotation off (vehicle drop spin)");
            WolfRuntime.endTrack(savedIdle);
            p.character.stateName="IdleState";
            check(p.play(drag,new Object())!=null,"idle restores after the drag");
            // Grapple forward offset: only for a flagged, dragging character.
            final class Grappleable { public Object character; }
            Grappleable g=new Grappleable(); g.character=p.character;
            close(WolfGrappleRuntime.offsetForward(g,0.4f),0.4f,"no flag: node offset untouched");
            WTAGarouJava.setGrappleForward(p.character,1.0);
            close(WolfGrappleRuntime.offsetForward(g,0.4f),0.4f,"flag but not dragging: node offset untouched");
            p.character.grappling=true;
            close(WolfGrappleRuntime.offsetForward(g,0.4f),1.4f,"dragging: node offset plus the wolf's extra metre");
            // 0.4.42: Oct 6 console: shoulder grip (trunk drag-out) +0.30 was
            // right at +1.0; leg grip from the ground -0.30 swung to the back.
            close(WolfGrappleRuntime.offsetForward(g,0.3f),1.3f,"shoulder grip (+0.30): extra pushes forward");
            close(WolfGrappleRuntime.offsetForward(g,-0.3f),-1.3f,"leg grip (-0.30): extra follows the node's sign");
            close(WolfGrappleRuntime.offsetForward(g,-0.7f),-1.7f,"leg pickup (-0.70) too");
            close(WolfGrappleRuntime.offsetForward(g,0f),-1.0f,"node at zero keeps the last grip's sign");
            p.character.grappling=false;
            WTAGarouJava.setGrappleForward(p.character,0);
            close(WolfGrappleRuntime.offsetForward(g,0.4f),0.4f,"cleared flag");
            WTAGarouJava.clear(p.character); WTAGarouJava.setWolf(p.character,true);
            WTAGarouJava.setGrappleForward(p.character,1.0); p.character.grappling=true;
            close(WolfGrappleRuntime.offsetForward(g,0f),1.0f,"clear() forgets the last sign (default forward)");
            p.character.grappling=false; WTAGarouJava.setGrappleForward(p.character,0);
            // 0.4.44: shoulders grab from the ground (pickup clip, not legs,
            // ground node -0.9 / -1.2) sits at a fixed distance; else as before.
            WTAGarouJava.setGrappleForward(p.character,0.7); p.character.grappling=true;
            WTAGarouJava.setShoulderPickupDistance(p.character,1.0);
            WolfGrappleRuntime.markCorpseClip(p.character,"Bob_PickUp_Person_FromOnFront");
            close(WolfGrappleRuntime.offsetForward(g,-0.9f),-1.0f,"shoulders ground pickup (FromOnFront -0.9): the carry distance");
            WolfGrappleRuntime.markCorpseClip(p.character,"Bob_PickUp_Person_FromOnBack");
            close(WolfGrappleRuntime.offsetForward(g,-1.2f),-1.0f,"shoulders ground pickup (FromOnBack -1.2): the carry distance");
            WolfGrappleRuntime.markCorpseClip(p.character,"Bob_PickUp_Person_OnBackLegs");
            close(WolfGrappleRuntime.offsetForward(g,-0.7f),-1.4f,"legs pickup keeps the carry extra");
            WolfGrappleRuntime.clearCorpseClip(p.character);
            close(WolfGrappleRuntime.offsetForward(g,-0.3f),-1.0f,"idle drag after the lift: carry extra");
            close(WolfGrappleRuntime.offsetForward(g,0.3f),1.0f,"trunk drag-out (+0.30, not a pickup): carry extra");
            WTAGarouJava.setShoulderPickupDistance(p.character,1.4);
            WolfGrappleRuntime.markCorpseClip(p.character,"Bob_PickUp_Person_FromOnFront");
            close(WolfGrappleRuntime.offsetForward(g,-0.9f),-1.4f,"shoulder distance is tunable (1.4)");
            WTAGarouJava.setShoulderPickupDistance(p.character,0);
            close(WolfGrappleRuntime.offsetForward(g,-0.9f),-1.6f,"cleared: the 0.4.42 behaviour");
            WolfGrappleRuntime.clearCorpseClip(p.character);
            p.character.grappling=false; WTAGarouJava.setGrappleForward(p.character,0);
            // 0.4.44: thrown into a container (not own inventory) -> next stationary clip is corpse handling.
            check(WolfPlayerClips.corpseHandling("Bob_ThrowBody_OutOFWindow")
                    && WolfPlayerClips.corpsePose("Bob_ThrowBody_OutOFWindow").equals("Wolf_idle"),"ThrowBody (Oct 6 console) is corpse handling, idle pose");
            check(!WolfPlayerClips.corpseHandling("Bob_Idle_Body") && !WolfPlayerClips.corpseHandling("Bob_Body_Idle"),"body without a handling verb is not corpse handling");
            WolfGrappleRuntime.markThrow(p.character,p.character.inventory);
            check(!WolfGrappleRuntime.recentThrow(p.character,3.0),"stow into own inventory is not a throw (Crinos/Hispo stow unchanged)");
            WolfGrappleRuntime.markThrow(p.character,new Object());
            check(WolfGrappleRuntime.recentThrow(p.character,3.0),"trunk / seat deposit marked");
            humanSkin.animationClips.put("Bob_DepositBody",idle);
            WolfCombatTest.Params dep=new WolfCombatTest.Params();
            dep.animName="Bob_DepositBody"; dep.deferredBoneName="Bip01"; dep.useDeferredRotation=true;
            Object savedDep=WolfRuntime.beginTrack(p,dep);
            check(savedDep!=null && dep.animName.startsWith("WTAGarou_Player_") && dep.animName.endsWith("pt")
                    && dep.animName.contains("|Wolf_idle|"),"deposit clip after a throw: pose-only idle (whatever its name)");
            check(!dep.useDeferredRotation && dep.deferredBoneName.equals("Translation_Data"),"deposit clip: deferred rotation off");
            WolfRuntime.endTrack(savedDep);
            WolfCombatTest.Params walk=new WolfCombatTest.Params();
            walk.animName="Bob_StrafeLeft"; walk.deferredBoneName="Translation_Data"; walk.useDeferredRotation=true;
            Object savedWalk=WolfRuntime.beginTrack(p,walk);
            check(savedWalk!=null && walk.useDeferredRotation && !walk.animName.endsWith("pt"),"walking away after the throw is an ordinary gait");
            WolfRuntime.endTrack(savedWalk);
            WTAGarouJava.clear(p.character); WTAGarouJava.setWolf(p.character,true);
            check(!WolfGrappleRuntime.recentThrow(p.character,3.0),"clear() forgets the throw");
            // 0.4.42 melee reach: getRangeMod x multiplier for melee only.
            WolfCombatTest.Weapon bite=new WolfCombatTest.Weapon();
            close(MeleeRangeRuntime.scale(bite,p.character,1.0f),1.0f,"unflagged: vanilla range mod");
            check(WTAGarouJava.setMeleeRange(p.character,1.3),"flag accepted");
            close(MeleeRangeRuntime.scale(bite,p.character,1.2f),1.56f,"flagged wolf: melee range mod x1.3");
            WolfCombatTest.Weapon gun=new WolfCombatTest.Weapon(); gun.ranged=true;
            close(MeleeRangeRuntime.scale(gun,p.character,1.0f),1.0f,"ranged weapons untouched");
            WTAGarouJava.setMeleeRange(p.character,1.0);
            close(MeleeRangeRuntime.scale(bite,p.character,1.0f),1.0f,"multiplier 1 clears");
            WTAGarouJava.setMeleeRange(p.character,1.3); WTAGarouJava.clear(p.character); WTAGarouJava.setWolf(p.character,true);
            close(MeleeRangeRuntime.scale(bite,p.character,1.0f),1.0f,"clear() drops the multiplier");
        }
        check(!JawsAttackPatch.swallow(p.character),"wolf with empty jaws still bites");
        WolfCombatTest.Weapon rifle=new WolfCombatTest.Weapon();rifle.ranged=true;p.character.primaryItem=rifle;
        check(JawsAttackPatch.swallow(p.character),"wolf carrying a firearm cannot fire it");
        p.character.primaryItem=new WolfCombatTest.Weapon();
        check(!JawsAttackPatch.swallow(p.character),"wolf carrying a melee item swings it");
        p.character.primaryItem=null;
        WolfCombatTest.Params params=new WolfCombatTest.Params();params.animName="Bob_StrafeLeft";
        params.deferredBoneName="Translation_Data";params.useDeferredRotation=true;
        Object originalMask=params.subLayerBoneWeights;
        Clip result=p.play(params,new Object());
        close(result.duration,1.0f*0.6f/1.0f*2.0f,"advice selects stride-matched clip (Lupus scale 0.6, x2 slowdown)");
        Frame[] m=result.getBoneFramesAt(2);
        check(m[m.length-1].position.x-m[0].position.x<0,"advice preserves left strafe direction");
        check(params.animName.equals("Bob_StrafeLeft") && params.subLayerBoneWeights==originalMask
                && params.deferredBoneName.equals("Translation_Data") && params.useDeferredRotation,
                "pooled parameters restored after derived playback");
        check(p.play(params,new Object())==result,"derived clips cached without per-frame allocation");
        check(humanSkin.animationClips.get("Bob_StrafeLeft")==human,"human map never edited");
        check(wolfSkin.animationClips.get("Wolf_walk")==wolf,"imported wolf clip never edited");

        WolfCombatTest.install(inst,Action.class,ShiftNilPatch.class,"setActionAnim");
        Action action=new Action();action.chr=p.character;
        WTAGarouJava.beginShiftAnimation(p.character);
        try {
            action.setActionAnim((WolfCombatTest.Axis)null);
            action.setActionAnim((String)null);
            check(action.calls==0,"both null overloads bypassed only in transformation scope");
            action.setActionAnim("Drink");
            check(action.calls==1,"non-null howl untouched even in scope");
            Action other=new Action();other.chr=new Object();other.setActionAnim((String)null);
            check(other.calls==1,"other character actions unchanged");
        } finally { WTAGarouJava.endShiftAnimation(); }
        action.setActionAnim((String)null);
        check(action.calls==2,"ordinary calls outside scope unchanged");
        try { action.setActionAnim((WolfCombatTest.Axis)null);throw new AssertionError("global guard leaked"); }
        catch(NullPointerException expected) { check(true,"enum behavior outside shift untouched"); }
        // 0.4.96: a fence/climb/window action carries the human clip's vertical
        // rise onto the wolf root (the wolf pose has no arc of its own).
        {
            humanSkin.boneIndices.put("Bip01_Pelvis",1);
            Clip idleClip=new Clip(1,List.of(new Frame(0,0,0,3,0),new Frame(0,1,0,3,0),
                    new Frame(1,0,7,8,9),new Frame(1,1,7,8,9),
                    at(2,0,0,0,0,"Translation_Data"),at(2,1,0,0,0,"Translation_Data")),"Wolf_idle",true);
            Clip hopClip=new Clip(2,List.of(at(2,0,0,0,0,"Translation_Data"),at(2,2,0,0,1,"Translation_Data"),
                    at(1,0,0,1.0f,0,"Bip01_Pelvis"),at(1,0.5f,0,1.2f,0,"Bip01_Pelvis"),at(1,1,0,1.6f,0,"Bip01_Pelvis"),
                    at(1,1.5f,0,0.9f,0,"Bip01_Pelvis"),at(1,2,0,1.0f,0,"Bip01_Pelvis")),"Bob_ClimbFence",true);
            float renderScale=1.5f;
            Clip derived=(Clip)WolfPlayerClips.derive(idleClip,hopClip,wolfSkin,humanSkin,"Translation_Data","Bob_ClimbFence",renderScale);
            close(derived.duration,2f,"climb action keeps the human duration");
            Frame[] root=derived.getBoneFramesAt(0);
            Arrays.sort(root,(x,y)->Float.compare(x.time,y.time));
            check(root.length==5,"root keys inserted at the human key times: "+root.length);
            close(root[0].position.y,3f,"start: wolf rest height");
            close(root[1].position.y,3f+0.2f/renderScale,"quarter: human rise 0.2 in wolf units");
            close(root[2].position.y,3f+0.6f/renderScale,"peak: human rise 0.6 carried onto the wolf root, divided by the render scale");
            close(root[3].position.y,3f,"a dip below the start is clamped to the rest height (never pushed into the floor)");
            close(root[4].position.y,3f,"end: back at rest");
            for (Frame f:root) { close(f.position.x,0,"root x still held"); close(f.position.z,0,"root z still held"); }
            Frame[] spine=derived.getBoneFramesAt(1);
            for (Frame f:spine) close(f.position.y,8,"only the root is lifted");
            float[][] arc=WolfPlayerClips.humanArc(hopClip,humanSkin);
            close(WolfPlayerClips.arcAt(arc,0.75f),0.4f,"arc interpolates between human keys");
            close(WolfPlayerClips.arcAt(arc,5f),0f,"arc clamps past the end");
            // A flat human track (no rise) leaves the wolf alone.
            Clip flat=new Clip(2,List.of(at(2,0,0,0,0,"Translation_Data"),at(2,2,0,0,1,"Translation_Data"),
                    at(1,0,0,1.0f,0,"Bip01_Pelvis"),at(1,2,0,1.0f,0,"Bip01_Pelvis")),"Bob_ClimbWindow",true);
            Clip flatDerived=(Clip)WolfPlayerClips.derive(idleClip,flat,wolfSkin,humanSkin,"Translation_Data","Bob_ClimbWindow",renderScale);
            Frame[] flatRoot=flatDerived.getBoneFramesAt(0);
            check(flatRoot.length==2,"no rise: no extra keys");
            for (Frame f:flatRoot) close(f.position.y,3f,"no rise: root untouched");
            // A walk never gets the arc even if the pelvis bobs.
            Clip walk=new Clip(2,List.of(at(2,0,0,0,0,"Translation_Data"),at(2,2,0,0,2,"Translation_Data"),
                    at(1,0,0,1.0f,0,"Bip01_Pelvis"),at(1,1,0,1.5f,0,"Bip01_Pelvis"),at(1,2,0,1.0f,0,"Bip01_Pelvis")),"Bob_Walk",true);
            Clip walkDerived=(Clip)WolfPlayerClips.derive(wolf,walk,wolfSkin,humanSkin,"Translation_Data","Bob_Walk",renderScale);
            for (Frame f:walkDerived.getBoneFramesAt(0)) check(f.position.y<=4f+1e-4f,"gait root keeps only the wolf bob");
            humanSkin.boneIndices.remove("Bip01_Pelvis");
        }
        System.out.println("PASS: "+checks+" player-motion/shift-scope assertions.");
    }
}
