package wtagarou.visuals;

import java.util.Collections;
import java.util.Map;
import java.util.Set;
import java.util.WeakHashMap;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

/** 0.4.80: vertical root-motion compression for the scaled bipeds while they
 * climb (Glabro 1.24, Crinos 1.65).
 *
 * The climb-over-fence / climb-over-wall / climb-through-window animations
 * start on the ground and lift the whole skeleton (the pelvis rises by the
 * fence height, in the bones; the character's z never changes). FinalScale
 * scales the model about its origin at the feet, so a Crinos's lift is drawn
 * 1.65x too high and the hands float above the fence top.
 *
 * 0.4.83: the reference is the HANDS, measured from the ground. The fence
 * top is world geometry at vanilla height, and the animation puts the hands
 * on it; so the hands are what must sit where vanilla draws them. With the
 * hands at model height h (mean of both hand bones), FinalScale draws them
 * at scale x h; moving every bone by dy = -h x (1 - 1/scale) draws them at
 * exactly h, the fence top. The offset is clamped so the lowest foot never
 * goes below the ground (dy >= -lowestFoot) and is never positive, which is
 * what makes the climb coherent: feet planted before the vault, no offset
 * (the hands at the sides are above a fence anyway on a tall body); as the
 * feet lift, the body comes down until the hands rest on the fence; while
 * the legs kick for purchase the hands are planted so the offset is
 * constant (no bob); landing feet bring the body back up to zero offset.
 *
 * Why not the earlier rules: 0.4.80 referenced the pelvis lift and 0.4.82
 * the lowest-foot lift, both relative to the first climb frame. A lift
 * relative to a rest frame keeps the standing hand height scaled (1.65 x
 * 0.9 = 1.5 above a 1.0 fence), so the hands could never reach the rail;
 * the rest frame depended on which blend frame the state was entered on
 * ("sometimes correct, other times too high"); and the lowest foot
 * changes every time the legs alternate, which bobbed the whole body while
 * the feet kicked (Oct 23 hosted test). Rigs without hand bones fall back
 * to the 0.4.82 lowest-foot lift, then the pelvis lift.
 *
 * The pelvis stays as the matrix-layout sanity check. Horizontal root
 * motion in climb states is left alone (StrideRuntime skips climbs on
 * purpose: the hands have to land on world geometry). Sub-model players
 * (clothing, body sub-models) follow the body player's offset for the
 * frame so everything moves together. Wolves (Lupus/Hispo) use their own
 * rig and are skipped. Unknown layouts disable the hook once, with a
 * console line.
 *
 * 0.4.95 SEATS: lying on a bed (PlayerOnBedState) and sitting on furniture
 * (PlayerSitOnFurnitureState) are the same problem with the PELVIS as the
 * reference: the animation lifts the skeleton onto the mattress or the
 * seat (world geometry at vanilla height) and FinalScale draws the pelvis
 * scale x too high ("floating above the bed", Oct 26 Glabro test). The
 * offset -pelvisY (1 - 1/scale) would seat the pelvis at vanilla height,
 * but both poses are SITTING poses (resting on a bed sits on the edge of
 * the mattress, feet on the floor - the author's correction), and a
 * scaled body is scale x taller from floor to pelvis, so the pelvis and
 * the feet cannot both land. The difference is split: half the pelvis
 * float, half the foot sink, with the drawn sink capped at MAX_SINK so
 * the Crinos (1.65) does not stand knee-deep in the floor ("the feet
 * shouldn't go through the floor, at least not too much"). Sitting on
 * the ground is left alone: the body's lowest point is already the origin. */
public final class ClimbRuntime {
    /** zombie.ai.states.* whose animation lifts the skeleton onto geometry. */
    static final Set<String> CLIMB_STATES = Set.of("ClimbOverFenceState", "ClimbOverWallState", "ClimbThroughWindowState");
    /** 0.4.95: states that seat the skeleton on furniture (pelvis reference). */
    static final Set<String> SEAT_STATES = Set.of("PlayerOnBedState", "PlayerSitOnFurnitureState");
    /** 0.4.83 reference: the hands (mean height), what rests on the fence top. */
    static final String[] HAND_BONES = { "Bip01_L_Hand", "Bip01_R_Hand" };
    /** Ground clamp (0.4.83) and fallback lift reference (0.4.82): the lowest foot. */
    static final String[] FOOT_BONES = { "Bip01_L_Foot", "Bip01_R_Foot" };
    /** Layout sanity check and fallback reference, first one present wins. */
    static final String[] REFERENCE_BONES = { "Bip01_Pelvis", "Bip01" };
    /** Plausible standing pelvis height in model units; anything else means
     *  the matrix layout is not the one evidenced in B42.20.2 (m13 = up). */
    static final float MIN_REST = 0.2f, MAX_REST = 3.0f;

