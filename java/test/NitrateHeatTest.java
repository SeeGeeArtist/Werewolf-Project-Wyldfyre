import java.lang.instrument.Instrumentation;
import java.util.LinkedHashMap;
import java.util.Map;
import net.bytebuddy.agent.ByteBuddyAgent;
import wtagarou.visuals.*;
import zombie.entity.components.fluids.Fluid;
import zombie.network.GameServer;

/** Real ZombieBuddy advice on a fixture shaped like InventoryItem.update() with a FluidContainer in a hot container. */
public final class NitrateHeatTest {
    static int checks;
    static void check(boolean ok, String why) { checks++; if (!ok) throw new AssertionError("FAIL: " + why); }
    static boolean near(float a, float b) { return Math.abs(a - b) < 1e-5f; }

    /** FluidContainer fixture: the public API NitrateHeatRuntime calls, with vanilla's clamp/blend semantics simplified. */
    public static final class Container {
        final float capacity; final Map<Fluid, Float> fluids = new LinkedHashMap<>();
        Container(float capacity) { this.capacity = capacity; }
        public boolean contains(Fluid f) { return fluids.containsKey(f); }
        public float getSpecificFluidAmount(Fluid f) { return fluids.getOrDefault(f, 0f); }
        public void adjustSpecificFluidAmount(Fluid f, float amount) {
            if (!fluids.containsKey(f)) return;
            if (amount <= 0f) fluids.remove(f); else fluids.put(f, amount);
        }
        public float getAmount() { float t = 0; for (float v : fluids.values()) t += v; return t; }
        public void addFluid(Fluid f, float amount) {
            float room = capacity - getAmount();
            if (amount <= 0f || room <= 1e-6f) return;
            fluids.merge(f, Math.min(amount, room), Float::sum);
        }
    }
    public static final class Bag { public float temperature = 1f; public float getTemprature() { return temperature; } }
    public static final class Item {
        Container fc; Bag outer; protected float timeMultiplier = 1f; int updates;
        public boolean isFluidContainer() { return fc != null; }
        public Container getFluidContainer() { return fc; }
        public Bag getOutermostContainer() { return outer; }
        /** Vanilla shape: the patched method; nothing of ours lives in it. */
        public void update() { updates++; }
    }

