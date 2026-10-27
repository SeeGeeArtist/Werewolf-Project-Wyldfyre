import wtagarou.visuals.*;
import zombie.core.skinnedmodel.ModelManager;
import zombie.core.skinnedmodel.model.*;
import zombie.core.textures.Texture;
import java.util.*;
import net.bytebuddy.agent.ByteBuddyAgent;

public class CrinosCosmeticsTest {
    static int checks;
    static void check(boolean b,String why) { checks++; if(!b) throw new AssertionError(why); }
    public static class Character extends zombie.characters.IsoGameCharacter {
        public int resets,textureRefreshes;
        public boolean female;
        public String savedSkin="OriginalHuman",savedHair="HumanHair";
        public void resetModelNextFrame() { resets++; }
        public void postUpdateModelTextures() { textureRefreshes++; }
        public boolean isFemale() { return female; }
    }
    /** Fixtures for the worn-item funnel (PopTemplateManager.addClothingItem). */
    public static class Location { final String id; Location(String id){this.id=id;} public String toString(){ return id; } }
    public static class ScriptItem { final Location loc; ScriptItem(String id){ loc=new Location(id);} public Location getBodyLocation(){ return loc; } }
    public static class ItemVisual { final ScriptItem item; ItemVisual(String id){ item=new ScriptItem(id);} public ScriptItem getScriptItem(){ return item; } }
    public static class Animator extends zombie.core.skinnedmodel.animation.AnimationPlayer {
        public int index=5;
        public int getSkinningBoneIndex(String name,int fallback) {
            if(!name.equals("Bip01_Head")) throw new AssertionError(name); return index;
        }
    }
    public static class Slot {
        public ModelInstance model=new ModelInstance();
        public List<Object> sub=new ArrayList<>();
        public Slot() { model.animPlayer=new Animator(); }
    }
    public static class Data {
        public ModelInstance modelInstance;
        public CharacterMask mask=new CharacterMask();
        public String maskFolder="media/textures/Body/Masks",baseTexture="native";
    }
    public static class Creator {
        public Data chrData=new Data();
        public List<Object> texturesNotReady=new ArrayList<>();
        public boolean[] holeMask={true,true};
        public void init(Object a) {}
        public void init(Object a,Object b,Object c) {}
    }
    public static class Population {
        public int hairs,clothes,wornModels;
        public void addHeadHair(Object chr,Object slot,Object visual,Object hat,boolean beard) { hairs++; }
        public void populateCharacterModelSlot(Object chr,Object slot) {
            addHeadHair(chr,slot,null,null,false); clothes++;
        }
        public ModelInstance addClothingItem(Object chr,Object slot,Object itemVisual,Object clothingItem) {
            return addClothingItem(chr,slot,itemVisual,clothingItem,false);
        }
        public ModelInstance addClothingItem(Object chr,Object slot,Object itemVisual,Object clothingItem,boolean alt) {
            wornModels++; ModelInstance m=new ModelInstance(); m.itemVisual=itemVisual; return m;
        }
    }
    public static void main(String[] args) throws Exception {
        var agent=ByteBuddyAgent.install();
        WolfCombatTest.installAll(agent,Population.class,
                new Class<?>[]{CrinosHeadPatch.class,CrinosHairPatch.class,CrinosFootwearPatch.class},
                new String[]{"populateCharacterModelSlot","addHeadHair","addClothingItem"});
        WolfCombatTest.installAll(agent,Creator.class,new Class<?>[]{CrinosTexturePatch.class},new String[]{"init"});
        WolfCombatTest.install(agent,ModelInstance.class,WolfAttachmentResetPatch.class,"reset");
        Character a=new Character(),b=new Character();
        String body="WTAGarou_CrinosBody_Brown",head="WTAGarou_Wolf_Brown";
        check(!CrinosCosmetics.valid("../oops","Body"),"reject traversal");
        check(!CrinosCosmetics.valid("WTAGarou_Wolf","Body"),"restrict family");
        check(CrinosCosmetics.validHead("WTAGarou_CrinosHead_Default"),"legacy custom heads remain valid");
        for(String coat:new String[]{"Timber","Brown","Blonde","Brindle","White","Black"})
            check(CrinosCosmetics.validHead("WTAGarou_Wolf_"+coat),"wolf head coat "+coat);
        for(String bad:new String[]{"../oops","WTAGarou_Wolf_../Brown","WTAGarou_Wolf_Brown.png",
                "media/textures/Body/WTAGarou_Wolf_Brown","WTAGarou_CrinosBody_Brown","WTAGarou_Wolf_",null})
            check(!CrinosCosmetics.validHead(bad),"reject unsafe or wrong-family head "+bad);
        check(CrinosCosmetics.set(b,true,body,"../oops").equals("failed") && b.resets==0,
                "bad head rejected before texture lookup or model reset");
        // 0.4.59: preload warms the same assets without mounting anything.
        check(CrinosCosmetics.preload(body,"../oops").equals("failed"),"preload rejects a bad head name");
        Texture.brown.ready=false;
        check(CrinosCosmetics.preload(body,head).equals("pending") && a.resets==0 && b.resets==0,
                "preload reports pending and touches no character");
        Texture.brown.ready=true; ModelManager.instance.crinosHead.mesh.ready=false;
        check(CrinosCosmetics.preload(body,head).equals("pending"),"preload waits for the head mesh");
        ModelManager.instance.crinosHead.mesh.ready=true;
        check(CrinosCosmetics.preload(body,head).equals("ready") && a.resets==0,"preload ready, still nothing mounted");
        check(WTAGarouJava.preloadForms(body,head,"media/textures/Body/WTAGarou_Wolf_Brown.png").equals("ready")
                || WTAGarouJava.preloadForms(body,head,"media/textures/Body/WTAGarou_Wolf_Brown.png").equals("pending"),
                "combined preload answers ready/pending with a wolf model fixture present");
        check(WTAGarouJava.preloadForms(body,"../oops",null).equals("failed"),"combined preload fails closed on a bad name");
        Texture.brown.ready=false;
        check(CrinosCosmetics.set(a,true,body,head).equals("pending"),"wait for wolf head PNG");
        Texture.brown.ready=true;
        Texture.crinos.ready=false;
        check(CrinosCosmetics.set(a,true,body,head).equals("pending"),"wait for PNG");
        check(a.resets==0,"pending leaves human intact");
        Texture.crinos.ready=true; ModelManager.instance.crinosHead.mesh.ready=false;
        check(CrinosCosmetics.set(a,true,body,head).equals("pending"),"wait for mesh");
        ModelManager.instance.crinosHead.mesh.ready=true;
        check(CrinosCosmetics.set(a,true,body,head).equals("crinos"),"register ready profile");
        check(a.resets==1,"one model reset");
        check(CrinosCosmetics.set(a,true,body,head).equals("crinos") && a.resets==1,"idempotent");
        Population pop=new Population();
        Slot slot=new Slot(),other=new Slot();
        pop.populateCharacterModelSlot(a,slot);
        pop.populateCharacterModelSlot(b,other);
        check(slot.sub.size()==1 && slot.model.sub.size()==1,"native slot and body lists");
        check(other.sub.isEmpty(),"other humans untouched");
        check(pop.hairs==1 && pop.clothes==2,"skip hair only, keep clothing");
        ModelInstance inst=(ModelInstance)slot.sub.get(0);
        check(inst.parent==slot.model && inst.parentBoneName.equals("Bip01_Head") && inst.parentBone==5,"head bone mount");
        check(inst.owner==slot && inst.character==a,"native ownership");
        check(inst.attachmentNameSelf.equals("mount_direct"),"default direct-attachment engine uses direct-fit mount");
        check(inst.scale==.6f,"native model-script scale retained; no second Java scale multiplication");
        zombie.core.skinnedmodel.model.ModelInstanceRenderData.invertAttachmentSelfTransform=true;
        check(CrinosCosmetics.attachmentName().equals("mount"),"inverting engine uses inverse-fit mount");
        Slot inverseSlot=new Slot();
        CrinosCosmetics.addHead(a,inverseSlot);
        check(((ModelInstance)inverseSlot.sub.get(0)).attachmentNameSelf.equals("mount"),
                "actual injected head receives inverse-fit mount");
        zombie.core.skinnedmodel.model.ModelInstanceRenderData.invertAttachmentSelfTransform=false;
        check(CrinosCosmetics.attachmentName().equals("mount_direct"),"mode is read, not globally changed or cached");
        check(inst.tex==Texture.brown,"head uses wolf atlas, not human-UV body atlas");
        CrinosCosmetics.addHead(a,slot);
        check(slot.sub.size()==1,"no duplicate attachment");
        Creator tex=new Creator(); tex.chrData.modelInstance=slot.model;
        Texture.mask.ready=false;
        tex.init(a);
        check(tex.chrData.baseTexture.endsWith(body+".png"),"fur in compositor not final render override");
        check(!tex.chrData.mask.head && tex.chrData.mask.chest && !tex.chrData.mask.dress,
                "hide native head and normally transparent dress geometry");
        check(!tex.holeMask[0] && tex.holeMask[1],"head hole cannot resurrect human face");
        check(tex.texturesNotReady.size()==1,"wait for newly required masks");
        tex.init(a,null,null);
        check(tex.texturesNotReady.size()==1,"overload/nested init idempotent");
        Creator vanilla=new Creator(); vanilla.chrData.modelInstance=other.model; vanilla.init(b);
        check(vanilla.chrData.baseTexture.equals("native") && vanilla.chrData.mask.head,"unregistered native compositor untouched");
        check(a.savedSkin.equals("OriginalHuman") && a.savedHair.equals("HumanHair"),"saved identity untouched");
        Slot noBone=new Slot(); ((Animator)noBone.model.animPlayer).index=-1;
        pop.populateCharacterModelSlot(a,noBone);
        check(!CrinosCosmetics.hasHead(noBone) && pop.hairs==2,"missing bone retains human head/hair");
        CrinosCosmetics.set(a,true,"WTAGarou_CrinosBody_Blonde","WTAGarou_Wolf_Blonde");
        check(a.resets==2,"coat change schedules rebuild");
        Slot blonde=new Slot(); pop.populateCharacterModelSlot(a,blonde);
        check(((ModelInstance)blonde.sub.get(0)).tex==Texture.blonde,
                "coat change replaces per-instance wolf head texture");
        tex=new Creator(); tex.chrData.modelInstance=blonde.model; tex.init(a);
        check(tex.chrData.baseTexture.endsWith("Blonde.png"),"new instance uses selected coat");
        slot.model.reset();
        check(!CrinosCosmetics.hasHead(slot),"pool reuse forgets role");
        CrinosCosmetics.set(a,false,body,head);
        check(a.resets==3,"leaving requests clean native rebuild");
        check(a.textureRefreshes==3,"enter/coat/exit explicitly refresh texture compositor");
        check(!CrinosCosmetics.hasHead(blonde),"exit invalidates body before native recycling");
        Creator stale=new Creator(); stale.chrData.modelInstance=blonde.model; stale.init(a);
        check(stale.chrData.baseTexture.equals("native"),"old body cannot reapply fur after exit");
        Slot restored=new Slot(); pop.populateCharacterModelSlot(a,restored);
        check(restored.sub.isEmpty() && pop.hairs==3,"human appearance restored without saved-state writes");
        Texture.mask.ready=true;

        // ---- 0.4.67: intrinsic skinned legs + optional tail -------------------
        ModelManager mm=ModelManager.instance;
        String legs="WTAGarou_CrinosBody_Brown",tail="WTAGarou_Wolf_Brown";
        Character l=new Character();
        check(CrinosCosmetics.set(l,true,body,head,"WTAGarou_Wolf_Brown",null).equals("failed"),"legs must be the CrinosBody/CrinosLegs texture family, not the wolf atlas");
        check(CrinosCosmetics.set(l,true,body,head,legs,"WTAGarou_CrinosBody_Brown").equals("failed"),"tail must be the Wolf/CrinosTail family, not the body atlas");
        check(CrinosCosmetics.valid("WTAGarou_CrinosLegs_Brown","Legs") && CrinosCosmetics.valid("WTAGarou_CrinosTail_Brown","Tail"),"legacy per-part names stay valid");
        check(CrinosCosmetics.set(l,true,body,head,legs,"../oops").equals("failed") && l.resets==0,"bad tail name rejected before any load");
        check(mm.skinnedLoads.isEmpty(),"rejected names start no mesh load");
        mm.skinnedReady=false;
        { String r0=CrinosCosmetics.set(l,true,body,head,legs,tail); check(r0.equals("pending") && l.resets==0,"legs/tail meshes still loading: pending, human intact: "+r0+" resets="+l.resets); }
        check(mm.skinnedLoads.equals(List.of("media/models_x/skinned/clothes/wtagarou_crinoslegs.glb|Body/"+legs)),
                "first pending call starts the (unisex) legs load and stops there: "+mm.skinnedLoads);
        for(ModelManager.TestModel m:mm.skinned.values()) m.ready=true;
        check(CrinosCosmetics.set(l,true,body,head,legs,tail).equals("pending") && mm.skinnedLoads.size()==2,"then the tail load");
        for(ModelManager.TestModel m:mm.skinned.values()) m.ready=true; mm.skinnedReady=true;
        check(CrinosCosmetics.set(l,true,body,head,legs,tail).equals("crinos") && l.resets==1,"all parts resident: profile registered");
        check(WTAGarouJava.setCrinosCosmeticsParts(l,true,body,head,legs,tail).equals("crinos") && l.resets==1,"Lua entry point, idempotent");
        Slot ls=new Slot(); pop.populateCharacterModelSlot(l,ls);
        check(ls.sub.size()==3 && ls.model.sub.size()==3,"head + legs + tail on the slot and body lists: "+ls.sub.size());
        ModelInstance legsInst=null,tailInst=null;
        for(Object o:ls.sub){ ModelInstance m=(ModelInstance)o; if(legsInst==null && "media/models_x/skinned/clothes/wtagarou_crinoslegs.glb".equals(m.meshName)) legsInst=m;
            if(tailInst==null && "media/models_x/skinned/clothes/wtagarou_crinostail.glb".equals(m.meshName)) tailInst=m; }
        check(legsInst!=null && tailInst!=null,"skinned legs and tail instances present");
        check(legsInst.animPlayer==ls.model.animPlayer && legsInst.parent==ls.model && legsInst.matrixModel==ls.model
                && legsInst.owner==ls && legsInst.character==l,"legs ride the body's AnimationPlayer like worn clothing");
        check(legsInst.depthBias==0f && legsInst.tintR==1f && legsInst.tintG==1f && legsInst.tintB==1f,"clothing post-process values, untinted");
        check(("Body/"+legs).equals(legsInst.texName) && ("Body/"+tail).equals(tailInst.texName),"per-coat part textures");
        check(legsInst.parentBoneName==null,"legs are skinned, not bone-mounted statics");
        // worn footwear loses its mesh, nothing else does
        Population wear=new Population();
        check(wear.addClothingItem(l,ls,new ItemVisual("Base:Shoes"),null)==null && wear.wornModels==0,"Shoes model skipped while legs are on");
        check(wear.addClothingItem(l,ls,new ItemVisual("Base:Socks"),null)==null && wear.wornModels==0,"Socks model skipped too");
        check(wear.addClothingItem(l,ls,new ItemVisual("Base:Hat"),null)!=null && wear.wornModels==1,"other worn models still built");
        check(wear.addClothingItem(a,slot,new ItemVisual("Base:Shoes"),null)!=null,"a Crinos without legs keeps its shoes mesh");
        check(wear.addClothingItem(b,other,new ItemVisual("Base:Shoes"),null)!=null,"humans untouched");
        check(CrinosCosmetics.isFootwearLocation("RabenRabo:Shoes") && !CrinosCosmetics.isFootwearLocation("Base:ShoesExtra")
                && !CrinosCosmetics.isFootwearLocation(null),"location id matching is by exact name after the namespace");
        // compositor hides the human legs/feet; 0.4.90: the vanilla mask set stays
        Creator lt=new Creator(); lt.chrData.modelInstance=ls.model; Texture.mask.ready=false; lt.init(l);
        for(CharacterMask.Part part:new CharacterMask.Part[]{CharacterMask.Part.LeftLeg,CharacterMask.Part.LeftFoot,CharacterMask.Part.RightLeg,CharacterMask.Part.RightFoot})
            check(!lt.chrData.mask.isPartVisible(part),"human "+part+" hidden under the digitigrade mesh");
        check(!lt.chrData.mask.head && lt.chrData.mask.chest,"head still hidden, torso still visible");
        check(lt.chrData.maskFolder.equals("media/textures/Body/Masks"),"0.4.90: vanilla mask set kept (no third-party masks)");
        check(lt.texturesNotReady.size()==1 && lt.texturesNotReady.get(0)==Texture.mask,"waits for the vanilla mask PNGs");
        Texture.mask.ready=true;
        // legs without tail (the author's preferred look): no tail instance, legs still hidden
        Character n=new Character(); n.female=true;
        check(CrinosCosmetics.set(n,true,body,head,legs,"").equals("crinos"),"empty tail = no tail; unisex legs mesh loads for a female: "+mm.skinnedLoads);
        check(mm.skinnedLoads.contains("media/models_x/skinned/clothes/wtagarou_crinoslegs.glb|Body/"+legs),"0.4.94: one legs mesh for both sexes");
        Slot ns=new Slot(); pop.populateCharacterModelSlot(n,ns);
        check(ns.sub.size()==2,"head + legs only");
        Creator nt=new Creator(); nt.chrData.modelInstance=ns.model; nt.init(n);
        check(!nt.chrData.mask.isPartVisible(CharacterMask.Part.LeftFoot) && nt.chrData.maskFolder.equals("media/textures/Body/Masks"),"tail-less legs still mask the feet");
        // legacy call (no parts) keeps the human legs
        Character o=new Character(); CrinosCosmetics.set(o,true,body,head);
        Slot os=new Slot(); pop.populateCharacterModelSlot(o,os);
        Creator ot=new Creator(); ot.chrData.modelInstance=os.model; ot.init(o);
        check(os.sub.size()==1 && ot.chrData.mask.isPartVisible(CharacterMask.Part.LeftLeg) && ot.chrData.maskFolder.equals("media/textures/Body/Masks"),
                "head-only profile: human legs and vanilla masks");
        check(CrinosCosmetics.preloadParts(legs,tail,false).equals("ready") && CrinosCosmetics.preloadParts("bad",null,false).equals("failed"),"preloadParts answers");
        CrinosCosmetics.set(l,false,body,head);
        check(wear.addClothingItem(l,ls,new ItemVisual("Base:Shoes"),null)!=null,"shoes mesh returns once the legs are gone");
        System.out.println("PASS: "+checks+" Crinos cosmetics/ownership/compositor assertions (fixtures, not visual test).");
    }
}
