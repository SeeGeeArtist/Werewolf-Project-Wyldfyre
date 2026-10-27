package wtagarou.visuals;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.Collections;
import java.util.Map;
import java.util.WeakHashMap;

/**
 * 0.4.62: "cook" raw silver nitrate the way vanilla boils tainted water.
 *
 * Vanilla (InventoryItem.update, B42.20): a fluid container sitting in a
 * container whose itemHeat passed 1.6 turns TaintedWater into Water at
 * (server ? 0.6 : 0.01) * timeMultiplier per update. itemHeat only climbs
 * for Cookable items (pots, kettles), so a jar or bottle never heats. We do
 * not want the player to need a cooking pot for a jar of acid, so this patch
 * reads the OUTERMOST container's temperature instead (a lit campfire,
 * barbecue or fireplace reports 1.8, a running stove (temp+100)/100 >= 2,
 * everything cold is 1.0) and converts {@code WTAGarou_SilverNitrateRaw} into
 * {@code WTAGarou_SilverNitrate} at the same rate above {@link #THRESHOLD}.
 *
 * 0.4.63: the Oct 16 playtest cooked a jar instantly in a microwave because
 * the 0.4.62 rate ran from the first hot tick. The vessel now warms up the way
 * a vanilla pot does (itemHeat climbs temp/1000 per client update, /16 on the
 * server, and only boils above 1.6) before any raw mix finishes, and the
 * finishing rate itself is a quarter of the tainted-water rate so a litre is
 * a visible wait rather than a blink. Warmth is tracked per vessel in a weak
 * map and cools back down when the vessel leaves the heat.
 *
 * 0.4.72: multiplayer is NOT handled here. A client never gets
 * InventoryItem.update for items in world containers (IsoCell.update calls
 * ProcessItems only in single player, or on the server every 5 s), and the
 * server has no Java. The Oct 18 hosted test (30 game minutes in a
 * microwave, still raw, "0 conversion ticks") was exactly that. Lua
 * WTAGarouNitrateSync.lua now scans the containers near the player and
 * reports; the report queue below is kept only for completeness.
 *
 * The item stays in the cell's process list while its heat differs from the
 * container's (InventoryItem.finishupdate), which is exactly the hot case.
 * Everything is reached through reflection so the jar can be tested against
 * fixtures; when something is missing the patch does nothing and reports it
 * through {@link #status()}.
 */
public final class NitrateHeatRuntime {
    public static final String RAW = "WTAGarou_SilverNitrateRaw";
    public static final String DONE = "WTAGarou_SilverNitrate";
    /** vessel warmth above which the raw mix finishes (vanilla boil is itemHeat > 1.6; a lit fire reports 1.8). */
    public static final float THRESHOLD = 1.6f;
    /** cold vessel warmth; vanilla itemHeat rests at 1.0. */
    public static final float COLD = 1.0f;
    /** warmth never exceeds this (vanilla caps itemHeat at min(3, temp)). */
    public static final float MAX_WARMTH = 3f;
    /** litres finished per update once boiling: a quarter of vanilla's tainted-water 0.01 / 0.6. */
    public static final float CLIENT_RATE = 0.0025f, SERVER_RATE = 0.15f;
    public static final float COOL_RATE = 0.001f;

    private static final Map<Object, float[]> WARMTH = Collections.synchronizedMap(new WeakHashMap<>());

    static volatile boolean observed = false;
    static volatile long conversions = 0;
    static volatile String lastError = null;
    private static volatile Boolean serverFlagKnown = null;
    private static Field serverField;
    private static Method fluidGet;
    private static Class<?> fluidClass;

    private NitrateHeatRuntime() {}

    /** Litres of raw mix that finish this update at the given vessel warmth. Pure. */
    public static float convertAmount(float rawAmount, float warmth, boolean server, float timeMultiplier) {
        if (rawAmount <= 0f || warmth <= THRESHOLD) return 0f;
        float rate = (server ? SERVER_RATE : CLIENT_RATE) * Math.max(0f, timeMultiplier);
        return Math.min(rawAmount, rate);
    }

    /** Next vessel warmth after one update in a container at {@code temp}. Mirrors vanilla itemHeat. Pure. */
    public static float warm(float warmth, float temp, boolean server, float timeMultiplier) {
        float mul = Math.max(0f, timeMultiplier);
        if (!(warmth >= COLD)) warmth = COLD;
        if (temp > warmth) {
            float cap = Math.min(MAX_WARMTH, temp);
            return Math.min(cap, warmth + temp / (server ? 16f : 1000f) * mul);
        }
        return Math.max(Math.max(COLD, temp), warmth - COOL_RATE * mul);
    }

    /** Vessels a remote client converted since Lua last asked (insertion order, no duplicates). */
    static final java.util.LinkedHashSet<Object> COOKED = new java.util.LinkedHashSet<>();

