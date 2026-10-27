--[[
    WTAGarou - Dress (v0.4.19)

    Counter-command to Strip. Walks the player's Wardrobe (the exact items
    Strip took off or a shift tore off, by InventoryItem id), finds each one
    in the main inventory, any nested container, or on the floor within
    WTAGarou.Wardrobe.FLOOR_RADIUS tiles, and queues the vanilla actions to
    put it back on:

      floor  -> ISGrabItemAction (walk adjacent first)   -> ISWearClothing
      bag    -> ISInventoryTransferAction to the main inventory -> ISWearClothing
      main   -> ISWearClothing

    Items are dressed innermost first, the reverse of the order Strip
    removed them, so layers come back as they were.

    Every item that cannot be re-equipped is reported on its own line in
    the Garou panel (WTAGarouHUD:pushNotice) and stays in the Wardrobe for
    the next Dress. Entries whose item is worn again are pruned. When a
    lookup fails the Wardrobe dumps the recorded ids next to the ids really
    present in the inventory ([WTAGarou][Dress] lines in the console).
]]

WTAGarou = WTAGarou or {}
WTAGarou.Dress = WTAGarou.Dress or {}
local Dress = WTAGarou.Dress

Dress.GRAB_TIME = 20

local function notice(text)
    if WTAGarou.HUD and WTAGarou.HUD.instance and WTAGarou.HUD.instance.pushNotice then
        WTAGarou.HUD.instance:pushNotice(text)
    end
    if WTAGarou.TestPanel and WTAGarou.TestPanel.notify then WTAGarou.TestPanel.notify(text) end
end

local function isBroken(item)
    local ok, b = pcall(function() return item:isBroken() end)
    return ok and b == true
end

local function isHeld(player, item)
    local ok, held = pcall(function()
        return player:getPrimaryHandItem() == item or player:getSecondaryHandItem() == item
    end)
    return ok and held == true
end

-- Queue the vanilla actions that bring `item` to the main inventory.
-- where: "inventory" | "floor"; worldItem: IsoWorldInventoryObject (floor).
local function queueFetch(player, inv, item, where, worldItem)
    if where == "floor" and worldItem then
        if not (ISGrabItemAction and ISGrabItemAction.new) then
            error("ISGrabItemAction unavailable")
        end
        pcall(function()
            local sq = worldItem:getSquare()
            if sq and luautils and luautils.walkAdj then luautils.walkAdj(player, sq, true) end
        end)
        ISTimedActionQueue.add(ISGrabItemAction:new(player, worldItem, Dress.GRAB_TIME))
        return
    end
    local src = nil
    pcall(function() src = item:getContainer() end)
    if inv and src and src ~= inv and ISInventoryTransferAction and ISInventoryTransferAction.new then
        ISTimedActionQueue.add(ISInventoryTransferAction:new(player, item, src, inv))
    end
end

local function nowSeconds()
    if WTAGarou.NowSeconds then return WTAGarou.NowSeconds() end
    if getTimestampMs then return getTimestampMs() / 1000 end
    return os.time()
end

