--[[
    WTAGarou - Scattered silver and the silver scent (0.4.77)

    "Silver caltrops": a tile of silver filings scattered on the floor, the
    way broken glass is picked up and put back down. Silver does not need an
    edge to burn a Garou, so:
      - humans and zombies walk it barefoot with no effect at all (the engine
        is never told it is glass);
      - a Garou in Homid or Glabro is safe in intact footwear, burned barefoot;
      - Crinos, Hispo and Lupus never wear shoes, so paws always burn.
    Standing or walking on it burns a foot like holding silver (contact rate)
    and each pass has a chance to work fragments INTO the foot: the engine's
    "lodged glass" state (haveGlass, pulled by hand or with tweezers), marked
    as silver so the part keeps burning and never regenerates until the
    fragments are out (see WTAGarouSilver lodgedStep).

    World object: a plain IsoObject with one of the SPRITES (mod textures
    registered with fixed sprite ids by shared/WTAGarouScatterSprites.lua,
    because the engine saves and networks an object by sprite id) and mod
    data FLAG = filings used. Deliberately NOT an IsoBrokenGlass so the
    engine's barefoot-glass code ignores it. It has no tile definition, so
    the vanilla "Pick up" furniture tool never lists it; the mod's own
    right-click "Pick up scattered silver" is the way to collect it.

    Multiplayer: the server places and removes the object (clients send a
    command with the square); the filings are drained on the owning client
    (vanilla pattern for drainables) and handed back by the server through
    WTAGarou.Grant (server-made items). The hazard runs inside the silver
    contact scan, so on the server in MP and on the client in single player,
    which is where the body is owned.

    The sniffer: worked silver (the mod's own items, coats, nitrate, silver
    rounds, scattered tiles) within SCENT_RADIUS[form] squares that are open
    to the Garou's air (same room, or both outdoors) raises "You smell silver"
    without saying where. Vanilla silver jewellery is NOT worked silver.
]]

WTAGarou = WTAGarou or {}
WTAGarou.Scatter = WTAGarou.Scatter or {}
local SC = WTAGarou.Scatter

SC.ITEM          = "WTAGarou.SilverFilings"
SC.COST_USES     = 5                                   -- of 20 per unit of filings
-- 0.4.79: a whole unit of Silver Fragments (vanilla Base.SilverScrap, the
-- thing the user asked to scatter "the same way a unit of broken glass" is)
-- lays one tile too. SOURCE_FLAG remembers which, so pickup gives it back.
SC.SCRAP_ITEM    = "Base.SilverScrap"
SC.SOURCE_FLAG   = "WTAGarou_SilverScatterSource"       -- "scrap" | "filings"
-- 0.4.81: the user's four tile variants (common/media/textures/WTAGarou,
-- 128x256 iso tiles). A square always gets the same one (x,y hash), so a
-- tile looks the same to every client and after a reload.
-- 0.4.82: the paths live in shared/WTAGarouScatterSprites.lua, which
-- registers them with FIXED sprite ids on client and server. IsoObject is
-- saved and networked by sprite id; an id-less texture sprite resolves to
-- the empty sprite on every other process, which is why the Oct 22 hosted
-- test saw (and the ground "pick up" tool listed) nothing.
SC.SPRITES       = (WTAGarou.ScatterSprites and WTAGarou.ScatterSprites.PATHS) or {
    "media/textures/WTAGarou/WTAGarou_SilverScatter_0.png",
    "media/textures/WTAGarou/WTAGarou_SilverScatter_1.png",
    "media/textures/WTAGarou/WTAGarou_SilverScatter_2.png",
    "media/textures/WTAGarou/WTAGarou_SilverScatter_3.png",
}
SC.SPRITE        = SC.SPRITES[1]
function SC.spriteFor(x, y)
    local n = #SC.SPRITES
    if n == 0 then return SC.SPRITE end
    local h = (math.floor(tonumber(x) or 0) * 7 + math.floor(tonumber(y) or 0) * 13) % n
    return SC.SPRITES[h + 1]
end
function SC.isScatterSprite(name)
    for _, p in ipairs(SC.SPRITES) do if p == name then return true end end
    return false
