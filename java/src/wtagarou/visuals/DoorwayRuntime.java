package wtagarou.visuals;

import java.lang.reflect.Method;
import java.util.Collections;
import java.util.Map;
import java.util.WeakHashMap;

/**
 * 0.4.68: a "tall" form (Crinos, 1.65x since 0.4.69) and doorways.
 *
 * <p>Movement collision funnels through
 * {@code IsoGridSquare.testCollideAdjacent(mover, dx, dy, dz)}; the engine's
 * answer is {@code false} (pass) for an open door or an empty frame. For a
 * tall LOCAL player crossing a doorway edge this runtime decides instead:
 * <ul>
 *   <li>sneaking (crouched): pass, as vanilla;</li>
 *   <li>running or sprinting: pass, and DUCK - sneak is forced on and the
 *       prior state is restored once the player is a tile past the frame
 *       (or on a timeout). Sneak is a toggle in this engine
 *       ({@code IsoPlayer.updateSneakKey}: setSneaking(!isSneaking())), it
 *       never releases itself, so the restore is ours. A player who was
 *       already crouched stays crouched; a player who toggles sneak during
 *       the duck owns the toggle again;</li>
 *   <li>walking upright: BLOCKED (the hint timestamp is set for the HUD).</li>
 * </ul>
 *
 * <p>The sprint-into-wall stumble lives in {@code IsoMovingObject.checkHitWall}.
 * {@link #charge(Object)} runs on its entry for a tall sprinting local player:
 * a closed, unbarricaded WOODEN door (sound prefix "Wood...") is recorded as a
 * pending charge for Lua to send to the server (which breaks it and charges
 * Rage/stamina) and the stumble is skipped; a closed, unbarricaded window the
 * player can climb starts the climb (the 0.4.39 WindowClimbPatch smashes it
 * first, vanilla rolls the glass cut) and the stumble is skipped. Anything
 * else keeps the vanilla reaction.
 *
 * <p>Only methods evidenced in the pinned 42.20.2 reference are used, all by
 * name, so test fixtures can stand in for the engine classes.
 */
public final class DoorwayRuntime {
    static final class State {
        boolean tall;
        float rage;                 // last Rage pushed by Lua
        boolean duckForced, sneakBefore;
        float duckX, duckY; long duckAt;
        long hintAt;
        Object pendingDoor; long pendingAt;
        Object lastDoor; long lastDoorAt;
        Object lastWindow; long lastWindowAt;
    }
    private static final Map<Object, State> STATES = Collections.synchronizedMap(new WeakHashMap<>());
    public static volatile long blocked, ducked, released, doorCharges, windowCharges, refusedNoRage, refusedKind;
    public static volatile float RAGE_COST = 12f, RAGE_COST_LOCKED = 18f; // 0.4.69: +50% (was 8 / 12)
    /** 0.4.69: the window charge smashed the glass but never carried the
     *  Crinos through (the vanilla climb did not start from a sprint), so it
     *  is off until the climb path is sorted; a sprint into a window is the
     *  vanilla stumble again. Flip for the harness only. */
    public static volatile boolean WINDOW_CHARGE = false;
    /** 0.4.71: the doorway duck / upright refusal is OFF. Across 0.4.68-0.4.70
     *  it never engaged in play ("whatever you're building just isn't working
     *  at all", Oct 18) and the author asked to drop it; the Crinos now walks
     *  through doorways as vanilla. The sprint door charge below is unaffected.
     *  Harness flips this on to keep the mechanism's tests. */
    public static volatile boolean DUCK_ENABLED = false;
    public static volatile float RELEASE_TILES = 1.0f;
    public static volatile long DUCK_TIMEOUT_MS = 2500L;
    private static final long CHARGE_DEBOUNCE_MS = 1500L;
    private static boolean loggedBlock, loggedDuck, loggedDoor, loggedWindow;
    /** 0.4.70 diagnostics (Oct 18: no duck/refusal ever fired while the door
     *  charge on the same State did). Counts every hook call for a tall
     *  local mover, every doorway edge it recognised, and the first failure
     *  is printed instead of being swallowed. The first few edge decisions
     *  are printed too, so the next console shows what the hook saw. */
    static long tallCalls, edgeCalls;
    private static int edgeLogs;
    private static String firstError;
    private static final int EDGE_LOG_LIMIT = 6;
    static java.util.function.LongSupplier clock = System::currentTimeMillis;

    private DoorwayRuntime() {}
    private static State state(Object character) {
        return STATES.computeIfAbsent(character, k -> new State());
    }

