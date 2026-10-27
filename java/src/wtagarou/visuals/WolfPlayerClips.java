package wtagarou.visuals;

import java.util.*;

/**
 * Wolf pose + the player's own movement marker.
 *
 * Build 42 moves a character purely through the deferred-movement bone of
 * the playing clip (the unskinned Translation_Data marker in every human
 * clip); the skinned Bip01 root of a human clip stays in place.  A derived
 * clip therefore keeps every wolf bone pose, holds the wolf Bip01 root in
 * place (belt and braces over tools/bake_wolf_root_inplace.py) and gives
 * the wolf's Translation_Data marker the HUMAN clip's marker keyframes:
 * same direction, same speed, same deferred rotation as the human player.
 *
 * Locomotion timing is stride-matched: the wolf clip is played over the time
 * its own stride (scaled by the render scale) needs at the human clip's
 * speed, so the paws stop sliding and a walk clip never looks like a run.
 * Non-locomotion clips keep their native wolf duration.
 *
 * Never overwrite the imported human/wolf clips; only add private keys.
 */
public final class WolfPlayerClips {
    private static final Map<Object,Map<String,Entry>> CACHE = new WeakHashMap<>();
    private record Entry(Object human, Object wolf, String key) {}
    public static volatile int built;
    private static boolean warned;
    /** Marker travel below this (tiles) is a turn/idle shuffle, not a gait. */
    public static final float MIN_STRIDE = 0.15f;
    public static final float MIN_DURATION = 0.15f, MAX_DURATION = 4.0f;

    public static Object humanData() throws ReflectiveOperationException {
        Object manager=Class.forName("zombie.core.skinnedmodel.ModelManager").getField("instance").get(null);
        return Reflect.get(Reflect.get(manager,"maleModel"),"tag");
    }
    public static Object weights(Object source,Object skin) throws ReflectiveOperationException {
        if (!(source instanceof List<?> list)) return source;
        Map<?,?> indices=(Map<?,?>)Reflect.get(skin,"boneIndices");
        List<Object> result=new ArrayList<>();
        for (Object weight:list)
            if (indices.containsKey(Reflect.get(weight,"boneName"))) result.add(weight);
        return result;
    }
    @SuppressWarnings("unchecked")
    public static String adapt(Object skin,String requested,String wolfName,String humanBone,float renderScale) {
        return adapt(skin,requested,wolfName,humanBone,renderScale,false);
    }
    /** 0.4.40: `reversePose` plays the wolf's pose keys backwards (a corpse
     * drag walks the wolf backwards) while the human movement marker is
     * copied unchanged, so direction and speed still match the human clip. */
    @SuppressWarnings("unchecked")
    public static String adapt(Object skin,String requested,String wolfName,String humanBone,float renderScale,
                               boolean reversePose) {
        return adapt(skin,requested,wolfName,humanBone,renderScale,reversePose,false);
    }
    /** 0.4.44: `forcePoseOnly` treats the clip as corpse handling whatever its
     * name (a body dropped into a trunk / seat; see CorpseThrowPatch). */
    @SuppressWarnings("unchecked")
    public static String adapt(Object skin,String requested,String wolfName,String humanBone,float renderScale,
                               boolean reversePose,boolean forcePoseOnly) {
        try {
            Map<String,Object> clips=(Map<String,Object>)Reflect.get(skin,"animationClips");
            Object wolf=clips.get(wolfName);
            Object humanSkin=humanData();
            Object human=((Map<?,?>)Reflect.get(humanSkin,"animationClips")).get(requested);
            if (human==null || wolf==null || humanBone==null) return wolfName; // e.g. a native ragdoll
            // A seated human node uses its SKINNED root as the movement
            // marker. Copying it replaces the wolf's root rotation/scale.
            // Keep the authored wolf sit pose; native seating queries still
            // use human data through WolfSeatingPatch.
            if (furnitureRoot(requested, humanBone)) return wolfName;
            // 0.4.40: a corpse pickup / lay-down keeps the wolf's own marker
            // (no human skinned root) but is retimed to the human clip, so
            // the Wolf_eat pose finishes with the vanilla action.
            boolean poseOnly=forcePoseOnly || corpseHandling(requested);
            String scaleKey=String.format(Locale.ROOT,"%.2f",renderScale)+"x"+String.format(Locale.ROOT,"%.2f",cycleSlowdown)
                    +"a"+Float.toString(attackSpeed)+"s"+Float.toString(stompSpeed)
                    +(markerAtOrigin?"o":"")+(transitionsKeepHumanTiming?"t":"")
                    +(reversePose?"r":"")+(poseOnly?"pt":"");
            String cacheKey=requested+"|"+wolfName+"|"+humanBone+"|"+scaleKey;
            Map<String,Entry> entries=CACHE.computeIfAbsent(skin,k->new HashMap<>());
            Entry previous=entries.get(cacheKey);
            if (previous!=null && previous.human==human && previous.wolf==wolf && clips.containsKey(previous.key))
                return previous.key;
            String key="WTAGarou_Player_"+cacheKey;
            Object derived=poseOnly?derivePoseOnly(wolf,human,requested,tailBones(skin))
                    :derive(wolf,human,skin,humanSkin,humanBone,requested,renderScale,reversePose);
            clips.put(key,derived);
            entries.put(cacheKey,new Entry(human,wolf,key));
            built++;
            if (isGait(wolfName) && gaitLogged<16) {
                gaitLogged++;
                System.out.println("[WTAGarou Java][Gait] "+lastDiag+" -> "+wolfName);
            }
            if (built<=3) System.out.println("[WTAGarou Java] player-motion clip ready: "
                    +requested+" -> "+wolfName+"; human duration="+Reflect.call(human,"getDuration")
                    +"; derived duration="+Reflect.call(derived,"getDuration")+"; scale="+scaleKey);
            return key;
        } catch (ReflectiveOperationException | RuntimeException error) {
            if (!warned) {
                warned=true;
                System.out.println("[WTAGarou Java] player-motion clip adaptation unavailable: "+error);
            }
            return wolfName;
        }
    }

