package wtagarou.visuals;

import java.util.Collections;
import java.util.Map;
import java.util.WeakHashMap;
import me.zed_0xff.zombie_buddy.Exposer;

/** Lua supplies per-character state on the game thread; rendering reads a
 * synchronized weak map, never a live Kahlua table on the render thread. */
@Exposer.LuaClass
public final class WTAGarouJava {
    private static final Map<Object, Float> SCALES =
            Collections.synchronizedMap(new WeakHashMap<>());

    public static boolean setScale(Object character, double scale) {
        if (character == null || !Double.isFinite(scale) || scale < 0.5 || scale > 2.0) {
            return false;
        }
        SCALES.put(character, (float) scale);
        return true;
    }

    public static void clear(Object character) {
        if (character != null) {
            CrinosCosmetics.clear(character);
            if (WolfRuntime.retainDyingWolf(character)) {
                CombatRuntime.enable(character, false);
                return; // keep the visible wolf and its scale until corpse handoff
            }
            SCALES.remove(character);
            WolfRuntime.setWolf(character, false);
            CombatRuntime.enable(character, false);
            StabilityRuntime.clear(character);
            StealthRuntime.clear(character);
            TraitsRuntime.clear(character);
            StrideRuntime.clear(character);
            FurRuntime.clear(character);
            WolfGrappleRuntime.clear(character); MeleeRangeRuntime.clear(character);
            PoiseRuntime.clear(character); DoorwayRuntime.clear(character);
            CrowdChargeRuntime.clear(character);
        }
    }
    public static void clearScale(Object character) {
        if (character != null) SCALES.remove(character);
    }
    public static void beginShiftAnimation(Object character) { ShiftNilGuard.begin(character); }
    public static void endShiftAnimation() { ShiftNilGuard.end(); }

    public static void clearAll() {
        FurRuntime.clearAll();
        CrinosCosmetics.clearAll();
        WolfCoats.clearAll();
        SCALES.clear();
        WolfRuntime.clearAll();
        CombatRuntime.clearAll();
        SilverHitRuntime.clearAll();
        StabilityRuntime.clearAll();
        PoiseRuntime.clearAll();
        DoorwayRuntime.clearAll();
        CrowdChargeRuntime.clearAll();
        StealthRuntime.clearAll();
        TraitsRuntime.clearAll();
        StrideRuntime.clearAll();
    }

    /** Footstep volume multiplier, sight-check keep fractions, wolf step bank. */
    public static boolean setNoise(Object character, double footstepMul, double spotMul,
                                   double spotMulSneaking, boolean wolfSteps, String stepSound) {
        return StealthRuntime.setNoise(character, footstepMul, spotMul, spotMulSneaking, wolfSteps, stepSound);
    }
    /** Q-shout replacement sounds (standing / crouched) and their radii. Empty clears. */
    public static boolean setVoice(Object character, String standing, String crouched,
                                   double radiusStanding, double radiusCrouched) {
        return StealthRuntime.setVoice(character, standing, crouched, radiusStanding, radiusCrouched);
    }
    public static boolean setVoiceText(Object character, String standing, String crouched) {
        return StealthRuntime.setVoiceText(character, standing, crouched);
    }
    /** 0.4.63: false = the Q shout/whisper plays no emote animation (Crinos). */
    public static boolean setShoutAnim(Object character, boolean playAnim) {
        return StealthRuntime.setShoutAnim(character, playAnim);
    }
    public static boolean setFallSound(Object character, String sound) {
        return StealthRuntime.setFallSound(character, sound);
    }
    public static void clearStealth(Object character) { StealthRuntime.clear(character); }
    public static boolean consumeCrinosRoar(Object character) { return StealthRuntime.consumeRoar(character); }

