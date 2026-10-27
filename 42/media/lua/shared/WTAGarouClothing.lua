--[[
    WTAGarou - Clothing rules (v0.4.19)

    Two independent things happen with clothing:

    1. When a shift completes, worn clothing is handled by the destination
       form's profile in WTAGarou.ShiftStrip.FORMS (0.4.15):
         Glabro  -> nothing comes off, nothing damaged (0.4.82; was a 0.1-point strain)
         Lupus   -> small damage + 1 hole, dropped at the Garou's feet
         Hispo   -> moderate damage + 2 holes, dropped
         Crinos  -> heavy damage (1.5x Hispo) + 3 holes, dropped
       Damage is a whole number of condition points derived from a T-shirt
       (engine default ConditionMax 10), never a share of the item's own
       maximum. Headwear and masks (ShiftStrip.NO_DAMAGE_LOCATIONS) are
       never damaged; head-only locations stay on in Crinos but still drop
       in Lupus/Hispo. Exempt from everything:
         - any worn container (backpacks, duffel bags, sheet slings, fanny
           packs, holsters that are containers, wolf saddlebags ...),
         - jewelry, glasses, belts, ammo straps, webbing and other gear
           straps (WTAGarou.ShiftStrip.SAFE_LOCATIONS),
         - anything held in the primary/secondary hand,
         - anything merely carried in the inventory.

    2. After the shift, WTAGarou.CanWear(form, item) governs whether the
       Garou can re-equip a given item. Any container a human can wear, a
       wolf can wear too. Unknown locations are allowed.

    Build 42 note: InventoryItem:getBodyLocation() returns an
    ItemBodyLocation OBJECT whose tostring is a namespaced id such as
    "base:Torso1". Earlier versions indexed a string table with that object,
    which never matched, so nothing was ever stripped. Everything below goes
    through WTAGarou.Clothing.locationId(), which yields the bare "Torso1".

    0.4.19: the bare ids the engine hands back are LOWER CASE ("ears",
    "rightwrist", "necklace_long", "knee_right", "wound"), not the B41
    CamelCase the tables below were written in. Every table lookup now goes
    through WTAGarou.Clothing.lookup(), which matches case-insensitively, so
    jewelry, watches, belts and the wound/bandage pseudo-items are exempt
    again and the Silver contact map finds its body parts (0.4.18 playtest:
    earrings dropped on a Crinos shift, silver never burned).
]]

WTAGarou = WTAGarou or {}
require "WTAGarouAudio"
WTAGarou.Clothing = WTAGarou.Clothing or {}

-- Case-insensitive table lookup keyed by body-location id. Lowered copies
-- are cached per table (weak keys) so the hot paths stay cheap.
local loweredCache = setmetatable({}, { __mode = "k" })
function WTAGarou.Clothing.lookup(tbl, loc)
    if type(tbl) ~= "table" or loc == nil then return nil end
    local direct = tbl[loc]
    if direct ~= nil then return direct end
    local key = tostring(loc):lower()
    local lowered = loweredCache[tbl]
    if not lowered then
        lowered = {}
        for k, v in pairs(tbl) do lowered[tostring(k):lower()] = v end
        loweredCache[tbl] = lowered
    end
    return lowered[key]
end

