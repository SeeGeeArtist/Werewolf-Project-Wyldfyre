require "WTAGarouCrinosBurst"
local B=WTAGarou.CrinosBurst
local seen,order={},{}
function B.receive(module,command,packet)
    if not isClient() or module~="WTAGarou" or command~="CrinosShiftBurst" then return end
    if type(packet)~="table" or type(packet.serial)~="string" or #packet.serial>100
        or seen[packet.serial] or type(packet.targets)~="table" then return end
    for _,key in ipairs({"x","y","z","radius","force"}) do if not B.finite(packet[key]) then return end end
    if packet.radius<0.25 or packet.radius>3 or packet.force<0.1 or packet.force>2 then return end
    local wanted,count={},0
    for _,id in pairs(packet.targets) do
        count=count+1
        if count>128 or not B.finite(id) or id<0 or id%1~=0 then return end
        wanted[id]=true
    end
    local cell=getCell()
    if not cell then return end
    seen[packet.serial]=true; order[#order+1]=packet.serial
    if #order>512 then seen[table.remove(order,1)]=nil end
    local zombies=cell:getZombieList()
    for i=0,zombies:size()-1 do
        local zombie=zombies:get(i)
        if wanted[zombie:getOnlineID()] then
            local ok,err=pcall(B.push,zombie,packet)
            if not ok then print("[WTAGarou][CrinosBurst] client push failed: "..tostring(err)) end
        end
    end
end
Events.OnServerCommand.Add(B.receive)
Events.OnGameStart.Add(function() seen,order={},{} end)
