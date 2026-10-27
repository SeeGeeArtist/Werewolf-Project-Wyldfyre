import java.util.ArrayList;
import java.util.List;
import wtagarou.visuals.*;

/** Real ZombieBuddy advice on fixtures shaped like IsoGridSquare.testCollideAdjacent
 *  and IsoMovingObject.checkHitWall (0.4.68 tall-form doorway rules). */
public class DoorwayTest {
    static int checks;
    static void check(boolean ok, String why) { checks++; if (!ok) throw new AssertionError("FAIL: " + why); }
    static long now = 1_000_000L;

    public enum IsoFlagType { DoorWallN, DoorWallW, WallN }
    /** 0.4.70: IsoGridSquare has these overloads too; the first `has` that
     *  getMethods() returns must not decide which enum the flag is parsed as. */
    public enum IsoPropertyType { WaterAmount }
    public enum IsoObjectType { doorN }
    public static class Cell {
        final Square[][] grid = new Square[6][6];
        Cell() { for (int x = 0; x < 6; x++) for (int y = 0; y < 6; y++) grid[x][y] = new Square(this, x, y); }
        public Square getGridSquare(int x, int y, int z) { return (x < 0 || y < 0 || x > 5 || y > 5 || z != 0) ? null : grid[x][y]; }
    }
    public static class Square {
        final Cell cell; final int x, y; final List<IsoFlagType> flags = new ArrayList<>();
        IsoDoor doorN, doorW; IsoWindow windowN; public boolean vanillaBlocked;
        Square(Cell c, int x, int y) { cell = c; this.x = x; this.y = y; }
        public Cell getCell() { return cell; }
        public int getX() { return x; } public int getY() { return y; } public int getZ() { return 0; }
        public boolean has(IsoFlagType f) { return flags.contains(f); }
        public boolean has(IsoPropertyType p) { throw new IllegalStateException("wrong overload: has(IsoPropertyType)"); }
        public boolean has(IsoObjectType t) { throw new IllegalStateException("wrong overload: has(IsoObjectType)"); }
        public boolean has(String s) { throw new IllegalStateException("wrong overload: has(String) tried before has(IsoFlagType)"); }
        public Object getDoorFrameTo(Square next) {
            if (next.y < y && doorN != null) return doorN;
            if (next.y > y && next.doorN != null) return next.doorN;
            if (next.x < x && doorW != null) return doorW;
            if (next.x > x && next.doorW != null) return next.doorW;
            return null;
        }
        public IsoWindow getWindowTo(Square next) {
            if (next.y < y) return windowN;
            if (next.y > y) return next.windowN;
            return null;
        }
        /** Engine signature; the body stands in for the collide matrix. */
        public boolean testCollideAdjacent(Mover mover, int dx, int dy, int dz) { return vanillaBlocked; }
    }
    public static class IsoDoor {
        public boolean open, destroyed, barricaded, locked, lockedByKey, north = true; public String prefix = "WoodDoor";
        public boolean IsOpen() { return open; } public boolean isDestroyed() { return destroyed; }
        public boolean isBarricaded() { return barricaded; } public boolean isLocked() { return locked; }
        public boolean isLockedByKey() { return lockedByKey; } public boolean getNorth() { return north; }
        public String getSoundPrefix() { return prefix; }
    }
    public static class IsoWindow {
        public boolean barricaded, destroyed, climbable = true; public int climbs;
        public boolean isBarricaded() { return barricaded; } public boolean isDestroyed() { return destroyed; }
        public boolean canClimbThrough(Mover m) { return climbable; }
    }
    public static class Mover {
        public boolean local = true, sneaking, running, sprinting, collidedDoor, collidedN;
        public Object collidedObject; public Square current; public float px, py; public int stumbles, sneakSets;
        public boolean isLocalPlayer() { return local; }
        public boolean isSneaking() { return sneaking; } public void setSneaking(boolean v) { sneaking = v; sneakSets++; }
        public boolean isRunning() { return running; } public boolean isSprinting() { return sprinting; }
        public float getX() { return px; } public float getY() { return py; }
        public boolean isCollidedWithDoor() { return collidedDoor; } public Object getCollidedObject() { return collidedObject; }
        public boolean isCollidedN() { return collidedN; } public boolean isCollidedS() { return false; }
        public boolean isCollidedW() { return false; } public boolean isCollidedE() { return false; }
        public Square getCurrentSquare() { return current; }
        public void climbThroughWindow(IsoWindow w) { w.climbs++; }
        /** Engine shape (private void checkHitWall()); the body is the stumble. */
        private void checkHitWall() { stumbles++; }
        public void sprintFrame() { checkHitWall(); }
    }

