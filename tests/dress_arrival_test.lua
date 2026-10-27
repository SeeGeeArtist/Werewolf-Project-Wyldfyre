-- 0.4.75: Dress in multiplayer. ISGrabItemAction only asks the server for a
-- floor item (vanilla transferItem returns at once when isClient()), so the
-- wear must wait until the item lands in the inventory. Pure step test.
local root = assert(arg[1], "supply WTAGarou directory")
package.path = root .. "/42/media/lua/shared/?.lua;" .. root .. "/42/media/lua/client/?.lua;" .. package.path
local checks = 0
local function check(ok, message) checks = checks + 1; assert(ok, message) end
WTAGarou = WTAGarou or {}
local notices = {}
WTAGarou.HUD = { instance = { pushNotice = function(_, t) notices[#notices + 1] = t end } }
Events = { OnTick = { Add = function() end } }
require "WTAGarouDress"
local Dress = WTAGarou.Dress

local arrivals = {}
Dress.awaitArrival = Dress.awaitArrival
local now = 1000
local inv = {}
local worn = {}
local function lookup(id) return inv[id] end
local function wear(item, a) worn[#worn + 1] = a.name end
arrivals[#arrivals + 1] = { id = 11, name = "Hoodie", at = now }
arrivals[#arrivals + 1] = { id = 12, name = "Jeans", at = now }
local w, e = Dress.arrivalStep(arrivals, now + 0.5, lookup, wear)
check(w == 0 and e == 0 and #arrivals == 2, "nothing has arrived yet: both still waiting")
inv[12] = { name = "Jeans" }
w, e = Dress.arrivalStep(arrivals, now + 1, lookup, wear)
check(w == 1 and worn[1] == "Jeans" and #arrivals == 1 and arrivals[1].id == 11, "the item that landed is worn; the other keeps waiting")
w, e = Dress.arrivalStep(arrivals, now + Dress.ARRIVAL_TIMEOUT + 1, lookup, wear)
check(w == 0 and e == 1 and #arrivals == 0 and notices[1]:find("Hoodie never arrived"), "a lost item is written off with a notice after the timeout")
check(Dress.ARRIVAL_TIMEOUT >= 5, "timeout leaves room for a slow server reply")

-- 0.4.82: one floor grab at a time (merged ISGrabItemActions finish after
-- their first item in multiplayer).
getTimestampMs = function() return now * 1000 end
Dress.arrivals = {}
Dress.floorPending = {}
check(Dress.floorBusy() == false, "idle with nothing awaited")
Dress.awaitArrival(21, "Shirt", now)
Dress.awaitArrival(21, "Shirt", now + 1)
check(#Dress.arrivals == 1 and Dress.arrivals[1].at == now + 1, "the same id is never awaited twice (refreshes its clock)")
check(Dress.floorBusy() == true, "busy while a floor item is awaited")
Dress.deferFloor(22, "Pants"); Dress.deferFloor(23, "Hoodie"); Dress.deferFloor(22, "Pants")
check(#Dress.floorPending == 2 and Dress.floorPending[1].id == 22, "deferred items keep order, no duplicates")

local world = { [22] = { name = "Pants", where = "floor" }, [23] = { name = "Hoodie", where = "inventory" } }
local grabbed, wornNow = {}, {}
local function find(id) local w = world[id]; if not w then return nil end; return w, w.where, w.where == "floor" and { world = true } or nil end
local function grab(item, worldItem) grabbed[#grabbed + 1] = item.name; check(worldItem and worldItem.world, "grab gets the world object") end
local function wearNow(item) wornNow[#wornNow + 1] = item.name end
Dress.arrivals = {}
local what, f = Dress.nextFloor(find, grab, wearNow, function() return false end)
check(what == "grab" and f.id == 22 and grabbed[1] == "Pants" and #Dress.arrivals == 1 and Dress.arrivals[1].id == 22,
    "next floor item is grabbed and awaited; one at a time")
check(#Dress.floorPending == 1 and Dress.floorPending[1].id == 23, "the rest keep waiting")
Dress.arrivals = {}
what, f = Dress.nextFloor(find, grab, wearNow, function() return false end)
check(what == "wear" and wornNow[1] == "Hoodie" and #Dress.arrivals == 0, "an item that reached the inventory meanwhile is simply worn")
check(#Dress.floorPending == 0 and Dress.nextFloor(find, grab, wearNow) == nil, "empty list: nothing to do")
Dress.deferFloor(99, "Ghost")
local n0 = #notices
check(Dress.nextFloor(find, grab, wearNow) == nil and #Dress.floorPending == 0 and notices[n0 + 1]:find("Ghost is not in your inventory"),
    "a vanished deferred item is reported and skipped")
check(Dress.MISS_LIMIT == 3, "three Dress presses before an unfound id is forgotten")

print("PASS: " .. checks .. " dress arrival assertions.")
