import wtagarou.visuals.*;
import net.bytebuddy.agent.ByteBuddyAgent;

public class SilverBurnTest {
    static int checks;
    static void close(float a,float b,String why) {
        checks++; if (Math.abs(a-b)>0.00001f) throw new AssertionError(why+": "+a+" != "+b);
    }
    public static class Combat {
        public void applyDamage(Part p,float damage) { p.damage+=damage; }
        public void applyDamage(Character p,float damage) { p.damage+=damage; }
    }
    public static class Character { public float damage; }
    static final Combat combat=new Combat();
    public static class Part {
        public float health=100;
        public final Body body=new Body();
        public float getHealth() { return health; }
        public Part getParentChar() { return this; }
        public Body getBodyDamage() { return body; }
        public float burn=2, damage;
        public boolean bandaged, fail;
        public Part nested;
        public float getBurnTime() { return burn; }
        public float getDamageScaler() { return 0.0057142857f; }
        public boolean bandaged() { return bandaged; }
        public float nativeDamage(float constant) {
            return constant*getDamageScaler()*zombie.GameTime.getInstance().getMultiplier();
        }
        public void DamageUpdate() {
            if (nested!=null) nested.DamageUpdate();
            // Exact shape of the game's separate damage calls, not total HP refund.
            combat.applyDamage(this,nativeDamage(0.9375f)); // scratch
            combat.applyDamage(this,nativeDamage(2.1875f)); // bite
            if (burn>0 && !bandaged) combat.applyDamage(this,nativeDamage(3.75f));
            combat.applyDamage(this,nativeDamage(3.125f)); // fracture/bullet
            if (fail) throw new IllegalStateException("fixture");
        }
    }
    public static class Body {
        public float health=100;
        public float getOverallBodyHealth() { return health; }
    }
    public static void main(String[] args) throws Exception {
        var inst=ByteBuddyAgent.install();
        WolfCombatTest.install(inst,Part.class,SilverBurnUpdatePatch.class,"DamageUpdate");
        WolfCombatTest.installAll(inst,Combat.class,new Class<?>[]{SilverBurnDamagePatch.class},new String[]{"applyDamage"});
        Part silver=new Part(),normal=new Part();
        for (float multiplier:new float[]{0.5f,1,5,20}) {
            zombie.GameTime.getInstance().multiplier=multiplier;
            WTAGarouJava.setSilverBurnDamage(silver,0.04);
            silver.damage=normal.damage=0;
            silver.DamageUpdate(); normal.DamageUpdate();
            float others=silver.nativeDamage(0.9375f)+silver.nativeDamage(2.1875f)+silver.nativeDamage(3.125f);
            close(silver.damage,others+silver.nativeDamage(3.75f)*0.04f,"only silver burn reduced");
            close(normal.damage,others+normal.nativeDamage(3.75f),"ordinary burn unchanged");
            silver.damage=0;
            combat.applyDamage(silver,silver.nativeDamage(3.75f));
            close(silver.damage,silver.nativeDamage(3.75f),"identical external hit unchanged");
            silver.bandaged=true; silver.damage=0; silver.DamageUpdate();
            close(silver.damage,others,"bandage behavior unchanged");
            silver.bandaged=false;
            silver.burn=0; silver.damage=0; silver.DamageUpdate();
            close(silver.damage,others,"healed burn contributes no damage");
            silver.burn=2;
            WTAGarouJava.setSilverBurnDamage(silver,1);
            silver.damage=0; silver.DamageUpdate();
            close(silver.damage,normal.damage,"factor can be cleared");
        }
        WTAGarouJava.setSilverBurnDamage(silver,0.2);
        silver.fail=true;
        try { silver.DamageUpdate(); } catch(IllegalStateException expected) {}
        silver.damage=0; combat.applyDamage(silver,silver.nativeDamage(3.75f));
        close(silver.damage,silver.nativeDamage(3.75f),"exception restores thread scope");
        silver.fail=false; silver.nested=normal; silver.damage=normal.damage=0;
        silver.DamageUpdate();
        close(normal.damage-silver.damage,silver.nativeDamage(3.75f)*0.8f,"nested update restores outer scope");
        Character character=new Character(); combat.applyDamage(character,12);
        close(character.damage,12,"character damage overload untouched");
        silver.nested=null; silver.body.health=20; silver.damage=0;
        Object scope=SilverBurnRuntime.begin(silver);
        close(SilverBurnRuntime.damage(silver,silver.nativeDamage(3.75f)),0,"silver burn cannot cross overall floor");
        close(SilverBurnRuntime.damage(silver,12),12,"external wounds remain lethal at floor");
        SilverBurnRuntime.end(scope);
        silver.body.health=100; silver.health=5;
        scope=SilverBurnRuntime.begin(silver);
        close(SilverBurnRuntime.damage(silver,silver.nativeDamage(3.75f)),0,"part health also protected");
        SilverBurnRuntime.end(scope);
        System.out.println("PASS: "+checks+" scoped silver burn damage assertions.");
    }
}
