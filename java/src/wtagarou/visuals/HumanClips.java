package wtagarou.visuals;

import java.util.Locale;
import java.util.Map;

/** Read-only lookup of the human (Bob) rig's loaded animation clips. */
public final class HumanClips {
    static volatile Map<?,?> override;   // tests
    public static boolean has(String clip) {
        if (clip == null || clip.isEmpty()) return false;
        try {
            Map<?,?> clips = override;
            if (clips == null) {
                Object manager = Class.forName("zombie.core.skinnedmodel.ModelManager").getField("instance").get(null);
                Object human = Reflect.get(Reflect.get(manager, "maleModel"), "tag");
                if (human == null) return false;
                clips = (Map<?,?>) Reflect.get(human, "animationClips");
            }
            if (clips == null) return false;
            if (clips.containsKey(clip)) return true;
            String lower = clip.toLowerCase(Locale.ROOT);
            for (Object key : clips.keySet()) if (key != null && lower.equals(key.toString().toLowerCase(Locale.ROOT))) return true;
            return false;
        } catch (ReflectiveOperationException | RuntimeException e) {
            return false;
        }
    }
}
