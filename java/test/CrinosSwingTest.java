import java.util.HashMap;
import java.util.Map;
import wtagarou.visuals.*;

/** Real ZombieBuddy advice on a fixture shaped like IsoPlayer.pressedAttack
 *  (0.4.69: spacebar shove vs attack-button unarmed swing). */
public class CrinosSwingTest {
    static int checks;
    static void check(boolean ok, String why) { checks++; if (!ok) throw new AssertionError("FAIL: " + why); }

    public static class Player {
        public final Map<String, Object> vars = new HashMap<>();
        public boolean meleePressed, attackStarted; public int presses;
        public boolean isMeleePressed() { return meleePressed; }
        public boolean isAttackStarted() { return attackStarted; }
        public boolean getVariableBoolean(String k) { return Boolean.TRUE.equals(vars.get(k)); }
        public void setVariable(String k, boolean v) { vars.put(k, v); }
        public void pressedAttack() { presses++; attackStarted = true; }
        boolean swing() { return getVariableBoolean(CrinosSwingRuntime.SWING_VARIABLE); }
    }
    public static class Broken extends Player {
        @Override public boolean isMeleePressed() { throw new IllegalStateException("no input"); }
    }

    public static void main(String[] args) throws Exception {
        var inst = net.bytebuddy.agent.ByteBuddyAgent.install();
        WolfCombatTest.install(inst, Player.class, CrinosSwingPatch.class, "pressedAttack");

        Player human = new Player();
        human.pressedAttack();
        check(human.presses == 1 && !human.swing(), "Homid / armed: variable written false, attack proceeds");

        Player crinos = new Player();
        crinos.setVariable(CrinosSwingRuntime.UNARMED_VARIABLE, true);
        crinos.meleePressed = true;                 // spacebar / LT shove
        crinos.pressedAttack();
        check(!crinos.swing() && CrinosSwingRuntime.shoves.get() == 1, "shove button -> vanilla shove node (flag off)");

        crinos.attackStarted = false; crinos.meleePressed = false; // ctrl+click / RT
        crinos.pressedAttack();
        check(crinos.swing() && CrinosSwingRuntime.swings.get() == 1, "attack button -> one-handed swing (flag on)");

        crinos.meleePressed = true;                 // space tapped mid-swing: attack already started
        crinos.pressedAttack();
        check(crinos.swing() && CrinosSwingRuntime.shoves.get() == 1, "a press during a running attack never re-decides the node");

        crinos.attackStarted = false; crinos.meleePressed = true;
        crinos.pressedAttack();
        check(!crinos.swing() && CrinosSwingRuntime.shoves.get() == 2, "next shove press decides again");

        crinos.attackStarted = false; crinos.meleePressed = false;
        crinos.setVariable(CrinosSwingRuntime.UNARMED_VARIABLE, false); // picked up a weapon
        crinos.pressedAttack();
        check(!crinos.swing() && CrinosSwingRuntime.swings.get() == 1, "armed Crinos: attack button is a normal weapon swing, flag off");

        Broken broken = new Broken();
        WolfCombatTest.install(inst, Broken.class, CrinosSwingPatch.class, "pressedAttack");
        broken.setVariable(CrinosSwingRuntime.UNARMED_VARIABLE, true);
        broken.pressedAttack();
        check(broken.presses == 1 && !broken.swing(), "reflection failure fails closed: vanilla shove, attack still runs");
        check(!CrinosSwingRuntime.onPressedAttack(null), "null player tolerated");

        System.out.println("CrinosSwingTest passed " + checks + " checks; swings=" + CrinosSwingRuntime.swings.get()
                + " shoves=" + CrinosSwingRuntime.shoves.get());
    }
}
