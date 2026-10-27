import java.lang.instrument.Instrumentation;
import java.util.HashMap;
import java.util.Map;
import net.bytebuddy.agent.ByteBuddyAgent;
import wtagarou.visuals.*;
import zombie.characters.CharacterStat;

/** Real ZombieBuddy advice on fixtures shaped like the four engine funnels. */
public final class TraitsTest {
    static int checks;
    static void check(boolean ok, String why) { checks++; if (!ok) throw new AssertionError("FAIL: " + why); }

    public static class Stats {
        public final Map<CharacterStat, Float> values = new HashMap<>();
        public float get(CharacterStat s) { return values.getOrDefault(s, 0f); }
        public boolean set(CharacterStat s, float v) { values.put(s, v); return true; }
        public boolean add(CharacterStat s, float v) { values.put(s, get(s) + v); return true; }
    }
    public static class Food {
        public boolean dangerous, cooked, rotten, tainted;
        public int poison;
        public boolean isbDangerousUncooked() { return dangerous; }
        public boolean isCooked() { return cooked; }
        public boolean isRotten() { return rotten; }
        public boolean isTainted() { return tainted; }
        public int getPoisonPower() { return poison; }
    }
    public static class Player {
        public boolean sneaking, running, sprinting;
        public final Map<String, Float> vars = new HashMap<>();
        public int footLoops, movementRates;
        public final Stats stats = new Stats();
        public boolean isSneaking() { return sneaking; }
        public boolean isRunning() { return running; }
        public boolean isSprinting() { return sprinting; }
        public Stats getStats() { return stats; }
        public float getVariableFloat(String k, float def) { return vars.getOrDefault(k, def); }
        public Object setVariable(String k, float v) { vars.put(k, v); return null; }
        public float getTurnDelta() { return sprinting ? 0.75f : running ? 0.8f : 1.0f; }
        public void updateFootInjuries() { footLoops++; }
        /** Vanilla shape: compute speeds, then the barefoot loop. */
        public void updateMovementRates() {
            movementRates++;
            boolean runOrSprint = running || sprinting;
            float walk = 0.8f * 0.85f, run = 0.65f * 0.85f;  // no shoes: x0.85 in updateSpeedModifiers
            vars.put("WalkSpeed", runOrSprint ? run : walk);
            vars.put("RunSpeed", run);
            updateFootInjuries();
        }
    }
    public static class BodyDamage {
        public final Player parent; public BodyDamage(Player p) { parent = p; }
        public Player getParentChar() { return parent; }
        public void JustAteFood(Food food) { JustAteFood(food, 100f); }
        public void JustAteFood(Food food, float percentage) {
            if (!food.isCooked() && food.isbDangerousUncooked()) parent.stats.add(CharacterStat.POISON, 15f * percentage / 100f);
        }
    }

