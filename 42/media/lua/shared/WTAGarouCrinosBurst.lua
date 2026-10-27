require "WTAGarouDefinitions"
require "WTAGarouAdapters"
WTAGarou.CrinosBurst = WTAGarou.CrinosBurst or {}
local B=WTAGarou.CrinosBurst

local function finite(n)
    return type(n)=="number" and n==n and math.abs(n)<1e8
end
B.finite=finite
function B.eligible(z,packet)
    if not z or not instanceof(z,"IsoZombie") or z:isDead() then return false end
    local A=WTAGarou.Adapters
    if A and ((A.isBandit and A.isBandit(z)) or (A.isGarou and A.isGarou(z))) then return false end
    local x,y,level=z:getX(),z:getY(),z:getZ()
    if not finite(x) or not finite(y) or not finite(level) then return false end
    if math.floor(level)~=math.floor(packet.z) then return false end
    if (x-packet.x)^2+(y-packet.y)^2>packet.radius^2 then return false end
    if not z:getSquare() then return false end
    -- Collision, not just visibility: closed doors/windows/walls block it.
    -- Missing API fails closed instead of shoving through structures.
    if not (LosUtil and LosUtil.lineClearCollide) then return false end
    return not LosUtil.lineClearCollide(math.floor(packet.x),math.floor(packet.y),math.floor(packet.z),
        math.floor(x),math.floor(y),math.floor(level),false)
end

function B.push(z,packet)
    -- Multiplayer mutations belong only to the current zombie authority.
    -- Remote clients receive the resulting native zombie state normally.
    if isServer() and z:getOwner()~=nil then return false end
    if isClient() and z:isRemoteZombie() then return false end
    if not B.eligible(z,packet) then return false end
    local dx,dy=z:getX()-packet.x,z:getY()-packet.y
    local length=math.sqrt(dx*dx+dy*dy)
    if length<0.0001 then
        dx,dy=-z:getForwardDirectionX(),-z:getForwardDirectionY()
        length=math.sqrt(dx*dx+dy*dy)
        if length<0.0001 then dx,dy,length=1,0,1 end
    end
    dx,dy=dx/length,dy/length
    -- Face the origin so native backward root motion travels outward.
    -- No setX/setY, Hit(), damage, fake weapon swing, or scripted knockdown.
    z:setForwardDirection(-dx,-dy)
    local direction=z:getHitDir()
    direction:set(dx,dy)
    z:setHitDir(direction)
    z:setHitFromBehind(false)
    z:setPlayerAttackPosition("FRONT")
    z:setHitForce(packet.force)
    z:setStaggerTimeMod(1)
    z:setHitReaction("")
    z:setStaggerBack(true)
    z:reportEvent("wasHit")
    return true
end