-- Map PZ body-location ids to our allowedClothing categories.
local LOC_TO_CATEGORY = {
    -- Torso / shirts / jackets (all treated as "Shirt" for allowed-set lookup)
    Torso1        = "Shirt",  TorsoExtra    = "Shirt",  Tshirt = "Shirt",
    Shirt         = "Shirt",  Sweater       = "Shirt",  Jacket = "Shirt",
    Jacket_Bulky  = "Shirt",  Jacket_Down   = "Shirt",  JacketHat_Bulky = "Shirt",
    JacketHat     = "Shirt",  JacketSuit    = "Shirt",  ShortSleeveShirt = "Shirt",
    TorsoExtraVest = "Shirt", TorsoExtraVestBullet = "Shirt", Dress = "Shirt",
    LongDress     = "Shirt",  BathRobe      = "Shirt",  FullRobe = "Shirt",
    FullSuit      = "Shirt",  FullSuitHead  = "Shirt",  FullSuitHeadSCBA = "Shirt",
    Boilersuit    = "Shirt",  FullTop       = "Shirt",  Torso1Legs1 = "Shirt",
    TankTop       = "Shirt",  Jersey        = "Shirt",  BodyCostume = "Shirt",
    Cuirass       = "Shirt",  Gorget        = "Shirt",
    -- Pants
    Pants         = "Pants",  ShortPants    = "Pants",  Skirt  = "Pants",
    LongSkirt     = "Pants",  ShortsShort   = "Pants",  Pants_Skinny = "Pants",
    Legs1         = "Pants",  Legs5         = "Pants",  PantsExtra = "Pants",
    UnderwearBottom = "Pants", Codpiece     = "Pants",
    -- Shoes
    Shoes         = "Shoes",  Socks         = "Shoes",
    -- Gloves
    Hands         = "Gloves", HandsLeft     = "Gloves", HandsRight = "Gloves",
    -- Hats
    Hat           = "Hat",    FullHat       = "Hat",    MaskEyes = "Hat",
    SweaterHat    = "Hat",
    -- Always-allowed slots
    Belt          = "Belt",   BeltExtra     = "Belt",   AmmoStrap = "Belt",
    Webbing       = "Belt",   AnkleHolster  = "Belt",   ShoulderHolster = "Belt",
    Back          = "Backpack", Satchel     = "Backpack",
    FannyPackFront = "Backpack", FannyPackBack = "Backpack", saddlebag = "Backpack",
    Neck          = "Neck",   Scarf         = "Neck",
    Necklace      = "Neck",   Necklace_Long = "Neck",
    Bandana       = "Bandana", MaskFull     = "Bandana",
    -- Extras
    Mask          = "Mask",
    Underwear     = "Underwear", UnderwearTop = "Underwear", UnderwearExtra1 = "Underwear",
    UnderwearExtra2 = "Underwear",
}

-- Bare body-location id for an item ("Torso1"), or nil.
function WTAGarou.Clothing.locationId(item)
    if not item or not item.getBodyLocation then return nil end
    local ok, loc = pcall(function() return item:getBodyLocation() end)
    if not ok or loc == nil then return nil end
    local s
    if type(loc) == "string" then
        s = loc
    else
        local okId, id = pcall(function()
            if loc.getId then return loc:getId() end
            return nil
        end)
        s = (okId and id) or tostring(loc)
    end
    if not s or s == "" or s == "nil" then return nil end
    s = tostring(s)
    -- Strip a "base:" / "wtagarou:" style namespace.
    local bare = s:match("^[%w_]+:(.+)$")
    return bare or s
end

local function categoryFor(item)
    local loc = WTAGarou.Clothing.locationId(item)
    if not loc then return nil end
    return WTAGarou.Clothing.lookup(LOC_TO_CATEGORY, loc)
end
WTAGarou.Clothing.categoryFor = categoryFor

-- Worn containers (bags, slings, holsters that are containers) are gear,
-- never clothing to rip.
function WTAGarou.Clothing.isContainer(item)
    if not item then return false end
    local ok, res = pcall(function()
        if item.getCategory and item:getCategory() == "Container" then return true end
        if instanceof and instanceof(item, "InventoryContainer") then return true end
        if item.getItemContainer and item:getItemContainer() ~= nil then return true end
        return false
    end)
    return ok and res == true
end

-- Public: is this worn item exempt from the shift strip?
-- 0.4.20: anything that PROVIDES attachment slots (belts, holsters, webbing,
-- vests with hotbar points) is gear, not clothing: ripping it would dump every
-- attached weapon and make re-attaching them tedious after each shift.
function WTAGarou.Clothing.providesAttachments(item)
    if not item or not item.getAttachmentsProvided then return false end
    local ok, list = pcall(function() return item:getAttachmentsProvided() end)
    if not ok or list == nil then return false end
    local okSize, size = pcall(function() return list:size() end)
    if okSize and type(size) == "number" then return size > 0 end
    if type(list) == "table" then return #list > 0 end
    return false
end

function WTAGarou.Clothing.isShiftSafe(item)
    if not item then return true end
    if WTAGarou.Clothing.isContainer(item) then return true end
    if WTAGarou.Clothing.providesAttachments(item) then return true end
    local loc = WTAGarou.Clothing.locationId(item)
    if not loc then return true end   -- no body location: not clothing
    local safe = (WTAGarou.ShiftStrip and WTAGarou.ShiftStrip.SAFE_LOCATIONS) or {}
    if WTAGarou.Clothing.lookup(safe, loc) == true then return true end
    -- Anything with a real body location that is not exempt rips.
    return false
end

