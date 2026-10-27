import java.util.HashMap;
import java.util.List;
import java.util.Map;
import wtagarou.visuals.*;
import zombie.core.skinnedmodel.advancedanimation.AnimBoneWeight;

/** 0.4.69: the howl's Drink track masked to neck+head (Glabro/Crinos). */
public class HowlMaskTest {
    static int checks;
    static void check(boolean ok, String why) { checks++; if (!ok) throw new AssertionError("FAIL: " + why); }

    public static class Character {
        public final Map<String, Object> vars = new HashMap<>();
        public boolean getVariableBoolean(String k) { return Boolean.TRUE.equals(vars.get(k)) || "true".equals(vars.get(k)); }
    }
    public static class Params {  // shaped like StartAnimTrackParameters
        public String animName; public List<AnimBoneWeight> subLayerBoneWeights;
    }
    public static class Skin extends zombie.core.skinnedmodel.model.SkinningData { }
    public static class Track {  // shaped like AnimationTrack
        public List<AnimBoneWeight> bindings; public boolean masked; public Object initSkin; public int inits;
        public boolean hasBoneMask() { return masked; }
        public void setBoneWeights(List<AnimBoneWeight> w) { bindings = w; masked = false; }
        public void initBoneWeights(zombie.core.skinnedmodel.model.SkinningData skin) { initSkin = skin; inits++; masked = bindings != null && !bindings.isEmpty(); }
    }
    public static class Layer { public boolean sub; public boolean isSubLayer() { return sub; } }
    public static class Player {
        public Character chr = new Character(); public int plays; public Skin skin = new Skin(); public Track last;
        public Character getIsoGameCharacter() { return chr; }
        public Skin getSkinningData() { return skin; }
        /** Mirrors AnimationPlayer.play(params, layer): sub-layer applies the params mask, root clears it. */
        public Object play(Object params, Object layer) {
            plays++;
            if (!(params instanceof Params)) return null;
            Track t = new Track();
            if (layer instanceof Layer && ((Layer) layer).sub) { t.setBoneWeights(((Params) params).subLayerBoneWeights); t.initBoneWeights(skin); }
            else t.setBoneWeights(null);
            last = t;
            return t;
        }
        public Object play(String animName, boolean looped) { plays++; return null; }
    }

