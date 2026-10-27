import wtagarou.visuals.*;
import zombie.core.skinnedmodel.ModelManager;
import net.bytebuddy.agent.ByteBuddyAgent;

/** Shader selection mirrors B42 Shader.startCharacter: skinned geometry uses
 * the skin palette, not the rigid xfrm. No GPU render is performed here. */
public class WolfHarnessScaleTest {
    static int checks;
    static void close(float value,float expected,String why) {
        checks++;
        if(Math.abs(value-expected)>0.00001f) throw new AssertionError(why+": "+value+" != "+expected);
    }
    public static class Data {
        public WolfCombatTest.Instance modelInstance;
        public float xfrmScale=1f, palettePosition=2f;
        public Object tex;
    }
    public static class Renderer {
        public float DrawChar(WolfCombatTest.Slot slot,Data data,boolean fail) {
            if(fail) throw new IllegalArgumentException("fixture draw failure");
            boolean skinned=data.modelInstance.model==ModelManager.instance.wolf
                    || data.modelInstance.model==ModelManager.instance.harness
                    || data.modelInstance.model==ModelManager.instance.harnessCamo;
            return (skinned ? data.palettePosition : data.xfrmScale)*slot.finalScale;
        }
    }
    public static void main(String[] args) throws Exception {
        WolfCombatTest.install(ByteBuddyAgent.install(),Renderer.class,DrawCharPatch.class,"DrawChar");
        var character=new WolfCombatTest.Character();
        WTAGarouJava.setWolf(character,true);
        var body=new WolfCombatTest.Instance(); body.character=character;
        body.model=ModelManager.instance.wolf; body.animPlayer=new Object();
        var harness=new WolfCombatTest.Instance(); harness.character=character;
        harness.parent=body; harness.model=new Object();
        harness.modelScript=new WolfCombatTest.Script(1);
        harness.attachmentNameParent="WTAGarou_Harness";
        var bodyData=new Data(); bodyData.modelInstance=body;
        var gearData=new Data(); gearData.modelInstance=harness;
        var slot=new WolfCombatTest.Slot(); slot.character=character;
        var renderer=new Renderer();
        for(int repeat=0;repeat<5;repeat++) for(float form:new float[]{1.15f,1.55f,1.15f}) {
            WTAGarouJava.setScale(character,form);
            for(String name:new String[]{"WTAGarou_Harness","WTAGarou_Harness_Camo"}) {
                harness.modelScript.name=name;
                gearData.xfrmScale=50f; // proves a matrix-only scale cannot fix this renderer
                float expected=2f*0.8f*WolfRuntime.BODY_SCALE*form;
                close(renderer.DrawChar(slot,bodyData,false),expected,"body reference");
                close(renderer.DrawChar(slot,gearData,false),expected,"harness follows same body shader scale");
                close(slot.finalScale,0.8f,"slot restored, no cumulative shrink");
                close(harness.scale,1f,"never compensate skinned instance like a rigid item");
            }
        }
        try { renderer.DrawChar(slot,gearData,true); throw new AssertionError("exception swallowed"); }
        catch(IllegalArgumentException expected) { close(slot.finalScale,0.8f,"exceptional draw restores slot"); }
        var previewBody=new WolfCombatTest.Instance(); previewBody.character=character;
        previewBody.model=ModelManager.instance.human;
        harness.parent=previewBody;
        WolfRuntime.hideSubmodel(slot,gearData);
        Object saved=ScaleRuntime.begin(slot,gearData);
        close(slot.finalScale,0.8f*WTAGarouJava.scaleFor(character),"human preview does not get wolf normalization");
        ScaleRuntime.end(saved);
        close(slot.finalScale,0.8f,"preview scale restored");
        System.out.println("PASS: "+checks+" harness/body shader-scale, variant, repeat and exception assertions; not a game render.");
    }
}