    /** Stride-matched playback length. Public for deterministic tests. */
    /** 0.4.22: the wolf's movement speed buff made the stride-matched gait
     * clips cycle very fast (Bob_Walk -> 0.42 s per wolf walk cycle). The
     * user asked for the animations at half speed or slower while the
     * movement speed stays; the feet slide a little instead. Set from
     * WTAGarou.WolfGait.CYCLE_SLOWDOWN through WTAGarouJava.setGaitSlowdown. */
    public static volatile float cycleSlowdown = 2.0f;
    public static volatile float attackSpeed = 1.5f;
    public static volatile float stompSpeed = 1.0f;
    public static boolean furnitureRoot(String name, String bone) {
        String n = name == null ? "" : name.toLowerCase(Locale.ROOT);
        return "Bip01".equals(bone) && (n.contains("seated") || n.contains("sitfurniture") || n.contains("sitonfurniture"));
    }
    /** Stationary corpse lift/lower poses must not donate a human skinned
     * root (including its roll) to the quadruped. Gameplay/grapple offsets
     * remain native; this is not the wolf player's own death handoff. */
    /** 0.4.44: "body" joined the nouns. Oct 6 console: Bob_ThrowBody_OutOFWindow
     * was not corpse handling by name, so it took the motion derive with the
     * human marker and then had its deferred bone swapped; the trunk / seat
     * deposit clip is the same family. */
    public static boolean corpseHandling(String name) {
        String n=name==null ? "" : name.toLowerCase(Locale.ROOT).replace("_","");
        return (n.contains("pickup") || n.contains("putdown") || n.contains("laydown")
                || n.contains("throw") || n.contains("container") || n.contains("trunk") || n.contains("deposit"))
                && (n.contains("person") || n.contains("corpse") || n.contains("deadbody") || n.contains("body"));
    }
    /** 0.4.40: the wolf pose for a corpse-handling clip. Lifting and lowering
     * a body is the head-down Wolf_eat; a throw (into a trunk, out of a
     * window, over a fence) has no wolf equivalent and stays idle. */
    public static String corpsePose(String name) {
        String n=name==null ? "" : name.toLowerCase(Locale.ROOT).replace("_","");
        if (n.contains("throw") || n.contains("container") || n.contains("trunk") || n.contains("deposit")) return "Wolf_idle";
        return "Wolf_eat";
    }
    /** 0.4.40: retime a wolf clip to the human clip's duration, keeping every
     * wolf bone (marker included) and holding the skinned root in place. */
    /** 0.4.42: wolf rig tail bones (Bip01_Tail, Bip01_Tail1). */
    static Set<Integer> tailBones(Object skin) {
        Set<Integer> out=new HashSet<>();
        try {
            Map<?,?> indices=(Map<?,?>)Reflect.get(skin,"boneIndices");
            for (Map.Entry<?,?> e:indices.entrySet())
                if (String.valueOf(e.getKey()).startsWith("Bip01_Tail") && e.getValue() instanceof Number)
                    out.add(((Number)e.getValue()).intValue());
        } catch (ReflectiveOperationException | RuntimeException ignored) {}
        return out;
    }
    public static Object derivePoseOnly(Object wolf,Object human,String name) throws ReflectiveOperationException {
        return derivePoseOnly(wolf,human,name,Collections.emptySet());
    }
    /** 0.4.42: Wolf_eat squeezed into a ~1 s corpse pickup wagged the tail
     * "like crazy" (Oct 6 playtest). Tail bones hold their first key for the
     * whole action; the rest of the pose is retimed as before. */
    public static Object derivePoseOnly(Object wolf,Object human,String name,Set<Integer> tail) throws ReflectiveOperationException {
        float humanDuration=number(Reflect.call(human,"getDuration"));
        float wolfDuration=number(Reflect.call(wolf,"getDuration"));
        if (!(humanDuration>0) || !(wolfDuration>0)) throw new IllegalStateException("invalid clip duration");
        float duration=Math.max(MIN_DURATION,humanDuration);
        float poseScale=duration/wolfDuration;
        Object[] frames=(Object[])Reflect.call(wolf,"getKeyframes");
        List<Object> output=new ArrayList<>();
        Map<Integer,Object> tailFirst=new HashMap<>();
        for (Object frame:frames) {
            int bone=((Number)Reflect.get(frame,"bone")).intValue();
            if (tail.contains(bone)) {
                Object first=tailFirst.get(bone);
                if (first==null || time(frame)<time(first)) tailFirst.put(bone,frame);
                continue;
            }
            Object copy=copy(frame);
            Reflect.set(copy,"time",Math.min(duration,number(Reflect.get(frame,"time"))*poseScale));
            output.add(copy);
        }
        for (Object first:tailFirst.values()) {
            Object start=copy(first); Reflect.set(start,"time",0f); output.add(start);
            Object end=copy(first); Reflect.set(end,"time",duration); output.add(end);
        }
        output.sort(Comparator.comparingDouble(WolfPlayerClips::time));
        return wolf.getClass().getConstructor(float.class,List.class,String.class,boolean.class)
                .newInstance(duration,output,name,true);
    }
    /** 0.4.24: transition clips (IdleToRun, RunToStop, WalkToTurn180L,
     * IdleToWalk180R ...) are one-shot root-motion clips, not cycles. The
     * stride match stretched Bob_RunToStop (1.0 s, 0.81 m) to the 4 s cap
     * and scaled its marker travel with it: the wolf coasted for seconds
     * after the keys were released, and a Ctrl-strafe started during that
     * stretched stop swung the body around (September 27 playtest). With
     * this on, a transition keeps the HUMAN duration and marker travel 1:1
     * and the wolf gait cycle is tiled across it at its stride-matched
     * cadence. WTAGarou.WolfGait.TRANSITIONS_KEEP_HUMAN_TIMING. */
    public static volatile boolean transitionsKeepHumanTiming = true;
    private static final java.util.regex.Pattern TRANSITION =
            java.util.regex.Pattern.compile("(?:[a-z0-9]To[A-Z])|(?:Turn)|(?:\\d{2,3}[LR](?:_|$))");
    public static boolean isTransition(String humanName) {
        return humanName != null && TRANSITION.matcher(humanName).find();
    }
    public static boolean windowAction(String name) {
        String n=name==null?"":name.toLowerCase(Locale.ROOT);
        return n.contains("window") || n.contains("climb") || n.contains("fence") || n.contains("vault");
    }
    public static float derivedDuration(float wolfDuration,float wolfStride,float humanDuration,
                                        float humanStride,float renderScale) {
        if (humanStride<MIN_STRIDE || wolfStride<MIN_STRIDE || !(humanDuration>0)) return wolfDuration;
        float humanSpeed=humanStride/humanDuration;
        float duration=wolfStride*Math.max(0.05f,renderScale)/humanSpeed*Math.max(0.1f,cycleSlowdown);
        return Math.max(MIN_DURATION,Math.min(MAX_DURATION,duration));
    }
    /** Forget every derived clip (they are rebuilt on the next request). */
    public static void clearCache() { CACHE.clear(); }