    public static void main(String[] args) throws Exception {
        Instrumentation inst = ByteBuddyAgent.install();
        WolfCombatTest.installAll(inst, Player.class,
                new Class<?>[]{FootInjuryPatch.class, MovementRatePatch.class, TurnDeltaPatch.class},
                new String[]{"updateFootInjuries", "updateMovementRates", "getTurnDelta"});
        WolfCombatTest.install(inst, BodyDamage.class, RawMeatPatch.class, "JustAteFood");

        // Pure gait selection.
        TraitsRuntime.Profile p = new TraitsRuntime.Profile();
        p.walk = 1.4f; p.run = 1.35f; p.sprint = 1.25f; p.sneak = 2.4f;
        check(TraitsRuntime.gaitMultiplier(p, false, false, false) == 1.4f, "walk multiplier");
        check(TraitsRuntime.gaitMultiplier(p, true, false, false) == 2.4f, "sneak multiplier");
        check(TraitsRuntime.gaitMultiplier(p, true, true, false) == 1.35f, "running beats sneaking");
        check(TraitsRuntime.gaitMultiplier(p, false, true, true) == 1.25f, "sprint beats run");
        check(TraitsRuntime.gaitMultiplier(null, true, true, true) == 1f, "no profile: 1");

        // Validation.
        Player homid = new Player();
        check(!WTAGarouJava.setTraits(homid, false, false, 0, 1, 1, 1, 1), "zero multiplier rejected");
        check(!WTAGarouJava.setTraits(homid, false, false, Double.NaN, 1, 1, 1, 1), "NaN rejected");
        check(!WTAGarouJava.setTraits(null, true, true, 1, 1, 1, 1, 1), "null character rejected");
        check(WTAGarouJava.setTraits(homid, false, false, 1, 1, 1, 1, 1), "identity accepted");
        check(TraitsRuntime.profile(homid) == null, "identity profile stores nothing");

        // Unregistered: vanilla everywhere.
        homid.updateMovementRates();
        check(homid.footLoops == 1, "unregistered player runs the barefoot loop");
        check(Math.abs(homid.vars.get("WalkSpeed") - 0.68f) < 1e-5, "unregistered WalkSpeed untouched");
        check(homid.getTurnDelta() == 1.0f, "unregistered turn untouched");
        BodyDamage homidBody = new BodyDamage(homid);
        Food rawBacon = new Food(); rawBacon.dangerous = true;
        homidBody.JustAteFood(rawBacon);
        check(homid.stats.get(CharacterStat.POISON) == 15f, "unregistered player is poisoned by raw bacon");

        // Lupus: paws, raw meat, wolf gaits, faster turn.
        Player lupus = new Player();
        check(WTAGarouJava.setTraits(lupus, true, true, 1.4, 1.35, 1.25, 2.4, 1.6), "Lupus traits accepted");
        lupus.updateMovementRates();
        check(lupus.footLoops == 0, "paw form skips the barefoot loop");
        check(Math.abs(lupus.vars.get("WalkSpeed") - 0.68f * 1.4f) < 1e-5, "Lupus walk x1.4: " + lupus.vars.get("WalkSpeed"));
        check(Math.abs(lupus.vars.get("RunSpeed") - 0.5525f * 1.35f) < 1e-5, "Lupus RunSpeed x1.35 while walking");
        lupus.sneaking = true; lupus.updateMovementRates();
        check(Math.abs(lupus.vars.get("WalkSpeed") - 0.68f * 2.4f) < 1e-5, "crouched Lupus walk x2.4");
        lupus.sneaking = false; lupus.running = true; lupus.updateMovementRates();
        check(Math.abs(lupus.vars.get("WalkSpeed") - 0.5525f * 1.35f) < 1e-5, "jogging Lupus x1.35 on the run value");
        lupus.sprinting = true; lupus.updateMovementRates();
        check(Math.abs(lupus.vars.get("WalkSpeed") - 0.5525f * 1.25f) < 1e-5, "sprinting Lupus x1.25");
        check(Math.abs(lupus.vars.get("RunSpeed") - 0.5525f * 1.25f) < 1e-5, "RunSpeed follows sprint multiplier");
        check(Math.abs(lupus.getTurnDelta() - 0.75f * 1.6f) < 1e-5, "sprinting turn x1.6");
        lupus.running = false; lupus.sprinting = false;
        check(Math.abs(lupus.getTurnDelta() - 1.6f) < 1e-5, "standing turn x1.6");
        check(lupus.footLoops == 0, "barefoot loop still skipped after several updates");

        BodyDamage lupusBody = new BodyDamage(lupus);
        lupus.stats.set(CharacterStat.POISON, 3f);
        lupusBody.JustAteFood(rawBacon);
        check(lupus.stats.get(CharacterStat.POISON) == 3f, "Garou raw bacon: poison unchanged (one-arg overload)");
        lupusBody.JustAteFood(rawBacon, 50f);
        check(lupus.stats.get(CharacterStat.POISON) == 3f, "Garou raw bacon: poison unchanged (partial meal)");
        rawBacon.rotten=true; lupusBody.JustAteFood(rawBacon);
        check(lupus.stats.get(CharacterStat.POISON)==18f,"rotten raw meat is not protected");
        rawBacon.rotten=false; rawBacon.tainted=true; lupusBody.JustAteFood(rawBacon);
        check(lupus.stats.get(CharacterStat.POISON)==33f,"tainted raw food is not protected");
        rawBacon.tainted=false; rawBacon.poison=10; lupusBody.JustAteFood(rawBacon);
        check(lupus.stats.get(CharacterStat.POISON)==48f,"poisoned raw food is not protected");
        rawBacon.poison=0; lupus.stats.set(CharacterStat.POISON,3f);
        Food cooked = new Food(); cooked.dangerous = true; cooked.cooked = true;
        lupusBody.JustAteFood(cooked);
        check(lupus.stats.get(CharacterStat.POISON) == 3f, "cooked meat never poisoned anyone");
        Food safeRaw = new Food();
        lupusBody.JustAteFood(safeRaw);
        check(lupus.stats.get(CharacterStat.POISON) == 3f, "non-dangerous raw food unaffected");
        // Real poison (not food) is not a meal and is never touched.
        lupus.stats.add(CharacterStat.POISON, 20f);
        check(lupus.stats.get(CharacterStat.POISON) == 23f, "bleach still poisons a Garou");

        // Homid Garou: raw meat immunity without paws or speed.
        Player homidGarou = new Player();
        check(WTAGarouJava.setTraits(homidGarou, true, false, 1, 1, 1, 1, 1), "Homid Garou traits accepted");
        homidGarou.updateMovementRates();
        check(homidGarou.footLoops == 1, "Homid keeps the barefoot loop");
        check(Math.abs(homidGarou.vars.get("WalkSpeed") - 0.68f) < 1e-5, "Homid speed untouched");
        new BodyDamage(homidGarou).JustAteFood(rawBacon);
        check(homidGarou.stats.get(CharacterStat.POISON) == 0f, "Homid Garou eats raw bacon fine");

        // Clearing restores vanilla.
        WTAGarouJava.clear(lupus);
        lupus.updateMovementRates();
        check(lupus.footLoops == 1, "cleared character runs the barefoot loop again");
        check(lupus.getTurnDelta() == 1.0f, "cleared turn back to vanilla");
        lupusBody.JustAteFood(rawBacon);
        check(lupus.stats.get(CharacterStat.POISON) == 38f, "cleared character is poisoned again");

        check(TraitsRuntime.failures.get() == 0, "no reflection failures: " + TraitsRuntime.status());
        System.out.println("TraitsTest passed " + checks + " checks; " + TraitsRuntime.status());
    }
}