    /** Body traits per form: raw-meat immunity, paw (barefoot) immunity and
     * gait/turn multipliers. All 1 / false clears the profile. */
    public static boolean setTraits(Object character, boolean rawMeat, boolean paws,
                                    double walk, double run, double sprint, double sneak, double turn) {
        return TraitsRuntime.set(character, rawMeat, paws, walk, run, sprint, sneak, turn);
    }
    public static void clearTraits(Object character) { TraitsRuntime.clear(character); }
    /** 0.4.60: root-motion stride factor for scaled bipeds (1 clears); see StrideRuntime. */
    public static boolean setStride(Object character, double factor) { return StrideRuntime.set(character, factor); }
    public static String strideStatus() { return StrideRuntime.status(); }
    /** 0.4.80: vertical root-motion compression while a scaled biped climbs; see ClimbRuntime. */
    public static String climbStatus() { return ClimbRuntime.status(); }
    /** 0.4.62: silver nitrate fluid cooking and the wtagarou:coatable weapon tag; see NitrateHeatRuntime / CoatableTagRuntime. */
    public static String nitrateStatus() { return NitrateHeatRuntime.status(); }
    /** 0.4.66: next vessel this client cooked (MP report queue), or null. */
    public static Object pollNitrateCooked() { return NitrateHeatRuntime.pollNitrateCooked(); }
    public static String coatableStatus() { return CoatableTagRuntime.status(); }
    public static int coatableCount() { return CoatableTagRuntime.tagged; }
    /** 0.4.39: Crinos/Hispo flag for BaseVehicle.isEnterBlocked and the window-climb smash. */
    public static boolean setBulkForm(Object character, boolean bulk) { return BulkFormRuntime.set(character, bulk); }
    public static boolean setFurInsulation(Object character, double floor) { return FurRuntime.set(character, floor); }
    /** 0.4.40: extra metres a dragged corpse sits ahead of a wolf-form grappler (0 clears). */
    public static boolean setGrappleForward(Object character, double metres) { return WolfGrappleRuntime.setForward(character, metres); }
    /** 0.4.44: total distance for a shoulders grab from the ground (0 clears). */
    public static boolean setShoulderPickupDistance(Object character, double metres) { return WolfGrappleRuntime.setShoulderPickupDistance(character, metres); }
    /** 0.4.40: corpse pickup/lay-down/throw clip running, dragging, or throwing (bite-sound filter). */
    public static boolean isCorpseHandling(Object character) { return WolfGrappleRuntime.isCorpseHandling(character); }
    public static String grappleStatus() { return WolfGrappleRuntime.status(); }
    /** 0.4.42: melee range multiplier for this character (1 clears). */
    public static boolean setMeleeRange(Object character, double multiplier) { return MeleeRangeRuntime.set(character, multiplier); }
    public static String meleeRangeStatus() { return MeleeRangeRuntime.status(); }
    public static boolean isBulkForm(Object character) { return BulkFormRuntime.isBulk(character); }
    /** Primary-hand item drawn at the wolf jaw instead of hidden (experimental). */
    public static void setMouthCarry(boolean enabled) { WolfRuntime.mouthCarry = enabled; }
    public static void setWolfCoat(Object character,String key) { WolfCoats.set(character,key); }
    public static void setWolfTexture(Object character,String path) { WolfCoats.setPath(character,path); }
    public static String setCrinosCosmetics(Object character,boolean enabled,String body,String head) {
        return CrinosCosmetics.set(character,enabled,body,head);
    }
    /** 0.4.67: same, plus intrinsic skinned legs and an optional tail
     *  (Body/ texture names; "" = none). */
    public static String setCrinosCosmeticsParts(Object character,boolean enabled,String body,String head,
                                                 String legs,String tail) {
        return CrinosCosmetics.set(character,enabled,body,head,legs,tail);
    }
    /** 0.4.67: warm the legs/tail meshes and this coat's part textures. */
    public static String preloadCrinosParts(String legs,String tail,boolean female) {
        return CrinosCosmetics.preloadParts(legs,tail,female);
    }
    /** 0.4.59: warm the wolf model, the Crinos head model and this coat's
     *  body/head textures before any shift asks for them. Also warms the
     *  wolf coat texture when a path is given. Returns
     *  "ready" when everything is resident, "pending" while loading,
     *  "failed" if a name was invalid or the wolf check failed. */
    public static String preloadForms(String body,String head,String wolfTexturePath) {
        String wolf=WolfRuntime.preload();
        String crinos=CrinosCosmetics.preload(body,head);
        if (wolfTexturePath!=null && !wolfTexturePath.isEmpty()) {
            try {
                Class.forName("zombie.core.textures.Texture").getMethod("getSharedTexture",String.class)
                        .invoke(null,wolfTexturePath);
            } catch (ReflectiveOperationException | RuntimeException ignored) {}
        }
        if ("failed".equals(wolf) || "failed".equals(crinos)) return "failed";
        return "ready".equals(wolf) && "ready".equals(crinos) ? "ready" : "pending";
    }
    public static String debugCrinosAttack(Object character) {
        return CrinosAttackDiagnostics.describe(character);
    }
    /** 0.4.70: read-only live track/mask dump during a howl. */
    public static String debugHowl(Object character) {
        return HowlDiagnostics.describe(character);
    }
    /** 0.4.71: true when the human (Bob) rig has a clip of this name loaded,
     *  e.g. an authored Bob_WTAGarouHowl from media/anims_X/Bob. Read-only;
     *  Lua uses it to pick the authored howl node over the Drink fallback. */
    public static boolean hasHumanClip(String clip) {
        return HumanClips.has(clip);
    }
    public static void setSilverBurnDamage(Object part,double factor) { SilverBurnRuntime.set(part,factor); }
    public static void setAttachmentPivot(String key,double x,double y,double z) {
        if (!("mouth".equals(key) || "harness".equals(key) || "saddlebag".equals(key))
                || !Double.isFinite(x) || !Double.isFinite(y) || !Double.isFinite(z)) return;
        if (x==0 && y==0 && z==0) WolfRuntime.ATTACHMENT_PIVOTS.remove(key);
        else WolfRuntime.ATTACHMENT_PIVOTS.put(key,new float[]{(float)x,(float)y,(float)z});
    }
    public static String wolfTimingStatus() {
        return "gait slowdown="+WolfPlayerClips.cycleSlowdown+"; attack speed="+WolfPlayerClips.attackSpeed
                +"; stomp speed="+WolfPlayerClips.stompSpeed;
    }
    public static void refreshWolfAnimations(Object character) {
        if (WolfRuntime.active(character) && !WolfRuntime.retainDyingWolf(character)) {
            try { WolfRuntime.resetAnimData(character); }
            catch (ReflectiveOperationException | RuntimeException error) { WolfRuntime.warn("timing refresh",error); }
        }
    }
    /** 0.4.17: rotation (degrees) and offset (metres) for the jaw-carried item. */
    public static void setMouthCarryTransform(double rotX, double rotY, double rotZ,
                                              double offX, double offY, double offZ) {
        WolfRuntime.mouthRotX = (float) rotX; WolfRuntime.mouthRotY = (float) rotY; WolfRuntime.mouthRotZ = (float) rotZ;
        WolfRuntime.mouthOffX = (float) offX; WolfRuntime.mouthOffY = (float) offY; WolfRuntime.mouthOffZ = (float) offZ;
    }
    /** 0.4.22: saddlebag post-transform (degrees / metres) from WTAGarou.Saddlebag. */
    public static void setSaddlebagTransform(double rotX, double rotY, double rotZ,
                                             double offX, double offY, double offZ) {
        WolfRuntime.saddleRotX = (float) rotX; WolfRuntime.saddleRotY = (float) rotY; WolfRuntime.saddleRotZ = (float) rotZ;
        WolfRuntime.saddleOffX = (float) offX; WolfRuntime.saddleOffY = (float) offY; WolfRuntime.saddleOffZ = (float) offZ;
    }
    /** 0.4.23: uniform extra scale on the saddlebag (WTAGarou.Saddlebag.scale). */
    public static void setSaddlebagScale(double scale) { WolfRuntime.saddleScale = scale > 0 ? (float) scale : 1f; }
    /** 0.4.23: harness stand-in transform (WTAGarou.Harness). */
    public static void setHarnessTransform(double rotX, double rotY, double rotZ,
                                           double offX, double offY, double offZ, double scale) {
        WolfRuntime.harnessRotX = (float) rotX; WolfRuntime.harnessRotY = (float) rotY; WolfRuntime.harnessRotZ = (float) rotZ;
        WolfRuntime.harnessOffX = (float) offX; WolfRuntime.harnessOffY = (float) offY; WolfRuntime.harnessOffZ = (float) offZ;
        WolfRuntime.harnessScale = scale > 0 ? (float) scale : 1f;
    }
    /** 0.4.22: wolf gait clips play this many times slower than the
     * stride-matched clock (WTAGarou.WolfGait.CYCLE_SLOWDOWN). Clears the
     * derived-clip cache so the next shift rebuilds with the new value. */
    /** 0.4.23: one WTAGarou.WolfSlots rule. key = attachment name of the
     * hotbar location (or "secondary"), bone = wolf bone, rot in degrees
     * (item space), off in metres (character space, Y up). */
    public static void setWolfSlot(String key, String bone, double rotX, double rotY, double rotZ,
                                   double offX, double offY, double offZ) {
        setWolfSlot(key, bone, rotX, rotY, rotZ, offX, offY, offZ, 0, 0, 0);
    }
    /** 0.4.24: grip point for an existing rule (Lua calls this after
     * setWolfSlot; a separate name keeps Kahlua's method lookup simple). */
    public static void setWolfSlotPivot(String key, double pivotX, double pivotY, double pivotZ) {
        WolfRuntime.SlotRule r = key == null ? null : WolfRuntime.slotRule(key);
        if (r == null || !r.key.equalsIgnoreCase(key)) return;
        WolfRuntime.setSlotRule(new WolfRuntime.SlotRule(r.key, r.bone, r.rotX, r.rotY, r.rotZ, r.offX, r.offY, r.offZ,
                (float) pivotX, (float) pivotY, (float) pivotZ));
    }
    /** 0.4.24: with a pivot - the point on the item (item space, metres)
     * the strap grips; the item turns about it when the spine bobs. */
    public static void setWolfSlot(String key, String bone, double rotX, double rotY, double rotZ,
                                   double offX, double offY, double offZ,
                                   double pivotX, double pivotY, double pivotZ) {
        if (key == null || key.isEmpty()) return;
        String b = (bone == null || bone.isEmpty()) ? WolfRuntime.SADDLEBAG_BONE : bone;
        WolfRuntime.setSlotRule(new WolfRuntime.SlotRule(key, b, (float) rotX, (float) rotY, (float) rotZ,
                (float) offX, (float) offY, (float) offZ, (float) pivotX, (float) pivotY, (float) pivotZ));
    }
    public static void clearWolfSlots() { WolfRuntime.clearSlotRules(); }
    public static void setWolfSlotsEnabled(boolean on) { WolfRuntime.slotsEnabled = on; }
    public static String wolfSlotStatus() { return WolfRuntime.slotStatus(); }
    /** 0.4.22: WTAGarou.WolfGait.MARKER_AT_ORIGIN (see WolfPlayerClips). */
    /** 0.4.24: WTAGarou.WolfGait.TRANSITIONS_KEEP_HUMAN_TIMING (see WolfPlayerClips). */
    public static void setTransitionsKeepHumanTiming(boolean on) {
        if (WolfPlayerClips.transitionsKeepHumanTiming != on) {
            WolfPlayerClips.transitionsKeepHumanTiming = on;
            WolfPlayerClips.clearCache();
        }
    }
    public static void setWolfAttackSpeed(double speed) {
        if (!Double.isFinite(speed)) return;
        float value = (float)Math.max(0.1, Math.min(4.0, speed));
        if (WolfPlayerClips.attackSpeed != value) {
            WolfPlayerClips.attackSpeed = value;
            WolfPlayerClips.clearCache();
        }
    }
    public static void setWolfStompSpeed(double speed) {
        if (!Double.isFinite(speed)) return;
        float value = (float)Math.max(0.1, Math.min(4.0, speed));
        if (WolfPlayerClips.stompSpeed != value) {
            WolfPlayerClips.stompSpeed = value;
            WolfPlayerClips.clearCache();
        }
    }
    public static void setMarkerAtOrigin(boolean on) {
        if (WolfPlayerClips.markerAtOrigin != on) {
            WolfPlayerClips.markerAtOrigin = on;
            WolfPlayerClips.clearCache();
        }
    }
    public static void setGaitSlowdown(double factor) {
        float f = (float) factor;
        if (!(f > 0f)) f = 1f;
        if (Math.abs(WolfPlayerClips.cycleSlowdown - f) > 1e-4f) {
            WolfPlayerClips.cycleSlowdown = f;
            WolfPlayerClips.clearCache();
        }
    }