    /** Public for deterministic fixture testing without invoking the game. */
    public static Object derive(Object wolf,Object human,Object wolfSkin,Object humanSkin,
                                String humanBone,String name,float renderScale) throws ReflectiveOperationException {
        return derive(wolf,human,wolfSkin,humanSkin,humanBone,name,renderScale,false);
    }
    public static Object derive(Object wolf,Object human,Object wolfSkin,Object humanSkin,
                                String humanBone,String name,float renderScale,boolean reversePose) throws ReflectiveOperationException {
        float humanDuration=number(Reflect.call(human,"getDuration"));
        float wolfDuration=number(Reflect.call(wolf,"getDuration"));
        if (!(humanDuration>0) || !(wolfDuration>0)) throw new IllegalStateException("invalid clip duration");
        Map<?,?> wolfIndices=(Map<?,?>)Reflect.get(wolfSkin,"boneIndices");
        Number root=(Number)wolfIndices.get("Bip01");
        Number marker=(Number)wolfIndices.get(humanBone);
        Number source=(Number)((Map<?,?>)Reflect.get(humanSkin,"boneIndices")).get(humanBone);
        if (marker==null || source==null) throw new IllegalStateException("movement marker missing: "+humanBone);
        Object[] wolfFrames=(Object[])Reflect.call(wolf,"getKeyframes");
        List<Object> humanList=new ArrayList<>(Arrays.asList(
                (Object[])Reflect.call(human,"getBoneFramesAt",int.class,source.intValue())));
        if (humanList.isEmpty()) throw new IllegalStateException("human marker frames missing");
        humanList.sort(Comparator.comparingDouble(WolfPlayerClips::time));

        List<Object> markerFrames=new ArrayList<>();
        List<Object> poseFrames=new ArrayList<>();
        Object rootStart=null;
        for (Object frame:wolfFrames) {
            int bone=((Number)Reflect.get(frame,"bone")).intValue();
            if (bone==marker.intValue()) { markerFrames.add(frame); continue; }
            poseFrames.add(frame);
            if (root!=null && bone==root.intValue()) {
                if (rootStart==null || time(frame)<time(rootStart)) rootStart=frame;
            }
        }
        markerFrames.sort(Comparator.comparingDouble(WolfPlayerClips::time));
        // 0.4.20: stride is the LARGEST marker displacement from the first
        // frame, not first-to-last. A looping clip whose marker snaps back on
        // its final key measured as "no stride" and fell to the wolf's native
        // duration, which is how a walk could cycle faster than a run.
        float wolfStride=stride(markerFrames);
        Object humanStart=Reflect.get(humanList.get(0),"position");
        float humanStride=stride(humanList);
        String wolfName=String.valueOf(Reflect.get(wolf,"name"));
        boolean attack=wolfName.toLowerCase(Locale.ROOT).startsWith("wolf_attack");
        boolean seatedAction=wolfName.equals("Wolf_getup") || wolfName.equals("Wolf_Sit");
        boolean transition=!attack && !seatedAction && !windowAction(name)
                && transitionsKeepHumanTiming && isTransition(name);
        // A transition keeps the human clock (marker travel 1:1) and tiles the
        // wolf cycle at its native cadence (x slowdown); a cycle IS the clock.
        boolean stomp=name != null && (name.toLowerCase(Locale.ROOT).contains("stomp")
                || name.toLowerCase(Locale.ROOT).contains("stamp"));
        float cycle=(windowAction(name) || seatedAction)?humanDuration
                :attack?wolfDuration/Math.max(0.1f,stomp ? stompSpeed : attackSpeed)
                :transition?Math.max(MIN_DURATION,wolfDuration*Math.max(0.1f,cycleSlowdown))
                :derivedDuration(wolfDuration,wolfStride,humanDuration,humanStride,renderScale);
        float duration=transition?humanDuration:cycle;
        lastDiag=String.format(Locale.ROOT,
                "human %s: duration=%.3f stride=%.3f speed=%.3f | wolf: duration=%.3f stride=%.3f x scale %.2f | derived=%.3f%s%s",
                name,humanDuration,humanStride,humanStride/humanDuration,wolfDuration,wolfStride,renderScale,duration,
                (humanStride<MIN_STRIDE||wolfStride<MIN_STRIDE)?" (no stride match: wolf duration kept)":"",
                transition?String.format(Locale.ROOT," (transition: human timing kept, wolf cycle %.3f tiled)",cycle):"");
        float poseScale=(transition?cycle:duration)/wolfDuration;
        float motionScale=duration/humanDuration;

        List<Object> output=new ArrayList<>();
        float rootX=rootStart==null?0f:number(Reflect.get(Reflect.get(rootStart,"position"),"x"));
        float rootZ=rootStart==null?0f:number(Reflect.get(Reflect.get(rootStart,"position"),"z"));
        // Cycles: one wolf cycle stretched to the derived clock. Transitions:
        // the wolf cycle (at its own stride-matched clock) tiled until the
        // human clip ends, so the legs keep their cadence through a stop.
        int tiles=transition?Math.max(1,(int)Math.ceil(duration/cycle)):1;
        for (int tile=0;tile<tiles;tile++) {
            float base=tile*cycle;
            for (Object frame:poseFrames) {
                // Reversed pose: the wolf key at time k plays at (cycle - k).
                float keyTime=number(Reflect.get(frame,"time"));
                if (reversePose) keyTime=Math.max(0f,wolfDuration-keyTime);
                float t=base+keyTime*poseScale;
                if (tile>0 && (t>duration || keyTime==0f)) continue;
                Object copy=copy(frame);
                Reflect.set(copy,"time",Math.min(duration,t));
                if (root!=null && ((Number)Reflect.get(frame,"bone")).intValue()==root.intValue()) {
                    // The skinned root never travels; the game moves the character.
                    Object pos=Reflect.get(copy,"position");
                    Reflect.set(pos,"x",rootX);
                    Reflect.set(pos,"z",rootZ);
                }
                output.add(copy);
            }
        }
        // 0.4.96: a climb/fence/window action plays a wolf pose (Wolf_climb,
        // else the idle) that has no vertical arc, so the wolf glided through
        // the rail at ground height. The human clip's rise (Bip01 + Pelvis Y
        // above their first key) is added to the wolf root, in wolf model
        // units, with extra root keys at the human key times so the arc is
        // not flattened to the wolf's two idle keys.
        if (root!=null && windowAction(name)) {
            try { liftRoot(output,root.intValue(),human,humanSkin,duration/humanDuration,renderScale); }
            catch (Throwable t) {
                if (liftWarned.compareAndSet(false,true))
                    System.out.println("[WTAGarou Java][Gait] wolf climb arc skipped ("+name+"): "+t);
            }
        }
        // The wolf marker's rest offset is kept; only the human's deltas are
        // applied, scaled so speed is identical to the human clip.
        Object markerRest=markerFrames.isEmpty()?null:Reflect.get(markerFrames.get(0),"position");
        float restX=markerRest==null?0f:number(Reflect.get(markerRest,"x"));
        float restY=markerRest==null?0f:number(Reflect.get(markerRest,"y"));
        float restZ=markerRest==null?0f:number(Reflect.get(markerRest,"z"));
        // 0.4.22 diagnostic for the "wolf swings around the origin / dips into
        // the floor on a hard turn" report: the deferred movement is the
        // marker's frame-to-frame delta, so a marker that RESTS off the
        // origin turns that rest offset into a spurious arc whenever the
        // human clip carries deferred rotation (turn/aim clips). The rest
        // offset is logged once per wolf clip; markerAtOrigin=true drops it
        // (WTAGarou.WolfGait.MARKER_AT_ORIGIN).
        String wolfClipName=String.valueOf(Reflect.get(wolf,"name"));
        if (markerRestLogged.add(wolfClipName)) {
            System.out.println(String.format(Locale.ROOT,
                    "[WTAGarou Java][Gait] wolf clip %s marker %s rests at (%.3f, %.3f, %.3f)%s",
                    wolfClipName,humanBone,restX,restY,restZ,markerAtOrigin?" - moved to the origin (MARKER_AT_ORIGIN)":""));
        }
        if (markerAtOrigin) { restX=0f; restY=0f; restZ=0f; }
        float startX=number(Reflect.get(humanStart,"x")), startY=number(Reflect.get(humanStart,"y")),
              startZ=number(Reflect.get(humanStart,"z"));
        for (Object frame:humanList) {
            Object copy=copy(frame);
            Reflect.set(copy,"bone",marker.intValue());
            Reflect.set(copy,"boneName",humanBone);
            Reflect.set(copy,"time",Math.max(0f,Math.min(duration,number(Reflect.get(frame,"time"))*motionScale)));
            Object pos=Reflect.get(copy,"position");
            Reflect.set(pos,"x",restX+(number(Reflect.get(pos,"x"))-startX)*motionScale);
            Reflect.set(pos,"y",restY+(number(Reflect.get(pos,"y"))-startY)*motionScale);
            Reflect.set(pos,"z",restZ+(number(Reflect.get(pos,"z"))-startZ)*motionScale);
            output.add(copy);
        }
        output.sort(Comparator.comparingDouble(WolfPlayerClips::time));
        // Preserve the source player identity, not "Wolf_walk" for all tracks.
        return wolf.getClass().getConstructor(float.class,List.class,String.class,boolean.class)
                .newInstance(duration,output,name,true);
    }
    /** Human bones whose Y keys carry a climb's rise (summed; a static one adds 0). */
    static final String[] LIFT_BONES={"Bip01","Bip01_Pelvis"};
    /** Gain on the human rise carried onto the wolf root (1 = the human arc in world units). */
    public static volatile float climbArcGain=1f;
    /** Rises below this (world metres) are noise, not a climb. */
    static final float MIN_ARC=0.02f;
    private static final java.util.concurrent.atomic.AtomicBoolean liftWarned=new java.util.concurrent.atomic.AtomicBoolean();
    private static int arcLogged=0;

