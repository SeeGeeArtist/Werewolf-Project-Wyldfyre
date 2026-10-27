-- 0.4.11 regression test: shift strip with Build 42 body-location objects,
-- per-form stealth/voice registration, wolf body sounds, saddlebag visual.
-- Lua 5.1 mocks shaped like the engine; tests our flow, not the game.
local root = assert(arg[1], "supply WTAGarou directory")
package.path = root .. "/42/media/lua/shared/?.lua;" .. root .. "/42/media/lua/client/?.lua;" .. package.path
local checks = 0
local function check(ok, message) checks = checks + 1; if not ok then error("FAIL: " .. message, 2) end end

-- ---------------------------------------------------------------- mocks ----
Events = setmetatable({}, { __index = function(t, k)
    t[k] = { handlers = {}, Add = function(fn) table.insert(t[k].handlers, fn) end }
    return t[k]
end })
isClient = function() return false end
isServer = function() return false end
ZombRand = function(n) return 0 end
local clock = 100
getTimestampMs = function() return clock * 1000 end
getTimestamp = function() return math.floor(clock) end
instanceof = function(obj, cls) return obj and obj.__class == cls end
CharacterTrait = { register = function(id) return id end }
local registeredTags = {}
ItemTag = {
    register = function(id) assert(not registeredTags[id], "duplicate tag " .. id); registeredTags[id] = id; return id end,
    get = function(loc) return registeredTags[loc] end,
}
ResourceLocation = { of = function(id) return id end }
ItemBodyLocation = { register = function(id) return { id = id } end }
BodyLocations = { getGroup = function() return { getOrCreateLocation = function() end } end }
ISWearClothing = { isValid = function() return true end }

-- Build 42: getBodyLocation() returns an object whose tostring is namespaced.
local function bodyLocation(id)
    return setmetatable({}, { __tostring = function() return "base:" .. id end })