end
-- Make sure the ids are registered in the live sprite manager (see the
-- shared file). Returns false, with a console line, when they are not.
function SC.ensureSprites()
    local SS = WTAGarou.ScatterSprites
    if not SS then return true end       -- headless tests without the shared file
    local ok = SS.ensure()
    if not ok then print("[WTAGarou][Scatter] tile sprites are NOT registered; a placed tile would be invisible to clients") end
    return ok
end
SC.FLAG          = "WTAGarou_SilverScatter"
SC.CMD_SCATTER   = "ScatterSilver"
SC.CMD_PICKUP    = "PickupSilverScatter"
SC.LODGE_CHANCE  = 0.35                                -- per hazard step on an exposed foot
SC.FEET          = { "Foot_L", "Foot_R" }
SC.BEAST_FORMS   = { Crinos = true, Hispo = true, Lupus = true }
SC.SCENT_RADIUS  = { Homid = 3, Glabro = 4, Crinos = 5, Hispo = 7, Lupus = 8 }
SC.SCENT_REPEAT  = 60                                  -- seconds between repeat warnings while it lingers

local function cfg(key, default)
    local c = WTAGarou.Silver and WTAGarou.Silver.CFG or nil
    local v = c and c[key]
    if v == nil then return default end
    return v
end

-- ---------------------------------------------------------------- pure ----

-- How a Garou's feet meet the tile: "paws" (beast form), "bare" (no intact
-- shoes), or nil (protected / not a Garou).
function SC.exposed(player, form, isGarou)
    if isGarou == false then return nil end
    if SC.BEAST_FORMS[form] then return "paws" end
    local shoes
    pcall(function()
        local worn = player:getWornItems()
        for i = 0, worn:size() - 1 do
            local it = worn:get(i):getItem()
            local loc = it and WTAGarou.Clothing and WTAGarou.Clothing.locationId and WTAGarou.Clothing.locationId(it) or nil
            if loc and tostring(loc):lower() == "shoes" then shoes = it end
        end
    end)
    if not shoes then return "bare" end
    local cond = 1
    pcall(function() cond = shoes:getCondition() end)
    if (cond or 0) <= 0 then return "bare" end
    return nil
end

-- Worked silver: the mod's own items and anything it silvered. Jewellery is
-- "Silver" by name and tag but was never filed, so it carries no dust.
function SC.workedSilver(item)
    if not item then return false end
    local ok, res = pcall(function()
        local ft = item.getFullType and item:getFullType() or nil
        if ft and tostring(ft):sub(1, 9) == "WTAGarou." then return true end
        local md = item.getModData and item:getModData() or nil
        if md then
            if md.WTAGarou_Silver == true then return true end
            if type(md.WTAGarou_SilverCoat) == "number" and md.WTAGarou_SilverCoat > 0 then return true end
            if type(md.WTAGarou_SilverAmmo) == "number" and md.WTAGarou_SilverAmmo > 0 then return true end
        end
        if item.isFluidContainer and item:isFluidContainer() then
            local fc = item:getFluidContainer()
            local name = fc and fc.getPrimaryFluid and fc:getPrimaryFluid()
            name = name and (name.getFluidTypeString and name:getFluidTypeString() or tostring(name)) or nil
            if name and tostring(name):find("WTAGarou_SilverNitrate", 1, true) then return true end
        end
        return false
    end)
    return ok and res == true
end

-- Open to the same air. 0.4.79: the engine's own line test
-- (LosUtil.lineClear) instead of "same room": air reaches through an OPEN
-- door and an open or smashed window, not through a closed door, a shut
-- window or a wall. The Oct 21 playtest found the room test blind to open
-- doorways. Same level only. Without the engine (headless tests) the old
-- room test stands in.
SC.AIR_CLEAR = { Clear = true, ClearThroughOpenDoor = true }
SC.AIR_WINDOW = "ClearThroughWindow"

