import wtagarou.visuals.*;

/** Real ZombieBuddy advice on a fixture with the engine setter signatures. */
public class StabilityTest {
    static int checks;
    static void check(boolean value,String why) { checks++; if(!value) throw new AssertionError(why); }
    public static class Character {
        public boolean knockedDown, bumpFall;
        public void setKnockedDown(boolean value) { knockedDown=value; }
        public void setBumpFall(boolean value) { bumpFall=value; }
    }
    public static void main(String[] args) throws Exception {
        var inst=net.bytebuddy.agent.ByteBuddyAgent.install();
        WolfCombatTest.installAll(inst,Character.class,new Class<?>[]{StabilityKnockdownPatch.class,StabilityBumpFallPatch.class},
                new String[]{"setKnockedDown","setBumpFall"});
        Character human=new Character(), crinos=new Character(), hispo=new Character();
        check(WTAGarouJava.setStability(crinos,1.0),"register full stability");
        check(WTAGarouJava.setStability(hispo,0.0),"zero clears");
        check(!WTAGarouJava.setStability(crinos,Double.NaN),"reject NaN");
        human.setKnockedDown(true); check(human.knockedDown,"unregistered character still falls");
        human.setBumpFall(true); check(human.bumpFall,"unregistered character still trips");
        crinos.setKnockedDown(true); check(!crinos.knockedDown,"Crinos knockdown refused by advice");
        crinos.setBumpFall(true); check(!crinos.bumpFall,"Crinos bump fall refused by advice");
        crinos.knockedDown=true; crinos.setKnockedDown(false); check(!crinos.knockedDown,"false is always stored (getting up works)");
        hispo.setKnockedDown(true); check(hispo.knockedDown,"cleared stability behaves like human");
        WTAGarouJava.setStability(hispo,0.95);
        int falls=0; for(int i=0;i<2000;i++){ hispo.knockedDown=false; hispo.setKnockedDown(true); if(hispo.knockedDown) falls++; }
        check(falls>20 && falls<250,"0.95 stability refuses roughly 95% of falls, not all: falls="+falls);
        WTAGarouJava.clear(crinos);
        crinos.setKnockedDown(true); check(crinos.knockedDown,"clear() removes stability with the rest of the state");
        check(StabilityRuntime.status().contains("falls refused="),"status reports counters");
        System.out.println("PASS: "+checks+" stability assertions with real ZombieBuddy advice.");
    }
}
