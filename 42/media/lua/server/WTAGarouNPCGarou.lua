--[[
    WTAGarou - NPC Garou faction (v0.2.1)

    On world load, a fraction of the human NPCs registered by Knox/Bandits are
    tagged as NPC Garou. A subset are Black Spiral Dancers -- the corrupted
    Werewolf: The Apocalypse tribe that has fallen to the Wyrm and hunts other
    Garou. Neutral NPC Garou may turn Black Spiral after witnessing a shift.

    NPC Garou recognize the player at greater distance when the player's
    Infamy is high, even in Homid form.

    We don't model shift AI in v0.2 beyond a "hide if townsfolk are watching"
    tag consumed by cosmetics; full transform behavior lands in v0.3.
]]

WTAGarou = WTAGarou or {}

local INIT_TAG = "WTAGarou_NPCGarouInitialized"

local function tagOnce(char)
    if not char then return end
    local md = char:getModData()
    if md[INIT_TAG] then return end
    md[INIT_TAG] = true
    if ZombRand and ZombRand(1000) < 60 then       -- ~6% of NPCs are Garou
        md[WTAGarou.Tags.GAROU] = true
        if ZombRand(1000) < 200 then               -- 20% of those are BSD
            md[WTAGarou.Tags.BSD] = true
        end
    end
end

-- Periodically sweep nearby NPCs so newly-spawned ones get tagged.
local sweepTick = 0
Events.OnTick.Add(function()
    if not (isServer() or isClient()) then return end
    sweepTick = sweepTick + 1
    if sweepTick < 120 then return end
    sweepTick = 0
    local players = getOnlinePlayers(); if not players then return end
    for i=0, players:size()-1 do
        local p = players:get(i)
        if p and not p:isDead() then
            local nearby = WTAGarou.Adapters.getHumansInRange(p:getX(), p:getY(), p:getZ(), 60)
            for _, npc in ipairs(nearby) do tagOnce(npc) end
        end
    end
end)

-- On witnessing a shift, roll for BSD conversion of a random nearby neutral Garou.
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "WTAGarou" or command ~= "TransformBroadcast" then return end
    local nearby = WTAGarou.Adapters.getHumansInRange(player:getX(), player:getY(), player:getZ(), 30)
    for _, npc in ipairs(nearby) do
        if WTAGarou.Adapters.isGarou(npc) and not WTAGarou.Adapters.isBlackSpiral(npc) then
            if ZombRand and ZombRand(1000) < math.floor(WTAGarou.Infamy.BSD_TURN_CHANCE * 1000) then
                npc:getModData()[WTAGarou.Tags.BSD] = true
                WTAGarou.Adapters.makeAttack(npc, player)
            end
        end
    end
end)