-- Squares on the straight line between two squares (Bresenham), from the
-- first to the last inclusive.
function SC.linePoints(x0, y0, x1, y1)
    local pts = {}
    local dx, dy = math.abs(x1 - x0), math.abs(y1 - y0)
    local sx, sy = (x0 < x1) and 1 or -1, (y0 < y1) and 1 or -1
    local err = dx - dy
    local x, y = x0, y0
    while true do
        pts[#pts + 1] = { x, y }
        if x == x1 and y == y1 then break end
        local e2 = 2 * err
        if e2 > -dy then err = err - dy; x = x + sx end
        if e2 < dx then err = err + dx; y = y + sy end
    end
    return pts
end

-- A window on the path lets air through only when open or smashed.
function SC.windowPasses(win)
    if not win then return false end
    local ok, res = pcall(function()
        if win.IsOpen and win:IsOpen() then return true end
        if win.isDestroyed and win:isDestroyed() then return true end
        if win.isSmashed and win:isSmashed() then return true end
        if win.isGlassRemoved and win:isGlassRemoved() then return true end
        return false
    end)
    return ok and res == true
end

function SC.openWindowBetween(fromSq, toSq)
    local cell = getCell and getCell() or nil
    if not cell then return false end
    local z = fromSq:getZ()
    local pts = SC.linePoints(fromSq:getX(), fromSq:getY(), toSq:getX(), toSq:getY())
    local prev = nil
    for _, pt in ipairs(pts) do
        local sq = cell:getGridSquare(pt[1], pt[2], z)
        if prev and sq and prev.getWindowTo then
            local win = prev:getWindowTo(sq)
            if win == nil and sq.getWindowTo then win = sq:getWindowTo(prev) end
            if win ~= nil then return SC.windowPasses(win) end
        end
        prev = sq or prev
    end
    return false
end

function SC.sameRoom(fromSq, toSq)
    local a = fromSq:getRoom(); local b = toSq:getRoom()
    if a == nil and b == nil then return true end
    return a ~= nil and a == b
end

function SC.openToAir(fromSq, toSq)
    if not (fromSq and toSq) then return false end
    local ok, res = pcall(function()
        if fromSq:getZ() ~= toSq:getZ() then return false end
        if fromSq == toSq then return true end
        if LosUtil and LosUtil.lineClear and getCell and getCell() then
            local z = fromSq:getZ()
            local r = tostring(LosUtil.lineClear(getCell(), fromSq:getX(), fromSq:getY(), z,
                toSq:getX(), toSq:getY(), z, false))
            if SC.AIR_CLEAR[r] then return true end
            if r == SC.AIR_WINDOW then return SC.openWindowBetween(fromSq, toSq) end
            return false
        end
        return SC.sameRoom(fromSq, toSq)
    end)
    return ok and res == true
end

-- ---------------------------------------------------------- world object --

function SC.find(square)
    if not square then return nil end
    local found
    pcall(function()
        local objs = square:getObjects()
        for i = 0, objs:size() - 1 do
            local o = objs:get(i)
            local md = o and o.getModData and o:getModData() or nil
            if md and md[SC.FLAG] then found = o; return end
        end
    end)
    if found then SC.repairSprite(found, square) end
    return found
end

-- 0.4.82 migration: a tile placed by 0.4.77..0.4.81 carries an id-less
-- sprite (invisible to clients, lost on reload as the empty sprite). The
-- mod data survived, so the first time the owner touches such a tile give
-- it the registered sprite for its square and tell the clients. Server (or
-- single player) only; a client never changes world objects (0.4.66 spirit).
function SC.repairSprite(obj, square)
    if not obj or (isClient and isClient()) then return false end
    local name
    pcall(function()
        local spr = obj:getSprite()
        name = spr and spr.getName and spr:getName() or nil
        if spr and spr.getID and WTAGarou.ScatterSprites and spr:getID() == WTAGarou.ScatterSprites.UNSET_ID then
            name = nil                          -- right texture, but never registered: still broken for clients
        end
    end)
    if SC.isScatterSprite(name) then return false end
    local fixed = false
    pcall(function()
        SC.ensureSprites()
        local want = SC.spriteFor(square:getX(), square:getY())
        -- setSpriteFromName goes through the sprite manager (our registered
        -- id). setSprite(String) builds a NEW id-less sprite every call,
        -- which is what the Oct 23 server did every 30 frames for one tile.
        if obj.setSpriteFromName then obj:setSpriteFromName(want) else obj:setSprite(want) end
        if isServer and isServer() then obj:transmitUpdatedSpriteToClients() end
        fixed = true
    end)
    if fixed then
        print(string.format("[WTAGarou][Scatter] repaired an id-less tile sprite at %d,%d,%d", square:getX(), square:getY(), square:getZ()))
    end
    return fixed
end

function SC.place(square, uses, source)
    if not square or SC.find(square) then return nil end
    local obj
    local ok, err = pcall(function()
        SC.ensureSprites()
        obj = IsoObject.new(getCell(), square, SC.spriteFor(square:getX(), square:getY()))
        obj:getModData()[SC.FLAG] = tonumber(uses) or SC.COST_USES
        obj:getModData()[SC.SOURCE_FLAG] = source or "filings"
        square:AddTileObject(obj)
        if isServer and isServer() then obj:transmitCompleteItemToClients() end
    end)
    if not ok then print("[WTAGarou][Scatter] place failed: " .. tostring(err)); return nil end
    print(string.format("[WTAGarou][Scatter] silver scattered at %d,%d,%d", square:getX(), square:getY(), square:getZ()))
    return obj
end

function SC.remove(obj)
    if not obj then return false end
    local ok, err = pcall(function()
        local sq = obj:getSquare()
        if isServer and isServer() then
            sq:transmitRemoveItemFromSquare(obj)
        else
            sq:RemoveTileObject(obj)
        end
    end)
    if not ok then print("[WTAGarou][Scatter] remove failed: " .. tostring(err)) end
    return ok
end

local function squareAt(args)
    if not (args and getCell) then return nil end
    local sq
    pcall(function() sq = getCell():getGridSquare(tonumber(args.x), tonumber(args.y), tonumber(args.z or 0)) end)
    return sq
end

local function near(player, square)
    if not (player and square) then return false end
    local ok, res = pcall(function()
        return math.abs(player:getX() - (square:getX() + 0.5)) <= 2.5 and math.abs(player:getY() - (square:getY() + 0.5)) <= 2.5
            and math.floor(player:getZ() + 0.5) == square:getZ()
    end)
    return ok and res == true
end

-- The player's own item by id (main inventory or any bag), or nil.
function SC.ownItem(player, id)
    if not (player and id) then return nil end
    local found
    pcall(function()
        local inv = player:getInventory()
        found = inv:getItemById(tonumber(id))
    end)
    return found
end

-- Take one Silver Fragments item out of the player's inventory, here (the
-- server in multiplayer: REGRESSION_CONTRACT 0.4.66; the same code in
-- single player). Vanilla's drop path: Remove + sendRemoveItemFromContainer.
function SC.takeScrap(player, id)
    local item = SC.ownItem(player, id)
    if not item then return false end
    local ok, res = pcall(function()
        if tostring(item:getFullType()) ~= SC.SCRAP_ITEM then return false end
        local container = item:getContainer() or player:getInventory()
        if player.getPrimaryHandItem and player:getPrimaryHandItem() == item then player:setPrimaryHandItem(nil) end
        if player.getSecondaryHandItem and player:getSecondaryHandItem() == item then player:setSecondaryHandItem(nil) end
        container:Remove(item)
        if isServer and isServer() and type(sendRemoveItemFromContainer) == "function" then
            sendRemoveItemFromContainer(container, item)
        end
        return true
    end)
    return ok and res == true
