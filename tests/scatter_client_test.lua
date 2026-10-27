-- 0.4.79: the scatter right-click options (client/WTAGarouScatterClient.lua).
-- Oct 21 playtest: no scatter option anywhere. Fragments (Base.SilverScrap)
-- and filings both offer it, on the world menu AND on the item's inventory
-- menu; the handler reports instead of vanishing; the command carries kind
-- and (for fragments) the item id, never the item.
local root = assert(arg[1])
package.path = root .. "/42/media/lua/shared/?.lua;" .. root .. "/42/media/lua/client/?.lua;" .. package.path
local n = 0
local function check(ok, why) n = n + 1; assert(ok, why) end
isServer = function() return false end
isClient = function() return true end           -- a multiplayer client
getTimestamp = function() return 1000 end
Events = setmetatable({}, { __index = function(t, k) t[k] = { Add = function(fn) t[k].fn = fn end }; return t[k] end })
WTAGarou = WTAGarou or {}
WTAGarou.HasGarouTrait = function(p) return p.garou ~= false end

-- the server module's surface the client uses
local tiles = {}
WTAGarou.Scatter = {
    ITEM = "WTAGarou.SilverFilings", SCRAP_ITEM = "Base.SilverScrap", COST_USES = 5,
    CMD_SCATTER = "ScatterSilver", CMD_PICKUP = "PickupSilverScatter",
    find = function(sq) return tiles[sq] end,
}
local sent = {}
WTAGarou.Net = { ToServer = function(player, cmd, args) sent[#sent + 1] = { cmd = cmd, args = args } end }
local printed = {}
local realPrint = print
print = function(s) printed[#printed + 1] = tostring(s) end

local C = require "WTAGarouScatterClient"

local function jlist(t) return { size = function() return #t end, get = function(_, i) return t[i + 1] end } end
local function item(full, uses, id)
    local it = { full = full, uses = uses or 20, id = id or 1, container = {} , used = 0 }
    function it:getFullType() return self.full end
    function it:getCurrentUses() return self.uses end
    function it:getID() return self.id end
    function it:getContainer() return self.container end
    function it:Use() self.uses = self.uses - 1; self.used = self.used + 1 end
    return it
end
local function square(x, y)
    local sq = { x = x, y = y, solid = false, floor = true }
    function sq:getX() return self.x end
    function sq:getY() return self.y end
    function sq:getZ() return 0 end
    function sq:isSolid() return self.solid end
    function sq:isSolidTrans() return false end
    function sq:getFloor() return self.floor and {} or nil end
    return sq
end
local here, there = square(10, 10), square(11, 10)
local function player(items)
    local p = { items = items or {}, dead = false }
    function p:isDead() return self.dead end
    function p:getCurrentSquare() return here end
    function p:getZ() return 0 end
    function p:getInventory()
        local inv = {}
        function inv:getAllTypeRecurse(full)
            local out = {}
            for _, it in ipairs(p.items) do if it.full == full then out[#out + 1] = it end end
            return jlist(out)
        end
        return inv
    end
    return p
end
local me
getSpecificPlayer = function(i) return me end
local function menu()
    local m = { options = {} }
    function m:addOption(name, target, fn, a, b) local o = { name = name, target = target, fn = fn, a = a, b = b }; self.options[#self.options + 1] = o; return o end
    return m
end

check(Events.OnFillWorldObjectContextMenu.fn == C.fillWorldMenu and Events.OnFillInventoryObjectContextMenu.fn == C.fillInventoryMenu, "world and inventory menus registered")

-- kinds
check(C.kindOf(item("Base.SilverScrap")) == "scrap", "Silver Fragments scatter")
check(C.kindOf(item("WTAGarou.SilverFilings", 20)) == "filings" and C.kindOf(item("WTAGarou.SilverFilings", 4)) == nil, "filings need COST_USES left")
check(C.kindOf(item("Base.Nails")) == nil and C.kindOf(nil) == nil, "anything else does not")

-- world menu: both items -> both options; a tile -> pick up
me = player({ item("Base.SilverScrap", nil, 7), item("WTAGarou.SilverFilings", 20, 8) })
local m = menu()
C.fillWorldMenu(0, m, { { getSquare = function() return there end } }, false)
check(#m.options == 2 and m.options[1].name == C.LABEL.scrap and m.options[2].name == C.LABEL.filings, "fragments and filings each offer a scatter option")
check(m.options[1].a == there and m.options[1].b.full == "Base.SilverScrap", "the option carries the clicked square and the item")
check(m.options[1].toolTip ~= nil or ISToolTip == nil, "tooltip when the tooltip class exists")
m = menu(); C.fillWorldMenu(0, m, { { getSquare = function() return there end } }, true)
check(#m.options == 0, "the test pass adds nothing")
tiles[there] = { tile = true }
m = menu(); C.fillWorldMenu(0, m, { { getSquare = function() return there end } }, false)
check(#m.options == 1 and m.options[1].name == C.LABEL.pickup, "a scattered tile offers pick up")
tiles[there] = nil
there.solid = true
m = menu(); C.fillWorldMenu(0, m, { { getSquare = function() return there end } }, false)
check(#m.options == 0, "a solid square cannot be scattered on")
there.solid = false
-- no objects clicked: the square under the cursor is used
screenToIsoX = function() return 11.4 end
screenToIsoY = function() return 10.2 end
getCell = function() return { getGridSquare = function(_, x, y, z) if x == 11 and y == 10 then return there end end } end
m = menu(); m.x = 0; m.y = 0
C.fillWorldMenu(0, m, {}, false)
check(#m.options == 2, "no clicked object: the square under the cursor still gets the options")
-- an error inside is reported once, not swallowed
local goodInv = me.getInventory
me.getInventory = function() error("boom: no inventory") end
m = menu(); C.fillWorldMenu(0, m, { { getSquare = function() return there end } }, false)
check(#printed >= 1 and printed[#printed]:find("%[WTAGarou%]%[Scatter%]") and printed[#printed]:find("boom"), "a failing lookup prints a [WTAGarou][Scatter] line: " .. tostring(printed[#printed]))
local before = #printed
C.fillWorldMenu(0, menu(), { { getSquare = function() return there end } }, false)
check(#printed == before, "the same failure is reported once")
me.getInventory = goodInv
local badCtx = setmetatable({}, { __index = function(_, k) if k == "addOption" then error("boom: context") end end })
C.fillWorldMenu(0, badCtx, { { getSquare = function() return there end } }, false)
check(#printed == before + 1 and printed[#printed]:find("world menu"), "a failing handler body is reported as the world menu")

-- inventory menu: right-click the fragments -> scatter on the player's own square
me = player({ item("Base.SilverScrap", nil, 7) })
m = menu()
C.fillInventoryMenu(0, m, { me.items[1] })
check(#m.options == 1 and m.options[1].name == C.LABEL.scrap and m.options[1].a == here, "inventory menu on the fragments: scatter here")
m = menu()
C.fillInventoryMenu(0, m, { { items = { item("WTAGarou.SilverFilings", 20, 8) } } })
check(#m.options == 1 and m.options[1].name == C.LABEL.filings, "a stack entry ({items={...}}) works too")
m = menu()
C.fillInventoryMenu(0, m, { item("Base.Nails") })
check(#m.options == 0, "other items: nothing")
tiles[here] = { tile = true }
m = menu(); C.fillInventoryMenu(0, m, { me.items[1] })
check(#m.options == 0, "standing on a scattered tile: no second scatter from the inventory")
tiles[here] = nil

-- the command: fragments by id, never the item; filings drained here
luautils = { walkAdj = function() return true end }
ISBaseTimedAction = nil; ISTimedActionQueue = nil     -- immediate path
local scrap = item("Base.SilverScrap", nil, 77)
C.onScatter(me, there, scrap)
check(sent[#sent].cmd == "ScatterSilver" and sent[#sent].args.kind == "scrap" and sent[#sent].args.id == 77 and sent[#sent].args.x == 11, "fragments: ScatterSilver with kind=scrap and the item id")
for k, v in pairs(sent[#sent].args) do check(type(v) ~= "table", "no table/object in the command (" .. k .. ")") end
check(scrap.used == 0, "fragments are not drained on the client (the server takes the item)")
local filings = item("WTAGarou.SilverFilings", 20, 8)
C.onScatter(me, there, filings)
check(sent[#sent].args.kind == "filings" and sent[#sent].args.id == nil and filings.used == 5, "filings: drained 5 uses here, no id needed")
C.onPickup(me, there)
check(sent[#sent].cmd == "PickupSilverScatter" and sent[#sent].args.x == 11, "pick up command")

print = realPrint
print("PASS: " .. n .. " scatter client menu/command assertions.")
