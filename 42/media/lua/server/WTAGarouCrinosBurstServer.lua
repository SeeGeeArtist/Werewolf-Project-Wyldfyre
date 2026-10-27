require "WTAGarouCrinosBurst"
require "WTAGarouNet"
local B=WTAGarou.CrinosBurst
local serial=0
local function emit(player,reason)
    local cfg=WTAGarou.CrinosShiftBurst or {}
    if isClient() or cfg.ENABLED==false
        or not player or player:isDead() or not WTAGarou.HasGarouTrait(player) then return end
    if WTAGarou.GetData(player).form~="Crinos" then return end
    local packet={x=player:getX(),y=player:getY(),z=player:getZ(),
        radius=math.max(0.25,math.min(3,tonumber(cfg.RADIUS) or 1.5)),
        force=math.max(0.1,math.min(2,tonumber(cfg.HIT_FORCE) or 1))}
    if not B.finite(packet.x) or not B.finite(packet.y) or not B.finite(packet.z)
        or not B.finite(packet.radius) or not B.finite(packet.force) then return end
    local cell=getCell()
    if not cell or not player:getSquare() then return end
    local zombies=cell:getZombieList()
    local ids,seen={},{}
    local count=0
    for i=0,zombies:size()-1 do
        local zombie=zombies:get(i)
        local ok,eligible=pcall(B.eligible,zombie,packet)
        if ok and eligible then
            if isServer() and zombie:getOwner()~=nil then
                local id=zombie:getOnlineID()
                if id and id>=0 and not seen[id] then ids[#ids+1]=id; seen[id]=true end
            end
            local pushed,result=pcall(B.push,zombie,packet)
            if pushed and result then count=count+1 end
            if not pushed then print("[WTAGarou][CrinosBurst] push failed: "..tostring(result)) end
        end
    end
    -- Only this authoritative selector creates packets. Roar commands carry
    -- no position, radius, force or targets; those always come from here.
    serial=serial+1
    for first=1,#ids,128 do
        local targets={}
        for i=first,math.min(first+127,#ids) do targets[#targets+1]=ids[i] end
        WTAGarou.Net.Broadcast("CrinosShiftBurst",{
            serial=tostring(getTimestamp())..":"..serial..":"..first,
            x=packet.x,y=packet.y,z=packet.z,radius=packet.radius,force=packet.force,targets=targets,
        })
    end
    print("[WTAGarou][CrinosBurst] "..reason.."; local pushes="..count.."; network targets="..#ids)
    return true
end
function B.onCompleted(player,previous,target)
    if target~="Crinos" or previous=="Crinos" then return end
    return emit(player,"completed Crinos shift")
end
local lastRoar=setmetatable({}, {__mode="k"})
local lastKnockback=setmetatable({}, {__mode="k"})
function B.onRoar(player)
    if isClient() or not player or player:isDead() or not WTAGarou.HasGarouTrait(player)
        or WTAGarou.GetData(player).form~="Crinos" or player:isSneaking() then return end
    local now=getTimestampMs and getTimestampMs() or getTimestamp()*1000
    -- Network flood/duplicate guard, not a Rage cost or a long ability cooldown.
    if lastRoar[player] and now-lastRoar[player]<250 then return end
    lastRoar[player]=now
    -- SP already gets the Java Callout world sound. MP also enforces the
    -- noise on authority, so a burst request cannot be a silent attack.
    if isServer() then
        local voice=(WTAGarou.Voice or {}).Crinos or {}
        local radius=tonumber(voice.radiusStanding) or 45
        if not B.finite(radius) then radius=45 end
        radius=math.max(1,math.min(90,radius))
        addSound(player,player:getX(),player:getY(),player:getZ(),radius,radius)
    end
    -- 0.4.42: knockback cooldown (noise above still applies every roar).
    local cooldown=tonumber((WTAGarou.CrinosShiftBurst or {}).ROAR_COOLDOWN) or 5
    if not B.finite(cooldown) then cooldown=5 end
    cooldown=math.max(0,math.min(60,cooldown))*1000
    local last=lastKnockback[player]
    if last and now-last<cooldown then
        print(string.format("[WTAGarou][CrinosBurst] standing Crinos Q roar; knockback cooling down (%.1fs left)",(cooldown-(now-last))/1000))
        return false
    end
    local emitted=emit(player,"standing Crinos Q roar")
    if emitted then lastKnockback[player]=now end
    return emitted
end
