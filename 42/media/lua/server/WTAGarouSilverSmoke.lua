--[[
    WTAGarou - Silver smoke bomb (0.4.81, "Home Alone" part 2)

    Item: WTAGarou.SilverSmokeBomb, a vanilla Smoke Bomb repacked with ten
    uses of Silver Filings (recipe "Pack Silver Filings into Smoke Bomb").
    The engine throws it, lands it and smokes it exactly like the vanilla
    bomb (same PhysicsObject / SmokeRange / ExplosionDuration); zombies
    inside lose their target as usual. What this file adds is the dust.

    Where the dust is: the engine explodes a trap on the server (or in
    single player) and fires OnThrowableExplode(trap, square). For our item
    we remember a cloud: centre, floor, radius (= SmokeRange) and an expiry
    ExplosionDuration game minutes later, the window during which the trap
    keeps refreshing its smoke squares. A square is "in the dust" when it is
    on the cloud's floor, within the radius and the engine's own line test
    from the centre is not Blocked / ClearThroughClosedDoor: the same test
    IsoTrap uses to decide which squares get smoke, so the dust matches the
    visible smoke.

    What it does to a Garou breathing it (every body sweep, server Lua,
    REGRESSION_CONTRACT 0.4.75): a silver burn on the face and throat (the
    Head and Neck parts, 0.4.94 - the dust is in the eyes and down the
    windpipe; it blocks regeneration like every silver burn and shows in
    the health panel), Rage, a cough cue, the
    silver scent, and a veil cue every sweep so the owning client can draw
    the impaired vision (WTAGarouSmokeVeil.lua). A worn vanilla gas mask
    (ItemTag GasMask / ImprovisedGasMask, compared by tag NAME - 0.4.19:
    InventoryItem.hasTag takes ItemTag objects, a String throws) keeps the
    dust out; a mask with no filter does not. Humans are not Garou and
    breathe it like ordinary smoke. Any form breathes; there is no holding
    your breath.
]]

WTAGarou = WTAGarou or {}
local SM = WTAGarou.SilverSmoke or {}
WTAGarou.SilverSmoke = SM

SM.ITEM            = "WTAGarou.SilverSmokeBomb"
SM.DEFAULT_RADIUS  = 5          -- SmokeRange in the item script
SM.DEFAULT_MINUTES = 10         -- ExplosionDuration in the item script
SM.BREATH_PART     = "Head"     -- 0.4.83: eyes and throat; the face burns
SM.BREATH_PARTS    = { "Head", "Neck" }   -- 0.4.94: the dust settles on the face and the throat
SM.BREATH_LABEL    = "face and throat"    -- what the notice calls it
SM.RAGE_PER_SECOND = 0.4        -- ~4 Rage for ten seconds in the dust
SM.COUGH_GAP       = 6          -- seconds between cough cues
SM.MASK_TAGS       = { gasmask = true, improvisedgasmask = true }  -- lower-case ItemTag names that keep the dust out (GasMaskNoFilter does not)
SM.SCENT_EXTRA     = 2          -- the dust smells a bit past the smoke edge
SM.clouds = SM.clouds or {}

local function cfg(key, default)
    local c = WTAGarou.Silver and WTAGarou.Silver.CFG or nil
    local v = c and c[key]
    if v == nil then return default end
    return v
end

