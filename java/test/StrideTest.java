import java.lang.instrument.Instrumentation;
import net.bytebuddy.agent.ByteBuddyAgent;
import wtagarou.visuals.*;

/** Real ZombieBuddy advice on a fixture shaped like IsoPlayer.getDeferredMovement(Vector2, boolean). */
public final class StrideTest {
    static int checks;
    static void check(boolean ok, String why) { checks++; if (!ok) throw new AssertionError("FAIL: " + why); }

    public static class Vector2 { public float x, y; public Vector2 set(float x, float y) { this.x = x; this.y = y; return this; } }
    public static class PlayerActionsState {}
    /** B42.20.2: the player's walk/run/sprint state ("movement", "run", "sprint"). */
    public static class PlayerMovementState {}
    public static class ClimbOverFenceState {}
    public static class SwipeStatePlayer {}
    public static class Player {
        public Object state = new PlayerActionsState();
        public float stepX = 0.05f, stepY = -0.02f;
        public Object getCurrentState() { return state; }
        /** Vanilla shape: root motion copied into result; vanilla's invisible-sprint scales it here too. */
        public Vector2 getDeferredMovement(Vector2 result, boolean reset) { return result.set(stepX, stepY); }
    }

    static boolean near(float a, float b) { return Math.abs(a - b) < 1e-5f; }

    public static void main(String[] args) throws Exception {
        Instrumentation inst = ByteBuddyAgent.install();
        WolfCombatTest.install(inst, Player.class, StridePatch.class, "getDeferredMovement");

        // Pure decisions.
        check(StrideRuntime.locomotion("PlayerMovementState"), "0.4.69: B42.20.2 PlayerMovementState (walk/run/sprint) scales");
        check(StrideRuntime.locomotion("PlayerActionsState") && StrideRuntime.locomotion("PathFindState")
                && StrideRuntime.locomotion("PlayerStrafeState") && StrideRuntime.locomotion("PlayerAimState"), "walking states scale");
        check(!StrideRuntime.locomotion("ClimbOverFenceState") && !StrideRuntime.locomotion("PlayerGetUpState")
                && !StrideRuntime.locomotion("SwipeStatePlayer") && !StrideRuntime.locomotion(null), "climbs, get-ups, attacks and no state do not");
        Player p = new Player();
        check(StrideRuntime.factor(p) == 1f, "default factor 1");
        check(!StrideRuntime.set(null, 1.44) && !StrideRuntime.set(p, Double.NaN), "null character / NaN refused");
        check(StrideRuntime.set(p, 1.0) && StrideRuntime.factor(p) == 1f, "1.0 clears");
        check(StrideRuntime.set(p, 9.0) && StrideRuntime.factor(p) == 2.5f, "factor clamped to 2.5");
        check(StrideRuntime.set(p, 0.1) && StrideRuntime.factor(p) == 0.5f, "factor clamped to 0.5");

        // Vanilla untouched while no profile exists.
        StrideRuntime.clear(p);
        Vector2 v = p.getDeferredMovement(new Vector2(), true);
        check(near(v.x, 0.05f) && near(v.y, -0.02f), "no profile: vanilla root motion");

        // Crinos: 1.44x in a locomotion state.
        check(StrideRuntime.set(p, 1.44), "Crinos stride accepted");
        long before = StrideRuntime.scaled.get();
        v = p.getDeferredMovement(new Vector2(), true);
        check(near(v.x, 0.05f * 1.44f) && near(v.y, -0.02f * 1.44f), "walking root motion scaled by the model scale");
        check(StrideRuntime.scaled.get() == before + 1, "scaled frame counted");

        // Standing still: nothing to scale, no counter.
        p.stepX = 0f; p.stepY = 0f;
        before = StrideRuntime.scaled.get();
        v = p.getDeferredMovement(new Vector2(), true);
        check(v.x == 0f && v.y == 0f && StrideRuntime.scaled.get() == before, "zero motion left alone");
        p.stepX = 0.05f; p.stepY = -0.02f;

        // Climb / attack states keep authored translation.
        p.state = new PlayerMovementState();
        v = p.getDeferredMovement(new Vector2(), true);
        check(near(v.x, 0.05f * StrideRuntime.factor(p)) && near(v.y, -0.02f * StrideRuntime.factor(p)),
                "a plain walk/run/sprint (PlayerMovementState) is stride-scaled: " + v.x);
        for (Object s : new Object[]{new ClimbOverFenceState(), new SwipeStatePlayer()}) {
            p.state = s;
            long skipped = StrideRuntime.skipped.get();
            v = p.getDeferredMovement(new Vector2(), true);
            check(near(v.x, 0.05f) && near(v.y, -0.02f), s.getClass().getSimpleName() + ": vanilla root motion");
            check(StrideRuntime.skipped.get() == skipped + 1, s.getClass().getSimpleName() + ": counted as left alone");
        }
        p.state = new PlayerActionsState();

        // Another player without a profile is never touched by this one's factor.
        Player other = new Player();
        v = other.getDeferredMovement(new Vector2(), true);
        check(near(v.x, 0.05f), "other character untouched");

        // Lua API and cleanup.
        check(WTAGarouJava.setStride(p, 1.24) && StrideRuntime.factor(p) == 1.24f, "WTAGarouJava.setStride");
        check(WTAGarouJava.strideStatus().startsWith("stride: 1 character"), "status names the profile count");
        WTAGarouJava.clearAll();
        check(StrideRuntime.factor(p) == 1f, "clearAll drops the stride profile");
        v = p.getDeferredMovement(new Vector2(), true);
        check(near(v.x, 0.05f), "after clear: vanilla again");

        System.out.println("PASS: " + checks + " stride/root-motion assertions.");
    }
}
