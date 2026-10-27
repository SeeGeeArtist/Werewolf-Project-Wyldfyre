import wtagarou.visuals.*;

/** 0.4.72: real ZombieBuddy advice on a fixture shaped like BodyPart.AddDamage
 *  (the acute-hit funnel) -- per-form damage intake / health pool. */
public class ToughnessTest {
    static int checks;
    static void check(boolean ok, String why) { checks++; if (!ok) throw new AssertionError("FAIL: " + why); }

    public static class Player { public final String name; Player(String n) { name = n; } }
    public static class BodyPart {
        public final Player parentChar; public float health = 100f;
        BodyPart(Player p) { parentChar = p; }
        public void AddDamage(float val) { ReduceHealth(val); }
        public void ReduceHealth(float val) { health = Math.max(0f, Math.min(100f, health - val)); }
    }

    public static void main(String[] args) throws Exception {
        var inst = net.bytebuddy.agent.ByteBuddyAgent.install();
        WolfCombatTest.install(inst, BodyPart.class, ToughnessPatch.class, "AddDamage");

        Player human = new Player("human"), crinos = new Player("crinos"), glabro = new Player("glabro");
        check(WTAGarouJava.setDamageIntake(crinos, 0.4), "Crinos intake registered");
        check(WTAGarouJava.setDamageIntake(glabro, 0.65), "Glabro intake registered");
        check(!WTAGarouJava.setDamageIntake(null, 0.4) && !WTAGarouJava.setDamageIntake(crinos, Double.NaN), "null / NaN rejected");
        WTAGarouJava.setDamageIntake(crinos, 0.4);

        BodyPart hTorso = new BodyPart(human), cTorso = new BodyPart(crinos), gTorso = new BodyPart(glabro);
        hTorso.AddDamage(40f); cTorso.AddDamage(40f); gTorso.AddDamage(40f);
        check(hTorso.health == 60f, "human takes the full hit: " + hTorso.health);
        check(Math.abs(cTorso.health - 84f) < 1e-4, "Crinos takes 40% of it: " + cTorso.health);
        check(Math.abs(gTorso.health - 74f) < 1e-4, "Glabro takes 65%: " + gTorso.health);

        // Ongoing damage (bleeding / deep wound) uses ReduceHealth directly: untouched.
        cTorso.ReduceHealth(10f);
        check(Math.abs(cTorso.health - 74f) < 1e-4, "bleeding is not scaled: " + cTorso.health);

        // A point-blank shotgun on a Crinos: 5 pellets at Rand(2,2.5)*15 ~ 33 each, with the
        // part weights calculateOverallHealth applies (upper torso x2, head/neck x4) folded in.
        float[] average = { 33f * 2, 33f, 33f, 33f, 33f };            // 198 raw: dead human, standing Crinos
        float[] unlucky = { 33f * 2, 33f, 33f, 33f * 4, 33f };        // 297 raw: a head pellet, dead Crinos
        for (float[] blast : new float[][]{ average, unlucky }) {
            float lost = 0;
            for (float pellet : blast) { BodyPart part = new BodyPart(crinos); part.AddDamage(pellet); lost += 100f - part.health; }
            if (blast == average) check(lost < 100f && lost > 70f, "average point-blank blast leaves a healthy Crinos standing with little left: " + lost);
            else check(lost > 100f, "two head/neck-weighted pellets still kill: " + lost);
        }
        float humanLost = 0; for (float pellet : average) { BodyPart part = new BodyPart(human); part.AddDamage(pellet); humanLost += 100f - part.health; }
        check(humanLost > 100f, "the same average blast kills a human: " + humanLost);

        // Clearing: factor 1 (Homid/Lupus) or 0 removes the flag.
        check(WTAGarouJava.setDamageIntake(crinos, 1.0), "factor 1 clears");
        BodyPart back = new BodyPart(crinos); back.AddDamage(40f);
        check(back.health == 60f, "cleared: full hit again");
        check(WTAGarouJava.toughnessStatus().contains("hits scaled="), "status line: " + WTAGarouJava.toughnessStatus());
        System.out.println("PASS: " + checks + " toughness (per-form damage intake) assertions.");
    }
}
