--[[
    WTAGarou - Doorway / door charge client glue (0.4.68)

    The rules themselves run in the Java agent (DoorwayRuntime): an upright
    Berzerker is refused at doorway edges, a running one ducks (sneak forced
    and restored a tile past the frame), a sprint into a closed wooden door
    or a climbable window skips the sprint stumble. This file only

      * pushes the tunables and the per-frame Rage value to Java,
      * shows the "crouch to pass" hint when Java reports a refusal,
      * relays a charged door to the SERVER (which re-checks it, breaks it
        and spends Rage/stamina: no client-side world or Rage writes), and
      * tells the player what happened.

    Nothing here is required by the server (REGRESSION_CONTRACT 0.4.65).
]]
require "WTAGarouNet"
WTAGarou.DoorwayClient = WTAGarou.DoorwayClient or {}
local DW = WTAGarou.DoorwayClient
DW.HINT_EVERY_SECONDS = 1.0
local lastHintAt = setmetatable({}, { __mode = "k" })
local pushed = false

local function java()
    return WTAGarouJava and WTAGarouJava.tickDoorway and WTAGarouJava.pollDoorCharge
end

local function pushTunables()
    if pushed or not java() then return end
    local C, D = WTAGarou.DoorCharge or {}, WTAGarou.Doorway or {}
    pcall(function()
        if WTAGarouJava.setDoorChargeCosts then
            WTAGarouJava.setDoorChargeCosts(C.RAGE or 8, C.RAGE_LOCKED or 12)
        end
        if WTAGarouJava.setDoorwayDuckRule then
            WTAGarouJava.setDoorwayDuckRule(D.DUCK_RELEASE_TILES or 1.0, D.DUCK_TIMEOUT_MS or 2500)
        end
    end)
    pushed = true
end
DW.pushTunables = pushTunables

-- Pure helper (tested): the command payload for a charged IsoDoor.
function DW.chargeArgs(door)
    if not door then return nil end
    local sq = door.getSquare and door:getSquare() or nil
    if not sq then return nil end
    return {
        x = sq:getX(), y = sq:getY(), z = sq:getZ(),
        north = (door.getNorth and door:getNorth() == true) or false,
    }
end

function DW.onUpdate(player)
    if not player or not player:isLocalPlayer() then return end
    if not java() then return end
    pushTunables()
    local md = player:getModData()
    local d = md and md.WTAGarou
    if not d or (((WTAGarou.Doorway or {}).TALL_FORMS or {})[d.form] ~= true) then return end
    local rage = tonumber(d.rage) or 0
    local okTick, hint = pcall(function() return WTAGarouJava.tickDoorway(player, rage) end)
    if okTick and hint == true then
        local now = getTimestamp()
        if (lastHintAt[player] or 0) + DW.HINT_EVERY_SECONDS <= now then
            lastHintAt[player] = now
            local hud = WTAGarou.HUDFor and WTAGarou.HUDFor(player)
            if hud then hud:flashDenial((WTAGarou.Doorway or {}).HINT or "Too tall for the doorway. Crouch to pass.") end
        end
    end
    local okPoll, door = pcall(function() return WTAGarouJava.pollDoorCharge(player) end)
    if okPoll and door then
        local args = DW.chargeArgs(door)
        if args then WTAGarou.Net.ToServer(player, "CrinosDoorCharge", args) end
    end
end

local RESULT_TEXT = {
    no_rage    = "Not enough Rage to smash the door.",
    not_wood   = "That door will not give.",
    barricaded = "The barricade holds.",
    too_far    = "You bounce off the door.",
    not_closed = nil, no_door = nil, not_crinos = nil, bad_args = nil, error = nil,
}
function DW.onServerCommand(module, command, args)
    if module ~= "WTAGarou" or command ~= "DoorChargeResult" then return end
    local player = getSpecificPlayer and getSpecificPlayer(0) or getPlayer()
    local hud = player and WTAGarou.HUDFor and WTAGarou.HUDFor(player)
    if not hud then return end
    args = args or {}
    if args.reason == nil then
        local rage = WTAGarou.DoorChargeCost and WTAGarou.DoorChargeCost(args.locked == true) or 0
        hud:pushNotice(string.format("You smash through the %sdoor. -%d Rage.", args.locked and "locked " or "", rage))
    else
        local text = RESULT_TEXT[tostring(args.reason)]
        if text then hud:flashDenial(text) end
    end
end

if Events and Events.OnPlayerUpdate then Events.OnPlayerUpdate.Add(DW.onUpdate) end
if Events and Events.OnServerCommand then Events.OnServerCommand.Add(DW.onServerCommand) end
