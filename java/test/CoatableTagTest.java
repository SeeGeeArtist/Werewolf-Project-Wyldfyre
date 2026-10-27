import java.lang.instrument.Instrumentation;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import net.bytebuddy.agent.ByteBuddyAgent;
import wtagarou.visuals.*;
import zombie.inventory.ItemTags;
import zombie.scripting.objects.ItemTag;
import zombie.scripting.objects.ResourceLocation;

/** Real ZombieBuddy advice on a fixture shaped like ItemTags.Init(ArrayList) plus the pure coatable rule. */
public final class CoatableTagTest {
    static int checks;
    static void check(boolean ok, String why) { checks++; if (!ok) throw new AssertionError("FAIL: " + why); }

    /** Registry-object shape: toString() is "base:weapon" like ItemType / ItemTag. */
    public static final class Kind { final String id; Kind(String id) { this.id = id; } public String toString() { return "base:" + id; } }
    static final Kind WEAPON = new Kind("weapon"), NORMAL = new Kind("normal");

    /** Script item fixture with the members CoatableTagRuntime reflects on. */
    public static final class Script {
        final String name, display, category; final Kind type; final boolean ranged;
        private float metalValue;
        private final Set<Object> tags = new HashSet<>();
        Script(String name, String display, Kind type, boolean ranged, float metal, String category, String... tagIds) {
            this.name = name; this.display = display; this.type = type; this.ranged = ranged; this.metalValue = metal; this.category = category;
            for (String t : tagIds) tags.add(ItemTag.get(ResourceLocation.of(t)) != null ? ItemTag.get(ResourceLocation.of(t)) : ItemTag.register(t));
        }
        public Object getItemType() { return type; }
        public boolean isRanged() { return ranged; }
        public Set<Object> getTags() { return tags; }
        public String getDisplayCategory() { return category; }
        public String getName() { return name; }
        public String getDisplayName() { return display; }
        boolean has(Object tag) { return tags.contains(tag); }
    }

