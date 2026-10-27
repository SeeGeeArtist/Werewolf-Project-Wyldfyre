package wtagarou.visuals;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Locale;
import java.util.Set;
import java.util.WeakHashMap;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

/** Direct IsoPlayer-body experiment, not an IsoAnimal or mount.
 * Keeps gameplay state/events in the player's existing graph; only substitutes
 * wolf clips, bone masks and render assets. It is NOT a complete wolf AnimSet.
 * Requires playtesting: human event timing on shorter wolf clips, movement,
 * upper-body blending, and unsupported actions can still look wrong. */
public final class WolfRuntime {
    /** First calibration from the 0.4.7 playtest, not a collision/speed scale.
     * Hispo remains 1.25 times Lupus. Needs another visual size check in game. */
    public static final float BODY_SCALE = 0.60f;
    private static final Map<Object,Object> WOLVES =
            Collections.synchronizedMap(new WeakHashMap<>());
    private static final Map<Object,Boolean> DEFERRED_RESETS =
            Collections.synchronizedMap(new WeakHashMap<>());
    private static final Set<Object> CORPSE_HANDOFF = Collections.newSetFromMap(new WeakHashMap<>());
    private static final Set<String> WARNINGS = ConcurrentHashMap.newKeySet();
    public static volatile boolean bodyHookObserved, trackHookObserved, wolfDrawObserved;
    public static volatile boolean rigHookObserved, rigEnforcedLogged;
    public static volatile int rigEnforcedFromTrack;
    /** Sub-models attached at these attachment names (the saddlebag stand-in)
     * are drawn on the wolf; every other human sub-model (hair, clothing) is hidden. */
    public static final String VISIBLE_ATTACHMENT_PREFIX = "WTAGarou_";
    /** Per-interval counters printed while a wolf is active, so a playtest
     * console shows WHERE the frame time goes instead of guessing. */
    public static final AtomicInteger perfPlays = new AtomicInteger(), perfDraws = new AtomicInteger(),
            perfHidden = new AtomicInteger(), perfSeating = new AtomicInteger(), perfSpots = new AtomicInteger();
    public static volatile int perfLiveTracksMax;
    private static volatile long perfWindowStart;
    private static volatile int perfBuiltAtWindowStart;
    public static final long PERF_INTERVAL_NANOS = 5_000_000_000L;
    private static volatile String lastStatus = "disabled";
    private static volatile String lastAssetStatus = "not checked";
    private static volatile String lastAssetSources = "";
    public static Object modelFor(Object character) { return WOLVES.get(character); }
    public static boolean active(Object character) { return character != null && WOLVES.containsKey(character); }
    public static boolean retainDyingWolf(Object character) {
        if (!active(character)) return false;
        try { return Boolean.TRUE.equals(Reflect.call(character,"isDead")); }
        catch (ReflectiveOperationException error) { return false; }
    }
    /** No animation reset or fake resurrection in a death callback. The native
     * graph finishes the wolf death; native corpse rendering supplies human dead. */
    public static boolean beforeCorpse(Object character) {
        if (!retainDyingWolf(character)) return false;
        CORPSE_HANDOFF.add(character);
        WOLVES.remove(character);
        DEFERRED_RESETS.remove(character);
        WTAGarouJava.clearScale(character);
        return true;
    }
    public static boolean corpseHandoff(Object character) { return CORPSE_HANDOFF.contains(character); }
    public static void afterCorpse(Object character) { CORPSE_HANDOFF.remove(character); }

    /** 0.4.59: ask the loader for the wolf model and its clips now, without
     *  registering any player, so the first Hispo/Lupus shift is not the
     *  moment the asynchronous load starts. "ready" | "pending" | "failed". */
    public static String preload() {
        try {
            Class<?> managerClass = Class.forName("zombie.core.skinnedmodel.ModelManager");
            Object manager = managerClass.getField("instance").get(null);
            Object model = Reflect.call(manager, "getLoadedModel", String.class, "WTAGarou_Lupus");
            WolfClipLoader.ensure(manager,model);
            WolfAssets.Check check=WolfAssets.inspect(model);
            if (!check.detail.equals(lastAssetStatus)) {
                lastAssetStatus=check.detail;
                lastAssetSources=check.ready ? "" : WolfAssets.sources();
                System.out.println("[WTAGarou Java][WolfAssets] "+lastAssetStatus);
                if (!lastAssetSources.isEmpty())
                    System.out.println("[WTAGarou Java][WolfAssets] "+lastAssetSources);
            }
            return check.ready ? "ready" : check.failed ? "failed" : "pending";
        } catch (ReflectiveOperationException | RuntimeException error) {
            warn("preload", error);
            return "failed";
        }
    }

    public static String setWolf(Object character, boolean enabled) {
        if (character == null) return "no player";
        if (!enabled) {
            if (WOLVES.remove(character) != null) { restoreAll(); rebuild(character); }
            lastStatus = "human requested; wolf is not registered for this player";
            return "human";
        }
        if (active(character)) return "wolf";
        try {
            // Ask the normal asset loader, then wait for its asynchronous load.
            Class<?> managerClass = Class.forName("zombie.core.skinnedmodel.ModelManager");
            Object manager = managerClass.getField("instance").get(null);
            Object model = Reflect.call(manager, "getLoadedModel", String.class, "WTAGarou_Lupus");
            WolfClipLoader.ensure(manager,model);
            WolfAssets.Check check=WolfAssets.inspect(model);
            if (!check.detail.equals(lastAssetStatus)) {
                lastAssetStatus=check.detail;
                lastAssetSources=check.ready ? "" : WolfAssets.sources();
                System.out.println("[WTAGarou Java][WolfAssets] "+lastAssetStatus);
                if (!lastAssetSources.isEmpty())
                    System.out.println("[WTAGarou Java][WolfAssets] "+lastAssetSources);
            }
            if (!check.ready) {
                lastStatus = check.failed ? "wolf asset failed; human body retained"
                        : "wolf assets pending; human body retained";
                return check.failed ? "failed" : "pending";
            }
            // Preflight critical player methods before changing any state.
            character.getClass().getMethod("resetModelNextFrame");
            Object animator = Reflect.call(character, "getAdvancedAnimator");
            animator.getClass().getMethod("OnAnimDataChanged", boolean.class);
            WOLVES.put(character, model);
            if (!rebuild(character)) {
                WOLVES.remove(character);
                rebuild(character);
                return "failed";
            }
            lastStatus = "wolf model registered; body normalization=" + BODY_SCALE;
            System.out.println("[WTAGarou Java] " + lastStatus);
            return "wolf";
        } catch (ReflectiveOperationException | RuntimeException error) {
            WOLVES.remove(character);
            warn("activation", error);
            return "failed";
        }
    }

    public static boolean ready(Object model) throws ReflectiveOperationException {
        return WolfAssets.inspect(model).ready;
    }
    private static boolean rebuild(Object character) {
        try {
            Reflect.call(character, "resetModelNextFrame");
            // OnPlayerDeath can run INSIDE AnimationMultiTrack.Update. Resetting
            // there releases the very track whose event callback we are inside.
            if (Boolean.TRUE.equals(Reflect.call(character, "isDead"))) {
                DEFERRED_RESETS.put(character, Boolean.TRUE);
                return true;
            }
            resetAnimData(character);
            return true;
        } catch (ReflectiveOperationException | RuntimeException error) {
            warn("rebuild", error);
            return false;
        }
    }
    /** 0.4.64: AdvancedAnimator.OnAnimDataChanged(false) nulls the root
     * layer state; the next animator update forces the "Idle" anim state
     * while the player's ActionContext stays in walk/run/sneak, so no
     * state-change callback fires and root-motion locomotion stops until
     * the key is released and pressed again. Vanilla only calls it next to
     * ActionContext.setGroup (checkActionGroup) or restores the state via
     * the private restoreAnimatorStateToActionContext. Do the same here. */
    public static void resetAnimData(Object character) throws ReflectiveOperationException {
        Object animator = Reflect.call(character, "getAdvancedAnimator");
        Reflect.call(animator, "OnAnimDataChanged", boolean.class, false);
        restoreAnimatorState(character, animator);
    }
    static boolean animatorRestoreObserved;
    public static void restoreAnimatorState(Object character, Object animator) {
        try {
            Object context = Reflect.call(character, "getActionContext");
            if (context == null || Reflect.call(context, "getCurrentState") == null) return;
            String stateName = (String) Reflect.call(context, "getCurrentStateName");
            if (stateName == null) return;
            List<String> children = new ArrayList<>();
            Object childStates = Reflect.call(context, "getChildStates");
            if (childStates instanceof List<?> list) {
                for (Object child : list) {
                    if (child == null) continue;
                    Object name = Reflect.call(child, "getName");
                    if (name != null) children.add(name.toString());
                }
            }
            Reflect.call(animator, "setState", new Class<?>[]{String.class, List.class}, stateName, children);
            animatorRestoreObserved = true;
        } catch (ReflectiveOperationException | RuntimeException error) {
            warn("animator state restore", error);
        }
    }
    /** ModelManager.update processes ResetNextFrame outside track iteration. */
    public static void beforeModelReset(Object character) {
        if (DEFERRED_RESETS.remove(character) == null) return;
        try {
            resetAnimData(character);
        } catch (ReflectiveOperationException | RuntimeException error) {
            warn("deferred death reset", error);
        }
    }

