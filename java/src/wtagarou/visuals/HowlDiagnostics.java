package wtagarou.visuals;

import java.util.List;

/** 0.4.70 read-only howl dump: every live anim node/track with its layer,
 *  whether the track carries a bone mask, and the effective per-bone weight
 *  for the right upper arm, neck and head. Printed once per howl from Lua
 *  (first HowlTick) so the console shows which track moves the arm. Never
 *  changes animation state. */
public final class HowlDiagnostics {
    private static final String[] BONES = {"Bip01_R_UpperArm", "Bip01_L_UpperArm", "Bip01_Neck", "Bip01_Head", "Bip01_Spine1"};

    public static String describe(Object character) {
        try {
            Object animator = Reflect.call(character, "getAdvancedAnimator");
            if (animator == null) return "animator=unavailable";
            Object root = Reflect.call(animator, "getRootLayer");
            Object skin = root == null ? null : Reflect.call(root, "getSkinningData");
            int[] idx = new int[BONES.length];
            for (int i = 0; i < BONES.length; i++) {
                Object bone = skin == null ? null : Reflect.call(skin, "getBone", String.class, BONES[i]);
                idx[i] = bone == null ? -1 : (Integer) Reflect.get(bone, "index");
            }
            StringBuilder out = new StringBuilder();
            out.append("howling=").append(Reflect.call(character, "getVariableBoolean", String.class, "WTAGarou_Howling"))
               .append(" mask=").append(Reflect.call(character, "getVariableBoolean", String.class, "WTAGarou_HowlMask"))
               .append(" masked=").append(HowlMaskRuntime.masked.get())
               .append(" root=").append(HowlMaskRuntime.rootMasks.get())
               .append(" repairs=").append(HowlMaskRuntime.repairs.get());
            appendLayer(out, "root", root, idx);
            int subs = (Integer) Reflect.call(animator, "getSubLayerCount");
            for (int i = 0; i < subs; i++) appendLayer(out, "sub" + i, Reflect.call(animator, "getSubLayerAt", int.class, i), idx);
            return out.toString();
        } catch (ReflectiveOperationException | RuntimeException e) {
            return "howl diagnostic unavailable: " + e;
        }
    }

    private static void appendLayer(StringBuilder out, String label, Object layer, int[] idx) throws ReflectiveOperationException {
        if (layer == null) return;
        out.append(" | ").append(label).append('[');
        Object state = Reflect.get(layer, "state");
        out.append(state == null ? "-" : Reflect.get(state, "name")).append("] ");
        Object nodes = Reflect.call(layer, "getLiveAnimNodes");
        if (!(nodes instanceof List<?> list)) return;
        for (Object node : list) {
            Object src = Reflect.call(node, "getSourceNode");
            out.append("node=").append(src == null ? "?" : Reflect.get(src, "name")).append('{');
            Object tracks = Reflect.get(node, "animationTracks");
            if (tracks instanceof List<?> ts) {
                for (Object t : ts) {
                    out.append(Reflect.call(t, "getName")).append(" w=").append(fmt(Reflect.call(t, "getBlendWeight")))
                       .append(" mask=").append(Reflect.call(t, "hasBoneMask")).append(" bones=");
                    for (int i = 0; i < BONES.length; i++) {
                        if (idx[i] < 0) { out.append("?"); }
                        else out.append(fmt(Reflect.call(t, "getBoneWeight", int.class, idx[i])));
                        if (i < BONES.length - 1) out.append('/');
                    }
                    out.append("; ");
                }
            }
            out.append("} ");
        }
    }

    private static String fmt(Object v) {
        return v instanceof Number n ? String.format(java.util.Locale.ROOT, "%.2f", n.floatValue()) : String.valueOf(v);
    }
}