end

-- Server / single-player side of the two actions. args.kind = "scrap"
-- (+ args.id of the fragments item) or "filings" (drained on the client).
function SC.serveScatter(player, args)
    local sq = squareAt(args)
    if not (sq and near(player, sq)) then return false end
    if SC.find(sq) then return false end
    if args and args.kind == "scrap" then
        if not SC.takeScrap(player, args.id) then return false end
        return SC.place(sq, SC.COST_USES, "scrap") ~= nil
    end
    return SC.place(sq, SC.COST_USES, "filings") ~= nil
end

function SC.serveGive(player, uses, source)
    local G = WTAGarou.Grant
    if not (G and G.begin and G.add) then return false end
    local batch = G.begin(player, "silver scatter"); batch.remote = false
    if source == "scrap" then
        return G.add(batch, SC.SCRAP_ITEM, 1) ~= nil
    end
    local item = G.add(batch, SC.ITEM, 1)
    if item and item.setUsedDelta and uses then
        pcall(function()
            local delta = item.getUseDelta and item:getUseDelta() or 0.05
            item:setUsedDelta(math.min(1, math.max(delta, delta * uses)))
            if isServer and isServer() and item.syncItemFields then item:syncItemFields() end
        end)
    end
    return item ~= nil
end

function SC.servePickup(player, args)
    local sq = squareAt(args)
    if not (sq and near(player, sq)) then return false end
    local obj = SC.find(sq); if not obj then return false end
    local uses = tonumber(obj:getModData()[SC.FLAG]) or SC.COST_USES
    local source = obj:getModData()[SC.SOURCE_FLAG]
    if not SC.remove(obj) then return false end
    SC.serveGive(player, uses, source)
    -- A Garou picking silver up bare-handed burns a hand (the contact rule).
    local S = WTAGarou.Silver
    if S and WTAGarou.HasGarouTrait and WTAGarou.HasGarouTrait(player) and not (S.wearsGloves and S.wearsGloves(player)) then
        pcall(function()
            local bd = player:getBodyDamage()
            local hand = (ZombRand and ZombRand(2) == 0) and "Hand_L" or "Hand_R"
            local bp = S.partByName and S.partByName(bd, hand)
            if bp and S.burnPart then
                S.burnPart(player, bp, nil)
                if S.announce then S.announce(player, hand) end
            end
        end)
    end
    return true