    public static void main(String[] args) throws Exception {
        Instrumentation inst = ByteBuddyAgent.install();
        WolfCombatTest.install(inst, ItemTags.class, CoatableTagPatch.class, "Init");

        // Pure rule.
        List<String> none = List.of();
        check(CoatableTagRuntime.decide(true, false, 10f, none, "Weapon", "MeatCleaver", "Meat Cleaver"), "metal melee weapon");
        check(CoatableTagRuntime.decide(true, false, 0f, List.of("base:hasmetal"), "Weapon", "Pan", "Frying Pan"), "HasMetal tag (namespaced) counts as metal");
        check(CoatableTagRuntime.decide(true, false, 0f, List.of("HasMetal"), "Weapon", "Pan", "Frying Pan"), "HasMetal tag (plain) counts as metal");
        check(!CoatableTagRuntime.decide(true, false, 0f, none, "Weapon", "BaseballBat", "Baseball Bat"), "wooden weapon refused");
        check(!CoatableTagRuntime.decide(true, true, 20f, none, "Weapon", "Shotgun", "Shotgun"), "ranged refused");
        check(!CoatableTagRuntime.decide(false, false, 20f, List.of("HasMetal"), "Household", "AluminumFoil", "Aluminum Foil"), "non-weapon refused");
        // 0.4.63: forge tools coat like any metal weapon but are not forgeable.
        check(CoatableTagRuntime.decide(true, false, 10f, List.of("base:tongs"), "Tool", "Tongs", "Tongs"), "tongs coatable");
        check(CoatableTagRuntime.decide(true, false, 25f, List.of("Hammer"), "ToolWeapon", "Hammer", "Hammer"), "claw hammer coatable");
        check(CoatableTagRuntime.decide(true, false, 25f, List.of("Hammer", "SmithingHammer"), "ToolWeapon", "SmithingHammer", "Smithing Hammer"), "smithing hammer coatable");
        check(CoatableTagRuntime.decide(true, false, 10f, List.of("ClubHammer"), "Tool", "ClubHammer", "Club Hammer"), "club hammer coatable");
        check(CoatableTagRuntime.decide(true, false, 10f, List.of("File"), "Tool", "File", "File"), "file coatable");
        check(!CoatableTagRuntime.forgeable(true, false, 10f, List.of("base:tongs"), "Tool", "Tongs", "Tongs"), "tongs not forgeable");
        check(!CoatableTagRuntime.forgeable(true, false, 25f, List.of("Hammer"), "ToolWeapon", "Hammer", "Hammer"), "hammer not forgeable");
        check(!CoatableTagRuntime.forgeable(true, false, 10f, List.of("ClubHammer"), "Tool", "ClubHammer", "Club Hammer"), "club hammer not forgeable");
        check(!CoatableTagRuntime.forgeable(true, false, 10f, List.of("File"), "Tool", "File", "File"), "file not forgeable");
        check(CoatableTagRuntime.forgeable(true, false, 10f, none, "Weapon", "MeatCleaver", "Meat Cleaver"), "cleaver forgeable");
        check(!CoatableTagRuntime.forgeable(true, false, 0f, none, "Weapon", "BaseballBat", "Baseball Bat"), "bat not forgeable either");
        check(CoatableTagRuntime.decide(true, false, 10f, List.of("Screwdriver"), "Tool", "Screwdriver", "Screwdriver"), "screwdriver stays coatable");
        // 0.4.63: metal weapons whose scripts lack MetalValue/HasMetal.
        check(CoatableTagRuntime.decide(true, false, 0f, none, "CookingWeapon", "CarvingFork2", "Carving Fork"), "carving fork (no tags, no MetalValue) coatable by name");
        check(CoatableTagRuntime.decide(true, false, 0f, none, "ToolWeapon", "IceAxe", "Ice Axe"), "ice axe coatable by name");
        check(CoatableTagRuntime.decide(true, false, 0f, List.of("base:smeltableironsmall"), "ToolWeapon", "FireplacePoker", "Fireplace Poker"), "Smeltable* tag counts as metal");
        check(CoatableTagRuntime.decide(true, false, 0f, List.of("Wrench", "SmeltableSteelMedium"), "ToolWeapon", "Ratchet", "Ratchet Wrench"), "SmeltableSteelMedium counts as metal");
        check(CoatableTagRuntime.decide(true, false, 0f, List.of("ChopTree", "Sharpenable"), "ToolWeapon", "HandAxe", "Hatchet"), "Sharpenable counts as metal");
        check(!CoatableTagRuntime.decide(true, false, 0f, List.of("SharpKnife", "KillAnimal"), "WeaponCrafted", "FlintKnife", "Stone Knife"), "stone knife (SharpKnife but not Sharpenable) refused");
        check(!CoatableTagRuntime.decide(true, false, 0f, List.of("Fork", "MixingUtensil"), "CookingWeapon", "Fork_Bone", "Bone Fork"), "bone fork refused");
        check(!CoatableTagRuntime.decide(true, false, 10f, none, "Material", "SpearHead", "Spear Head"), "material refused");
        check(!CoatableTagRuntime.decide(true, false, 10f, none, "Weapon", "SilverMachete", "Silver Machete"), "silver by script name refused");
        check(!CoatableTagRuntime.decide(true, false, 10f, none, "Weapon", "Machete2", "Silvered Machete"), "silver by display name refused");
        check(CoatableTagRuntime.decide(true, false, 10f, null, null, null, null), "null tags/names tolerated");
        List<Object> withNull = new ArrayList<>(); withNull.add(null); withNull.add("HasMetal");
        check(CoatableTagRuntime.decide(true, false, 0f, withNull, "Weapon", "Pan", "Pan"), "null tag entries (unregistered script tags) skipped");
        check("hasmetal".equals(CoatableTagRuntime.tagPath("base:HasMetal")) && "tongs".equals(CoatableTagRuntime.tagPath("Tongs"))
                && CoatableTagRuntime.tagPath(null) == null, "tagPath normalises namespace and case");

        // Patched index pass: nothing registered yet, the runtime registers the tags itself.
        ItemTag.reset();
        check(ItemTag.get(ResourceLocation.of(CoatableTagRuntime.TAG_ID)) == null, "tag absent before Init");
        Script cleaver = new Script("MeatCleaver", "Meat Cleaver", WEAPON, false, 10f, "CookingWeapon", "Sharpenable", "SharpKnife");
        Script pan = new Script("Saucepan", "Saucepan", WEAPON, false, 0f, "Cooking", "HasMetal", "Cookable");
        Script bat = new Script("BaseballBat", "Baseball Bat", WEAPON, false, 0f, "Weapon");
        Script foil = new Script("AluminumFoil", "Aluminum Foil", NORMAL, false, 1f, "Household", "HasMetal");
        Script tongs = new Script("Tongs", "Tongs", WEAPON, false, 5f, "Tool", "Tongs", "HasMetal");
        Script silver = new Script("SilverMachete", "Silver Machete", WEAPON, false, 10f, "Weapon", "HasMetal");
        Script shotgun = new Script("Shotgun", "Shotgun", WEAPON, true, 20f, "Weapon");
        Script crowbar = new Script("Crowbar", "Crowbar", WEAPON, false, 15f, "Weapon");
        Script hammer = new Script("Hammer", "Hammer", WEAPON, false, 25f, "ToolWeapon", "Hammer");
        Script fork = new Script("CarvingFork2", "Carving Fork", WEAPON, false, 0f, "CookingWeapon");
        ArrayList<Object> all = new ArrayList<>(List.of(cleaver, pan, bat, foil, tongs, silver, shotgun, crowbar, hammer, fork));
        all.add(null);
        ItemTags.Init(all);
        ItemTag tag = ItemTag.get(ResourceLocation.of(CoatableTagRuntime.TAG_ID));
        ItemTag forgeTag = ItemTag.get(ResourceLocation.of(CoatableTagRuntime.FORGE_TAG_ID));
        check(tag != null && forgeTag != null && tag != forgeTag, "runtime registered wtagarou:coatable and wtagarou:forgeable when registries.lua had not");
        check(cleaver.has(tag) && pan.has(tag) && crowbar.has(tag) && hammer.has(tag) && tongs.has(tag) && fork.has(tag), "cleaver, saucepan, crowbar, hammer, tongs and carving fork tagged coatable");
        check(!bat.has(tag) && !foil.has(tag) && !silver.has(tag) && !shotgun.has(tag), "bat, foil, silver, shotgun untouched");
        check(cleaver.has(forgeTag) && pan.has(forgeTag) && crowbar.has(forgeTag) && fork.has(forgeTag), "non-tool weapons tagged forgeable");
        check(!hammer.has(forgeTag) && !tongs.has(forgeTag), "forge tools not tagged forgeable");
        check(cleaver.has(ItemTag.get(ResourceLocation.of("SharpKnife"))), "existing tags kept");
        List<Object> indexed = ItemTags.getItemsForTag(tag);
        check(indexed.size() == 6 && indexed.contains(cleaver) && indexed.contains(pan) && indexed.contains(crowbar)
                && indexed.contains(hammer) && indexed.contains(tongs) && indexed.contains(fork),
                "ItemTags index lists exactly the coatable weapons (recipe tags[] resolves through it)");
        List<Object> forgeIndexed = ItemTags.getItemsForTag(forgeTag);
        check(forgeIndexed.size() == 4 && !forgeIndexed.contains(hammer) && !forgeIndexed.contains(tongs), "forgeable index leaves out the tools");
        check(WTAGarouJava.coatableCount() == 6 && WTAGarouJava.coatableStatus().contains("6 of 10 item scripts tagged coatable, 4 forgeable")
                && WTAGarouJava.coatableStatus().contains("Init seen"), "status: " + WTAGarouJava.coatableStatus());

        // Second pass (script reload / registries.lua already registered): idempotent, no duplicate registration.
        ItemTags.Init(all);
        check(ItemTag.get(ResourceLocation.of(CoatableTagRuntime.TAG_ID)) == tag, "same tag object reused");
        check(ItemTags.getItemsForTag(tag).size() == 6 && cleaver.getTags().size() == 4 && hammer.getTags().size() == 2, "no duplicates after a second Init");
        check(!WTAGarouJava.coatableStatus().contains("error"), "no error recorded");

        System.out.println("PASS: " + checks + " coatable-tag assertions.");
    }
}
