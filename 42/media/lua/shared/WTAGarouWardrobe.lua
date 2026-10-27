--[[
    WTAGarou - Wardrobe (v0.4.17)

    The list of exact clothing items a Garou took off with "Strip" or had
    torn off by a shift, so "Dress" can put the very same pieces back on.
    Entries are { id, name, type, source, pending } keyed by
    InventoryItem:getID(), which the engine saves with the item
    (InventoryItem.load reads it back), so the list survives a save/load.
    Stored in the player's mod data under WTAGarou_Wardrobe, oldest first;
    capped at MAX entries.

    0.4.17 fixes from the September 26 playtest:
      * Strip entries are recorded while the item is STILL WORN (the vanilla
        unequip actions run afterwards). prune() used to drop them at once
        because "found and worn" looked like "dressed again". Entries now
        start `pending`; a pending entry is kept while worn and only becomes
        prunable once it has been seen NOT worn.
      * find() no longer trusts ItemContainer:getItemWithIDRecursiv alone
        (Dress reported items that were plainly in the inventory as
        missing). It walks the main inventory and every nested container in
        Lua, comparing getID() as Lua numbers, and then the floor within
        FLOOR_RADIUS tiles (world items on the ground), returning where the
        item was found so Dress can grab it first.
      * Matching is ALWAYS by exact id, never by type (regression contract).
]]

WTAGarou = WTAGarou or {}
WTAGarou.Wardrobe = WTAGarou.Wardrobe or {}
local W = WTAGarou.Wardrobe

W.KEY = "WTAGarou_Wardrobe"
W.MAX = 32
-- Tiles around the player searched for dropped clothes (Chebyshev radius).
W.FLOOR_RADIUS = 2

local function modData(player)
    if not player or not player.getModData then return nil end
    local ok, md = pcall(function() return player:getModData() end)
    return ok and md or nil
end

-- The live list table (created on demand). nil when the player has no mod data.
function W.list(player)
    local md = modData(player)
    if not md then return nil end
    if type(md[W.KEY]) ~= "table" then md[W.KEY] = {} end
    return md[W.KEY]
end

function W.count(player)
    local l = W.list(player)
    return l and #l or 0
end

function W.itemId(item)
    if not item then return nil end
    local ok, id = pcall(function() return item:getID() end)
    if ok and type(id) == "number" then return id end
    return nil
end

function W.itemName(item)
    if not item then return "?" end
    local ok, n = pcall(function() return item:getDisplayName() end)
    if ok and n and n ~= "" then return tostring(n) end
    ok, n = pcall(function() return item:getName() end)
    if ok and n then return tostring(n) end
    return "?"
end

-- Remember an item (by exact id). Re-recording an id moves it to the end.
-- `source` is "strip" (still worn: the unequip action runs later, so the
-- entry starts pending) or "shift" (already off the body).
-- Returns true when the item was stored.
function W.record(player, item, source)
    local l = W.list(player)
    local id = W.itemId(item)
    if not l or not id then return false end
    for i = #l, 1, -1 do
        if l[i].id == id then table.remove(l, i) end
    end
    local fullType = nil
    pcall(function() fullType = item:getFullType() end)
    source = source or "strip"
    table.insert(l, {
        id = id, name = W.itemName(item), type = fullType, source = source,
        pending = (source == "strip") or nil,
    })
    while #l > W.MAX do table.remove(l, 1) end
    return true
end

-- 0.4.66: entries recorded by the SERVER (it strips in multiplayer) travel
-- to the client inside TransformCompleted.strip.wardrobe and are merged here
-- so Dress still knows what to pick back up. Same shape as W.record writes.
function W.recordEntries(player, entries)
    local l = W.list(player)
    if not l or type(entries) ~= "table" then return 0 end
    local n = 0
    for _, e in ipairs(entries) do
        local id = tonumber(e and e.id)
        if id then
            for i = #l, 1, -1 do
                if l[i].id == id then table.remove(l, i) end
            end
            table.insert(l, { id = id, name = tostring(e.name or "?"), type = e.type,
                source = e.source or "shift", pending = e.pending or nil })
            n = n + 1
        end
    end
    while #l > W.MAX do table.remove(l, 1) end
    return n
end

