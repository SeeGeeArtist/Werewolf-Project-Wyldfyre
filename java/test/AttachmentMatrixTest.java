import wtagarou.visuals.*;
import zombie.core.skinnedmodel.ModelManager;
import net.bytebuddy.agent.ByteBuddyAgent;

/** Optional numerical test using the user's JOML classes on the classpath.
 * No game binary is bundled. Uses synthetic bone placement, not a renderer.
 * Run with test fixtures BEFORE the game JAR on the runtime classpath. */
public class AttachmentMatrixTest {
    public static class Mesh { public Object transform; }
    public static class ImportedModel { public Mesh mesh=new Mesh(); }
    static int checks;
    static final Class<?>[] FLOAT3={float.class,float.class,float.class};
    static void close(float actual,float expected,String message) {
        checks++;
        if (Math.abs(actual-expected)>0.0001f) throw new AssertionError(message+": "+actual+" != "+expected);
    }
    public static class Data {
        public WolfCombatTest.Instance modelInstance;
        public Object xfrm;
        public Object properties;
        public Data() throws Exception {
            xfrm=Class.forName("org.joml.Matrix4f").getConstructor().newInstance();
            properties=Class.forName("zombie.core.rendering.ShaderPropertyBlock").getConstructor().newInstance();
        }
        public Data transformToParent(Object value) throws Exception {
            if (!(value instanceof Data parent)) return this;
            Reflect.call(xfrm,"set",Class.forName("org.joml.Matrix4fc"),parent.xfrm);
            Reflect.call(xfrm,"transpose");
            // Known synthetic bone placement; rest of order matches the
            // uploaded transformToParent (self/mesh transforms are identity).
            if (!WolfRuntime.isHarness(modelInstance))
                Reflect.call(xfrm,"translate",FLOAT3,1f,2f,3f);
            Reflect.call(xfrm,"scale",float.class,modelInstance.scale);
            if (modelInstance.model instanceof ImportedModel)
                Reflect.call(xfrm,"scale",float.class,100f);
            Reflect.call(xfrm,"transpose");
            return this;
        }
    }
    static float number(Object matrix,String name) throws Exception {
        return ((Number)Reflect.call(matrix,name)).floatValue();
    }
    static float axisScale(Object matrix) throws Exception {
        // Stored transposed: the first row is the original first column.
        float x=number(matrix,"m00"),y=number(matrix,"m10"),z=number(matrix,"m20");
        return (float)Math.sqrt(x*x+y*y+z*z);
    }
    public static void main(String[] args) throws Exception {
        var instrumentation=ByteBuddyAgent.install();
        WolfCombatTest.install(instrumentation,Data.class,MouthCarryPatch.class,"transformToParent");
        WolfCombatTest.install(instrumentation,WolfCombatTest.Instance.class,WolfAttachmentResetPatch.class,"reset");
        var character=new WolfCombatTest.Character();
        if (!WTAGarouJava.setWolf(character,true).equals("wolf")) throw new AssertionError("fixture wolf missing");
        WTAGarouJava.setWolfSlot("belt_left","Bip01_Spine2",0,0,0,0,0,0);
        WTAGarouJava.setSaddlebagTransform(0,0,0,0,0,0);
        WTAGarouJava.setSaddlebagScale(1);
        WTAGarouJava.setHarnessTransform(0,0,0,0,0,0,1);
        var body=new WolfCombatTest.Instance(); body.character=character; body.model=ModelManager.instance.wolf;
        body.animPlayer=new WolfCombatTest.Player();
        Data parent=new Data(); parent.modelInstance=body;
        var pooled=new WolfCombatTest.Instance();
        for (int repeat=0;repeat<8;repeat++) for (float form:new float[]{1f,1.35f,1.15f,1.55f}) {
            WTAGarouJava.setScale(character,form);
            for (String attachment:new String[]{"WTAGarou_Saddlebags","WTAGarou_Harness","belt_left_screwdriver"}) {
                pooled.reset();
                pooled.character=character; pooled.parent=body; pooled.model=new Object();
                pooled.scale=0.6f; pooled.modelScript=new WolfCombatTest.Script(0.6f);
                pooled.attachmentNameParent=attachment;
                boolean gear=attachment.startsWith("WTAGarou_");
                boolean harness=attachment.equals("WTAGarou_Harness");
                float size=harness ? 1f : 0.6f*(gear?form:1f);
                float anchor=harness ? 0f : WolfRuntime.BODY_SCALE*form;
                Data data=new Data(); data.modelInstance=pooled;
                data.transformToParent(parent);
                close(axisScale(data.xfrm),size,"mesh size "+attachment);
                close(number(data.xfrm,"m03"),anchor,"bone anchor x");
                close(number(data.xfrm,"m13"),2*anchor,"bone anchor y");
                close(number(data.xfrm,"m23"),3*anchor,"bone anchor z");
                Object parameter=Reflect.call(properties(data),"GetParameter",String.class,"transform");
                Object copied=Reflect.call(parameter,"GetMatrix4");
                close(((Number)Reflect.get(copied,"m00")).floatValue(),number(data.xfrm,"m00"),"instanced scale copy current");
                close(((Number)Reflect.get(copied,"m03")).floatValue(),number(data.xfrm,"m03"),"instanced placement copy current");
                // A second rebuild uses parent's matrix again, not ours.
                data.transformToParent(parent);
                close(axisScale(data.xfrm),size,"no accumulation");
                var slot=new WolfCombatTest.Slot(); slot.character=character; slot.finalScale=1f;
                Object saved=ScaleRuntime.begin(slot,data);
                close(slot.finalScale,harness ? WolfRuntime.BODY_SCALE*form : 1f,
                        "skinned harness scales like body; static gear gets no second scale");
                ScaleRuntime.end(saved);
                close(slot.finalScale,1f,"exact slot scale restored");
                // A scope inherits the matrix; it gets no second body scale.
                if (!gear) {
                    var scope=new WolfCombatTest.Instance(); scope.parent=pooled; scope.model=new Object();
                    scope.character=character; scope.attachmentNameParent="scope";
                    Data child=new Data(); child.modelInstance=scope; child.transformToParent(data);
                    close(axisScale(child.xfrm),0.6f,"weapon child inherits once");
                }
            }
        }
        pooled.reset(); pooled.character=character; pooled.parent=body;
        pooled.scale=0.6f; pooled.modelScript=new WolfCombatTest.Script(0.6f);
        pooled.attachmentNameParent="WTAGarou_Saddlebags";
        ImportedModel imported=new ImportedModel();
        imported.mesh.transform=Class.forName("org.joml.Matrix4f").getConstructor().newInstance();
        Reflect.call(imported.mesh.transform,"scale",float.class,100f);
        pooled.model=imported;
        close(WolfRuntime.bagImportUnits(pooled),100f,"import unit scale extracted from mesh");
        Data bag=new Data(); bag.modelInstance=pooled;
        bag.transformToParent(parent);
        float baseline=number(bag.xfrm,"m03"), size=axisScale(bag.xfrm);
        WTAGarouJava.setSaddlebagTransform(0,0,0,0.05,0,0);
        bag.transformToParent(parent);
        close(number(bag.xfrm,"m03")-baseline,size*0.05f/100f,"offset cancels FBX units only");
        close(axisScale(bag.xfrm),size,"import-unit offset fix never resizes bag");
        WTAGarouJava.setAttachmentPivot("saddlebag",0.05,0,0);
        bag.transformToParent(parent);
        close(number(bag.xfrm,"m03"),baseline,"bag pivot uses same meter convention");
        WTAGarouJava.setAttachmentPivot("saddlebag",0,0,0);
        WTAGarouJava.setSaddlebagTransform(0,0,0,0,0,0);
        System.out.println("PASS: "+checks+" numerical JOML attachment checks; synthetic bone placement, not an in-game visual test.");
    }
    static Object properties(Data data) { return data.properties; }
}
