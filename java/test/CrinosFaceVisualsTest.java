import java.util.*;
import net.bytebuddy.agent.ByteBuddyAgent;
import net.bytebuddy.ByteBuddy;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.dynamic.loading.ClassReloadingStrategy;
import zombie.core.skinnedmodel.visual.ItemVisuals;
import wtagarou.visuals.*;
import static net.bytebuddy.matcher.ElementMatchers.named;

/** Native-shaped visual snapshots, real advice, no inventory mutations. */
public class CrinosFaceVisualsTest {
    public record Location(String name) { public String toString(){ return name; } }
    public record Script(Object location) { public Object getBodyLocation(){ return location; } }
    public record Visual(Script script) { public Script getScriptItem(){ return script; } }
    public static Visual visual(String location) { return new Visual(new Script(new Location(location))); }
    public static class Human {
        public final ItemVisuals saved=new ItemVisuals();
        public ItemVisuals getBodyVisuals(){ return saved; }
    }
    public static class Sprite { public CrinosCosmeticsTest.Slot modelSlot; }
    public static class Player extends CrinosCosmeticsTest.Character {
        public final Sprite legsSprite=new Sprite();
        public final Human human=new Human();
        public final ItemVisuals worn=new ItemVisuals(), remoteVisuals=new ItemVisuals();
        public boolean remote;
        public Human getHumanVisual() { return human; }
        public void getItemVisuals(ItemVisuals out) {
            out.clear(); out.addAll(remote ? remoteVisuals : worn);
        }
    }
    public static class Pop {
        public ItemVisuals seenWorn,seenBody;
        public boolean fail;
        public void populateCharacterModelSlot(Player p,CrinosCosmeticsTest.Slot slot) {
            p.legsSprite.modelSlot=slot;
            seenWorn=new ItemVisuals(); p.getItemVisuals(seenWorn);
            seenBody=p.human.getBodyVisuals();
            if(fail) throw new IllegalStateException("fixture population failure");
        }
    }
    public static class Creator {
        public ItemVisuals seenWorn,seenBody;
        public boolean fail;
        public void init(Player p) {
            ItemVisuals temporary=new ItemVisuals(); p.getItemVisuals(temporary);
            init(p.human,temporary,p.legsSprite.modelSlot.model);
        }
        public void init(Human human,ItemVisuals worn,Object model) {
            seenWorn=worn; seenBody=human.getBodyVisuals();
            if(fail) throw new IllegalStateException("fixture compositor failure");
        }
        public void init(Object animal,Object model) { seenBody=null; }
    }
    static int checks;
    static void check(boolean ok,String why){ checks++; if(!ok) throw new AssertionError(why); }
    static Player player(boolean remote) {
        Player p=new Player(); p.remote=remote;
        p.worn.add(visual("base:Eyes")); p.worn.add(visual("base:Jacket"));
        p.remoteVisuals.addAll(p.worn);
        p.human.saved.add(visual("base:MakeUp_FullFace"));
        p.human.saved.add(visual("base:UpperArm_Left")); // tattoo, not makeup
        return p;
    }
    public static void main(String[] args) throws Exception {
        for(String location:new String[]{"base:MakeUp_Eyes","base:MakeUp_EyesShadow","base:MakeUp_Lips","base:MakeUp_FullFace",
                "other:MakeUp_Custom"}) check(CrinosFaceVisuals.hidden(visual(location)),"hide "+location);
        // 0.4.69: eyewear and masks are hidden on the wolf head; hats, neck
        // jewellery, bandages and clothing stay.
        for(String location:new String[]{"base:MaskFull","Eyes","base:Eyes","base:LeftEye","base:RightEye","base:MaskEyes","base:Mask"})
            check(CrinosFaceVisuals.hidden(visual(location)),"hide face gear "+location);
        for(String location:new String[]{"base:Hat","base:FullHat","base:Jacket","base:UpperArm_Left",
                "base:Bandage","base:Ears","base:Neck","base:Necklace","base:Nose","base:Shoes","base:Socks"})
            check(!CrinosFaceVisuals.hidden(visual(location)),"preserve "+location);
        // Footwear is hidden only inside a population scope whose character has the legs on.
        Object prevScope=CrinosFaceVisuals.enterPopulation(new Object(),null);
        check(!CrinosFaceVisuals.hidden(visual("base:Shoes")),"no legs: shoes stay");
        check(!CrinosFaceVisuals.hidden(visual("base:Pants")),"no legs: pants stay");
        CrinosFaceVisuals.leave(prevScope);
        // 0.4.71: legwear locations (hidden with the legs on; underwear and tops are not legwear)
        for(String location:new String[]{"Base:Pants","Base:Pants_Skinny","Base:PantsExtra","Base:ShortPants","Base:Skirt","Base:LongSkirt","Base:Legs1","Base:Legs5"})
            check(CrinosCosmetics.isLegwearLocation(location),"legwear location "+location);
        for(String location:new String[]{"Base:UnderwearBottom","Base:Underwear","Base:Torso1Legs1","Base:Jacket","Base:Shoes","Base:Socks",null})
            check(!CrinosCosmetics.isLegwearLocation(location),"not legwear: "+location);
        check(!CrinosFaceVisuals.hidden(visual("base:Pants")),"outside any legs scope pants are untouched");
        check(!CrinosFaceVisuals.hidden(null) && !CrinosFaceVisuals.hidden(new Object()),"unknown visual fails open");
        check(!CrinosFaceVisuals.hidden(new Visual(null)),"missing script fails open");

        var inst=ByteBuddyAgent.install();
        WolfCombatTest.install(inst,Pop.class,CrinosHeadPatch.class,"populateCharacterModelSlot");
        WolfCombatTest.install(inst,Player.class,CrinosWornVisualsPatch.class,"getItemVisuals");
        WolfCombatTest.install(inst,Human.class,CrinosBodyVisualsPatch.class,"getBodyVisuals");
        check(CrinosTextureScopePatch.class.getAnnotation(me.zed_0xff.zombie_buddy.Patch.class).isAdvice(),
                "ZombieBuddy routes the native dynamic-argument advice without wrapper conversion");
        new ByteBuddy().redefine(Creator.class)
            .visit(Advice.to(CrinosTextureScopePatch.class).on(named("init")))
            .make().load(Creator.class.getClassLoader(),ClassReloadingStrategy.of(inst));

        Player a=player(false), b=player(true), human=player(false);
        Pop pop=new Pop(); Creator creator=new Creator();
        for(Player p:new Player[]{a,b}) {
            check(WTAGarouJava.setCrinosCosmetics(p,true,"WTAGarou_CrinosBody_Brown","WTAGarou_Wolf_Brown")
                    .equals("crinos"),"ready profile");
            var slot=new CrinosCosmeticsTest.Slot();
            pop.populateCharacterModelSlot(p,slot);
            check(pop.seenWorn.size()==1 && !CrinosFaceVisuals.hidden(pop.seenWorn.get(0)),
                    "0.4.69: local/remote glasses filtered out of model population, jacket stays");
            check(pop.seenBody.size()==1 && !CrinosFaceVisuals.hidden(pop.seenBody.get(0)),
                    "makeup absent but tattoo remains");
            check(pop.seenBody!=p.human.saved && p.human.saved.size()==2,"saved makeup never mutated");
            check(p.worn.size()==2 && p.remoteVisuals.size()==2,"equipment/network snapshot never mutated");
            check(!CrinosFaceVisuals.enabled(),"population scope restored");
            creator.init(p);
            check(creator.seenWorn.size()==1 && creator.seenBody.size()==1,
                    "nested texture init also filters before compositor loops");
            check(!CrinosFaceVisuals.enabled(),"nested texture scope restored");
            creator.init(p.human,p.remote ? p.remoteVisuals : p.worn,slot.model);
            check(creator.seenWorn.size()==1 && p.worn.size()==2 && p.remoteVisuals.size()==2,
                    "direct compositor callers receive a copy, not mutated input");
            ItemVisuals outside=new ItemVisuals(); p.getItemVisuals(outside);
            check(outside.size()==2 && p.human.getBodyVisuals()==p.human.saved,
                    "normal inventory/save/UI queries see original visuals");
        }
        Object outer=CrinosFaceVisuals.enter(true);
        pop.populateCharacterModelSlot(human,new CrinosCosmeticsTest.Slot());
        check(pop.seenWorn.size()==2 && pop.seenBody==human.human.saved,
                "nested non-Crinos render overrides outer scope");
        check(CrinosFaceVisuals.enabled(),"nested render restores outer scope");
        CrinosFaceVisuals.leave(outer);
        check(!CrinosFaceVisuals.enabled(),"outer scope restored");
        creator.fail=true;
        try { creator.init(a); throw new AssertionError("expected throw"); }
        catch(IllegalStateException expected) {}
        check(!CrinosFaceVisuals.enabled(),"texture exceptions cannot leak hiding to other characters");
        creator.fail=false; creator.init(human);
        check(creator.seenWorn.size()==2 && creator.seenBody==human.human.saved,"human unaffected after exception");
        pop.fail=true;
        try { pop.populateCharacterModelSlot(a,new CrinosCosmeticsTest.Slot()); throw new AssertionError("expected throw"); }
        catch(IllegalStateException expected) {}
        check(!CrinosFaceVisuals.enabled(),"population exception scope restored");
        pop.fail=false;
        var retained=a.legsSprite.modelSlot;
        WTAGarouJava.setCrinosCosmetics(a,false,null,null);
        // Native render references can keep an old body alive after the
        // profile clears. Test BEFORE replacing/resetting the model slot.
        check(!CrinosCosmetics.ownsBody(retained.model),"exit invalidates retained body immediately");
        creator.init(a);
        check(creator.seenBody==a.human.saved && creator.seenBody.size()==2,
                "makeup restored on same body while recycling is delayed");
        creator.init(b);
        check(creator.seenBody.size()==1,"other active Crinos still hides makeup");
        pop.populateCharacterModelSlot(a,new CrinosCosmeticsTest.Slot());
        creator.init(a);
        check(pop.seenWorn.size()==2 && creator.seenWorn.size()==2 && creator.seenBody==a.human.saved,
                "Homid restore shows original makeup/glasses without re-equipping");
        check(a.worn.size()==2 && a.human.saved.size()==2,"original identities/data remain intact");
        check(!CrinosFaceVisuals.enabled(),"final no-leak check");
        Player pending=player(false);
        zombie.core.textures.Texture.brown.ready=false;
        check(WTAGarouJava.setCrinosCosmetics(pending,true,"WTAGarou_CrinosBody_Brown","WTAGarou_Wolf_Brown")
                .equals("pending"),"pending head profile");
        pop.populateCharacterModelSlot(pending,new CrinosCosmeticsTest.Slot());
        creator.init(pending);
        check(pop.seenWorn.size()==2 && pop.seenBody==pending.human.saved && creator.seenWorn.size()==2,
                "head-not-ready fallback never hides a normal human's eyewear or makeup");
        zombie.core.textures.Texture.brown.ready=true;
        // Repeated shifts, including shared coat profiles and delayed body
        // release, must never remove the original makeup object.
        Object makeup=a.human.saved.get(0);
        for(int i=0;i<8;i++) {
            CrinosCosmetics.set(a,true,"WTAGarou_CrinosBody_Brown","WTAGarou_Wolf_Brown");
            pop.populateCharacterModelSlot(a,new CrinosCosmeticsTest.Slot());
            creator.init(a);
            check(creator.seenBody.size()==1,"cycle hides makeup");
            CrinosCosmetics.clear(a);
            creator.init(a);
            check(creator.seenBody==a.human.saved && creator.seenBody.get(0)==makeup,
                    "cycle restores exact saved identity without native reset");
        }
        CrinosCosmetics.clearAll();
        System.out.println("PASS: "+checks+" Crinos-only face-visual snapshot/restoration/exception assertions.");
    }
}
