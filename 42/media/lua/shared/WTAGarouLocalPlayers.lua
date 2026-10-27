-- Local character ownership, never remote gameplay authority.
WTAGarou = WTAGarou or {}
function WTAGarou.LocalPlayers()
    local out={}
    if getSpecificPlayer then
        local count=getNumActivePlayers and getNumActivePlayers() or 4
        for i=0,math.max(0,count-1) do
            local p=getSpecificPlayer(i)
            if p then out[#out+1]=p end
        end
    elseif getPlayer then
        local p=getPlayer()
        if p then out[1]=p end
    end
    return out
end
function WTAGarou.PrimaryLocalPlayer()
    if getSpecificPlayer then return getSpecificPlayer(0) end
    return getPlayer and getPlayer() or nil
end
function WTAGarou.HUDFor(player)
    local H=WTAGarou.HUD
    if not H then return nil end
    if H.forPlayer then return H.forPlayer(player) end
    -- Old single-panel integrations/test fixtures only. Never use this
    -- fallback after the new per-character HUD manager has been loaded.
    return H.instance
end