    /** Seating uses the model's clip table for HUMAN interaction offsets,
     * outside AnimationPlayer.play. Substitute query data only, not render
     * skeleton data, and never insert human clips into the wolf rig. */
    public static Object seatingData(Object data, Object node) {
        if (data == null || node == null || WOLVES.isEmpty()) return data;
        perfSeating.incrementAndGet();
        try {
            boolean wolfData = false;
            synchronized (WOLVES) {
                for (Object model : WOLVES.values()) {
                    if (Reflect.get(model, "tag") == data) { wolfData = true; break; }
                }
            }
            if (!wolfData) return data;
            Object name = Reflect.get(node, "animName");
            if (((Map<?,?>) Reflect.get(data, "animationClips")).containsKey(name)) return data;
            Object manager = Class.forName("zombie.core.skinnedmodel.ModelManager")
                    .getField("instance").get(null);
            Object human = Reflect.get(Reflect.get(manager, "maleModel"), "tag");
            Object bone = Reflect.call(node, "getDeferredBoneName");
            if (((Map<?,?>) Reflect.get(human, "animationClips")).get(name) != null
                    && ((Map<?,?>) Reflect.get(human, "boneIndices")).containsKey(bone)) {
                return human;
            }
        } catch (ReflectiveOperationException | RuntimeException error) {
            warn("seating data", error);
        }
        return data;
    }
    public static void clearAll() {
        Object[] characters;
        synchronized (WOLVES) { characters = WOLVES.keySet().toArray(); }
        for (Object character : characters) setWolf(character, false);
    }

    /** Remove HUMAN limb reparenting after vanilla has installed recorder and
     * character ownership. Only the fresh wolf AnimationPlayer is modified;
     * return to human allocates a fresh vanilla player through getBodyModel. */
    public static void configureRig(Object character, Object animationPlayer) {
        if (!active(character)) return;
        try {
            ((List<?>) Reflect.get(animationPlayer, "reparentedBoneBindings")).clear();
            ((List<?>) Reflect.get(animationPlayer, "twistBones")).clear();
            Reflect.set(animationPlayer, "counterRotationBone", null);
            if (!rigHookObserved) {
                rigHookObserved = true;
                System.out.println("[WTAGarou Java] wolf rig configured from onAnimPlayerCreated: "
                        + "human twist bones, limb reparenting and Bip01 counter-rotation removed");
            }
        } catch (ReflectiveOperationException | RuntimeException error) { warn("rig", error); }
    }

    /** Belt and braces for configureRig. The human twist chain
     * (Pelvis..Head, up to 70 degrees toward the target direction) and the
     * Bip01 counter-rotation (forces the root to the HUMAN rest yaw, a
     * quarter turn off the wolf's) are exactly the 0.4.11 symptoms: head
     * moving on its own, the body swinging round the origin while turning and
     * a 90-degree twist with a slow wobble during attacks. If the
     * onAnimPlayerCreated hook was missed or the player was re-initialised,
     * every track start re-checks and strips them again. Cheap: three field
     * reads when nothing needs doing. */
    public static boolean enforceRig(Object animationPlayer) throws ReflectiveOperationException {
        List<?> twist = (List<?>) Reflect.get(animationPlayer, "twistBones");
        List<?> reparent = (List<?>) Reflect.get(animationPlayer, "reparentedBoneBindings");
        Object counter = Reflect.get(animationPlayer, "counterRotationBone");
        if (twist.isEmpty() && reparent.isEmpty() && counter == null) return false;
        int twistCount = twist.size();
        twist.clear();
        reparent.clear();
        Reflect.set(animationPlayer, "counterRotationBone", null);
        rigEnforcedFromTrack++;
        if (!rigEnforcedLogged) {
            rigEnforcedLogged = true;
            System.out.println("[WTAGarou Java] wolf rig enforced from the track hook (twist bones="
                    + twistCount + " were present, counter-rotation=" + (counter != null)
                    + "); onAnimPlayerCreated hook observed=" + rigHookObserved);
        }
        return true;
    }

    /** Gait/idle clips never run on masked sub-layers (a head or upper-body
     * layer replaying Wolf_walk at its own phase is the "head moves on its
     * own" look); every other action (attack, hit reaction, eat, sit, death)
     * takes the WHOLE wolf body for its duration. */
    public static boolean isGaitClip(String clip) {
        String name = clip == null ? "" : clip.toLowerCase(Locale.ROOT);
        return name.equals("wolf_idle") || name.equals("wolf_walk") || name.startsWith("wolf_run");
    }
    private static volatile List<Object> fullBodyWeights;
    /** One AnimBoneWeight("Bip01", 1.0) with includeDescendants (the class
     * default), i.e. every skinned wolf bone; the unskinned Translation_Data
     * marker is NOT a Bip01 descendant, so the base layer keeps the movement. */
    public static List<Object> fullBodyWeights() throws ReflectiveOperationException {
        List<Object> cached = fullBodyWeights;
        if (cached != null) return cached;
        Object weight = Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimBoneWeight")
                .getConstructor(String.class, float.class).newInstance("Bip01", 1.0f);
        cached = Collections.singletonList(weight);
        fullBodyWeights = cached;
        return cached;
    }
    /** Sub-layer masks: gait/idle inert, masked actions full body.
     * AnimationPlayer ignores these weights for actual root layers. */
    /** 0.4.69: an authored Wolf_howl is head-only by design (neck, head, jaw
     *  keyed; the exporter samples every other bone at rest). Played with
     *  the full-body action weights it would freeze the legs, so the howl
     *  track is masked to Bip01_Neck and its descendants (Head, Jaw, Ears)
     *  and the gait layer keeps the rest. The Wolf_eat fallback keeps the
     *  confirmed full-body behaviour. */
    public static Object howlWeights(String baseClip, boolean howling, Object weights) throws ReflectiveOperationException {
        if (howling && "Wolf_howl".equals(baseClip)) return HowlMaskRuntime.headNeckWeights();
        return weights;
    }

    public static Object layerWeights(Object source, Object skin, String clip) throws ReflectiveOperationException {
        // Root layers ignore this parameter in AnimationPlayer.play. Empty
        // source masks do not imply a root: carry/aim sublayers can have one.
        if (isGaitClip(clip)) return new ArrayList<>();
        if (!(source instanceof List<?> list) || list.isEmpty()) return source;
        return fullBodyWeights();
    }

    /** Perf window: counts per ~5 s while any wolf is registered. */
    public static void perfFrame(Object animationPlayer) {
        long now = System.nanoTime();
        long start = perfWindowStart;
        if (start == 0) { perfWindowStart = now; perfBuiltAtWindowStart = WolfPlayerClips.built; return; }
        if (now - start < PERF_INTERVAL_NANOS) return;
        perfWindowStart = now;
        double seconds = (now - start) / 1e9;
        int plays = perfPlays.getAndSet(0), draws = perfDraws.getAndSet(0), hidden = perfHidden.getAndSet(0),
            seating = perfSeating.getAndSet(0), spots = perfSpots.getAndSet(0);
        int builtNow = WolfPlayerClips.built, builtDelta = builtNow - perfBuiltAtWindowStart;
        perfBuiltAtWindowStart = builtNow;
        int tracks = perfLiveTracksMax; perfLiveTracksMax = 0;
        System.out.println(String.format(Locale.ROOT,
                "[WTAGarou Java][Perf] %.1fs: wolf draws=%d (%.0f/s) hidden submodel draws=%d (%.0f/s) "
                + "track starts=%d (%.1f/s) live tracks max=%d derived clips built=%d seating lookups=%d "
                + "spot checks=%d rig enforcements=%d saddlebag retargets=%d mouth-carry retargets=%d slot retargets=%d scale recompensations=%d",
                seconds, draws, draws / seconds, hidden, hidden / seconds, plays, plays / seconds, tracks,
                builtDelta, seating, spots, rigEnforcedFromTrack, perfSaddlebagBone.getAndSet(0), perfMouthCarry.getAndSet(0),
                perfSlot.getAndSet(0), perfRecompensated.getAndSet(0)));
    }

