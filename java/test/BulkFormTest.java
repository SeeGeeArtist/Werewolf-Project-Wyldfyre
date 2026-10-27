import java.lang.instrument.Instrumentation;
import net.bytebuddy.agent.ByteBuddyAgent;
import wtagarou.visuals.*;

/** Real ZombieBuddy advice on fixtures shaped like BaseVehicle.isEnterBlocked and IsoGameCharacter.climbThroughWindow. */
public final class BulkFormTest {
    static int checks;
    static void check(boolean ok, String why) { checks++; if (!ok) throw new AssertionError("FAIL: " + why); }

    public static class BodyDamage { public int cuts; public Object setScratchedWindow() { cuts++; return null; } }
    public static class Character {
        public final BodyDamage body = new BodyDamage();
        public int climbs; public String lastVoice;
        public BodyDamage getBodyDamage() { return body; }
        public long playerVoiceSound(String name) { lastVoice = name; return 1L; }
        public void climbThroughWindow(IsoWindow window) { climbs++; window.climbedThrough++; }
    }
    /** Simple name "IsoWindow" is what the runtime recognises on the fixture. */
    public static class IsoWindow {
        public boolean smashed, destroyed, barricaded; public int hits, climbedThrough; public Object hitBy, hitWeapon;
        public boolean isSmashed() { return smashed; }
        public boolean isDestroyed() { return destroyed; }
        public boolean isBarricaded() { return barricaded; }
        public void WeaponHit(Character chr, Object weapon) { hits++; hitBy = chr; hitWeapon = weapon; smashed = true; }
        public void smashWindow() { smashed = true; }
    }
    public static class Vehicle {
        public boolean vanillaBlocked;
        public boolean isEnterBlocked(Character chr, int seat) { return vanillaBlocked; }
    }

    public static void main(String[] args) throws Exception {
        Instrumentation inst = ByteBuddyAgent.install();
        WolfCombatTest.install(inst, Vehicle.class, VehicleEntryPatch.class, "isEnterBlocked");
        WolfCombatTest.install(inst, Character.class, WindowClimbPatch.class, "climbThroughWindow");

        Character human = new Character(), crinos = new Character();
        check(WTAGarouJava.setBulkForm(crinos, true) && WTAGarouJava.isBulkForm(crinos), "bulk flag stored");
        check(!WTAGarouJava.isBulkForm(human), "unflagged character is not bulk");
        check(!WTAGarouJava.setBulkForm(null, true), "null character rejected");

        Vehicle car = new Vehicle();
        check(!car.isEnterBlocked(human, 0), "human may enter (vanilla answer kept)");
        check(car.isEnterBlocked(crinos, 0), "Crinos/Hispo entry blocked");
        car.vanillaBlocked = true;
        check(car.isEnterBlocked(human, 0), "vanilla block is never cleared");
        check(BulkFormRuntime.entriesBlocked.get() == 1, "one bulk refusal counted");

        IsoWindow open = new IsoWindow();
        human.climbThroughWindow(open);
        check(human.climbs == 1 && open.hits == 0 && !open.smashed && human.body.cuts == 0, "human climbs an open window untouched");
        crinos.climbThroughWindow(open);
        check(crinos.climbs == 1 && open.climbedThrough == 2, "bulk climb still happens");
        check(open.hits == 1 && open.hitBy == crinos && open.hitWeapon == null && open.smashed,
                "open window smashed bare-handed (WeaponHit(chr, null)) before the climb");
        check(crinos.body.cuts == 1 && "PainFromGlassCut".equals(crinos.lastVoice), "climber takes the bare-handed glass cut");
        crinos.climbThroughWindow(open);
        check(open.hits == 1 && crinos.body.cuts == 1 && crinos.climbs == 2, "already smashed window passes untouched");
        IsoWindow gone = new IsoWindow(); gone.destroyed = true;
        crinos.climbThroughWindow(gone);
        check(gone.hits == 0 && crinos.body.cuts == 1, "destroyed window passes untouched");
        IsoWindow boarded = new IsoWindow(); boarded.barricaded = true;
        crinos.climbThroughWindow(boarded);
        check(boarded.hits == 0, "barricaded window is left to vanilla");
        WTAGarouJava.setBulkForm(crinos, false);
        IsoWindow later = new IsoWindow();
        crinos.climbThroughWindow(later);
        check(later.hits == 0 && !later.smashed, "flag cleared: back to vanilla climbing");
        check(!car.isEnterBlocked(crinos, 0) || car.vanillaBlocked, "flag cleared: vanilla entry answer");
        car.vanillaBlocked = false;
        check(!car.isEnterBlocked(crinos, 0), "flag cleared: may enter again");
        check(BulkFormRuntime.windowsSmashed.get() == 1 && BulkFormRuntime.failures.get() == 0,
                "one smash, no reflection failures: " + BulkFormRuntime.status());
        System.out.println("BulkFormTest passed " + checks + " checks; " + BulkFormRuntime.status());
    }
}