    static final class Entry {
        float restY;
        boolean hasRest;
        String reference;      // "hands" (0.4.83), "lowest foot" or "pelvis" (fallbacks)
        float dy;              // the body player's offset for this frame
    }
    private static final Map<Object, Entry> ENTRIES = Collections.synchronizedMap(new WeakHashMap<>());
    private static final AtomicBoolean WARNED = new AtomicBoolean();
    private static final AtomicBoolean LOGGED = new AtomicBoolean();
    private static final AtomicBoolean SEAT_LOGGED = new AtomicBoolean();
    public static volatile boolean disabled;
    public static final AtomicLong applied = new AtomicLong(), frames = new AtomicLong();
    public static volatile float lastLift, lastDy;

    /** Pure decision: compress when the state's simple class name is a climb. */
    public static boolean climbing(String stateClassName) {
        return stateClassName != null && CLIMB_STATES.contains(stateClassName);
    }

    /** 0.4.95 pure decision: seat the pelvis when the state is a bed or furniture state. */
    public static boolean seated(String stateClassName) {
        return stateClassName != null && SEAT_STATES.contains(stateClassName);
    }

    /** Drawn metres the lowest foot may sink below the floor while seated. */
    public static final float MAX_SINK = 0.08f;

    /** 0.4.95 pure math. want = offset that draws the pelvis at vanilla seat
     *  height after FinalScale; floor = offset that puts the lowest foot on the
     *  ground. If both agree (feet already up) take want. Otherwise split the
     *  difference, but never sink the drawn foot more than MAX_SINK. Never
     *  positive. */
    public static float seatOffset(float pelvisY, float lowestFootY, float scale) {
        if (!(pelvisY > 0f) || !(scale > 0f) || Math.abs(scale - 1f) < 1e-4f) return 0f;
        float want = -pelvisY * (1f - 1f / scale);
        float floor = -Math.max(0f, lowestFootY);
        if (want >= floor) return Math.min(0f, want);
        float mid = 0.5f * (want + floor);
        float sinkLimit = floor - MAX_SINK / scale;
        return Math.min(0f, Math.max(mid, sinkLimit));
    }

    /** Pure math (fallback rigs): model-space offset for a lift at a given scale (0 or negative). */
    public static float offset(float lift, float scale) {
        if (!(lift > 0f) || !(scale > 0f) || Math.abs(scale - 1f) < 1e-4f) return 0f;
        return -lift * (1f - 1f / scale);
    }

    /** 0.4.83 pure math: offset that draws hands at model height {@code handY}
     *  at vanilla height after FinalScale, clamped so the lowest foot never
     *  goes below the ground and the body is never pushed up. */
    public static float handOffset(float handY, float lowestFootY, float scale) {
        if (!(handY > 0f) || !(scale > 0f) || Math.abs(scale - 1f) < 1e-4f) return 0f;
        float want = -handY * (1f - 1f / scale);
        float floor = -Math.max(0f, lowestFootY);
        return Math.min(0f, Math.max(want, floor));
    }

    /** 0.4.96: the low-fence hop (`ClimbOverFenceState` is only ever the
     *  hoppable fence; tall fences and walls are `ClimbOverWallState`). The
     *  body's lowest point is what passes over the fence top, so the LOWEST
     *  FOOT draws at its vanilla height: dy = -foot (1 - 1/scale). The hands
     *  rule put the feet, which hang below the hands, scale x further down
     *  and through the rail. Never positive. */
    public static float hopOffset(float lowestFootY, float scale) {
        if (!(lowestFootY > 0f) || !(scale > 0f) || Math.abs(scale - 1f) < 1e-4f) return 0f;
        return Math.min(0f, -lowestFootY * (1f - 1f / scale));
    }

    /** The hoppable-fence vault state. */
    public static boolean hop(String stateName) { return "ClimbOverFenceState".equals(stateName); }

