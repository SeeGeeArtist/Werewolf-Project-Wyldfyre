--[[
    WTAGarou - Tough feet on the server (0.4.82)

    Oct 22 hosted playtest: "I'm in glabro and I stepped outside without
    shoes and my foot got scratched."

    Vanilla IsoPlayer.updateFootInjuries() is the barefoot loop: no shoes
    (or shoes at 0 condition), walking or running outdoors, and every so
    often a random Foot_L/Foot_R scratch (1..3 scratch time, more each
    time, a cut past 30, bleeding past 20), plus the broken-glass branch.
    It is guarded by `else if (!GameClient.client)`: it runs on the SERVER
    and in single player, never on a multiplayer client. The mod's
    FootInjuryPatch (Java, client-only by rule 0.4.65) skips that loop for
    a paw form, which is why tough feet held in single player and did
    nothing in the hosted game: the hosted child server has no Java and
    ran the loop untouched. The silver burn had nothing to do with it.

    Server Lua owns every player's BodyDamage (0.4.75), so the server
    shrugs the loop's wounds off here: a tough-footed form (FormData
    toughFeet: Glabro, Crinos, Hispo, Lupus) that is barefoot and shows a
    FRESH foot scratch or cut (timers still within the loop's first roll,
    FRESH_TIME) has the wound cleared on the next body sweep (every 10
    ticks). Older or bigger foot wounds, feet with lodged silver, burns
    and glass flags are never touched; a real fight wound on a foot that
    happens to be that fresh is the accepted cost of a form whose feet
    are tough anyway.
]]

WTAGarou = WTAGarou or {}
WTAGarou.Paws = WTAGarou.Paws or {}
local P = WTAGarou.Paws

P.FEET       = { "Foot_L", "Foot_R" }
P.FRESH_TIME = 3.5          -- the loop's first roll is Rand(1, 3)
P.cleared    = 0

function P.toughFeet(form)
    local fd = WTAGarou.FormData and WTAGarou.FormData[tostring(form)]
    return fd and fd.toughFeet == true or false
end

-- "bare" when no footwear is worn or it is at 0 condition (the loop's own
-- test). Uses the scatter module's reader when present.
function P.barefoot(player, form)
    local SC = WTAGarou.Scatter
    if SC and SC.exposed then
        local e = SC.exposed(player, form, true)
        return e == "bare" or e == "paws"
    end
    return false
end

-- Pure rule for one foot. `foot` offers scratched(), isCut(),
-- getScratchTime(), getCutTime(), bleeding(). Returns true when the wound
-- is the barefoot loop's fresh roll.
function P.isFreshLoopWound(foot, fresh)
    fresh = fresh or P.FRESH_TIME
    local scratched = foot:scratched()
    local cut = foot:isCut()
    if not (scratched or cut) then return false end
    if scratched and foot:getScratchTime() > fresh then return false end
    if cut and foot:getCutTime() > fresh then return false end
    return true
end

-- Same lookup the silver module uses (type name match over getBodyParts()).
function P.partByName(bd, name)
    if WTAGarou.Silver and WTAGarou.Silver.partByName then return WTAGarou.Silver.partByName(bd, name) end
    local found
    pcall(function()
        local parts = bd:getBodyParts()
        for i = 0, parts:size() - 1 do
            local bp = parts:get(i)
            if tostring(bp:getType()) == name then found = bp; return end
        end
    end)
    return found
end

function P.clearFoot(foot)
    local function try(f) pcall(f) end
    try(function() foot:setScratched(false, true) end)
    try(function() foot:setScratched(false) end)
    try(function() foot:setScratchTime(0) end)
    try(function() foot:setCut(false) end)
    try(function() foot:setCutTime(0) end)
    try(function() foot:setBleeding(false) end)
    try(function() foot:setBleedingTime(0) end)
end

-- Server body sweep hook. Returns the number of feet cleared.
function P.sweep(player, d, bd)
    if not (player and d and bd and d.isGarou) then return 0 end
    if not P.toughFeet(d.form) then return 0 end
    if not P.barefoot(player, d.form) then return 0 end
    local n = 0
    for _, key in ipairs(P.FEET) do
        local lodged = d.silverLodged and d.silverLodged[key]
        if not lodged then
            pcall(function()
                local foot = P.partByName(bd, key)
                if foot and P.isFreshLoopWound(foot) then
                    P.clearFoot(foot)
                    n = n + 1
                    P.cleared = P.cleared + 1
                    print(string.format("[WTAGarou][Paws] %s shrugged off a barefoot %s on %s (tough feet)",
                        tostring(player:getUsername()), tostring(d.form), key))
                end
            end)
        end
    end
    if n > 0 then pcall(function() bd:calculateOverallHealth() end) end
    return n
end
