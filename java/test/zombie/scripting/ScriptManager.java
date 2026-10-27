package zombie.scripting;
import zombie.core.skinnedmodel.ModelManager;

/** Diagnostic fixture only; never packaged into the mod. */
public class ScriptManager {
    public static final ScriptManager instance=new ScriptManager();
    public Object script=new Object();
    public static class Rig {
        public Object modelMesh=ModelManager.instance.wolf.mesh;
    }
    public Rig rig=new Rig();
    public Object getModelScript(String name) {
        if (!name.equals("WTAGarou_Lupus")) throw new AssertionError(name);
        return script;
    }
    public Object getAnimationsMesh(String name) {
        if (!name.equals("WTAGarou_Wolf")) throw new AssertionError(name);
        return rig;
    }
}
