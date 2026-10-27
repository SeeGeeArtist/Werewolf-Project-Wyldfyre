-- Multiplayer item ownership regression test (0.4.66).
-- Build 42 MP inventories are server-owned. This loads the real Grant,
-- Clothing, Wardrobe, SilverAmmo, Adapters and NitrateSync files against
-- small mocks and checks:
--   * kits create items directly in single player, but a remote client only
--     sends GrantItems and the server creates + sendAddItemToContainer;
--   * the server strips forbidden clothing with the networked drop path and
--     ships a `strip` summary (with Wardrobe entries) the client presents;
--   * nitrate reports are absolute, bounded, and applied with sendItemStats;
--   * CharacterTrait lookups never pass a bare string; craft recipes are
--     found under the module-qualified name.
local root = arg[1] or "."
local checks = 0
local function check(v, why) checks = checks + 1; if not v then error("FAIL: " .. why, 2) end end

-- ---------------------------------------------------------------- mocks ----
local MODE = "sp" -- "sp" | "client" | "server"
isClient = function() return MODE == "client" end
isServer = function() return MODE == "server" end
Events = setmetatable({}, { __index = function(t, k)
    t[k] = { handlers = {}, Add = function(f) table.insert(t[k].handlers, f) end }; return t[k] end })
ZombRand = function(n) return 0 end
instanceof = function() return false end
getTimestampMs = function() return 0 end
function require(_) end
local printed = {}
local realPrint = print
print = function(...) local parts = {} for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    printed[#printed + 1] = table.concat(parts, " ") end

local scripts = { ["Base.Fertilizer"] = true, ["Base.Coldpack"] = true, ["Base.Pistol"] = true, ["Base.Shirt"] = true, ["Base.EmptyJar"] = true }
getScriptManager = function() return { FindItem = function(_, full) return scripts[full] and { name = full } or nil end } end
local netSent = {}
local synced = { add = {}, remove = {}, stats = {}, visuals = 0, equip = 0 }
sendAddItemToContainer = function(inv, item) table.insert(synced.add, item) end
sendRemoveItemFromContainer = function(inv, item) table.insert(synced.remove, item) end
sendItemStats = function(item) table.insert(synced.stats, item) end
syncVisuals = function(p) synced.visuals = synced.visuals + 1 end
sendEquip = function(p) synced.equip = synced.equip + 1 end
getDebug = function() return false end

local nextId = 100
local function Item(full, opts)
    opts = opts or {}
    nextId = nextId + 1
    local it = { full = full, id = nextId, cond = opts.cond or 10, md = {}, worldDropped = false }
    function it:getFullType() return self.full end
    function it:getID() return self.id end
    function it:getDisplayName() return self.full end
    function it:getName() return self.full end
    function it:getModData() return self.md end
    function it:getCondition() return self.cond end
    function it:setCondition(c) self.cond = c end
    function it:getCoveredParts() return nil end
    function it:getVisual() return nil end
    function it:getBodyLocation() return self.loc end
    function it:getContainer() return nil end
    function it:isFluidContainer() return opts.fc ~= nil end
    function it:getFluidContainer() return opts.fc end
    return it
end
local function Inventory()
    local inv = { items = {} }
    function inv:AddItem(full)
        if not scripts[full] then return nil end
        local opts = nil
        if full == "Base.EmptyJar" then
            local fc = { amounts = {} , cap = 1.0 }
            function fc:addFluid(f, v) self.amounts[f.key] = (self.amounts[f.key] or 0) + v end
            function fc:getCapacity() return self.cap end
            function fc:getSpecificFluidAmount(f) return self.amounts[f.key] or 0 end
            opts = { fc = fc }
        end
        local it = Item(full, opts); table.insert(self.items, it); return it
    end
    function inv:Remove(item) for i, it in ipairs(self.items) do if it == item then table.remove(self.items, i) end end end
    function inv:getItems() return { size = function() return #inv.items end, get = function(_, i) return inv.items[i + 1] end } end
    return inv
end
local function Player(name, level)
    local p = { name = name, level = level or "None", inv = Inventory(), worn = {}, md = {}, hands = {} }
    function p:getInventory() return self.inv end
    function p:getUsername() return self.name end
    function p:getAccessLevel() return self.level end
    function p:getModData() return self.md end
    function p:getWornItems()
        local list = self.worn
        return { size = function() return #list end, get = function(_, i) return { getItem = function() return list[i + 1] end, getLocation = function() return list[i + 1].loc end } end }
    end
    function p:removeWornItem(item) for i, it in ipairs(self.worn) do if it == item then table.remove(self.worn, i) end end end
    function p:getPrimaryHandItem() return self.hands.primary end
    function p:getSecondaryHandItem() return self.hands.secondary end
    function p:setPrimaryHandItem(i) self.hands.primary = i end
    function p:setSecondaryHandItem(i) self.hands.secondary = i end
    function p:getCurrentSquare() return self.square end
    function p:resetModelNextFrame() self.modelReset = (self.modelReset or 0) + 1 end
    function p:isFemale() return false end
    p.square = { AddWorldInventoryItem = function(_, item, x, y, z, b)
        item.worldDropped = true
        return { getWorldItem = function() return { transmitCompleteItemToClients = function() item.transmitted = true end } end }
    end }
    return p
end

WTAGarou = WTAGarou or {}
WTAGarou.Net = {
    ToServer = function(p, cmd, args) table.insert(netSent, { to = "server", cmd = cmd, args = args, player = p }) end,
    ToClient = function(p, cmd, args) table.insert(netSent, { to = "client", cmd = cmd, args = args, player = p }) end,
    RegisterClientHandler = function() end, RegisterServerHandler = function() end,
    IsSinglePlayer = function() return MODE == "sp" end,
}
WTAGarou.LocalPlayers = function() return {} end

dofile(root .. "/42/media/lua/shared/WTAGarouDefinitions.lua")
dofile(root .. "/42/media/lua/shared/WTAGarouAccess.lua")   -- 0.4.83: Grant's server policy
dofile(root .. "/42/media/lua/shared/WTAGarouGrant.lua")
dofile(root .. "/42/media/lua/shared/WTAGarouAudio.lua")
dofile(root .. "/42/media/lua/shared/WTAGarouWardrobe.lua")
dofile(root .. "/42/media/lua/shared/WTAGarouClothing.lua")
dofile(root .. "/42/media/lua/shared/WTAGarouSilverAmmo.lua")
dofile(root .. "/42/media/lua/shared/WTAGarouAdapters.lua")
dofile(root .. "/42/media/lua/client/WTAGarouNitrateSync.lua")
dofile(root .. "/42/media/lua/server/WTAGarouNitrateServer.lua")
WTAGarou.Audio.play = function() return 1, {} end

local G = WTAGarou.Grant
local S = WTAGarou.SilverAmmo

-- ================================================================ Grant ====
-- Single player: created on the spot.
MODE = "sp"
local sp = Player("solo")
local b = G.begin(sp, "silver kit")
local first = G.add(b, "Base.Fertilizer", 1)
G.add(b, "Base.Coldpack", 2)
G.add(b, "Base.NotAThing", 1)
check(first and first.full == "Base.Fertilizer", "SP add returns the created item")
check(#sp.inv.items == 3 and b.added == 3, "SP: three items in the inventory")
check(#b.missing == 1 and b.missing[1] == "Base.NotAThing", "SP: unknown script reported missing, never raised")
check(G.commit(b):find("3 item%(s%) added"), "SP commit describes the count")
check(#netSent == 0 and #synced.add == 0, "SP: nothing on the wire, no server sync calls")

-- Remote client: nothing local, one command.
MODE = "client"
local cl = Player("deck")
b = G.begin(cl, "firearm kit")
check(b.remote == true, "a client of a real server is remote")
check(G.add(b, "Base.Pistol", 1) == nil and G.add(b, "Base.Fertilizer", 2) == nil, "remote add returns nil (item not in hand yet)")
check(#cl.inv.items == 0, "remote client creates nothing locally")
local msg = G.commit(b)
check(#netSent == 1 and netSent[1].cmd == "GrantItems" and netSent[1].to == "server", "remote commit sends exactly one GrantItems")
check(netSent[1].args.reason == "firearm kit" and #netSent[1].args.items == 2 and netSent[1].args.items[2].count == 2, "payload carries reason, types and counts")
check(msg:find("requested from the server"), "remote commit says the items are server-made")
-- per-request cap
b = G.begin(cl, "flood")
check(G.add(b, "Base.Pistol", G.MAX_ITEMS + 1) == nil and #b.missing == 1 and b.missing[1]:find("cap"), "over-cap request is refused client-side")

-- Server: policy and creation.
MODE = "server"
netSent = {}
local sv = Player("deck", "user")      -- 0.4.83: B42's default role for every player
local n = G.serve(sv, netSent[1] and netSent[1].args or { reason = "firearm kit", items = { { type = "Base.Pistol", count = 1 }, { type = "Base.Fertilizer", count = 2 } } })
check(n == 0 and #sv.inv.items == 0, "non-debug server refuses an ordinary 'user' role player")
check(#netSent == 1 and netSent[1].cmd == "GrantItemsDone" and netSent[1].args.denied == true, "refusal is answered with denied=true")
check(G.describeReply(netSent[1].args):find("refused"), "client text explains the refusal")
netSent = {}
local admin = Player("host", "admin")
n = G.serve(admin, { reason = "firearm kit", items = { { type = "Base.Pistol", count = 1 }, { type = "Base.Fertilizer", count = 2 }, { type = "Base.Nope", count = 1 } } })
check(n == 3 and #admin.inv.items == 3, "admin gets the three real items")
check(#synced.add == 3, "every server-made item is sent with sendAddItemToContainer")
check(netSent[1].cmd == "GrantItemsDone" and netSent[1].args.added == 3 and netSent[1].args.missing[1] == "Base.Nope", "reply lists count and the missing script")
check(G.describeReply(netSent[1].args):find("3 item%(s%)") and G.describeReply(netSent[1].args):find("Base.Nope"), "client text names count and missing")
getDebug = function() return true end
netSent = {}
local guest = Player("deck", "None")
n = G.serve(guest, { reason = "silver kit", items = { { type = "Base.Coldpack", count = 2 } } })
check(n == 2 and #guest.inv.items == 2, "a debug server (hosted from a -debug client) grants to everyone")
getDebug = function() return false end
-- cap on the server too
netSent = {}
local greedy = Player("host", "admin")
n = G.serve(greedy, { reason = "flood", items = { { type = "Base.Coldpack", count = G.MAX_ITEMS + 50 } } })
check(n == 0, "server refuses an entry over the cap")

-- ======================================================= server strip =====
MODE = "server"
synced = { add = {}, remove = {}, stats = {}, visuals = 0, equip = 0 }
local wolf = Player("host", "admin")
local shirt = Item("Base.Shirt"); shirt.loc = "Shirt"
local hat = Item("Base.Hat"); hat.loc = "Hat"
check(WTAGarou.Clothing.locationId(shirt) == "Shirt" and not WTAGarou.Clothing.isShiftSafe(shirt), "mock shirt is a strip candidate")
wolf.worn = { shirt, hat }
wolf.inv.items = { shirt, hat }
local profile = WTAGarou.ShiftStrip.profileFor("Crinos")
check(profile and profile.drop, "Crinos profile drops")
local before = WTAGarou.Wardrobe.count(wolf)
local dropped, damaged, tore = WTAGarou.Clothing.dropForbidden(wolf, "Crinos", { forced = false })
check(dropped >= 1, "server strip dropped at least one item (" .. tostring(dropped) .. ")")
check(shirt.worldDropped and shirt.transmitted, "dropped item placed via AddWorldInventoryItem and transmitted to clients")
check(#synced.remove >= 1, "server removal uses sendRemoveItemFromContainer")
check(#wolf.inv.items < 2, "dropped item left the server inventory")
check(synced.visuals == 1, "server pushed syncVisuals once for the torn model")
check(wolf.modelReset == nil, "server never calls the client-only model reset")
local entries = WTAGarou.Wardrobe.entriesSince(wolf, before)
check(#entries == dropped and entries[1].id == shirt.id or entries[1].id == hat.id, "Wardrobe entries since the strip match the drops")

-- client presents the summary the server attached
MODE = "client"
local viewer = Player("host")
local okP = WTAGarou.Clothing.presentStrip(viewer, { dropped = dropped, damaged = 0, tore = true, modelChanged = true, wardrobe = entries })
check(okP and viewer.modelReset == 1, "client presentStrip resets the model from the summary")
check(WTAGarou.Wardrobe.count(viewer) == #entries, "client Wardrobe learned the server-dropped items")
check(#WTAGarou.Clothing.pendingRips == 1, "rip sound queued once on the client")
WTAGarou.Clothing.pendingRips[1] = nil

-- single player still strips locally and presents in one go
MODE = "sp"
synced = { add = {}, remove = {}, stats = {}, visuals = 0, equip = 0 }
local solo = Player("solo")
local shirt2 = Item("Base.Shirt"); shirt2.loc = "Shirt"
solo.worn = { shirt2 }; solo.inv.items = { shirt2 }
local d2 = WTAGarou.Clothing.dropForbidden(solo, "Crinos")
check(d2 == 1 and shirt2.worldDropped and not shirt2.transmitted and #synced.remove == 0, "SP drop is the direct path, no network calls")
check(solo.modelReset == 1, "SP presents immediately (model reset)")
WTAGarou.Clothing.pendingRips[1] = nil

-- ===================================================== nitrate report =====
local function FC(raw, done)
    local fc = { amounts = { raw = raw, done = done } }
    function fc:getSpecificFluidAmount(f) return self.amounts[f.key] or 0 end
    function fc:adjustSpecificFluidAmount(f, v) self.amounts[f.key] = v end
    function fc:addFluid(f, v) self.amounts[f.key] = (self.amounts[f.key] or 0) + v end
    function fc:isEmpty() return (self.amounts.raw + self.amounts.done) <= 0 end
    return fc
end
Fluid = { Get = function(name) if name == S.FLUID_RAW then return { key = "raw" } elseif name == S.FLUID_DONE then return { key = "done" } end return nil end }
local jar = Item("Base.Jar", { fc = FC(1.0, 0.0) })
local r, dn = S.readNitrate(jar)
check(r == 1.0 and dn == 0.0, "readNitrate reads both litres")
check(S.readNitrate(Item("Base.Shirt")) == nil, "readNitrate is nil for a non-container")
local ok, moved = S.applyNitrateReport(jar, 0.7, 0.3)
check(ok and math.abs(moved - 0.3) < 1e-6, "report moves 0.3 L raw -> done")
check(math.abs(jar:getFluidContainer().amounts.raw - 0.7) < 1e-6 and math.abs(jar:getFluidContainer().amounts.done - 0.3) < 1e-6, "server copy now matches the report")
ok, moved = S.applyNitrateReport(jar, 0.7, 0.3)
check(ok and moved == 0, "a repeated (identical) report is a no-op, not an error")
ok, moved = S.applyNitrateReport(jar, 0.9, 0.1)
check(not ok and moved:find("adds raw"), "a report that re-raws the mix is refused")
ok, moved = S.applyNitrateReport(jar, 0.5, 0.9)
check(not ok and moved:find("total"), "a report that changes the total is refused")
ok, moved = S.applyNitrateReport(jar, -1, 2)
check(not ok, "negative amounts refused")
ok, moved = S.applyNitrateReport(Item("Base.Jar", { fc = FC(0, 0) }), 0, 0)
check(not ok and moved:find("no nitrate"), "an empty vessel is not a nitrate report")

-- client flush: polls Java, sends one command per vessel
MODE = "client"
netSent = {}
local queue = { jar, Item("Base.Shirt"), Item("Base.Glass", { fc = FC(0.2, 0) }) }
local sentN = WTAGarou.NitrateSync.flush(Player("host"), function() return table.remove(queue, 1) end)
check(sentN == 2 and #netSent == 2 and netSent[1].cmd == S.NITRATE_COMMAND, "flush reports the two vessels and skips the non-container")
check(netSent[1].args.item == nil and netSent[1].args.id == jar:getID() and math.abs(netSent[1].args.raw - 0.7) < 1e-6 and math.abs(netSent[1].args.done - 0.3) < 1e-6, "0.4.74: a multiplayer report carries the item ID and absolute litres, never the object")
check(WTAGarou.NitrateSync.flush(Player("host"), function() return nil end) == 0, "empty queue sends nothing")

-- 0.4.74: a kit vessel can arrive pre-filled with finished nitrate (coating
-- tests never wait on the cook), in SP, on the server, and over the wire.
MODE = "sp"
local spk = Player("solo")
b = G.begin(spk, "silver kit")
local fullJar = G.add(b, "Base.EmptyJar", 1, { name = "WTAGarou_SilverNitrate", litres = 1.0 })
local emptyJar = G.add(b, "Base.EmptyJar", 1)
check(fullJar and fullJar:getFluidContainer().amounts.done == 1.0, "SP: the kit jar holds a litre of finished nitrate")
check(emptyJar and next(emptyJar:getFluidContainer().amounts) == nil, "SP: the plain jar is still empty")
check(#b.missing == 0, "no fill complaints: " .. table.concat(b.missing, ", "))
G.add(b, "Base.EmptyJar", 1, { name = "WTAGarou_SilverNitrate", litres = 40 })
check(spk.inv.items[3]:getFluidContainer().amounts.done == 1.0, "fill is capped by the vessel's capacity (and MAX_LITRES)")
check(G.validFluid({ name = "Water", litres = 1 }) == nil and G.validFluid({ name = "WTAGarou_SilverNitrate", litres = 0 }) == nil
    and G.validFluid({ name = "WTAGarou_SilverNitrate", litres = 9 }).litres == G.MAX_LITRES,
    "only this mod's fluids, positive litres, clamped to MAX_LITRES")
local shirtB = G.begin(spk, "x")
G.add(shirtB, "Base.Shirt", 1, { name = "WTAGarou_SilverNitrate", litres = 1 })
check(#shirtB.missing == 1 and shirtB.missing[1]:find("fill"), "a non-vessel reports the failed fill, never raises")
MODE = "client"
netSent = {}
b = G.begin(Player("deck"), "silver kit")
G.add(b, "Base.EmptyJar", 1, { name = "WTAGarou_SilverNitrate", litres = 1.0 })
G.commit(b)
check(netSent[1].args.items[1].fluid and netSent[1].args.items[1].fluid.name == "WTAGarou_SilverNitrate" and netSent[1].args.items[1].fluid.litres == 1.0,
    "remote request carries the fluid as plain name + litres")
MODE = "server"
synced.add = {}
local srvP = Player("deck", "admin")
G.serve(srvP, netSent[1].args)
check(#srvP.inv.items == 1 and srvP.inv.items[1]:getFluidContainer().amounts.done == 1.0 and synced.add[1] == srvP.inv.items[1],
    "server makes the jar, fills it, then sends it to the client")
MODE = "client"

-- ============================ 0.4.72: client warming simulation (MP) =====
-- Shared math in game minutes.
local Sim = S.Sim
check(math.abs(S.simWarm(1.0, 2.0, Sim.WARM_MINUTES) - Sim.THRESHOLD) < 1e-9, "a cold vessel reaches the boil point after WARM_MINUTES in a hot container")
check(S.simWarm(1.0, 1.0, 100) == 1.0, "nothing warms in a cold container")
check(S.simWarm(2.0, 1.0, 100) == 1.0, "a hot vessel cools back to cold (never below)")
local w2, w9 = 1.0, 1.0
for _ = 1, 20 do w2 = S.simWarm(w2, 2.0, 5); w9 = S.simWarm(w9, 9.0, 5) end
check(w2 == 2.0, "warmth caps at the container temperature")
check(w9 == Sim.MAX_WARMTH, "...and at MAX_WARMTH")
check(S.simConvert(1.0, Sim.THRESHOLD, 10) == 0, "at exactly the boil point nothing finishes yet")
check(math.abs(S.simConvert(1.0, 2.0, 1) - Sim.LITRES_PER_MINUTE) < 1e-9, "one boiling minute finishes LITRES_PER_MINUTE")
check(S.simConvert(0.03, 2.0, 10) == 0.03, "never more than what is raw")
check(S.simConvert(1.0, 2.0, 1000) == S.simConvert(1.0, 2.0, Sim.MAX_STEP_MINUTES), "one step is capped at MAX_STEP_MINUTES (pause / lag)")
local full = Sim.WARM_MINUTES + 1 / Sim.LITRES_PER_MINUTE
check(full <= 20, "a one-litre jar finishes within 20 game minutes of oven time: " .. full)

-- Scanner over a mocked square/container, reporting through the net.
local NS = WTAGarou.NitrateSync
local function Container(temp, items, kind)
    local c = { temp = temp, list = items, kind = kind or "stove" }
    function c:getTemprature() return self.temp end
    function c:getType() return self.kind end
    function c:getItems() local l = self.list; return { size = function() return #l end, get = function(_, i) return l[i + 1] end } end
    return c
end
local oven = Item("Base.Jar", { fc = FC(1.0, 0.0) })
local hot = Container(2.0, { oven, Item("Base.Shirt") })
local cold = Container(1.0, { Item("Base.Jar", { fc = FC(0.5, 0) }) })
local cook = Player("cook"); cook.getX = function() return 10 end; cook.getY = function() return 10 end; cook.getZ = function() return 0 end
netSent = {}
local reports = {}
local send = function(_, args) reports[#reports + 1] = args end
local t = 0
-- first scans: warming up, nothing to report
for _ = 1, 4 do t = t + 1; NS.scan(cook, { hot, cold }, 1, t, send) end
check(#reports == 0, "no report while the vessel is still warming (4 of " .. Sim.WARM_MINUTES .. " minutes)")
NS.scan(cook, { hot, cold }, 1, t + 1, send); t = t + 1
check(#reports == 0, "at the boil point nothing has finished yet")
NS.scan(cook, { hot, cold }, 1, t + 1, send); t = t + 1
check(#reports == 1 and reports[1].item == nil and reports[1].id == oven:getID() and math.abs(reports[1].raw - 0.9) < 1e-9 and math.abs(reports[1].done - 0.1) < 1e-9,
    "first boiling minute reports absolute litres 0.9 raw / 0.1 done")
-- the server copy has not caught up yet: another minute passes, no second report
NS.scan(cook, { hot, cold }, 1, t + 1, send); t = t + 1
check(#reports == 1, "a report in flight is not repeated while the item copy is stale")
-- the server applied it (sendItemStats): copy now reads 0.9/0.1 -> next report carries the two pending minutes
oven:getFluidContainer().amounts.raw, oven:getFluidContainer().amounts.done = 0.9, 0.1
NS.scan(cook, { hot, cold }, 1, t + 1, send); t = t + 1
check(#reports == 2 and math.abs(reports[2].raw - 0.7) < 1e-9 and math.abs(reports[2].done - 0.3) < 1e-9, "after the copy catches up the pending progress is reported in one go")
-- timeout path: copy never catches up, 3 s pass -> re-report from the (stale) read minus pending
NS.scan(cook, { hot, cold }, 1, t + 4, send); t = t + 4
check(#reports == 3 and reports[3].raw < 0.9, "REPORT_TIMEOUT_S re-reports with the pending litres")
check(NS.tracked == 1, "the cold jar is read but never tracked as warming")
-- finish: with the copy at 0.05 raw, the last bit is reported even though it is under REPORT_LITRES
oven:getFluidContainer().amounts.raw, oven:getFluidContainer().amounts.done = 0.03, 0.97
NS.vessels[oven:getID()].awaiting = false; NS.vessels[oven:getID()].pending = 0
NS.scan(cook, { hot, cold }, 1, t + 1, send); t = t + 1
check(#reports == 4 and reports[4].raw == 0 and math.abs(reports[4].done - 1.0) < 1e-9, "the last drops are reported as soon as the vessel is done")
check(NS.status():find("6 report%(s%) sent"), "status counts every report (2 earlier Java-queue flushes + 4 scans): " .. NS.status())
-- real-path: scan with the default sender goes through WTAGarou.Net.ToServer
netSent = {}
oven:getFluidContainer().amounts.raw, oven:getFluidContainer().amounts.done = 1.0, 0.0
NS.vessels[oven:getID()] = nil; NS.tracked = 0
for i = 1, 7 do NS.scan(cook, { hot }, 1, t + i, nil) end
check(#netSent == 1 and netSent[1].cmd == S.NITRATE_COMMAND and netSent[1].args.item == nil and netSent[1].args.id == oven:getID(), "default sender is the NitrateCooked command")
-- nearbyContainers walks the squares around the player
local squares = {}
local function Square(objs) return { getObjects = function() return { size = function() return #objs end, get = function(_, i) return objs[i + 1] end } end } end
local ovenObj = { getContainerCount = function() return 1 end, getContainerByIndex = function() return hot end }
local plainObj = { getContainerCount = function() return 0 end, getContainer = function() return nil end }
local legacyObj = { getContainer = function() return cold end }
squares["12,10,0"] = Square({ ovenObj, plainObj }); squares["10,15,0"] = Square({ legacyObj }); squares["30,30,0"] = Square({ ovenObj })
local cell = { getGridSquare = function(_, x, y, z) return squares[x .. "," .. y .. "," .. z] end }
local near = NS.nearbyContainers(cook, cell)
check(#near == 2 and ((near[1] == hot and near[2] == cold) or (near[1] == cold and near[2] == hot)), "containers within RADIUS found (indexed and legacy getContainer), the far oven ignored")

-- Discovery remembers containers holding raw nitrate; remembered ones are
-- simulated at any distance and forgotten FORGET_S after they empty.
NS.watch = {}; NS.watched = 0
local farHot = Container(2.0, { Item("Base.Jar", { fc = FC(0.5, 0) }) }, "microwave")
check(NS.discover(cook, { hot, cold, Container(2.0, { Item("Base.Shirt") }) }, 1000) == 2, "discovery remembers the two containers with raw nitrate, not the empty hot one")
check(NS.discover(cook, { hot, cold }, 1001) == 0 and NS.watched == 2, "a second pass adds nothing new")
NS.watch[farHot] = { seen = 1000 }; NS.watched = 3
local watched = NS.watchedContainers(1002)
check(#watched == 3, "remembered containers are simulated regardless of where the player stands: " .. #watched)
farHot.list[1]:getFluidContainer().amounts.raw = 0
check(#NS.watchedContainers(1003) == 3, "an emptied container is kept for FORGET_S")
check(#NS.watchedContainers(1003 + NS.FORGET_S + 1) == 2 and NS.watched == 2, "...then forgotten")
check(NS.status():find("2 container%(s%) watched"), "status shows the watch list: " .. NS.status())
check(NS.RADIUS >= 15 and NS.DISCOVER_TICKS > NS.SCAN_TICKS, "discovery radius is at least 15 metre squares and runs less often than the simulation")

-- 0.4.74: reports carry a locator, never the item object (the command
-- serializer would hand the server a detached copy).
local ovenSquare = { getX = function() return 12 end, getY = function() return 10 end, getZ = function() return 0 end }
local ovenParent = { getSquare = function() return ovenSquare end, getObjectIndex = function() return 3 end,
    getContainerCount = function() return 2 end }
local ovenCont = Container(2.0, { oven }, "stove")
local otherCont = Container(1.0, {}, "shelf")
ovenParent.getContainerByIndex = function(_, i) return i == 1 and ovenCont or otherCont end
ovenCont.getParent = function() return ovenParent end
function ovenCont:getItemWithID(id) for _, it in ipairs(self.list) do if it:getID() == id then return it end end return nil end
function otherCont:getItemWithID(_) return nil end
local loc = S.locateVessel(oven, ovenCont)
check(loc.id == oven:getID() and loc.x == 12 and loc.y == 10 and loc.z == 0 and loc.index == 3 and loc.containerIndex == 1,
    "locator: item id, square, object index and container index")
oven:getFluidContainer().amounts.raw, oven:getFluidContainer().amounts.done = 1.0, 0.0
NS.vessels[oven:getID()] = nil; NS.tracked = 0
reports = {}
for i = 1, 7 do NS.scan(cook, { ovenCont }, 1, 2000 + i, send) end
check(#reports == 1 and reports[1].item == nil and reports[1].id == oven:getID() and reports[1].x == 12 and reports[1].index == 3 and reports[1].containerIndex == 1,
    "client report in multiplayer: locator fields, no item object")
-- server resolves the locator to the live vessel
MODE = "server"
local objects = { {}, {}, {}, ovenParent }
local square = { getObjects = function() return { size = function() return #objects end, get = function(_, i) return objects[i + 1] end } end }
local cell = { getGridSquare = function(_, x, y, z) if x == 12 and y == 10 and z == 0 then return square end end }
local detachedCopy = Item("Base.Jar", { fc = FC(1.0, 0.0) })
local found = WTAGarou.NitrateServer.resolve(cook, { item = detachedCopy, id = oven:getID(), x = 12, y = 10, z = 0, index = 3, containerIndex = 1 }, cell)
check(found == oven, "server: the live vessel is found by id/square; the detached copy is ignored")
check(WTAGarou.NitrateServer.resolve(cook, { id = oven:getID(), x = 12, y = 10, z = 0, index = 0, containerIndex = -1 }, cell) == oven,
    "server: a wrong object index still finds it by searching the square")
cook.getInventory = function() return { getItemWithID = function(_, id) return id == 777 and detachedCopy or nil end } end
check(WTAGarou.NitrateServer.resolve(cook, { id = 777 }, cell) == detachedCopy, "server: no square -> the player's own bags")
check(WTAGarou.NitrateServer.resolve(cook, { id = 123456, x = 12, y = 10, z = 0, index = 3, containerIndex = 1 }, cell) == nil, "server: unknown id -> nil (logged)")
MODE = "client"

-- Server pace clamp: two clients reporting the same oven cannot double it.
MODE = "server"
local NSrv = WTAGarou.NitrateServer
local srvJar = Item("Base.Jar", { fc = FC(1.0, 0.0) })
local okA, movedA, clampedA = NSrv.apply(srvJar, 0.95, 0.05, 100)
check(okA and math.abs(movedA - 0.05) < 1e-9 and not clampedA, "first report within the slack is applied as sent")
local okB, movedB, clampedB = NSrv.apply(srvJar, 0.0, 1.0, 100)
check(okB and clampedB and math.abs(movedB - 0.05) < 1e-9, "a second report in the same minute is clamped to the slack, not refused: " .. tostring(movedB))
check(math.abs(srvJar:getFluidContainer().amounts.raw - 0.90) < 1e-9, "server copy moved only the allowed litres")
local okC, movedC, clampedC = NSrv.apply(srvJar, 0.5, 0.5, 102)
check(okC and clampedC and math.abs(movedC - (Sim.LITRES_PER_MINUTE * 1.5 * 2 + 0.05)) < 1e-9, "two minutes later: 1.5x rate for 2 minutes plus slack")
local okD, movedD, clampedD = NSrv.apply(srvJar, srvJar:getFluidContainer().amounts.raw - 0.1, srvJar:getFluidContainer().amounts.done + 0.1, 104)
check(okD and not clampedD and math.abs(movedD - 0.1) < 1e-9, "an honest two-minute report passes unclamped")
check(not NSrv.apply(srvJar, 2.0, 0.0, 105), "re-rawing is still refused by applyNitrateReport")
MODE = "client"

-- ============================================ trait + recipe lookups =====
local getCalls = {}
CharacterTrait = { BRAVE = { name = "Brave" }, get = function(loc) table.insert(getCalls, loc); if type(loc) == "string" then error("expected argument of type ResourceLocation, got String") end return loc.path == "fearless" and { name = "Fearless" } or nil end }
ResourceLocation = { of = function(id) return { path = string.lower(id) } end }
check(WTAGarou.Adapters.traitByName("Brave") == CharacterTrait.BRAVE, "static field wins for Brave")
check(WTAGarou.Adapters.traitByName("Fearless").name == "Fearless", "ResourceLocation lookup for Fearless")
check(WTAGarou.Adapters.traitByName("Cop") == nil and WTAGarou.Adapters.traitByName("Cop") == nil, "unknown trait is nil and cached")
for _, c in ipairs(getCalls) do check(type(c) ~= "string", "CharacterTrait.get never receives a bare string") end
-- isBrave uses it without raising
local brave = { getModData = function() return {} end, getCharacterTraits = function() return { contains = function(_, t) return t == CharacterTrait.BRAVE end, getKnownTraits = function() return { size = function() return 0 end } end } end }
check(WTAGarou.Adapters.isBrave(brave) == true, "isBrave finds Brave through the resolved trait object")

local recipes = { ["WTAGarou.WTAGarou_CoatSilverNitrate"] = { getInputs = function() return { size = function() return 0 end } end, getScriptObjectName = function() return "WTAGarou_CoatSilverNitrate" end } }
local sm = { getCraftRecipe = function(_, name) return recipes[name] end,
             getAllCraftRecipes = function() local list = {} for _, r in pairs(recipes) do list[#list + 1] = r end
                 return { size = function() return #list end, get = function(_, i) return list[i + 1] end } end }
check(S.findCraftRecipe(sm, "WTAGarou_CoatSilverNitrate") == recipes["WTAGarou.WTAGarou_CoatSilverNitrate"], "recipe found under the module-qualified name")
check(S.findCraftRecipe(sm, "WTAGarou_Nothing") == nil, "missing recipe is nil, no error")
local bare = { getCraftRecipe = function() return nil end, getAllCraftRecipes = sm.getAllCraftRecipes }
check(S.findCraftRecipe(bare, "WTAGarou_CoatSilverNitrate") ~= nil, "falls back to walking the recipe list by script object name")

print = realPrint
print("PASS: " .. checks .. " multiplayer item-ownership assertions (grant, server strip, nitrate report, trait/recipe lookups).")
