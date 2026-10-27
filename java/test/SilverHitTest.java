import net.bytebuddy.agent.ByteBuddyAgent;
import wtagarou.visuals.*;

/** Real woven advice on a BodyDamage-shaped stub: the recorder observes the
 * engine's chosen part without changing damage, and Lua-side semantics
 * (take-once, expiry, per-victim) hold. Not an in-game wound test. */
public class SilverHitTest {
    static int checks;
    static void check(boolean ok,String why) { checks++; if(!ok) throw new AssertionError(why); }
    public static class Victim { public String name; Victim(String n){ name=n; } }
    public static class BodyDamage {
        public Victim parent; public int applied; public float lastDamage;
        public BodyDamage(Victim v){ parent=v; }
        public Victim getParentChar() { return parent; }
        public void applyDamageFromWeapon(int partIndex,float damage,int damageType,float pain) {
            applied++; lastDamage=damage;
        }
    }
    public static void main(String[] args) throws Exception {
        var inst=ByteBuddyAgent.install();
        WolfCombatTest.install(inst,BodyDamage.class,SilverHitPatch.class,"applyDamageFromWeapon");
        Victim a=new Victim("a"), b=new Victim("b");
        BodyDamage bdA=new BodyDamage(a), bdB=new BodyDamage(b);
        check(WTAGarouJava.takeWeaponHitPart(a,1000)==-1,"nothing recorded yet");
        bdA.applyDamageFromWeapon(7,1.5f,0,0.2f);
        check(bdA.applied==1 && bdA.lastDamage==1.5f,"engine damage path untouched");
        check(SilverHitRuntime.observed,"advice observed the hit");
        check(WTAGarouJava.takeWeaponHitPart(b,1000)==-1,"other victim has no record");
        check(WTAGarouJava.takeWeaponHitPart(a,1000)==7,"recorded part index returned");
        check(WTAGarouJava.takeWeaponHitPart(a,1000)==-1,"take clears the record");
        bdA.applyDamageFromWeapon(3,0.5f,0,0f);
        bdA.applyDamageFromWeapon(9,0.5f,0,0f);
        check(WTAGarouJava.takeWeaponHitPart(a,1000)==9,"latest hit overwrites earlier one");
        bdB.applyDamageFromWeapon(12,0.5f,0,0f);
        Thread.sleep(30);
        check(WTAGarouJava.takeWeaponHitPart(b,5)==-1,"stale record expires");
        check(WTAGarouJava.takeWeaponHitPart(b,1000)==-1,"expired record also cleared");
        bdA.applyDamageFromWeapon(-1,0.5f,0,0f);
        check(WTAGarouJava.takeWeaponHitPart(a,1000)==-1,"negative part index ignored");
        bdA.applyDamageFromWeapon(4,0.5f,0,0f);
        bdB.applyDamageFromWeapon(5,0.5f,0,0f);
        check(SilverHitRuntime.pending()==2,"records are per victim");
        WTAGarouJava.clearAll();
        check(SilverHitRuntime.pending()==0,"clearAll drops pending hits");
        check(WTAGarouJava.takeWeaponHitPart(null,1000)==-1,"null victim safe");
        System.out.println("PASS: "+checks+" weapon-hit recorder advice/take-once/expiry checks; not an in-game wound test.");
    }
}