    /** 0.4.24: optional wolf clips the author can add to
     * common/media/anims_X/WTAGarouWolf/ and the packaged clip each falls
     * back to until it exists. preferredClipFor names them; resolveClip walks
     * the chain against the loaded clip map. docs/WOLF_ANIMATION_LIST.md. */
    public static final Map<String,String> OPTIONAL_FALLBACK = Map.ofEntries(
        Map.entry("Wolf_idle_crouch","Wolf_idle"),   // sneak/crouch idle (was Wolf_walk: "walks in place")
        Map.entry("Wolf_sneak","Wolf_walk"),         // sneak walk
        Map.entry("Wolf_trot","Wolf_walk"),          // author-planned
        Map.entry("Wolf_gallop","Wolf_run"),         // author-planned
        Map.entry("Wolf_strafe","Wolf_walk"),        // sideways step (Bob_Strafe*)
        Map.entry("Wolf_walk_back","Wolf_walk"),     // backing up
        Map.entry("Wolf_turn","Wolf_walk"),          // turn in place (IdleToWalk180, WalkToTurn180)
        Map.entry("Wolf_run_stop","Wolf_run"),       // RunToStop
        Map.entry("Wolf_Sit_idle","Wolf_Sit"),       // held sit loop (Wolf_Sit is the sit-down motion)
        Map.entry("Wolf_getup","Wolf_idle"),         // stand up from sit / knockdown
        Map.entry("Wolf_climb","Wolf_idle"),         // fence / window / vault
        Map.entry("Wolf_fall","Wolf_hitreaction"),   // knockdown / fall
        Map.entry("Wolf_drink","Wolf_eat"),
        Map.entry("Wolf_attack_run","Wolf_attack"),  // attack while moving
        Map.entry("Wolf_howl","Wolf_eat"));          // the howl action plays the Drink node
    /** Lua WTAGarouHowlAction sets WTAGarou_Howling for the whole howl. */
    public static boolean isHowling(Object character) {
        try { return Boolean.TRUE.equals(Reflect.call(character,"getVariableBoolean",String.class,"WTAGarou_Howling")); }
        catch (ReflectiveOperationException | RuntimeException e) { return false; }
    }
    public static String resolveClip(String clip, Map<?,?> clips) {
        for (int guard=0; clip != null && !clips.containsKey(clip) && OPTIONAL_FALLBACK.containsKey(clip) && guard < 6; guard++)
            clip = OPTIONAL_FALLBACK.get(clip);
        return clip;
    }
    /** Packaged (always present) clip for a human node name. */
    public static String clipFor(String requested) {
        return resolveClip(preferredClipFor(requested), Collections.emptyMap());
    }
    /** Optional-first clip for a human node name (see OPTIONAL_FALLBACK). */
    public static String preferredClipFor(String requested) {
        String name = requested == null ? "" : requested.toLowerCase(Locale.ROOT);
        if (name.startsWith("wolf_")) return requested;
        // Death/reaction priority matters: Bob_SitGround_EndDeath is not a get-up.
        if (name.contains("death") || name.contains("dying")) return "Wolf_death";
        // 0.4.40: corpse pickup / lay-down is the head-down Wolf_eat pose
        // (October 5 playtest: it fell through to Wolf_idle).
        if (WolfPlayerClips.corpseHandling(requested)) return WolfPlayerClips.corpsePose(requested);
        if (name.contains("sit") && (name.contains("getup") || name.contains("stand")
                || name.contains("toidle") || name.contains("exit") || name.contains("end")
                || name.contains("sitground_out") || name.contains("sitonground_out")))
            return "Wolf_getup";
        if (name.contains("dead") || (name.contains("onground") && !name.contains("sit"))) return "Wolf_dead";
        // Match attack before hit reaction: Bob_Attack..._Hit is an attack.
        if (name.contains("attack") || name.contains("shove") || name.contains("stomp")
                || name.contains("stamp")) return "Wolf_attack";
        // 0.4.20: the zombie bite/grab reactions (PlayerHitReactionState,
        // hitReaction=Bite) do not carry "hitreaction" in every clip name; the
        // September 26 playtest froze a Hispo in that state until the 4 s
        // Wolf_idle fallback ran out. Every reaction-type name maps to the
        // short wolf flinch, and unknown names are logged once each.
        if (name.contains("hitreaction") || name.contains("hitreact") || name.contains("bump")
                || name.contains("bite") || name.contains("bitten") || name.contains("grab")
                || name.contains("react") || name.contains("defend") || name.contains("stagger")
                || name.contains("knock") || name.contains("shot") || name.contains("hit")) return "Wolf_hitreaction";
        if (name.contains("satchair")) return "Wolf_Sit_idle";
        if (name.contains("sit") || name.contains("seated")) {
            if (name.contains("getup") || name.contains("stand") || name.contains("toidle")) return "Wolf_getup";
            if (name.contains("idle") || name.contains("loop")) return "Wolf_Sit_idle";
            return "Wolf_Sit";
        }
        if (name.contains("getup")) return "Wolf_getup";
        if (name.contains("climb") || name.contains("vault") || name.contains("window") || name.contains("fence")) return "Wolf_climb";
        if (name.contains("fall") || name.contains("collapse")) return "Wolf_fall";
        if (name.contains("drink")) return "Wolf_drink";
        // "Breathing" contains "eat"; exhausted idle is NOT eating.
        if (name.contains("eat") && !name.contains("breath")) return "Wolf_eat";
        // 0.4.24: an IDLE node is an idle whatever else its name says
        // (Bob_SneakIdle / Bob_IdleCrouch used to fall into Wolf_walk and
        // "walk in place"); IdleToX transitions are not idles.
        boolean transition = WolfPlayerClips.isTransition(requested);
        if (name.contains("idle") && !transition)
            return (name.contains("sneak") || name.contains("crouch")) ? "Wolf_idle_crouch" : "Wolf_idle";
        if (name.contains("stop")) return "Wolf_run_stop";
        if (name.contains("turn") || name.contains("180")) return "Wolf_turn";
        if (name.contains("sprint")) return "Wolf_run_fourx";
        if (name.contains("run") || name.contains("jog")) return "Wolf_run";
        if (name.contains("strafe")) return "Wolf_strafe";
        if (isBackwardWalk(name)) return "Wolf_walk_back";
        if (name.contains("sneak") || name.contains("crouch")) return "Wolf_sneak";
        if (name.contains("walk")) return "Wolf_walk";
        if (!name.contains("idle") && requested != null && IDLE_FALLBACK_LOGGED.add(requested)
                && IDLE_FALLBACK_LOGGED.size() <= 24)
            System.out.println("[WTAGarou Java] wolf clip fallback: '" + requested + "' -> Wolf_idle");
        return "Wolf_idle";
    }
    /** 0.4.64: a human walk-backwards node (Bob_WalkBwdAim is the one the
     * strafe state plays when backing up; "back"+"walk" for any other name). */
    public static boolean isBackwardWalk(String lowerName) {
        if (lowerName == null) return false;
        String name = lowerName.toLowerCase(Locale.ROOT);
        if (!name.contains("walk")) return false;
        return name.contains("bwd") || name.contains("back");
    }
    /** 0.4.64: play the wolf gait in reverse for this human node when no
     * authored Wolf_walk_back exists (the wolf used to
     * trot forwards while sliding backwards). An authored clip plays as is. */
    public static boolean reverseForBackwardWalk(String requested, String resolvedClip) {
        if (requested == null || resolvedClip == null) return false;
        if (!isBackwardWalk(requested)) return false;
        return !"Wolf_walk_back".equals(resolvedClip) && isLocomotionClip(resolvedClip);
    }
    /** Human clip names that fell through to Wolf_idle (logged once each). */
    private static final Set<String> IDLE_FALLBACK_LOGGED = ConcurrentHashMap.newKeySet();
    /**
     * Gait comes from the requested human clip name ONLY. IsoPlayer.isRunning()
     * is the run KEY state: it is true while aiming, strafing or standing with
     * the key (or run toggle) held, so the 0.4.9 flag upgrade played the run
     * pose over walk-speed movement ("walking with the run animation").
     * The derived clip is stride-matched to the human clip's speed, so a
     * walk-named clip always cycles the paws at walking pace.
     */
    public static String gaitFor(Object character,String requested) {
        return clipFor(requested);
    }
    /** Locomotion cycles (not idle) whose pose may be reversed for a corpse drag. */
    public static boolean isLocomotionClip(String wolfName) {
        return "Wolf_walk".equals(wolfName) || "Wolf_run".equals(wolfName) || "Wolf_run_fourx".equals(wolfName)
                || "Wolf_sneak".equals(wolfName) || "Wolf_trot".equals(wolfName) || "Wolf_strafe".equals(wolfName)
                || "Wolf_walk_back".equals(wolfName);
    }