    /** The human clip's vertical arc: {times, rises}, rise = summed Y of
     *  LIFT_BONES above their first key, never negative, sampled at the union
     *  of their key times. null when no such track exists. */
    public static float[][] humanArc(Object human,Object humanSkin) throws ReflectiveOperationException {
        Map<?,?> idx=(Map<?,?>)Reflect.get(humanSkin,"boneIndices");
        java.util.TreeSet<Float> times=new java.util.TreeSet<>();
        List<List<Object>> tracks=new ArrayList<>();
        for (String bone:LIFT_BONES) {
            Number i=(Number)idx.get(bone);
            if (i==null) continue;
            Object[] frames=(Object[])Reflect.call(human,"getBoneFramesAt",int.class,i.intValue());
            if (frames==null || frames.length<2) continue;
            List<Object> track=new ArrayList<>(Arrays.asList(frames));
            track.sort(Comparator.comparingDouble(WolfPlayerClips::time));
            tracks.add(track);
            for (Object f:track) times.add((float)time(f));
        }
        if (tracks.isEmpty()) return null;
        float[] t=new float[times.size()], rise=new float[times.size()];
        int n=0; for (Float v:times) t[n++]=v;
        for (int k=0;k<t.length;k++) {
            float sum=0f;
            for (List<Object> track:tracks) sum+=sampleY(track,t[k])-sampleY(track,t[0]);
            rise[k]=Math.max(0f,sum);
        }
        return new float[][]{t,rise};
    }
    /** Linear sample of a track's position.y at time t (clamped to its ends). */
    static float sampleY(List<Object> track,float t) throws ReflectiveOperationException {
        Object prev=track.get(0);
        if (t<=time(prev)) return number(Reflect.get(Reflect.get(prev,"position"),"y"));
        for (int i=1;i<track.size();i++) {
            Object next=track.get(i);
            float t0=(float)time(prev), t1=(float)time(next);
            if (t<=t1) {
                float y0=number(Reflect.get(Reflect.get(prev,"position"),"y")), y1=number(Reflect.get(Reflect.get(next,"position"),"y"));
                return t1-t0<=1e-6f?y1:y0+(y1-y0)*(t-t0)/(t1-t0);
            }
            prev=next;
        }
        return number(Reflect.get(Reflect.get(prev,"position"),"y"));
    }
    /** Linear sample of an arc ({times, rises}) at time t (clamped). */
    public static float arcAt(float[][] arc,float t) {
        float[] times=arc[0], rise=arc[1];
        if (t<=times[0]) return rise[0];
        for (int i=1;i<times.length;i++) {
            if (t<=times[i]) {
                float span=times[i]-times[i-1];
                return span<=1e-6f?rise[i]:rise[i-1]+(rise[i]-rise[i-1])*(t-times[i-1])/span;
            }
        }
        return rise[rise.length-1];
    }
    /** Adds the human arc (timeScale = derived/human duration) to the wolf
     *  root frames in {@code output} and inserts root keys at the human key
     *  times (pose copied from the nearest wolf root key). */
    static void liftRoot(List<Object> output,int root,Object human,Object humanSkin,float timeScale,float renderScale)
            throws ReflectiveOperationException {
        float[][] arc=humanArc(human,humanSkin);
        if (arc==null || !(renderScale>0f) || !(timeScale>0f)) return;
        float peak=0f; for (float r:arc[1]) peak=Math.max(peak,r);
        if (peak<MIN_ARC) return;
        float gain=climbArcGain/renderScale;
        List<Object> rootFrames=new ArrayList<>();
        for (Object f:output) if (((Number)Reflect.get(f,"bone")).intValue()==root) rootFrames.add(f);
        if (rootFrames.isEmpty()) return;
        rootFrames.sort(Comparator.comparingDouble(WolfPlayerClips::time));
        float[] baseY=new float[rootFrames.size()];
        for (int i=0;i<rootFrames.size();i++) baseY[i]=number(Reflect.get(Reflect.get(rootFrames.get(i),"position"),"y"));
        // Extra keys first (they need the unlifted wolf Y).
        for (float ht:arc[0]) {
            float t=ht*timeScale;
            boolean present=false;
            for (Object f:rootFrames) if (Math.abs(time(f)-t)<1e-3) { present=true; break; }
            if (present) continue;
            int after=0;
            while (after<rootFrames.size() && time(rootFrames.get(after))<t) after++;
            int before=Math.max(0,after-1); if (after>=rootFrames.size()) after=rootFrames.size()-1;
            float t0=(float)time(rootFrames.get(before)), t1=(float)time(rootFrames.get(after));
            float y=t1-t0<=1e-6f?baseY[after]:baseY[before]+(baseY[after]-baseY[before])*(t-t0)/(t1-t0);
            Object copy=copy(rootFrames.get(t-t0<=t1-t ? before : after));
            Reflect.set(copy,"time",t);
            Reflect.set(Reflect.get(copy,"position"),"y",y+arcAt(arc,ht)*gain);
            output.add(copy);
        }
        for (Object f:rootFrames) {
            Object pos=Reflect.get(f,"position");
            Reflect.set(pos,"y",number(Reflect.get(pos,"y"))+arcAt(arc,(float)time(f)/timeScale)*gain);
        }
        if (arcLogged<3) {
            arcLogged++;
            System.out.println(String.format(Locale.ROOT,"[WTAGarou Java][Gait] wolf climb arc: human rise %.3f m carried onto the wolf root (x %.2f, %d keys)",peak,gain,arc[0].length));
        }
    }
    /** Largest displacement of a marker from its first (time-sorted) frame. */
    public static float stride(List<Object> frames) throws ReflectiveOperationException {
        if (frames.size()<2) return 0f;
        Object start=Reflect.get(frames.get(0),"position");
        float best=0f;
        for (int i=1;i<frames.size();i++) best=Math.max(best,distance(start,Reflect.get(frames.get(i),"position")));
        return best;
    }
    /** Description of the last derivation (gait logging). */
    public static volatile String lastDiag="";
    /** 0.4.22: place the wolf's movement marker at the origin instead of its
     * authored rest offset (see derive). Off by default: unverified in game. */
    public static volatile boolean markerAtOrigin=false;
    private static final Set<String> markerRestLogged=java.util.concurrent.ConcurrentHashMap.newKeySet();
    private static int gaitLogged=0;
    private static boolean isGait(String wolfName) {
        return "Wolf_walk".equals(wolfName) || "Wolf_run".equals(wolfName) || "Wolf_run_fourx".equals(wolfName);
    }
    private static float distance(Object a,Object b) throws ReflectiveOperationException {
        float dx=number(Reflect.get(b,"x"))-number(Reflect.get(a,"x"));
        float dy=number(Reflect.get(b,"y"))-number(Reflect.get(a,"y"));
        float dz=number(Reflect.get(b,"z"))-number(Reflect.get(a,"z"));
        return (float)Math.sqrt(dx*dx+dy*dy+dz*dz);
    }
    private static Object copy(Object frame) throws ReflectiveOperationException {
        Object result=frame.getClass().getConstructor().newInstance();
        Reflect.call(result,"set",frame.getClass(),frame);
        return result;
    }
    private static float number(Object value) { return ((Number)value).floatValue(); }
    private static double time(Object frame) {
        try { return number(Reflect.get(frame,"time")); }
        catch (ReflectiveOperationException error) { throw new IllegalStateException(error); }
    }
}
