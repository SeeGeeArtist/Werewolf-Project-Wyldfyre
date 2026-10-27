--[[
    WTAGarou - Silver ammunition and silvered weapons (v0.4.58, Wits W1-W4)

    Human players need a counter to the beasts. This file is the shared
    bookkeeping; recipes live in media/scripts/silver_recipes.txt, the
    loading actions (vanilla reload derivatives, 0.4.63) in
    shared/WTAGarouSilverLoadActions.lua, the context menu and firearm
    radial slice in client/WTAGarouSilverLoad.lua, and the burn itself in
    server/WTAGarouSilver.lua.

    Catalogue (W1)
      One silver-tipped variant per vanilla calibre (CATALOG). Silver rounds
      are separate items so vanilla reload never loads them by accident; the
      mod loads them with its own action.

    Loading (W3)
      A gun's own tube/cylinder (no MagazineType) or a magazine item carries
      mod data:
        WTAGarou_SilverAmmo    number  silver rounds now in that tube/magazine
                               true    legacy Test Panel "unlimited silver"
        WTAGarou_SilverChamber boolean the chambered round is silver (guns
                                       with a chamber)
        WTAGarou_SilverShot    boolean the shot being fired is silver (set at
                                       OnWeaponSwing, read by the hit code)
      Loads are homogeneous: a tube/magazine holds silver or ordinary rounds,
      never both. Vanilla reload refuses while silver is inside, and the
      silver loader refuses while ordinary rounds are inside ("Unload the
      ordinary rounds first"). Unloading hands the silver rounds back as
      silver items. Magazines carry their count through insert/eject.

    Burn (W4)
      Silver shots and silvered weapons burn the wound the engine actually
      made (server/WTAGarouSilver.lua + Java weapon-hit recorder).

    Silvered weapons
      Forge recipe keeps the metal weapon, OnForgeWeapon marks it
      WTAGarou_Silver and prefixes "Silver " to its name. The existing
      silver-weapon checks in server/WTAGarouSilver.lua pick that up.

    MP: the bookkeeping runs where the vanilla shot/unload code runs (single
    player and the hosting side). Dedicated-server sync of silver counts is
    not part of this slice.
]]

WTAGarou = WTAGarou or {}
WTAGarou.SilverAmmo = WTAGarou.SilverAmmo or {}
local S = WTAGarou.SilverAmmo

S.KEY         = "WTAGarou_SilverAmmo"
S.CHAMBER_KEY = "WTAGarou_SilverChamber"
S.SHOT_KEY    = "WTAGarou_SilverShot"
S.PRE_KEY     = "WTAGarou_SilverPreCount"
S.SILVER_KEY  = "WTAGarou_Silver"         -- silvered melee weapon flag
S.NAME_KEY    = "WTAGarou_SilverNamed"    -- rename already applied
S.HIT_WINDOW_MS = 250

-- base ammo full type -> silver-tipped full type
S.CATALOG = {
    ["Base.ShotgunShells"] = "WTAGarou.SilverShotgunShells",
    ["Base.Bullets9mm"]    = "WTAGarou.SilverBullets9mm",
    ["Base.Bullets45"]     = "WTAGarou.SilverBullets45",
    ["Base.Bullets44"]     = "WTAGarou.SilverBullets44",
    ["Base.Bullets38"]     = "WTAGarou.SilverBullets38",
    ["Base.Bullets357"]    = "WTAGarou.SilverBullets357",
    ["Base.3030Bullets"]   = "WTAGarou.Silver3030Bullets",
    ["Base.308Bullets"]    = "WTAGarou.Silver308Bullets",
    ["Base.556Bullets"]    = "WTAGarou.Silver556Bullets",
}
S.REVERSE = {}
for base, silver in pairs(S.CATALOG) do S.REVERSE[silver] = base end

function S.silverTypeFor(baseType) return baseType and S.CATALOG[baseType] or nil end
function S.baseTypeFor(silverType) return silverType and S.REVERSE[silverType] or nil end
function S.isSilverRound(fullType) return S.REVERSE[fullType] ~= nil end

-- ---------------------------------------------------------------------------
-- Engine access (all pcall-guarded; stubs in tests provide the same methods)
-- ---------------------------------------------------------------------------
local function call(obj, name, ...)
    if obj == nil then return nil end
    local f = obj[name]
    if type(f) ~= "function" then return nil end
    local ok, res = pcall(f, obj, ...)
    if ok then return res end
    return nil
end
S.call = call

local function modData(item)
    return call(item, "getModData")
end

-- "Base.ShotgunShells" for a gun or magazine (B42 AmmoType object or string).
function S.ammoKeyOf(item)
    local ammo = call(item, "getAmmoType")
    if ammo == nil then return nil end
    local key = call(ammo, "getItemKey")
    if type(key) == "string" then return key end
    return tostring(ammo)
end

function S.hasMagazine(gun)
    local mag = call(gun, "getMagazineType")
    return mag ~= nil and tostring(mag) ~= ""
end

function S.isDebugUnlimited(item)
    local md = modData(item)
    return md ~= nil and md[S.KEY] == true
end

-- Silver rounds in the tube/magazine; math.huge for the legacy debug flag.
function S.count(item)
    local md = modData(item)
    if not md then return 0 end
    local v = md[S.KEY]
    if v == true then return math.huge end
    if type(v) == "number" and v > 0 then return math.floor(v) end
    return 0
end

function S.setCount(item, n)
    local md = modData(item)
    if not md then return end
    if md[S.KEY] == true then return end -- debug flag is sticky until the panel clears it
    if type(n) == "number" and n > 0 then md[S.KEY] = math.floor(n) else md[S.KEY] = nil end
end

function S.chamberSilver(gun)
    local md = modData(gun)
    if not md then return false end
    if md[S.KEY] == true then return true end
    return md[S.CHAMBER_KEY] == true
end

function S.setChamberSilver(gun, flag)
    local md = modData(gun)
    if not md or md[S.KEY] == true then return end
    if flag then md[S.CHAMBER_KEY] = true else md[S.CHAMBER_KEY] = nil end
end

-- Keep the invariant silver <= rounds present.
function S.clamp(item)
    local n = S.count(item)
    if n == math.huge then return n end
    local have = call(item, "getCurrentAmmoCount") or 0
    if n > have then S.setCount(item, have); n = have end
    return n
end

-- Ordinary rounds present in a tube/magazine?
function S.hasOrdinary(item)
    local have = call(item, "getCurrentAmmoCount") or 0
    local n = S.count(item)
    if n == math.huge then return false end
    return have > n
end

-- Does the next shot from this gun fire silver? Pre-shot question.
function S.nextShotIsSilver(gun)
    if S.isDebugUnlimited(gun) then return true end
    if call(gun, "haveChamber") then return S.chamberSilver(gun) end
    return S.count(gun) > 0
end

-- ---------------------------------------------------------------------------
-- Loading (W3)
-- ---------------------------------------------------------------------------
-- Count of a given full type in a container (stacked items are separate
-- InventoryItems in PZ, so this is a plain count).
function S.countInInventory(inventory, fullType)
    if not inventory or not fullType then return 0 end
    local n = call(inventory, "getCountTypeRecurse", fullType)
    if type(n) == "number" then return n end
    local items = call(inventory, "getItemsFromFullType", fullType)
    if items and items.size then return items:size() end
    return 0
end

-- ok, reason|count, silverType. Target = gun without magazine, or a magazine.
function S.canLoad(character, target)
    if not (character and target) then return false, "silver_no_rounds" end
    if call(target, "isRanged") and S.hasMagazine(target) then
        return false, "silver_use_magazine"
    end
    local baseKey = S.ammoKeyOf(target)
    local silverType = S.silverTypeFor(baseKey)
    if not silverType then return false, "silver_no_rounds" end
    if S.isDebugUnlimited(target) then return false, "silver_debug" end
    if S.hasOrdinary(target) then return false, "silver_mixed_load" end
    local have = call(target, "getCurrentAmmoCount") or 0
    local max = call(target, "getMaxAmmo") or 0
    local room = max - have
    if room <= 0 then return false, "silver_full" end
    local inv = call(character, "getInventory")
    local available = S.countInInventory(inv, silverType)
    if available <= 0 then return false, "silver_no_rounds" end
    return true, math.min(room, available), silverType
end

-- Remove n items of fullType from the inventory. Returns removed count.
function S.removeRounds(inventory, fullType, n)
    local removed = 0
    if not inventory or n <= 0 then return 0 end
    for _ = 1, n do
        local item = call(inventory, "getFirstTypeRecurse", fullType)
        if not item then break end
        local okRemove = pcall(function()
            local owner = call(item, "getContainer") or inventory
            owner:Remove(item)
        end)
        if not okRemove then break end
        removed = removed + 1
    end
    return removed
end

-- Perform the load; returns rounds loaded.
function S.load(character, target, n)
    local ok, count, silverType = S.canLoad(character, target)
    if not ok then return 0, count end
    n = math.min(n or count, count)
    local inv = call(character, "getInventory")
    local removed = S.removeRounds(inv, silverType, n)
    if removed <= 0 then return 0, "silver_no_rounds" end
    local have = call(target, "getCurrentAmmoCount") or 0
    call(target, "setCurrentAmmoCount", have + removed)
    S.setCount(target, S.count(target) + removed)
    return removed
end

-- ---------------------------------------------------------------------------
-- Vanilla action interplay (W3): refuse mixing, hand silver back on unload,
-- carry counts through magazines and racks.
-- ---------------------------------------------------------------------------
-- Vanilla reload adds ORDINARY rounds; refuse while silver sits inside.
function S.refusesOrdinaryReload(target)
    if not target then return false end
    if S.isDebugUnlimited(target) then return false end
    return S.clamp(target) > 0
end

-- After a vanilla unload step removed `delta` rounds and added that many
-- ordinary items: swap up to `silverBefore` of them for silver items.
function S.swapUnloadedRounds(character, target, silverBefore, delta)
    if not (character and target) or delta <= 0 or silverBefore <= 0 then return 0 end
    if silverBefore == math.huge then return 0 end
    local baseKey = S.ammoKeyOf(target)
    local silverType = S.silverTypeFor(baseKey)
    if not silverType then return 0 end
    local swap = math.min(delta, silverBefore)
    local inv = call(character, "getInventory")
    local removed = S.removeRounds(inv, baseKey, swap)
    for _ = 1, removed do call(inv, "AddItem", silverType) end
    S.setCount(target, silverBefore - removed)
    return removed
end

-- Rack / chamber transition. before = {count=, chambered=, silver=}
function S.afterRack(gun, before)
    if not (gun and before) then return end
    if S.isDebugUnlimited(gun) then return end
    local count = call(gun, "getCurrentAmmoCount") or 0
    local chambered = call(gun, "isRoundChambered") == true
    local delta = (before.count or 0) - count
    local silver = before.silver or 0
    if delta > 0 then
        if chambered and not before.chambered then S.setChamberSilver(gun, silver > 0) end
        S.setCount(gun, math.max(0, silver - delta))
    elseif before.chambered and not chambered then
        -- live round ejected by racking
        S.setChamberSilver(gun, false)
    end
    S.clamp(gun)
end

-- 0.4.63: the item a rack hands back. Vanilla ISRackFirearm:removeBullet
-- always creates the gun's ORDINARY ammo type, so racking a silver shell out
-- of the chamber un-silvered it (Oct 16 playtest). Returns the silver item
-- type when the round leaving the gun is silver, nil for vanilla behaviour.
function S.ejectedRoundType(gun)
    if not gun then return nil end
    local silver
    if call(gun, "haveChamber") == true then
        silver = S.chamberSilver(gun)
    else
        silver = S.count(gun) > 0
    end
    if not silver then return nil end
    return S.silverTypeFor(S.ammoKeyOf(gun))
end

function S.snapshot(gun)
    return {
        count = call(gun, "getCurrentAmmoCount") or 0,
        chambered = call(gun, "isRoundChambered") == true,
        silver = S.count(gun),
    }
end

-- Magazine inserted: the gun's tube count now mirrors the magazine.
function S.afterInsert(gun, magazineSilver)
    if not gun or S.isDebugUnlimited(gun) then return end
    S.setCount(gun, magazineSilver or 0)
    S.clamp(gun)
end

-- Magazine ejected into newMagazine: it inherits the gun's silver count.
function S.afterEject(gun, newMagazine, gunSilverBefore)
    if not newMagazine then return end
    if gunSilverBefore == math.huge then return end
    S.setCount(newMagazine, gunSilverBefore or 0)
    S.clamp(newMagazine)
    if gun and not S.isDebugUnlimited(gun) then S.setCount(gun, 0) end
end

-- ---------------------------------------------------------------------------
-- Shots: pre-shot flag (OnWeaponSwing) and post-shot bookkeeping
-- (OnWeaponSwingHitPoint, after vanilla ISReloadWeaponAction.onShoot).
-- ---------------------------------------------------------------------------
function S.onSwing(character, weapon)
    if not (character and weapon) or not call(weapon, "isRanged") then return end
    local md = modData(weapon); if not md then return end
    local silverShot = S.nextShotIsSilver(weapon)
    md[S.SHOT_KEY] = silverShot
    md[S.PRE_KEY] = call(weapon, "getCurrentAmmoCount") or 0
    return silverShot
end

function S.afterShot(character, weapon)
    if not (character and weapon) or not call(weapon, "isRanged") then return end
    local md = modData(weapon); if not md then return end
    if md[S.KEY] == true then return end
    local pre = md[S.PRE_KEY]; md[S.PRE_KEY] = nil
    local count = call(weapon, "getCurrentAmmoCount") or 0
    local silver = S.count(weapon)
    local delta = type(pre) == "number" and (pre - count) or 0
    if call(weapon, "haveChamber") then
        if delta > 0 then
            -- a round moved tube/magazine -> chamber
            S.setChamberSilver(weapon, silver > 0)
            S.setCount(weapon, math.max(0, silver - delta))
        elseif not call(weapon, "isRoundChambered") then
            -- rack-after-shoot guns: the chamber is empty until racked
            S.setChamberSilver(weapon, false)
        end
    elseif delta > 0 then
        S.setCount(weapon, math.max(0, silver - delta))
    end
    S.clamp(weapon)
end

-- Hit code question: was THIS shot silver?
function S.shotIsSilver(weapon)
    local md = modData(weapon)
    if not md then return false end
    if md[S.KEY] == true then return true end
    if md[S.SHOT_KEY] ~= nil then return md[S.SHOT_KEY] == true end
    return false
end

-- ---------------------------------------------------------------------------
-- Silvered melee weapons (forge recipe callbacks)
-- ---------------------------------------------------------------------------
-- 0.4.63: mirrors CoatableTagRuntime.decide (Java): HasMetal, Sharpenable or
-- any Smeltable* tag means metal; SharpKnife/ChopTree alone do not (stone
-- knives and axes carry them). The carving fork and ice axe scripts carry
-- none of these and no MetalValue, so they qualify by name.
local METAL_TAGS = {
    HasMetal = true, Sharpenable = true,
    SmeltableIronSmall = true, SmeltableIronMedium = true, SmeltableIronLarge = true,
    SmeltableSteelSmall = true, SmeltableSteelMedium = true, SmeltableSteelLarge = true,
    SmeltableSteelMediumPlus = true, SmeltableIronMediumPlus = true,
}
S.METAL_TAGS = METAL_TAGS
S.METAL_BY_NAME = { carvingfork2 = true, iceaxe = true }
-- forge tools: coatable, never the forge recipe's weapon
S.FORGE_TOOL_TAGS = { Tongs = true, File = true, Hammer = true, ClubHammer = true }

-- 0.4.62: ItemTag:toString() is the namespaced registry id ("base:hasmetal",
-- lower case) in B42.20+, so a plain `wanted["HasMetal"]` lookup never matched
-- in-game (it only ever matched the test stubs' plain strings). Normalise both
-- sides: strip the namespace, lower-case.
local function tagKey(t)
    local s = tostring(t or "")
    s = s:match("^[^:]*:(.*)$") or s
    return s:lower()
end
S.tagKey = tagKey

local function hasAnyTag(item, wanted)
    local tags = call(item, "getTags")
    if not tags then return false end
    local want = {}
    for k, v in pairs(wanted) do if v then want[tagKey(k)] = true end end
    local ok, found = pcall(function()
        local it = tags.iterator and tags:iterator() or nil
        while it and it:hasNext() do
            if want[tagKey(it:next())] then return true end
        end
        if type(tags) == "table" then
            for _, t in ipairs(tags) do if want[tagKey(t)] then return true end end
        end
        return false
    end)
    return ok and found == true
end
S.hasAnyTag = hasAnyTag

function S.isSilvered(item)
    local md = modData(item)
    return md ~= nil and md[S.SILVER_KEY] == true
end

-- Is this (melee weapon) item made of metal? MetalValue, a metal tag, any
-- Smeltable* tag, or one of the named exceptions.
function S.isMetalItem(item)
    if not item then return false end
    local metal = call(item, "getMetalValue")
    if type(metal) == "number" and metal > 0 then return true end
    if hasAnyTag(item, METAL_TAGS) then return true end
    local full = tostring(call(item, "getFullType") or "")
    local script = (full:match("%.([^%.]+)$") or full):lower()
    if S.METAL_BY_NAME[script] then return true end
    local tags = call(item, "getTags")
    local ok, found = pcall(function()
        local it = tags and tags.iterator and tags:iterator() or nil
        while it and it:hasNext() do
            if tagKey(it:next()):find("^smeltable") then return true end
        end
        if type(tags) == "table" then
            for _, t in ipairs(tags) do if tagKey(t):find("^smeltable") then return true end end
        end
        return false
    end)
    return ok and found == true
end

function S.isForgeTool(item)
    return hasAnyTag(item, S.FORGE_TOOL_TAGS)
end

-- 0.4.65: the recipes' weapon slots are explicit, generated item lists (a
-- hosted co-op server has no ZombieBuddy, so a Java-added tag is empty there
-- and `tags[wtagarou:coatable]` aborted world load). Clients still tag the
-- rule-coatable scripts; compare that set with what the recipes actually
-- accept and report the difference, so tools/gen_coatable_lists.py --extra
-- can refresh the lists. Returns { coat = {names}, forge = {names} } or nil.
S.COAT_RECIPE = "WTAGarou_CoatSilverNitrate"
S.FORGE_RECIPE = "WTAGarou_SilverWeapon"

-- 0.4.66: craft recipes are stored under their module-qualified name
-- ("WTAGarou.WTAGarou_CoatSilverNitrate"); the bare name returned nil and
-- indexing it raised inside the pcall, which Kahlua still prints. Try both
-- names and nil-check before touching the result.
S.RECIPE_MODULE = "WTAGarou"
function S.findCraftRecipe(sm, recipeName)
    if not (sm and recipeName) then return nil end
    for _, name in ipairs({ S.RECIPE_MODULE .. "." .. recipeName, recipeName }) do
        local ok, recipe = pcall(function() return sm:getCraftRecipe(name) end)
        if ok and recipe ~= nil then return recipe end
    end
    -- Last resort (42.21 returned nil for the bare name on the live game):
    -- walk the recipe list and match the name with or without the module.
    local found = nil
    pcall(function()
        local all = sm:getAllCraftRecipes()
        if not all then return end
        local want = { [recipeName] = true, [S.RECIPE_MODULE .. "." .. recipeName] = true }
        for i = 0, all:size() - 1 do
            local r = all:get(i)
            local n = r and ((r.getScriptObjectName and r:getScriptObjectName())
                or (r.getName and r:getName()) or (r.getFullName and r:getFullName()))
            if n and (want[tostring(n)] or (r.getScriptObjectFullType and want[tostring(r:getScriptObjectFullType())])) then
                found = r; break
            end
        end
    end)
    return found
end

local function recipeItemSet(sm, recipeName)
    local set = {}
    local recipe = S.findCraftRecipe(sm, recipeName)
    if recipe == nil or not recipe.getInputs then return nil end
    local ok = pcall(function()
        local inputs = recipe:getInputs()
        if inputs == nil then return end
        for i = 0, inputs:size() - 1 do
            local items = inputs:get(i):getPossibleInputItems()
            for j = 0, items:size() - 1 do
                set[tostring(items:get(j):getFullName())] = true
            end
        end
    end)
    return ok and set or nil
end

function S.recipeDrift(sm, registries)
    sm = sm or (getScriptManager and getScriptManager())
    registries = registries or WTAGarouRegistries
    if not sm or not registries or not registries.Coatable then return nil end
    local coatSet, forgeSet = recipeItemSet(sm, S.COAT_RECIPE), recipeItemSet(sm, S.FORGE_RECIPE)
    if not coatSet or not forgeSet then return nil end
    local drift = { coat = {}, forge = {}, tagged = 0 }
    local ok = pcall(function()
        local all = sm:getAllItems()
        for i = 0, all:size() - 1 do
            local item = all:get(i)
            local tags = item:getTags()
            if tags and tags:contains(registries.Coatable) then
                drift.tagged = drift.tagged + 1
                local name = tostring(item:getFullName())
                if not coatSet[name] then drift.coat[#drift.coat + 1] = name end
                if registries.Forgeable and tags:contains(registries.Forgeable) and not forgeSet[name] then
                    drift.forge[#drift.forge + 1] = name
                end
            end
        end
    end)
    if not ok then return nil end
    table.sort(drift.coat); table.sort(drift.forge)
    return drift
end

function S.reportRecipeDrift(sm, registries)
    local drift = S.recipeDrift(sm, registries)
    if not drift then return "coat recipe drift: not measurable here (no Java tags or recipes)" end
    local msg
    if #drift.coat == 0 and #drift.forge == 0 then
        msg = "coat recipe drift: none; recipes cover all " .. drift.tagged .. " rule-coatable items"
    else
        msg = "coat recipe drift: " .. #drift.coat .. " rule-coatable item(s) missing from the coat list"
            .. " [" .. table.concat(drift.coat, ";") .. "]; " .. #drift.forge
            .. " missing from the forge list [" .. table.concat(drift.forge, ";") .. "]"
            .. " -> tools/gen_coatable_lists.py --extra"
    end
    print("[WTAGarou][Silver] " .. msg)
    return msg
end

-- Metal melee weapon that can take FORGED silver. Tongs, files and hammers
-- are the forge recipe's tools, not its weapon input (they can still be
-- nitrate-coated), and ranged weapons use rounds instead.
function S.canSilverWeapon(item)
    if not item then return false end
    if instanceof and not instanceof(item, "HandWeapon") then return false end
    if call(item, "isRanged") then return false end
    if S.isSilvered(item) then return false end
    local name = tostring(call(item, "getDisplayName") or "")
    if name:find("[Ss]ilver") then return false end
    if S.isForgeTool(item) then return false end
    return S.isMetalItem(item)
end

-- 0.4.59: forging silver into a weapon asks for the Blacksmith level vanilla
-- asks for to forge that weapon (its blade/head recipe, B42.20.2 scripts).
-- Loot-only twins inherit their forged version's level; weapons vanilla
-- cannot forge at all fall back to FORGE_LEVEL_DEFAULT, the recipe's floor.
S.FORGE_LEVEL_DEFAULT = 1
S.FORGE_LEVELS = {
    ["Base.Axe_Sawblade"] = 0,
    ["Base.CrudeKnife"] = 0,
    ["Base.IronBar"] = 0,
    ["Base.IronBarHalf"] = 0,
    ["Base.SpearCrude"] = 0,
    ["Base.MetalworkingPunch"] = 1,
    ["Base.SmallKnife"] = 1,
    ["Base.SpearKnifeSmall"] = 1,
    ["Base.LargeHook"] = 2,
    ["Base.Pan"] = 2,
    ["Base.PanForged"] = 2,
    ["Base.LongCrudeKnife"] = 3,
    ["Base.MasonsChisel"] = 3,
    ["Base.Saucepan"] = 3,
    ["Base.SaucepanCopper"] = 3,
    ["Base.SpearCrudeLong"] = 3,
    ["Base.CarpentryChisel"] = 4,
    ["Base.File"] = 4,
    ["Base.GardenHoe"] = 4,
    ["Base.GardenHoeForged"] = 4,
    ["Base.HandAxeForged"] = 4,
    ["Base.HandScythe"] = 4,
    ["Base.HandScytheForged"] = 4,
    ["Base.KitchenKnife"] = 4,
    ["Base.KitchenKnifeForged"] = 4,
    ["Base.LargeKnife"] = 4,
    ["Base.MeatCleaver"] = 4,
    ["Base.MeatCleaverForged"] = 4,
    ["Base.MetalworkingChisel"] = 4,
    ["Base.ScissorsForged"] = 4,
    ["Base.SpearShort"] = 4,
    ["Base.HuntingKnife"] = 5,
    ["Base.HuntingKnifeForged"] = 5,
    ["Base.Scissors"] = 5,
    ["Base.ShortSword_Scrap"] = 5,
    ["Base.SpearLong"] = 5,
    ["Base.SpearScissors"] = 5,
    ["Base.Wrench"] = 5,
    ["Base.Axe"] = 6,
    ["Base.Axe_Old"] = 6,
    ["Base.BaseballBat_Spiked"] = 6,
    ["Base.CrudeShortSword"] = 6,
    ["Base.HandAxe"] = 6,
    ["Base.HandAxe_Old"] = 6,
    ["Base.HandguardDagger"] = 6,
    ["Base.ScrapWeaponSpade"] = 6,
    ["Base.Cudgel_Spike"] = 7,
    ["Base.JawboneBovide_Morningstar"] = 7,
    ["Base.ShortSword"] = 7,
    ["Base.Sword_Scrap"] = 7,
    ["Base.CrudeSword"] = 8,
    ["Base.WoodAxe"] = 8,
    ["Base.WoodAxeForged"] = 8,
    ["Base.Katana"] = 9,
    ["Base.Machete"] = 9,
    ["Base.MacheteForged"] = 9,
    ["Base.MacheteKnife"] = 9,
    ["Base.Sword"] = 9,
}

function S.forgeLevelFor(item)
    local ft = call(item, "getFullType")
    local lvl = ft and S.FORGE_LEVELS[tostring(ft)] or nil
    return lvl or S.FORGE_LEVEL_DEFAULT
end

function S.blacksmithLevel(character)
    if not character then return nil end
    local ok, lvl = pcall(function()
        if Perks and Perks.Blacksmith and character.getPerkLevel then
            return character:getPerkLevel(Perks.Blacksmith)
        end
        return nil
    end)
    if ok and type(lvl) == "number" then return lvl end
    return nil
end

-- true when `character` may forge silver into `item`; nil character (no
-- player in the test call) defers to the recipe's own SkillRequired floor.
function S.canForgeAtSkill(item, character)
    local have = S.blacksmithLevel(character)
    if have == nil then return true end
    return have >= S.forgeLevelFor(item)
end

-- craftRecipe OnTest: called for EVERY input item; only judge weapons.
function S.OnTestForgeInput(item, character)
    if item == nil then return false end
    if instanceof and not instanceof(item, "HandWeapon") then return true end
    if call(item, "isRanged") then return false end
    -- Tools keep passing; the weapon input must be a silver candidate.
    if S.isForgeTool(item) then return true end
    if not S.canSilverWeapon(item) then return false end
    return S.canForgeAtSkill(item, character)
end

-- ---------------------------------------------------------------------------
-- 0.4.59: silver nitrate coating (the cheap, temporary route)
-- ---------------------------------------------------------------------------
-- Fertilizer (nitrate) + car battery (sulphuric acid) make nitric acid; it
-- dissolves silver fragments into silver nitrate. Painted on steel, iron
-- displaces the silver out of solution: a thin metallic silver coat forms
-- while the iron underneath corrodes. Hence: condition drops, the coat is
-- real silver, and it wears off after a number of landed hits.
S.COAT_KEY = "WTAGarou_SilverCoat"        -- hits left (number)
S.COAT_NAME_KEY = "WTAGarou_CoatName"      -- name to restore when it wears off
S.COAT_HITS = 12
S.COAT_CONDITION_FRACTION = 0.10
S.COAT_MIN_CONDITION = 1

function S.coatLeft(item)
    local md = modData(item)
    local n = md and md[S.COAT_KEY] or nil
    return type(n) == "number" and n > 0 and n or 0
end

function S.isCoated(item) return S.coatLeft(item) > 0 end

-- Metal melee weapon that can take a coat: like forging, but a coated
-- weapon may be re-coated (the count resets to COAT_HITS), while a forged
-- "Silver" weapon never needs one. 0.4.63: forge tools (hammers, tongs,
-- files) coat like any other metal weapon.
function S.canCoatWeapon(item)
    if not item then return false end
    if instanceof and not instanceof(item, "HandWeapon") then return false end
    if call(item, "isRanged") then return false end
    if S.isSilvered(item) then return false end
    if S.isCoated(item) then return true end
    local name = tostring(call(item, "getDisplayName") or "")
    if name:find("[Ss]ilver") then return false end
    return S.isMetalItem(item)
end

function S.coatName(base, left)
    return "Silvered " .. tostring(base or "Weapon") .. " (" .. tostring(left) .. ")"
end

-- 0.4.62: InventoryItem only saves a renamed item's name when its customName
-- flag is set (save flag 64), so every rename here marks it; restoring the
-- original name clears it again. Fluid-container weapons (saucepans, kettles)
-- display their FluidContainer's UI name instead of the item name, which is
-- why the tooltip line (S.tooltipLine) exists as well.
local function rename(item, name, custom)
    call(item, "setName", name)
    pcall(function() item:setCustomName(custom == true) end)
end
S.rename = rename

-- 0.4.62: silver nitrate is a fluid; a coat pours COAT_FLUID litres of it.
S.FLUID_RAW = "WTAGarou_SilverNitrateRaw"
S.FLUID_DONE = "WTAGarou_SilverNitrate"
S.COAT_FLUID = 0.2

-- ---------------------------------------------------------------------------
-- 0.4.66: multiplayer nitrate warming. The warming itself is client Java
-- (NitrateHeatRuntime); a hosted or dedicated server has no Java, yet the
-- server owns the items and performs the coat recipe. So the client that
-- converted a vessel reports {item, raw, done} (NitrateCooked) and the server
-- sets its copy to the same litres and pushes sendItemStats. Reports are
-- absolute, so a repeated or doubled report is harmless, and the server
-- only accepts a report that keeps the vessel's total and never adds raw.
-- ---------------------------------------------------------------------------
S.NITRATE_COMMAND = "NitrateCooked"
S.NITRATE_TOLERANCE = 0.02

local function fluidByName(name)
    if not (Fluid and Fluid.Get) then return nil end
    local ok, f = pcall(Fluid.Get, name)
    if ok then return f end
    return nil
end
S.fluidByName = fluidByName

-- Litres of raw and finished nitrate in a vessel, or nil when it is not a
-- fluid container.
function S.readNitrate(item)
    if item == nil or call(item, "isFluidContainer") ~= true then return nil end
    local fc = call(item, "getFluidContainer")
    if fc == nil then return nil end
    local rawF, doneF = fluidByName(S.FLUID_RAW), fluidByName(S.FLUID_DONE)
    local raw = rawF and tonumber(call(fc, "getSpecificFluidAmount", rawF)) or 0
    local done = doneF and tonumber(call(fc, "getSpecificFluidAmount", doneF)) or 0
    return raw or 0, done or 0, fc
end

-- Server side: make `item` hold `raw` litres of raw mix and `done` litres of
-- finished nitrate. Returns true plus the litres moved, or false and why.
function S.applyNitrateReport(item, raw, done)
    raw, done = tonumber(raw), tonumber(done)
    if not (raw and done) or raw < 0 or done < 0 then return false, "bad amounts" end
    local curRaw, curDone, fc = S.readNitrate(item)
    if not fc then return false, "not a fluid container" end
    if curRaw + curDone <= 0 then return false, "vessel holds no nitrate" end
    if raw > curRaw + S.NITRATE_TOLERANCE then return false, "report adds raw mix" end
    if math.abs((raw + done) - (curRaw + curDone)) > S.NITRATE_TOLERANCE then return false, "report changes the total" end
    local moved = curRaw - raw
    if math.abs(moved) < 0.0005 and math.abs(done - curDone) < 0.0005 then return true, 0 end
    local rawF, doneF = fluidByName(S.FLUID_RAW), fluidByName(S.FLUID_DONE)
    if not (rawF and doneF) then return false, "fluids not registered" end
    local ok, err = pcall(function()
        fc:adjustSpecificFluidAmount(rawF, math.max(0, raw))
        if done > curDone then fc:addFluid(doneF, done - curDone)
        elseif done < curDone then fc:adjustSpecificFluidAmount(doneF, math.max(0, done)) end
    end)
    if not ok then return false, tostring(err) end
    return true, moved
end

-- ---------------------------------------------------------------------------
-- 0.4.72: multiplayer warming simulation (shared math, client-driven).
--
-- Why: on a multiplayer CLIENT the engine never calls InventoryItem.update
-- for items sitting in world containers. IsoCell.update runs ProcessItems
-- only in single player, or on the server every 5 s (IsoCell.java: `if
-- (!GameClient.client && !GameServer.server || GameServer.server && ...)`),
-- and a client only updates IUpdater items in the player's own bags. So the
-- 0.4.66 "client Java is the MP authority" hook never fired for a jar in an
-- oven (Oct 18 hosted test: 30 game minutes in a microwave, still raw, Java
-- status "0 conversion ticks"). The server has no Java either.
--
-- Now a client near a hot container simulates the warming in Lua (no Java
-- involved) in GAME MINUTES and reports absolute litres through the existing
-- NitrateCooked command; the server applies them (applyNitrateReport) and
-- additionally clamps the speed per vessel (nitrateAllowance) so two clients
-- watching the same oven cannot double it. Single player keeps the Java
-- frame-rate simulation unchanged.
-- ---------------------------------------------------------------------------
S.Sim = {
    COLD = 1.0,           -- ItemContainer.getTemprature() for anything unheated
    THRESHOLD = 1.6,      -- vanilla boil point (itemHeat > 1.6)
    MAX_WARMTH = 3.0,
    WARM_MINUTES = 5,     -- cold vessel to boiling in a running oven / lit fire
    LITRES_PER_MINUTE = 0.1,  -- finished per game minute once boiling (1 L in 10 min; ~15 with warm-up)
    MAX_STEP_MINUTES = 10,    -- one scan never simulates more than this (pause / lag)
}
S.Sim.WARM_RATE = (S.Sim.THRESHOLD - S.Sim.COLD) / S.Sim.WARM_MINUTES   -- warmth per game minute
S.Sim.COOL_RATE = S.Sim.WARM_RATE

-- Vessel warmth after `minutes` in a container at `temp`. Pure.
function S.simWarm(warmth, temp, minutes)
    local Z = S.Sim
    minutes = math.max(0, math.min(Z.MAX_STEP_MINUTES, tonumber(minutes) or 0))
    warmth = tonumber(warmth) or Z.COLD
    temp = tonumber(temp) or Z.COLD
    if warmth < Z.COLD then warmth = Z.COLD end
    if temp > warmth then
        return math.min(math.min(Z.MAX_WARMTH, temp), warmth + Z.WARM_RATE * minutes)
    end
    return math.max(math.max(Z.COLD, temp), warmth - Z.COOL_RATE * minutes)
end

-- Litres of raw mix that finish in `minutes` at `warmth`. Pure.
function S.simConvert(raw, warmth, minutes)
    local Z = S.Sim
    raw = tonumber(raw) or 0
    if raw <= 0 or (tonumber(warmth) or Z.COLD) <= Z.THRESHOLD + 1e-9 then return 0 end
    minutes = math.max(0, math.min(Z.MAX_STEP_MINUTES, tonumber(minutes) or 0))
    return math.min(raw, Z.LITRES_PER_MINUTE * minutes)
end

-- 0.4.74: where a vessel is, as plain numbers. An InventoryItem placed in a
-- client command is serialized as a full COPY (TableNetworkUtils: type 4 =
-- saveWithSize / loadItem), so the server receives a detached twin and any
-- fluid change on it goes nowhere -- the Oct 19 test: client "warming",
-- vessel still raw after 35 game minutes. Vanilla sends item IDs plus the
-- square / object index / container index (ClientCommands.lua) and so do we.
function S.locateVessel(item, cont)
    if not (item and item.getID) then return nil end
    local loc = { id = item:getID() }
    local parent = cont and cont.getParent and cont:getParent()
    local sq = parent and parent.getSquare and parent:getSquare()
    if sq then
        loc.x, loc.y, loc.z = sq:getX(), sq:getY(), sq:getZ()
        loc.index = parent.getObjectIndex and parent:getObjectIndex() or -1
        loc.containerIndex = -1
        local count = parent.getContainerCount and parent:getContainerCount() or 0
        for i = 0, count - 1 do
            if parent:getContainerByIndex(i) == cont then loc.containerIndex = i; break end
        end
    end
    return loc
end

-- Server: the live vessel for a located report. Tries the object the client
-- named, then every container on that square, then the player's own bags.
-- `cell` injectable for tests.
function S.findVessel(player, args, cell)
    if not (args and args.id ~= nil) then return nil end
    local id = tonumber(args.id)
    if not id then return nil end
    local function fromContainer(cont)
        if not cont then return nil end
        local ok, item = pcall(function() return cont:getItemWithID(id) end)
        if ok and item then return item end
        return nil
    end
    cell = cell or (getCell and getCell())
    if cell and args.x then
        local ok, sq = pcall(function() return cell:getGridSquare(args.x, args.y, args.z) end)
        if ok and sq then
            local objects = sq:getObjects()
            local n = objects and objects:size() or 0
            local index = tonumber(args.index) or -1
            if index >= 0 and index < n then
                local o = objects:get(index)
                local ci = tonumber(args.containerIndex) or -1
                local cont = (ci >= 0 and o.getContainerByIndex) and o:getContainerByIndex(ci)
                    or (o.getContainer and o:getContainer())
                local item = fromContainer(cont)
                if item then return item end
            end
            for i = 0, n - 1 do
                local o = objects:get(i)
                local count = o.getContainerCount and o:getContainerCount() or 0
                for c = 0, count - 1 do
                    local item = fromContainer(o:getContainerByIndex(c))
                    if item then return item end
                end
                if count == 0 and o.getContainer then
                    local item = fromContainer(o:getContainer())
                    if item then return item end
                end
            end
        end
    end
    if player and player.getInventory then
        return fromContainer(player:getInventory())
    end
    return nil
end

-- Server: litres a vessel may have finished since its last accepted report
-- (`sinceMinutes` game minutes ago). Generous: 1.5x the rate plus a little
-- slack for the first report, so honest lag never clips; two clients
-- reporting the same oven still cannot exceed roughly one oven's pace.
function S.nitrateAllowance(sinceMinutes)
    local Z = S.Sim
    sinceMinutes = math.max(0, tonumber(sinceMinutes) or 0)
    return Z.LITRES_PER_MINUTE * 1.5 * sinceMinutes + 0.05
end

-- Server: clamp a report to the allowance. Returns raw, done to apply.
function S.clampNitrateReport(curRaw, curDone, raw, done, allowance)
    curRaw, curDone = tonumber(curRaw) or 0, tonumber(curDone) or 0
    raw, done = tonumber(raw) or 0, tonumber(done) or 0
    local moved = curRaw - raw
    if moved > allowance + 1e-6 then
        moved = math.max(0, allowance)
        return curRaw - moved, curDone + moved, true
    end
    return raw, done, false
end

-- Fluid container that is not empty (the nitrate vessel in the coat recipe,
-- whatever it is: jar, bottle, glass, or even a saucepan).
function S.isFilledFluidContainer(item)
    if item == nil then return false end
    if call(item, "isFluidContainer") ~= true then return false end
    local fc = call(item, "getFluidContainer")
    if fc == nil then return false end
    return call(fc, "isEmpty") == false
end

-- Inventory tooltip extra line (client, WTAGarouSilverTooltip.lua). Returns
-- text plus r,g,b, or nil when the item carries no silver state.
function S.tooltipLine(item)
    if item == nil then return nil end
    local left = S.coatLeft(item)
    if left > 0 then
        return "Silver coat: " .. left .. " of " .. S.COAT_HITS .. " hits left", 0.80, 0.85, 0.95
    end
    if S.isSilvered(item) then
        -- 0.4.79 wording (user): the old "Forged silver: ..." read as if the
        -- weapon were made of silver.
        return "Silver-Clad: burns werewolves, prevents healing.", 0.80, 0.85, 0.95
    end
    -- 0.4.81: the silver smoke bomb.
    if call(item, "getFullType") == "WTAGarou.SilverSmokeBomb" then
        return "Silver dust: werewolves breathing the smoke burn and rage.", 0.80, 0.85, 0.95
    end
    return nil
end

-- craftRecipe OnTest for the coating recipe (0.4.62): the vessel slot is any
-- NON-EMPTY fluid container (the engine checks that it holds 0.2 L of
-- WTAGarou_SilverNitrate); the weapon slot must accept a coat. Anything else
-- (foil, cans, bulbs that still carry HasMetal) is refused. No skill involved.
function S.OnTestCoatInput(item, character)
    if item == nil then return false end
    if S.isFilledFluidContainer(item) then return true end
    if instanceof and not instanceof(item, "HandWeapon") then return false end
    return S.canCoatWeapon(item)
end

-- Vessel rule for WTAGarou_PrepareSilverNitrate (0.4.60, kept in 0.4.62).
-- The recipe's vessel slot is `tags[Glass;GlassBottle] mode:keep
-- flags[ItemIsFluid;IsEmpty]` and the recipe pours 1.0 L of raw silver
-- nitrate into it; this OnTest tightens it: anything carrying a Glass tag
-- must actually be a fluid container (jar, beaker, beer/whiskey/wine bottle,
-- glass...), not a windshield or a shard, and it must be empty. Plastic never
-- carries the Glass tag, so plastic bottles are refused by the script alone.
-- Every other input (fertilizer, battery, fragments, the opening tool) passes
-- untouched. The vessel is KEPT: it comes back full of raw mix.
S.GLASS_TAGS = { Glass = true, GlassBottle = true }

function S.isEmptyGlassVessel(item)
    if item == nil then return false end
    if not hasAnyTag(item, S.GLASS_TAGS) then return false end
    local isFc = call(item, "isFluidContainer")
    if isFc ~= true then return false end
    local fc = call(item, "getFluidContainer")
    if fc == nil then return false end
    local empty = call(fc, "isEmpty")
    return empty == true
end

function S.OnTestNitrateInput(item, character)
    if item == nil then return false end
    if not hasAnyTag(item, S.GLASS_TAGS) then return true end
    return S.isEmptyGlassVessel(item)
end

function S.applyCoat(item)
    local md = modData(item)
    if not md then return false end
    if not md[S.COAT_NAME_KEY] then
        md[S.COAT_NAME_KEY] = tostring(call(item, "getDisplayName") or "Weapon")
    end
    md[S.COAT_KEY] = S.COAT_HITS
    rename(item, S.coatName(md[S.COAT_NAME_KEY], S.COAT_HITS), true)
    pcall(function()
        local max = item:getConditionMax()
        local cond = item:getCondition()
        local cost = math.max(1, math.floor(max * S.COAT_CONDITION_FRACTION + 0.5))
        item:setCondition(math.max(S.COAT_MIN_CONDITION, cond - cost))
    end)
    return true
end

-- craftRecipe OnCreate(craftRecipeData, character): coat the kept weapon.
function S.OnCoatWeapon(recipeData, character)
    if not recipeData then return 0 end
    local kept = call(recipeData, "getAllKeepInputItems")
    if not kept then return 0 end
    local coated = 0
    local size = call(kept, "size") or (type(kept) == "table" and #kept) or 0
    for i = 0, size - 1 do
        local item = kept.get and kept:get(i) or kept[i + 1]
        -- the nitrate vessel is kept too; never coat the thing the acid is in
        if not S.isFilledFluidContainer(item) and S.canCoatWeapon(item) and S.applyCoat(item) then coated = coated + 1 end
    end
    if coated > 0 then print("[WTAGarou][Silver] silver nitrate coat on " .. coated .. " weapon(s)") end
    return coated
end

-- One landed hit spends one charge. Returns the charges left, or nil when
-- the weapon was not coated. At zero the name goes back to what it was.
function S.spendCoat(item)
    local left = S.coatLeft(item)
    if left <= 0 then return nil end
    local md = modData(item)
    left = left - 1
    if left <= 0 then
        local base = md[S.COAT_NAME_KEY]
        md[S.COAT_KEY] = nil
        md[S.COAT_NAME_KEY] = nil
        if base then rename(item, base, false) end
        return 0
    end
    md[S.COAT_KEY] = left
    rename(item, S.coatName(md[S.COAT_NAME_KEY], left), true)
    return left
end

function S.silverName(name)
    name = tostring(name or "Weapon")
    if name:find("^Silver ") then return name end
    return "Silver " .. name
end

-- craftRecipe OnCreate(craftRecipeData, character): mark the kept weapon.
function S.OnForgeWeapon(recipeData, character)
    if not recipeData then return 0 end
    local kept = call(recipeData, "getAllKeepInputItems")
    if not kept then return 0 end
    local marked = 0
    local size = call(kept, "size") or (type(kept) == "table" and #kept) or 0
    for i = 0, size - 1 do
        local item = kept.get and kept:get(i) or kept[i + 1]
        if S.canSilverWeapon(item) then
            local md = modData(item)
            if md then
                md[S.SILVER_KEY] = true
                if not md[S.NAME_KEY] then
                    rename(item, S.silverName(call(item, "getDisplayName")), true)
                    md[S.NAME_KEY] = true
                end
                marked = marked + 1
            end
        end
    end
    if marked > 0 then print("[WTAGarou][Silver] forged silver into " .. marked .. " weapon(s)") end
    return marked
end

-- ---------------------------------------------------------------------------
-- Vanilla action wrappers (installed once the game has loaded them)
-- ---------------------------------------------------------------------------
local installed = false
function S.install(env)
    if installed then return 0 end
    env = env or _G
    local count = 0
    local function wrap(klass, method, fn)
        if type(klass) ~= "table" or type(klass[method]) ~= "function" then return end
        local saved = "WTAGarou_silver_" .. method
        if klass[saved] then return end
        klass[saved] = klass[method]
        klass[method] = function(self, ...) return fn(self, klass[saved], ...) end
        count = count + 1
    end
    local function refuse(character, reason)
        local hud = WTAGarou.HUD and WTAGarou.HUD.instance
        if hud and hud.flashDenial then hud:flashDenial(reason) end
    end
    -- Mixed loading refused (gun tube and magazines).
    wrap(env.ISReloadWeaponAction, "isValid", function(self, orig, ...)
        if S.refusesOrdinaryReload(self.gun) then refuse(self.character, "silver_mixed_load"); return false end
        return orig(self, ...)
    end)
    wrap(env.ISLoadBulletsInMagazine, "isValid", function(self, orig, ...)
        if S.refusesOrdinaryReload(self.magazine) then refuse(self.character, "silver_mixed_load"); return false end
        return orig(self, ...)
    end)
    -- Unloading hands silver back as silver (vanilla creates ordinary rounds
    -- inside animEvent, one step per loop).
    wrap(env.ISUnloadBulletsFromFirearm, "animEvent", function(self, orig, ...)
        local before = S.snapshot(self.gun)
        local result = orig(self, ...)
        local now = call(self.gun, "getCurrentAmmoCount") or 0
        S.swapUnloadedRounds(self.character, self.gun, before.silver, before.count - now)
        return result
    end)
    wrap(env.ISUnloadBulletsFromMagazine, "animEvent", function(self, orig, ...)
        local before = S.snapshot(self.magazine)
        local result = orig(self, ...)
        local now = call(self.magazine, "getCurrentAmmoCount") or 0
        S.swapUnloadedRounds(self.character, self.magazine, before.silver, before.count - now)
        return result
    end)
    -- Magazines carry their silver count into and out of the gun.
    wrap(env.ISInsertMagazine, "loadAmmo", function(self, orig, ...)
        local magSilver = S.clamp(self.magazine)
        local result = orig(self, ...)
        S.afterInsert(self.gun, magSilver)
        return result
    end)
    wrap(env.ISEjectMagazine, "unloadAmmo", function(self, orig, ...)
        local gunSilver = S.clamp(self.gun)
        local inv = call(self.character, "getInventory")
        local magType = call(self.gun, "getMagazineType")
        local seen = {}
        local beforeItems = magType and call(inv, "getItemsFromFullType", tostring(magType)) or nil
        if beforeItems and beforeItems.size then
            for i = 0, beforeItems:size() - 1 do seen[beforeItems:get(i)] = true end
        end
        local result = orig(self, ...)
        local afterItems = magType and call(inv, "getItemsFromFullType", tostring(magType)) or nil
        if afterItems and afterItems.size then
            for i = 0, afterItems:size() - 1 do
                local mag = afterItems:get(i)
                if not seen[mag] then S.afterEject(self.gun, mag, gunSilver); break end
            end
        end
        return result
    end)
    -- Racking chambers a round (or ejects one).
    wrap(env.ISRackFirearm, "animEvent", function(self, orig, ...)
        local before = S.snapshot(self.gun)
        local result = orig(self, ...)
        S.afterRack(self.gun, before)
        return result
    end)
    -- 0.4.63: the ejected live round stays silver (vanilla instances the
    -- ordinary ammo type here).
    wrap(env.ISRackFirearm, "removeBullet", function(self, orig, ...)
        local silverType = S.ejectedRoundType(self.gun)
        if not silverType then return orig(self, ...) end
        local inv = call(self.character, "getInventory")
        local round = inv and (instanceItem and instanceItem(silverType) or nil)
        if round then
            call(inv, "AddItem", round)
        elseif inv then
            round = call(inv, "AddItem", silverType)
        end
        if not round then return orig(self, ...) end
        if sendAddItemToContainer then pcall(sendAddItemToContainer, inv, round) end
    end)
    installed = count > 0
    if installed then print("[WTAGarou][Silver] " .. count .. " vanilla ammunition paths wrapped for silver bookkeeping") end
    return count
end

if Events then
    if Events.OnGameStart then Events.OnGameStart.Add(function() S.install(_G) end) end
    if Events.OnWeaponSwing then Events.OnWeaponSwing.Add(S.onSwing) end
    if Events.OnWeaponSwingHitPoint then Events.OnWeaponSwingHitPoint.Add(S.afterShot) end
end