    // ----------------------------------------------------------------- Lua API
    public static boolean setTall(Object character, boolean tall) {
        if (character == null) return false;
        if (!tall) {
            State st = STATES.get(character);
            if (st != null) { releaseDuck(character, st, "form left"); STATES.remove(character); }
            return true;
        }
        state(character).tall = true;
        return true;
    }
    public static boolean isTall(Object character) {
        State st = character == null ? null : STATES.get(character);
        return st != null && st.tall;
    }
    public static void setCosts(double rage, double rageLocked) {
        if (rage > 0) RAGE_COST = (float) rage;
        if (rageLocked > 0) RAGE_COST_LOCKED = (float) rageLocked;
    }
    public static void setDuckRule(double releaseTiles, double timeoutMs) {
        if (releaseTiles > 0) RELEASE_TILES = (float) releaseTiles;
        if (timeoutMs > 0) DUCK_TIMEOUT_MS = (long) timeoutMs;
    }
    public static void clear(Object character) {
        if (character == null) return;
        State st = STATES.remove(character);
        if (st != null && st.duckForced) releaseDuck(character, st, "clear");
    }
    public static void clearAll() { STATES.clear(); }

    /** Per-frame from Lua (local player). Pushes the current Rage, releases a
     * finished duck. Returns true while the "crouch to pass" hint is fresh. */
    public static boolean tick(Object character, double rage) {
        State st = character == null ? null : STATES.get(character);
        if (st == null) return false;
        st.rage = (float) rage;
        long now = clock.getAsLong();
        if (st.duckForced) {
            try {
                boolean sneakingNow = bool(character, "isSneaking");
                if (!sneakingNow) {
                    // The player toggled sneak themselves: hands off.
                    st.duckForced = false;
                } else {
                    float px = num(character, "getX"), py = num(character, "getY");
                    float dx = px - st.duckX, dy = py - st.duckY;
                    boolean past = dx * dx + dy * dy >= RELEASE_TILES * RELEASE_TILES;
                    if (past || now - st.duckAt > DUCK_TIMEOUT_MS) releaseDuck(character, st, past ? "past the frame" : "timeout");
                }
            } catch (Exception e) {
                st.duckForced = false;
            }
        }
        return now - st.hintAt < 400L;
    }

    /** The door recorded by the last sprint charge, once; null when none. */
    public static Object pollDoorCharge(Object character) {
        State st = character == null ? null : STATES.get(character);
        if (st == null || st.pendingDoor == null) return null;
        Object door = st.pendingDoor;
        st.pendingDoor = null;
        return door;
    }

    // --------------------------------------------------------- collision hook
    /** OnExit of IsoGridSquare.testCollideAdjacent: the value the engine should return. */
    public static boolean collide(Object square, Object mover, int dx, int dy, int dz, boolean vanilla) {
        if (!DUCK_ENABLED) return vanilla;                        // 0.4.71: doorway rule retired
        if (vanilla || square == null || mover == null) return vanilla;
        if (dz != 0 || (dx != 0 && dy != 0) || (dx == 0 && dy == 0)) return vanilla;
        State st = STATES.get(mover);
        if (st == null || !st.tall) return vanilla;
        try {
            if (!isLocal(mover)) return vanilla;
            tallCalls++;
            Object next = neighbour(square, dx, dy);
            if (next == null || !isDoorwayEdge(square, next, dx, dy)) return vanilla;
            edgeCalls++;
            boolean sneaking = bool(mover, "isSneaking");
            boolean running = bool(mover, "isRunning"), sprinting = bool(mover, "isSprinting");
            if (edgeLogs < EDGE_LOG_LIMIT) {
                edgeLogs++;
                System.out.println("[WTAGarou][Doorway] edge d=(" + dx + "," + dy + ") sneaking=" + sneaking
                        + " running=" + running + " sprinting=" + sprinting + " -> "
                        + (sneaking ? "fits" : (running || sprinting) ? "duck" : "refuse"));
            }
            if (sneaking) return vanilla;                         // crouched: fits
            if (running || sprinting) {
                engageDuck(mover, st, square, dx, dy);
                return vanilla;                                   // ducks through
            }
            st.hintAt = clock.getAsLong();
            blocked++;
            if (!loggedBlock) {
                loggedBlock = true;
                System.out.println("[WTAGarou][Doorway] upright tall form refused at a doorway (crouch or jog to pass)");
            }
            return true;                                          // walking upright: no
        } catch (Exception e) {
            if (firstError == null) {
                firstError = String.valueOf(e);
                System.out.println("[WTAGarou][Doorway] collide hook failed, vanilla collision kept: " + e);
            }
            return vanilla;
        }
    }