    public static final class SavedTrack {
        final Object params;
        final String name;
        final Object weights;
        final String bone;
        final Object deferredRotation;
        final Object axis, ragdoll;
        final Object reversed, looped;
        SavedTrack(Object params) throws ReflectiveOperationException {
            this.params=params;
            name=(String)Reflect.get(params,"animName");
            weights=Reflect.get(params,"subLayerBoneWeights");
            bone=(String)Reflect.get(params,"deferredBoneName");
            deferredRotation=Reflect.get(params,"useDeferredRotation");
            axis=Reflect.get(params,"deferredBoneAxis");
            ragdoll=Reflect.get(params,"isRagdoll");
            reversed=Reflect.get(params,"isReversed");
            looped=Reflect.get(params,"isLooped");
        }
    }
    private static final Set<String> CORPSE_POSE_LOGS = java.util.concurrent.ConcurrentHashMap.newKeySet();
    public static Object beginTrack(Object player, Object params) {
        // play also has String overloads. Do not modify them or double-map.
        if (WOLVES.isEmpty() || params == null || params instanceof String) return null;
        SavedTrack saved = null;
        try {
            Object character=Reflect.call(player,"getIsoGameCharacter");
            if (!active(character)) return null;
            perfPlays.incrementAndGet();
            try { enforceRig(player); }
            catch (ReflectiveOperationException | RuntimeException error) { warn("rig-enforce", error); }
            try {
                Object entries=Reflect.get(player,"liveAnimationTrackEntries");
                int count=((Number)Reflect.call(entries,"count")).intValue();
                if (count>perfLiveTracksMax) perfLiveTracksMax=count;
            } catch (ReflectiveOperationException | RuntimeException ignored) {}
            saved=new SavedTrack(params);
            String clip=gaitFor(character,saved.name);
            Object data=Reflect.call(player,"getSkinningData");
            Map<?,?> clips=(Map<?,?>)Reflect.get(data,"animationClips");
            if (retainDyingWolf(character)) clip="Wolf_death";
            // 0.4.24: an optional authored clip replaces the packaged one it
            // falls back to, when the human node maps there.
            String preferred=preferredClipFor(saved.name);
            if (!preferred.equals(clip) && clipFor(saved.name).equals(clip)) clip=resolveClip(preferred,clips);
            // Ground sit uses forceGetUp even when the clip name is still the
            // sit node. Do not apply this flag to unrelated attack/death clips.
            if (("Wolf_Sit".equals(clip) || "Wolf_Sit_idle".equals(clip)) && clips.containsKey("Wolf_getup")) {
                try {
                    if (Boolean.TRUE.equals(Reflect.call(character,"getVariableBoolean",String.class,"forceGetUp")))
                        clip="Wolf_getup";
                } catch (ReflectiveOperationException ignored) {}
            }
            // Native get-up may reuse the sit-down node in reverse. Our
            // get-up asset is ALREADY reversed; never reverse it a second time.
            if ("Wolf_Sit".equals(clip) && Boolean.TRUE.equals(saved.reversed)
                    && clips.containsKey("Wolf_getup")) clip="Wolf_getup";
            if ("Wolf_getup".equals(clip) || "Wolf_Sit".equals(clip)) {
                Reflect.set(params,"isReversed",false);
                Reflect.set(params,"isLooped",false);
            }
            // 0.4.69: the howl action plays the Drink node; while the Lua howl
            // variable is up an authored Wolf_howl replaces the eat pose
            // (OPTIONAL_FALLBACK keeps Wolf_eat until that clip exists).
            if (("Wolf_eat".equals(clip) || "Wolf_drink".equals(clip)) && isHowling(character))
                clip=resolveClip("Wolf_howl",clips);
            if (clip.equals("Wolf_run_fourx") && !clips.containsKey(clip)) clip="Wolf_run";
            if (!clips.containsKey(clip)) clip="Wolf_idle";
            if (!clips.containsKey(clip)) throw new IllegalStateException("Wolf_idle clip absent");
            float renderScale=WTAGarouJava.scaleFor(character)*BODY_SCALE;
            String baseClip=clip;
            // 0.4.40: corpse handling = a pickup/lay-down/throw clip, or any
            // clip while the wolf is dragging / throwing a body. Dragging
            // plays a gait with the wolf's pose reversed (walking backwards).
            boolean corpseClip=WolfPlayerClips.corpseHandling(saved.name);
            boolean dragging=WolfGrappleRuntime.isDragging(character);
            // 0.4.44: a body just thrown into a trunk / seat / trailer: the
            // deposit clip (name unknown, no corpse noun) is corpse handling
            // too, played as the idle pose (Oct 6: "dropping corpses into a
            // trunk or trailer ... causes the weird reference point rotation").
            boolean thrownClip=!corpseClip && !isLocomotionClip(baseClip)
                    && WolfGrappleRuntime.recentThrow(character,3.0d);
            if (thrownClip) {
                corpseClip=true;
                clip=resolveClip("Wolf_idle",clips);
                baseClip=clip;
                if (!clips.containsKey(clip)) throw new IllegalStateException("Wolf_idle clip absent");
            }
            boolean corpse=corpseClip || dragging || WolfGrappleRuntime.isThrowing(character);
            boolean reversePose=(dragging && !corpseClip && isLocomotionClip(baseClip))
                    || (!corpseClip && !dragging && reverseForBackwardWalk(saved.name,baseClip));
            if (dragging) WolfGrappleRuntime.logDragClip(saved.name,baseClip,reversePose);
            if (corpseClip) WolfGrappleRuntime.markCorpseClip(character,saved.name);
            else WolfGrappleRuntime.clearCorpseClip(character);
            String adapted=WolfPlayerClips.adapt(data,saved.name,clip,saved.bone,renderScale,reversePose,thrownClip);
            boolean playerMotion=!adapted.equals(clip);
            clip=adapted;
            Reflect.set(params,"animName",clip);
            // Root layer: pass through. Sub-layer: inert for gaits, whole
            // body for actions (see layerWeights). The 0.4.11 per-bone filter
            // let human head/upper-body layers replay wolf gaits on the
            // wolf's same-named bones, out of phase with the base layer.
            Reflect.set(params,"subLayerBoneWeights",howlWeights(baseClip,isHowling(character),
                    WolfAttackMasks.weightsFor(character, baseClip, layerWeights(saved.weights,data,baseClip))));
            // Human parity: the deferred bone, axis and rotation flag stay
            // exactly what the human node asked for. The derived clip carries
            // the human marker keyframes on the wolf's marker of the same
            // name, and the wolf's skinned Bip01 root is held in place, so
            // nothing here needs to be re-pointed at the skin root. (Pointing
            // the deferred bone at Bip01 was 0.4.9's remaining rubber band:
            // the engine's Y-axis counter-position ADDS the marker's z.)
            if (retainDyingWolf(character)) Reflect.set(params,"isRagdoll",false);
            if (!playerMotion) {
                // Raw wolf clip fallback (human clip absent): its marker has a
                // constant rotation, so animation-driven turning must stay off
                // or the player's input/path facing is suppressed.
                Reflect.set(params,"useDeferredRotation",false);
                if (WolfPlayerClips.furnitureRoot(saved.name, saved.bone)) {
                    Map<?,?> bones=(Map<?,?>)Reflect.get(data,"boneIndices");
                    if (bones.containsKey("Translation_Data"))
                        Reflect.set(params,"deferredBoneName","Translation_Data");
                }
            }
            // 0.4.40: a stationary corpse action (pickup, lay-down, drop into
            // a trunk) must not turn the wolf through the human clip's
            // deferred rotation: the body spun on the reference point when a
            // Lupus/Hispo dropped a corpse into a vehicle. Gaits while
            // dragging keep the human marker (direction, speed, turning).
            if (corpseClip || (corpse && !isLocomotionClip(baseClip))) {
                Reflect.set(params,"useDeferredRotation",false);
                Map<?,?> bones=(Map<?,?>)Reflect.get(data,"boneIndices");
                if (bones.containsKey("Translation_Data"))
                    Reflect.set(params,"deferredBoneName","Translation_Data");
                if (CORPSE_POSE_LOGS.size()<16 && CORPSE_POSE_LOGS.add(saved.name))
                    System.out.println("[WTAGarou Java] corpse handling pose guarded: "+saved.name
                            +"; original marker="+saved.bone+"; wolf pose="+baseClip+" ("+clip+"); deferred rotation off");
            }
            if (!trackHookObserved) {
                trackHookObserved=true;
                System.out.println("[WTAGarou Java] wolf track adapter reached: "+saved.name+" -> "+clip);
            }
            return saved;
        } catch (ReflectiveOperationException | RuntimeException error) {
            endTrack(saved);
            warn("track",error);
            return null;
        }
    }
    public static void endTrack(Object state) {
        if (!(state instanceof SavedTrack)) return;
        SavedTrack s=(SavedTrack)state;
        try {
            Reflect.set(s.params,"animName",s.name);
            Reflect.set(s.params,"subLayerBoneWeights",s.weights);
            Reflect.set(s.params,"deferredBoneName",s.bone);
            Reflect.set(s.params,"useDeferredRotation",s.deferredRotation);
            Reflect.set(s.params,"deferredBoneAxis",s.axis);
            Reflect.set(s.params,"isRagdoll",s.ragdoll);
            Reflect.set(s.params,"isReversed",s.reversed);
            Reflect.set(s.params,"isLooped",s.looped);
        } catch (ReflectiveOperationException | RuntimeException error) { warn("track restore",error); }
    }