    /** AnimationPlayer.UpdateSkinTransforms entry. */
    public static void apply(Object player) {
        if (disabled || player == null) return;
        try {
            Object parent = Reflect.get(player, "parentPlayer");
            Object character = Reflect.call(player, "getIsoGameCharacter");
            for (Object p = parent; character == null && p != null; p = Reflect.get(p, "parentPlayer"))
                character = Reflect.call(p, "getIsoGameCharacter");
            if (character == null) return;
            if (WolfRuntime.active(character)) { ENTRIES.remove(character); return; }
            float scale = WTAGarouJava.scaleFor(character);
            if (Math.abs(scale - 1f) < 1e-4f) { ENTRIES.remove(character); return; }
            Object state = Reflect.call(character, "getCurrentState");
            String stateName = state == null ? null : state.getClass().getSimpleName();
            boolean seat = seated(stateName);
            if (state == null || (!climbing(stateName) && !seat)) { ENTRIES.remove(character); return; }
            int count = ((Number) Reflect.call(player, "getModelTransformsCount")).intValue();
            if (count <= 0) return;
            Entry entry = ENTRIES.computeIfAbsent(character, k -> new Entry());
            float dy;
            int bone = referenceBone(player);
            if (bone >= 0 && bone < count) {
                Object m = Reflect.call(player, "getModelTransformAt", int.class, bone);
                float pelvisY = Reflect.field(m.getClass(), "m13").getFloat(m);
                int[] feet = bones(player, count, FOOT_BONES);
                int[] hands = bones(player, count, HAND_BONES);
                float y = feet.length > 0 ? lowestY(player, feet) : pelvisY;
                if (!entry.hasRest) {
                    if (!seat && (pelvisY < MIN_REST || pelvisY > MAX_REST))
                        throw new IllegalStateException("unexpected pelvis height " + pelvisY + " (matrix layout?)");
                    entry.restY = y;
                    entry.hasRest = true;
                    entry.reference = seat ? "pelvis (seat)" : hop(stateName) && feet.length > 0 ? "lowest foot (hop)"
                            : hands.length > 0 ? "hands" : feet.length > 0 ? "lowest foot" : "pelvis";
                }
                float lift;
                if (seat) {
                    lift = pelvisY;                                // absolute: pelvis measured from the ground
                    dy = seatOffset(pelvisY, feet.length > 0 ? lowestY(player, feet) : 0f, scale);
                } else if (hop(stateName) && feet.length > 0) {
                    lift = y;                                      // absolute: lowest foot measured from the ground
                    dy = hopOffset(y, scale);
                } else if (hands.length > 0) {
                    float handY = meanY(player, hands);
                    lift = handY;                                  // absolute: hands measured from the ground
                    dy = handOffset(handY, feet.length > 0 ? lowestY(player, feet) : 0f, scale);
                } else {
                    lift = Math.max(0f, y - entry.restY);
                    dy = offset(lift, scale);
                }
                if (parent == null) { entry.dy = dy; lastLift = lift; }
            } else {
                dy = entry.dy;         // a sub-model without the reference bones follows the body
            }
            frames.incrementAndGet();
            if (dy == 0f) return;
            for (int i = 0; i < count; i++) {
                Object m = Reflect.call(player, "getModelTransformAt", int.class, i);
                java.lang.reflect.Field f = Reflect.field(m.getClass(), "m13");
                f.setFloat(m, f.getFloat(m) + dy);
            }
            lastDy = dy;
            applied.incrementAndGet();
            if ((seat ? SEAT_LOGGED : LOGGED).compareAndSet(false, true))
                System.out.println("[WTAGarou Java][Climb] vertical root motion compressed in " + stateName
                        + " (scale " + scale + ", reference " + entry.reference + " rest " + entry.restY
                        + ", first offset " + dy + ")");
        } catch (Throwable t) {
            disabled = true;
            if (WARNED.compareAndSet(false, true))
                System.out.println("[WTAGarou Java] climb compression disabled (vanilla climb arc kept): " + t);
        }
    }

    static int referenceBone(Object player) throws ReflectiveOperationException {
        for (String name : REFERENCE_BONES) {
            Object idx = Reflect.call(player, "getSkinningBoneIndex", new Class<?>[] { String.class, int.class }, name, -1);
            int i = ((Number) idx).intValue();
            if (i >= 0) return i;
        }
        return -1;
    }

    /** Indices of the named bones present on this player (0, 1 or 2 of them). */
    static int[] bones(Object player, int count, String[] names) throws ReflectiveOperationException {
        int[] out = new int[names.length];
        int n = 0;
        for (String name : names) {
            Object idx = Reflect.call(player, "getSkinningBoneIndex", new Class<?>[] { String.class, int.class }, name, -1);
            int i = ((Number) idx).intValue();
            if (i >= 0 && i < count) out[n++] = i;
        }
        return java.util.Arrays.copyOf(out, n);
    }

    /** Model-space height (m13) of the lowest of the given bones. */
    static float lowestY(Object player, int[] bones) throws ReflectiveOperationException {
        float min = Float.POSITIVE_INFINITY;
        for (int b : bones) {
            Object m = Reflect.call(player, "getModelTransformAt", int.class, b);
            min = Math.min(min, Reflect.field(m.getClass(), "m13").getFloat(m));
        }
        return min;
    }

    /** Mean model-space height (m13) of the given bones. */
    static float meanY(Object player, int[] bones) throws ReflectiveOperationException {
        float sum = 0f;
        for (int b : bones) {
            Object m = Reflect.call(player, "getModelTransformAt", int.class, b);
            sum += Reflect.field(m.getClass(), "m13").getFloat(m);
        }
        return bones.length == 0 ? 0f : sum / bones.length;
    }

    public static void clearAll() { ENTRIES.clear(); }

    public static String status() {
        return "climb compression disabled=" + disabled + "; frames=" + frames.get() + "; applied=" + applied.get()
                + "; last lift=" + lastLift + "; last dy=" + lastDy;
    }
}
