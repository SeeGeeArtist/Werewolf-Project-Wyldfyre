--[[
    WTAGarou - Client-side witness scanner (v0.3.7)

    Once per second, scans human players and Bandits/Bandits Week One NPCs.
    A witnessed transformation reacts immediately; sustained supernatural-form
    exposure reacts after the form's configured look time. Living witnesses
    are streamed for Infamy tracking, while confirmed deaths remove them.
]]

WTAGarou = WTAGarou or {}

require "WTAGarouNet"
WTAGarou.WitnessScan = WTAGarou.WitnessScan or {}

local lookState = {}
local lastForm = nil

local function hasLOS(player, other)
    if not (player and other) or player:getZ() ~= other:getZ() then return false end
    if IsoUtils and IsoUtils.LineClearCollide then
        return not IsoUtils.LineClearCollide(
            player:getX(), player:getY(), player:getZ(),
            other:getX(), other:getY(), other:getZ(), getCell())
    end
    local dx = other:getX() - player:getX()
    local dy = other:getY() - player:getY()
    return math.sqrt(dx * dx + dy * dy) <= WTAGarou.Delirium.SIGHT_TILES
end

local function isDead(char)
    local dead = false
    if char and char.isDead then pcall(function() dead = char:isDead() end) end
    if not dead and char and char.getHealth then
        pcall(function() dead = char:getHealth() <= 0 end)
    end
    return dead
end

local function react(npc, player, tier)
    local adapters = WTAGarou.Adapters
    if not adapters then return end

    if tier >= 3 and adapters.isBrave and adapters.isBrave(npc) then
        if adapters.makeAttack then adapters.makeAttack(npc, player) end
    elseif tier >= 1 and adapters.makeFlee then
        adapters.makeFlee(npc, player)
    end
end

-- 0.4.79: another player is never a witness (friends with PvP on were
-- raising each other's Infamy on Oct 21).
local function isPlayerCharacter(char)
    if not char then return false end
    if instanceof then
        local ok, res = pcall(instanceof, char, "IsoPlayer")
        if ok and res then return true end
    end
    return char.isLocalPlayer ~= nil or char.getUsername ~= nil
end
WTAGarou.WitnessScan.isPlayerCharacter = isPlayerCharacter

local function scan()
    if WTAGarou.Delirium and WTAGarou.Delirium.ENABLED == false then return end
    local player = getPlayer()
    if not player then return end

    local adapters = WTAGarou.Adapters
    if not adapters or not adapters.getHumansInRange or
       not adapters.getCharacterID or not adapters.isHunter then
        return
    end

    local d = WTAGarou.GetData(player)
    local supernatural = WTAGarou.IsSupernatural(d.form)
    local justTransformed = supernatural and lastForm ~= nil and lastForm ~= d.form
    lastForm = d.form

    local now = getTimestamp()
    local dReport, wReport, deadReport = {}, {}, {}
    local deadReportCount = 0

    for id, state in pairs(lookState) do
        if state.npc and isDead(state.npc) then
            deadReport[id] = true
            deadReportCount = deadReportCount + 1
            lookState[id] = nil
        end
    end

    if supernatural then
        local trigger = WTAGarou.Delirium.LOOK_TIME_TRIGGER[d.form] or 3.0
        local tier = WTAGarou.GetForm(d.form).deliriumTier or 0
        local nearby = adapters.getHumansInRange(
            player:getX(), player:getY(), player:getZ(), WTAGarou.Delirium.SIGHT_TILES)

        for _, npc in ipairs(nearby) do
            local playerWitness = isPlayerCharacter(npc) and not (WTAGarou.Delirium and WTAGarou.Delirium.PLAYERS_WITNESS)
            if npc ~= player and not playerWitness and not isDead(npc) and hasLOS(player, npc) then
                local id = adapters.getCharacterID(npc)
                local state = lookState[id]
                if not state then
                    state = { firstSeenAt = now, npc = npc, lastReportAt = 0 }
                    lookState[id] = state
                else
                    state.npc = npc
                end

                local exposed = justTransformed or (now - state.firstSeenAt >= trigger)
                if exposed then
                    wReport[id] = {
                        form = d.form,
                        isHunter = adapters.isHunter(npc),
                        x = npc:getX(), y = npc:getY(), z = npc:getZ(),
                    }
                    if now - (state.lastReportAt or 0) >= 4 then
                        state.lastReportAt = now
                        table.insert(dReport, {
                            id = id,
                            name = npc.getUsername and npc:getUsername() or "",
                            x = npc:getX(), y = npc:getY(), z = npc:getZ(),
                        })
                        react(npc, player, tier)
                    end
                end
            end
        end
    end

    -- Kahlua's client environment does not expose Lua's global next(). The old
    -- `if next(deadReport)` line therefore threw once per scan forever. Track
    -- insertions explicitly instead of probing the table with next().
    if deadReportCount > 0 then
        WTAGarou.Net.ToServer(player, "WitnessDeath", { witnesses = deadReport })
    end
    if #dReport > 0 then
        WTAGarou.Net.ToServer(player, "DeliriumReport", { witnesses = dReport })
    end
    WTAGarou.Net.ToServer(player, "WitnessTick", { witnesses = wReport })
end

if Events.EveryOneSecond then
    Events.EveryOneSecond.Add(scan)
else
    Events.EveryOneMinute.Add(scan)
end
