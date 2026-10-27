import wtagarou.visuals.*;

public final class FurTest {
    public static class Character {
        public boolean dead;
        public boolean isDead() { return dead; }
    }
    public static class Part {
        public Character owner;
        public Part(Character c) { owner = c; }
        public Character getParentChar() { return owner; }
    }
    public static class Node {
        private Part bodyPart;
        private float insulationLayerMultiplierUi, insulation;
        public float clothing, windresist = .17f, bodyWetness = .4f;
        public Node(Character c, float scale) {
            bodyPart = new Part(c); insulationLayerMultiplierUi = scale;
        }
        public void calculateInsulation() { insulation = clothing; }
        public float ui() { return insulation * insulationLayerMultiplierUi; }
    }
    public static void main(String[] args) throws Exception {
        var inst = net.bytebuddy.agent.ByteBuddyAgent.install();
        WolfCombatTest.install(inst, Node.class, FurInsulationPatch.class, "calculateInsulation");
        Character c = new Character(), other = new Character();
        Node[] nodes = new Node[17];
        for (int i=0;i<nodes.length;i++) nodes[i] = new Node(c, i%2==0 ? .5f : 1f);
        assert WTAGarouJava.setFurInsulation(c, .5);
        for (Node n : nodes) {
            for(int j=0;j<50;j++) n.calculateInsulation();
            assert n.ui() == .5f : "every part reaches medium with no accumulation";
            assert n.windresist == .17f && n.bodyWetness == .4f : "weather properties untouched";
            n.clothing = 2; n.calculateInsulation();
            assert n.insulation == 2 : "better clothing never reduced";
        }
        Node stranger = new Node(other, 1); stranger.calculateInsulation();
        assert stranger.ui() == 0 : "ordinary characters unchanged";
        Node n = new Node(c, 1); c.dead = true; n.calculateInsulation();
        assert n.ui() == 0;
        c.dead = false; WTAGarouJava.setFurInsulation(c, 0); n.calculateInsulation();
        assert n.ui() == 0 : "human form removes fur";
        WTAGarouJava.setFurInsulation(c, .5); WTAGarouJava.clear(c); n.calculateInsulation();
        assert n.ui() == 0 : "death/trait removal clear profile";
        assert !WTAGarouJava.setFurInsulation(c, Double.NaN);
        assert FurRuntime.failures == 0;
        System.out.println("PASS: fur floor on all 17 synthetic thermal nodes; actual woven advice, not climate playtest.");
    }
}
