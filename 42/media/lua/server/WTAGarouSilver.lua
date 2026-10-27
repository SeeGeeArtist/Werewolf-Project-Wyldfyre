--[[
    WTAGarou - Silver (v0.4.28)

    Two ways silver hurts a Garou:

    1. Weapon hits (since 0.2.0). A weapon tagged as silver that lands on a
       Garou burns the struck body part and deals DAMAGE_MULT damage.

    2. Contact burns (0.4.17, the user's rule): "silver burn inflicts a burn
       wound the longer the silver item is held without gloves or worn. It
       burns the body part that it is being held in or is worn on, and it
       disables super healing on that body part until the silver burn wound
       has healed naturally. Silver burns heal at the same rate and with the
       same treatment as a regular vanilla burn. Once the silver burn has
       healed, super healing is enabled again for that body part."

       Every SCAN_SECONDS the server looks at the Garou's worn items and
       hands. Worn silver touches the parts in WTAGarou.Silver.LOCATION_PARTS
       for its body location (or the item's covered parts for real
       clothing). Held silver touches Hand_R (primary) / Hand_L (secondary)
       unless something is worn on a GLOVE_LOCATIONS location. Contact time
       accumulates per part; at CONTACT_SECONDS the part gets a vanilla burn
       (BodyPart burn time INITIAL_BURN, needs washing, bandage helps) and is
       flagged in d.silverBurns[part] = true. Continued contact grows the burn
       by GROWTH_PER_SECOND up to MAX_BURN. WTAGarou.Regenerate skips a
       flagged part while its burn time is above 0 and clears the flag when
       the burn has healed.

    0.4.28: onset 1s; mild burn 2, growth 0.05/s. Java scales only the
    native unbandaged burn damage call; wound healing and washing stay native.
    The tests/rage_engine_test.lua fixture exercises S.scan.
]]

WTAGarou = WTAGarou or {}
WTAGarou.Silver = WTAGarou.Silver or {}
local S = WTAGarou.Silver

S.SCAN_SECONDS = 1.0

local function cfg(key, default)
    local v = S[key]
    if v == nil then return default end
    return v
end

-- "base:HasMetal" / "HasMetal" / ItemTag -> "hasmetal"
function S.tagKey(t)
    local str = tostring(t or "")
    str = str:match("^[^:]*:(.*)$") or str
    return str:lower()
end

local function itemIsSilver(item)
    if not item then return false end
    local ok, res = pcall(function()
        if item.getModData then
            local md = item:getModData()
            if md and md.WTAGarou_Silver then return true end
            -- 0.4.59: a silver nitrate coat is silver while charges remain.
            if md and type(md.WTAGarou_SilverCoat) == "number" and md.WTAGarou_SilverCoat > 0 then return true end
        end
        local pattern = cfg("NAME_PATTERN", "[Ss]ilver")
        if item.getFullType then
            local ft = item:getFullType()
            if ft and tostring(ft):find(pattern) then return true end
        end
        if item.getDisplayName then
            local dn = item:getDisplayName()
            if dn and tostring(dn):find(pattern) then return true end
        end
        -- 0.4.19: InventoryItem.hasTag takes ItemTag objects in 42.20.2, not
        -- a String; the old hasTag("Silver") threw a Java exception on every
        -- non-silver worn item, once per scan, from frame 1. Compare tag names.
        -- 0.4.62: ItemTag:toString() is the namespaced registry id
        -- ("base:silver", lower case), so compare the path without namespace.
        local tag = cfg("TAG", "Silver")
        if tag ~= nil and item.getTags then
            local want = tostring(tag):lower()
            local tags = item:getTags()
            if tags then
                local it = tags.iterator and tags:iterator() or nil
                while it and it:hasNext() do
                    if S.tagKey(it:next()) == want then return true end
                end
                if type(tags) == "table" then
                    for _, t in ipairs(tags) do if S.tagKey(t) == want then return true end end
                end
            end
        end
        return false
    end)
    return ok and res == true
end
S.itemIsSilver = itemIsSilver

-- 0.4.59: "anything with silver in its name burns" has logical exceptions.
-- Silver that is sealed away from the skin does not touch it. 0.4.62: silver
-- nitrate is a fluid, so the vessel it sits in (jar, bottle, glass, saucepan)
-- is exempt as long as the vessel itself is not silver: a coated or forged
-- weapon that happens to be a fluid container (a Silvered Saucepan) still
-- burns through its coat. Only the CONTACT scan honours this; a sealed item
-- that is swung and lands still counts as a weapon hit through itemIsSilver.
-- Silver rounds inside a gun or magazine are covered by the ammo bookkeeping.
local function contactExempt(item)
    if not item then return false end
    local ok, res = pcall(function()
        if item.getModData then
            local md = item:getModData()
            if md then
                local coat = md.WTAGarou_SilverCoat
                if (type(coat) == "number" and coat > 0) or md.WTAGarou_Silver == true then return false end
            end
        end
        if item.isFluidContainer and item:isFluidContainer() == true then return true end
        return false
    end)
    return ok and res == true
end
S.contactExempt = contactExempt

-- Silver that burns when held or worn against bare skin.
local function contactSilver(item)
    return itemIsSilver(item) and not contactExempt(item)
end
S.contactSilver = contactSilver

-- 0.4.20: a firearm fires silver when its rounds are silver: mod data
-- WTAGarou_SilverAmmo on the weapon (set by the Test Panel "Silver rounds"
-- button or by another mod's loading recipe), or an ammo / magazine type
-- whose name matches NAME_PATTERN (for mods that add silver bullets).
local function firesSilver(weapon)
    if not weapon then return false end
    local ok, res = pcall(function()
        if not (weapon.isRanged and weapon:isRanged()) then return false end
        local md = weapon.getModData and weapon:getModData() or nil
        -- 0.4.58: real silver rounds are counted per shot by
        -- WTAGarou.SilverAmmo (WTAGarou_SilverShot set at OnWeaponSwing).
        -- The Test Panel's legacy boolean flag still means "always silver".
        if md and md.WTAGarou_SilverAmmo == true then return true end
        if md and md.WTAGarou_SilverShot ~= nil then return md.WTAGarou_SilverShot == true end
        if md and type(md.WTAGarou_SilverAmmo) == "number" and md.WTAGarou_SilverAmmo > 0 then return true end
        local pattern = cfg("NAME_PATTERN", "[Ss]ilver")
        if weapon.getAmmoType then
            local ammo = weapon:getAmmoType()
            if ammo ~= nil and tostring(ammo):find(pattern) then return true end
        end
        if weapon.getMagazineType then
            local mag = weapon:getMagazineType()
            if mag ~= nil and tostring(mag):find(pattern) then return true end
        end
        return false
    end)
    return ok and res == true
end
S.firesSilver = firesSilver

-- Body part lookup by type name ("Hand_L"), through the BodyDamage parts list.
local function partByName(bd, name)
    if not (bd and name) then return nil end
    local found = nil
    pcall(function()
        local parts = bd:getBodyParts()
        for i = 0, parts:size() - 1 do
            local bp = parts:get(i)
            if tostring(bp:getType()) == name then found = bp; return end
        end
    end)
    return found
end
S.partByName = partByName

-- S-curve: slow onset, steep middle, then a plateau. Seconds of contact,
-- not game time acceleration or render frames. Exported for fixture tests.
function S.contactSeverity(seconds)
    local onset=cfg("CONTACT_SECONDS",1)
    local t=math.max(0,math.min(1,(seconds-onset)/math.max(1,cfg("RAMP_SECONDS",60)-onset)))
    local ease=t*t*t*(t*(t*6-15)+10)
    return cfg("INITIAL_BURN",2)+(cfg("MAX_BURN",75)-cfg("INITIAL_BURN",2))*ease
end

-- Start a vanilla burn on `bp` (when it has none) and flag it as a silver
-- burn. growSeconds (number) = the contact continued that long on an already
-- burned part: grow the burn by GROWTH_PER_SECOND * growSeconds up to
-- MAX_BURN. Returns true when the part was newly flagged.
local function burnPart(target, bp, growSeconds)
    if not (target and bp) then return false end
    local d = WTAGarou.GetData(target)
    d.silverBurns = d.silverBurns or {}
    local key = tostring(bp:getType())
    local current = 0
    pcall(function() current = bp:getBurnTime() or 0 end)
    local newBurn = current
    if current <= 0 then
        newBurn = cfg("INITIAL_BURN", 2)
        pcall(function() if bp.setNeedBurnWash then bp:setNeedBurnWash(true) end end)
        pcall(function() if bp.setLastTimeBurnWash then bp:setLastTimeBurnWash(0) end end)
    elseif type(growSeconds) == "number" and growSeconds > 0 then
        newBurn = math.max(current, math.min(cfg("MAX_BURN", 30), current + cfg("GROWTH_PER_SECOND", 0.05) * growSeconds))
    end
    if newBurn ~= current then pcall(function() bp:setBurnTime(newBurn) end) end
    local fresh = (current <= 0)
    d.silverBurns[key] = true
    return fresh
end
S.burnPart = burnPart

-- Case-insensitive table lookup: engine ids are lower case ("ears"), the
-- tables are CamelCase (Ears). Shares WTAGarou.Clothing.lookup when loaded.
local function lookup(tbl, loc)
    if WTAGarou.Clothing and WTAGarou.Clothing.lookup then
        return WTAGarou.Clothing.lookup(tbl, loc)
    end
    if type(tbl) ~= "table" or loc == nil then return nil end
    if tbl[loc] ~= nil then return tbl[loc] end
    local key = tostring(loc):lower()
    for k, v in pairs(tbl) do
        if tostring(k):lower() == key then return v end
    end
    return nil
end

-- Bare body location id of a worn item (via the Clothing helper when loaded).
local function locationOf(item)
    if WTAGarou.Clothing and WTAGarou.Clothing.locationId then
        return WTAGarou.Clothing.locationId(item)
    end
    local ok, loc = pcall(function() return item:getBodyLocation() end)
    if not ok or loc == nil then return nil end
    local s = tostring(loc)
    return s:match("^[%w_]+:(.+)$") or s
end

-- Body part names touched by a worn item.
local function partsTouched(item)
    local loc = locationOf(item)
    local map = cfg("LOCATION_PARTS", {})
    local mapped = loc and lookup(map, loc) or nil
    if mapped then return mapped end
    local out = {}
    pcall(function()
        if item.getCoveredParts then
            local covered = item:getCoveredParts()
            if covered then
                for i = 0, covered:size() - 1 do
                    local bpt = covered:get(i)
                    -- BloodBodyPartType -> BodyPartType share names for the
                    -- parts that matter here (Hand_L, ForeArm_R, Neck ...).
                    out[#out + 1] = tostring(bpt)
                end
            end
        end
    end)
    return out
end
S.partsTouched = partsTouched

local function wearsGloves(player)
    local gloves = cfg("GLOVE_LOCATIONS", { Hands = true })
    local found = false
    pcall(function()
        local worn = player:getWornItems()
        for i = 0, worn:size() - 1 do
            local it = worn:get(i):getItem()
            local loc = it and locationOf(it) or nil
            if loc and lookup(gloves, loc) then found = true; return end
        end
    end)
    return found
end
S.wearsGloves = wearsGloves

-- Set of body part names in contact with silver right now.
function S.contacts(player)
    local set = {}
    if not player then return set end
    pcall(function()
        local worn = player:getWornItems()
        for i = 0, worn:size() - 1 do
            local it = worn:get(i):getItem()
            if it and contactSilver(it) then
                for _, name in ipairs(partsTouched(it)) do set[name] = true end
            end
        end
    end)
    local gloved = wearsGloves(player)
    if not gloved then
        pcall(function()
            local p = player:getPrimaryHandItem()
            local s = player:getSecondaryHandItem()
            if p and contactSilver(p) then set.Hand_R = true end
            if s and contactSilver(s) then set.Hand_L = true end
            -- two-handed: the same item sits in both slots
            if p and s and p == s and contactSilver(p) then set.Hand_L = true; set.Hand_R = true end
        end)
    end
    return set
end

-- One scan step for `player`, `dt` seconds since the previous one.
-- Returns the list of part names that received a NEW silver burn this step.
function S.scan(player, dt)
    local fresh = {}
    if not player then return fresh end
    if not WTAGarou.HasGarouTrait(player) then
        if WTAGarouJava and WTAGarouJava.setSilverBurnDamage and player.getBodyDamage then
            local parts=player:getBodyDamage():getBodyParts()
            for i=0,parts:size()-1 do WTAGarouJava.setSilverBurnDamage(parts:get(i),1) end
        end
        return fresh
    end
    local d = WTAGarou.GetData(player)
    d.silverContact = d.silverContact or {}
    local bd = player.getBodyDamage and player:getBodyDamage() or nil
    if not bd then return fresh end
    -- 0.4.76: lodged silver-tip bullets smoulder until pulled.
    if d.silverLodged then pcall(S.lodgedStep, player, d, bd, dt) end
    -- 0.4.77: scattered silver underfoot.
    if WTAGarou.Scatter and WTAGarou.Scatter.step then pcall(WTAGarou.Scatter.step, player, d, bd, dt) end
    -- 0.4.81: silver dust from a silver smoke bomb.
    if WTAGarou.SilverSmoke and WTAGarou.SilverSmoke.step then pcall(WTAGarou.SilverSmoke.step, player, d, bd, dt) end
    local touching = S.contacts(player)
    local threshold = cfg("CONTACT_SECONDS", 1)
    -- accumulate
    for name in pairs(touching) do
        d.silverContact[name] = (d.silverContact[name] or 0) + dt
        local bp = partByName(bd, name)
        if bp and d.silverContact[name] >= threshold then
            -- first pass burns; every later pass while still touching grows
            if burnPart(player, bp, 0) then fresh[#fresh + 1] = name end
            -- Preserve more severe pre-existing wounds; contact never heals.
            bp:setBurnTime(math.max(bp:getBurnTime() or 0,S.contactSeverity(d.silverContact[name])))
        end
    end
    -- decay contact timers for parts no longer touching silver
    for name, t in pairs(d.silverContact) do
        if not touching[name] then
            local nt = t - dt * 2
            if nt <= 0 then d.silverContact[name] = nil else d.silverContact[name] = nt end
        end
    end
    -- Also restore registered damage factors for saved wounds after reload
    -- and after the silver item is removed. Never heal/refund damage here.
    if WTAGarouJava and WTAGarouJava.setSilverBurnDamage then
        local parts=bd:getBodyParts()
        for i=0,parts:size()-1 do
            local bp=parts:get(i)
            local bt=bp:getBurnTime() or 0
            local marked=(d.silverBurns or {})[tostring(bp:getType())]
            local factor=1
            if marked==true and bt>0 then
                local t=math.max(0,math.min(1,(bt-cfg("INITIAL_BURN",2))
                    / math.max(1,cfg("MAX_BURN",75)-cfg("INITIAL_BURN",2))))
                factor=cfg("TICK_DAMAGE_MIN",0.04)
                    +(cfg("TICK_DAMAGE_MAX",0.85)-cfg("TICK_DAMAGE_MIN",0.04))*t
            end
            WTAGarouJava.setSilverBurnDamage(bp,factor)
        end
    end
    return fresh
end

-- 0.4.41: tell the owner a burn was applied (dedicated server: command to
-- that client; single player / host: react locally). Weapon hits and the
-- contact scan share this path.
local function announce(player, name)
    print("[WTAGarou][Silver] " .. tostring(name) .. " burned by silver")
    if sendServerCommand and isServer and isServer() then
        pcall(function() sendServerCommand(player, "WTAGarou", "SilverBurn", { part = name }) end)
    elseif WTAGarou.SilverReact then
        WTAGarou.SilverReact(player, name)
    else
        local part = (tostring(name):gsub("_", " "))
        if WTAGarou.HUD and WTAGarou.HUD.instance and WTAGarou.HUD.instance.pushNotice then
            WTAGarou.HUD.instance:pushNotice("Silver burns your " .. part .. ".")
        end
        if WTAGarou.SilverBurnHalo then WTAGarou.SilverBurnHalo(player, part) end
    end
end
S.announce = announce

-- ---------------------------------------------------------------------------
-- Weapon hits (0.2.0 behaviour, now a real burn wound).
-- ---------------------------------------------------------------------------
-- 0.4.59: coated weapons wear. Tells the wielder when the last charge goes.
function S.spendCoatOnHit(attacker, weapon)
    local A = WTAGarou.SilverAmmo
    if not (A and A.spendCoat) then return nil end
    local ok, left = pcall(A.spendCoat, weapon)
    if not ok then return nil end
    if left == 0 then
        pcall(function()
            local hud = WTAGarou.HUD and WTAGarou.HUD.instance or nil
            local mine = attacker and getSpecificPlayer and attacker.getPlayerNum
                and getSpecificPlayer(attacker:getPlayerNum()) == attacker
            if hud and hud.flashDenial and (mine or getSpecificPlayer == nil) then hud:flashDenial("silver_worn_off") end
        end)
    end
    return left
end

-- 0.4.58 (Wits W4): burn the wound the engine made. OnWeaponHitCharacter
-- fires BEFORE BodyDamage.DamageFromWeapon chooses the part, so with the
-- Java recorder present we wait one tick and ask which part was wounded.
-- No record within the window means the clothing stopped the hit: silver
-- burns wounds, not coats, so nothing burns. Without the Java supplement
-- the pre-0.4.58 random-part burn is kept.
local pendingHits = {}
local function partByIndex(bd, index)
    local found = nil
    pcall(function()
        local parts = bd:getBodyParts()
        if parts and index >= 0 and index < parts:size() then found = parts:get(index) end
    end)
    return found
end
S.partByIndex = partByIndex

-- ---------------------------------------------------------------------------
-- 0.4.76/0.4.77: lodged silver keeps burning until it is pulled. Two kinds:
--   "bullet": a silver-tip round that stayed in (engine haveBullet; Pliers,
--             Tweezers, Forceps, Suture Needle Holder pull it),
--   "shard":  silver fragments from a scattered tile that worked into a bare
--             foot or paw (engine haveGlass; Remove Glass by hand/tweezers).
-- A small piece: the burn creeps up at LODGED_GROWTH_PER_SECOND to
-- LODGED_MAX_BURN instead of the contact S-curve to MAX_BURN, but it never
-- goes out, so the part stays silver-blocked: no regeneration there and the
-- engine's own foreign-body damage ticks on. d.silverLodged[partKey] = kind,
-- synced to the owner's client for the health panel.
-- ---------------------------------------------------------------------------
S.LODGED_GROWTH_PER_SECOND = 0.15
S.LODGED_MAX_BURN = 25
S.LODGED_FLAG = { bullet = "haveBullet", shard = "haveGlass" }
S.LODGED_COMMAND = "SilverLodged"

local function lodgedNotice(player, key, kind, lodged)
    if sendServerCommand and isServer and isServer() then
        pcall(sendServerCommand, player, "WTAGarou", S.LODGED_COMMAND, { part = key, kind = kind, lodged = lodged == true })
    elseif WTAGarou.SilverLodgedReact then
        pcall(WTAGarou.SilverLodgedReact, player, key, kind, lodged == true)
    end
end

local function partHasForeign(bp, kind)
    local m = S.LODGED_FLAG[kind]
    if not (m and bp and bp[m]) then return false end
    local ok, has = pcall(bp[m], bp)
    return ok and has == true
end
S.partHasForeign = partHasForeign

-- Called once the wound exists: silver that stayed in the part.
function S.markLodged(target, bp, kind)
    kind = kind or "bullet"
    if not partHasForeign(bp, kind) then return false end
    local d = WTAGarou.GetData(target); if not d then return false end
    d.silverLodged = d.silverLodged or {}
    local key = tostring(bp:getType())
    if d.silverLodged[key] == kind then return false end
    d.silverLodged[key] = kind
    print("[WTAGarou][Silver] silver " .. kind .. " lodged in " .. key .. " of " .. tostring(target.getUsername and target:getUsername() or "player"))
    lodgedNotice(target, key, kind, true)
    return true
end

-- Per-scan step for the lodged pieces. Returns the number still lodged.
function S.lodgedStep(player, d, bd, dt)
    local lodged = d and d.silverLodged
    if not lodged then return 0 end
    -- Kahlua does not expose Lua's global next(); probe with pairs.
    local any = false
    for _ in pairs(lodged) do any = true; break end
    if not any then return 0 end
    local count = 0
    for key, kind in pairs(lodged) do
        local bp = partByName(bd, key)
        if not (bp and partHasForeign(bp, kind)) then
            lodged[key] = nil
            print("[WTAGarou][Silver] silver " .. tostring(kind) .. " removed from " .. key)
            lodgedNotice(player, key, kind, false)
        else
            count = count + 1
            local bt = bp:getBurnTime() or 0
            local target = math.min(cfg("LODGED_MAX_BURN", S.LODGED_MAX_BURN), bt + cfg("LODGED_GROWTH_PER_SECOND", S.LODGED_GROWTH_PER_SECOND) * (dt or 0))
            if bt < 0.5 then target = math.max(target, 0.5) end     -- never goes out while the piece is in
            if target > bt then bp:setBurnTime(target) end
            d.silverBurns = d.silverBurns or {}
            d.silverBurns[key] = true
        end
    end
    local left = false
    for _ in pairs(lodged) do left = true; break end
    if not left then d.silverLodged = nil end
    return count
end

local function burnHit(target, bp, garou, ranged)
    if not bp then return end
    burnPart(target, bp, nil)
    -- 0.4.41: every silver hit on a Garou is a burn application; react
    -- (the client cue is rate-limited, so a volley growls once a second).
    if garou and target.getModData and bp.getType then
        pcall(function() announce(target, tostring(bp:getType())) end)
        -- 0.4.76: a silver round that stayed in burns until pulled.
        if ranged then pcall(S.markLodged, target, bp, "bullet") end
    end
end

function S.locatedBurnAvailable()
    return WTAGarouJava ~= nil and type(WTAGarouJava.takeWeaponHitPart) == "function"
end

function S.resolvePendingHits()
    if #pendingHits == 0 then return 0 end
    local queue = pendingHits; pendingHits = {}
    local burned = 0
    for _, hit in ipairs(queue) do
        local ok, index = pcall(WTAGarouJava.takeWeaponHitPart, hit.target, S.HIT_WINDOW_MS or 250)
        if ok and type(index) == "number" and index >= 0 then
            local bd = hit.target.getBodyDamage and hit.target:getBodyDamage() or nil
            local bp = bd and partByIndex(bd, index) or nil
            if bp then burnHit(hit.target, bp, hit.garou, hit.ranged); burned = burned + 1 end
        end
    end
    return burned
end
S.HIT_WINDOW_MS = 250

-- ---------------------------------------------------------------------------
-- 0.4.72: multiplayer relay. OnWeaponHitCharacter fires on the ATTACKER's
-- client, where another player is only a network proxy: burning its body
-- parts changes nothing on the real player and never reaches her screen
-- (Oct 18 hosted test: silver shells, no "burned by silver" on either
-- console). Players own their own BodyDamage in MP, so the hit is relayed:
-- attacker client -> SilverHit {target onlineID, damage} -> server checks
-- the attacker really holds/fires silver and the two are within reach ->
-- SilverHitRelay {damage} -> the struck player's client burns itself through
-- the same burnHit/announce path as single player.
-- ---------------------------------------------------------------------------
S.HIT_COMMAND = "SilverHit"
S.HIT_RELAY = "SilverHitRelay"
S.HIT_MAX_TILES = 40      -- server sanity: a shotgun/rifle hit is still a few tiles; 40 covers any firearm
local relayed = 0

local function remotePlayer(target)
    if not (isClient and isClient()) then return false end
    if not (target and target.isLocalPlayer and target.getOnlineID) then return false end
    local ok, loc = pcall(target.isLocalPlayer, target)
    return ok and loc == false
end
S.remotePlayer = remotePlayer

-- The struck player's own client (or single player / host for a local hit).
local function burnWeaponHit(target, damage, ranged)
    if not target.getBodyDamage then return end
    local bd = target:getBodyDamage(); if not bd then return end
    local parts = bd:getBodyParts(); if not parts or parts:size() == 0 then return end
    local garou = (WTAGarou.Adapters and WTAGarou.Adapters.isGarou and WTAGarou.Adapters.isGarou(target))
        or (target.getModData and target:getModData().WTAGarou) or false
    if S.locatedBurnAvailable() then
        pendingHits[#pendingHits + 1] = { target = target, garou = garou, ranged = ranged }
    else
        local bp = parts:get(ZombRand and ZombRand(parts:size()) or 0)
        burnHit(target, bp, garou, ranged)
    end
    -- Amplify the damage on Garou.
    if garou then
        if bd.setOverallBodyHealth and damage then
            local extra = damage * (cfg("DAMAGE_MULT", 2.0) - 1)
            bd:setOverallBodyHealth(math.max(0, bd:getOverallBodyHealth() - extra))
        end
    end
end
S.burnWeaponHit = burnWeaponHit

-- Struck player's client: a relayed silver hit. The engine's own hit packet
-- already made the wound; this burns it (random part: the Java recorder's
-- 250 ms window has usually passed by the time the relay lands).
function S.applyRelayedHit(player, args)
    if not player then return false end
    args = args or {}
    local located = S.locatedBurnAvailable
    S.locatedBurnAvailable = function() return false end
    local ok, err = pcall(burnWeaponHit, player, tonumber(args.damage) or 0)
    S.locatedBurnAvailable = located
    if not ok then print("[WTAGarou][Silver] relayed hit failed: " .. tostring(err)) end
    return ok
end

-- Server: validate and forward. `findPlayer` injectable for tests.
function S.onHitCommand(module, command, attacker, args, findPlayer)
    if module ~= "WTAGarou" or command ~= S.HIT_COMMAND then return false end
    if not (isServer and isServer()) then return false end
    -- 0.4.75: clients no longer send this (the server sees the hit itself);
    -- an old client's relay is still validated and forwarded as before.
    args = args or {}
    findPlayer = findPlayer or (getPlayerByOnlineID and function(id) return getPlayerByOnlineID(id) end)
    if not (attacker and findPlayer and args.target ~= nil) then return false end
    local weapon = attacker.getPrimaryHandItem and attacker:getPrimaryHandItem()
    if not (weapon and (itemIsSilver(weapon) or firesSilver(weapon))) then
        print("[WTAGarou][Silver] hit relay refused: attacker holds no silver")
        return false
    end
    local target = findPlayer(tonumber(args.target) or args.target)
    if not target or target == attacker then return false end
    if attacker.getX and target.getX then
        local dx, dy = attacker:getX() - target:getX(), attacker:getY() - target:getY()
        if dx * dx + dy * dy > S.HIT_MAX_TILES * S.HIT_MAX_TILES then
            print("[WTAGarou][Silver] hit relay refused: out of reach")
            return false
        end
    end
    relayed = relayed + 1
    local who = target.getUsername and target:getUsername() or "player"
    print(string.format("[WTAGarou][Silver] silver hit relayed to %s (damage %.2f)", tostring(who), tonumber(args.damage) or 0))
    WTAGarou.Net.ToClient(target, S.HIT_RELAY, { damage = tonumber(args.damage) or 0 })
    return true
end
function S.relayCount() return relayed end

-- ---------------------------------------------------------------------------
-- 0.4.75: multiplayer silver hits burn on the SERVER, on the wounded part.
-- Build 42 servers own every player's BodyDamage (BodyDamage.Update returns
-- on clients; the server applies the wound in hitConsequences and pushes
-- the whole body back every 2 s), so the 0.4.72 relay burned a random part
-- on the victim's client and the next push erased it ("silver burn in my
-- foot", "healed pretty quick"). OnWeaponHitCharacter fires on the server
-- too, BEFORE the wound lands: snapshot the target's parts, and on the next
-- tick burn every part that got hurt (health down or a new wound flag).
-- No part changed = the clothing took it = no burn (silver burns wounds).
-- ---------------------------------------------------------------------------
S.WOUND_FLAGS = { "scratched", "isCut", "isDeepWounded", "haveBullet", "bitten", "bleeding" }
local serverPending = {}

function S.snapshotParts(bd)
    local snap = {}
    pcall(function()
        local parts = bd:getBodyParts()
        for i = 0, parts:size() - 1 do
            local bp = parts:get(i)
            local e = { health = bp:getHealth() }
            for _, f in ipairs(S.WOUND_FLAGS) do
                local okf, v = pcall(function() return bp[f] and bp[f](bp) end)
                e[f] = okf and v == true or false
            end
            snap[i] = e
        end
    end)
    return snap
end

-- Pure: indexes of the parts the hit touched. `partsNow` is the same shape
-- as a snapshot.
function S.woundedParts(before, after)
    local hit = {}
    for i, now in pairs(after) do
        local was = before[i]
        if was then
            local changed = (now.health or 100) < (was.health or 100) - 0.01
            if not changed then
                for _, f in ipairs(S.WOUND_FLAGS) do
                    if now[f] and not was[f] then changed = true; break end
                end
            end
            if changed then hit[#hit + 1] = i end
        end
    end
    table.sort(hit)
    return hit
end

local function garouTarget(target)
    return (WTAGarou.Adapters and WTAGarou.Adapters.isGarou and WTAGarou.Adapters.isGarou(target))
        or (target.getModData and target:getModData().WTAGarou and target:getModData().WTAGarou.isGarou) or false
end

function S.serverQueueHit(target, damage, ranged)
    if not (target and target.getBodyDamage) then return false end
    local bd = target:getBodyDamage(); if not bd then return false end
    serverPending[#serverPending + 1] = { target = target, before = S.snapshotParts(bd), damage = tonumber(damage) or 0, ranged = ranged == true }
    return true
end

-- Server tick: resolve the hits queued last tick. `pushDamage` injectable
-- (defaults to the engine's sendDamage, which pushes the body at once).
function S.resolveServerHits(pushDamage)
    if #serverPending == 0 then return 0 end
    local queue = serverPending; serverPending = {}
    pushDamage = pushDamage or (sendDamage and function(pl) sendDamage(pl) end) or function() end
    local burned = 0
    for _, hit in ipairs(queue) do
        local target = hit.target
        local bd = target.getBodyDamage and target:getBodyDamage()
        if bd then
            local after = S.snapshotParts(bd)
            local indexes = S.woundedParts(hit.before, after)
            local garou = garouTarget(target)
            for _, i in ipairs(indexes) do
                local bp = partByIndex(bd, i)
                if bp then
                    burnHit(target, bp, garou, hit.ranged)
                    if garou and hit.damage > 0 then
                        local extra = hit.damage * (cfg("DAMAGE_MULT", 2.0) - 1)
                        pcall(function() bp:AddDamage(extra) end)
                    end
                    burned = burned + 1
                end
            end
            if #indexes == 0 then
                print("[WTAGarou][Silver] silver hit on " .. tostring(target.getUsername and target:getUsername() or "player") .. " wounded nothing (absorbed): no burn")
            else
                pcall(function() bd:calculateOverallHealth() end)
                pcall(pushDamage, target)
            end
        end
    end
    return burned
end
function S.serverPendingCount() return #serverPending end

if Events and Events.OnWeaponHitCharacter then
    Events.OnWeaponHitCharacter.Add(function(attacker, target, weapon, damage)
        if not (target and weapon) then return end
        -- 0.4.20: silver rounds burn like a silver blade.
        if not (itemIsSilver(weapon) or firesSilver(weapon)) then return end
        -- 0.4.59: a silver nitrate coat spends one charge per landed hit,
        -- zombie or Garou; the hit itself still counts as silver.
        S.spendCoatOnHit(attacker, weapon)
        -- 0.4.75: the server owns the body in multiplayer: burn there, on
        -- the part the wound lands on (next tick). The attacker's client
        -- only spends its coat charge for the HUD.
        if isServer and isServer() then
            if target.getOnlineID then S.serverQueueHit(target, damage, firesSilver(weapon)) end
            return
        end
        if remotePlayer(target) then return end
        burnWeaponHit(target, damage, firesSilver(weapon))
    end)
end
if Events and Events.OnClientCommand then
    Events.OnClientCommand.Add(function(module, command, player, args) S.onHitCommand(module, command, player, args) end)
end
if WTAGarou.Net and WTAGarou.Net.RegisterServerHandler then
    WTAGarou.Net.RegisterServerHandler(function(module, command, player, args) S.onHitCommand(module, command, player, args) end)
end

-- ---------------------------------------------------------------------------
-- Contact scan. OnPlayerUpdate in single player / hosted (the engine raises
-- it for local players); a dedicated server sweeps the online players from
-- OnTick, like the Rage engine.
-- ---------------------------------------------------------------------------
local lastScan = setmetatable({}, {__mode="k"})
local function scanPlayer(player)
    if not player or player:isDead() then return end
    local now = WTAGarou.NowSeconds and WTAGarou.NowSeconds() or os.time()
    local last = lastScan[player]
    if last and (now - last) < S.SCAN_SECONDS then return end
    local dt = last and math.min(5, now - last) or S.SCAN_SECONDS
    lastScan[player] = now
    local fresh = S.scan(player, dt)
    for _, name in ipairs(fresh) do announce(player, name) end
end
S.scanPlayer = scanPlayer

if Events then
    if Events.OnPlayerUpdate then
        Events.OnPlayerUpdate.Add(function(player)
            if isServer and isServer() then return end
            -- 0.4.75: a multiplayer client's body is overwritten by the
            -- server every 2 s; the server's own sweep below does the scan.
            if isClient and isClient() then return end
            scanPlayer(player)
        end)
    end
    if Events.OnTick then
        Events.OnTick.Add(function()
            S.resolvePendingHits()
            if not (isServer and isServer()) then return end
            S.resolveServerHits()
            if not getOnlinePlayers then return end
            local players = getOnlinePlayers()
            if not players then return end
            for i = 0, players:size() - 1 do scanPlayer(players:get(i)) end
        end)
    end
end