    /** Bone the saddlebag stand-in hangs from. The body ModelInstance keeps
     * the MaleBody/FemaleBody model script under the direct wolf, so the
     * WTAGarou_ attachment is never found on the parent and the engine falls
     * back to parentBoneName (AnimatedModel.transformToParent). */
    public static final String SADDLEBAG_BONE = "Bip01_Spine2";
    /** Primary-hand item bone while a wolf (experimental mouth carry). */
    public static final String MOUTH_BONE = "Bip01_Jaw";
    public static volatile boolean mouthCarry = true;
    public static final AtomicLong perfMouthCarry = new AtomicLong(), perfSaddlebagBone = new AtomicLong();
    /** 0.4.20 bounded saddlebag retarget diagnostics (see ScaleRuntime hook). */
    static final AtomicLong SADDLEBAG_LOGS = new AtomicLong();

    /** Attachment name that no human body script defines, so the engine's
     * transformToParent falls through to parentBoneName (Bip01_Jaw) instead
     * of resolving the MaleBody "Bip01_Prop1" attachment to a bone the wolf
     * rig does not have. Deliberately NOT prefixed WTAGarou_ (that prefix
     * marks the saddlebag attachments that are drawn on the spine). */
    public static final String MOUTH_ATTACHMENT = "GarouJaw";
    /** attachmentNameParent before the jaw override (weak; restored when the wolf is gone). */
    private static final Map<Object,Object> MOUTH_ORIGINAL_ATTACHMENT = Collections.synchronizedMap(new WeakHashMap<>());
    /** Extra rotation (degrees) / offset (metres) for the jaw-carried item,
     * applied after the engine transform in the item's local space. Set from
     * Lua (WTAGarou.MouthCarry) through WTAGarouJava.setMouthCarryTransform. */
    public static volatile float mouthRotX = 0f, mouthRotY = 90f, mouthRotZ = 0f;
    public static volatile float mouthOffX = 0f, mouthOffY = 0f, mouthOffZ = 0f;
    /** Sub-models currently drawn from the jaw (weak; instances are rebuilt). */
    private static final Set<Object> MOUTH_INSTANCES = Collections.newSetFromMap(new WeakHashMap<>());
    public static boolean isMouthCarried(Object instance) {
        return instance != null && MOUTH_INSTANCES.contains(instance);
    }
    /** 0.4.22: extra rotation (degrees) / offset (metres, item local space)
     * for the saddlebag stand-in, applied after the engine transform exactly
     * like the jaw item. Set from Lua (WTAGarou.Saddlebag) through
     * WTAGarouJava.setSaddlebagTransform, so the bags can be tuned from
     * Definitions without a Java rebuild or a game restart. */
    public static volatile float saddleRotX = 0f, saddleRotY = 0f, saddleRotZ = 0f;
    public static volatile float saddleOffX = 0f, saddleOffY = 0f, saddleOffZ = 0f;
    /** 0.4.23: extra uniform scale on the saddlebag (WTAGarou.Saddlebag.scale). */
    public static volatile float saddleScale = 1f;
    /** Sub-models currently drawn as the saddlebag (weak). */
    private static final Set<Object> SADDLEBAG_INSTANCES = Collections.newSetFromMap(new WeakHashMap<>());
    public static boolean isSaddlebag(Object instance) {
        return instance != null && SADDLEBAG_INSTANCES.contains(instance);
    }
    /** Skinned harness carrier. Unlike bags/cargo, never pinned to a bone.
     * Legacy transform fields/API remain binary-compatible but are unused. */
    public static final String HARNESS_ATTACHMENT = "WTAGarou_Harness";
    public static volatile float harnessRotX = 0f, harnessRotY = 0f, harnessRotZ = 0f;
    public static volatile float harnessOffX = 0f, harnessOffY = 0f, harnessOffZ = 0f;
    public static volatile float harnessScale = 1f;
    public static final Map<String,float[]> ATTACHMENT_PIVOTS = new java.util.concurrent.ConcurrentHashMap<>();
    /** Import units affect bag tuning offsets, not the authored mesh size. */
    public static float bagImportUnits(Object instance) {
        try {
            Object mesh=Reflect.get(Reflect.get(instance,"model"),"mesh");
            Object matrix=mesh == null ? null : Reflect.get(mesh,"transform");
            if (matrix == null) return 1f;
            float x=((Number)Reflect.get(matrix,"m00")).floatValue();
            float y=((Number)Reflect.get(matrix,"m01")).floatValue();
            float z=((Number)Reflect.get(matrix,"m02")).floatValue();
            float units=(float)Math.sqrt(x*x+y*y+z*z);
            return Float.isFinite(units) && units>0.0001f ? units : 1f;
        } catch (ReflectiveOperationException | RuntimeException ignored) { return 1f; }
    }
    private static final Set<Object> HARNESS_INSTANCES = Collections.newSetFromMap(new WeakHashMap<>());
    public static boolean isHarness(Object instance) {
        return instance != null && HARNESS_INSTANCES.contains(instance);
    }
    /** 0.4.23 wolf slots: hotbar / secondary-hand sub-models drawn on the
     * wolf instead of hidden. A rule is keyed by the sub-model's
     * attachmentNameParent (the location's attachment name, e.g. what the
     * "Back" hotbar location maps to) or by the pseudo key "secondary" for
     * the secondary-hand model. The item is re-parented to {@code bone}, its
     * parent attachment renamed so the human body attachment is skipped
     * (engine falls through to parentBoneName, like the jaw), and the
     * post-transform below places it: {@code off*} pre-multiplied
     * (character space, Y up; scales with the body), {@code rot*} in the
     * item's own space. Rules come from WTAGarou.WolfSlots via
     * WTAGarouJava.setWolfSlot. Unknown attachments stay hidden and are
     * logged once each so the real names can be added to Definitions. */
    public static final class SlotRule {
        public final String key, bone;
        public final float rotX, rotY, rotZ, offX, offY, offZ;
        /** 0.4.24: the grip point on the item (item space). The mesh is shifted
         * by -pivot after its rotation so this point sits on the mount and the
         * item turns about it, instead of about its handle-tip origin. */
        public final float pivotX, pivotY, pivotZ;
        public SlotRule(String key, String bone, float rotX, float rotY, float rotZ, float offX, float offY, float offZ) {
            this(key, bone, rotX, rotY, rotZ, offX, offY, offZ, 0f, 0f, 0f);
        }
        public SlotRule(String key, String bone, float rotX, float rotY, float rotZ, float offX, float offY, float offZ,
                        float pivotX, float pivotY, float pivotZ) {
            this.key=key; this.bone=bone; this.rotX=rotX; this.rotY=rotY; this.rotZ=rotZ;
            this.offX=offX; this.offY=offY; this.offZ=offZ; this.pivotX=pivotX; this.pivotY=pivotY; this.pivotZ=pivotZ;
        }
        public boolean hasPivot() { return pivotX!=0f || pivotY!=0f || pivotZ!=0f; }
        public boolean identity() { return rotX==0f && rotY==0f && rotZ==0f && offX==0f && offY==0f && offZ==0f && !hasPivot(); }
        @Override public String toString() {
            return String.format(Locale.ROOT,"%s -> %s rot(%.1f,%.1f,%.1f) off(%.3f,%.3f,%.3f)%s",key,bone,rotX,rotY,rotZ,offX,offY,offZ,
                    hasPivot()?String.format(Locale.ROOT," pivot(%.3f,%.3f,%.3f)",pivotX,pivotY,pivotZ):"");
        }
    }
    public static final String SECONDARY_SLOT_KEY = "secondary";
    public static final String SLOT_ATTACHMENT_PREFIX = "GarouSlot_";
    public static volatile boolean slotsEnabled = true;
    private static final Map<String,SlotRule> SLOT_RULES = new java.util.concurrent.ConcurrentHashMap<>();
    /** Sub-models currently drawn under a slot rule (weak). */
    private static final Map<Object,SlotRule> SLOT_INSTANCES = Collections.synchronizedMap(new WeakHashMap<>());
    public static SlotRule slotRuleFor(Object instance) { return instance == null ? null : SLOT_INSTANCES.get(instance); }
    public static boolean isSlotItem(Object instance) { return instance != null && SLOT_INSTANCES.containsKey(instance); }
    public static void setSlotRule(SlotRule rule) { if (rule != null) SLOT_RULES.put(rule.key.toLowerCase(Locale.ROOT), rule); }
    public static void clearSlotRules() { SLOT_RULES.clear(); }
    public static SlotRule slotRule(String key) {
        if (key == null) return null;
        String k=key.toLowerCase(Locale.ROOT);
        SlotRule exact=SLOT_RULES.get(k);
        if (exact != null) return exact;
        if (k.equals("wrench_left") || k.equals("meatcleaver_left")) return SLOT_RULES.get("belt_left");
        if (k.equals("wrench_right") || k.equals("meatcleaver_right")) return SLOT_RULES.get("belt_right");
        // 0.4.24: the engine names the attachment per item type as well
        // ("shovel_back", "bag_back" ... for the Back location; the
        // September 27 console showed shovel_back). A rule for "back" covers
        // every "<type>_back"; the longest matching suffix wins.
        SlotRule best=null;
        for (Map.Entry<String,SlotRule> e : SLOT_RULES.entrySet()) {
            String rk=e.getKey();
            if (rk.equals(SECONDARY_SLOT_KEY)) continue;
            if ((k.endsWith("_"+rk) || k.startsWith(rk+"_"))
                    && (best == null || rk.length() > best.key.length())) best=e.getValue();
        }
        return best;
    }
    /** Attachment names of sub-models hidden on the wolf (bounded, for the
     * Status button / console: these are the keys WTAGarou.WolfSlots needs). */
    static final Set<String> HIDDEN_ATTACHMENTS = java.util.concurrent.ConcurrentHashMap.newKeySet();
    static final AtomicLong SLOT_LOGS = new AtomicLong();
    public static final AtomicLong perfSlot = new AtomicLong();
    public static final AtomicLong perfSlotErrors = new AtomicLong();
    public static String slotStatus() {
        return "slots enabled=" + slotsEnabled + " rules=" + SLOT_RULES.values()
                + " hiddenAttachments=" + HIDDEN_ATTACHMENTS + " drawn=" + perfSlot.get()
                + " recompensations=" + perfRecompensated.get() + " slotErrors=" + perfSlotErrors.get();
    }
    /** ModelInstance.scale before the 1/BODY_SCALE compensation (weak). */
    private static final Map<Object,Float> COMPENSATED = Collections.synchronizedMap(new WeakHashMap<>());
    /** The compensated value we last wrote (weak). 0.4.22: the engine pools
     * ModelInstances and resets their scale from the model script when it
     * reuses one (re-wearing a bag, sleeping, a model reset), and the old
     * "compensate once per instance" rule then left the bags at script scale
     * x FinalScale = 0.36 - the "tiny saddlebags" of the September 27
     * playtest. Now a mismatch between the current scale and the value we
     * wrote means the engine reset it, and it is compensated again. */
    private static final Map<Object,Float> COMPENSATED_TO = Collections.synchronizedMap(new WeakHashMap<>());
    public static final AtomicLong perfRecompensated = new AtomicLong();
    /** parentBoneName before a retarget (weak). 0.4.20: ModelInstances are
     * pooled and reused by the engine, so a jaw/spine retarget could outlive
     * the wolf on an instance that was never rebuilt. */
    private static final Map<Object,Object> RETARGET_ORIGINAL_BONE = Collections.synchronizedMap(new WeakHashMap<>());
    /** Restore every compensated / retargeted sub-model at once (wolf cleared). */
    static void restoreAll() {
        WolfHarness.restoreAll();
        List<Object> pending=new ArrayList<>();
        pending.addAll(HARNESS_INSTANCES);
        synchronized (COMPENSATED) { pending.addAll(COMPENSATED.keySet()); }
        synchronized (RETARGET_ORIGINAL_BONE) { pending.addAll(RETARGET_ORIGINAL_BONE.keySet()); }
        synchronized (MOUTH_ORIGINAL_ATTACHMENT) { pending.addAll(MOUTH_ORIGINAL_ATTACHMENT.keySet()); }
        for (Object instance:pending) restoreScale(instance);
    }
    public static final AtomicLong perfCompensated = new AtomicLong();