-- Public: can `formName` re-equip `item` after the shift completes?
-- 0.4.22 (user rule, September 27): every form can wear anything. "Any form
-- can wear clothes again, there's just not much point for the beast forms."
-- The shift-damage rules are the only discouragement; the per-form
-- allowedClothing tables stay in Definitions as documentation of what USED
-- to be blocked and are no longer consulted here.
WTAGarou.WEAR_BLACKLIST_ENABLED = false
function WTAGarou.CanWear(formName, item)
    if not formName or not item then return false end
    if WTAGarou.Clothing.isContainer(item) then return true end
    if WTAGarou.WEAR_BLACKLIST_ENABLED ~= true then return true end
    local cat = categoryFor(item)
    if not cat then return true end
    local form = WTAGarou.GetForm(formName)
    local rules = (form and form.allowedClothing) or {}
    return rules[cat] == true
end

-- Held items are never touched by the strip.
local function isHeld(player, item)
    if not (player and item) then return false end
    local ok, held = pcall(function()
        return (player.getPrimaryHandItem and player:getPrimaryHandItem() == item)
            or (player.getSecondaryHandItem and player:getSecondaryHandItem() == item)
    end)
    return ok and held == true
end

-- Public: the worn items a shift to a stripping form would tear off right
-- now (worn, not held in a hand, not shift-safe). Outermost worn item first,
-- so a manual strip peels layers in a sensible order.
function WTAGarou.Clothing.stripCandidates(player)
    local list = {}
    if not player then return list end
    local ok, worn = pcall(function() return player:getWornItems() end)
    if not ok or not worn then return list end
    for i = worn:size() - 1, 0, -1 do
        local w = worn:get(i)
        local item = w and w:getItem() or nil
        if item and not isHeld(player, item) and not WTAGarou.Clothing.isShiftSafe(item) then
            table.insert(list, item)
        end
    end
    return list
end

-- Headwear / masks: never damaged; Crinos retention is handled below.
function WTAGarou.Clothing.isDamageExempt(item)
    local loc = WTAGarou.Clothing.locationId(item)
    if not loc then return true end
    local nd = (WTAGarou.ShiftStrip and WTAGarou.ShiftStrip.NO_DAMAGE_LOCATIONS) or {}
    return WTAGarou.Clothing.lookup(nd, loc) == true
end

-- Take `points` of condition and tear `holes` into covered parts.
-- Fractions of a point accumulate on the item (mod data WEAR_KEY) and turn
-- into a real point when they reach 1. Returns the whole points applied.
-- 0.4.66: on a server the condition change is pushed with sendItemStats
-- (the server owns MP inventories; see dropForbidden for the holes).
local function onServer()
    return type(isServer) == "function" and isServer() == true
end
WTAGarou.Clothing.onServer = onServer

local function damageItem(item, points, holes)
    if not item or (points <= 0 and holes <= 0) then return 0 end
    local applied = 0
    if points > 0 then
        pcall(function()
            local whole = math.floor(points)
            local frac = points - whole
            if frac > 0 and item.getModData then
                local key = WTAGarou.ShiftStrip.WEAR_KEY or "WTAGarou_Wear"
                local md = item:getModData()
                local acc = (tonumber(md[key]) or 0) + frac
                if acc >= 0.9995 then whole = whole + 1; acc = acc - 1 end
                md[key] = math.max(0, math.floor(acc * 1000 + 0.5) / 1000)
            end
            if whole > 0 and item.setCondition and item.getCondition then
                local cond = item:getCondition()
                item:setCondition(math.max(1, cond - whole))
                applied = whole
                if onServer() and type(sendItemStats) == "function" then pcall(sendItemStats, item) end
            end
        end)
    end
    if holes > 0 then
        pcall(function()
            if item.getCoveredParts and item.getVisual then
                local parts = item:getCoveredParts()
                local visual = item:getVisual()
                if parts and visual and visual.setHole and parts:size() > 0 then
                    local n = math.min(holes, parts:size())
                    for i = 0, n - 1 do
                        local idx = (ZombRand and parts:size() > n) and ZombRand(parts:size()) or i
                        visual:setHole(parts:get(idx))
                    end
                end
            end
        end)
    end
    return applied
end

