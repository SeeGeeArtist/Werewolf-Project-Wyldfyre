-- B42.20 namespaced registry API, also demonstrated by the read-only
-- BanditsWeekOne/42.20/media/registries.lua reference.
WTAGarouTraits = WTAGarouTraits or {}
WTAGarouTraits.Garou = CharacterTrait.register("wtagarou:garou")

WTAGarouRegistries = WTAGarouRegistries or {}
WTAGarouRegistries.Saddlebag = ItemBodyLocation.register("wtagarou:saddlebag")
WTAGarouRegistries.QuadrupedBag = ItemTag.register("wtagarou:quadrupedbag")
BodyLocations.getGroup("Human"):getOrCreateLocation(WTAGarouRegistries.Saddlebag)

-- 0.4.62: item tags used by silver_items.txt / silver_recipes.txt. Tags that
-- are not registered resolve to nil when a script says "Tags = X" (ItemTag.get
-- is a plain registry lookup), so every custom tag has to be declared here,
-- before the item scripts are parsed. Registering twice throws, hence the get-first.
local function itemTag(id)
    local existing = ItemTag.get(ResourceLocation.of(id))
    if existing then return existing end
    return ItemTag.register(id)
end
WTAGarouRegistries.SilverAmmo = itemTag("wtagarou:silverammo")
-- Added at runtime by CoatableTagPatch (WTAGarou.jar) to every metal melee
-- weapon script; the coat recipe uses it as its weapon slot. 0.4.63:
-- wtagarou:forgeable is the same set minus forge tools (tongs, file,
-- hammers) and is the forge recipe's weapon slot, so hammers can be coated
-- without competing with the forge recipe's own hammer slot.
WTAGarouRegistries.Coatable = itemTag("wtagarou:coatable")
WTAGarouRegistries.Forgeable = itemTag("wtagarou:forgeable")
