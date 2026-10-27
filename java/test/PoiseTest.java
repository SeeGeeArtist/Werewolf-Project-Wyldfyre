import wtagarou.visuals.*;

/** Real ZombieBuddy advice on fixtures shaped like IsoGameCharacter.setHitReaction,
 *  IsoPlayer.hitConsequences and BodyDamage.AddRandomDamageFromZombie (0.4.68 poise). */
public class PoiseTest {
    static int checks;
    static void check(boolean ok, String why) { checks++; if (!ok) throw new AssertionError("FAIL: " + why); }

    public static class HandWeapon { public boolean ranged; public boolean isRanged() { return ranged; } }
    public static class Zombie { public boolean crawling; public boolean isCrawling() { return crawling; } }
    public static class BodyDamage {
        final Player parent; BodyDamage(Player p) { parent = p; }
        public Player getParentChar() { return parent; }
        /** Engine shape: the reaction is stored, then damage is rolled. */
        public boolean AddRandomDamageFromZombie(Zombie z, String hitReaction, int part) {
            parent.setHitReaction(hitReaction + "LEFT");
            parent.damageTaken++;
            return true;
        }
    }
    public static class Player {
        public String hitReaction = ""; public int damageTaken, knockdowns, lungeStaggers; public final BodyDamage body = new BodyDamage(this);
        /** 0.4.69: fence/window climb lunge (ClimbOverFenceState CheckAttack). */
        public void attackFromWindowsLunge(Zombie zombie) { lungeStaggers++; hitReaction = "stagger-bump"; }
        public void setHitReaction(String r) { hitReaction = r; }
        public String getHitReaction() { return hitReaction; }
        public void setKnockedDown(boolean v) { if (v) knockdowns++; }
        public void hitConsequences(HandWeapon weapon, Object wielder, boolean ignoreDamage, float damage, boolean remote) {
            setKnockedDown(false);
            setHitReaction("HitReaction");
            damageTaken++;
        }
    }

    public static void main(String[] args) throws Exception {
        var inst = net.bytebuddy.agent.ByteBuddyAgent.install();
        WolfCombatTest.installAll(inst, Player.class,
                new Class<?>[]{PoisePatch.class, PoiseWeaponHitPatch.class, PoiseLungePatch.class},
                new String[]{"setHitReaction", "hitConsequences", "attackFromWindowsLunge"});
        WolfCombatTest.install(inst, BodyDamage.class, PoiseZombieHitPatch.class, "AddRandomDamageFromZombie");

        Player human = new Player(), crinos = new Player();
        check(WTAGarouJava.setPoise(crinos, 1.0), "full poise registered");
        check(!WTAGarouJava.setPoise(null, 1.0) && !WTAGarouJava.setPoise(crinos, Double.NaN), "null/NaN rejected");
        WTAGarouJava.setPoise(crinos, 1.0);
        Zombie walker = new Zombie(), crawler = new Zombie(); crawler.crawling = true;
        HandWeapon bat = new HandWeapon(), rifle = new HandWeapon(); rifle.ranged = true;

        human.body.AddRandomDamageFromZombie(walker, "Scratch", -1);
        check("ScratchLEFT".equals(human.hitReaction) && human.damageTaken == 1, "human flinches from a zombie as vanilla");
        crinos.body.AddRandomDamageFromZombie(walker, "Scratch", -1);
        check("".equals(crinos.hitReaction) && crinos.damageTaken == 1, "Crinos: zombie flinch shrugged, damage still rolled");
        crinos.body.AddRandomDamageFromZombie(crawler, "Lunge", -1);
        check("".equals(crinos.hitReaction) && crinos.damageTaken == 2, "crawler lunge flinch shrugged too");
        crinos.body.AddRandomDamageFromZombie(walker, "Bite", -1);
        check("".equals(crinos.hitReaction) && crinos.damageTaken == 3, "bite stagger shrugged; the bite damage roll is untouched");

        crinos.hitConsequences(bat, human, false, 1f, false);
        check("".equals(crinos.hitReaction) && crinos.damageTaken == 4, "melee weapon flinch shrugged");
        crinos.hitConsequences(rifle, human, false, 1f, false);
        check("HitReaction".equals(crinos.hitReaction) && PoiseRuntime.rangedKept == 1, "a bullet always staggers");
        human.hitConsequences(bat, crinos, false, 1f, false);
        check("HitReaction".equals(human.hitReaction), "unflagged victim flinches");

        crinos.setHitReaction("Floor");
        check("Floor".equals(crinos.hitReaction), "outside a hit the setter is untouched (Floor)");
        crinos.setHitReaction("HitReaction");
        check("HitReaction".equals(crinos.hitReaction), "outside a hit the setter is untouched (vehicle-style HitReaction)");
        crinos.setHitReaction("");

        // EndDeath (drag-down) is never filtered even inside a zombie hit.
        BodyDamage dragged = new BodyDamage(crinos) {
            @Override public boolean AddRandomDamageFromZombie(Zombie z, String r, int p) { parent.setHitReaction("EndDeath"); return true; }
        };
        WolfCombatTest.install(inst, dragged.getClass(), PoiseZombieHitPatch.class, "AddRandomDamageFromZombie");
        dragged.AddRandomDamageFromZombie(walker, "Bite", -1);
        check("EndDeath".equals(crinos.hitReaction), "drag-down death is never shrugged");

        // 0.4.69: the climb lunge has its own stagger path (no hit-reaction string).
        human.attackFromWindowsLunge(walker);
        check(human.lungeStaggers == 1 && "stagger-bump".equals(human.hitReaction), "human: fence-flop lunge staggers as vanilla");
        WTAGarouJava.setPoise(crinos, 1.0); crinos.hitReaction = "";
        crinos.attackFromWindowsLunge(walker);
        check(crinos.lungeStaggers == 0 && crinos.hitReaction.isEmpty() && PoiseRuntime.lungesShrugged == 1,
                "full poise: the fence-flop lunge is skipped whole (no stagger, no fall roll)");
        WTAGarouJava.setPoise(crinos, 0.85);
        int lunges = 0;
        for (int i = 0; i < 4000; i++) { crinos.lungeStaggers = 0; crinos.attackFromWindowsLunge(walker); lunges += crinos.lungeStaggers; }
        check(lunges > 400 && lunges < 800, "0.85 poise lets roughly 15% of climb lunges through: " + lunges);
        check(PoiseRuntime.status().contains("climb lunges shrugged="), "status reports the lunge counters");

        WTAGarouJava.setPoise(crinos, 0.85);
        int flinches = 0;
        for (int i = 0; i < 4000; i++) { crinos.body.AddRandomDamageFromZombie(walker, "Scratch", -1); if (!crinos.hitReaction.isEmpty()) flinches++; }
        check(flinches > 400 && flinches < 800, "0.85 poise still lets roughly 15% of flinches through: " + flinches);

        WTAGarouJava.clear(crinos);
        crinos.body.AddRandomDamageFromZombie(walker, "Scratch", -1);
        check("ScratchLEFT".equals(crinos.hitReaction), "clear() removes poise with the rest of the state");
        check(PoiseRuntime.status().contains("shrugged="), "status reports counters");
        System.out.println("PASS: " + checks + " poise assertions with real ZombieBuddy advice.");
    }
}
