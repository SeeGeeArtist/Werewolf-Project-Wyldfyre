import java.lang.instrument.Instrumentation;
import java.util.ArrayList;
import java.util.List;
import net.bytebuddy.agent.ByteBuddyAgent;
import wtagarou.visuals.*;

/** Real ZombieBuddy advice on fixtures shaped like the engine funnels. */
public final class StealthTest {
    static int checks;
    static void check(boolean ok, String why) { checks++; if (!ok) throw new AssertionError("FAIL: " + why); }

    public static class Character {
        public boolean sneaking; public float spotMod = 0.7f;
        public final List<String> sounds = new ArrayList<>(), local = new ArrayList<>(), said = new ArrayList<>();
        public float lastHumanVolume = -1f; public int humanSteps, humanCallouts;
        public boolean isSneaking() { return sneaking; }
        public float getSneakSpotMod() { return spotMod; }
        public long playSound(String s) { sounds.add(s); return 1L; }
        public long playSoundLocal(String s) { local.add(s); return 1L; }
        public void Say(String s) { said.add(s); }
        public float getX() { return 10.5f; } public float getY() { return 20.5f; } public float getZ() { return 0f; }
        public Object getCurrentSquare() { return null; }
        public void DoFootstepSound(float volume) { humanSteps++; lastHumanVolume = volume; }
        public void Callout() { humanCallouts++; }
        public void Callout(boolean anim) { Callout(); }
    }
    public static class Zombie {
        public int spots;
        public void spotted(Object other, boolean forced) { spots++; }
    }