    static boolean isDoorwayEdge(Object square, Object next, int dx, int dy) throws Exception {
        // A door object (open or closed) on the shared edge...
        Object frame = callWith(square, "getDoorFrameTo", next);
        if (frame != null) return true;
        // ...or an empty frame: the DoorWall flag sits on the square whose N/W edge it is.
        if (dy == -1) return hasFlag(square, "DoorWallN");
        if (dy == 1)  return hasFlag(next, "DoorWallN");
        if (dx == -1) return hasFlag(square, "DoorWallW");
        if (dx == 1)  return hasFlag(next, "DoorWallW");
        return false;
    }

    private static void engageDuck(Object mover, State st, Object square, int dx, int dy) throws Exception {
        long now = clock.getAsLong();
        if (!st.duckForced) {
            st.sneakBefore = bool(mover, "isSneaking");
            st.duckForced = true;
            ducked++;
            if (!loggedDuck) {
                loggedDuck = true;
                System.out.println("[WTAGarou][Doorway] tall form ducked through a doorway at a run");
            }
        }
        // Midpoint of the crossed edge, in tile units.
        st.duckX = intOf(square, "getX") + 0.5f + dx * 0.5f;
        st.duckY = intOf(square, "getY") + 0.5f + dy * 0.5f;
        st.duckAt = now;
        setBool(mover, "setSneaking", true);
    }

    private static void releaseDuck(Object mover, State st, String why) {
        if (!st.duckForced) return;
        st.duckForced = false;
        released++;
        try { setBool(mover, "setSneaking", st.sneakBefore); } catch (Exception ignored) {}
    }