-- Returns queued, failed (numbers). Failures are listed in the panel.
function Dress.queue(player)
    player = player or (getPlayer and getPlayer())
    if not player or player:isDead() then return 0, 0 end
    if not WTAGarou.HasGarouTrait(player) then return 0, 0 end
    local W = WTAGarou.Wardrobe
    if not W then return 0, 0 end
    if WTAGarou.IsChannelling and WTAGarou.IsChannelling(player) then
        notice("Finish the change first.")
        return 0, 0
    end
    W.prune(player)
    local list = W.list(player) or {}
    if #list == 0 then
        notice("Nothing to put back on.")
        return 0, 0
    end
    if not (ISTimedActionQueue and ISTimedActionQueue.add and ISWearClothing and ISWearClothing.new) then
        print("[WTAGarou][Dress] vanilla wear action unavailable; nothing queued")
        return 0, 0
    end
    local inv = nil
    pcall(function() inv = player:getInventory() end)
    local queued, failed = 0, 0
    local queueErrors = 0
    local skippedForForm = 0
    local missing = {}
    local d = WTAGarou.GetData and WTAGarou.GetData(player) or {}
    local form = d.form or "Homid"
    local formShown = (WTAGarou.DisplayName and WTAGarou.DisplayName(form)) or form
    Dress.floorPending = {}            -- 0.4.82: a press recomputes the floor turn order from the wardrobe
    -- innermost (recorded last by Strip, which removes outer layers first)
    -- goes on first
    for i = #list, 1, -1 do
        local e = list[i]
        local item, where, worldItem = W.find(player, e.id)
        local name = tostring(e.name or e.type or e.id)
        if not item then
            failed = failed + 1
            missing[#missing + 1] = tostring(e.id) .. "=" .. tostring(e.type or e.name)
            -- 0.4.82: an item whose id is gone for good (a hoodie toggled
            -- hood-down becomes a new item, Base.HoodieDOWN_*, with a new
            -- id) was reported "not in your inventory" on every Dress for
            -- the rest of the session. Three strikes and it is forgotten.
            e.misses = (tonumber(e.misses) or 0) + 1
            if e.misses >= (Dress.MISS_LIMIT or 3) then
                W.forget(player, e.id)
                notice("Dress: " .. name .. " is gone; forgetting it.")
                print("[WTAGarou][Dress] forgot " .. name .. " id=" .. tostring(e.id) .. " (not found in " .. tostring(e.misses) .. " Dress attempts)")
            else
                notice("Dress: " .. name .. " is not in your inventory or nearby.")
            end
        elseif W.isWorn(player, item) then
            -- already back on (e.g. dressed by hand); prune now
            W.forget(player, e.id)
        elseif isBroken(item) then
            failed = failed + 1
            notice("Dress: " .. name .. " is ruined.")
        elseif isHeld(player, item) then
            failed = failed + 1
            notice("Dress: " .. name .. " is in your hands.")
        elseif WTAGarou.CanWear and not WTAGarou.CanWear(form, item) then
            -- 0.4.20: the item stays remembered for the next human form; do
            -- not queue a wear action the form rules will reject (the 0.4.19
            -- playtest queued six items three times from Crinos and dressed
            -- one).
            skippedForForm = skippedForForm + 1
        else
            e.misses = nil
            local deferred = false
            local ok, err = pcall(function()
                if where == "floor" and isClient and isClient() then
                    -- 0.4.75: in multiplayer ISGrabItemAction only ASKS the
                    -- server for the item; it arrives later. Queueing
                    -- ISWearClothing right behind it crashed in its start()
                    -- (getItemById -> nil, Oct 19 debugger screenshot) and
                    -- killed the rest of the queue. Wear it when it lands.
                    -- 0.4.82: ONE floor grab at a time. Back-to-back
                    -- ISGrabItemActions merge into a single action with a
                    -- queueList (ISGrabItemAction:checkQueueList), and in
                    -- multiplayer that merged action finishes after its first
                    -- item (transferItem -> ISBaseTimedAction.perform), so the
                    -- Oct 22 hosted test got exactly one item per Dress press
                    -- and half-filled bars on the rest. The next grab is
                    -- queued when the previous item has arrived (or expired).
                    if Dress.floorBusy() then
                        Dress.deferFloor(e.id, name)
                        deferred = true
                    else
                        queueFetch(player, inv, item, where, worldItem)
                        Dress.awaitArrival(e.id, name, nowSeconds())
                    end
                else
                    queueFetch(player, inv, item, where, worldItem)
                    ISTimedActionQueue.add(ISWearClothing:new(player, item))
                end
            end)
            if ok then
                queued = queued + 1
                print("[WTAGarou][Dress] queued " .. name .. " id=" .. tostring(e.id) .. " from " .. tostring(where)
                    .. (deferred and " (waits for the previous floor item)" or ""))
            else
                failed = failed + 1
                queueErrors = queueErrors + 1
                notice("Dress: " .. name .. " could not be worn.")
                print("[WTAGarou][Dress] wear queue failed: " .. tostring(err))
            end
        end
    end
    if #missing > 0 and W.debugDump then pcall(W.debugDump, player, missing) end
    if queued > 0 then
        notice("Dressing " .. queued .. " item(s)...")
        -- 0.4.20: report the outcome once the queue has drained, so a
        -- console shows WHICH queued items never went on (the 0.4.19 forced
        -- Crinos queued six and wore one, silently).
        Dress.reportAt = nowSeconds() + (Dress.REPORT_DELAY or 8)
        Dress.reportPending = true
    end
    if skippedForForm > 0 then
        notice(string.format("%d item(s) will not fit a %s; shift to a human form first.",
            skippedForForm, tostring(formShown)))
        print("[WTAGarou][Dress] skipped " .. skippedForForm .. " item(s) the form " .. tostring(form)
            .. " cannot wear; they stay remembered")
    end
    -- 0.4.19: a wear action that failed to queue (the 0.4.18 playtest saw a
    -- vanilla ISBaseTimedAction:begin NPE on the first Strip/Dress of a
    -- session; the Long Skirt stayed off) leaves its entry in the wardrobe.
    -- Schedule one automatic retry once the current queue has drained.
    if queueErrors > 0 and not Dress.retryPending then
        Dress.retryPending = true
        Dress.retryAt = nowSeconds() + (Dress.RETRY_DELAY or 4)
        print("[WTAGarou][Dress] " .. queueErrors .. " wear action(s) failed to queue; retrying once in "
            .. tostring(Dress.RETRY_DELAY or 4) .. "s")
    end
    return queued, failed
end

Dress.RETRY_DELAY = 4

local function queueIdle(player)
    local ok, idle = pcall(function()
        local q = ISTimedActionQueue and ISTimedActionQueue.getTimedActionQueue
            and ISTimedActionQueue.getTimedActionQueue(player) or nil
        return (not q) or (not q.queue) or (#q.queue == 0)
    end)
    return ok and idle
end

Dress.REPORT_DELAY = 8

function Dress.report(player)
    local W = WTAGarou.Wardrobe
    if not (W and player) then return 0 end
    pcall(W.prune, player)
    local left = W.list(player) or {}
    local stillOff = {}
    for _, e in ipairs(left) do
        local item = W.find(player, e.id)
        if item and not W.isWorn(player, item) then
            stillOff[#stillOff + 1] = tostring(e.name or e.type or e.id)
        end
    end
    local d = WTAGarou.GetData and WTAGarou.GetData(player) or {}
    if #stillOff > 0 then
        print("[WTAGarou][Dress] " .. #stillOff .. " queued item(s) still not worn after "
            .. tostring(Dress.REPORT_DELAY) .. "s in " .. tostring(d.form) .. ": " .. table.concat(stillOff, ", ")
            .. " (queue idle=" .. tostring(queueIdle(player)) .. ")")
    else
        print("[WTAGarou][Dress] every queued item is worn (" .. tostring(d.form) .. ")")
    end
    return #stillOff
end

-- ---------------------------------------------------------------------------
-- 0.4.75: floor items in multiplayer. The grab completes on the client at
-- once; the item shows up in the main inventory when the server's reply
-- lands (same item ID). Poll for it and queue the wear then.
-- ---------------------------------------------------------------------------
Dress.ARRIVAL_TIMEOUT = 10        -- seconds before an item is written off
Dress.MISS_LIMIT = 3              -- Dress presses an unfound id survives
Dress.arrivals = Dress.arrivals or {}
function Dress.awaitArrival(id, name, now)
    for _, a in ipairs(Dress.arrivals) do
        if a.id == id then a.at = now or nowSeconds(); return end   -- 0.4.82: never twice (double "arrived" lines)
    end
    Dress.arrivals[#Dress.arrivals + 1] = { id = id, name = name, at = now or nowSeconds() }
end

-- 0.4.82: floor items waiting for their turn (multiplayer, see Dress.queue).
Dress.floorPending = Dress.floorPending or {}
function Dress.floorBusy() return #Dress.arrivals > 0 end
function Dress.deferFloor(id, name)
    for _, f in ipairs(Dress.floorPending) do if f.id == id then return end end
    Dress.floorPending[#Dress.floorPending + 1] = { id = id, name = name }
end
-- Start the next deferred floor item. `find(id)` -> item, where, worldItem;
-- `grab(item, worldItem)` queues the fetch; `wear(item)` queues a wear
-- (for an item that reached the inventory meanwhile). Returns what it did.
function Dress.nextFloor(find, grab, wear, isWorn)
    while #Dress.floorPending > 0 do
        local f = table.remove(Dress.floorPending, 1)
        local item, where, worldItem = find(f.id)
        if item and where == "floor" then
            grab(item, worldItem)
            Dress.awaitArrival(f.id, f.name, nowSeconds())
            print("[WTAGarou][Dress] next floor item: " .. tostring(f.name) .. " id=" .. tostring(f.id))
            return "grab", f
        elseif item and not (isWorn and isWorn(item)) then
            wear(item)
            print("[WTAGarou][Dress] " .. tostring(f.name) .. " was already in the inventory; wear queued")
            return "wear", f
        elseif not item then
            notice("Dress: " .. tostring(f.name) .. " is not in your inventory or nearby.")
        end
    end
    return nil
end
-- Pure step for tests: `lookup(id)` -> item or nil, `wear(item)` queues it.
-- Returns worn, expired counts.
function Dress.arrivalStep(arrivals, now, lookup, wear, timeout)
    timeout = timeout or Dress.ARRIVAL_TIMEOUT
    local worn, expired, i = 0, 0, 1
    while i <= #arrivals do
        local a = arrivals[i]
        local item = lookup(a.id)
        if item then
            wear(item, a)
            table.remove(arrivals, i); worn = worn + 1
        elseif now - (a.at or 0) > timeout then
            table.remove(arrivals, i); expired = expired + 1
            if a.name then notice("Dress: " .. tostring(a.name) .. " never arrived from the floor.") end
        else
            i = i + 1
        end
    end
    return worn, expired
end
local function onArrivalTick()
    if #Dress.arrivals == 0 then return end
    local player = getPlayer and getPlayer() or nil
    if not player or player:isDead() then Dress.arrivals = {}; return end
    local inv = player:getInventory()
    local worn, expired = Dress.arrivalStep(Dress.arrivals, nowSeconds(), function(id)
        local ok, item = pcall(function() return inv:getItemById(id) end)
        return ok and item or nil
    end, function(item, a)
        local ok, err = pcall(function() ISTimedActionQueue.add(ISWearClothing:new(player, item)) end)
        print("[WTAGarou][Dress] " .. tostring(a.name) .. " arrived from the floor; wear " .. (ok and "queued" or ("failed: " .. tostring(err))))
    end)
    if (worn + expired) > 0 and #Dress.arrivals == 0 and #Dress.floorPending > 0 then
        local W = WTAGarou.Wardrobe
        pcall(Dress.nextFloor,
            function(id) return W.find(player, id) end,
            function(item, worldItem) queueFetch(player, inv, item, "floor", worldItem) end,
            function(item) ISTimedActionQueue.add(ISWearClothing:new(player, item)) end,
            function(item) return W.isWorn(player, item) end)
    end
end
if Events and Events.OnTick then Events.OnTick.Add(onArrivalTick) end

local function onReportTick()
    if not Dress.reportPending then return end
    local player = getPlayer and getPlayer() or nil
    if not player then Dress.reportPending = false; return end
    if nowSeconds() < (Dress.reportAt or 0) then return end
    Dress.reportPending = false
    pcall(Dress.report, player)
end
if Events and Events.OnTick then Events.OnTick.Add(onReportTick) end

local function onTick()
    if not Dress.retryPending then return end
    local player = getPlayer and getPlayer() or nil
    if not player then Dress.retryPending = false; return end
    if nowSeconds() < (Dress.retryAt or 0) then return end
    if not queueIdle(player) then return end
    Dress.retryPending = false
    local W = WTAGarou.Wardrobe
    if W then pcall(W.prune, player) end
    local left = W and W.list(player) or {}
    if #left == 0 then return end
    print("[WTAGarou][Dress] retrying " .. #left .. " item(s) left in the wardrobe")
    Dress.retrying = true
    pcall(Dress.queue, player)
    Dress.retrying = false
end

if Events and Events.OnTick then Events.OnTick.Add(onTick) end

function WTAGarou.RequestDress(player)
    return Dress.queue(player or (getPlayer and getPlayer() or nil))
end
