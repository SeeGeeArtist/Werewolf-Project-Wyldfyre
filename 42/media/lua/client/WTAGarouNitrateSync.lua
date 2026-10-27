--[[
    WTAGarou - multiplayer nitrate warming (0.4.66 report path, 0.4.72 Lua
    simulation)

    Single player: client Java (NitrateHeatRuntime) warms raw silver nitrate
    in a hot container from InventoryItem.update. Nothing here runs.

    Multiplayer: the engine never calls InventoryItem.update on a CLIENT for
    items in world containers (IsoCell.update runs ProcessItems only in
    single player or on the server every 5 s), and a hosted/dedicated server
    has no Java. So the 0.4.66 Java hook never fired (Oct 18: 30 game minutes
    in a microwave, still raw). Now every SCAN_TICKS this looks at the
    containers within RADIUS tiles of each local player, simulates the
    warming of any vessel holding raw nitrate in GAME MINUTES
    (WTAGarou.SilverAmmo.simWarm / simConvert, shared math) and, when enough
    has finished, sends one NitrateCooked {item, raw, done} with absolute
    litres. The server applies it (WTAGarouNitrateServer.lua) and pushes
    sendItemStats, which updates this client's copy of the item. A vessel
    with a report in flight is not reported again until the copy reflects it
    (or REPORT_TIMEOUT_S passes), so a stale read can never re-raw the mix.

    Range (0.4.72 follow-up): tiles are the one-metre ground squares. A
    DISCOVERY pass every DISCOVER_TICKS walks the squares within RADIUS of
    each local player and remembers every container holding raw nitrate
    (hot or not). Remembered containers are then simulated every SCAN_TICKS
    with NO distance limit for as long as this client still has their chunk
    loaded, so you can put the jar in the oven and go about your business.
    Only when nobody running the mod has the area loaded does the cooking
    pause (vanilla ovens pause in unloaded chunks too).

    Rule 0.4.66 holds: this client never touches the item; it only reports.
    Rule 0.4.65 holds: no Java is involved on either side.
]]
WTAGarou = WTAGarou or {}
WTAGarou.NitrateSync = WTAGarou.NitrateSync or {}
local NS = WTAGarou.NitrateSync
require "WTAGarouNet"
require "WTAGarouSilverAmmo"

NS.POLL_TICKS = 20          -- legacy Java queue drain (harmless when empty)
NS.MAX_PER_POLL = 8
NS.SCAN_TICKS = 30          -- remembered containers: about twice a second
NS.DISCOVER_TICKS = 120     -- square walk around the player: about every 2 s
NS.RADIUS = 15              -- metre squares around each local player for discovery
NS.FORGET_S = 300           -- drop a remembered container 5 min after it last held raw nitrate
NS.REPORT_LITRES = 0.05     -- send once this much has finished (or the vessel is done)
NS.REPORT_TIMEOUT_S = 3.0   -- re-report even if the copy has not caught up
NS.sent = 0
NS.vessels = {}             -- itemID -> { warmth, pending, awaiting, sentRaw, sentAt, lastRaw, logged }
NS.tracked = 0
NS.watch = {}               -- remembered containers: cont -> { seen = real seconds }
NS.watched = 0
local ticks, scanTicks, discoverTicks = 0, 0, 0
local lastHours = nil

local S = WTAGarou.SilverAmmo

local function active()
    return isClient and isClient() and not (isServer and isServer())
end

local function pollActive()
    return active() and WTAGarouJava and WTAGarouJava.pollNitrateCooked
end

-- One pass over the Java queue (kept for completeness; in practice empty on
-- a client, see the header). `poll`/`send` are injectable for tests.
function NS.flush(player, poll, send)
    poll = poll or function() return WTAGarouJava.pollNitrateCooked() end
    send = send or function(p, args) WTAGarou.Net.ToServer(p, S.NITRATE_COMMAND, args) end
    if not player then return 0 end
    local n = 0
    for _ = 1, NS.MAX_PER_POLL do
        local ok, item = pcall(poll)
        if not ok or item == nil then break end
        local raw, done = S.readNitrate(item)
        if raw then
            local report = { item = item, raw = raw, done = done }
            local loc = S.locateVessel(item, item.getContainer and item:getContainer())
            if loc then for k, v in pairs(loc) do report[k] = v end end
            if isClient and isClient() then report.item = nil end
            send(player, report)
            n = n + 1
        end
    end
    NS.sent = NS.sent + n
    return n
