-- 0.4.77: scattered silver ("silver caltrops") and the silver scent.
local root = assert(arg[1])
package.path = root .. "/42/media/lua/shared/?.lua;" .. root .. "/42/media/lua/server/?.lua;" .. root .. "/42/media/lua/client/?.lua;" .. package.path
local n = 0
local function check(ok, why) n = n + 1; assert(ok, why) end

-- single player by default
isServer = function() return false end
isClient = function() return false end
getTimestamp = function() return 1000 end
local clock = 1000
Events = setmetatable({}, { __index = function(t, k) t[k] = { handlers = {}, Add = function(f) table.insert(t[k].handlers, f) end }; return t[k] end })
WTAGarou = WTAGarou or {}
require "WTAGarouDefinitions"
require "WTAGarouState"
WTAGarou.NowSeconds = function() return clock end
WTAGarou.HasGarouTrait = function(p) return p.garou ~= false end
require "WTAGarouClothing"
require "WTAGarouGrant"

-- ------------------------------------------------------------ engine mocks --
local ZR = 0
ZombRand = function(a, b) if b then return a + (ZR % (b - a)) end return ZR % a end
local cellSquares = {}
local function key(x, y, z) return x .. ":" .. y .. ":" .. z end
local Square = {}; Square.__index = Square
local function newSquare(x, y, z, room)
    local s = setmetatable({ x = x, y = y, z = z, room = room, objects = {}, worldObjects = {}, movers = {}, floor = true, solid = false }, Square)
    cellSquares[key(x, y, z)] = s
    return s