    /** Is this sub-model attached (directly or through another sub-model) to
     * the character's wolf body? */
    public static boolean attachedToWolf(Object instance, Object character) {
        Object wolf=modelFor(character);
        if (wolf == null || instance == null) return false;
        try {
            Object parent=Reflect.get(instance,"parent");
            for (int depth=0; parent != null && depth < 4; depth++) {
                if (Reflect.get(parent,"model") == wolf) return true;
                parent=Reflect.get(parent,"parent");
            }
        } catch (ReflectiveOperationException | RuntimeException ignored) {}
        return false;
    }
    /** Bake body-space scale into top-level STATIC gear matrices, not FinalScale:
     * 42.21 DrawSolid's instanced path does not call Shader.setScale.
     * Skinned harness follows the body via ScaleRuntime, not static xfrm.
     * Descendant weapon parts inherit the matrix and must NOT scale twice. */
    public static void bakeSubmodelScale(Object data, Object parentData) {
        if (data == null || parentData == null) return;
        try {
            Object parent=Reflect.get(parentData,"modelInstance");
            if (parent == null) return;
            Object character=Reflect.get(parent,"character");
            Object wolf=modelFor(character);
            if (wolf == null || Reflect.get(parent,"model") != wolf) return;
            Object instance=Reflect.get(data,"modelInstance");
            if (isHarness(instance)) return;
            if (!isSaddlebag(instance)
                    && !isSlotItem(instance) && !isMouthCarried(instance)) return;
            Object matrix=Reflect.get(data,"xfrm");
            Reflect.call(matrix,"transpose");
            Reflect.call(matrix,"scaleLocal",float.class,BODY_SCALE*WTAGarouJava.scaleFor(character));
            Reflect.call(matrix,"transpose");
        } catch (ReflectiveOperationException | RuntimeException error) { warn("attachment matrix scale",error); }
    }
    /** ShaderPropertyBlock.SetMatrix4 COPIES xfrm. init() calls it before
     * transformToParent, so instanced gear otherwise draws the old matrix. */
    public static void publishSubmodelTransform(Object data) {
        try {
            Object instance=Reflect.get(data,"modelInstance");
            Object parent=instance == null ? null : Reflect.get(instance,"parent");
            if (parent == null) return;
            if (!isSaddlebag(instance) && !isHarness(instance)
                    && !isSlotItem(instance) && !isMouthCarried(instance)
                    && !isSlotItem(parent) && !isMouthCarried(parent)) return;
            Object properties=Reflect.get(data,"properties");
            if (properties == null) return;
            Object matrix=Reflect.get(data,"xfrm");
            Reflect.call(properties,"SetMatrix4",new Class<?>[]{String.class,matrix.getClass()},"transform",matrix);
        } catch (ReflectiveOperationException | RuntimeException error) { warn("attachment shader transform",error); }
    }
    /** The top-level matrix scales wolf bone space by BODY_SCALE. Mesh-local
     * compensation restores authored item size, and for cargo cancels form
     * scale too. Never depend on the instanced shader's FinalScale uniform. */
    /** 0.4.24: the engine only ever writes ModelInstance.scale from the
     * model script (applyModelScriptScale) or resets it to 1 (pool reset),
     * so the base value is read from the script, never from the current
     * field. The old "compare with what we wrote" rule could compound
     * (script -> ours -> ours/0.6) when a pooled instance changed model
     * under us: the September 27 "jumbo" belt items that shrank again after
     * a hand-equip refresh. Now target = script scale / BODY_SCALE, always. */
    static float scriptScale(Object instance, float current) {
        try {
            Object script=Reflect.get(instance,"modelScript");
            if (script != null) {
                Object s=Reflect.get(script,"scale");
                if (s instanceof Float f && f > 0f) return f;
            }
        } catch (ReflectiveOperationException | RuntimeException ignored) {}
        // No script (test fixtures, exotic instances): first-seen value, memoised.
        Float seen=COMPENSATED.get(instance);
        return seen != null ? seen : current;
    }
    static void compensateScale(Object instance, Object character, boolean followsForm) {
        if (instance == null) return;
        try {
            Object current=Reflect.get(instance,"scale");
            float scale=current instanceof Float f ? f : 1f;
            float base=scriptScale(instance, scale);
            // Anchors follow the wolf; only ordinary item meshes cancel the
            // form multiplier. Harness/bags deliberately grow with Hispo.
            float target=base / (BODY_SCALE * (followsForm ? 1f : WTAGarouJava.scaleFor(character)));
            if (Math.abs(target - scale) < 1e-4f) { COMPENSATED_TO.put(instance, target); COMPENSATED.putIfAbsent(instance, base); return; }
            if (COMPENSATED_TO.containsKey(instance)) perfRecompensated.incrementAndGet(); else perfCompensated.incrementAndGet();
            COMPENSATED.put(instance, base);
            COMPENSATED_TO.put(instance, target);
            Reflect.set(instance,"scale", target);
            if (SCALE_LOGS.incrementAndGet() <= 16)
                System.out.println(String.format(Locale.ROOT,"[WTAGarou Java][Scale] sub-model %s: script %.3f, was %.3f, local %.3f; matrix body %.2f x form %.2f; followsForm=%s",
                        peek(peek(instance,"model"),"name"),base,scale,target,BODY_SCALE,WTAGarouJava.scaleFor(character),followsForm));
        } catch (ReflectiveOperationException | RuntimeException error) { warn("compensate",error); }
    }
    static final AtomicLong SCALE_LOGS = new AtomicLong();
    /** Pool reset starts a new lifetime, even when the Java object survives.
     * Forget WITHOUT restoring old fields into the engine's new instance. */
    public static void forgetSubmodel(Object instance) {
        WolfHarness.forget(instance);
        COMPENSATED.remove(instance);
        COMPENSATED_TO.remove(instance);
        RETARGET_ORIGINAL_BONE.remove(instance);
        MOUTH_ORIGINAL_ATTACHMENT.remove(instance);
        clearRoles(instance);
    }
    private static void clearRoles(Object instance) {
        SADDLEBAG_INSTANCES.remove(instance);
        HARNESS_INSTANCES.remove(instance);
        SLOT_INSTANCES.remove(instance);
        MOUTH_INSTANCES.remove(instance);
    }
    private static void restoreScale(Object instance) {
        WolfHarness.restore(instance);
        Float original=COMPENSATED.remove(instance);
        if (original != null) {
            // The script value is the truth; the memo is only the fallback.
            try {
                Object script=Reflect.get(instance,"modelScript");
                Object s=script == null ? null : Reflect.get(script,"scale");
                if (s instanceof Float f && f > 0f) original=f;
            } catch (ReflectiveOperationException | RuntimeException ignored) {}
        }
        COMPENSATED_TO.remove(instance);
        SADDLEBAG_INSTANCES.remove(instance);
        HARNESS_INSTANCES.remove(instance);
        SLOT_INSTANCES.remove(instance);
        if (original != null) {
            try { Reflect.set(instance,"scale", original); }
            catch (ReflectiveOperationException | RuntimeException ignored) {}
        }
        if (MOUTH_ORIGINAL_ATTACHMENT.containsKey(instance)) {
            Object attachment=MOUTH_ORIGINAL_ATTACHMENT.remove(instance);
            try { Reflect.set(instance,"attachmentNameParent", attachment); }
            catch (ReflectiveOperationException | RuntimeException ignored) {}
        }
        if (RETARGET_ORIGINAL_BONE.containsKey(instance)) {
            Object bone=RETARGET_ORIGINAL_BONE.remove(instance);
            try { Reflect.set(instance,"parentBoneName", bone); }
            catch (ReflectiveOperationException | RuntimeException ignored) {}
        }
        MOUTH_INSTANCES.remove(instance);
    }

