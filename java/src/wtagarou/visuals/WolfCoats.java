package wtagarou.visuals;

import java.util.Collections;
import java.util.Map;
import java.util.WeakHashMap;

/** Per-character cosmetic texture; never mutate the shared wolf model. */
public final class WolfCoats {
    private static final Map<Object,Object> TEXTURES=Collections.synchronizedMap(new WeakHashMap<>());
    private static final Map<Object,String> KEYS=Collections.synchronizedMap(new WeakHashMap<>());
    public static void set(Object character,String key) {
        setPath(character,"blonde".equals(key) ? "media/textures/Body/WTAGarou_Wolf_Blonde.png" : null);
    }
    public static void setPath(Object character,String path) {
        if (character==null) return;
        if (path==null || path.equals("media/textures/Body/WTAGarou_Wolf.png")) { clear(character); return; }
        if (!path.matches("media/textures/Body/WTAGarou_Wolf_[A-Za-z0-9_-]+\\.png")) { clear(character); return; }
        if (path.equals(KEYS.get(character))) return;
        clear(character); // missing new texture must not leave the old coat
        try {
            Object texture=Class.forName("zombie.core.textures.Texture").getMethod("getSharedTexture",String.class)
                    .invoke(null,path);
            if (texture != null) { TEXTURES.put(character,texture); KEYS.put(character,path); }
        } catch (ReflectiveOperationException | RuntimeException error) { WolfRuntime.warn("wolf coat",error); }
    }
    public static Object texture(Object character,Object fallback) {
        Object texture=TEXTURES.get(character);
        if (texture != null) try {
            if (Boolean.TRUE.equals(Reflect.call(texture,"isReady"))) return texture;
        } catch (ReflectiveOperationException | RuntimeException ignored) {}
        return fallback;
    }
    public static void clear(Object character) { TEXTURES.remove(character); KEYS.remove(character); }
    public static void clearAll() { TEXTURES.clear(); KEYS.clear(); }
}
