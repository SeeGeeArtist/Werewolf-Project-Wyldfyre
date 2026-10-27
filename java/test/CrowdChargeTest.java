import wtagarou.visuals.*;

/** 0.4.69: sprinting Crinos knocks down the first zombies it runs into
 *  instead of stumbling; the crowd stops it after the limit. Mirrors the
 *  IsoMovingObject.separate() bump sequence against fixture classes. */
public class CrowdChargeTest {
    static int checks;
    static void check(boolean ok, String why) { checks++; if (!ok) throw new AssertionError("FAIL: " + why); }
    static long now = 1_000_000;

    public static class Character {
        public String bumpType = ""; public boolean bumpFall; public Object bumpedChr; public boolean sprinting;
        public int events;
        public boolean isSprinting() { return sprinting; }
        public boolean isBehind(Character other) { return other != null && other.behindMe; }
        public boolean behindMe;
        public void setBumpedChr(Character other) { bumpedChr = other; }
        public void setBumpType(String type) { bumpType = type; }
        public void setBumpFall(boolean fall) { bumpFall = fall; }
    }
    public static class Zombie extends Character {
        public int knockdowns; public boolean fromBehind, onFloor;
        public boolean isOnFloor() { return onFloor; }
        public void knockDown(boolean hitFromBehind) { knockdowns++; fromBehind = hitFromBehind; onFloor = true; }
    }
    /** zombie.characters.action.ActionContextEvents shape. */
    public static class Events {
        public int added;
        public synchronized void add(String name, String state) { added++; }
    }

    /** The separate() sequence for a running player overlapping a zombie. */
    static void bump(Character player, Zombie zombie, Events events) {
        if (player.sprinting) player.setBumpFall(true);
        player.setBumpedChr(zombie);
        player.setBumpType("left");
        zombie.setBumpType("bumped");
        events.add("wasBumped", null);
    }

    public static void main(String[] args) throws Exception {
        var inst = net.bytebuddy.agent.ByteBuddyAgent.install();
        WolfCombatTest.installAll(inst, Character.class,
                new Class<?>[]{CrowdChargeBumpedPatch.class, CrowdChargeBumpTypePatch.class, StabilityBumpFallPatch.class},
                new String[]{"setBumpedChr", "setBumpType", "setBumpFall"});
        WolfCombatTest.install(inst, Events.class, CrowdChargeEventPatch.class, "add");
        CrowdChargeRuntime.clock = () -> now;

        Events events = new Events();
        Character human = new Character(); human.sprinting = true;
        Zombie z = new Zombie();
        bump(human, z, events);
        check(human.bumpType.equals("left") && human.bumpFall && z.bumpType.equals("bumped") && z.knockdowns == 0 && events.added == 1,
                "no rule: vanilla sprint bump (stumble, trip roll, zombie flinch, event)");

        Character crinos = new Character(); crinos.sprinting = true;
        check(WTAGarouJava.setCrowdCharge(crinos, 3, 3.0), "rule registered");
        check(!WTAGarouJava.setCrowdCharge(crinos, Double.NaN, 3.0), "NaN rejected");
        WTAGarouJava.setStability(crinos, 0.0);  // make sure the fall filter alone is not what saves it
        Zombie a = new Zombie(); a.behindMe = true;
        int before = events.added;
        bump(crinos, a, events);
        check(a.knockdowns == 1 && a.fromBehind, "charge: zombie knocked down (from-behind flag passed through)");
        check(crinos.bumpType.isEmpty() && !crinos.bumpFall, "charge: no stumble type, and the trip rolled before setBumpedChr is undone");
        check(a.bumpType.isEmpty(), "charge: the zombie's flinch bump is dropped (it is falling instead)");
        check(events.added == before && !CrowdChargeRuntime.scopeOpen(), "charge: wasBumped swallowed and the scope closed");
        check(crinos.bumpedChr == a, "the engine still records the bumped character");

        Zombie b = new Zombie(), c = new Zombie(), d = new Zombie();
        now += 500; bump(crinos, b, events);
        now += 500; bump(crinos, c, events);
        check(b.knockdowns == 1 && c.knockdowns == 1 && crinos.bumpType.isEmpty(), "second and third zombie inside the window still go down");
        now += 500; crinos.bumpFall = false; before = events.added;
        bump(crinos, d, events);
        check(d.knockdowns == 0 && crinos.bumpType.equals("left") && d.bumpType.equals("bumped") && events.added == before + 1,
                "fourth zombie inside 3 s: the crowd stops the charge (vanilla bump)");
        check(crinos.bumpFall, "crowd stop with zero stability: the trip roll reaches the engine again");

        now += 4000; Zombie e = new Zombie(); crinos.bumpType = ""; crinos.bumpFall = false;
        bump(crinos, e, events);
        check(e.knockdowns == 1 && crinos.bumpType.isEmpty(), "window expired: a fresh charge");

        crinos.sprinting = false; Zombie f = new Zombie(); before = events.added;
        bump(crinos, f, events);
        check(f.knockdowns == 0 && crinos.bumpType.equals("left") && events.added == before + 1, "jogging (not sprinting): vanilla bump");

        crinos.sprinting = true; Zombie g = new Zombie(); g.onFloor = true; before = events.added; crinos.bumpType = "";
        bump(crinos, g, events);
        check(g.knockdowns == 0 && events.added == before + 1, "a zombie already on the floor is not re-knocked");

        Character other = new Character(); other.sprinting = true; before = events.added; now += 10000;
        bump(other, new Zombie(), events);
        check(other.bumpType.equals("left") && events.added == before + 1, "another character's bump is never swallowed by a stale scope");

        events.add("wasBumped", null);
        check(events.added == before + 2, "wasBumped outside any charge passes through");

        WTAGarouJava.setCrowdCharge(crinos, 0, 0);
        Zombie h = new Zombie(); crinos.bumpType = "";
        bump(crinos, h, events);
        check(h.knockdowns == 0 && crinos.bumpType.equals("left"), "limit 0 clears the rule");
        WTAGarouJava.setCrowdCharge(crinos, 3, 3.0); WTAGarouJava.clear(crinos);
        check(!CrowdChargeRuntime.active(crinos), "clear() drops the rule with the rest of the state");
        check(WTAGarouJava.crowdChargeStatus().contains("knockdowns=4"), "status counts knockdowns: " + WTAGarouJava.crowdChargeStatus());
        System.out.println("CrowdChargeTest passed " + checks + " checks");
    }
}