    public static boolean hideSubmodel(Object slot, Object data) {
        if (data == null) return false;
        if (WOLVES.isEmpty() && COMPENSATED.isEmpty() && MOUTH_ORIGINAL_ATTACHMENT.isEmpty()) return false;
        try {
            Object instance=Reflect.get(data,"modelInstance");
            if (instance == null) return false;
            Object character=Reflect.get(instance,"character");
            if (character == null && slot != null) character=Reflect.get(slot,"character");
            // Transform preparation has no render slot; static gear often
            // omits character but its body parent owns the real IsoPlayer.
            Object owner=instance;
            for (int depth=0; character==null && owner!=null && depth<8; depth++) {
                owner=Reflect.get(owner,"parent");
                if (owner!=null) character=Reflect.get(owner,"character");
            }
            Object wolf=modelFor(character);
            if (wolf == null) { restoreScale(instance); return false; }
            if (Reflect.get(instance,"model") == wolf) return false;
            // The same character also owns HUMAN inventory/preview models.
            // Their gear must never be prepared as if parented to our wolf.
            if (!attachedToWolf(instance, character)) {
                restoreScale(instance);
                return Reflect.get(instance,"parent") == null;
            }
            // Classification is exclusive and belongs to this draw, not to
            // a previous hand/slot role of the pooled Java object.
            clearRoles(instance);
            // The saddlebag stand-in is a static sub-model attached at a
            // WTAGarou_ attachment of the wolf body; 0.4.11 hid it with the
            // human clothing, which is why no bags ever showed on the wolf.
            // 0.4.12 drew it at the character origin (no parent attachment on
            // the human body script, no parent bone); pin it to the spine.
            Object attachment=Reflect.get(instance,"attachmentNameParent");
            if (!HARNESS_ATTACHMENT.equals(attachment)) WolfHarness.restore(instance);
            if ((instance==primaryHandModel(character) || instance==secondaryHandModel(character))
                    && actionHandOverride(character)) {
                // A reading/eating/crafting prop is not equipped cargo.
                // Hide only its visual on wolves, not the item/action.
                restoreScale(instance);
                return true;
            }
            // Held containers can be skinned clothing models, not static
            // cargo. Jaw retargeting cannot rebind their vertex weights.
            if (heldContainer(character,instance)) {
                restoreScale(instance);
                return true;
            }
            if (HARNESS_ATTACHMENT.equals(attachment)) {
                // Keep missing/pending skinned assets hidden, never render a
                // rigid fallback or bind human animation to wolf weights.
                if (!WolfHarness.prepare(instance)) return true;
                HARNESS_INSTANCES.add(instance);
                return false;
            }
            if ("WTAGarou_Saddlebags".equals(attachment)) {
                Object before=Reflect.get(instance,"parentBoneName");
                if (retarget(instance, SADDLEBAG_BONE)) {
                    perfSaddlebagBone.incrementAndGet();
                    // 0.4.20: the September 26 playtest saw the bags yaw 90
                    // degrees after Lupus -> Hispo. Log every fresh retarget
                    // (bounded) with the names that decide its transform.
                    if (SADDLEBAG_LOGS.incrementAndGet() <= 12) saddlebagLog(instance, before, (String)attachment, wolf);
                }
                SADDLEBAG_INSTANCES.add(instance);
                compensateScale(instance, character, true);
                return false;
            }
            // Mouth carry: the primary-hand item is drawn from the jaw bone.
            if (mouthCarry && character != null && instance == primaryHandModel(character)) {
                if (retarget(instance, MOUTH_BONE)) {
                    perfMouthCarry.incrementAndGet();
                    // 0.4.17: skip the human body's Bip01_Prop1 attachment so
                    // the engine uses parentBoneName (the jaw) for real.
                    try {
                        if (!MOUTH_ORIGINAL_ATTACHMENT.containsKey(instance)) MOUTH_ORIGINAL_ATTACHMENT.put(instance, attachment);
                        Reflect.set(instance,"attachmentNameParent", MOUTH_ATTACHMENT);
                    } catch (ReflectiveOperationException | RuntimeException error) { warn("mouth attachment",error); }
                }
                MOUTH_INSTANCES.add(instance);
                compensateScale(instance, character, false);
                return false;
            }
            // 0.4.23 wolf slots (hotbar items, secondary hand). 0.4.24: in its
            // own try so a reflection surprise hides the item (the pre-0.4.23
            // behaviour) instead of drawing it at the human attachment.
            if (slotsEnabled && character != null) try {
                Object parent=Reflect.get(instance,"parent");
                // Children of a visible slot/jaw item (weapon parts, scopes,
                // magazines) ride along with their parent's transform.
                if (parent != null && (SLOT_INSTANCES.containsKey(parent) || MOUTH_INSTANCES.contains(parent))) return false;
                String key=null;
                if (instance == secondaryHandModel(character)) key=SECONDARY_SLOT_KEY;
                else if (attachment instanceof String name) key=name.startsWith(SLOT_ATTACHMENT_PREFIX) ? name.substring(SLOT_ATTACHMENT_PREFIX.length()) : name;
                SlotRule rule=slotRule(key);
                if (rule != null) {
                    if (retarget(instance, rule.bone)) {
                        perfSlot.incrementAndGet();
                        try {
                            if (!MOUTH_ORIGINAL_ATTACHMENT.containsKey(instance)) MOUTH_ORIGINAL_ATTACHMENT.put(instance, attachment);
                            Reflect.set(instance,"attachmentNameParent", SLOT_ATTACHMENT_PREFIX + key);
                        } catch (ReflectiveOperationException | RuntimeException error) { warn("slot attachment",error); }
                        if (SLOT_LOGS.incrementAndGet() <= 24)
                            System.out.println("[WTAGarou Java][Slot] drawn on the wolf: "+rule+" self="+peek(instance,"attachmentNameSelf")
                                    +" model="+peek(peek(instance,"model"),"name"));
                    }
                    SLOT_INSTANCES.put(instance, rule);
                    compensateScale(instance, character, false);
                    return false;
                }
                if (attachment instanceof String name && parent != null && Reflect.get(parent,"model") == wolf
                        && HIDDEN_ATTACHMENTS.size() < 32 && HIDDEN_ATTACHMENTS.add(name)) {
                    System.out.println("[WTAGarou Java][Slot] hidden on the wolf (no WTAGarou.WolfSlots rule): attachment=\""+name
                            +"\" self="+peek(instance,"attachmentNameSelf")+" model="+peek(peek(instance,"model"),"name"));
                }
            } catch (ReflectiveOperationException | RuntimeException error) {
                perfSlotErrors.incrementAndGet();
                if (perfSlotErrors.get() <= 3) warn("slot",error);
            }
            restoreScale(instance);
            perfHidden.incrementAndGet();
            return true;
        } catch (ReflectiveOperationException | RuntimeException ignored) { return false; }
    }
    private static Object secondaryHandModel(Object character) {
        try { return Reflect.get(character,"secondaryHandModel"); }
        catch (ReflectiveOperationException | RuntimeException error) { return null; }
    }
    private static boolean heldContainer(Object character,Object instance) {
        if(character==null) return false;
        String getter=instance==primaryHandModel(character) ? "getPrimaryHandItem"
                : instance==secondaryHandModel(character) ? "getSecondaryHandItem" : null;
        if(getter==null) return false;
        try {
            Object item=Reflect.call(character,getter);
            return item!=null && "Container".equals(Reflect.call(item,"getCategory"));
        } catch (ReflectiveOperationException | RuntimeException ignored) { return false; }
    }
    private static boolean actionHandOverride(Object character) {
        if (character == null) return false;
        try {
            Object actions=Reflect.call(character,"getCharacterActions");
            if (!Boolean.TRUE.equals(Reflect.call(actions,"isEmpty"))) {
                Object action=Reflect.call(actions,"get",int.class,0);
                if (Boolean.TRUE.equals(Reflect.get(action,"overrideHandModels"))) return true;
            }
            Object primary=Reflect.get(character,"overridePrimaryHandModel");
            Object secondary=Reflect.get(character,"overrideSecondaryHandModel");
            return (primary instanceof String p && !p.isEmpty()) || (secondary instanceof String s && !s.isEmpty());
        } catch (ReflectiveOperationException | RuntimeException ignored) { return false; }
    }
    private static Object primaryHandModel(Object character) {
        try { return Reflect.get(character,"primaryHandModel"); }
        catch (ReflectiveOperationException | RuntimeException error) { return null; }
    }
    private static Object peek(Object target, String field) {
        if (target == null) return null;
        try { return Reflect.get(target, field); } catch (ReflectiveOperationException | RuntimeException error) { return "?"; }
    }
    static String saddlebagLog(Object instance, Object before, String parentAttach, Object wolf) {
        Object parent=peek(instance,"parent");
        Object parentModel=peek(parent,"model");
        Object parentScript=peek(parent,"modelScript");
        String line="[WTAGarou Java][Saddlebag] retarget #"+SADDLEBAG_LOGS.get()
            +" bone "+before+" -> "+SADDLEBAG_BONE
            +" self="+peek(instance,"attachmentNameSelf")
            +" parentAttach="+parentAttach
            +" parentModel="+peek(parentModel,"name")
            +" parentScript="+peek(parentScript,"name")
            +" parentIsWolf="+(parentModel != null && parentModel == wolf)
            +" scale="+peek(instance,"scale")
            +" parentScale="+peek(parent,"scale");
        System.out.println(line);
        return line;
    }
    /** Point a sub-model at another parent bone; true when it changed. The
     * instance is rebuilt from scratch on the next model reset, so nothing
     * has to be restored when the wolf is cleared. */
    static boolean retarget(Object instance, String bone) {
        try {
            Object current=Reflect.get(instance,"parentBoneName");
            if (bone.equals(current)) return false;
            if (!RETARGET_ORIGINAL_BONE.containsKey(instance)) RETARGET_ORIGINAL_BONE.put(instance, current);
            Reflect.set(instance,"parentBoneName",bone);
            return true;
        } catch (ReflectiveOperationException | RuntimeException error) { return false; }
    }
    /** Snapshot render-data only: no HumanVisual edits, clothing removal, or
     * mutation of shared Model/ModelInstance textures on the render thread.
     * KEEP this per-draw value: RenderList.DrawQueued retains the record until
     * later. Its next initModel/RenderCharacter overwrites tex from the owner. */
    public static void applyTexture(Object data) {
        if (WOLVES.isEmpty() || data == null) return;
        try {
            Object instance=Reflect.get(data,"modelInstance");
            if (instance == null) return;
            Object wolf=modelFor(Reflect.get(instance,"character"));
            if (wolf == null || Reflect.get(instance,"model") != wolf) return;
            Reflect.set(data,"tex",WolfCoats.texture(Reflect.get(instance,"character"),Reflect.get(wolf,"tex")));
            wolfDrawObserved=true;
            perfDraws.incrementAndGet();
            perfFrame(null);
        } catch (ReflectiveOperationException | RuntimeException error) { warn("texture",error); }
    }
    static void warn(String area, Exception error) {
        lastStatus=area+": "+error;
        if (WARNINGS.add(area)) System.out.println("[WTAGarou Java] wolf "+lastStatus);
    }
    public static String status() {
        return "wolf body hook="+bodyHookObserved+"; track hook="+trackHookObserved
                +"; rig hook="+rigHookObserved+"; rig enforcements from track="+rigEnforcedFromTrack
                +"; wolf draw="+wolfDrawObserved+"; registered wolves="+WOLVES.size()
                +"; animator state restored after reset="+animatorRestoreObserved
                +"; harness skin-init hook="+WolfHarness.initObserved
                +"; wolf body normalization="+BODY_SCALE
                +"; compensated sub-models="+perfCompensated.get()
                +"; mouth carry rot="+mouthRotX+","+mouthRotY+","+mouthRotZ+" off="+mouthOffX+","+mouthOffY+","+mouthOffZ
                +"; player-motion clips="+WolfPlayerClips.built
                +"; "+lastStatus+"; last asset check: "+lastAssetStatus
                +"; "+WolfClipLoader.status()
                +(lastAssetSources.isEmpty() ? "" : "; "+lastAssetSources);
    }
}
