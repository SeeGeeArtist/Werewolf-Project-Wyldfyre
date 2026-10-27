package zombie.inventory;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import zombie.scripting.objects.ItemTag;
/** Test stub of the vanilla tag index: Init rebuilds tagItemMap from every item's getTags(). */
public final class ItemTags {
    private static final ArrayList<Object> emptyList = new ArrayList<>();
    private static final Map<ItemTag, ArrayList<Object>> tagItemMap = new HashMap<>();
    public static void Init(ArrayList<Object> allItems) {
        tagItemMap.clear();
        for (Object item : allItems) {
            if (item == null) continue;
            try {
                for (Object tag : (Iterable<?>) item.getClass().getMethod("getTags").invoke(item)) {
                    tagItemMap.computeIfAbsent((ItemTag) tag, k -> new ArrayList<>()).add(item);
                }
            } catch (ReflectiveOperationException e) { throw new RuntimeException(e); }
        }
    }
    public static ArrayList<Object> getItemsForTag(ItemTag tag) {
        return tagItemMap.containsKey(tag) ? tagItemMap.get(tag) : emptyList;
    }
}
