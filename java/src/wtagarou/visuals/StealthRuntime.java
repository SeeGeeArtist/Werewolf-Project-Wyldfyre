package wtagarou.visuals;

import java.util.Collections;
import java.util.Map;
import java.util.WeakHashMap;
import java.util.concurrent.ThreadLocalRandom;

/**
 * Per-form noise, visibility and voice. Lua registers a profile for every
 * Garou it can see (local player and synced remotes); three engine funnels
 * consult it:
 *
 *  - IsoGameCharacter.DoFootstepSound(float): footstep volume/radius scaled
 *    by the form; wolf forms replace the human footstep bank with the wolf
 *    step sound and their own world-sound radius.
 *  - IsoGameCharacter.Callout(): the Q shout. Wolf forms bark (standing) or
 *    growl (crouched); Crinos roars or growls. Radius per form replaces the
 *    human 30 / 6 tiles.
 *  - IsoZombie.spotted(IsoMovingObject, boolean): a fraction of sight
 *    checks against a low-profile form is dropped, which scales the spot
 *    chance the same way the engine's own sneaking multiplier does.
 *
 * Every engine call goes through reflection on the live object so this
 * compiles without the game jar and degrades to "do nothing" when a method
 * is missing.
 */
public final class StealthRuntime {
    public static final class Profile {
        public float footstepMul = 1f;
        public float spotMul = 1f;          // standing
        public float spotMulSneaking = 1f;  // extra factor while sneaking
        public boolean wolfSteps;
        /** wolfSteps: the wolf step bank that REPLACES the human one.
         *  0.4.67, !wolfSteps: an extra bank LAYERED under the human step
         *  (Crinos bass impact), played locally on every client. */
        public String stepSound;
        public String shoutStanding, shoutCrouched;
        public float radiusStanding = 30f, radiusCrouched = 6f;
        public String textStanding = "", textCrouched = "";
        public String fallSound;
        public boolean pendingRoar;
        /** 0.4.63: Q shout / whisper plays no "shout" emote animation (Crinos). */
        public boolean suppressShoutAnim;
        public boolean calloutCooling;
        public long nextCalloutNanos;
        public boolean hasVoice() { return shoutStanding != null || shoutCrouched != null; }
    }

    private static final Map<Object, Profile> PROFILES =
            Collections.synchronizedMap(new WeakHashMap<>());
    public static volatile long footsteps, wolfFootsteps, layeredFootsteps, shouts, sightSkipped, sightChecked, falls;
    private static boolean loggedStep, loggedShout;
    public static final long CALLOUT_STANDING_NANOS = 200_000_000L;
    public static final long CALLOUT_CROUCHED_NANOS = 400_000_000L;
    static java.util.function.LongSupplier voiceClock = System::nanoTime;

    public static Profile profile(Object character) {
        return character == null ? null : PROFILES.get(character);
    }
    private static Profile edit(Object character) {
        return PROFILES.computeIfAbsent(character, k -> new Profile());
    }

    public static boolean setNoise(Object character, double footstepMul, double spotMul,
                                   double spotMulSneaking, boolean wolfSteps, String stepSound) {
        if (character == null || !Double.isFinite(footstepMul) || !Double.isFinite(spotMul)
                || !Double.isFinite(spotMulSneaking)) return false;
        Profile p = edit(character);
        p.footstepMul = (float) Math.max(0, footstepMul);
        p.spotMul = (float) Math.max(0, Math.min(1, spotMul));
        p.spotMulSneaking = (float) Math.max(0, Math.min(1, spotMulSneaking));
        p.wolfSteps = wolfSteps;
        p.stepSound = (stepSound == null || stepSound.isEmpty()) ? null : stepSound;
        return true;
    }
    public static boolean setVoice(Object character, String standing, String crouched,
                                   double radiusStanding, double radiusCrouched) {
        if (character == null) return false;
        Profile p = edit(character);
        p.shoutStanding = (standing == null || standing.isEmpty()) ? null : standing;
        if (!"WTAGarou_CrinosRoar".equals(p.shoutStanding)) p.pendingRoar=false;
        p.shoutCrouched = (crouched == null || crouched.isEmpty()) ? null : crouched;
        if (Double.isFinite(radiusStanding)) p.radiusStanding = (float) Math.max(0, radiusStanding);
        if (Double.isFinite(radiusCrouched)) p.radiusCrouched = (float) Math.max(0, radiusCrouched);
        return true;
    }
    public static boolean setVoiceText(Object character, String standing, String crouched) {
        if (character == null) return false;
        Profile p = edit(character);
        p.textStanding = standing == null ? "" : standing;
        p.textCrouched = crouched == null ? "" : crouched;
        return true;
    }
    /** 0.4.63: whether the Q shout/whisper should skip the "shout" emote animation for this character. */
    public static boolean setShoutAnim(Object character, boolean playAnim) {
        if (character == null) return false;
        edit(character).suppressShoutAnim = !playAnim;
        return true;
    }
    /** ShoutEmotePatch: IsoGameCharacter.playEmote(emote) entry; true skips the emote. Pure over the profile. */
    public static boolean suppressEmote(Object character, String emote) {
        if (character == null || emote == null) return false;
        if (!"shout".equalsIgnoreCase(emote.trim())) return false;
        Profile p = PROFILES.get(character);
        return p != null && p.suppressShoutAnim;
    }
    public static boolean setFallSound(Object character, String sound) {
        if (character == null) return false;
        edit(character).fallSound = (sound == null || sound.isEmpty()) ? null : sound;
        return true;
    }
    public static void clear(Object character) { if (character != null) PROFILES.remove(character); }
    public static void clearAll() { PROFILES.clear(); }
    /** One edge consumed by the local Lua update, never a held-Q poll. */
    public static boolean consumeRoar(Object character) {
        Profile p=profile(character);
        if (p==null) return false;
        boolean pending=p.pendingRoar;
        p.pendingRoar=false;
        return pending;
    }

