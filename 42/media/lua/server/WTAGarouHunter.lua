--[[
    WTAGarou - Hunter class assignment (v0.2.0)

    Every in-game hour, roll for each Garou player's infamy: a matching number
    of nearby human NPCs are promoted to Hunter class. Hunter promotion means:
      - Tagged with WTAGarou_IsHunter
      - Loadout gets a silver knife (via WTAGarouSilver)
      - Recognition range goes to melee distance regardless of form
]]

WTAGarou = WTAGarou or {}

local function tryPromoteHunter(candidate)
    if not candidate then return false end
    local md = candidate:getModData()
    if md[WTAGarou.Tags.HUNTER] then return false end
    if md[WTAGarou.Tags.GAROU]  then return false end -- Garou aren't Hunters
    md[WTAGarou.Tags.HUNTER] = true

    -- Grant a silver knife inventory drop if the character has an inventory.
    if candidate.getInventory and candidate:getInventory() then
        pcall(function()
            candidate:getInventory():AddItem("WTAGarou.SilverKnife")
        end)
    end
    return true
end

local lastRollHour = -1
Events.EveryOneMinute.Add(function()
    if not (isServer() or isClient()) then return end
    local gt = getGameTime(); if not gt then return end
    local hour = math.floor(gt:getWorldAgeHours())
    if hour == lastRollHour then return end
    lastRollHour = hour

    local players = getOnlinePlayers(); if not players then return end
    for i=0, players:size()-1 do
        local p = players:get(i)
        if p and not p:isDead() then
            local inf = WTAGarou.GetInfamy(p)
            if inf > 0 then
                local chance = inf * WTAGarou.Infamy.HUNTER_HOURLY_CHANCE_PER_POINT
                if ZombRand and ZombRand(1000) < math.floor(chance * 1000) then
                    -- Pick a nearby NPC and promote them.
                    local nearby = WTAGarou.Adapters.getHumansInRange(p:getX(), p:getY(), p:getZ(), 40)
                    for _, npc in ipairs(nearby) do
                        if npc ~= p and tryPromoteHunter(npc) then break end
                    end
                end
            end
        end
    end
end)