end

-- ------------------------------------------------------------- the hazard --

-- One hazard step for a Garou (called from the silver contact scan).
function SC.step(player, d, bd, dt)
    local sq = player.getSquare and player:getSquare() or nil
    local obj = SC.find(sq); if not obj then return nil end
    local garou = (WTAGarou.HasGarouTrait and WTAGarou.HasGarouTrait(player)) and true or false
    local how = SC.exposed(player, d and d.form, garou)
    if not how then return nil end
    local S = WTAGarou.Silver; if not (S and S.partByName and S.burnPart) then return nil end
    local foot = SC.FEET[(ZombRand and ZombRand(#SC.FEET) or 0) + 1]
    local bp = S.partByName(bd, foot); if not bp then return nil end
    local fresh = S.burnPart(player, bp, dt or 0)
    if fresh and S.announce then S.announce(player, foot) end
    local roll = ZombRand and (ZombRand(100) / 100) or 0
    if roll < cfg("SCATTER_LODGE_CHANCE", SC.LODGE_CHANCE) and not S.partHasForeign(bp, "shard") then
        pcall(function() bp:setHaveGlass(true) end)
        S.markLodged(player, bp, "shard")
    end
    return how, foot
end

-- ------------------------------------------------------------ the sniffer --

local function containerHasWorked(container, depth)
    if not container or depth > 2 then return false end
    local hit = false
    pcall(function()
        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if SC.workedSilver(it) then hit = true; return end
            if it.getInventory and it:getInventory() and containerHasWorked(it:getInventory(), depth + 1) then hit = true; return end
        end
    end)
    return hit
end
SC.containerHasWorked = containerHasWorked

-- Anything worked-silver on `square`: a scattered tile, a floor item, a
-- container's contents, another character's hands or pack.
function SC.squareSmells(square, me)
    if not square then return false end
    if SC.find(square) then return true end
    local hit = false
    pcall(function()
        local wos = square:getWorldObjects()
        for i = 0, wos:size() - 1 do
            local it = wos:get(i):getItem()
            if SC.workedSilver(it) then hit = true; return end
            if it and it.getInventory and it:getInventory() and containerHasWorked(it:getInventory(), 1) then hit = true; return end
        end
    end)
    if hit then return true end
    pcall(function()
        local objs = square:getObjects()
        for i = 0, objs:size() - 1 do
            local c = objs:get(i):getContainer()
            if c and containerHasWorked(c, 1) then hit = true; return end
        end
    end)
    if hit then return true end
    pcall(function()
        local movers = square:getMovingObjects()
        for i = 0, movers:size() - 1 do
            local m = movers:get(i)
            if m ~= me and m.getInventory then
                local p = m.getPrimaryHandItem and m:getPrimaryHandItem()
                local s = m.getSecondaryHandItem and m:getSecondaryHandItem()
                if SC.workedSilver(p) or SC.workedSilver(s) or containerHasWorked(m:getInventory(), 1) then hit = true; return end
            end
        end
    end)
    return hit
end

function SC.smell(player, form)
    local home = player.getSquare and player:getSquare() or nil
    if not home then return false end
    local r = SC.SCENT_RADIUS[form] or 3
    -- 0.4.81: silver dust in the air smells too.
    if WTAGarou.SilverSmoke and WTAGarou.SilverSmoke.near and WTAGarou.SilverSmoke.near(home, r) then return true end
    local cell = getCell and getCell() or nil
    if not cell then return false end
    local cx, cy, z = home:getX(), home:getY(), home:getZ()
    for dx = -r, r do
        for dy = -r, r do
            if dx * dx + dy * dy <= r * r then
                local sq = cell:getGridSquare(cx + dx, cy + dy, z)
                if sq and (sq == home or SC.openToAir(home, sq)) and SC.squareSmells(sq, player) then return true end
            end
        end
    end
    return false
end

local function scentNotice(player)
    if sendServerCommand and isServer and isServer() then
        pcall(sendServerCommand, player, "WTAGarou", "SilverScent", {})
    elseif WTAGarou.SilverScentReact then
        pcall(WTAGarou.SilverScentReact, player, {})
    end
end

-- Called every SCENT_INTERVAL from the body sweeps. ONE warning per sniff
-- however many silver things are near. Warns on first contact and every
-- SCENT_REPEAT seconds while the smell lingers. 0.4.79: the smell has to be
-- gone for SCENT_CLEAR seconds before the clock resets (a step behind a
-- door frame and back used to count as "walked back into it" and warned
-- again at once: the Oct 21 panel showed a line every three game minutes),
-- and two warnings are never closer than SCENT_MIN_GAP. Returns true when
-- it warned.
SC.SCENT_INTERVAL = 2
SC.SCENT_CLEAR    = 20   -- seconds of clean air before the next contact counts as new
SC.SCENT_MIN_GAP  = 30   -- never two warnings closer than this
local lastSniff = setmetatable({}, { __mode = "k" })
function SC.sniff(player, d, now)
    if not (player and d and d.isGarou) then return false end
    local last = lastSniff[player]
    if last and now - last < SC.SCENT_INTERVAL then return false end
    lastSniff[player] = now
    if SC.smell(player, d.form) then
        d.scentClearAt = nil
        local since = d.scentAt and (now - d.scentAt) or nil
        local due = (since == nil) or (since >= SC.SCENT_REPEAT)
            or (d.scentLost == true and since >= SC.SCENT_MIN_GAP)
        if due then
            d.scentAt = now
            d.scentLost = nil
            scentNotice(player)
            return true
        end
        return false
    end
    -- clean air: remember when it went, forget the contact after SCENT_CLEAR
    if d.scentAt then
        d.scentClearAt = d.scentClearAt or now
        if now - d.scentClearAt >= SC.SCENT_CLEAR then
            d.scentLost = true      -- the next contact is new (subject to MIN_GAP)
            d.scentClearAt = nil
            if now - d.scentAt >= SC.SCENT_MIN_GAP then d.scentAt = nil; d.scentLost = nil end
        end
    end
    return false
end

-- --------------------------------------------------------------- wiring ---

if Events then
    if Events.OnClientCommand then
        Events.OnClientCommand.Add(function(module, command, player, args)
            if module ~= "WTAGarou" or not (isServer and isServer()) then return end
            if command == SC.CMD_SCATTER then SC.serveScatter(player, args)
            elseif command == SC.CMD_PICKUP then SC.servePickup(player, args) end
        end)
    end
    if Events.OnPlayerUpdate then
        Events.OnPlayerUpdate.Add(function(player)
            -- single player only: the server sweep below does multiplayer
            if (isServer and isServer()) or (isClient and isClient()) then return end
            if not player or not WTAGarou.GetData then return end
            local now = WTAGarou.NowSeconds and WTAGarou.NowSeconds() or os.time()
            pcall(SC.sniff, player, WTAGarou.GetData(player), now)
        end)
    end
    if Events.OnTick then
        local acc = 0
        Events.OnTick.Add(function()
            if not (isServer and isServer()) then return end
            acc = acc + 1; if acc < 30 then return end; acc = 0
            if not getOnlinePlayers then return end
            local players = getOnlinePlayers(); if not players then return end
            local now = WTAGarou.NowSeconds and WTAGarou.NowSeconds() or os.time()
            for i = 0, players:size() - 1 do
                local p = players:get(i)
                pcall(SC.sniff, p, WTAGarou.GetData(p), now)
            end
        end)
    end
end

return SC