-- The entries recorded since `fromCount` (for the server to ship).
function W.entriesSince(player, fromCount)
    local l = W.list(player)
    if not l then return {} end
    local out = {}
    for i = (tonumber(fromCount) or 0) + 1, #l do
        local e = l[i]
        out[#out + 1] = { id = e.id, name = e.name, type = e.type, source = e.source, pending = e.pending }
    end
    return out
end

function W.forget(player, id)
    local l = W.list(player)
    if not l then return end
    for i = #l, 1, -1 do
        if l[i].id == id then table.remove(l, i) end
    end
end

function W.clear(player)
    local md = modData(player)
    if md then md[W.KEY] = {} end
end

local function sameId(a, b)
    return a ~= nil and b ~= nil and tonumber(a) == tonumber(b)
end

-- Java ArrayList / ItemContainer item list iteration helper.
local function eachItem(list, fn)
    if not list then return end
    local ok, n = pcall(function() return list:size() end)
    if not ok or not n then return end
    for i = 0, n - 1 do
        local okGet, it = pcall(function() return list:get(i) end)
        if okGet and it ~= nil then
            if fn(it) then return true end
        end
    end
    return false
end

-- Walk a container and every container item inside it (depth-first).
local function scanContainer(container, id, depth)
    depth = depth or 0
    if not container or depth > 6 then return nil end
    local found = nil
    local ok, items = pcall(function() return container:getItems() end)
    if not ok then return nil end
    eachItem(items, function(it)
        if sameId(W.itemId(it), id) then found = it; return true end
        local okInner, inner = pcall(function()
            if it.getItemContainer then return it:getItemContainer() end
            if it.getInventory then return it:getInventory() end
            return nil
        end)
        if okInner and inner then
            found = scanContainer(inner, id, depth + 1)
            if found then return true end
        end
        return false
    end)
    return found
end
W.scanContainer = scanContainer

-- Exact item for an entry, searching the inventory and nested containers.
-- Returns item, "inventory" | nil.
function W.findInInventory(player, id)
    if not player or not id then return nil end
    local inv = nil
    pcall(function() inv = player:getInventory() end)
    if not inv then return nil end
    -- Engine lookup first (int id, recursive through InventoryContainers).
    local ok, item = pcall(function()
        if inv.getItemWithIDRecursiv then return inv:getItemWithIDRecursiv(id) end
        if inv.getItemWithID then return inv:getItemWithID(id) end
        return nil
    end)
    if ok and item then return item, "inventory" end
    -- Lua walk: same containers, id compared as Lua numbers.
    item = scanContainer(inv, id, 0)
    if item then return item, "inventory" end
    return nil
end

-- Square helper: the player's cell square at an offset from the player.
local function squareAt(player, dx, dy)
    local ok, sq = pcall(function()
        local cell = player.getCell and player:getCell() or (getCell and getCell()) or nil
        if not cell then return nil end
        local x = math.floor(player:getX()) + dx
        local y = math.floor(player:getY()) + dy
        local z = math.floor(player:getZ())
        return cell:getGridSquare(x, y, z)
    end)
    return ok and sq or nil
end

-- Exact item lying on the floor within FLOOR_RADIUS tiles. Returns the
-- IsoWorldInventoryObject (the thing ISGrabItemAction wants) and the
-- InventoryItem inside it.
function W.findOnFloor(player, id)
    if not player or not id then return nil end
    local r = W.FLOOR_RADIUS or 0
    for dy = -r, r do
        for dx = -r, r do
            local sq = squareAt(player, dx, dy)
            if sq then
                local worldItem, invItem = nil, nil
                local ok, objs = pcall(function() return sq:getWorldObjects() end)
                if ok and objs then
                    eachItem(objs, function(wo)
                        local okIt, it = pcall(function() return wo:getItem() end)
                        if okIt and it and sameId(W.itemId(it), id) then
                            worldItem, invItem = wo, it
                            return true
                        end
                        return false
                    end)
                end
                if worldItem then return worldItem, invItem end
            end
        end
    end
    return nil
end

-- Exact item for an entry: inventory (incl. nested bags) first, then the
-- floor around the player. Returns item, where ("inventory" | "floor"),
-- worldObject (floor only).
function W.find(player, id)
    local item, where = W.findInInventory(player, id)
    if item then return item, where, nil end
    local worldItem, floorItem = W.findOnFloor(player, id)
    if worldItem and floorItem then return floorItem, "floor", worldItem end
    return nil
end

function W.isWorn(player, item)
    if not (player and item) then return false end
    local ok, worn = pcall(function()
        if player.isEquippedClothing then return player:isEquippedClothing(item) end
        if item.isWorn then return item:isWorn() end
        return false
    end)
    return ok and worn == true
end

-- Drop every entry whose item is worn again. A `pending` entry (recorded
-- by Strip before its unequip action ran) is kept while it is still worn
-- and simply stops being pending once seen off the body. Returns the number
-- pruned.
function W.prune(player)
    local l = W.list(player)
    if not l then return 0 end
    local pruned = 0
    for i = #l, 1, -1 do
        local e = l[i]
        local item = W.findInInventory(player, e.id)
        local worn = item and W.isWorn(player, item) or false
        if e.pending then
            if not worn then e.pending = nil end
        elseif worn then
            table.remove(l, i); pruned = pruned + 1
        end
    end
    return pruned
end

-- Names, oldest first, for tooltips.
function W.names(player)
    local out = {}
    for _, e in ipairs(W.list(player) or {}) do out[#out + 1] = tostring(e.name or e.type or e.id) end
    return out
end

-- Diagnostic dump for the console: the ids Dress could not find next to the
-- ids actually present in the inventory (main + nested), so a playtest
-- console shows WHY a lookup failed instead of only "not in your inventory".
function W.debugDump(player, missingIds)
    local lines = {}
    lines[#lines + 1] = "[WTAGarou][Dress] missing ids: " .. table.concat(missingIds or {}, ", ")
    local seen = {}
    local inv = nil
    pcall(function() inv = player:getInventory() end)
    local function walk(container, depth)
        if not container or depth > 6 then return end
        local ok, items = pcall(function() return container:getItems() end)
        if not ok then return end
        eachItem(items, function(it)
            local id = W.itemId(it)
            local okT, t = pcall(function() return it:getFullType() end)
            local worn = W.isWorn(player, it) and " worn" or ""
            seen[#seen + 1] = tostring(id) .. "=" .. tostring(okT and t or "?") .. worn
            local okInner, inner = pcall(function()
                if it.getItemContainer then return it:getItemContainer() end
                return nil
            end)
            if okInner and inner then walk(inner, depth + 1) end
            return false
        end)
    end
    walk(inv, 0)
    lines[#lines + 1] = "[WTAGarou][Dress] inventory ids (" .. #seen .. "): " .. table.concat(seen, ", ")
    for _, line in ipairs(lines) do print(line) end
    return lines
end