    public static void main(String[] args) throws Exception {
        var inst = net.bytebuddy.agent.ByteBuddyAgent.install();
        WolfCombatTest.install(inst, Square.class, DoorwayCollisionPatch.class, "testCollideAdjacent");
        WolfCombatTest.install(inst, Mover.class, DoorChargePatch.class, "checkHitWall");
        java.lang.reflect.Field clock = DoorwayRuntime.class.getDeclaredField("clock");
        clock.setAccessible(true); clock.set(null, (java.util.function.LongSupplier) () -> now);

        Cell cell = new Cell();
        Square inside = cell.getGridSquare(2, 2, 0), outside = cell.getGridSquare(2, 1, 0), plain = cell.getGridSquare(4, 4, 0);
        inside.flags.add(IsoFlagType.DoorWallN);              // empty frame on inside's north edge
        IsoDoor openDoor = new IsoDoor(); openDoor.open = true;
        Square hall = cell.getGridSquare(3, 3, 0); hall.doorW = openDoor;   // open door on hall's west edge

        Mover human = new Mover(), crinos = new Mover();
        check(WTAGarouJava.setTallForm(crinos, true) && WTAGarouJava.isTallForm(crinos), "tall flag stored");
        check(!WTAGarouJava.setTallForm(null, true), "null rejected");

        // --- 0.4.71: shipped default = doorway duck/refusal OFF ------------------
        check(!DoorwayRuntime.DUCK_ENABLED, "doorway duck is retired by default (0.4.71)");
        check(!inside.testCollideAdjacent(crinos, 0, -1, 0), "default: upright Crinos walks through the frame like vanilla");
        check(!outside.testCollideAdjacent(crinos, 0, 1, 0), "default: ...from either side");
        check(!WTAGarouJava.tickDoorway(crinos, 50) && DoorwayRuntime.blocked == 0, "default: no hint, nothing counted");
        DoorwayRuntime.DUCK_ENABLED = true;                   // the mechanism itself stays under test
        // --- doorway crossing --------------------------------------------------
        check(!inside.testCollideAdjacent(human, 0, -1, 0), "human walks through the frame (vanilla answer kept)");
        check(inside.testCollideAdjacent(crinos, 0, -1, 0), "upright walking Crinos refused at an empty frame (N edge)");
        check(outside.testCollideAdjacent(crinos, 0, 1, 0), "...and from the other side (S step onto the frame square)");
        check(WTAGarouJava.tickDoorway(crinos, 50), "hint is fresh right after a refusal");
        now += 1000; check(!WTAGarouJava.tickDoorway(crinos, 50), "hint fades");
        check(!plain.testCollideAdjacent(crinos, 0, -1, 0), "no doorway: pass");
        check(!inside.testCollideAdjacent(crinos, -1, -1, 0), "diagonal steps are the engine's business");
        check(!inside.testCollideAdjacent(crinos, 0, -1, 1), "z steps are the engine's business");
        plain.vanillaBlocked = true;
        check(plain.testCollideAdjacent(crinos, 0, -1, 0), "a vanilla block is never cleared");
        plain.vanillaBlocked = false;
        Square west = cell.getGridSquare(2, 3, 0);
        check(west.testCollideAdjacent(crinos, 1, 0, 0), "upright walk refused at an OPEN door on the next square's W edge");
        check(hall.testCollideAdjacent(crinos, -1, 0, 0), "...and leaving through it");
        crinos.sneaking = true;
        check(!west.testCollideAdjacent(crinos, 1, 0, 0) && !inside.testCollideAdjacent(crinos, 0, -1, 0), "crouched Crinos fits");
        crinos.sneaking = false; crinos.local = false;
        check(!inside.testCollideAdjacent(crinos, 0, -1, 0), "remote players are replicated, never blocked");
        crinos.local = true;

        // --- the automatic duck at a run ----------------------------------------
        crinos.running = true; crinos.px = 2.5f; crinos.py = 2.6f;
        check(!inside.testCollideAdjacent(crinos, 0, -1, 0), "jogging Crinos passes");
        check(crinos.sneaking, "...because sneak was forced on (the duck)");
        check(DoorwayRuntime.ducked == 1, "one duck counted");
        crinos.py = 2.1f; WTAGarouJava.tickDoorway(crinos, 50);
        check(crinos.sneaking, "still ducked while within a tile of the frame");
        crinos.py = 0.9f; WTAGarouJava.tickDoorway(crinos, 50);
        check(!crinos.sneaking && DoorwayRuntime.released == 1, "duck released a tile past the frame: sneak restored to OFF");
        crinos.sneaking = true; crinos.py = 2.6f;                     // manually crouched before the doorway
        check(!inside.testCollideAdjacent(crinos, 0, -1, 0), "crouched jog passes without engaging a duck");
        check(DoorwayRuntime.ducked == 1, "no duck when already sneaking");
        crinos.sneaking = false; crinos.running = false; crinos.sprinting = true;
        check(!inside.testCollideAdjacent(crinos, 0, -1, 0) && crinos.sneaking, "sprint ducks too");
        crinos.sneaking = false;                                     // player toggled sneak off mid-duck
        crinos.py = 2.4f; WTAGarouJava.tickDoorway(crinos, 50);
        check(!crinos.sneaking, "a manual toggle during the duck is respected");
        check(!inside.testCollideAdjacent(crinos, 0, -1, 0) && crinos.sneaking, "re-engage");
        now += 3000; WTAGarouJava.tickDoorway(crinos, 50);
        check(!crinos.sneaking, "timeout releases a stalled duck");
        crinos.sprinting = false;

        // --- sprint charge: doors ----------------------------------------------
        IsoDoor wood = new IsoDoor();
        human.sprinting = true; human.collidedDoor = true; human.collidedObject = wood;
        human.sprintFrame(); check(human.stumbles == 1, "human sprinting into a door stumbles as vanilla");
        crinos.sprinting = true; crinos.collidedDoor = true; crinos.collidedObject = wood;
        WTAGarouJava.tickDoorway(crinos, 5);
        crinos.sprintFrame(); check(crinos.stumbles == 1 && DoorwayRuntime.refusedNoRage == 1, "5 Rage: no charge, vanilla stumble");
        check(WTAGarouJava.pollDoorCharge(crinos) == null, "nothing pending");
        WTAGarouJava.tickDoorway(crinos, 11);
        crinos.sprintFrame(); check(crinos.stumbles == 2 && DoorwayRuntime.refusedNoRage == 2, "11 Rage: still short of the 12 (0.4.69), vanilla stumble");
        now += 2000;
        WTAGarouJava.tickDoorway(crinos, 13);
        crinos.sprintFrame(); check(crinos.stumbles == 2, "13 Rage: wooden door charged, stumble skipped");
        check(WTAGarouJava.pollDoorCharge(crinos) == wood && WTAGarouJava.pollDoorCharge(crinos) == null, "door reported once");
        crinos.sprintFrame(); check(crinos.stumbles == 2 && DoorwayRuntime.doorCharges == 1, "same door within the debounce: still no stumble, no second report");
        now += 2000;
        wood.locked = true;
        crinos.sprintFrame(); check(crinos.stumbles == 3 && DoorwayRuntime.refusedNoRage == 3, "LOCKED needs 18 Rage: 13 is a stumble");
        WTAGarouJava.tickDoorway(crinos, 60);
        crinos.sprintFrame(); check(crinos.stumbles == 3 && WTAGarouJava.pollDoorCharge(crinos) == wood, "60 Rage charges the locked door");
        now += 2000;
        IsoDoor metal = new IsoDoor(); metal.prefix = "MetalDoor"; crinos.collidedObject = metal;
        crinos.sprintFrame(); check(crinos.stumbles == 4 && DoorwayRuntime.refusedKind == 1, "metal door: vanilla stumble");
        IsoDoor barred = new IsoDoor(); barred.barricaded = true; crinos.collidedObject = barred;
        crinos.sprintFrame(); check(crinos.stumbles == 5, "barricaded door: vanilla stumble");
        IsoDoor ajar = new IsoDoor(); ajar.open = true; crinos.collidedObject = ajar;
        crinos.sprintFrame(); check(crinos.stumbles == 6, "open door: vanilla stumble");
        crinos.sprinting = false; crinos.collidedObject = wood;
        crinos.sprintFrame(); check(crinos.stumbles == 7, "not sprinting: never a charge");
        crinos.sprinting = true;

        // --- sprint charge: windows --------------------------------------------
        IsoWindow glass = new IsoWindow();
        Square room = cell.getGridSquare(1, 1, 0); room.windowN = glass;
        crinos.collidedDoor = false; crinos.collidedObject = null; crinos.current = room; crinos.collidedN = true;
        // 0.4.69: window charge disabled by default (glass broke, Crinos never moved through).
        crinos.sprintFrame(); check(crinos.stumbles == 8 && glass.climbs == 0 && DoorwayRuntime.windowCharges == 0, "window charge off: sprint into a window is the vanilla stumble");
        crinos.stumbles = 7; DoorwayRuntime.WINDOW_CHARGE = true;
        crinos.sprintFrame(); check(crinos.stumbles == 7 && glass.climbs == 1 && DoorwayRuntime.windowCharges == 1, "(harness flag) sprint into a window: climb started, no stumble");
        crinos.sprintFrame(); check(glass.climbs == 1 && crinos.stumbles == 7, "debounced while the climb starts");
        now += 2000; glass.barricaded = true;
        crinos.sprintFrame(); check(crinos.stumbles == 8, "barricaded window: vanilla stumble");
        glass.barricaded = false; glass.climbable = false;
        crinos.sprintFrame(); check(crinos.stumbles == 9, "unclimbable window: vanilla stumble");
        human.collidedDoor = false; human.current = room; human.collidedN = true; glass.climbable = true;
        human.sprintFrame(); check(human.stumbles == 2 && glass.climbs == 1, "human never charges a window");
        DoorwayRuntime.WINDOW_CHARGE = false;

        WTAGarouJava.clear(crinos);
        check(!WTAGarouJava.isTallForm(crinos), "clear() drops the tall flag");
        check(inside.testCollideAdjacent(crinos, 0, -1, 0) == false, "cleared character walks through upright");
        check(DoorwayRuntime.status().contains("door charges=") && DoorwayRuntime.status().contains("hook calls="), "status reports counters incl. 0.4.70 hook/edge diagnostics");
        check(!DoorwayRuntime.status().contains("error="), "no swallowed exception in any doorway path of this run");
        System.out.println("PASS: " + checks + " doorway assertions with real ZombieBuddy advice.");
    }
}
