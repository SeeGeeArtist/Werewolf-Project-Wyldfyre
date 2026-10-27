package zombie.iso.objects;
import java.util.HashMap;
import zombie.core.skinnedmodel.visual.*;
/** TEST ONLY. Does not implement any real corpse engine behavior. */
public class IsoDeadBody implements IHumanVisual {
    public static class Table extends HashMap<Object,Object> {
        public Object rawget(Object key) { return get(key); }
    }
    public Table modData=new Table(),data=new Table();
    public HumanVisual visual=new HumanVisual(this);
    public boolean skeleton;
    public IsoDeadBody() { modData.put("WTAGarou",data); }
    public Table getModData() { return modData; }
    public boolean isSkeleton() { return skeleton; }
}