    // ----------------------------------------------------------- charge hook
    /** OnEnter of IsoMovingObject.checkHitWall: true = skip the vanilla stumble. */
    public static boolean charge(Object mover) {
        if (mover == null) return false;
        State st = STATES.get(mover);
        if (st == null || !st.tall) return false;
        try {
            if (!isLocal(mover) || !bool(mover, "isSprinting")) return false;
            long now = clock.getAsLong();
            if (bool(mover, "isCollidedWithDoor")) {
                Object door = call(mover, "getCollidedObject");
                if (door == null || !isDoor(door)) return false;
                if (door == st.lastDoor && now - st.lastDoorAt < CHARGE_DEBOUNCE_MS) return true; // waiting on the server
                if (!chargeableDoor(mover, door)) { refusedKind++; return false; }
                boolean locked = isLocked(door);
                float cost = locked ? RAGE_COST_LOCKED : RAGE_COST;
                if (st.rage < cost) { refusedNoRage++; return false; }
                st.pendingDoor = door; st.pendingAt = now;
                st.lastDoor = door; st.lastDoorAt = now;
                doorCharges++;
                if (!loggedDoor) {
                    loggedDoor = true;
                    System.out.println("[WTAGarou][Doorway] sprint charge into a wooden door (locked=" + locked + ")");
                }
                return true;
            }
            if (!WINDOW_CHARGE) return false;
            Object window = collidedWindow(mover);
            if (window == null) return false;
            if (window == st.lastWindow && now - st.lastWindowAt < CHARGE_DEBOUNCE_MS) return true;
            if (bool(window, "isBarricaded")) return false;
            Object can = callWith(window, "canClimbThrough", mover);
            if (!(can instanceof Boolean) || !(Boolean) can) return false;
            st.lastWindow = window; st.lastWindowAt = now;
            climb(mover, window);
            windowCharges++;
            if (!loggedWindow) {
                loggedWindow = true;
                System.out.println("[WTAGarou][Doorway] sprint charge through a window");
            }
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    static boolean chargeableDoor(Object mover, Object door) throws Exception {
        if (bool(door, "isDestroyed") || bool(door, "IsOpen")) return false;
        if (bool(door, "isBarricaded")) return false;
        Object prefix = call(door, "getSoundPrefix");
        return prefix == null || String.valueOf(prefix).contains("Wood");
    }
    static boolean isLocked(Object door) throws Exception {
        return bool(door, "isLocked") || bool(door, "isLockedByKey");
    }
    static boolean isDoor(Object o) {
        for (Class<?> c = o.getClass(); c != null; c = c.getSuperclass())
            if ("IsoDoor".equals(c.getSimpleName())) return true;
        return false;
    }
    private static Object collidedWindow(Object mover) throws Exception {
        Object current = call(mover, "getCurrentSquare");
        if (current == null) return null;
        int dx = 0, dy = 0;
        if (bool(mover, "isCollidedN")) dy = -1;
        else if (bool(mover, "isCollidedS")) dy = 1;
        else if (bool(mover, "isCollidedW")) dx = -1;
        else if (bool(mover, "isCollidedE")) dx = 1;
        else return null;
        Object next = neighbour(current, dx, dy);
        if (next == null) return null;
        Object window = callWith(current, "getWindowTo", next);
        return window != null && !bool(window, "isDestroyed") ? window : null;
    }
    private static void climb(Object mover, Object window) throws Exception {
        for (Method m : mover.getClass().getMethods()) {
            if (!m.getName().equals("climbThroughWindow") || m.getParameterCount() != 1) continue;
            if (m.getParameterTypes()[0].isInstance(window)) { m.invoke(mover, window); return; }
        }
        throw new NoSuchMethodException("climbThroughWindow(" + window.getClass().getSimpleName() + ")");
    }

    // ------------------------------------------------------------- reflection
    private static Object neighbour(Object square, int dx, int dy) throws Exception {
        Object cell = call(square, "getCell");
        if (cell == null) return null;
        int x = intOf(square, "getX") + dx, y = intOf(square, "getY") + dy, z = intOf(square, "getZ");
        return Reflect.call(cell, "getGridSquare", new Class<?>[]{int.class, int.class, int.class}, x, y, z);
    }
    /** IsoGridSquare.has(IsoFlagType). 0.4.70: IsoGridSquare also has
     *  has(IsoPropertyType) and has(IsoObjectType); getMethods() order is
     *  unspecified, and Enum.valueOf on the wrong enum throws -- which the
     *  caller used to swallow as "vanilla". Only the IsoFlagType overload is
     *  tried now, with the String overload as the fallback. */
    private static boolean hasFlag(Object square, String flag) throws Exception {
        Method byString = null;
        for (Method m : square.getClass().getMethods()) {
            if (!m.getName().equals("has") || m.getParameterCount() != 1) continue;
            Class<?> p = m.getParameterTypes()[0];
            if (p.isEnum() && p.getSimpleName().equals("IsoFlagType")) {
                @SuppressWarnings({"unchecked", "rawtypes"})
                Object constant = Enum.valueOf((Class<? extends Enum>) p, flag);
                Object r = m.invoke(square, constant);
                return r instanceof Boolean && (Boolean) r;
            }
            if (p == String.class) byString = m;
        }
        if (byString != null) {
            Object r = byString.invoke(square, flag);
            return r instanceof Boolean && (Boolean) r;
        }
        return false;
    }
    private static boolean isLocal(Object mover) throws Exception {
        try { return bool(mover, "isLocalPlayer"); }
        catch (NoSuchMethodException e) { return false; } // not an IsoPlayer
    }
    private static boolean bool(Object target, String name) throws Exception {
        Object r = Reflect.call(target, name);
        return r instanceof Boolean && (Boolean) r;
    }
    private static float num(Object target, String name) throws Exception {
        Object r = Reflect.call(target, name);
        return r instanceof Number ? ((Number) r).floatValue() : 0f;
    }
    private static int intOf(Object target, String name) throws Exception {
        Object r = Reflect.call(target, name);
        return r instanceof Number ? ((Number) r).intValue() : 0;
    }
    private static Object call(Object target, String name) throws Exception {
        return Reflect.call(target, name);
    }
    private static void setBool(Object target, String name, boolean value) throws Exception {
        Reflect.call(target, name, boolean.class, value);
    }
    private static Object callWith(Object target, String name, Object arg) throws Exception {
        for (Method m : target.getClass().getMethods()) {
            if (!m.getName().equals(name) || m.getParameterCount() != 1) continue;
            if (m.getParameterTypes()[0].isInstance(arg)) return m.invoke(target, arg);
        }
        throw new NoSuchMethodException(target.getClass().getName() + "." + name + "(" + arg.getClass().getSimpleName() + ")");
    }

    public static String status() {
        return "doorway tall=" + STATES.size() + "; hook calls=" + tallCalls + " edges=" + edgeCalls
                + (firstError != null ? " error=" + firstError : "")
                + "; blocked=" + blocked + "; ducked=" + ducked + "; released=" + released
                + "; door charges=" + doorCharges + " (no rage " + refusedNoRage + ", wrong kind " + refusedKind + ")"
                + "; window charges=" + windowCharges;
    }
}
