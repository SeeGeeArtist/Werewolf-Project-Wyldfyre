require "WTAGarouNet"
WTAGarou.CrinosRoar = WTAGarou.CrinosRoar or {}
local R=WTAGarou.CrinosRoar
function R.onUpdate(player)
    if not player or not player:isLocalPlayer() then return end
    if not WTAGarouJava or not WTAGarouJava.consumeCrinosRoar then return end
    if not WTAGarouJava.consumeCrinosRoar(player) then return end
    -- Consume even a stale edge, but never send it after leaving Crinos.
    local md=player:getModData()
    if player:isDead() or not md or not md.WTAGarou or md.WTAGarou.form~="Crinos" then return end
    WTAGarou.Net.ToServer(player,"CrinosRoarRequest",{})
end
if Events and Events.OnPlayerUpdate then Events.OnPlayerUpdate.Add(R.onUpdate) end