-- World age in hours (the trap's own clock), or nil without a game.
function SM.nowHours()
    local t
    pcall(function() t = getGameTime():getWorldAgeHours() end)
    return t
end

-- Register a cloud. `minutes` of game time from `now` (hours).
function SM.addCloud(x, y, z, radius, minutes, now)
    now = now or SM.nowHours() or 0
    local cloud = {
        x = math.floor(tonumber(x) or 0), y = math.floor(tonumber(y) or 0), z = math.floor(tonumber(z) or 0),
        r = tonumber(radius) or SM.DEFAULT_RADIUS,
        untilHours = now + (tonumber(minutes) or SM.DEFAULT_MINUTES) / 60,
    }
    SM.clouds[#SM.clouds + 1] = cloud
    print(string.format("[WTAGarou][SilverSmoke] silver dust at %d,%d,%d r=%d for %s min", cloud.x, cloud.y, cloud.z, cloud.r, tostring(minutes or SM.DEFAULT_MINUTES)))
    return cloud
end

function SM.prune(now)
    now = now or SM.nowHours() or 0
    local keep = {}
    for _, c in ipairs(SM.clouds) do if c.untilHours > now then keep[#keep + 1] = c end end
    SM.clouds = keep
    return #keep
end

-- OnThrowableExplode(trap, square): server and single player.
function SM.onExplode(trap, square)
    local ft, radius, minutes
    local ok = pcall(function()
        local item = trap:getItem()
        ft = item and tostring(item:getFullType()) or nil
        radius = trap.getSmokeRange and trap:getSmokeRange() or nil
        minutes = trap.getExplosionDuration and trap:getExplosionDuration() or nil
    end)
    if not ok or ft ~= SM.ITEM then return nil end
    local sq = square or (trap.getSquare and trap:getSquare())
    local x, y, z = 0, 0, 0
    pcall(function()
        if sq then x, y, z = sq:getX(), sq:getY(), sq:getZ() else x, y, z = trap:getX(), trap:getY(), trap:getZ() end
    end)
    if not radius or radius <= 0 then radius = SM.DEFAULT_RADIUS end
    if not minutes or minutes <= 0 then minutes = SM.DEFAULT_MINUTES end
    return SM.addCloud(x, y, z, radius, minutes)
end

-- The engine's line test from the cloud centre to a square: the smoke
-- reaches where IsoTrap's drawCircleExplosion / refreshSmokeBombSmoke do.
function SM.reaches(cloud, x, y, z)
    if not (LosUtil and getCell) then return true end
    local pass = true
    pcall(function()
        local res = tostring(LosUtil.lineClear(getCell(), cloud.x, cloud.y, cloud.z, x, y, z, false))
        pass = res ~= "Blocked" and res ~= "ClearThroughClosedDoor"
    end)
    return pass
end

-- Is square (x,y,z) inside any live cloud (radius + `extra`)? Returns the cloud.
function SM.cloudAt(x, y, z, now, extra)
    extra = extra or 0
    now = now or SM.nowHours() or 0
    x, y, z = math.floor(tonumber(x) or 0), math.floor(tonumber(y) or 0), math.floor(tonumber(z) or 0)
    for _, c in ipairs(SM.clouds) do
        if c.untilHours > now and c.z == z then
            local dx, dy = x - c.x, y - c.y
            local r = c.r + extra
            if dx * dx + dy * dy <= r * r and SM.reaches(c, x, y, z) then return c end
        end
    end
    return nil
end

-- For the sniffer (WTAGarouScatter.smell): does the dust smell from `square`?
function SM.near(square, radius)
    if not square or #SM.clouds == 0 then return false end
    local x, y, z
    pcall(function() x, y, z = square:getX(), square:getY(), square:getZ() end)
    if not x then return false end
    return SM.cloudAt(x, y, z, nil, (tonumber(radius) or 0) + SM.SCENT_EXTRA) ~= nil
end

-- Lower-case name of an ItemTag ("base:gasmask" -> "gasmask").
local function tagKey(tag)
    local S = WTAGarou.Silver
    if S and S.tagKey then return S.tagKey(tag) end
    local s = tostring(tag or ""):lower()
    return (s:gsub("^.*:", ""))
end
SM.tagKey = tagKey

-- Does this item carry one of the mask tags? Walks getTags() and compares
-- names: 42.20.2 exposes hasTag(ItemTag...) only, so hasTag("GasMask")
-- throws "No implementation found" (46 times a second in the Oct 23 coop
-- console, which is why the full gas mask did not block anything).
function SM.itemIsMask(item)
    if not item or not item.getTags then return false end
    local found = false
    pcall(function()
        local tags = item:getTags()
        if not tags then return end
        local it = tags.iterator and tags:iterator() or nil
        while it and it:hasNext() do
            if SM.MASK_TAGS[tagKey(it:next())] then found = true; return end
        end
        if type(tags) == "table" then
            for _, t in ipairs(tags) do if SM.MASK_TAGS[tagKey(t)] then found = true; return end end
        end
    end)
    return found
end

-- A worn vanilla gas mask keeps the dust out.
function SM.masked(player)
    local masked = false
    pcall(function()
        local worn = player:getWornItems()
        for i = 0, worn:size() - 1 do
            local it = worn:get(i):getItem()
            if SM.itemIsMask(it) then masked = true; return end
        end
    end)
    return masked
end

-- Veil cue every sweep; cough + halo + log line only when `cough` is set.
local function smokeNotice(player, seconds, cough)
    local args = { seconds = seconds, cough = cough and true or false }
    if sendServerCommand and isServer and isServer() then
        pcall(sendServerCommand, player, "WTAGarou", "SilverSmoke", args)
    elseif WTAGarou.SilverSmokeReact then
        pcall(WTAGarou.SilverSmokeReact, player, args)
    end
end
SM.smokeNotice = smokeNotice

-- One body sweep for a Garou player; dt seconds since the previous one.
-- Returns the cloud when the player breathed dust this sweep.
function SM.step(player, d, bd, dt)
    if #SM.clouds == 0 or not (player and d and bd) then return nil end
    local now = SM.nowHours() or 0
    if SM.prune(now) == 0 then d.silverSmokeSeconds = nil; return nil end
    local sq = player.getSquare and player:getSquare() or nil
    if not sq then return nil end
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    local cloud = SM.cloudAt(x, y, z, now, 0)
    if not cloud or SM.masked(player) then
        d.silverSmokeSeconds = nil
        return nil
    end
    dt = tonumber(dt) or 0
    local was = d.silverSmokeSeconds or 0
    d.silverSmokeSeconds = was + dt
    local S = WTAGarou.Silver
    if S and S.partByName and S.burnPart then
        local anyFresh = false
        for _, name in ipairs(SM.BREATH_PARTS or { SM.BREATH_PART }) do
            local bp = S.partByName(bd, name)
            if bp and S.burnPart(player, bp, dt) then anyFresh = true end
        end
        if anyFresh and S.announce then S.announce(player, SM.BREATH_LABEL) end
    end
    if WTAGarou.AddRage and dt > 0 then
        pcall(WTAGarou.AddRage, player, cfg("SMOKE_RAGE_PER_SECOND", SM.RAGE_PER_SECOND) * dt)
    end
    local gap = cfg("SMOKE_COUGH_GAP", SM.COUGH_GAP)
    local cough = was == 0 or math.floor(was / gap) ~= math.floor(d.silverSmokeSeconds / gap)
    smokeNotice(player, d.silverSmokeSeconds, cough)
    return cloud
end

if Events and Events.OnThrowableExplode then Events.OnThrowableExplode.Add(SM.onExplode) end

return SM