    /** Chance (0..1) that a knockdown or trip is shrugged off. 0 clears. */
    public static boolean setStability(Object character, double chance) {
        return StabilityRuntime.set(character, chance);
    }

    /** 0.4.72: fraction (0..1) of every acute hit that lands (per-form health
     *  pool: 0.4 = 250 effective). 1 clears. */
    public static boolean setDamageIntake(Object character, double factor) {
        return ToughnessRuntime.set(character, factor);
    }
    public static String toughnessStatus() { return ToughnessRuntime.status(); }

    /** 0.4.68: chance (0..1) a melee flinch is shrugged off. 0 clears. */
    public static boolean setPoise(Object character, double chance) {
        return PoiseRuntime.set(character, chance);
    }
    /** 0.4.68: the form is too tall for doorways (crouch / duck rules). */
    public static boolean setTallForm(Object character, boolean tall) {
        return DoorwayRuntime.setTall(character, tall);
    }
    public static boolean isTallForm(Object character) { return DoorwayRuntime.isTall(character); }
    /** 0.4.69: sprinting into zombies knocks down up to `limit` of them per
     *  `windowSeconds` without stumbling; limit 0 clears. */
    public static boolean setCrowdCharge(Object character, double limit, double windowSeconds) {
        if (!Double.isFinite(limit) || !Double.isFinite(windowSeconds)) return false;
        return CrowdChargeRuntime.set(character, (int) Math.floor(limit), windowSeconds);
    }
    public static String crowdChargeStatus() { return CrowdChargeRuntime.status(); }
    public static void setDoorChargeCosts(double rage, double rageLocked) { DoorwayRuntime.setCosts(rage, rageLocked); }
    public static void setDoorwayDuckRule(double releaseTiles, double timeoutMs) { DoorwayRuntime.setDuckRule(releaseTiles, timeoutMs); }
    /** Per frame for the local player: pushes Rage, releases a finished duck;
     * true while the "crouch to pass" hint is fresh. */
    public static boolean tickDoorway(Object character, double rage) { return DoorwayRuntime.tick(character, rage); }
    /** The IsoDoor a sprint just charged (once), or null. */
    public static Object pollDoorCharge(Object character) { return DoorwayRuntime.pollDoorCharge(character); }

