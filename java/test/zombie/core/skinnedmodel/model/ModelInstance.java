package zombie.core.skinnedmodel.model;
import java.util.*;
/** TEST ONLY. Never packaged. */
public class ModelInstance {
    public Object model,animPlayer,character,tex,owner,itemVisual;
    public ModelInstance parent;
    public String parentBoneName,attachmentNameSelf;
    public float scale=1f,tintR=.5f,tintG=.5f,tintB=.5f,depthBias=9f;
    public ModelInstance matrixModel;
    public String meshName,texName;
    public int parentBone;
    public List<Object> sub=new ArrayList<>();
    public void setOwner(Object value) { owner=value; }
    public Object getItemVisual() { return itemVisual; }
    public void reset() { sub.clear(); }
}
