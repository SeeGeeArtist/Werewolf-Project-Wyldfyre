package zombie.core.skinnedmodel.visual;
import java.util.ArrayList;
import zombie.core.skinnedmodel.model.Model;
/** TEST ONLY. */
public class HumanVisual extends BaseVisual {
    public Model model;
    public zombie.core.ImmutableColor color;
    public void setSkinColor(zombie.core.ImmutableColor c) { color=c; }
    public String skin="HumanSkin",hair="HumanHair",beard="HumanBeard",script="MaleBody";
    public ArrayList<Object> bodyVisuals=new ArrayList<>();
    public HumanVisual(IHumanVisual owner) {}
    public void copyFrom(BaseVisual other) {
        HumanVisual h=(HumanVisual)other;
        model=h.model; skin=h.skin; hair=h.hair; beard=h.beard; script=h.script;
        bodyVisuals.addAll(h.bodyVisuals);
    }
    public void setForceModel(Model m) { model=m; }
    public void setForceModelScript(String s) { script=s; }
    public void setSkinTextureName(String s) { skin=s; }
    public void setHairModel(String s) { hair=s; }
    public void setBeardModel(String s) { beard=s; }
    public ArrayList<Object> getBodyVisuals() { return bodyVisuals; }
}