    public static void setCombatTiming(Object character, boolean enabled) {
        CombatRuntime.enable(character, enabled);
    }
    /** 0.4.58: body-part index the engine last wounded on this victim with a
     * weapon (BodyPartType index), or -1 if none within maxAgeMillis. Cleared
     * on read. Lua uses it to burn the real wound with silver. */
    public static int takeWeaponHitPart(Object character, double maxAgeMillis) {
        return SilverHitRuntime.take(character, maxAgeMillis);
    }
    public static boolean weaponHitRecorderObserved() { return SilverHitRuntime.observed; }
    public static String setWolf(Object character, boolean enabled) {
        return WolfRuntime.setWolf(character, enabled);
    }

    public static float scaleFor(Object character) {
        Float scale = character == null ? null : SCALES.get(character);
        return scale == null ? 1.0f : scale;
    }

    public static String status() {
        return "WTAGarou Java 0.4.32; DrawChar observed=" + ScaleRuntime.observed
                + "; scaled draw observed=" + ScaleRuntime.scaled
                + "; render hook disabled=" + ScaleRuntime.disabled
                + "; recovery hook="+CombatRuntime.observed+"; "+StabilityRuntime.status()+"; "+PoiseRuntime.status()+"; "+ToughnessRuntime.status()+"; "+ClimbRuntime.status()+"; "+DoorwayRuntime.status()+"; "+StealthRuntime.status()+"; "+TraitsRuntime.status()+"; "+WolfRuntime.status()+"; "+WolfRuntime.slotStatus();
    }
}
