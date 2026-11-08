-- A narrow, self-only opt-in, NOT a way around Debug* permissions.
require "WTAGarouNet"
require "WTAGarouTraitBundle"
WTAGarou.EnrollmentServer = WTAGarou.EnrollmentServer or {}
local E = WTAGarou.EnrollmentServer
local function alive(player)
    return player and player.isDead and not player:isDead()
end
local function enabled()
    return not (SandboxVars and SandboxVars.WTAGarou
        and SandboxVars.WTAGarou.AllowWerewolfOptIn == false)
end
local function reply(player, status, reason)
    local d = WTAGarou.GetData(player)
    WTAGarou.Net.ToClient(player, "WerewolfEnrollment", {
        status = status, reason = reason, decision = d.werewolfOfferDecision,
    })
end

-- Also used inside the existing privileged DebugTrait branch.
function E.grant(player, removing)
    if not alive(player) then return false end
    local ok, changed = WTAGarou.TraitBundle.apply(player, removing)
    if not ok then reply(player, "error", changed); return false end
    local d = WTAGarou.GetData(player)
    d.isGarou = not removing
    d.werewolfOfferDecision = removing and "declined" or "accepted"
    -- B42.21 SyncXp is client -> server ONLY. Do not call it here or
    -- depend on an ordinary user's client sending a vanilla stats packet.
    -- Mirror the server-approved native change through the addressed reply.
    reply(player, removing and "removed" or "accepted")
    return true
end

function E.handle(module, command, player, args)
    if module ~= "WTAGarou" then return end
    if command ~= "RequestWerewolfOffer" and command ~= "AnswerWerewolfOffer" then return end
    if not alive(player) then return end
    args = args or {}
    local d = WTAGarou.GetData(player)
    if command == "RequestWerewolfOffer" then
        if d.werewolfOfferDecision == "accepted" then
            E.grant(player, false) -- reconnect repair, idempotent
        elseif WTAGarou.HasGarouTrait(player) then
            d.werewolfOfferDecision = d.werewolfOfferDecision or "existing"
            reply(player, "existing")
        elseif d.werewolfOfferDecision then
            reply(player, "declined")
        elseif not enabled() then
            reply(player, "disabled")
        else
            -- Showing a prompt is not a saved decision.
            reply(player, "offer")
        end
        return
    end
    -- No incoming argument can select another player, trait, XP amount or role.
    if type(args.accept) ~= "boolean" then reply(player, "error", "Choose Yes or No."); return end
    if not args.accept then
        if d.werewolfOfferDecision == "accepted" or WTAGarou.HasGarouTrait(player) then
            reply(player, "existing") -- stale No cannot undo a grant
        else
            d.werewolfOfferDecision = "declined"
            reply(player, "declined")
        end
        return
    end
    if not enabled() then
        reply(player, "disabled", "Werewolf opt-in is disabled by the host.")
        return
    end
    E.grant(player, false)
end
Events.OnClientCommand.Add(E.handle)
WTAGarou.Net.RegisterServerHandler(E.handle)
return E