    public static void main(String[] args) throws Exception {
        var inst = net.bytebuddy.agent.ByteBuddyAgent.install();
        WolfCombatTest.install(inst, Player.class, HowlMaskPatch.class, "play");

        List<Object> w = HowlMaskRuntime.headNeckWeights();
        check(w.size() == 2 && ((AnimBoneWeight) w.get(0)).boneName.equals("Bip01") && ((AnimBoneWeight) w.get(0)).weight == 0f
                && ((AnimBoneWeight) w.get(0)).includeDescendants
                && ((AnimBoneWeight) w.get(1)).boneName.equals("Bip01_Neck") && ((AnimBoneWeight) w.get(1)).weight == 1f
                && ((AnimBoneWeight) w.get(1)).includeDescendants,
                "mask = Bip01 0 (+descendants) then Bip01_Neck 1 (+descendants = head)");
        check(HowlMaskRuntime.isActionClip("Bob_DrinkBottle") && HowlMaskRuntime.isActionClip("Bob_EatFood")
                && !HowlMaskRuntime.isActionClip("Bob_Walk") && !HowlMaskRuntime.isActionClip("Bob_Aim") && !HowlMaskRuntime.isActionClip(null),
                "only drink/eat clips are action clips");

        Player p = new Player();
        AnimBoneWeight armMask = new AnimBoneWeight("Bip01_Spine1", 1f);
        Params drink = new Params(); drink.animName = "Bob_DrinkBottle"; drink.subLayerBoneWeights = List.of(armMask);
        p.play(drink, null);
        check(p.plays == 1 && drink.subLayerBoneWeights.size() == 1 && drink.subLayerBoneWeights.get(0) == armMask,
                "not howling: the node's own upper-body mask is untouched");

        p.chr.vars.put(HowlMaskRuntime.VARIABLE, "true");   // Lua writes the string "true"
        p.play(drink, null);
        check(drink.subLayerBoneWeights == (Object) w && HowlMaskRuntime.masked.get() == 1,
                "howling Glabro/Crinos: the drink track gets the neck+head mask");

        Params walk = new Params(); walk.animName = "Bob_Walk"; walk.subLayerBoneWeights = null;
        p.play(walk, null);
        check(walk.subLayerBoneWeights == null, "gait tracks are never masked");
        Params aim = new Params(); aim.animName = "Bob_AimRifle"; aim.subLayerBoneWeights = List.of(armMask);
        p.play(aim, null);
        check(aim.subLayerBoneWeights.get(0) == armMask, "aim sublayer keeps its own mask");

        p.play("Bob_DrinkBottle", true);
        check(p.plays == 5 && HowlMaskRuntime.masked.get() == 1, "String overload passes through");

        p.chr.vars.remove(HowlMaskRuntime.VARIABLE);
        Params again = new Params(); again.animName = "Bob_DrinkBottle"; again.subLayerBoneWeights = List.of(armMask);
        p.play(again, null);
        check(again.subLayerBoneWeights.get(0) == armMask, "after the howl: vanilla drink pose again");

        check(!HowlMaskRuntime.begin(null, drink) && !HowlMaskRuntime.begin(p, null), "null guards");

        // 0.4.70: root layer (standing howl). play() clears the track mask; the
        // exit advice puts the neck+head mask on the track itself.
        p.chr.vars.put(HowlMaskRuntime.VARIABLE, "true");
        Layer root = new Layer(), sub = new Layer(); sub.sub = true;
        long before = HowlMaskRuntime.rootMasks.get();
        Params standing = new Params(); standing.animName = "Bob_DrinkBottle"; standing.subLayerBoneWeights = List.of(armMask);
        p.play(standing, root);
        check(standing.subLayerBoneWeights == (Object) w, "standing howl: params masked on enter");
        check(p.last.bindings == (Object) w && p.last.masked && p.last.initSkin == p.skin && p.last.inits == 1,
                "...and the ROOT track itself now carries the neck+head mask, initialised against the player's skinning data");
        check(HowlMaskRuntime.rootMasks.get() == before + 1, "root mask counted once");
        Params moving = new Params(); moving.animName = "Bob_DrinkBottle"; moving.subLayerBoneWeights = List.of(armMask);
        p.play(moving, sub);
        check(p.last.bindings == (Object) w && p.last.inits == 1 && HowlMaskRuntime.rootMasks.get() == before + 1,
                "sub-layer howl: play() applied the mask itself; the exit advice does not re-init it");
        Params gait = new Params(); gait.animName = "Bob_Walk"; gait.subLayerBoneWeights = null;
        p.play(gait, root);
        check(p.last.bindings == null && !p.last.masked && HowlMaskRuntime.rootMasks.get() == before + 1, "root gait track stays full body");
        p.chr.vars.remove(HowlMaskRuntime.VARIABLE);
        Params plain = new Params(); plain.animName = "Bob_DrinkBottle"; plain.subLayerBoneWeights = List.of(armMask);
        p.play(plain, root);
        check(p.last.bindings == null && HowlMaskRuntime.rootMasks.get() == before + 1, "not howling: a root drink stays vanilla full body");
        check(!HowlMaskRuntime.afterPlay(p, standing, null) && !HowlMaskRuntime.afterPlay(null, standing, new Track())
                && !HowlMaskRuntime.afterPlay(p, "Bob_Drink", new Track()), "afterPlay null/String guards");

        // 0.4.69: wolves. An authored Wolf_howl track is masked to neck+head+jaw;
        // the Wolf_eat fallback keeps the full-body action weights.
        Object full = List.of(armMask);
        check(WolfRuntime.howlWeights("Wolf_howl", true, full) == (Object) w, "Lupus/Hispo authored howl: neck+head mask");
        check(WolfRuntime.howlWeights("Wolf_eat", true, full) == full, "eat fallback while howling: unchanged (confirmed behaviour)");
        check(WolfRuntime.howlWeights("Wolf_howl", false, full) == full, "Wolf_howl outside a howl (never happens) left alone");
        System.out.println("HowlMaskTest passed " + checks + " checks");
    }
}
