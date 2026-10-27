package wtagarou.visuals;

import java.util.Collections;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.WeakHashMap;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Wolf-form corpse handling (0.4.40).
 *
 * Build 42 positions a grappled body from the grappler's live anim node:
 * every frame AnimLayer pushes the node's GrappleOffsetForward into
 * BaseGrappleable.setGrapplePosOffsetForward(float) and the body is placed
 * that far in front of the grappler. The human offsets put a dragged corpse
 * inside the longer quadruped body (October 5 playtest: "a whole meter
 * forward for the Hispo would do it"). GrappleOffsetPatch adds a per-form
 * extra, set from Lua, while the character is dragging.
 *
 * It also records when a corpse-handling clip (pickup / lay-down / throw
 * into a container) starts on a wolf so the Lua bite-sound filter can tell a
 * SwipeStatePlayer corpse grab from a bite: at swing time the state is still
 * SwipeStatePlayer and none of the grapple flags are set yet.
 */
public final class WolfGrappleRuntime {
    private static final Map<Object, Float> FORWARD = Collections.synchronizedMap(new WeakHashMap<>());
    private static final Map<Object, Long> CORPSE_CLIP_AT = Collections.synchronizedMap(new WeakHashMap<>());
    private static final Map<Object, String> CORPSE_CLIP_NAME = Collections.synchronizedMap(new WeakHashMap<>());
    private static final Map<Object, Long> THROW_AT = Collections.synchronizedMap(new WeakHashMap<>());
    private static final Map<Object, Float> SHOULDER_PICKUP = Collections.synchronizedMap(new WeakHashMap<>());
    private static final Set<String> OFFSET_LOGS = ConcurrentHashMap.newKeySet();
    private static final Set<String> DRAG_LOGS = ConcurrentHashMap.newKeySet();
    public static final AtomicLong offsetsApplied = new AtomicLong(), failures = new AtomicLong();
    static final String DRAGGING_STATE = "PlayerDraggingCorpse";

    /** Extra forward metres for a character's dragged corpse (0 clears). */
    public static boolean setForward(Object character, double metres) {
        if (character == null) return false;
        if (metres == 0d) FORWARD.remove(character); else FORWARD.put(character, (float) metres);
        return true;
    }
    public static float forward(Object character) {
        Float f = character == null ? null : FORWARD.get(character);
        return f == null ? 0f : f;
    }
    /** 0.4.44: total distance (metres, sign follows the node) at which a body
     * lifted from the ground BY THE SHOULDERS sits. Oct 6 console: those
     * pickup nodes are -0.9 (FromOnFront) and -1.2 (FromOnBack) against -0.3
     * for the carry, so with the carry extra added the body was "too far from
     * the wolf's head"; the legs grab and the trunk drag-out were right. The
     * default is the carry distance, so the lift happens where the body is
     * then carried. 0 or less clears. */
    public static boolean setShoulderPickupDistance(Object character, double metres) {
        if (character == null) return false;
        if (metres <= 0d) SHOULDER_PICKUP.remove(character); else SHOULDER_PICKUP.put(character, (float) metres);
        return true;
    }
    static Float shoulderPickupDistance(Object character) {
        return character == null ? null : SHOULDER_PICKUP.get(character);
    }
    public static void clear(Object character) {
        if (character == null) return;
        FORWARD.remove(character);
        SHOULDER_PICKUP.remove(character);
        CORPSE_CLIP_AT.remove(character);
        CORPSE_CLIP_NAME.remove(character);
        THROW_AT.remove(character);
        LAST_SIGN.remove(character);
    }

    /** Current state name, "" when unavailable. */
    public static String stateName(Object character) {
        try {
            Object state = Reflect.call(character, "getCurrentState");
            return state == null ? "" : String.valueOf(Reflect.call(state, "getName"));
        } catch (Throwable t) { return ""; }
    }
    /** Dragging: the dedicated state, or the grapple already accepted. */
    public static boolean isDragging(Object character) {
        if (character == null) return false;
        if (DRAGGING_STATE.equals(stateName(character))) return true;
        try { return Boolean.TRUE.equals(Reflect.call(character, "isGrappling")); }
        catch (Throwable t) { return false; }
    }
    /** Throwing the grappled body into a container / out of a window / over a fence. */
    public static boolean isThrowing(Object character) {
        if (character == null) return false;
        for (String m : new String[]{"isGrappleThrowIntoContainer", "isGrappleThrowOutWindow", "isGrappleThrowOverFence"}) {
            try { if (Boolean.TRUE.equals(Reflect.call(character, m))) return true; }
            catch (Throwable ignored) {}
        }
        return false;
    }

    /** OnEnter of BaseGrappleable.setGrapplePosOffsetForward: the node's value plus ours. */
    public static float offsetForward(Object grappleable, float requested) {
        try {
            Object character = Reflect.get(grappleable, "character");
            if (character == null) return requested;
            float extra = forward(character);
            if (extra == 0f) return requested;
            Float shoulder = shoulderPickupDistance(character);
            boolean shoulderLift = shoulder != null && shoulderGroundPickup(currentCorpseClip(character), requested);
            String state = stateName(character);
            boolean dragging = DRAGGING_STATE.equals(state) || isDragging(character);
            if (OFFSET_LOGS.size() < 8 && OFFSET_LOGS.add(state + "|" + String.format(Locale.ROOT, "%.3f", requested)))
                System.out.println(String.format(Locale.ROOT,
                        "[WTAGarou Java][Grapple] node forward offset %.3f in state %s; wolf extra %.2f %s",
                        requested, state, extra, dragging ? "applied" : "held (not dragging)"));
            if (!dragging) return requested;
            offsetsApplied.incrementAndGet();
            if (shoulderLift) return direction(character, requested) * shoulder;
            return requested + direction(character, requested) * extra;
        } catch (Throwable t) {
            failures.incrementAndGet();
            return requested;
        }
    }

    /** 0.4.42: the node offset is measured along the grapple's own axis, and
     * that axis flips with the grip. Oct 6 console: a body grabbed by the
     * shoulders (trunk drag-out, Bob_IdleDrag_Person) has +0.30 and our +1.0
     * put it correctly at the wolf's head; a body grabbed by the legs from the
     * ground (Bob_IdleDrag_PersonLegs) has -0.30, and +1.0 swung it round to
     * the wolf's back. The extra therefore follows the node's sign; a node at
     * ~0 keeps the last sign seen for that character (positive by default). */
    private static final Map<Object, Float> LAST_SIGN = Collections.synchronizedMap(new WeakHashMap<>());
    static float direction(Object character, float requested) {
        if (requested > 0.02f) { LAST_SIGN.put(character, 1f); return 1f; }
        if (requested < -0.02f) { LAST_SIGN.put(character, -1f); return -1f; }
        Float last = LAST_SIGN.get(character);
        return last == null ? 1f : last;
    }

    /** A corpse-handling clip started on this wolf (see WolfRuntime.beginTrack). */
    public static void markCorpseClip(Object character) { markCorpseClip(character, null); }
    public static void markCorpseClip(Object character, String humanClip) {
        if (character == null) return;
        CORPSE_CLIP_AT.put(character, System.nanoTime());
        if (humanClip != null) CORPSE_CLIP_NAME.put(character, humanClip);
    }
    /** A non-corpse clip started: the lift / lower is over. */
    public static void clearCorpseClip(Object character) {
        if (character != null) CORPSE_CLIP_NAME.remove(character);
    }
    static String currentCorpseClip(Object character) {
        return character == null ? null : CORPSE_CLIP_NAME.get(character);
    }
    /** Shoulders grab from the ground: a pickup clip that is not the legs
     * grab, with the ground node offset (|0.7..0.9|; the trunk drag-out,
     * Bob_Cont_DragOut, is +0.30 and not a pickup). */
    static boolean shoulderGroundPickup(String humanClip, float requested) {
        if (humanClip == null) return false;
        String n = humanClip.toLowerCase(Locale.ROOT).replace("_", "");
        return n.contains("pickup") && !n.contains("legs") && Math.abs(requested) >= 0.5f;
    }

    /** 0.4.44: IsoGameCharacter.throwGrappledIntoInventory on a container that
     * is not the character's own inventory (trunk, seat, trailer). The clip it
     * starts has no corpse noun we can rely on, so WolfRuntime treats the next
     * stationary clip as corpse handling. The Crinos / Hispo stow (own
     * inventory) is left exactly as confirmed. */
    public static void markThrow(Object character, Object container) {
        if (character == null) return;
        try {
            Object own = Reflect.call(character, "getInventory");
            if (own != null && own == container) return;
        } catch (Throwable ignored) {}
        THROW_AT.put(character, System.nanoTime());
        if (THROW_LOGS.getAndIncrement() < 4)
            System.out.println("[WTAGarou Java][Grapple] body thrown into a container; next stationary clip is corpse handling");
    }
    private static final java.util.concurrent.atomic.AtomicInteger THROW_LOGS = new java.util.concurrent.atomic.AtomicInteger();
    public static boolean recentThrow(Object character, double seconds) {
        Long at = character == null ? null : THROW_AT.get(character);
        if (at == null) return false;
        return (System.nanoTime() - at) <= (long) (seconds * 1_000_000_000d);
    }
    /** True when a corpse-handling clip started within the last `seconds`. */
    public static boolean recentCorpseClip(Object character, double seconds) {
        Long at = character == null ? null : CORPSE_CLIP_AT.get(character);
        if (at == null) return false;
        return (System.nanoTime() - at) <= (long) (seconds * 1_000_000_000d);
    }
    /** Lua-facing: is this character handling a corpse right now? */
    public static boolean isCorpseHandling(Object character) {
        return recentCorpseClip(character, 1.5d) || isDragging(character) || isThrowing(character);
    }

    /** Log each human clip seen while dragging, once (which names reverse). */
    static void logDragClip(String human, String wolf, boolean reversed) {
        if (DRAG_LOGS.size() < 24 && DRAG_LOGS.add(human))
            System.out.println("[WTAGarou Java][Drag] clip '" + human + "' while dragging -> " + wolf
                    + (reversed ? " (pose reversed)" : ""));
    }

    public static String status() {
        return "grapple forward offsets applied=" + offsetsApplied.get() + "; flagged=" + FORWARD.size()
                + "; failures=" + failures.get();
    }
}
