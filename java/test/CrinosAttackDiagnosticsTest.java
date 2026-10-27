import java.util.*;
import wtagarou.visuals.WTAGarouJava;

public class CrinosAttackDiagnosticsTest {
    public static class Node {
        public String name="WTAGarouCrinosClaw",animName="Bob_Attack1Hand01_Hit";
        public int conditionPriority=1;
    }
    public static class State { public List<Object> nodes=new ArrayList<>(); }
    public static class Set { public String name="player"; public Map<String,Object> states=new HashMap<>(); }
    public static class Animator {
        public Set animSet=new Set();
        public String GetDebug() { return "State: player/shove\nNode: ShoveDefault\nAnim: Bob_Shove"; }
    }
    public static class Player {
        public Animator animator=new Animator();
        public Animator getAdvancedAnimator() { return animator; }
        public boolean getVariableBoolean(String key) { return key.equals("WTAGarouCrinosUnarmed"); }
    }
    public static void main(String[] args) {
        Player p=new Player(); State shove=new State(); Node node=new Node();
        shove.nodes.add(node); p.animator.animSet.states.put("shove",shove);
        String status=WTAGarouJava.debugCrinosAttack(p);
        assert status.contains("customNodeLoaded=true") && status.contains("eligible=true");
        assert status.contains("Bob_Attack1Hand01_Hit") && status.contains("Anim: Bob_Shove");
        assert shove.nodes.size()==1 && shove.nodes.get(0)==node : "read-only";
        shove.nodes.clear();
        assert WTAGarouJava.debugCrinosAttack(p).contains("customNodeLoaded=false");
        p.animator.animSet.states.clear();
        assert WTAGarouJava.debugCrinosAttack(p).contains("shoveState=absent");
        p.animator=null;
        assert WTAGarouJava.debugCrinosAttack(p).equals("animator=unavailable");
        assert WTAGarouJava.debugCrinosAttack(new Object()).contains("unavailable");
        System.out.println("PASS: read-only Crinos attack node/eligibility/live-clip diagnostics.");
    }
}