    public static void main(String[] args) throws Exception {
        Instrumentation inst = ByteBuddyAgent.install();
        WolfCombatTest.installAll(inst, Character.class,
                new Class<?>[]{FootstepPatch.class, CalloutPatch.class},
                new String[]{"DoFootstepSound", "Callout"});
        WolfCombatTest.install(inst, Zombie.class, SpottedPatch.class, "spotted");
        java.lang.reflect.Field voiceClock=StealthRuntime.class.getDeclaredField("voiceClock");
        voiceClock.setAccessible(true);
        java.util.concurrent.atomic.AtomicLong voiceTime=new java.util.concurrent.atomic.AtomicLong(0);
        // Existing isolated-call tests advance beyond either gate, no sleeps.
        voiceClock.set(null,(java.util.function.LongSupplier)()->voiceTime.getAndAdd(500_000_000L));

        // Unregistered characters are untouched.
        Character human = new Character();
        human.DoFootstepSound(0.5f);
        check(human.humanSteps == 1 && human.lastHumanVolume == 0.5f, "unregistered footstep passes through unchanged");
        human.Callout();
        check(human.humanCallouts == 1, "unregistered Callout runs the engine shout");

        // Crinos: louder human footsteps, roar / growl voice.
        Character crinos = new Character();
        check(WTAGarouJava.setNoise(crinos, 1.5, 1.0, 1.0, false, ""), "setNoise accepted");
        check(WTAGarouJava.setVoice(crinos, "WTAGarou_CrinosRoar", "WTAGarou_CrinosGrowl", 45, 9), "setVoice accepted");
        check(WTAGarouJava.setVoiceText(crinos, "RAAARGH!", "*growl*"), "setVoiceText accepted");
        crinos.DoFootstepSound(0.5f);
        check(crinos.humanSteps == 1 && Math.abs(crinos.lastHumanVolume - 0.75f) < 1e-5, "Crinos footstep volume x1.5 through the human path: " + crinos.lastHumanVolume);
        check(crinos.local.isEmpty(), "no step layer unless one is registered");
        // 0.4.67: Crinos bass layer plays locally under the human step, which still runs.
        check(WTAGarouJava.setNoise(crinos, 1.5, 1.0, 1.0, false, "WTAGarou_CrinosStep"), "setNoise with a step layer accepted");
        crinos.DoFootstepSound(0.5f);
        check(crinos.humanSteps == 2 && Math.abs(crinos.lastHumanVolume - 0.75f) < 1e-5, "layered step keeps the human surface step");
        check(crinos.local.equals(List.of("WTAGarou_CrinosStep")), "Crinos bass layer played locally (not the networked path): " + crinos.local);
        check(crinos.sounds.isEmpty(), "step layer does not use character.playSound");
        crinos.Callout();
        check(crinos.humanCallouts == 0, "Crinos Callout skips the human 'Hey'");
        check(crinos.sounds.equals(List.of("WTAGarou_CrinosRoar")) && crinos.said.equals(List.of("RAAARGH!")), "standing Crinos roars");
        // 0.4.63: no shout gesture in Crinos; everything else untouched.
        check(!StealthRuntime.suppressEmote(crinos, "shout"), "shout emote plays until Lua asks otherwise");
        check(WTAGarouJava.setShoutAnim(crinos, false), "setShoutAnim accepted");
        check(StealthRuntime.suppressEmote(crinos, "shout") && StealthRuntime.suppressEmote(crinos, "Shout "), "Crinos: the shout emote is skipped (case/space tolerant)");
        check(!StealthRuntime.suppressEmote(crinos, "wavehi") && !StealthRuntime.suppressEmote(crinos, null) && !StealthRuntime.suppressEmote(null, "shout"), "other emotes, null emote, null character: never skipped");
        check(!StealthRuntime.suppressEmote(new Character(), "shout"), "a character without a profile shouts with the gesture");
        check(WTAGarouJava.setShoutAnim(crinos, true) && !StealthRuntime.suppressEmote(crinos, "shout"), "back to Homid: gesture returns");
        check(!WTAGarouJava.setShoutAnim(null, false), "null character refused");
        WTAGarouJava.setShoutAnim(crinos, false);
        check(StealthRuntime.profile(crinos).hasVoice() && "WTAGarou_CrinosRoar".equals(StealthRuntime.profile(crinos).shoutStanding), "voice profile untouched by the gesture flag (roar still routes through CalloutPatch)");
        WTAGarouJava.setShoutAnim(crinos, true);
        check(WTAGarouJava.consumeCrinosRoar(crinos),"standing roar emits one Lua bridge edge");
        check(!WTAGarouJava.consumeCrinosRoar(crinos),"edge consumed exactly once");
        crinos.sneaking = true;
        crinos.Callout();
        check(crinos.sounds.get(1).equals("WTAGarou_CrinosGrowl") && crinos.said.get(1).equals("*growl*"), "crouched Crinos growls");
        crinos.Callout(true);
        check(crinos.humanCallouts == 0 && crinos.sounds.size() == 3, "Callout(boolean) routes through the patched no-arg Callout");
        check(!WTAGarouJava.consumeCrinosRoar(crinos),"crouched growls never knock back");
        crinos.sneaking=false; crinos.Callout(true);
        check(WTAGarouJava.consumeCrinosRoar(crinos),"animated native callout produces the same roar edge");
        crinos.Callout();
        WTAGarouJava.setVoice(crinos,"","",30,6);
        check(!WTAGarouJava.consumeCrinosRoar(crinos),"leaving form clears an unconsumed edge");

        // Lupus: wolf steps replace the human bank; bark / growl voice.
        Character lupus = new Character();
        WTAGarouJava.setNoise(lupus, 0.5, 0.6, 0.5, true, "WTAGarou_WolfStep");
        WTAGarouJava.setVoice(lupus, "WTAGarou_WolfBark", "WTAGarou_WolfGrowl", 20, 4);
        lupus.DoFootstepSound(0.5f);
        check(lupus.humanSteps == 0, "wolf footstep skips the human footstep bank");
        check(lupus.local.equals(List.of("WTAGarou_WolfStep")), "wolf footstep plays the wolf step sound locally");
        lupus.DoFootstepSound(0f);
        check(lupus.humanSteps == 1, "zero-volume steps fall through untouched");
        lupus.Callout();
        check(lupus.sounds.equals(List.of("WTAGarou_WolfBark")), "standing Lupus barks");
        check(!WTAGarouJava.consumeCrinosRoar(lupus) && !WTAGarouJava.consumeCrinosRoar(human),
                "wolf and human voices never generate a Crinos burst");
        lupus.sneaking = true;
        lupus.Callout();
        check(lupus.sounds.get(1).equals("WTAGarou_WolfGrowl"), "crouched Lupus growls");
        check(lupus.said.isEmpty(), "no speech bubble when no text registered");

        // Sight: keep fraction drives skipped checks deterministically.
        Zombie z = new Zombie();
        lupus.sneaking = false;
        java.util.function.Supplier<Float> roll = () -> 0.7f;
        java.lang.reflect.Field f = StealthRuntime.class.getDeclaredField("rng"); f.setAccessible(true); f.set(null, roll);
        z.spotted(lupus, false);
        check(z.spots == 0, "roll 0.7 >= keep 0.6: standing Lupus sight check dropped");
        f.set(null, (java.util.function.Supplier<Float>) () -> 0.5f);
        z.spotted(lupus, false);
        check(z.spots == 1, "roll 0.5 < keep 0.6: sight check runs");
        lupus.sneaking = true;
        z.spotted(lupus, false);
        check(z.spots == 1, "sneaking Lupus keep 0.3: roll 0.5 dropped");
        f.set(null, (java.util.function.Supplier<Float>) () -> 0.2f);
        z.spotted(lupus, false);
        check(z.spots == 2, "sneaking Lupus keep 0.3: roll 0.2 runs");
        f.set(null, (java.util.function.Supplier<Float>) () -> 0.99f);
        z.spotted(lupus, true);
        check(z.spots == 3, "forced sight checks are never dropped");
        z.spotted(human, false);
        check(z.spots == 4, "unregistered targets are never dropped");
        z.spotted(crinos, false);
        check(z.spots == 5, "keep 1.0 never drops");
        f.set(null, null);

        // Fall sound rides on stability's allowed falls.
        WTAGarouJava.setFallSound(lupus, "WTAGarou_WolfFallOver");
        WTAGarouJava.setStability(lupus, 0.0);
        check(StabilityRuntime.filter(lupus, true, "knockdown"), "no stability: fall allowed");
        check(lupus.sounds.contains("WTAGarou_WolfFallOver"), "allowed fall plays the wolf fall-over sound");
        int before = lupus.sounds.size();
        WTAGarouJava.setStability(lupus, 1.0);
        check(!StabilityRuntime.filter(lupus, true, "knockdown"), "refused fall");
        check(lupus.sounds.size() == before, "refused fall makes no fall sound");

        // Exact real-time boundaries, independence and spam suppression.
        voiceTime.set(0);
        voiceClock.set(null,(java.util.function.LongSupplier)voiceTime::get);
        for (String standing:new String[]{"WTAGarou_WolfBark","WTAGarou_HispoBark","WTAGarou_CrinosRoar"}) {
            Character a=new Character(), b=new Character();
            WTAGarouJava.setVoice(a,standing,"WTAGarou_WolfGrowl",20,4);
            WTAGarouJava.setVoice(b,standing,"WTAGarou_WolfGrowl",20,4);
            voiceTime.set(0); a.Callout(); b.Callout();
            check(a.sounds.size()==1 && b.sounds.size()==1,"per-character gate "+standing);
            WTAGarouJava.consumeCrinosRoar(a);
            long shouts=StealthRuntime.shouts;
            for(int i=0;i<20;i++) a.Callout();
            check(a.sounds.size()==1 && a.humanCallouts==0 && StealthRuntime.shouts==shouts,
                "spam skips audio, world noise and vanilla fallback "+standing);
            check(!WTAGarouJava.consumeCrinosRoar(a),"suppressed input cannot enqueue knockback");
            voiceTime.set(199_000_000L); a.Callout(); check(a.sounds.size()==1,"199ms blocked");
            // Ordinary Lua refresh must not reset the gate.
            WTAGarouJava.setVoice(a,standing,"WTAGarou_WolfGrowl",20,4);
            a.Callout(); check(a.sounds.size()==1,"profile refresh does not bypass cooldown");
            voiceTime.set(200_000_000L); a.Callout(); check(a.sounds.size()==2,"200ms accepted");
            a.sneaking=true; a.Callout(); check(a.sounds.size()==2,"stance change cannot bypass standing gate");
            voiceTime.set(400_000_000L); a.Callout(); check(a.sounds.size()==3,"crouched call accepted");
            WTAGarouJava.consumeCrinosRoar(a);
            voiceTime.set(799_000_000L); a.Callout(); check(a.sounds.size()==3,"399ms after growl blocked");
            a.sneaking=false; a.Callout(); check(a.sounds.size()==3,"stance switch cannot bypass growl gate");
            voiceTime.set(800_000_000L); a.sneaking=true; a.Callout();
            check(a.sounds.size()==4 && !WTAGarouJava.consumeCrinosRoar(a),"400ms growl without knockback");
            WTAGarouJava.clearStealth(a); a.Callout(); check(a.humanCallouts==1,"human voice not throttled");
        }
        voiceClock.set(null,(java.util.function.LongSupplier)System::nanoTime);

        // Clearing removes the profile.
        WTAGarouJava.clearStealth(lupus);
        lupus.sneaking = false;
        lupus.DoFootstepSound(0.5f);
        check(lupus.humanSteps == 2 && lupus.lastHumanVolume == 0.5f, "cleared Lupus footsteps are human again");
        check(WTAGarouJava.status().contains("stealth profiles="), "status reports stealth");
        System.out.println("PASS: " + checks + " stealth/voice assertions with real ZombieBuddy advice.");
    }
}
