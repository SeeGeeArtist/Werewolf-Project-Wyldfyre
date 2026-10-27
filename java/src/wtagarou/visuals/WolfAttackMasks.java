package wtagarou.visuals;

import java.util.List;
import java.util.Locale;

/** Stationary bites own hips and hind legs, not just the human upper body.
 * Does not change BlockMovement, root motion, priorities or moving attacks. */
public final class WolfAttackMasks {
    public static volatile int repairs;
    public static Object weightsFor(Object character, String clip, Object previous)
            throws ReflectiveOperationException {
        if (!WolfRuntime.active(character) || clip == null) return previous;
        String pose=poseName(clip).toLowerCase(Locale.ROOT);
        boolean eating=pose.equals("wolf_eat") || pose.equals("wolf_drink");
        if (!eating && !clip.toLowerCase(Locale.ROOT).contains("attack")) return previous;
        if (Boolean.TRUE.equals(Reflect.call(character, "isDead"))) return previous;
        if (!eating && !Boolean.FALSE.equals(Reflect.call(character, "isMoving"))) return previous;
        // A null/empty mask does NOT tell us whether the engine's layer is a
        // root. AnimationPlayer.play itself ignores these weights on roots.
        return WolfRuntime.fullBodyWeights();
    }
    /** Accept native/source names (derived clips preserve that identity)
     * and adapter lookup keys without matching incidental cache-key words. */
    public static String poseName(String name) {
        if (name.startsWith("WTAGarou_Player_")) {
            String[] parts=name.split("\\|",3);
            if (parts.length>=2) return parts[1];
        }
        return WolfRuntime.preferredClipFor(name);
    }

    public static void afterTransfer(Object node, Object track, boolean useMasks) {
        if (!useMasks || node == null || track == null) return;
        try {
            Object layer = Reflect.get(node, "animLayer");
            if (layer == null) return;
            Object character = Reflect.get(layer, "character");
            if (!WolfRuntime.active(character)) return;
            Object clip = Reflect.call(track, "getClip");
            if (clip == null) return;
            String name=String.valueOf(Reflect.get(clip,"name"));
            Object player = Reflect.call(character, "getAnimationPlayer");
            Object skin = Reflect.call(player, "getSkinningData");
            if (skin == null) return;
            String resolved=WolfRuntime.resolveClip(poseName(name),
                    (java.util.Map<?,?>)Reflect.get(skin,"animationClips"));
            // A carried-object/aim gait sublayer may be transferred later,
            // reintroducing its human arm mask after initially looking fine.
            Object weights=WolfRuntime.isGaitClip(resolved) ? List.of()
                    : weightsFor(character,name,null);
            if (weights == null) return;
            Reflect.call(track, "setBoneWeights", List.class, weights);
            Reflect.call(track, "initBoneWeights",
                    Class.forName("zombie.core.skinnedmodel.model.SkinningData"), skin);
            if (repairs++ == 0)
                System.out.println("[WTAGarou Java] wolf layer-transfer mask repair active (inert gait/idle sublayers; eating/drinking and stationary bites include hips/hind legs)");
        } catch (ReflectiveOperationException | RuntimeException error) {
            WolfRuntime.warn("stationary attack mask", error);
        }
    }
}