    public static void main(String[] args) throws Exception {
        Instrumentation inst = ByteBuddyAgent.install();
        WolfCombatTest.install(inst, Item.class, NitrateHeatPatch.class, "update");

        // Pure rate (at boiling warmth).
        check(near(NitrateHeatRuntime.convertAmount(1f, 1.8f, false, 1f), 0.0025f), "client: 0.0025 L per update once boiling (quarter of vanilla)");
        check(near(NitrateHeatRuntime.convertAmount(1f, 1.8f, true, 1f), 0.15f), "server: 0.15 L per update once boiling");
        check(near(NitrateHeatRuntime.convertAmount(1f, 1.8f, false, 2.5f), 0.00625f), "scaled by timeMultiplier");
        check(NitrateHeatRuntime.convertAmount(1f, 1.0f, true, 1f) == 0f && NitrateHeatRuntime.convertAmount(1f, 1.6f, true, 1f) == 0f, "cold or merely warm (<= 1.6): nothing");
        check(NitrateHeatRuntime.convertAmount(0.001f, 2.0f, false, 1f) == 0.001f, "never more than what is left");
        check(NitrateHeatRuntime.convertAmount(0f, 2.0f, true, 1f) == 0f, "no raw mix: nothing");

        // Pure warm-up: vanilla itemHeat ramp.
        check(near(NitrateHeatRuntime.warm(1f, 1.8f, false, 1f), 1.0018f), "client: warms temp/1000 per update");
        check(near(NitrateHeatRuntime.warm(1f, 1.8f, true, 1f), 1.1125f), "server: warms temp/16 per update");
        check(near(NitrateHeatRuntime.warm(1.79f, 1.8f, false, 100f), 1.8f), "never warmer than the container");
        check(near(NitrateHeatRuntime.warm(2.9f, 5f, true, 10f), 3f), "capped at 3 like vanilla");
        check(near(NitrateHeatRuntime.warm(1.8f, 1f, false, 1f), 1.799f), "cools 0.001 per update out of the heat");
        check(near(NitrateHeatRuntime.warm(1.0005f, 1f, false, 1f), 1f), "never colder than cold");
        check(near(NitrateHeatRuntime.warm(0f, 1f, false, 1f), 1f), "garbage warmth resets to cold");
        float w = 1f; int ticks = 0;
        while (w <= NitrateHeatRuntime.THRESHOLD) { w = NitrateHeatRuntime.warm(w, 1.8f, false, 1f); ticks++; }
        check(ticks >= 300 && ticks <= 400, "a lit fire needs a few hundred client updates before the jar boils: " + ticks);

        // Fluids missing (mod fluids not loaded): patch is inert.
        Fluid.reset();
        Item jar = new Item(); jar.fc = new Container(1f); jar.outer = new Bag(); jar.outer.temperature = 1.8f;
        jar.update();
        check(jar.updates == 1 && jar.fc.getAmount() == 0f, "update ran, nothing to convert, no exception");
        check(NitrateHeatRuntime.status().contains("update seen"), "status sees the hook: " + NitrateHeatRuntime.status());

        // Jar of raw mix in a lit campfire, client rate: warm-up first, then the slow finish.
        Fluid raw = Fluid.define(NitrateHeatRuntime.RAW), done = Fluid.define(NitrateHeatRuntime.DONE), water = Fluid.define("Water");
        jar.fc.fluids.put(raw, 1f);
        jar.update();
        check(near(jar.fc.getSpecificFluidAmount(raw), 1f) && !jar.fc.contains(done), "first hot tick: warming, nothing finished yet");
        check(NitrateHeatRuntime.warmthOf(jar) > 1f, "vessel warmth tracked: " + NitrateHeatRuntime.warmthOf(jar));
        int warmTicks = 1;
        while (!jar.fc.contains(done) && warmTicks < 1000) { jar.update(); warmTicks++; }
        check(warmTicks >= 300 && warmTicks <= 400, "boils after a few hundred updates: " + warmTicks);
        check(near(jar.fc.getSpecificFluidAmount(done), 0.0025f) && near(jar.fc.getAmount(), 1f), "first boiling tick: 0.0025 L finished, volume conserved");
        int finishTicks = 0;
        while (jar.fc.contains(raw) && finishTicks < 2000) { jar.update(); finishTicks++; }
        check(finishTicks >= 398 && finishTicks <= 401, "a litre finishes over ~400 boiling updates: " + finishTicks);
        check(!jar.fc.contains(raw) && near(jar.fc.getSpecificFluidAmount(done), 1f), "last tick finishes the jar; raw instance removed");

        // Pulled out of the fire: the vessel cools and stops finishing.
        Item half = new Item(); half.fc = new Container(1f); half.outer = new Bag(); half.outer.temperature = 1.8f; half.fc.fluids.put(raw, 1f);
        for (int i = 0; i < 450; i++) half.update();
        float finished = half.fc.getSpecificFluidAmount(done);
        check(finished > 0f && half.fc.contains(raw), "half-cooked jar has some of each: " + finished);
        half.outer.temperature = 1f;
        for (int i = 0; i < 300; i++) half.update();
        float afterResidual = half.fc.getSpecificFluidAmount(done);
        check(afterResidual > finished && half.fc.contains(raw), "residual heat keeps finishing a little while the jar cools (vanilla pot behaviour)");
        check(NitrateHeatRuntime.warmthOf(half) < NitrateHeatRuntime.THRESHOLD, "warmth fell back under the boil: " + NitrateHeatRuntime.warmthOf(half));
        for (int i = 0; i < 200; i++) half.update();
        check(near(half.fc.getSpecificFluidAmount(done), afterResidual), "cooled: the jar stops finishing");

        // Cold jar: untouched. Jar on the floor (no container): untouched.
        Item cold = new Item(); cold.fc = new Container(1f); cold.outer = new Bag(); cold.fc.fluids.put(raw, 0.5f);
        for (int i = 0; i < 500; i++) cold.update();
        check(near(cold.fc.getSpecificFluidAmount(raw), 0.5f) && !cold.fc.contains(done), "cold container: raw stays raw");
        cold.outer = null; cold.update();
        check(near(cold.fc.getSpecificFluidAmount(raw), 0.5f), "no outer container: untouched");

        // Water in the fire is not our business; an item without a fluid container is skipped cheaply.
        Item pot = new Item(); pot.fc = new Container(1f); pot.outer = new Bag(); pot.outer.temperature = 1.8f; pot.fc.fluids.put(water, 1f);
        for (int i = 0; i < 500; i++) pot.update();
        check(near(pot.fc.getSpecificFluidAmount(water), 1f) && pot.fc.fluids.size() == 1, "water untouched");
        Item axe = new Item(); axe.update();
        check(axe.updates == 1, "non-fluid item passes through");

        // Server rate on a running stove ((100+100)/100 = 2.0): warms /16 per update, then 0.15 L per tick.
        GameServer.server = true;
        Item bottle = new Item(); bottle.fc = new Container(1f); bottle.outer = new Bag(); bottle.outer.temperature = 2.0f; bottle.fc.fluids.put(raw, 1f);
        int serverWarm = 0;
        while (!bottle.fc.contains(done) && serverWarm < 100) { bottle.update(); serverWarm++; }
        check(serverWarm >= 5 && serverWarm <= 7, "server: boils after a handful of updates: " + serverWarm);
        check(near(bottle.fc.getSpecificFluidAmount(done), 0.15f), "server: 0.15 L per boiling tick");
        for (int i = 0; i < 6; i++) bottle.update();
        check(!bottle.fc.contains(raw) && near(bottle.fc.getSpecificFluidAmount(done), 1f), "server: done in seven boiling ticks");
        GameServer.server = false;

        // 0.4.66: a remote client (hosted/dedicated server has no Java) is the authority for its vessels:
        // server rates, and every converted vessel is queued once for Lua to report (pollNitrateCooked).
        zombie.network.GameClient.client = true;
        NitrateHeatRuntime.reset();
        Item mp = new Item(); mp.fc = new Container(1f); mp.outer = new Bag(); mp.outer.temperature = 2.0f; mp.fc.fluids.put(raw, 1f);
        int mpWarm = 0;
        while (!mp.fc.contains(done) && mpWarm < 100) { mp.update(); mpWarm++; }
        check(mpWarm >= 5 && mpWarm <= 7, "remote client: boils at the server pace: " + mpWarm);
        check(near(mp.fc.getSpecificFluidAmount(done), 0.15f), "remote client: 0.15 L per boiling tick");
        check(NitrateHeatRuntime.pendingReports() == 1, "one report queued after the first conversion");
        mp.update(); mp.update();
        check(NitrateHeatRuntime.pendingReports() == 1, "repeated conversions of the same vessel queue it once");
        check(WTAGarouJava.pollNitrateCooked() == mp, "Lua poll hands back the vessel");
        check(WTAGarouJava.pollNitrateCooked() == null && NitrateHeatRuntime.pendingReports() == 0, "queue drained");
        mp.update();
        check(NitrateHeatRuntime.pendingReports() == 1, "the next conversion queues it again");
        check(NitrateHeatRuntime.status().contains("Lua NitrateSync scans instead"), "status points at the Lua scanner (0.4.72): " + NitrateHeatRuntime.status());
        zombie.network.GameClient.client = false;
        NitrateHeatRuntime.reset();
        Item solo = new Item(); solo.fc = new Container(1f); solo.outer = new Bag(); solo.outer.temperature = 2.0f; solo.fc.fluids.put(raw, 1f);
        for (int i = 0; i < 400; i++) solo.update();
        check(NitrateHeatRuntime.pendingReports() == 0, "single player never queues reports");
        check(!NitrateHeatRuntime.status().contains("error"), "no error recorded: " + NitrateHeatRuntime.status());
        check(WTAGarouJava.nitrateStatus().startsWith("nitrate heat: "), "Lua-facing status");

        System.out.println("PASS: " + checks + " nitrate-heat assertions.");
    }
}
