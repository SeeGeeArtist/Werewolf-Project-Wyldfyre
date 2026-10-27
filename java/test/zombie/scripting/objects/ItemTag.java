package zombie.scripting.objects;
import java.util.HashMap;
/** Test stub: registry lookup returns null for unregistered tags, register twice throws (B42.20 Registry). */
public final class ItemTag {
    private static final HashMap<ResourceLocation, ItemTag> registry = new HashMap<>();
    public final ResourceLocation id;
    private ItemTag(ResourceLocation id) { this.id = id; }
    public static ItemTag get(ResourceLocation id) { return registry.get(id); }
    public static ItemTag register(String id) {
        ResourceLocation loc = ResourceLocation.of(id);
        if (registry.containsKey(loc)) throw new IllegalArgumentException("Tried to register duplicate object: " + loc);
        ItemTag t = new ItemTag(loc); registry.put(loc, t); return t;
    }
    public static void reset() { registry.clear(); }
    @Override public String toString() { return id.toString(); }
}
