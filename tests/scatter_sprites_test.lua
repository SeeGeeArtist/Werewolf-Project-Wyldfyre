-- 0.4.82: scattered-silver tile sprites are registered with fixed ids on
-- both sides, survive the engine's sprite-manager wipe, and already-placed
-- id-less tiles are repaired by the server.
local root = arg[1] or "."
package.path = root .. "/42/media/lua/shared/?.lua;" .. root .. "/42/media/lua/server/?.lua;" .. package.path

local checks = 0
local function check(cond, msg)
    checks = checks + 1
    if not cond then error("FAIL: " .. msg, 2) end
end

-- Fake engine ------------------------------------------------------------
local printed = {}
local realPrint = print
print = function(s) printed[#printed + 1] = tostring(s) end

Events = setmetatable({}, { __index = function(t, k)
    t[k] = { handlers = {}, Add = function(f) table.insert(t[k].handlers, f) end }
    return t[k]
end })

local UNSET = 20000000
local function newManager()
    local m = { named = {}, ints = {} }
    local function newSprite(path, id)
        local s = { path = path, id = id or UNSET, name = nil }
        function s:getID() return self.id end
        function s:getName() return self.name end
        function s:setName(n) self.name = n end
        s.flags = {}
        function s:getProperties()
            local spr = self
            return { set = function(_, f) spr.flags[f] = true end }
        end
        return s
    end
    function m:AddSprite(path, id)
        if id == nil then
            local s = newSprite(path); self.named[path] = s; return s
        end
        local s = newSprite(path, id)
        if self.named[path] then id = self.named[path].id end
        self.named[path] = s; s.id = id; self.ints[id] = s
        return s
    end
    function m:getSprite(path)
        return self.named[path] or self:AddSprite(path)
    end
    function m:Dispose() self.named = {}; self.ints = {} end
    return m
end
IsoSpriteManager = { instance = newManager() }
IsoSprite = { getSprite = function(manager, id) return manager.ints[id] end }

require "WTAGarouScatterSprites"
local SS = WTAGarou.ScatterSprites

-- Ids follow the engine's tile formula, far above any real sheet.
check(SS.ID_BASE == 786956288, "id base = 1048576 + 2998*262144 (" .. tostring(SS.ID_BASE) .. ")")
check(#SS.PATHS == 4 and SS.idFor(4) == SS.ID_BASE + 3, "four consecutive ids")
check(SS.isScatterSpriteName(SS.PATHS[2]) and not SS.isScatterSpriteName("floors_rugs_01_0") and not SS.isScatterSpriteName(nil),
    "scatter sprite name test")

-- File load registered everything in the live manager, with names.
check(SS.registered(), "registered at file load")
local m = IsoSpriteManager.instance
for i, p in ipairs(SS.PATHS) do
    check(m.ints[SS.idFor(i)] and m.ints[SS.idFor(i)].path == p, "id " .. SS.idFor(i) .. " -> " .. p)
    check(m.named[p]:getName() == p, "sprite name set for " .. p)
end
check(m:getSprite(SS.PATHS[1]):getID() == SS.ID_BASE, "getSprite(path) now returns the id'd sprite (what IsoObject.new uses)")

-- IsoWorld.init wipes the manager, then fires OnLoadedTileDefinitions.
m:Dispose()
check(not SS.registered(), "a disposed manager is detected (no stale Lua flag)")
for _, f in ipairs(Events.OnLoadedTileDefinitions.handlers) do f(m) end
check(SS.registered(), "OnLoadedTileDefinitions re-registers")

-- ensure() is idempotent and quiet once registered.
local before = #printed
check(SS.ensure() == true, "ensure true")
check(#printed == before, "ensure does not re-register when ids resolve")

-- 0.4.99: every registered variant is a FloorOverlay (flat floor depth in
-- B42, so it draws under a character standing on it).
IsoFlagType = { FloorOverlay = "FLAG_FloorOverlay" }
m:Dispose(); SS.register(m)
for i, path in ipairs(SS.PATHS) do
    check(m.named[path].flags["FLAG_FloorOverlay"] == true, "variant " .. i .. " flagged FloorOverlay")
end
IsoFlagType = nil
m:Dispose(); SS.register(m)
check(m.named[SS.PATHS[1]].flags["FloorOverlay"] == true, "string fallback when IsoFlagType is not exposed")
check(SS.markFloorOverlay({}) == false, "a sprite without properties is skipped, no error")

-- ensure() repairs a wiped manager (lazy path for a late event).
m:Dispose()
check(SS.ensure() == true and SS.registered(), "ensure re-registers after a wipe")

-- An id-less duplicate made before us is reported, not hidden.
m:Dispose()
m:AddSprite(SS.PATHS[3])                       -- someone called getSprite(path) first
local ok = SS.register(m)
check(ok == false, "register reports the id-less duplicate")
check(printed[#printed]:find("already registered with id " .. UNSET, 1, true), "console names the stale id")

-- Server-side repair of a tile placed by 0.4.77..0.4.81 ---------------------
m:Dispose(); SS.register(m)
package.path = root .. "/42/media/lua/server/?.lua;" .. package.path
isServer = function() return true end
isClient = function() return false end
getCell = function() return {} end
WTAGarou.GetData = WTAGarou.GetData or function() return {} end
IsoObject = { new = function(_, square, sprite)
    local o = { square = square, spriteName = sprite, md = {}, sent = 0, spriteUpdates = 0 }
    function o:getModData() return self.md end
    function o:getSquare() return self.square end
    function o:getSprite() return self.sprite end
    function o:setSprite(name) self.spriteName = name; self.sprite = { getID = function() return UNSET end, getName = function() return nil end }; self.rawSets = (self.rawSets or 0) + 1 end  -- the engine's String overload: a fresh id-less sprite
    function o:setSpriteFromName(name) self.spriteName = name; self.sprite = m:getSprite(name) end
    function o:transmitCompleteItemToClients() self.sent = self.sent + 1 end
    function o:transmitUpdatedSpriteToClients() self.spriteUpdates = self.spriteUpdates + 1 end
    return o
end }
local function Square(x, y, objs)
    local s = { x = x, y = y, objs = objs or {} }
    function s:getX() return self.x end
    function s:getY() return self.y end
    function s:getZ() return 0 end
    function s:getObjects() return { size = function() return #self.objs end, get = function(_, i) return self.objs[i + 1] end } end
    function s:AddTileObject(o) table.insert(self.objs, o) end
    return s
end
require "WTAGarouScatter"
local SC = WTAGarou.Scatter
check(SC.SPRITES == SS.PATHS, "scatter module shares the registered path list")

-- A healthy tile is left alone.
local sq = Square(10, 10)
local obj = SC.place(sq, 5, "filings")
obj.sprite = m:getSprite(obj.spriteName)        -- the real engine resolves the name on construction
obj.rawSets = 0
check(obj and obj.spriteName == SC.spriteFor(10, 10) and obj.sprite:getID() ~= UNSET, "placed tile uses a registered sprite")
check(SC.find(sq) == obj and obj.spriteUpdates == 0, "find leaves a registered sprite alone")

-- An old tile: id-less sprite (what the saved AddItemToMap carried as 20000000).
local old = IsoObject.new(nil, sq, nil)
old.sprite = { getID = function() return UNSET end, getName = function() return nil end }
old.md[SC.FLAG] = 5
local sq2 = Square(11, 10, { old })
check(SC.find(sq2) == old, "old tile still found by mod data")
check(old.spriteName == SC.spriteFor(11, 10) and old.spriteUpdates == 1, "old tile re-sprited for its square and sent to clients")
check(printed[#printed]:find("repaired an id-less tile sprite at 11,10,0", 1, true), "repair is logged")
check(SC.find(sq2) == old and old.spriteUpdates == 1, "repair happens once")
check((old.rawSets or 0) == 0, "repair never uses setSprite(String), which would make another id-less sprite and loop forever")

-- A client never touches it.
isClient = function() return true end
local old2 = IsoObject.new(nil, sq, nil)
old2.sprite = { getID = function() return UNSET end, getName = function() return nil end }
old2.md[SC.FLAG] = 5
SC.find(Square(12, 10, { old2 }))
check(old2.spriteUpdates == 0 and old2.spriteName == nil, "client leaves an old tile alone")

print = realPrint
print("PASS: " .. checks .. " scatter sprite registration assertions.")