-- Unequip the item and drop it at the Garou's feet.
-- 0.4.66: on a server this follows vanilla ISDropWorldItemAction.complete
-- (remove + sendRemoveItemFromContainer, world item transmitted to clients);
-- in single player it stays the direct path. A remote client never calls
-- this any more: the server strips and tells it (TransformCompleted.strip).
local function dropItem(player, item)
    local dropped = false
    pcall(function()
        local server = onServer()
        player:removeWornItem(item)
        if server then
            if item == player:getPrimaryHandItem() then player:setPrimaryHandItem(nil) end
            if item == player:getSecondaryHandItem() then player:setSecondaryHandItem(nil) end
            if type(sendEquip) == "function" then pcall(sendEquip, player) end
        end
        local inv = player:getInventory()
        local sq = player:getCurrentSquare()
        if sq then
            local ox = ZombRand and (ZombRand(60) / 100 + 0.2) or 0.5
            local oy = ZombRand and (ZombRand(60) / 100 + 0.2) or 0.5
            local worldItem = sq:AddWorldInventoryItem(item, ox, oy, 0, false)
            if server and worldItem and worldItem.getWorldItem then
                local w = worldItem:getWorldItem()
                if w and w.transmitCompleteItemToClients then pcall(function() w:transmitCompleteItemToClients() end) end
            end
            dropped = true
        end
        if inv and inv.Remove then inv:Remove(item) end
        if server and type(sendRemoveItemFromContainer) == "function" then
            pcall(sendRemoveItemFromContainer, inv, item)
        end
    end)
    return dropped
end

-- Apply a form's clothing profile to one worn item. Returns
-- "dropped" | "damaged" | nil, plus whether anything visibly tore (whole
-- points or holes) for the rip sound.
local function applyProfile(player, item, formName, opts)
    if not (player and item) then return nil, false end
    local prof = WTAGarou.ShiftStrip.profileFor and WTAGarou.ShiftStrip.profileFor(formName)
    if not prof then return nil, false end
    if formName == "Crinos" and WTAGarou.Clothing.lookup(
            WTAGarou.ShiftStrip.CRINOS_KEEP_LOCATIONS or {},
            WTAGarou.Clothing.locationId(item)) == true then
        return nil, false
    end
    local exempt = WTAGarou.Clothing.isDamageExempt(item)
    local points = exempt and 0 or WTAGarou.ShiftStrip.damageFor(formName, opts)
    local holes = exempt and 0 or (prof.holes or 0)
    local applied = damageItem(item, points, holes)
    local tore = applied > 0 or holes > 0
    if prof.drop then
        if WTAGarou.Wardrobe and WTAGarou.Wardrobe.record then
            WTAGarou.Wardrobe.record(player, item, "shift")
        end
        return dropItem(player, item) and "dropped" or nil, tore
    end
    return (points > 0 or holes > 0) and "damaged" or nil, tore
end
WTAGarou.Clothing.applyProfile = applyProfile

-- Back-compat name (0.4.11-0.4.14): damage + drop as Hispo does.
function WTAGarou.Clothing.damageAndDrop(player, item)
    return (applyProfile(player, item, "Hispo")) == "dropped"
end

-- 0.4.17: ClothesRipping is the vanilla CRAFTING clip (the recipe stops it
-- when the craft ends), so a bare playSound left it running and every shift
-- stacked another copy. Keep the emitter handle and stop it RIP_SECONDS
-- later from OnTick; stop by name as well in case the handle is stale.
local pendingRips = {}
local ripTickHooked = false
local function nowSeconds()
    if getTimestampMs then return getTimestampMs() / 1000 end
    return os.time()
end
local function stopRip(entry)
    pcall(function()
        local emitter = entry.emitter
        if emitter then
            if entry.handle then emitter:stopSound(entry.handle) end
            if emitter.stopSoundByName then emitter:stopSoundByName(entry.name) end
        end
    end)
end
local function onRipTick()
    if #pendingRips == 0 then return end
    local now = nowSeconds()
    for i = #pendingRips, 1, -1 do
        if now >= pendingRips[i].stopAt then
            stopRip(pendingRips[i])
            table.remove(pendingRips, i)
        end
    end
end
local function hookRipTick()
    if ripTickHooked then return end
    ripTickHooked = true
    if Events and Events.OnTick and Events.OnTick.Add then Events.OnTick.Add(onRipTick) end
end
WTAGarou.Clothing.onRipTick = onRipTick
WTAGarou.Clothing.pendingRips = pendingRips

local function playRip(player)
    local name = WTAGarou.ShiftStrip.RIP_SOUND
    if not name or name == "" then return false end
    -- 0.4.40: scaled by the Sound Effects slider and capped (WTAGarou.Audio).
    local handle, emitter = WTAGarou.Audio.play(player, name)
    local ok = handle ~= nil or emitter ~= nil
    if ok then
        local secs = tonumber(WTAGarou.ShiftStrip.RIP_SECONDS) or 1.2
        table.insert(pendingRips, { emitter = emitter, handle = handle, name = name,
            stopAt = nowSeconds() + secs })
        hookRipTick()
    end
    return ok
end
WTAGarou.Clothing.playRip = playRip