    // ------------------------------------------------------------ engine --
    static Object rng = null; // test hook: Float supplier
    static float roll() {
        if (rng instanceof java.util.function.Supplier<?> s) return ((Number) s.get()).floatValue();
        return ThreadLocalRandom.current().nextFloat();
    }

    static boolean isSneaking(Object character) {
        try { return Boolean.TRUE.equals(Reflect.call(character, "isSneaking")); }
        catch (Throwable t) { return false; }
    }
    static float sneakSpotMod(Object character) {
        try { return ((Number) Reflect.call(character, "getSneakSpotMod")).floatValue(); }
        catch (Throwable t) { return 0.95f; }
    }
    static boolean inRoom(Object character) {
        try {
            Object sq = Reflect.call(character, "getCurrentSquare");
            return sq != null && Reflect.call(sq, "getRoom") != null;
        } catch (Throwable t) { return false; }
    }
    static int[] position(Object character) {
        try {
            return new int[]{
                (int) Math.floor(((Number) Reflect.call(character, "getX")).doubleValue()),
                (int) Math.floor(((Number) Reflect.call(character, "getY")).doubleValue()),
                (int) Math.floor(((Number) Reflect.call(character, "getZ")).doubleValue())};
        } catch (Throwable t) { return null; }
    }
    /** 0.4.40: file-clip cues ignore the Sound Effects slider (the engine
     * only pauses/mutes channelGroupInGameNonBankSounds), so every handle we
     * start is scaled by the slider and capped. Mirrors shared/WTAGarouAudio.lua. */
    public static final float MAX_VOLUME = 1.0f;   // 0.4.88: no cap (was 0.75f)
    public static float sliderVolume() {
        try {
            Object manager = Class.forName("zombie.SoundManager").getField("instance").get(null);
            float v = ((Number) Reflect.call(manager, "getSoundVolume")).floatValue();
            return Math.max(0f, Math.min(1f, v));
        } catch (Throwable t) { return 1f; }
    }
    public static float volumeFactor() { return MAX_VOLUME * sliderVolume(); }
    static void scaleHandle(Object character, Object handle) { scaleHandle(character, handle, 1f); }
    /** 0.4.67: `gain` (0..1) multiplies the slider factor for one handle. */
    static void scaleHandle(Object character, Object handle, float gain) {
        if (!(handle instanceof Number) || ((Number) handle).longValue() == 0L) return;
        try {
            Object emitter = Reflect.call(character, "getEmitter");
            if (emitter != null) Reflect.call(emitter, "setVolume", new Class<?>[]{long.class, float.class},
                    ((Number) handle).longValue(), volumeFactor() * Math.max(0f, Math.min(1f, gain)));
        } catch (Throwable t) { /* no emitter in tests */ }
    }
    /** character.playSound(name): the emitter path, network-synced in MP. */
    static void playSound(Object character, String name) {
        if (name == null) return;
        try { scaleHandle(character, Reflect.call(character, "playSound", String.class, name)); }
        catch (Throwable t) { /* no emitter in tests */ }
    }
    static void say(Object character, String text) {
        if (text == null || text.isEmpty()) return;
        try { Reflect.call(character, "Say", String.class, text); }
        catch (Throwable t) { /* no UI in tests */ }
    }
    static Object worldSoundManager;
    static java.lang.reflect.Method addSoundMethod;
    /** WorldSoundManager.instance.addSound(source, x, y, z, radius, volume). */
    static boolean addWorldSound(Object character, int radius, int volume) {
        if (radius <= 0) return false;
        int[] pos = position(character);
        if (pos == null) return false;
        try {
            if (addSoundMethod == null) {
                Class<?> wsm = Class.forName("zombie.WorldSoundManager");
                worldSoundManager = wsm.getField("instance").get(null);
                addSoundMethod = wsm.getMethod("addSound", Object.class, int.class, int.class, int.class, int.class, int.class);
            }
            addSoundMethod.invoke(worldSoundManager, character, pos[0], pos[1], pos[2], radius, volume);
            return true;
        } catch (Throwable t) { return false; }
    }