end
function Square:getX() return self.x end
function Square:getY() return self.y end
function Square:getZ() return self.z end
function Square:getRoom() return self.room end
local function jlist(t) return { size = function() return #t end, get = function(_, i) return t[i + 1] end } end
function Square:getObjects() return jlist(self.objects) end
function Square:getWorldObjects() return jlist(self.worldObjects) end
function Square:getMovingObjects() return jlist(self.movers) end
function Square:getFloor() return self.floor end
function Square:isSolid() return self.solid end
function Square:isSolidTrans() return false end
function Square:AddTileObject(o) self.objects[#self.objects + 1] = o; o.square = self end
function Square:RemoveTileObject(o) for i, x in ipairs(self.objects) do if x == o then table.remove(self.objects, i) end end; self.removed = (self.removed or 0) + 1 end
function Square:transmitRemoveItemFromSquare(o) self:RemoveTileObject(o); self.transmitted = (self.transmitted or 0) + 1 end
local cell = { getGridSquare = function(_, x, y, z) return cellSquares[key(x, y, z)] end }
getCell = function() return cell end
IsoObject = { new = function(_, square, sprite)
    local o = { square = square, sprite = sprite, md = {}, sent = 0 }
    function o:getModData() return self.md end
    function o:getSquare() return self.square end
    function o:getContainer() return self.container end
    function o:transmitCompleteItemToClients() self.sent = self.sent + 1 end
    return o
end }

local function newPart(name)
    local bp = { name = name, health = 100, burn = 0, glass = false }
    function bp:getType() return self.name end
    function bp:getHealth() return self.health end
    function bp:getBurnTime() return self.burn end
    function bp:setBurnTime(v) self.burn = v end
    function bp:haveGlass() return self.glass end
    function bp:setHaveGlass(v) self.glass = v end
    function bp:haveBullet() return false end
    return bp
end
local function newPlayer(name, form, opts)
    opts = opts or {}
    local p = { name = name, garou = opts.garou, worn = {}, inv = { items = {} }, hands = {}, x = 10.5, y = 10.5, z = 0,
                md = { WTAGarou = { form = form or "Homid", isGarou = opts.garou ~= false } }, notices = {} }
    p.parts = { newPart("Hand_L"), newPart("Hand_R"), newPart("Foot_L"), newPart("Foot_R") }
    p.bd = { getBodyParts = function() return jlist(p.parts) end,
             getBodyPart = function(_, t) for _, bp in ipairs(p.parts) do if bp.name == t then return bp end end end }
    function p:getModData() return self.md end
    function p:getUsername() return self.name end
    function p:getOnlineID() return 1 end
    function p:getBodyDamage() return self.bd end
    function p:getX() return self.x end
    function p:getY() return self.y end
    function p:getZ() return self.z end
    function p:getSquare() return cellSquares[key(math.floor(self.x), math.floor(self.y), self.z)] end
    function p:getWornItems()
        local list = {}
        for _, it in ipairs(self.worn) do list[#list + 1] = { getItem = function() return it end } end
        return jlist(list)
    end
    function p:getPrimaryHandItem() return self.hands[1] end
    function p:getSecondaryHandItem() return self.hands[2] end
    function p:getInventory()
        local inv = self.inv
        inv.getItems = inv.getItems or function() return jlist(inv.items) end
        inv.AddItem = inv.AddItem or function(_, full)
            local it = { full = full, delta = 0.05, md = {} }
            function it:getFullType() return self.full end
            function it:getUseDelta() return 0.05 end
            function it:setUsedDelta(v) self.delta = v end
            function it:getUsedDelta() return self.delta end
            function it:getModData() return self.md end
            inv.items[#inv.items + 1] = it
            return it
        end
        return inv
    end
    return p
end
local function item(full, opts)
    opts = opts or {}
    local it = { full = full, md = opts.md or {}, loc = opts.loc, cond = opts.cond or 10, fluid = opts.fluid }
    function it:getFullType() return self.full end
    function it:getModData() return self.md end
    function it:getBodyLocation() return self.loc end
    function it:getCondition() return self.cond end
    function it:isFluidContainer() return self.fluid ~= nil end
    function it:getFluidContainer() return { getPrimaryFluid = function() return { getFluidTypeString = function() return it.fluid end } end } end
    return it
end

-- Silver module (burnPart/partByName/announce/markLodged) and the scatter.
WTAGarou.Silver = WTAGarou.Silver or {}
local announced = {}
require "WTAGarouSilver"
local S = WTAGarou.Silver
S.announce = function(player, part) announced[#announced + 1] = { player = player, part = part } end
local reacts = {}
WTAGarou.SilverLodgedReact = function(player, k, kind, lodged) reacts[#reacts + 1] = { player = player, key = k, kind = kind, lodged = lodged } end
local scents = {}
WTAGarou.SilverScentReact = function(player) scents[#scents + 1] = player end
require "WTAGarouScatter"
local SC = WTAGarou.Scatter
check(SC and SC.step and SC.sniff and SC.serveScatter and SC.servePickup, "scatter module loaded")

-- ------------------------------------------------------------- exposure ----
local shoes = item("Base.Shoes_Black", { loc = "Shoes" })
local homid = newPlayer("H", "Homid")
check(SC.exposed(homid, "Homid", true) == "bare", "Homid barefoot is exposed")
homid.worn = { shoes }
check(SC.exposed(homid, "Homid", true) == nil, "Homid in shoes is safe")
check(SC.exposed(homid, "Glabro", true) == nil, "Glabro in shoes is safe")
shoes.cond = 0
check(SC.exposed(homid, "Homid", true) == "bare", "worn-out shoes do not count")
shoes.cond = 10
for _, f in ipairs({ "Crinos", "Hispo", "Lupus" }) do
    check(SC.exposed(homid, f, true) == "paws", f .. " is always on paws (shoes or not)")
end
check(SC.exposed(homid, "Homid", false) == nil, "a human is never exposed")
check(WTAGarou.FormData.Glabro.allowedClothing.Shoes == true and WTAGarou.FormData.Glabro.allowedClothing.Gloves == true, "0.4.77: Glabro may wear shoes and gloves")
for _, f in ipairs({ "Crinos", "Hispo", "Lupus" }) do
    check(not WTAGarou.FormData[f].allowedClothing.Shoes, f .. " cannot wear shoes")
end

-- ---------------------------------------------------------- worked silver --
check(SC.workedSilver(item("WTAGarou.SilverFilings")) and SC.workedSilver(item("WTAGarou.SilverBullets9mm")) and SC.workedSilver(item("WTAGarou.SilverKnife")), "the mod's own items are worked silver")
check(SC.workedSilver(item("Base.Knife", { md = { WTAGarou_SilverCoat = 3 } })), "a nitrate-coated blade is worked silver")
check(not SC.workedSilver(item("Base.Knife", { md = { WTAGarou_SilverCoat = 0 } })), "a spent coat is not")
check(SC.workedSilver(item("Base.Pistol", { md = { WTAGarou_SilverAmmo = 2 } })), "a gun loaded with silver rounds is")
check(SC.workedSilver(item("Base.EmptyJar", { fluid = "WTAGarou_SilverNitrate" })) and SC.workedSilver(item("Base.EmptyJar", { fluid = "WTAGarou_SilverNitrateRaw" })), "nitrate in a vessel is")
check(not SC.workedSilver(item("Base.Ring_Silver")) and not SC.workedSilver(item("Base.Necklace_Silver", { md = {} })), "vanilla silver jewellery is NOT (no dust)")
check(not SC.workedSilver(item("Base.EmptyJar", { fluid = "Water" })) and not SC.workedSilver(nil), "water / nil are not")

-- --------------------------------------------------------------- the tile --
local roomA, roomB = { name = "A" }, { name = "B" }
for x = 0, 20 do for y = 0, 20 do newSquare(x, y, 0, (x <= 12) and roomA or roomB) end end
local here = cellSquares[key(10, 10, 0)]
check(SC.find(here) == nil and SC.place(here, 5) ~= nil and SC.find(here) ~= nil, "a tile is placed and found by its mod data")
check(SC.find(here):getModData()[SC.FLAG] == 5 and SC.find(here).sprite == SC.spriteFor(10, 10), "the object carries the filings used and the mod sprite")
-- 0.4.81: four tile variants, chosen by square so every client and reload agree
do
    local seen = {}
    for x = 0, 7 do for y = 0, 7 do seen[SC.spriteFor(x, y)] = true end end
    local n = 0; for _ in pairs(seen) do n = n + 1 end
    check(n == 4, "all four variants get used across nearby squares")
    check(SC.spriteFor(10, 10) == SC.spriteFor(10, 10) and SC.spriteFor(10, 10) ~= SC.spriteFor(11, 10), "deterministic per square, differs between neighbours")
    for i, name in ipairs(SC.SPRITES) do
        local f = io.open(root .. "/common/" .. name, "rb")
        check(f ~= nil, "variant file exists: " .. name)
        if f then
            local head = f:read(24); f:close()
            local w = head:byte(17) * 16777216 + head:byte(18) * 65536 + head:byte(19) * 256 + head:byte(20)
            local h = head:byte(21) * 16777216 + head:byte(22) * 65536 + head:byte(23) * 256 + head:byte(24)
            check(w == 128 and h == 256, name .. " is a 128x256 iso tile (" .. w .. "x" .. h .. ")")
        end
    end
end
check(SC.place(here, 5) == nil, "one tile per square")

-- ------------------------------------------------------------ the hazard ---
local wolf = newPlayer("W", "Lupus")
local wd = WTAGarou.GetData(wolf)
ZR = 1       -- ZombRand(2) -> 1 (Foot_R), ZombRand(100) -> 1 -> roll 0.01 < LODGE_CHANCE
local how, foot = SC.step(wolf, wd, wolf.bd, 0.5)
check(how == "paws" and foot == "Foot_R", "a wolf on the tile: paws, one foot picked")
check(wolf.parts[4].burn > 0 and wd.silverBurns and wd.silverBurns.Foot_R == true, "the foot is silver-burned")
check(#announced == 1 and announced[1].part == "Foot_R", "the first burn is announced (growl + HUD)")
check(wolf.parts[4].glass == true and wd.silverLodged and wd.silverLodged.Foot_R == "shard", "fragments lodged (engine haveGlass) and marked silver")
check(#reacts == 1 and reacts[1].kind == "shard" and reacts[1].lodged == true, "owner told fragments are lodged")
ZR = 51      -- ZombRand(2) -> 1 again, roll 0.51 >= LODGE_CHANCE
local burnBefore = wolf.parts[4].burn
SC.step(wolf, wd, wolf.bd, 0.5)
check(wolf.parts[4].burn >= burnBefore and #announced == 1, "staying on the tile grows the burn quietly, no new lodge")
-- step off: nothing
wolf.x = 15.5
check(SC.step(wolf, wd, wolf.bd, 0.5) == nil, "off the tile: nothing")
-- a human on it: nothing, ever
local human = newPlayer("Z", "Homid", { garou = false })
local hd = WTAGarou.GetData(human)
check(SC.step(human, hd, human.bd, 0.5) == nil and human.parts[3].burn == 0 and human.parts[4].burn == 0, "a barefoot human on the tile is untouched")
-- Homid in shoes: nothing; barefoot: burns
local man = newPlayer("M", "Homid"); man.worn = { shoes }
local md = WTAGarou.GetData(man)
check(SC.step(man, md, man.bd, 0.5) == nil, "Homid in shoes crosses the tile safely")
man.worn = {}
ZR = 0
check(SC.step(man, md, man.bd, 0.5) == "bare" and man.parts[3].burn > 0, "Homid barefoot burns a foot")
-- the lodged clock keeps the foot burning until the fragments are out
wolf.parts[4].burn = 0
check(S.lodgedStep(wolf, wd, wolf.bd, 1) == 1 and wolf.parts[4].burn >= 0.5, "lodged fragments keep the paw burning")
wolf.parts[4].glass = false
check(S.lodgedStep(wolf, wd, wolf.bd, 1) == 0 and wd.silverLodged == nil and reacts[#reacts].lodged == false and reacts[#reacts].kind == "shard", "fragments pulled: mark gone, owner told")

-- ------------------------------------------------------- scatter / pickup --
local picker = newPlayer("P", "Crinos"); picker.x = 10.5; picker.y = 11.5
check(SC.servePickup(picker, { x = 10, y = 10, z = 0 }) == true and SC.find(here) == nil and here.removed == 1, "pickup removes the tile")
check(#picker.inv.items == 1 and picker.inv.items[1].full == SC.ITEM and math.abs(picker.inv.items[1].delta - 0.25) < 1e-6, "the filings come back (5 uses)")
check((picker.parts[1].burn > 0 or picker.parts[2].burn > 0) and announced[#announced].player == picker, "a bare-handed Garou burns a hand picking it up")
local gloved = newPlayer("G", "Homid"); gloved.x = 10.5; gloved.y = 11.5; gloved.worn = { item("Base.Gloves_LeatherGloves", { loc = "Hands" }) }
SC.place(here, 5)
check(SC.servePickup(gloved, { x = 10, y = 10, z = 0 }) == true and gloved.parts[1].burn == 0 and gloved.parts[2].burn == 0, "gloves: no hand burn")
local far = newPlayer("F", "Homid"); far.x = 18.5; far.y = 18.5
check(SC.serveScatter(far, { x = 10, y = 10, z = 0 }) == false, "scatter is refused from across the room")
far.x = 11.5; far.y = 10.5
check(SC.serveScatter(far, { x = 10, y = 10, z = 0 }) == true and SC.find(here) ~= nil, "scatter next to the square places the tile")
check(SC.serveScatter(far, { x = 10, y = 10, z = 0 }) == false, "not twice")
check(SC.find(here):getModData()[SC.SOURCE_FLAG] == "filings", "a filings tile remembers its source")
-- 0.4.79: a whole unit of Silver Fragments (Base.SilverScrap) lays a tile;
-- the server takes the item by id and pickup gives the fragments back.
do
    local sq3 = cellSquares[key(12, 10, 0)]
    local scrapper = newPlayer("S", "Homid"); scrapper.x = 12.5; scrapper.y = 11.5
    local inv = scrapper:getInventory()
    local scrap = inv:AddItem("Base.SilverScrap"); scrap.id = 77
    function scrap:getID() return self.id end
    function scrap:getContainer() return inv end
    inv.getItemById = function(_, id) for _, it in ipairs(inv.items) do if it.id == id then return it end end return nil end
    inv.Remove = function(_, it) for i, x in ipairs(inv.items) do if x == it then table.remove(inv.items, i); return end end end
    local removedSent = 0
    sendRemoveItemFromContainer = function() removedSent = removedSent + 1 end
    check(SC.serveScatter(scrapper, { x = 12, y = 10, z = 0, kind = "scrap", id = 99 }) == false and SC.find(sq3) == nil, "an id the player does not own: refused, nothing placed")
    check(SC.serveScatter(scrapper, { x = 12, y = 10, z = 0, kind = "scrap", id = 77 }) == true and SC.find(sq3) ~= nil, "fragments by id: tile placed")
    check(#inv.items == 0 and removedSent == 0, "the fragments left the inventory (single player: no network removal)")
    check(SC.find(sq3):getModData()[SC.SOURCE_FLAG] == "scrap", "a fragments tile remembers its source")
    check(SC.servePickup(scrapper, { x = 12, y = 10, z = 0 }) == true and SC.find(sq3) == nil, "pickup removes the fragments tile")
    check(#inv.items == 1 and inv.items[1].full == "Base.SilverScrap", "and gives one Silver Fragments back, not filings")
    -- on a server the removal is also sent
    isServer = function() return true end
    local scrap2 = inv:AddItem("Base.SilverScrap"); scrap2.id = 78
    function scrap2:getID() return self.id end
    function scrap2:getContainer() return inv end
    inv.items = { scrap2 }
    check(SC.serveScatter(scrapper, { x = 12, y = 10, z = 0, kind = "scrap", id = 78 }) == true and removedSent == 1, "server: the fragments removal is sent to the owner")
    SC.remove(SC.find(sq3))
    isServer = function() return false end
    sendRemoveItemFromContainer = nil
end
-- MP: the server transmits
isServer = function() return true end
local sq2 = cellSquares[key(11, 11, 0)]
local placed = SC.place(sq2, 5)
check(placed.sent == 1, "server: placed tile is sent to clients")
check(SC.remove(placed) and sq2.transmitted == 1 and SC.find(sq2) == nil, "server: removal is transmitted")
isServer = function() return false end

-- ---------------------------------------------------------- the sniffer ---
local nose = newPlayer("N", "Homid"); nose.x = 5.5; nose.y = 5.5
local nd = WTAGarou.GetData(nose)
check(SC.smell(nose, "Homid") == false, "nothing worked nearby: no scent")
-- a jewellery box next door: nothing
cellSquares[key(6, 5, 0)].worldObjects = { { getItem = function() return item("Base.Ring_Silver") end } }
check(SC.smell(nose, "Homid") == false, "silver jewellery on the floor does not smell")
-- silver rounds in a crate 3 squares away in the same room
cellSquares[key(8, 5, 0)].objects = { { getContainer = function() return { getItems = function() return jlist({ item("WTAGarou.SilverBullets9mm") }) end } end, getModData = function() return {} end } }
check(SC.smell(nose, "Homid") == true, "worked silver in a container 3 squares away, same room: smelled")
cellSquares[key(8, 5, 0)].objects = {}
-- a scattered tile 5 squares away: Homid radius 3 misses it, Lupus (8) catches it
check(SC.find(here) ~= nil and SC.smell(nose, "Homid") == false, "Homid: 5 squares is out of nose range")
check(SC.smell(nose, "Lupus") == true, "Lupus: the scattered tile 5 squares away is smelled")
-- same distance through a wall (another room): nothing
nose.x = 11.5; nose.y = 15.5                       -- room A, (11,15); crate in room B at (14,15)
cellSquares[key(14, 15, 0)].objects = { { getContainer = function() return { getItems = function() return jlist({ item("WTAGarou.SilverFilings") }) end } end, getModData = function() return {} end } }
SC.remove(SC.find(here))
check(SC.openToAir(cellSquares[key(11, 15, 0)], cellSquares[key(14, 15, 0)]) == false, "another room is not open to the same air")
check(SC.smell(nose, "Lupus") == false, "filings behind a wall: nothing")
nose.x = 13.5                                        -- step into room B
check(SC.smell(nose, "Lupus") == true, "step into the room: smelled")
-- another player carrying a silvered knife
cellSquares[key(14, 15, 0)].objects = {}
local carrier = newPlayer("C", "Homid"); carrier.x = 15.5; carrier.y = 15.5; carrier.hands = { item("Base.HuntingKnife", { md = { WTAGarou_SilverCoat = 2 } }) }
cellSquares[key(15, 15, 0)].movers = { carrier }
check(SC.smell(nose, "Homid") == true, "a nearby player holding a coated knife is smelled (not where, just near)")
-- the warning clock: first contact, then every SCENT_REPEAT, reset by clean air
clock = 2000
check(SC.sniff(nose, nd, clock) == true and #scents == 1, "first contact warns")
clock = clock + SC.SCENT_INTERVAL
check(SC.sniff(nose, nd, clock) == false and #scents == 1, "still there: no spam")
clock = clock + SC.SCENT_REPEAT
check(SC.sniff(nose, nd, clock) == true and #scents == 2, "repeats after SCENT_REPEAT while it lingers")
-- 0.4.79: a flicker of clean air (a door frame, a step round a corner) is
-- not "walked back into it"; the smell must be gone SCENT_CLEAR seconds,
-- and two warnings are never closer than SCENT_MIN_GAP.
cellSquares[key(15, 15, 0)].movers = {}
clock = clock + SC.SCENT_INTERVAL
check(SC.sniff(nose, nd, clock) == false and nd.scentAt ~= nil, "one clean sniff does not reset the clock")
cellSquares[key(15, 15, 0)].movers = { carrier }
clock = clock + SC.SCENT_INTERVAL
check(SC.sniff(nose, nd, clock) == false and #scents == 2, "back in the smell right away: no new warning (this was the spam)")
cellSquares[key(15, 15, 0)].movers = {}
clock = clock + SC.SCENT_INTERVAL
SC.sniff(nose, nd, clock)
clock = clock + SC.SCENT_CLEAR
check(SC.sniff(nose, nd, clock) == false and nd.scentLost == true, "clean for SCENT_CLEAR: the contact is over")
clock = clock + SC.SCENT_MIN_GAP
SC.sniff(nose, nd, clock)
cellSquares[key(15, 15, 0)].movers = { carrier }
clock = clock + SC.SCENT_INTERVAL
check(SC.sniff(nose, nd, clock) == true and #scents == 3, "walking back into it after a real absence warns again")
-- the minimum gap: warned, out for SCENT_CLEAR, back in, all inside SCENT_MIN_GAP
check(SC.SCENT_MIN_GAP > SC.SCENT_CLEAR, "the gap outlasts the clear time, so a quick out-and-in cannot warn twice")
cellSquares[key(15, 15, 0)].movers = {}
clock = clock + SC.SCENT_INTERVAL; SC.sniff(nose, nd, clock)
clock = clock + SC.SCENT_CLEAR; SC.sniff(nose, nd, clock)
cellSquares[key(15, 15, 0)].movers = { carrier }
clock = clock + SC.SCENT_INTERVAL
check(SC.sniff(nose, nd, clock) == false and #scents == 3, "back inside SCENT_MIN_GAP of the last warning: held")
clock = clock + SC.SCENT_MIN_GAP
check(SC.sniff(nose, nd, clock) == true and #scents == 4, "the held warning fires once the gap has passed")
check(SC.sniff(human, hd, clock + 10) == false, "humans have no nose for it")
-- one warning per sniff however many silver things are near
cellSquares[key(14, 15, 0)].objects = { { getContainer = function() return { getItems = function() return jlist({ item("WTAGarou.SilverFilings"), item("WTAGarou.SilverBullets9mm"), item("WTAGarou.SilverFilings") }) end } end, getModData = function() return {} end } }
clock = clock + SC.SCENT_REPEAT
check(SC.sniff(nose, nd, clock) == true and #scents == 5, "three silver things and a carrier: one warning")
cellSquares[key(14, 15, 0)].objects = {}
-- 0.4.79: air through the engine's line test. Clear and open doors pass;
-- a window only when open or smashed; closed doors and walls do not.
do
    local result = "Clear"
    -- tostring on the Java enum gives its name; mimic with __tostring
    local function enum(name) return setmetatable({}, { __tostring = function() return name end }) end
    LosUtil = { lineClear = function() return enum(result) end }
    local a, b = cellSquares[key(11, 15, 0)], cellSquares[key(14, 15, 0)]
    check(SC.openToAir(a, b) == true, "line test Clear: open to air even across the room boundary")
    result = "ClearThroughOpenDoor"
    check(SC.openToAir(a, b) == true, "through an open door: open to air")
    result = "ClearThroughClosedDoor"
    check(SC.openToAir(a, b) == false, "through a closed door: not")
    result = "Blocked"
    check(SC.openToAir(a, b) == false, "blocked: not")
    result = "ClearThroughWindow"
    check(SC.openToAir(a, b) == false, "through a window with no window object found: treated as shut")
    local win = { open = false, IsOpen = function(self) return self.open end, isDestroyed = function() return false end }
    cellSquares[key(12, 15, 0)].getWindowTo = function(self, next) if next == cellSquares[key(13, 15, 0)] then return win end return nil end
    check(SC.openToAir(a, b) == false, "a shut window on the line: not")
    win.open = true
    check(SC.openToAir(a, b) == true, "the same window open: air comes through")
    win.open = false; win.isDestroyed = function() return true end
    check(SC.openToAir(a, b) == true, "a smashed window: air comes through")
    cellSquares[key(12, 15, 0)].getWindowTo = nil
    local pts = SC.linePoints(0, 0, 3, 1)
    check(#pts == 4 and pts[1][1] == 0 and pts[4][1] == 3 and pts[4][2] == 1, "line points run from the first square to the last")
    LosUtil = nil
    check(SC.openToAir(a, b) == false, "without the engine test the room test stands in")
end
check(SC.SCENT_RADIUS.Lupus > SC.SCENT_RADIUS.Hispo and SC.SCENT_RADIUS.Hispo > SC.SCENT_RADIUS.Crinos and SC.SCENT_RADIUS.Crinos > SC.SCENT_RADIUS.Homid, "the wolf noses reach further")

print("PASS: " .. n .. " scattered-silver / scent assertions.")