-- Called client-side after TransformCompleted. Applies the destination
-- form's profile to every tearable worn item (see stripCandidates). Homid
-- has no profile and leaves worn items intact. Returns the number of items
-- DROPPED (Glabro damages without dropping and so returns 0), and reports
-- both counts to the test panel. opts.forced marks a Rage-forced shift
-- (double Crinos points, same holes). Plays the vanilla ClothesRipping clip
-- once when anything actually tore.
--
-- Because the check is on the DESTINATION form, chains like
-- Homid -> Lupus -> Crinos -> Homid can pick items back up between shifts
-- and only trigger a strip on the specific hops that shift TO a dropping
-- form while non-safe items are worn.
function WTAGarou.Clothing.dropForbidden(player, formName, opts)
    if not player then return 0 end
    if not (WTAGarou.ShiftStrip.profileFor and WTAGarou.ShiftStrip.profileFor(formName)) then return 0 end
    local candidates = WTAGarou.Clothing.stripCandidates(player)
    local dropped, damaged, tore = 0, 0, false
    local dropLog = {}
    for _, item in ipairs(candidates) do
        local r, t = applyProfile(player, item, formName, opts)
        if t then tore = true end
        if r == "dropped" then dropped = dropped + 1
        elseif r == "damaged" then damaged = damaged + 1 end
        if r then
            dropLog[#dropLog + 1] = tostring(WTAGarou.Clothing.locationId(item)) .. ":"
                .. tostring(item.getFullType and item:getFullType() or "?") .. "=" .. r
        end
    end
    -- 0.4.17: name every item the shift touched, with its body location, so a
    -- playtest console shows whether the mod or the engine (helmetFall /
    -- ChanceToFall) dropped a piece.
    if #dropLog > 0 then
        print("[WTAGarou][Strip] shift to " .. tostring(formName) .. ": " .. table.concat(dropLog, ", "))
    end
    local prof = WTAGarou.ShiftStrip.profileFor(formName)
    local modelChanged = dropped > 0 or (damaged > 0 and (prof.holes or 0) > 0)
    if onServer() then
        -- 0.4.66: the server strips for a hosted game. Push the torn visuals
        -- and leave sound/notices to the client (TransformCompleted.strip).
        if modelChanged and type(syncVisuals) == "function" then pcall(syncVisuals, player) end
        return dropped, damaged, tore
    end
    WTAGarou.Clothing.presentStrip(player, { dropped = dropped, damaged = damaged, tore = tore,
        modelChanged = modelChanged, forced = opts and opts.forced == true })
    return dropped, damaged, tore
end

-- Client-side presentation of a strip: rip sound, model reset, test-panel
-- line. Single player calls it from dropForbidden; a remote client calls it
-- with the `strip` table the server attached to TransformCompleted.
function WTAGarou.Clothing.presentStrip(player, strip)
    if not (player and strip) then return false end
    local dropped = tonumber(strip.dropped) or 0
    local damaged = tonumber(strip.damaged) or 0
    if type(strip.wardrobe) == "table" and WTAGarou.Wardrobe and WTAGarou.Wardrobe.recordEntries then
        WTAGarou.Wardrobe.recordEntries(player, strip.wardrobe)
    end
    if strip.tore then playRip(player) end
    if dropped > 0 or damaged > 0 then
        if strip.modelChanged then
            -- only holes and removed layers change the model; a Glabro
            -- seam strain is condition-only
            pcall(function()
                if player.resetModelNextFrame then player:resetModelNextFrame() end
            end)
        end
        if WTAGarou.TestPanel and WTAGarou.TestPanel.notify then
            if dropped > 0 then
                WTAGarou.TestPanel.notify("Shift tore off " .. dropped .. " worn item(s)"
                    .. (strip.forced and " (forced: double damage)" or ""))
            else
                WTAGarou.TestPanel.notify("Shift strained " .. damaged .. " worn item(s)")
            end
        end
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Re-equip guard: block ISWearClothing from succeeding on items the current
-- form is not allowed to wear. Hooks the vanilla wear-clothing action.
-- ---------------------------------------------------------------------------
Events.OnGameStart.Add(function()
    if not ISWearClothing then return end
    local orig = ISWearClothing.isValid
    ISWearClothing.isValid = function(self)
        local ok = orig(self)
        if not ok then return false end
        local player = self.character
        if not player then return ok end
        local d = WTAGarou.GetData(player)
        if not d or not d.form then return ok end
        if WTAGarou.CanWear(d.form, self.item) then return ok end
        -- Silent block; the context-menu greying is handled elsewhere.
        return false
    end
end)