end
local nextId = 0
local function item(loc, opts)
    opts = opts or {}
    nextId = nextId + 1
    local it = { id = nextId, loc = loc, condition = opts.condition or 10, max = opts.max or 10,
        holes = {}, __class = opts.container and "InventoryContainer" or "Clothing",
        parts = opts.parts or { "Torso_Upper", "Torso_Lower" } }
    function it:getBodyLocation() if self.loc then return bodyLocation(self.loc) end return nil end
    function it:getCategory() return self.__class == "InventoryContainer" and "Container" or "Clothing" end
    function it:getCondition() return self.condition end
    function it:getConditionMax() return self.max end
    function it:setCondition(v) self.condition = v end
    function it:getCoveredParts()
        local p = self.parts
        return { size = function() return #p end, get = function(_, i) return p[i + 1] end }
    end
    function it:getVisual()
        local holes = self.holes
        return { setHole = function(_, part) table.insert(holes, part) end }
    end
    it.md = {}
    function it:getModData() return self.md end
    function it:getID() return self.id end
    function it:getDisplayName() return opts.name or (tostring(loc) .. "#" .. tostring(self.id)) end
    function it:getName() return self:getDisplayName() end
    function it:getFullType() return "Base." .. tostring(loc) end
    function it:isBroken() return self.broken == true end
    function it:getContainer() return self.container_ end
    if opts.container then it.contents = {} end
    return it
end

local function newPlayer(form)
    local p = { md = { WTAGarou = { form = form or "Homid", isGarou = true } }, worn = {}, world = {},
        inventory = {}, primary = nil, secondary = nil, resets = 0, sounds = {}, attached = {},
        moving = false, dead = false, local_ = true }
    function p:getModData() return self.md end
    function p:isDead() return self.dead end
    function p:isLocalPlayer() return self.local_ end
    function p:isFemale() return false end
    function p:getOnlineID() return -1 end
    function p:getHumanVisual() return nil end
    function p:getPrimaryHandItem() return self.primary end
    function p:getSecondaryHandItem() return self.secondary end
    function p:getWornItems()
        local worn = self.worn
        return { size = function() return #worn end,
                 get = function(_, i) local it = worn[i + 1]; return { getItem = function() return it end } end }
    end
    function p:removeWornItem(it)
        for i, w in ipairs(self.worn) do if w == it then table.remove(self.worn, i); return end end
    end
    function p:getInventory()
        if self.invObj then return self.invObj end
        local inv = self.inventory
        local obj = {}
        function obj.Remove(_, it) inv[it] = nil end
        function obj.getItemWithIDRecursiv(_, id)
            for it in pairs(inv) do
                if it.id == id then return it end
                if it.contents then for _, c in ipairs(it.contents) do if c.id == id then return c end end end
            end
            return nil
        end
        self.invObj = obj
        return obj
    end
    function p:isEquippedClothing(it)
        for _, w in ipairs(self.worn) do if w == it then return true end end
        return false
    end
    function p:getCurrentSquare()
        local world = self.world
        return { AddWorldInventoryItem = function(_, it, x, y, z) table.insert(world, { it, x, y, z }) end }
    end
    function p:resetModelNextFrame() self.resets = self.resets + 1 end
    function p:playSound(name) table.insert(self.sounds, name) end
    function p:isMoving() return self.moving end
    function p:setAttachedItem(loc, it) self.attached[loc] = it end
    function p:getAttachedItems()
        local att = self.attached
        local list = {}
        for loc, it in pairs(att) do table.insert(list, { loc = loc, it = it }) end
        table.sort(list, function(a, b) return a.loc < b.loc end)
        return { getItem = function(_, loc)
            if not (WTAGarou.AttachedLocationsReady and WTAGarou.AttachedLocationsReady[loc]) then
                error('no such location "' .. tostring(loc) .. '"')   -- AttachedLocationGroup.checkValid
            end
            return att[loc] end,
            size = function() return #list end,
            get = function(_, i) local e = list[i + 1]
                return e and { getLocation = function() return e.loc end, getItem = function() return e.it end } or nil end,
            -- 0.4.23: the Human group resolves hotbar location ids to engine attachment names
            getGroup = function() return { getLocation = function(_, id)
                local names = { ["Back"] = "back_hotbar", ["Belt Left"] = "belt_left_hotbar",
                    ["Custom Tool Left"]="customtool_left" }
                return names[id] and { getAttachmentName = function() return names[id] end } or nil end } end }
    end
    function p:getSecondaryHandItem() return self.secondary end
    function p:getPrimaryHandItem() return self.primary end
    return p
end

WTAGarou = WTAGarou or {}
dofile(root .. "/42/media/registries.lua")
dofile(root .. "/42/media/lua/shared/WTAGarouDefinitions.lua")
dofile(root .. "/42/media/lua/shared/WTAGarouState.lua")
dofile(root .. "/42/media/lua/shared/WTAGarouClothing.lua")
dofile(root .. "/42/media/lua/shared/WTAGarouWardrobe.lua")
for _, h in ipairs(Events.OnGameStart.handlers) do h() end

-- ------------------------------------------------------- location parsing --
local C = WTAGarou.Clothing
check(C.locationId(item("Torso1")) == "Torso1", "namespaced object -> bare id")
check(C.locationId(item(nil)) == nil, "no location -> nil")
check(C.locationId({ getBodyLocation = function() return "Pants" end }) == "Pants", "plain string still works")
check(C.locationId({ getBodyLocation = function() return "wtagarou:saddlebag" end }) == "saddlebag", "mod namespace stripped")

-- ------------------------------------------------------------ safe rules --
check(C.isShiftSafe(item("Back", { container = true })), "worn backpack safe (container)")
check(C.isShiftSafe(item("Torso1", { container = true })), "sheet sling on a torso slot safe (container)")
check(C.isShiftSafe(item("Necklace")), "necklace safe")
check(C.isShiftSafe(item("Belt")), "belt safe")
check(C.isShiftSafe(item("Ears")), "earrings safe")
check(C.isShiftSafe(item("Eyes")), "glasses safe")
check(not C.isShiftSafe(item("Torso1")), "shirt rips")
check(not C.isShiftSafe(item("Pants")), "pants rip")
check(not C.isShiftSafe(item("Shoes")), "shoes rip")
check(not C.isShiftSafe(item("Hat")), "hat rips")
check(not C.isShiftSafe(item("Hands")), "gloves rip")
check(not C.isShiftSafe(item("Neck")), "scarf rips")
check(not C.isShiftSafe(item("Jacket_Bulky")), "bulky jacket rips")
-- 0.4.20: anything providing attachment slots is gear (belt, holster, vest with hotbar points).
local vest = item("TorsoExtraVest")
vest.getAttachmentsProvided = function() return { size = function() return 2 end } end
check(C.providesAttachments(vest) and C.isShiftSafe(vest), "a vest that provides attachment slots is shift-safe")
local plainVest = item("TorsoExtraVest")
plainVest.getAttachmentsProvided = function() return { size = function() return 0 end } end
check(not C.providesAttachments(plainVest) and not C.isShiftSafe(plainVest), "a vest with no attachment slots still rips")
check(not C.providesAttachments(item("Torso1")), "no accessor: not an attachment provider")

-- ------------------------------------------------------------- CanWear --
check(WTAGarou.CanWear("Lupus", item("Back", { container = true })), "Lupus can wear a backpack")
check(WTAGarou.CanWear("Lupus", item("Torso1", { container = true })), "Lupus can wear any wearable container")
check(WTAGarou.CanWear("Hispo", item("Belt")), "Hispo can wear a belt")
-- 0.4.22: the wear blacklist is off; every form can put anything back on.
check(WTAGarou.WEAR_BLACKLIST_ENABLED == false, "wear blacklist disabled by default")
check(WTAGarou.CanWear("Lupus", item("Torso1")), "Lupus may put a shirt on (0.4.22)")
check(WTAGarou.CanWear("Lupus", item("Shoes")), "Lupus may wear shoes (0.4.22)")
check(WTAGarou.CanWear("Crinos", item("Torso1")), "Crinos can put a shirt back on")
check(WTAGarou.CanWear("Glabro", item("Shoes")), "Glabro wears shoes (0.4.22)")
check(WTAGarou.CanWear("Crinos", item("Shoes")), "Crinos may wear shoes (0.4.22)")
WTAGarou.WEAR_BLACKLIST_ENABLED = true
check(not WTAGarou.CanWear("Lupus", item("Shoes")), "blacklist still works when switched on")
WTAGarou.WEAR_BLACKLIST_ENABLED = false
check(WTAGarou.CanWear("Homid", item("Shoes")), "Homid wears shoes")
check(WTAGarou.CanWear("Lupus", item("Necklace")), "unknown-category jewelry allowed")

-- ------------------------------------------------------------- the strip --
-- 0.4.15/0.4.16 profiles: damage is points off a T-shirt yardstick (10).
local SS = WTAGarou.ShiftStrip
check(SS.TSHIRT_CONDITION == 10, "T-shirt yardstick is the engine default ConditionMax 10")
check(SS.damageFor("Glabro") == 0, "0.4.82: Glabro wears nothing (fraction 0): " .. tostring(SS.damageFor("Glabro")))
check(SS.damageFor("Lupus") == 1, "Lupus takes 1 point (10%)")
check(SS.damageFor("Hispo") == 3, "Hispo takes 3 points (25% of 10, rounded)")
check(SS.damageFor("Crinos") == 4, "Crinos takes 4 points (1.5x Hispo's 2.5 = 3.75, rounded)")
check(SS.damageFor("Crinos", { forced = true }) == 8, "a Rage-forced Crinos takes double: 8")
check(SS.damageFor("Hispo", { forced = true }) == 3, "forced multiplier is Crinos-only")
check(SS.damageFor("Homid") == 0 and SS.profileFor("Homid") == nil, "Homid has no clothing profile")
check(SS.profileFor("Glabro").drop == false and SS.profileFor("Lupus").drop and SS.profileFor("Hispo").drop
    and SS.profileFor("Crinos").drop, "only Lupus/Hispo/Crinos drop")
check(SS.profileFor("Glabro").holes == 0 and SS.profileFor("Lupus").holes == 1 and SS.profileFor("Hispo").holes == 2
    and SS.profileFor("Crinos").holes == 3, "holes: 0 / 1 / 2 / 3")
check(SS.RIP_SOUND == "ClothesRipping", "rip clip is the vanilla ClothesRipping SoundKey")
for _, loc in ipairs({ "Hat", "FullHat", "SweaterHat", "Bandana", "Mask", "MaskEyes", "MaskFull" }) do
    check(C.isDamageExempt(item(loc)), loc .. " is never damaged")
    check(not C.isShiftSafe(item(loc)), loc .. " still drops")
end
check(not C.isDamageExempt(item("Torso1")) and not C.isDamageExempt(item("Neck")), "shirts and scarves take damage")

local p = newPlayer("Homid")
local shirt, pants, shoes = item("Torso1", { condition = 10, max = 10 }), item("Pants", { condition = 8, max = 12 }), item("Shoes")
local jacket = item("Jacket", { condition = 10, max = 10 })
local hat = item("Hat", { condition = 10, max = 10 })
local bag, sling, ring, belt = item("Back", { container = true }), item("Torso1", { container = true }), item("Right_RingFinger"), item("Belt")
local heldHat = item("Hat")
local carriedJacket = item("Jacket")
p.worn = { shirt, pants, shoes, jacket, hat, bag, sling, ring, belt, heldHat }
p.primary = heldHat
p.inventory[carriedJacket] = true

check(C.dropForbidden(p, "Homid") == 0, "shift to Homid touches nothing")
check(shirt.condition == 10 and #p.world == 0, "Homid: no damage, no drops")

-- Glabro: sub-point wear only
check(C.dropForbidden(p, "Glabro") == 0, "Glabro drops nothing")
check(#p.worn == 10 and #p.world == 0, "Glabro: everything still worn")
check(shirt.condition == 10 and pants.condition == 8 and jacket.condition == 10, "Glabro: no condition lost")
check(shirt.md.WTAGarou_Wear == nil and hat.md.WTAGarou_Wear == nil, "0.4.82: Glabro accumulates no wear at all")
check(#shirt.holes == 0, "Glabro tears no holes")
check(p.resets == 0 and #p.sounds == 0, "Glabro: no model reset and no rip sound")
for _ = 1, 9 do C.dropForbidden(p, "Glabro") end
check(shirt.condition == 10 and pants.condition == 8 and shirt.md.WTAGarou_Wear == nil, "0.4.82: ten Glabro shifts still cost nothing (was one point on the tenth)")
check(#p.sounds == 0, "0.4.82: no rip clip ever for Glabro")
p.sounds = {}
check(WTAGarou.Wardrobe.count(p) == 0, "Glabro records nothing in the wardrobe (nothing came off)")

-- Lupus: small damage, drop, remembered
local n = C.dropForbidden(p, "Lupus")
check(n == 5, "Lupus drops shirt, pants, shoes, jacket, hat: " .. tostring(n))
check(#p.world == 5, "five items on the ground")
local stillWorn = {}
for _, w in ipairs(p.worn) do stillWorn[w] = true end
check(stillWorn[bag] and stillWorn[sling] and stillWorn[ring] and stillWorn[belt], "containers, jewelry and belt stay worn")
check(stillWorn[heldHat], "clothing held in a hand is untouched")
check(p.inventory[carriedJacket], "carried clothing is untouched")
check(not stillWorn[shirt] and not stillWorn[pants] and not stillWorn[shoes] and not stillWorn[hat], "dropped items are no longer worn")
check(shirt.condition == 9 and pants.condition == 7, "Lupus: -1 point: " .. shirt.condition .. "/" .. pants.condition)
check(hat.condition == 10, "Lupus: hat dropped undamaged")
check(#shirt.holes == 1, "Lupus tears one hole")
check(p.resets == 1, "model reset once after a drop")
check(#p.sounds == 1 and p.sounds[1] == "ClothesRipping", "one rip clip per tearing shift, not per item")
check(WTAGarou.Wardrobe.count(p) == 5, "the five torn-off items are remembered for Dress")
check(C.dropForbidden(p, "Crinos") == 0, "second strip finds nothing left to rip")

-- Hispo: current damage (3 points, 2 holes)
local h = newPlayer("Homid")
local hs, hh = item("Torso1", { condition = 10, max = 10 }), item("MaskFull", { condition = 10, max = 10 })
h.worn = { hs, hh }
check(C.dropForbidden(h, "Hispo") == 2, "Hispo drops shirt and mask")
check(hs.condition == 7 and #hs.holes == 2, "Hispo: -3 points and two holes")
check(hh.condition == 10 and #hh.holes == 0, "Hispo: mask dropped undamaged")

-- Crinos: explosive (4 points, 3 holes), never destroys outright
local c = newPlayer("Homid")
local cs, cl = item("Torso1", { condition = 1, max = 10 }), item("Jacket_Bulky", { condition = 10, max = 20, parts = { "Torso_Upper", "Torso_Lower", "UpperArm_L", "UpperArm_R" } })
c.worn = { cs, cl }
check(C.dropForbidden(c, "Crinos") == 2, "Crinos strips too")
check(c.worn[1] == nil and cs.condition == 1, "condition floors at 1")
check(cl.condition == 6 and #cl.holes == 3, "Crinos: bulky jacket loses 4 of 20 (amount, not 25% of max) and three holes")

-- Forced Crinos (100 Rage): double points, same holes
local f = newPlayer("Homid")
local fs = item("Torso1", { condition = 10, max = 10, parts = { "Torso_Upper", "Torso_Lower", "UpperArm_L", "UpperArm_R" } })
f.worn = { fs }
check(C.dropForbidden(f, "Crinos", { forced = true }) == 1, "forced Crinos still drops")
check(fs.condition == 2 and #fs.holes == 3, "forced Crinos: -8 points, still 3 holes: " .. fs.condition .. "/" .. #fs.holes)
check(C.damageAndDrop ~= nil, "legacy damageAndDrop still exported")

-- ------------------------------------------------- manual Strip action --
-- 0.4.12: "Strip" queues a vanilla unequip per tearable worn item; nothing
-- is damaged or dropped, and safe items / held items are skipped.
local queued = {}
ISTimedActionQueue = { add = function(a) table.insert(queued, a) end }
ISUnequipAction = { new = function(_, player, it, time) return { player = player, item = it, time = time } end }
getPlayer = function() return nil end
dofile(root .. "/42/media/lua/client/WTAGarouStrip.lua")
local sp = newPlayer("Homid")
local sShirt, sPants, sBag, sRing, sHeld = item("Torso1"), item("Pants"), item("Back", { container = true }), item("Right_RingFinger"), item("Hat")
sp.worn = { sShirt, sPants, sBag, sRing, sHeld }
sp.primary = sHeld
local cands = C.stripCandidates(sp)
check(#cands == 2 and cands[1] == sPants and cands[2] == sShirt, "strip candidates: tearable worn items, outermost first")
check(WTAGarou.Strip.queue(sp) == 2, "Strip queues one unequip per candidate")
check(#queued == 2 and queued[1].item == sPants and queued[2].item == sShirt and queued[1].time == 50, "vanilla ISUnequipAction per item at the inventory's 50-tick time")
check(#sp.worn == 5 and #sp.world == 0 and #sShirt.holes == 0, "Strip itself neither drops, unequips nor damages anything (the queued actions do the unequipping)")
queued = {}
sp.worn = { sBag, sRing }
check(WTAGarou.Strip.queue(sp) == 0 and #queued == 0, "nothing tearable: nothing queued")
WTAGarou.IsChannelling = function() return true end
sp.worn = { sShirt }
check(WTAGarou.Strip.queue(sp) == 0, "no strip while a shift is channelling")
WTAGarou.IsChannelling = nil
sp.dead = true
check(WTAGarou.Strip.queue(sp) == 0, "dead players do not strip")
sp.dead = false
check(WTAGarou.RequestStrip() == 0, "RequestStrip without a local player is a no-op")

-- ------------------------------------------------------------- Dress --
-- 0.4.16: Strip remembers exact ids; Dress re-equips them from the
-- inventory or nested bags, innermost first, and reports each failure.
local notices = {}
WTAGarou.HUD = WTAGarou.HUD or {}
WTAGarou.HUD.instance = { pushNotice = function(_, t) table.insert(notices, t) end }
ISWearClothing = { new = function(_, player, it) return { kind = "wear", player = player, item = it } end }
ISInventoryTransferAction = { new = function(_, player, it, src, dst) return { kind = "move", item = it, src = src, dst = dst } end }
dofile(root .. "/42/media/lua/client/WTAGarouDress.lua")
WTAGarou.Wardrobe.clear(sp)
queued = {}
local dShirt, dPants, dHat = item("Torso1", { name = "Blue T-shirt" }), item("Pants", { name = "Jeans" }), item("Hat", { name = "Cap" })
sp.worn = { dShirt, dPants, dHat }
check(WTAGarou.Strip.queue(sp) == 3, "Strip queues three unequips")
check(WTAGarou.Wardrobe.count(sp) == 3, "Strip remembered the three exact items")
local names = WTAGarou.Wardrobe.names(sp)
check(names[1] == "Cap" and names[2] == "Jeans" and names[3] == "Blue T-shirt", "remembered in removal order (outermost first)")
-- pretend the unequips ran: shirt in the main inventory, jeans in a bag, cap left on the floor
sp.worn = {}
local dBag = item("Back", { container = true })
sp.inventory[dShirt] = true; dShirt.container_ = sp:getInventory()
sp.inventory[dBag] = true; table.insert(dBag.contents, dPants); dPants.container_ = { name = "bag" }
queued = {}; notices = {}
local q, fl = WTAGarou.Dress.queue(sp)
check(q == 2 and fl == 1, "Dress queues two and fails one: " .. tostring(q) .. "/" .. tostring(fl))
check(queued[1].kind == "wear" and queued[1].item == dShirt, "innermost (shirt) goes on first, straight from the main inventory")
check(queued[2].kind == "move" and queued[2].item == dPants and queued[3].kind == "wear" and queued[3].item == dPants,
    "an item in a bag is moved to the main inventory, then worn")
check(#queued == 3, "no action queued for the missing cap")
check(notices[1] == "Dress: Cap is not in your inventory or nearby." and notices[2] == "Dressing 2 item(s)...", "one panel line per failure, then the summary")
check(WTAGarou.Wardrobe.count(sp) == 3, "entries stay until the item is confirmed worn")
sp.worn = { dShirt, dPants }
check(WTAGarou.Wardrobe.prune(sp) == 2 and WTAGarou.Wardrobe.count(sp) == 1 and WTAGarou.Wardrobe.names(sp)[1] == "Cap",
    "worn again: pruned; the cap is still remembered")
sp.inventory[dHat] = true; dHat.broken = true
queued = {}; notices = {}
q, fl = WTAGarou.Dress.queue(sp)
check(q == 0 and fl == 1 and notices[1] == "Dress: Cap is ruined.", "a broken item is reported, not worn")
dHat.broken = false; sp.primary = dHat
queued = {}; notices = {}
q, fl = WTAGarou.Dress.queue(sp)
check(q == 0 and fl == 1 and notices[1] == "Dress: Cap is in your hands.", "a held item is reported, not worn")
sp.primary = nil
queued = {}; notices = {}
q, fl = WTAGarou.Dress.queue(sp)
check(q == 1 and fl == 0 and queued[1].item == dHat, "picked up and free: the cap is worn")
WTAGarou.Wardrobe.clear(sp)
queued = {}; notices = {}
check(WTAGarou.Dress.queue(sp) == 0 and notices[1] == "Nothing to put back on.", "empty wardrobe: nothing queued")

-- 0.4.20: Dress from a beast form skips what the form cannot wear (the 0.4.19
-- playtest queued six items three times from Crinos and dressed one).
sp.worn = { dShirt, dPants }
check(WTAGarou.Strip.queue(sp) == 2 and WTAGarou.Wardrobe.count(sp) == 2, "two items remembered for the form test")
sp.worn = {}
local dc = WTAGarou.GetData(sp); local savedForm = dc.form
-- 0.4.22: the wear blacklist is OFF by default (every form dresses), so the
-- form filter only bites when it is switched back on.
dc.form = "Lupus"
queued = {}; notices = {}
q, fl = WTAGarou.Dress.queue(sp)
check(q == 2 and #queued >= 2, "Lupus (0.4.22): shirt and pants are queued like any form (" .. tostring(q) .. "/" .. tostring(#queued) .. ")")
WTAGarou.Dress.reportPending = false
check(WTAGarou.Wardrobe.count(sp) == 2, "Lupus: the items stay remembered")
WTAGarou.WEAR_BLACKLIST_ENABLED = true
queued = {}; notices = {}
q, fl = WTAGarou.Dress.queue(sp)
check(q == 0 and #queued == 0, "blacklist on: Lupus queues nothing for shirt and pants (" .. tostring(q) .. "/" .. tostring(#queued) .. ")")
check(notices[1] and notices[1]:find("will not fit a Wolf", 1, true), "blacklist on: the notice names the form: " .. tostring(notices[1]))
check(WTAGarou.Wardrobe.count(sp) == 2, "blacklist on: the items stay remembered for the next human form")
WTAGarou.WEAR_BLACKLIST_ENABLED = false
dc.form = "Crinos"
queued = {}; notices = {}
q, fl = WTAGarou.Dress.queue(sp)
check(q == 2 and WTAGarou.Dress.reportPending == true, "Crinos may wear shirt and pants; an outcome report is scheduled")
WTAGarou.Dress.reportPending = false
sp.worn = { dShirt }
local realPrint2 = print; local dressLogs = {}
print = function(...) dressLogs[#dressLogs + 1] = table.concat({ ... }, " ") end
local off = WTAGarou.Dress.report(sp)
print = realPrint2
check(off == 1 and dressLogs[1]:find("1 queued item(s) still not worn", 1, true) and dressLogs[1]:find("Jeans", 1, true),
    "the outcome report names the item still off: " .. tostring(dressLogs[1]))
sp.worn = {}
dc.form = savedForm
queued = {}; notices = {}
q, fl = WTAGarou.Dress.queue(sp)
check(q == 1 and fl == 0 and queued[1].item == dPants, "back in Homid the item still off (jeans) is queued; the worn shirt was pruned by the report")
WTAGarou.Wardrobe.clear(sp)

-- 0.4.17 playtest fixes.
-- (a) Strip records items that are STILL WORN (the unequip runs later); a
--     HUD refresh between Strip and the unequip used to prune them at once.
local pShirt, pPants = item("Torso1", { name = "Work Shirt" }), item("Pants", { name = "Cargo Pants" })
sp.worn = { pShirt, pPants }; sp.inventory = {}; sp.invObj = nil; sp.primary = nil
queued = {}
check(WTAGarou.Strip.queue(sp) == 2 and WTAGarou.Wardrobe.count(sp) == 2, "Strip remembered two worn items")
check(WTAGarou.Wardrobe.prune(sp) == 0 and WTAGarou.Wardrobe.count(sp) == 2, "prune keeps pending Strip entries while they are still worn")
sp.worn = {}; sp.inventory[pShirt] = true; sp.inventory[pPants] = true
check(WTAGarou.Wardrobe.prune(sp) == 0 and WTAGarou.Wardrobe.count(sp) == 2, "off the body: entries stay, no longer pending")
sp.worn = { pShirt }
check(WTAGarou.Wardrobe.prune(sp) == 1 and WTAGarou.Wardrobe.names(sp)[1] == "Cargo Pants", "worn again after being off: pruned")
-- (b) find() walks the inventory in Lua when the engine lookup returns nil
sp.invObj = nil
local realGet = nil
function sp:getInventory()
    if self.invObj then return self.invObj end
    local inv = self.inventory
    local obj = { name = "main" }
    function obj.Remove(_, it) inv[it] = nil end
    function obj.getItemWithIDRecursiv() return nil end            -- engine says "nothing"
    function obj.getItems()
        local list = {}
        for it in pairs(inv) do list[#list + 1] = it end
        return { size = function() return #list end, get = function(_, i) return list[i + 1] end }
    end
    self.invObj = obj
    return obj
end
local lBag = item("Back", { container = true })
function lBag:getItemContainer()
    local c = self.contents
    return { getItems = function() return { size = function() return #c end, get = function(_, i) return c[i + 1] end } end }
end
sp.inventory = { [lBag] = true }; table.insert(lBag.contents, pPants); pPants.container_ = lBag:getItemContainer()
sp.invObj = nil
local found, where = WTAGarou.Wardrobe.find(sp, pPants.id)
check(found == pPants and where == "inventory", "Lua scan finds the exact item inside a bag when the engine lookup fails")
check(WTAGarou.Wardrobe.find(sp, 999999) == nil, "unknown id is not found (never matched by type)")
-- (c) floor search + grab before wearing
local grabbed = {}
ISGrabItemAction = { new = function(_, player, wo, time) return { kind = "grab", player = player, worldItem = wo, time = time } end }
luautils = { walkAdj = function() return true end }
local fHat = item("Hat", { name = "Straw Hat" })
local worldObj = { getItem = function() return fHat end, getSquare = function() return { x = 1 } end }
function sp:getX() return 10.4 end
function sp:getY() return 20.6 end
function sp:getZ() return 0 end
function sp:getCell()
    return { getGridSquare = function(_, x, y, z)
        if x == 11 and y == 19 and z == 0 then
            return { getWorldObjects = function() return { size = function() return 1 end, get = function() return worldObj end } end }
        end
        return { getWorldObjects = function() return { size = function() return 0 end, get = function() return nil end } end }
    end }
end
found, where = WTAGarou.Wardrobe.find(sp, fHat.id)
check(found == fHat and where == "floor", "an item dropped within 2 tiles is found on the floor")
WTAGarou.Wardrobe.clear(sp); WTAGarou.Wardrobe.record(sp, fHat, "shift")
queued = {}; notices = {}
q, fl = WTAGarou.Dress.queue(sp)
check(q == 1 and fl == 0, "floor item is dressed: " .. tostring(q) .. "/" .. tostring(fl))
check(queued[1].kind == "grab" and queued[1].worldItem == worldObj and queued[2].kind == "wear" and queued[2].item == fHat,
    "grab from the floor first, then wear")
-- (d) a missing item dumps the recorded id and the inventory ids to the console
WTAGarou.Wardrobe.clear(sp); WTAGarou.Wardrobe.record(sp, pShirt, "shift"); sp.worn = {}; sp.inventory = {}; sp.invObj = nil
local lines = WTAGarou.Wardrobe.debugDump(sp, { tostring(pShirt.id) .. "=Base.Torso1" })
check(lines[1]:find(tostring(pShirt.id), 1, true) ~= nil and lines[2]:find("inventory ids", 1, true) ~= nil, "diagnostic dump lists the missing id and the inventory ids")
WTAGarou.IsChannelling = function() return true end
WTAGarou.Wardrobe.record(sp, dHat, "strip")
check(WTAGarou.Dress.queue(sp) == 0, "no dress while a shift is channelling")
WTAGarou.IsChannelling = nil
for i = 1, 40 do WTAGarou.Wardrobe.record(sp, item("Torso1", { name = "s" .. i }), "strip") end
check(WTAGarou.Wardrobe.count(sp) == WTAGarou.Wardrobe.MAX, "wardrobe capped at MAX")
WTAGarou.Wardrobe.record(sp, dHat, "shift")
check(WTAGarou.Wardrobe.count(sp) == WTAGarou.Wardrobe.MAX and WTAGarou.Wardrobe.names(sp)[WTAGarou.Wardrobe.MAX] == "Cap", "re-recording an id moves it to the end, no duplicate")
WTAGarou.Wardrobe.clear(sp)
WTAGarou.HUD.instance = nil

-- ------------------------------------------- stealth / voice registration --
local java = { noise = {}, voice = {}, text = {}, fall = {}, calls = 0 }
WTAGarouJava = {
    setScale = function() return true end, clearScale = function() end, clear = function(pl)
        java.noise[pl] = nil; java.voice[pl] = nil end,
    setStability = function() return true end, setWolf = function() return "mock" end,
    status = function() return "mock" end,
    setNoise = function(pl, f, s, ss, wolf, step)
        java.calls = java.calls + 1
        java.noise[pl] = { f = f, s = s, ss = ss, wolf = wolf, step = step }; return true end,
    setVoice = function(pl, a, b, ra, rb) java.voice[pl] = { a = a, b = b, ra = ra, rb = rb }; return true end,
    setVoiceText = function(pl, a, b) java.text[pl] = { a = a, b = b }; return true end,
    setFallSound = function(pl, s) java.fall[pl] = s; return true end,
    setShoutAnim = function(pl, on) java.shoutAnim = java.shoutAnim or {}; java.shoutAnim[pl] = on; return true end,
    slots = {}, slotsEnabled = nil,
    setWolfSlot = function(key, bone, rx, ry, rz, ox, oy, oz)
        WTAGarouJava.slots[key] = { bone = bone, rot = { rx, ry, rz }, off = { ox, oy, oz } } end,
    setWolfSlotPivot = function(key, px, py, pz) WTAGarouJava.pivots[key] = { px, py, pz } end,
    pivots = {},
    clearWolfSlots = function() WTAGarouJava.slots = {} end,
    setWolfSlotsEnabled = function(on) WTAGarouJava.slotsEnabled = on end,
    setHarnessTransform = function(rx, ry, rz, ox, oy, oz, sc) WTAGarouJava.harness = { rx, ry, rz, ox, oy, oz, sc } end,
    setSaddlebagScale = function(sc) WTAGarouJava.saddleScale = sc end,
    setTraits = function(pl, rawMeat, paws, walk, run, sprint, sneak, turn)
        java.traitCalls = (java.traitCalls or 0) + 1
        java.traits[pl] = { rawMeat = rawMeat, paws = paws, walk = walk, run = run, sprint = sprint, sneak = sneak, turn = turn }
        return true end,
    setStride = function(pl, factor) java.stride = java.stride or {}; java.stride[pl] = factor; return true end,
}
java.traits = {}
-- 0.4.13: the attached location must be registered before AttachedItems is
-- queried; the engine throws (and logs) on an unknown location.
local locations = {}
AttachedLocations = { getGroup = function(id)
    check(id == "Human", "saddlebag location lives in the Human group")
    return {
        getLocation = function(_, loc) return locations[loc] end,
        getOrCreateLocation = function(_, loc)
            locations[loc] = locations[loc] or { name = nil,
                setAttachmentName = function(self, n) self.name = n end }
            return locations[loc]
        end,
    }
end }
dofile(root .. "/42/media/lua/shared/WTAGarouAttachedLocations.lua")
check(locations["WTAGarou_Saddlebags"] and locations["WTAGarou_Saddlebags"].name == "WTAGarou_Saddlebags",
    "saddlebag attached location registered at load, before any query")
WTAGarou.EnableDirectWolf = false
local realPrint = print
print = function() end
dofile(root .. "/42/media/lua/client/WTAGarouVisual.lua")
dofile(root .. "/42/media/lua/client/WTAGarouWolfVoice.lua")
print = realPrint
local refresh = WTAGarou.Visual.refresh

local g = newPlayer("Lupus")
g.worn = { item("Back", { container = true }) }
refresh(g, true)
check(java.noise[g] and java.noise[g].f == 0.5 and java.noise[g].s == 0.6 and java.noise[g].ss == 0.5, "Lupus noise profile")
check(java.noise[g].wolf == true and java.noise[g].step == "WTAGarou_WolfStep", "Lupus uses wolf steps")
check(java.voice[g].a == "WTAGarou_WolfBark" and java.voice[g].b == "WTAGarou_WolfGrowl", "Lupus bark/growl voice")
check(java.voice[g].ra == 20 and java.voice[g].rb == 4, "Lupus voice radii shorter than human 30/6")
check(WTAGarou.Voice.Hispo.standing == "WTAGarou_HispoBark" and WTAGarou.Voice.Hispo.crouched == "WTAGarou_HispoGrowl",
    "Hispo Q/crouched Q use the author's Hispo bark/growl (0.4.18)")
check(WTAGarou.Voice.Lupus.standing == "WTAGarou_WolfBark" and WTAGarou.Voice.Lupus.crouched == "WTAGarou_WolfGrowl",
    "Lupus keeps the WolfMod bark/growl")
check(java.fall[g] == "WTAGarou_WolfFallOver", "Lupus fall-over sound")
check(java.shoutAnim[g] == true, "Lupus keeps the shout gesture")
check(g.attached["WTAGarou_Saddlebags"] == nil or true, "saddlebag attach attempted without instanceItem is safe")
local calls = java.calls
for _ = 1, 20 do refresh(g, false) end
check(java.calls == calls, "unchanged form does not re-register stealth")

g.md.WTAGarou.form = "Crinos"
refresh(g, true)
check(java.noise[g].f == 1.5 and java.noise[g].s == 1.0 and java.noise[g].wolf == false, "Crinos louder, human steps, full visibility")
check(java.voice[g].a == "WTAGarou_CrinosRoar" and java.voice[g].b == "WTAGarou_CrinosGrowl", "Crinos roar / growl")
check(java.voice[g].ra == 45 and java.voice[g].rb == 9, "Crinos shout carries farther than human")
check(java.fall[g] == "", "Crinos has no wolf fall sound")
check(java.shoutAnim[g] == false and WTAGarou.Voice.Crinos.shoutAnim == false, "0.4.63: Crinos Q shout / whisper plays no gesture animation")

g.md.WTAGarou.form = "Glabro"
refresh(g, true)
check(java.noise[g].f == 1.0 and java.noise[g].s == 1.0, "Glabro sounds like Homid")
check(java.voice[g].a == "" and java.voice[g].b == "" and java.voice[g].ra == 30 and java.voice[g].rb == 6, "Glabro keeps the human shout")
check(java.shoutAnim[g] == true, "Glabro shouts with the gesture again")

g.md.WTAGarou.form = "Hispo"
refresh(g, true)
check(java.noise[g].f == 1.0 and java.noise[g].wolf == true, "Hispo: human-loud wolf steps")
check(java.voice[g].ra == 30 and java.voice[g].rb == 6, "Hispo bark carries like a human shout")

-- ---------------------------------------------------------------- traits --
g.md.WTAGarou.form = "Lupus"
refresh(g, true)
local t = java.traits[g]
check(t and t.rawMeat == true and t.paws == true, "Lupus: raw meat and paw immunity requested")
check(t.walk == 1.40 and t.run == 1.35 and t.sprint == 1.25 and t.sneak == 2.40 and t.turn == 1.60, "Lupus gait/turn multipliers")
local tcalls = java.traitCalls
for _ = 1, 10 do refresh(g, false) end
check(java.traitCalls == tcalls, "unchanged form does not re-send traits")
g.md.WTAGarou.form = "Hispo"
refresh(g, true)
t = java.traits[g]
check(t.paws == true and t.sneak == 2.00 and t.turn == 1.30 and t.walk == 1.30, "Hispo multipliers")
g.md.WTAGarou.form = "Homid"
refresh(g, true)
t = java.traits[g]
check(t.rawMeat == true and t.paws == false and t.walk == 1 and t.run == 1 and t.sprint == 1 and t.sneak == 1 and t.turn == 1,
    "Homid: raw meat only; no paws, vanilla speed and turn")
check(java.stride[g] == 1, "Homid: vanilla root motion (stride 1)")
-- 0.4.60: scaled bipeds move by stride x cadence. The stride equals the drawn
-- model scale (feet no longer slide); the cadence is below 1 so the net speed
-- is a modest step up from 0.4.59, not cadence x scale.
for _, f in ipairs({ "Glabro", "Crinos" }) do
    g.md.WTAGarou.form = f
    refresh(g, true)
    local tr, def = java.traits[g], WTAGarou.FormData[f]
    check(tr.paws == true and tr.turn == 1, f .. " has paws and vanilla turn")
    check(java.stride[g] == def.modelScale and java.stride[g] > 1, f .. " stride equals its modelScale (" .. tostring(def.modelScale) .. ")")
    local net = tr.walk * java.stride[g]
    check(tr.walk < 1 and net > 1.1 and net < WTAGarou.Traits.Hispo.walk * 1.01,
        f .. " net walk " .. string.format("%.2f", net) .. ": slower cadence, longer stride, faster than Homid, not past the wolves")
    check(tr.sprint * java.stride[g] < net, f .. " sprint cadence drops more than walk")
end
check(WTAGarou.Traits.Hispo.stride == nil and WTAGarou.Traits.Lupus.stride == nil, "wolf gaits untouched: no stride entry")
check(WTAGarou.Traits.Lupus.sneak > WTAGarou.Traits.Hispo.sneak and WTAGarou.Traits.Hispo.sneak > WTAGarou.Traits.Crinos.sneak,
    "wolves out-sneak the bipeds")
check(WTAGarou.Traits.Lupus.turn > WTAGarou.Traits.Hispo.turn, "Lupus turns faster than Hispo")
g.md.WTAGarou.form = "Hispo"
refresh(g, true)

g.dead = true
refresh(g, false)
check(java.noise[g] == nil, "death clears the stealth profile via Java clear")
g.dead = false

-- ----------------------------------------------------------- saddlebags --
instanceItem = function(t) return { fullType = t, getFullType=function(self) return self.fullType end } end
local w = newPlayer("Lupus")
refresh(w, true)
check(w.attached["WTAGarou_Saddlebags"] == nil, "no container worn: no saddlebag")
w.worn = { item("Back", { container = true }) }
WTAGarou.Visual.refreshSaddlebag(w)
check(w.attached["WTAGarou_Saddlebags"] and w.attached["WTAGarou_Saddlebags"].fullType == "WTAGarou.WolfSaddlebagVisual", "worn container on a wolf attaches the saddlebag")
w.worn = { item("Torso1", { container = true }) }
WTAGarou.Visual.refreshSaddlebag(w)
check(w.attached["WTAGarou_Saddlebags"] ~= nil, "a sheet sling counts as a container too")
w.md.WTAGarou.form = "Homid"
refresh(w, true)
check(w.attached["WTAGarou_Saddlebags"] == nil, "Homid removes the saddlebag")
w.md.WTAGarou.form = "Hispo"
refresh(w, true)
check(w.attached["WTAGarou_Saddlebags"] ~= nil, "Hispo shows it again")
w.worn = {}
WTAGarou.Visual.refreshSaddlebag(w)
check(w.attached["WTAGarou_Saddlebags"] == nil, "taking the bag off removes the saddlebag")
WTAGarou.EnableSaddlebagVisual = false
w.worn = { item("Back", { container = true }) }
WTAGarou.Visual.refreshSaddlebag(w)
check(w.attached["WTAGarou_Saddlebags"] == nil, "toggle off disables the saddlebag visual")
WTAGarou.EnableSaddlebagVisual = true

-- 0.4.12: the engine raises OnClothingUpdated from setAttachedItem. 0.4.11
-- re-entered refreshSaddlebag from that event and overflowed the Lua stack
-- (the "put on a sheet bag / hat" errors). The attach must converge.
local rw = newPlayer("Lupus")
rw.worn = { item("Back", { container = true }) }
local attachCalls = 0
function rw:setAttachedItem(loc, it)
    attachCalls = attachCalls + 1
    if attachCalls > 50 then error("saddlebag attach recursion") end
    self.attached[loc] = it
    WTAGarou.WolfVoice.onClothingUpdated(self)   -- what the engine does
end
WTAGarou.Visual.refreshSaddlebag(rw)
check(rw.attached["WTAGarou_Saddlebags"] ~= nil, "saddlebag attached through the re-entrant clothing event")
check(rw.attached["WTAGarou_Harness"] ~= nil, "0.4.23: the harness comes with the worn container")
check(attachCalls == 2, "exactly one attach each (saddlebag + harness); re-entry is ignored: " .. attachCalls)
WTAGarou.Visual.refreshSaddlebag(rw)
check(attachCalls == 2, "already attached: no re-attach")
rw.worn = {}
WTAGarou.Visual.refreshSaddlebag(rw)
check(rw.attached["WTAGarou_Saddlebags"] == nil and rw.attached["WTAGarou_Harness"] == nil and attachCalls == 4,
    "one detach each when the bag comes off")
rw.worn = { item("Back", { container = true }) }
rw.md.WTAGarou.wolfGearVariant="Camo"
WTAGarou.Visual.refreshSaddlebag(rw)
check(rw.attached["WTAGarou_Saddlebags"].fullType=="WTAGarou.WolfSaddlebagVisualCamo"
    and rw.attached["WTAGarou_Harness"].fullType=="WTAGarou.WolfHarnessVisualCamo" and attachCalls==6,
    "saved Camo creates both variants once despite re-entry")
rw.md.WTAGarou.wolfGearVariant="Black"
refresh(rw,true)
check(rw.attached["WTAGarou_Saddlebags"].fullType=="WTAGarou.WolfSaddlebagVisual"
    and rw.attached["WTAGarou_Harness"].fullType=="WTAGarou.WolfHarnessVisual" and attachCalls==8,
    "gear-only change replaces both actual attachments")
for i=1,10 do refresh(rw,false) end
check(attachCalls==8,"unchanged gear never re-attaches")
rw.md.WTAGarou.form="Homid"; refresh(rw,true)
rw.md.WTAGarou.wolfGearVariant="Camo"; refresh(rw,true)
check(rw.attached["WTAGarou_Harness"]==nil and rw.attached["WTAGarou_Saddlebags"]==nil,
    "changing gear while human never equips cosmetic gear")
rw.md.WTAGarou.form="Hispo"; refresh(rw,true)
check(rw.attached["WTAGarou_Harness"].fullType=="WTAGarou.WolfHarnessVisualCamo",
    "Camo survives human to Hispo")
rw.attached["WTAGarou_Harness"]=nil
local createItem=instanceItem
instanceItem=function() return nil end
refresh(rw,true)
check(rw.attached["WTAGarou_Harness"]==nil,"failed creation is not fake success")
instanceItem=createItem
refresh(rw,false)
check(rw.attached["WTAGarou_Harness"].fullType=="WTAGarou.WolfHarnessVisualCamo",
    "lost attachment / failed creation retried without gear toggle")

local function xyz(t) return type(t) == "table" and #t == 3 and type(t[1]) == "number" and type(t[2]) == "number" and type(t[3]) == "number" end
-- ------------------------------------------------- harness stand-in (0.4.23) --
check(locations["WTAGarou_Harness"] and locations["WTAGarou_Harness"].name == "WTAGarou_Harness",
    "harness attached location registered at load")
local hw = newPlayer("Lupus")
refresh(hw, true)
check(hw.attached["WTAGarou_Harness"] == nil, "bare wolf: nothing on the hotbar, no harness")
hw.attached["Back"] = { fullType = "Base.Axe" }
WTAGarou.Visual.refreshSaddlebag(hw)
check(hw.attached["WTAGarou_Harness"] and hw.attached["WTAGarou_Harness"].fullType == "WTAGarou.WolfHarnessVisual",
    "a hotbar item on a wolf attaches the harness")
check(hw.attached["WTAGarou_Saddlebags"] == nil, "the harness does not bring the saddlebag (no container worn)")
hw.attached["Back"] = nil
WTAGarou.Visual.refreshSaddlebag(hw)
check(hw.attached["WTAGarou_Harness"] == nil, "last hotbar item removed: harness gone")
hw.worn = { item("Back", { container = true }) }
WTAGarou.Visual.refreshSaddlebag(hw)
check(hw.attached["WTAGarou_Saddlebags"] ~= nil and hw.attached["WTAGarou_Harness"] ~= nil,
    "a worn container shows the saddlebag AND the harness (bags hang from the harness)")
check(not WTAGarou.Visual.hasHotbarItem(hw), "our own stand-ins never count as attached gear")
hw.worn = {}
WTAGarou.Visual.refreshSaddlebag(hw)
check(hw.attached["WTAGarou_Saddlebags"] == nil and hw.attached["WTAGarou_Harness"] == nil,
    "no container and nothing attached: both stand-ins gone")
hw.secondary = { fullType = "Base.Torch" }
WTAGarou.Visual.refreshSaddlebag(hw)
check(hw.attached["WTAGarou_Harness"] ~= nil, "a secondary-hand item counts as attached gear")
hw.primary = hw.secondary
WTAGarou.Visual.refreshSaddlebag(hw)
check(hw.attached["WTAGarou_Harness"] == nil, "a two-handed item (same item in both hands) is not secondary gear")
hw.primary = nil
WTAGarou.Visual.refreshSaddlebag(hw)
hw.md.WTAGarou.form = "Homid"
refresh(hw, true)
check(hw.attached["WTAGarou_Harness"] == nil, "Homid removes the harness")
hw.md.WTAGarou.form = "Hispo"
refresh(hw, true)
check(hw.attached["WTAGarou_Harness"] ~= nil, "Hispo shows it again")
WTAGarou.EnableHarnessVisual = false
hw.attached["WTAGarou_Harness"] = nil
WTAGarou.Visual.refreshSaddlebag(hw)
check(hw.attached["WTAGarou_Harness"] == nil, "toggle off disables the harness visual")
WTAGarou.EnableHarnessVisual = true
local hrw = newPlayer("Lupus")
hrw.attached["Belt Left"] = { fullType = "Base.Hammer" }
local hAttach = 0
function hrw:setAttachedItem(loc, it)
    hAttach = hAttach + 1
    if hAttach > 50 then error("harness attach recursion") end
    self.attached[loc] = it
    WTAGarou.WolfVoice.onClothingUpdated(self)
end
WTAGarou.Visual.refreshSaddlebag(hrw)
check(hrw.attached["WTAGarou_Harness"] ~= nil and hAttach == 1, "harness attached once through the re-entrant clothing event: " .. hAttach)

-- ------------------------------------------------- wolf slot rules (0.4.23) --
local rules = WTAGarou.Visual.wolfSlotRules(hw)
hw.attached["Custom Tool Left"]={getAttachedSlotType=function() return "Belt Left" end}
local aliases=WTAGarou.Visual.wolfSlotRules(hw)
local aliasFound=false
for _,r in ipairs(aliases) do
    if r.key=="customtool_left" then
        aliasFound=true
        check(r.pivot[1]==WTAGarou.WolfSlots["Belt Left"].pivot[1],"actual hotbar slot retains tuned pivot")
    end
end
check(aliasFound,"actual equipped item location maps to its configured hotbar slot")
hw.attached["Custom Tool Left"]=nil
local byKey = {}
for _, r in ipairs(rules) do byKey[r.key] = r end
check(byKey["Back"] and byKey["back_hotbar"], "a location id rule is pushed under the id AND the engine attachment name")
check(byKey["Belt Left"] and byKey["belt_left_hotbar"], "Belt Left resolves through the Human group")
check(byKey["Belt Right"] and byKey["secondary"], "unresolvable ids and 'secondary' are pushed by key alone")
check(byKey["ENABLED"] == nil and byKey["BONE"] == nil, "ENABLED/BONE are settings, not rules")
check(byKey["Back"].bone == WTAGarou.WolfSlots.BONE and xyz(byKey["Back"].rotate) and xyz(byKey["Back"].offset), "rule carries bone, rotate and offset triples")
local pushed = WTAGarou.Visual.pushWolfSlots(hw)
check(pushed == #rules and WTAGarouJava.slots["back_hotbar"] and WTAGarouJava.slots["secondary"], "pushWolfSlots hands every rule to Java")
check(WTAGarouJava.slotsEnabled == true, "WolfSlots.ENABLED pushed")
-- 0.4.24: pivot (grip point) travels as its own call, only when non-zero.
check(byKey["Back"].pivot and #byKey["Back"].pivot == 3, "rule carries a pivot triple (defaults to zeros)")
check(WTAGarouJava.pivots["Back"] and WTAGarouJava.pivots["Back"][2] == WTAGarou.WolfSlots["Back"].pivot[2],
    "author's configured Back pivot is pushed")
hw.attached["Custom Tool Left"]={getAttachedSlotType=function() return "Belt Left" end}
WTAGarouJava.slots={}
WTAGarou.Visual.refreshSaddlebag(hw)
check(WTAGarouJava.slots["customtool_left"],"equipment refresh publishes newly attached item alias without Reload defs")
hw.attached["Custom Tool Left"]=nil
check(WTAGarouJava.pivots["Holster Left"] == nil, "zero pivots are not pushed")
WTAGarou.WolfSlots["Back"].pivot = { 0.0, 0.35, 0.0 }
WTAGarouJava.pivots = {}
WTAGarou.Visual.pushWolfSlots(hw)
check(WTAGarouJava.pivots["Back"] and WTAGarouJava.pivots["Back"][2] == 0.35 and WTAGarouJava.pivots["back_hotbar"], "non-zero pivot pushed under the id and the attachment name")
WTAGarou.WolfSlots["Back"].pivot = { 0.0, 0.0, 0.0 }
check(WTAGarouJava.harness==nil and WTAGarouJava.saddleScale == WTAGarou.Saddlebag.scale,
    "skinned harness no longer receives rigid transforms; saddlebag tuning still pushed")
check(WTAGarou.Visual.slotAttachmentName(hw, "Nowhere") == nil, "unknown location id resolves to nil, not an error")

-- ---------------------------------------------------------- wolf sounds --
local V = WTAGarou.WolfVoice
local wv = newPlayer("Lupus")
V.onWeaponSwing(wv, nil)
check(#wv.sounds==0,"attack sound waits for settled state, not damage")
V.flushSwing(wv)
check(wv.sounds[#wv.sounds] == "WTAGarou_WolfAttack", "swing -> attack sound")
function wv:isDoGrapple() return self.grapple end
wv.grapple=true
V.onWeaponSwing(wv,nil)
check(#wv.sounds==1,"corpse/grapple grab does not bark as a bite")
wv.grapple=false
function wv:getCurrentState() return {getName=function() return self.voiceState or "SwipeStatePlayer" end} end
V.onWeaponSwing(wv,nil)
wv.voiceState="PlayerDraggingCorpse"
V.flushSwing(wv)
check(#wv.sounds==1,"pickup transition with consumed grapple flag does not bark")
V.onWeaponSwing(wv,nil); V.flushSwing(wv)
check(#wv.sounds==1,"already dragging corpse does not bark as a bite")
wv.voiceState="SwipeStatePlayer"
function wv:isPerformingGrappleGrabAnimation() return self.grabAnim end
wv.grabAnim=true; V.onWeaponSwing(wv,nil); V.flushSwing(wv); wv.grabAnim=false
check(#wv.sounds==1,"active grab animation is not a bite")
V.onWeaponSwing(wv,nil); wv.dead=true; V.flushSwing(wv); wv.dead=false
check(#wv.sounds==1,"pending sound dropped on death")
V.onWeaponSwing(wv,nil); wv.md.WTAGarou.form="Homid"; V.flushSwing(wv); wv.md.WTAGarou.form="Lupus"
check(#wv.sounds==1,"pending sound dropped on form change")
clock = 50
V.onPlayerGetDamage(wv, "WEAPONHIT", 3)
check(wv.sounds[#wv.sounds] == "WTAGarou_WolfBark", "damage -> pain bark")
V.onPlayerGetDamage(wv, "WEAPONHIT", 0)
check(#wv.sounds == 2, "zero damage does not bark")
-- 0.4.13: a grab reports damage every frame; one bark per cooldown.
for _ = 1, 30 do clock = clock + 0.016; V.onPlayerGetDamage(wv, "WEAPONHIT", 1) end
check(#wv.sounds == 2, "rapid damage within the cooldown does not stack barks")
clock = clock + 2
V.onPlayerGetDamage(wv, "WEAPONHIT", 1)
check(#wv.sounds == 3, "next bark after the cooldown")
-- 0.4.17: ongoing damage ticks never bark (the endless bark of the playtest)
for _, t in ipairs({ "BLEEDING", "INFECTION", "HUNGRY", "THIRST", "SICK", "HEAVYLOAD", "POISON", "LOWWEIGHT" }) do
    clock = clock + 2
    V.onPlayerGetDamage(wv, t, 1)
end
check(#wv.sounds == 3, "bleeding/infection/hunger ticks do not bark")
for _, t in ipairs({ "FALLDOWN", "CARHITDAMAGE", "FIRE" }) do
    clock = clock + 2
    V.onPlayerGetDamage(wv, t, 1)
end
check(#wv.sounds == 6, "falls, car hits and fire still yelp")
-- 0.4.17: zombie bites raise no damage event; a new wound yelps instead
wv.wounds = 0
function wv:getBodyDamage()
    local me = self
    return { getNumPartsBitten = function() return me.wounds end, getNumPartsScratched = function() return 0 end }
end
clock = clock + 2; V.onWoundCheck(wv, "Lupus")            -- baseline
clock = clock + 2; V.onWoundCheck(wv, "Lupus")
check(#wv.sounds == 6, "no new wound, no bark")
wv.wounds = 1; clock = clock + 2; V.onWoundCheck(wv, "Lupus")
check(#wv.sounds == 7 and wv.sounds[7] == "WTAGarou_WolfBark", "a fresh bite yelps once")
clock = clock + 2; V.onWoundCheck(wv, "Lupus")
check(#wv.sounds == 7, "the same wound does not keep barking")
check(WTAGarou.WolfSounds.PAIN_COOLDOWN == 1.5, "pain cooldown is 1.5 s (0.4.17)")
wv.md.WTAGarou.form = "Homid"
clock = clock + 5
V.onWeaponSwing(wv, nil)
V.onPlayerGetDamage(wv, "WEAPONHIT", 3)
check(#wv.sounds == 7, "Homid makes no wolf sounds")
wv.md.WTAGarou.form = "Crinos"
V.onWeaponSwing(wv, nil); V.flushSwing(wv)
check(#wv.sounds == 7, "Crinos makes no wolf attack sound")
-- 0.4.75: the Crinos growls when hurt (pain only; attack/sniff/death stay wolf-only)
clock = clock + 2
V.onPlayerGetDamage(wv, "WEAPONHIT", 3)
check(#wv.sounds == 8 and wv.sounds[8] == "WTAGarou_CrinosGrowl", "Crinos hurt -> growl")
clock = clock + 2; V.onWoundCheck(wv, V.painForm(wv)); wv.wounds = 2; clock = clock + 2; V.onWoundCheck(wv, V.painForm(wv))
check(#wv.sounds == 9 and wv.sounds[9] == "WTAGarou_CrinosGrowl", "a fresh wound on a Crinos growls too")
check(V.wolfForm(wv) == nil and V.painForm(wv) == "Crinos", "Crinos is a pain form, not a wolf form")
local n7 = #wv.sounds
wv.md.WTAGarou.form = "Hispo"
clock = 100
V.onPlayerUpdate(wv)
check(#wv.sounds == 9, "first update only schedules the sniff")
clock = 105
V.onPlayerUpdate(wv)
check(#wv.sounds == 9, "no sniff before 10 s")
clock = 111
wv.moving = true
V.onPlayerUpdate(wv)
check(#wv.sounds == 9, "moving wolves do not sniff")
clock = 114
wv.moving = false
V.onPlayerUpdate(wv)
check(wv.sounds[#wv.sounds] == "WTAGarou_WolfSniff", "still wolf sniffs after the interval")
clock = 116
V.onPlayerUpdate(wv)
check(#wv.sounds == 10, "sniff rescheduled, not spammed")
V.onPlayerDeath(wv)
check(wv.sounds[#wv.sounds] == "WTAGarou_WolfDeath", "death whimper in wolf form")
local remote = newPlayer("Lupus"); remote.local_ = false
V.onWeaponSwing(remote, nil)
check(#remote.sounds == 0, "remote players are not voiced locally")

-- Countdown sound is the author's shift-timer cue (0.4.18; was the growl).
check(WTAGarou.CrinosCountdownSound == "WTAGarou_CrinosShiftTimer", "countdown uses the Crinos shift-timer cue")
local client = io.open(root .. "/42/media/lua/client/WTAGarouClient.lua"):read("*a")
check(not client:find('"WTAGarou_Growl"', 1, true), "client no longer references the old WTAGarou_Growl entry")


-- 0.4.19: Build 42 hands back LOWER-CASE body-location ids.
check(C.lookup({ Ears = true }, "ears") == true and C.lookup({ Ears = true }, "Ears") == true
    and C.lookup({ Ears = true }, "EARS") == true and C.lookup({ Ears = true }, "nose") == nil, "case-insensitive location lookup")
check(C.isShiftSafe(item("ears")) and C.isShiftSafe(item("eartop")) and C.isShiftSafe(item("nose"))
    and C.isShiftSafe(item("necklace_long")) and C.isShiftSafe(item("left_ringfinger")) and C.isShiftSafe(item("belt")),
    "lower-case jewelry/belt ids are shift-safe")
check(C.isShiftSafe(item("rightwrist")) and C.isShiftSafe(item("leftwrist")), "wristwatches are shift-safe (never dropped, damaged, stripped or dressed)")
check(C.isDamageExempt(item("hat")) and C.isDamageExempt(item("mask")) and C.isShiftSafe(item("wound")), "lower-case hat/mask are damage-exempt, wound is shift-safe")
check(not C.isShiftSafe(item("tshirt")) and not C.isShiftSafe(item("pants_skinny")) and not C.isShiftSafe(item("knee_right")),
    "lower-case garments still tear")
check(C.categoryFor(item("tshirt")) == "Shirt" and C.categoryFor(item("pants_skinny")) == "Pants" and C.categoryFor(item("shoes")) == "Shoes",
    "lower-case ids map to allowed-clothing categories")
-- Strip/Dress candidates skip watches and jewelry
local wearer = { worn = { item("tshirt"), item("rightwrist"), item("ears"), item("pants") } }
function wearer:getWornItems()
    local list = self.worn
    return { size = function() return #list end, get = function(_, i) return { getItem = function() return list[i + 1] end } end }
end
local cands = C.stripCandidates(wearer)
check(#cands == 2, "stripCandidates keeps only the torn garments (" .. #cands .. ")")
check(WTAGarou.WolfSounds.forForm("Hispo", "attack") == "WTAGarou_HispoBark" and WTAGarou.WolfSounds.forForm("Hispo", "pain") == "WTAGarou_HispoBark",
    "Hispo attacks and yelps with its own bark (0.4.19)")
check(WTAGarou.WolfSounds.forForm("Lupus", "attack") == "WTAGarou_WolfAttack" and WTAGarou.WolfSounds.forForm("Lupus", "pain") == "WTAGarou_WolfBark",
    "Lupus keeps the WolfMod attack/bark")
local voiceSrc = io.open(root .. "/42/media/lua/client/WTAGarouWolfVoice.lua"):read("*a")
check(voiceSrc:find('forForm(form, "attack")', 1, true) and voiceSrc:find('forForm(form, "pain")', 1, true), "WolfVoice routes swing/pain through forForm")
local postGrab=newPlayer("Hispo")
function postGrab:getCurrentState() return {getName=function() return self.state or "SwipeStatePlayer" end} end
V.onWeaponSwing(postGrab,nil)
V.onPlayerUpdate(postGrab)
V.onPlayerUpdate(postGrab)
check(#postGrab.sounds==1 and postGrab.sounds[1]=="WTAGarou_HispoBark","normal Hispo bite plays once via actual update callback")
postGrab.state="PlayerDraggingCorpse"
V.onWeaponSwing(postGrab,nil); V.onPlayerUpdate(postGrab)
check(#postGrab.sounds==1,"corpse interaction stays silent through actual update callback")
V.onPlayerGetDamage(postGrab,"WEAPONHIT",1)
check(#postGrab.sounds==2,"real damage still yelps while handling a corpse")
postGrab.state="SwipeStatePlayer"
V.onWeaponSwing(postGrab,nil); V.onPlayerUpdate(postGrab)
check(#postGrab.sounds==3,"bite sound returns immediately after corpse handling")
-- 0.4.40: the Oct 5 console showed the bite firing in SwipeStatePlayer on the
-- very frame Bob_PickUp_Person_FromOnBack started: no grapple flag was set yet.
-- The Java track adapter saw the corpse clip; the filter asks it.
local javaSaw=false
WTAGarouJava=WTAGarouJava or {}
WTAGarouJava.isCorpseHandling=function(p) return p==postGrab and javaSaw end
V.onWeaponSwing(postGrab,nil); javaSaw=true; V.onPlayerUpdate(postGrab)
check(#postGrab.sounds==3,"corpse pickup in SwipeStatePlayer stays silent when Java saw the corpse clip")
javaSaw=false
V.onWeaponSwing(postGrab,nil); V.onPlayerUpdate(postGrab)
check(#postGrab.sounds==4,"bite returns once Java no longer reports corpse handling")
function postGrab:isGrappling() return self.grappling end
postGrab.grappling=true
V.onWeaponSwing(postGrab,nil); V.onPlayerUpdate(postGrab)
check(#postGrab.sounds==4,"isGrappling (accepted grapple) also silences the bite")
postGrab.grappling=false
WTAGarouJava.isCorpseHandling=nil
local traits = io.open(root .. "/42/media/scripts/characters/wtagarou_traits.txt"):read("*a")
check(traits:find("XPBoosts = Fitness=2;Strength=2;Sneak=2;Nimble=2;Lightfoot=2;Sprinting=3;Tracking=3,", 1, true), "Garou trait grants the 0.4.19 skill boosts")
local models = io.open(root .. "/42/media/scripts/wtagarou_models.txt"):read("*a")
check(select(2, models:gsub("offset = 0%.0 0%.08 0%.02,", "")) == 4 and not models:find("0.08 -0.05", 1, true), "saddlebag z +0.02 preserved including Camo variant")
-- 0.4.22: MouthCarry / Saddlebag / WolfGait are user-tuned in Definitions, so
-- only their SHAPE is pinned (three numbers each), not the values.
local function xyz(t) return type(t) == "table" and #t == 3 and type(t[1]) == "number" and type(t[2]) == "number" and type(t[3]) == "number" end
check(xyz(WTAGarou.MouthCarry.rotate) and xyz(WTAGarou.MouthCarry.offset), "mouth carry rotate/offset are xyz triples")
check(xyz(WTAGarou.Saddlebag.rotate) and xyz(WTAGarou.Saddlebag.offset), "saddlebag rotate/offset are xyz triples (0.4.22)")
check(type(WTAGarou.Saddlebag.scale) == "number" and WTAGarou.Saddlebag.scale > 0, "saddlebag scale is a positive number (0.4.23)")
check(xyz(WTAGarou.Harness.rotate) and xyz(WTAGarou.Harness.offset) and type(WTAGarou.Harness.scale) == "number", "harness rotate/offset/scale shape (0.4.23)")
check(type(WTAGarou.WolfGait.CYCLE_SLOWDOWN) == "number" and WTAGarou.WolfGait.CYCLE_SLOWDOWN >= 1, "wolf gait slowdown is a number >= 1 (0.4.22)")
local visualSrc = io.open(root .. "/42/media/lua/client/WTAGarouVisual.lua"):read("*a")
check(visualSrc:find("setSaddlebagTransform", 1, true) and visualSrc:find("setGaitSlowdown", 1, true), "Visual pushes the saddlebag transform and gait slowdown to Java with the mouth carry")
local itemsSrc = io.open(root .. "/42/media/scripts/wtagarou_items.txt"):read("*a")
check(select(2, itemsSrc:gsub("Obsolete = TRUE", "")) == 2, "both saddlebag container items are Obsolete (0.4.22)")
check(visualSrc:find("setWolfSlot", 1, true) and not visualSrc:find("setHarnessTransform", 1, true),
    "Visual preserves rigid cargo rules without pushing legacy harness transforms")
check(itemsSrc:find("item WolfHarnessVisual", 1, true) and itemsSrc:find("StaticModel = WTAGarou_Harness", 1, true), "harness stand-in item exists")
local modelsSrc = io.open(root .. "/42/media/scripts/wtagarou_models.txt"):read("*a")
check(modelsSrc:find("model WTAGarou_Harness", 1, true) and modelsSrc:find("mesh = WTAGarou/WTAGarou_Harness", 1, true), "harness model script exists")
check(io.open(root .. "/common/media/models_X/WTAGarou/WTAGarou_Harness.glb", "rb") ~= nil and io.open(root .. "/common/media/textures/WTAGarou/WTAGarou_Harness.png", "rb") ~= nil, "authored harness mesh and default texture are in the package")

print("PASS: " .. checks .. " stealth/voice/strip assertions.")