end

-- ---------------------------------------------------------------------------
-- Scanner
-- ---------------------------------------------------------------------------
local function gameMinutesNow()
    if getGameTime then
        local ok, gt = pcall(getGameTime)
        if ok and gt and gt.getWorldAgeHours then
            local ok2, h = pcall(function() return gt:getWorldAgeHours() end)
            if ok2 and h then return h * 60 end
        end
    end
    return nil
end
NS.gameMinutesNow = gameMinutesNow

local function nowSeconds()
    return WTAGarou.NowSeconds and WTAGarou.NowSeconds() or os.time()
end

-- Containers of one square: every IsoObject container (ovens, microwaves,
-- barbecues, fireplaces, campfires all expose one).
local function containersOf(square, out)
    local objects = square and square.getObjects and square:getObjects()
    if not objects then return out end
    local n = objects.size and objects:size() or 0
    for i = 0, n - 1 do
        local obj = objects:get(i)
        if obj then
            local count = obj.getContainerCount and obj:getContainerCount() or 0
            if count and count > 0 and obj.getContainerByIndex then
                for c = 0, count - 1 do
                    local cont = obj:getContainerByIndex(c)
                    if cont then out[#out + 1] = cont end
                end
            elseif obj.getContainer then
                local cont = obj:getContainer()
                if cont then out[#out + 1] = cont end
            end
        end
    end
    return out
end
NS.containersOf = containersOf

-- Containers within RADIUS of a player. `cell` is injectable for tests.
function NS.nearbyContainers(player, cell)
    cell = cell or (getCell and getCell())
    local out = {}
    if not (player and cell and cell.getGridSquare) then return out end
    local px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    local r = NS.RADIUS
    for dx = -r, r do
        for dy = -r, r do
            local ok, sq = pcall(function() return cell:getGridSquare(px + dx, py + dy, pz) end)
            if ok and sq then containersOf(sq, out) end
        end
    end
    return out
end

local function vesselState(item, create)
    local id = item.getID and item:getID() or tostring(item)
    local st = NS.vessels[id]
    if not st and create then
        st = { warmth = S.Sim.COLD, pending = 0, awaiting = false, lastRaw = nil, logged = false, seen = 0 }
        NS.vessels[id] = st
        NS.tracked = NS.tracked + 1
    end
    return st, id
end

-- Simulate one vessel for `minutes` at `temp`; returns the report to send
-- (or nil). Pure apart from `st`. `now` is real seconds.
function NS.stepVessel(st, item, raw, done, temp, minutes, now)
    st.seen = now
    -- A report in flight: wait for the server copy to reflect it.
    if st.awaiting then
        if raw <= (st.sentRaw or 0) + S.NITRATE_TOLERANCE or (now - (st.sentAt or 0)) >= NS.REPORT_TIMEOUT_S then
            st.awaiting = false
        end
    end
    st.warmth = S.simWarm(st.warmth, temp, minutes)
    local moved = S.simConvert(raw - st.pending, st.warmth, minutes)
    st.pending = st.pending + moved
    if st.pending <= 0 then return nil end
    local finished = (raw - st.pending) <= 0.0005
    if st.awaiting or (st.pending < NS.REPORT_LITRES and not finished) then return nil end
    local report = { item = item, raw = math.max(0, raw - st.pending), done = done + st.pending }
    st.awaiting, st.sentRaw, st.sentAt, st.pending = true, report.raw, now, 0
    return report
end

-- One scan for one player. `containers`, `minutes`, `now`, `send` are
-- injectable for tests. Returns the number of reports sent.
function NS.scan(player, containers, minutes, now, send)
    if not player then return 0 end
    containers = containers or NS.nearbyContainers(player)
    now = now or nowSeconds()
    send = send or function(p, args) WTAGarou.Net.ToServer(p, S.NITRATE_COMMAND, args) end
    local n = 0
    for _, cont in ipairs(containers) do
        local okT, temp = pcall(function() return cont:getTemprature() end)
        temp = okT and tonumber(temp) or S.Sim.COLD
        local items = cont.getItems and cont:getItems()
        local count = items and items.size and items:size() or 0
        for i = 0, count - 1 do
            local item = items:get(i)
            local raw, done = S.readNitrate(item)
            -- track a vessel once it sits in something warmer than cold;
            -- keep following it while it cools
            local st = raw and raw > 0 and vesselState(item, temp > S.Sim.COLD + 1e-6)
            if st then
                if not st.logged and temp > S.Sim.THRESHOLD then
                    st.logged = true
                    print(string.format("[WTAGarou][Silver] nitrate vessel warming in a %s (temp %.2f): %.2f L raw, %.2f L done",
                        tostring(cont.getType and cont:getType() or "container"), temp, raw, done or 0))
                end
                local report = NS.stepVessel(st, item, raw, done or 0, temp, minutes or 0, now)
                if report then
                    -- 0.4.74: locate the vessel by id/square for the server; an
                    -- InventoryItem in a client command arrives as a detached
                    -- copy, so in multiplayer the object itself is NOT sent.
                    local loc = S.locateVessel(item, cont)
                    if loc then for k, v in pairs(loc) do report[k] = v end end
                    if isClient and isClient() then report.item = nil end
                    send(player, report)
                    n = n + 1
                end
            end
        end
    end
    -- forget vessels not seen for a while (moved away, emptied)
    for id, st in pairs(NS.vessels) do
        if (now - (st.seen or 0)) > 120 then NS.vessels[id] = nil; NS.tracked = NS.tracked - 1 end
    end
    NS.sent = NS.sent + n
    return n
end

-- Does this container hold any raw nitrate right now?
local function holdsRaw(cont)
    local ok, items = pcall(function() return cont:getItems() end)
    if not ok or not items then return false end
    local count = items.size and items:size() or 0
    for i = 0, count - 1 do
        local raw = S.readNitrate(items:get(i))
        if raw and raw > 0 then return true end
    end
    return false
end
NS.holdsRaw = holdsRaw

-- Discovery pass: remember every container near the player holding raw
-- nitrate. `containers`/`now` injectable for tests. Returns new count.
function NS.discover(player, containers, now)
    containers = containers or NS.nearbyContainers(player)
    now = now or nowSeconds()
    local added = 0
    for _, cont in ipairs(containers) do
        if holdsRaw(cont) then
            if not NS.watch[cont] then
                NS.watch[cont] = { seen = now }
                NS.watched = NS.watched + 1
                added = added + 1
                local kind = cont.getType and cont:getType() or "container"
                print("[WTAGarou][Silver] watching a " .. tostring(kind) .. " with raw silver nitrate (simulated at any distance while loaded)")
            else
                NS.watch[cont].seen = now
            end
        end
    end
    return added
end

-- The remembered containers still worth simulating; forgets stale ones.
function NS.watchedContainers(now)
    now = now or nowSeconds()
    local out = {}
    for cont, w in pairs(NS.watch) do
        local alive = holdsRaw(cont)
        if alive then w.seen = now end
        if alive or (now - (w.seen or 0)) <= NS.FORGET_S then
            out[#out + 1] = cont
        else
            NS.watch[cont] = nil
            NS.watched = NS.watched - 1
        end
    end
    return out
end

function NS.status()
    return string.format("nitrate MP simulation: %s, %d container(s) watched, %d vessel(s) warming, %d report(s) sent",
        active() and "client scanner on" or "off (single player / server)", NS.watched, NS.tracked, NS.sent)
end

local function onTick()
    if not active() then return end
    ticks = ticks + 1
    scanTicks = scanTicks + 1
    local players = WTAGarou.LocalPlayers and WTAGarou.LocalPlayers() or { getPlayer() }
    if ticks >= NS.POLL_TICKS then
        ticks = 0
        if pollActive() and players and players[1] then NS.flush(players[1]) end
    end
    discoverTicks = discoverTicks + 1
    if discoverTicks >= NS.DISCOVER_TICKS then
        discoverTicks = 0
        for _, player in ipairs(players or {}) do
            local ok, err = pcall(NS.discover, player, nil, nil)
            if not ok then print("[WTAGarou][Silver] nitrate discovery failed: " .. tostring(err)) end
        end
    end
    if scanTicks >= NS.SCAN_TICKS then
        scanTicks = 0
        local nowMin = gameMinutesNow()
        local minutes = 0
        if nowMin and lastHours then minutes = math.max(0, nowMin - lastHours) end
        lastHours = nowMin or lastHours
        local reporter = players and players[1]
        if reporter and NS.watched > 0 then
            local ok, err = pcall(function() return NS.scan(reporter, NS.watchedContainers(), minutes, nil, nil) end)
            if not ok then print("[WTAGarou][Silver] nitrate scan failed: " .. tostring(err)) end
        end
    end
end

if Events and Events.OnTick then Events.OnTick.Add(onTick) end
