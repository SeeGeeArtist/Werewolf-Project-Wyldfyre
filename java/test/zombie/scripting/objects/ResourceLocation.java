package zombie.scripting.objects;
import java.util.Locale;
/** Test stub mirroring B42.20: "namespace:path", lower-cased, default namespace base. */
public final class ResourceLocation {
    public final String id;
    private ResourceLocation(String ns, String path) { this.id = (ns + ":" + path).toLowerCase(Locale.ENGLISH); }
    public static ResourceLocation of(String s) {
        String[] p = s.split(":", 2);
        return p.length == 1 ? new ResourceLocation("base", p[0]) : new ResourceLocation(p[0], p[1]);
    }
    @Override public boolean equals(Object o) { return o instanceof ResourceLocation r && r.id.equals(id); }
    @Override public int hashCode() { return id.hashCode(); }
    @Override public String toString() { return id; }
}