    /** Lua poll: the next vessel whose fluids this client changed, or null. */
    public static Object pollNitrateCooked() {
        synchronized (COOKED) {
            java.util.Iterator<Object> it = COOKED.iterator();
            if (!it.hasNext()) return null;
            Object o = it.next();
            it.remove();
            return o;
        }
    }

    /** Pending report count (status/tests). */
    public static int pendingReports() { synchronized (COOKED) { return COOKED.size(); } }

    /** Current tracked warmth of a vessel (COLD when unknown). */
    public static float warmthOf(Object item) {
        float[] w = item == null ? null : WARMTH.get(item);
        return w == null ? COLD : w[0];
    }

    /** InventoryItem.update exit. */
    public static void afterUpdate(Object item) {
        observed = true;
        if (item == null) return;
        try {
            if (!Boolean.TRUE.equals(Reflect.call(item, "isFluidContainer"))) return;
            Object fc = Reflect.call(item, "getFluidContainer");
            if (fc == null) return;
            Object raw = fluid(RAW);
            if (raw == null) return;
            if (!Boolean.TRUE.equals(Reflect.call(fc, "contains", fluidClass, raw))) return;
            Object outer = Reflect.call(item, "getOutermostContainer");
            if (outer == null) return;
            float temp = ((Number) Reflect.call(outer, "getTemprature")).floatValue();
            float mul = ((Number) Reflect.get(item, "timeMultiplier")).floatValue();
            boolean server = isServer();
            boolean client = !server && isClient();
            // 0.4.66: a hosted/dedicated server has no Java, so a remote client
            // is the authority for its own vessels: it warms and converts at the
            // server rates and reports the result (pollNitrateCooked -> Lua ->
            // NitrateCooked command -> server sets the fluids + sendItemStats).
            boolean authority = server || client;
            float[] w = WARMTH.computeIfAbsent(item, k -> new float[]{COLD});
            w[0] = warm(w[0], temp, authority, mul);
            float have = ((Number) Reflect.call(fc, "getSpecificFluidAmount", fluidClass, raw)).floatValue();
            float move = convertAmount(have, w[0], authority, mul);
            if (move <= 0f) return;
            Object done = fluid(DONE);
            if (done == null) { lastError = "fluid " + DONE + " missing"; return; }
            Reflect.call(fc, "adjustSpecificFluidAmount", new Class<?>[]{fluidClass, float.class}, raw, have - move);
            Reflect.call(fc, "addFluid", new Class<?>[]{fluidClass, float.class}, done, move);
            conversions++;
            lastError = null;
            if (server) sendItemStats(item);
            else if (client) synchronized (COOKED) { COOKED.add(item); }
        } catch (Throwable t) {
            lastError = t.toString();
        }
    }

    static Object fluid(String name) throws ReflectiveOperationException {
        if (fluidGet == null) {
            fluidClass = Class.forName("zombie.entity.components.fluids.Fluid");
            fluidGet = fluidClass.getMethod("Get", String.class);
        }
        return fluidGet.invoke(null, name);
    }

    private static Boolean clientFlagKnown; private static java.lang.reflect.Field clientField;
    static boolean isClient() {
        if (Boolean.FALSE.equals(clientFlagKnown)) return false;
        try {
            if (clientFlagKnown == null) {
                clientField = Reflect.field(Class.forName("zombie.network.GameClient"), "client");
                clientFlagKnown = Boolean.TRUE;
            }
            return clientField.getBoolean(null);
        } catch (Throwable t) {
            clientFlagKnown = Boolean.FALSE;
            return false;
        }
    }

    static boolean isServer() {
        if (Boolean.FALSE.equals(serverFlagKnown)) return false;
        try {
            if (serverFlagKnown == null) {
                serverField = Reflect.field(Class.forName("zombie.network.GameServer"), "server");
                serverFlagKnown = Boolean.TRUE;
            }
            return serverField.getBoolean(null);
        } catch (Throwable t) {
            serverFlagKnown = Boolean.FALSE;
            return false;
        }
    }

    static void sendItemStats(Object item) {
        try {
            Class<?> gs = Class.forName("zombie.network.GameServer");
            Class<?> ii = Class.forName("zombie.inventory.InventoryItem");
            gs.getMethod("sendItemStats", ii).invoke(null, item);
        } catch (Throwable ignored) {}
    }

    /** Test hook: forget cached reflection targets. */
    public static void reset() {
        fluidGet = null; fluidClass = null; serverFlagKnown = null; serverField = null;
        clientFlagKnown = null; clientField = null;
        observed = false; conversions = 0; lastError = null;
        WARMTH.clear();
        synchronized (COOKED) { COOKED.clear(); }
    }

    public static String status() {
        return "nitrate heat: " + (observed ? "InventoryItem.update seen" : "InventoryItem.update NOT seen")
                + ", " + conversions + " conversion ticks"
                + (isClient() && !isServer() ? ", MP client: InventoryItem.update never runs for world containers here (0.4.72: Lua NitrateSync scans instead; " + pendingReports() + " Java report(s) waiting)" : "")
                + (lastError == null ? "" : ", error: " + lastError);
    }
}