    // ---------------------------------------------------------- footsteps --
    /**
     * Called from the DoFootstepSound(float) advice. Returns the volume the
     * engine should continue with, or a negative value when the wolf path
     * handled the step itself and the human code must be skipped.
     */
    public static float footstep(Object character, float volume) {
        Profile p = profile(character);
        if (p == null || volume <= 0f) return volume;
        footsteps++;
        float scaled = volume * p.footstepMul;
        if (!p.wolfSteps) {
            // 0.4.67: Crinos bass layer. DoFootstepSound runs from the
            // Footstep anim event on every client that animates this
            // character (remote copies included), so playSoundLocal here is
            // what makes it heard in multiplayer; a networked playSound would
            // double it. Gain follows the surface step: full when the step is
            // at least a normal walk, quieter while sneaking.
            if (p.stepSound != null) {
                float gain = Math.max(0f, Math.min(1f, scaled / 0.75f));
                try { scaleHandle(character, Reflect.call(character, "playSoundLocal", String.class, p.stepSound), gain); }
                catch (Throwable t) { /* tests */ }
                layeredFootsteps++;
            }
            return scaled;
        }
        wolfFootsteps++;
        // Mirror the engine's human math: 1.4x base, no shoes (paws) 0.5x,
        // sneaking applies the perk multiplier, indoors halves the radius.
        float v = scaled * 1.4f * 0.5f;
        if (isSneaking(character)) v *= sneakSpotMod(character);
        if (v <= 0f) return -1f;
        if (p.stepSound != null) {
            try { scaleHandle(character, Reflect.call(character, "playSoundLocal", String.class, p.stepSound)); }
            catch (Throwable t) { /* tests */ }
        }
        int rad = (int) Math.ceil(v * 10f);
        if (isSneaking(character)) rad = Math.max(1, rad);
        if (inRoom(character)) rad = (int) (rad * 0.5f);
        int gate = isSneaking(character) ? 4 : 2;
        if (rad > 0 && ThreadLocalRandom.current().nextInt(gate) == 0) addWorldSound(character, rad, rad);
        if (!loggedStep) {
            loggedStep = true;
            System.out.println("[WTAGarou Java] wolf footstep volume=" + v + " radius=" + rad + " sound=" + p.stepSound);
        }
        return -1f;
    }

    // -------------------------------------------------------------- shout --
    /** Returns true when the form voice replaced the human Callout. */
    public static boolean callout(Object character) {
        Profile p = profile(character);
        if (p == null || !p.hasVoice()) return false;
        boolean sneaking = isSneaking(character);
        long now=voiceClock.getAsLong();
        // Consume suppressed Q presses too: never fall through to human
        // shouting, add noise/bubbles or enqueue a Crinos knockback edge.
        if (p.calloutCooling && now-p.nextCalloutNanos<0) return true;
        p.calloutCooling=true;
        p.nextCalloutNanos=now+(sneaking ? CALLOUT_CROUCHED_NANOS : CALLOUT_STANDING_NANOS);
        String sound = sneaking ? p.shoutCrouched : p.shoutStanding;
        if (sound == null) sound = sneaking ? p.shoutStanding : p.shoutCrouched;
        float radius = sneaking ? p.radiusCrouched : p.radiusStanding;
        shouts++;
        playSound(character, sound);
        say(character, sneaking ? p.textCrouched : p.textStanding);
        int r = Math.round(radius);
        addWorldSound(character, r, r);
        if (!sneaking && "WTAGarou_CrinosRoar".equals(sound)) p.pendingRoar=true;
        if (!loggedShout) {
            loggedShout = true;
            System.out.println("[WTAGarou Java] form voice replaced Callout: sound=" + sound + " radius=" + r + " sneaking=" + sneaking);
        }
        return true;
    }

    // -------------------------------------------------------------- sight --
    /** Returns true when this sight check should be dropped. */
    public static boolean skipSpot(Object target, boolean forced) {
        WolfRuntime.perfSpots.incrementAndGet();
        if (forced) return false;
        Profile p = profile(target);
        if (p == null) return false;
        float keep = p.spotMul;
        if (isSneaking(target)) keep *= p.spotMulSneaking;
        sightChecked++;
        if (keep >= 1f) return false;
        boolean skip = keep <= 0f || roll() >= keep;
        if (skip) sightSkipped++;
        return skip;
    }

    // --------------------------------------------------------------- falls --
    /** A fall that stability allowed: wolves make their fall-over sound. */
    public static void onFall(Object character) {
        Profile p = profile(character);
        if (p == null || p.fallSound == null) return;
        falls++;
        playSound(character, p.fallSound);
    }

    public static String status() {
        return "stealth profiles=" + PROFILES.size() + "; footsteps=" + footsteps + " (wolf " + wolfFootsteps
                + "); shouts=" + shouts + "; sight checks=" + sightChecked + " skipped=" + sightSkipped + "; falls=" + falls;
    }
}
