local root=assert(arg[1])
package.path=root.."/42/media/lua/shared/?.lua;"..root.."/42/media/lua/server/?.lua;"..package.path
require "WTAGarouDefinitions"
assert(WTAGarou.CrinosShiftBurst.RADIUS==3,"default burst range doubled")
-- Remaining authority/filter edge tests deliberately use a smaller configured range.
WTAGarou.CrinosShiftBurst.RADIUS=1.5
local n=0
local function check(ok,why) n=n+1; assert(ok,why) end
local server,client=false,false
isServer=function() return server end
isClient=function() return client end
getTimestamp=function() return 1000 end
instanceof=function(o,t) return t=="IsoZombie" and o.zombie end
Events={OnServerCommand={Add=function() end},OnGameStart={Add=function() end}}
local function zed(id,x,y,z)
    local z={id=id,x=x,y=y,z=z or 0,zombie=true,hp=100,pushes=0,data={}}
    function z:getX() return self.x end
    function z:getY() return self.y end
    function z:getZ() return self.z end
    function z:isDead() return self.dead end
    function z:getModData() return self.data end
    function z:getSquare() return self.square~=false and {} or nil end
    function z:isRemoteZombie() return self.remote end
    function z:getOwner() return self.owner end
    function z:getOnlineID() return self.id end
    function z:getForwardDirectionX() return 1 end
    function z:getForwardDirectionY() return 0 end
    function z:setForwardDirection(x,y) self.face={x,y} end
    function z:getHitDir() return {set=function(_,x,y) self.direction={x,y} end} end
    function z:setHitDir(v) end
    function z:setHitFromBehind(v) self.behind=v end
    function z:setPlayerAttackPosition(v) self.position=v end
    function z:setHitForce(v) self.force=v end
    function z:setStaggerTimeMod(v) self.staggerTime=v end
    function z:setHitReaction(v) self.reaction=v end
    function z:setStaggerBack(v) self.stagger=v end
    function z:reportEvent(e) check(e=="wasHit","native hit reaction event"); self.pushes=self.pushes+1 end
    return z
end
local player={data={WTAGarou={isGarou=true,form="Crinos"}}}
function player:getModData() return self.data end
function player:isDead() return self.dead end
function player:isSneaking() return self.sneaking end
function player:getX() return 10 end
function player:getY() return 10 end
function player:getZ() return 0 end
function player:getSquare() return {} end
WTAGarou.GetData=function(p) return p:getModData().WTAGarou end
local zombies={}
getCell=function() return {getZombieList=function() return {
    size=function() return #zombies end,get=function(_,i) return zombies[i+1] end} end} end
LosUtil={lineClearCollide=function(x,y,z,tx,ty,tz,ignoreDoors)
    check(ignoreDoors==false,"closed doors block burst")
    return tx==9 and ty==9 -- designated blocked diagonal target
end}
local packets={}
require "WTAGarouNet"
WTAGarou.Net.Broadcast=function(command,args)
    check(command=="CrinosShiftBurst","only server pulse packet")
    packets[#packets+1]=args
end
require "WTAGarouCrinosBurstServer"
dofile(root.."/42/media/lua/client/WTAGarouCrinosBurstClient.lua")
local B=WTAGarou.CrinosBurst
local east,west,north,south=zed(1,11.5,10),zed(2,8.5,10),zed(3,10,11.4),zed(4,10,8.6)
local far,up,dead,wall=zed(5,11.51,10),zed(6,10,10,1),zed(7,10.2,10),zed(8,9.5,9.5)
dead.dead=true
local bandit,human=zed(9,10.3,10),zed(10,10.4,10)
bandit.data.brain={}; human.zombie=false
local center=zed(11,10,10)
zombies={east,west,north,south,far,up,dead,wall,bandit,human,center}
B.onCompleted(player,"Homid","Crinos")
for _,z in ipairs({east,west,north,south,center}) do
    check(z.pushes==1 and z.stagger and z.force==1,"every unobstructed in-range zombie pushed")
    check(z.hp==100,"no damage")
end
for _,z in ipairs({far,up,dead,wall,bandit,human}) do check(z.pushes==0,"out of scope target untouched") end
check(east.direction[1]==1 and west.direction[1]==-1 and north.direction[2]==1 and south.direction[2]==-1,"radial direction all quadrants")
check(east.x==11.5 and west.x==8.5,"no teleport")
check(#packets==0,"solo does not broadcast")
B.onCompleted(player,"Crinos","Crinos"); B.onCompleted(player,"Homid","Hispo")
player.dead=true; B.onCompleted(player,"Homid","Crinos"); player.dead=false
WTAGarou.CrinosShiftBurst.ENABLED=false; B.onCompleted(player,"Homid","Crinos")
WTAGarou.CrinosShiftBurst.ENABLED=true
check(east.pushes==1,"same form, other form, dead and disabled do not pulse")
local los=LosUtil; LosUtil=nil
B.onCompleted(player,"Homid","Crinos")
check(east.pushes==1,"missing barrier API fails closed")
LosUtil=los
-- Dedicated server selects targets; only owning simulation mutates them.
server=true
east.owner={}; east.remote=true
west.owner=nil; west.remote=false
zombies={east,west}
B.onCompleted(player,"Homid","Crinos")
check(east.pushes==1 and west.pushes==2,"server leaves client-owned zombie alone")
check(#packets==1 and #packets[1].targets==1 and packets[1].targets[1]==east.id,"only client-owned selected IDs broadcast")
local packet=packets[1]
server,client=false,true
B.receive("WTAGarou","CrinosShiftBurst",packet)
check(east.pushes==1,"non-owning client ignores remote zombie")
-- Simulate receiving on its actual owner in a separate client session.
dofile(root.."/42/media/lua/client/WTAGarouCrinosBurstClient.lua")
east.remote=false
B.receive("WTAGarou","CrinosShiftBurst",packet)
B.receive("WTAGarou","CrinosShiftBurst",packet)
check(east.pushes==2,"owner applies packet only once")
check(west.pushes==2,"non-target never hit by client message")
B.onCompleted(player,"Homid","Crinos")
check(#packets==1,"client cannot originate burst")
local malformed={serial="bad",x=10,y=10,z=0,radius=100,force=1,targets={1}}
B.receive("WTAGarou","CrinosShiftBurst",malformed)
check(east.pushes==2,"oversized network radius rejected")
malformed.radius=1.5; malformed.x=0/0
B.receive("WTAGarou","CrinosShiftBurst",malformed)
check(east.pushes==2,"NaN center rejected")
-- Roar shares the exact selector/push path, never client-provided geometry.
server,client=false,false
zombies={west,wall,far,up,dead,bandit}
local ms=10000
getTimestampMs=function() return ms end
local before=west.pushes
check(B.onRoar(player)==true,"standing Crinos roar accepted")
check(west.pushes==before+1 and west.force==1 and west.hp==100,"roar uses same non-damaging stagger")
B.onRoar(player)
check(west.pushes==before+1,"duplicate/flood within 250ms rejected")
ms=ms+250
B.onRoar(player)
check(west.pushes==before+1,"0.4.42: a roar inside the 5 s knockback cooldown does not stagger")
ms=ms+4000
B.onRoar(player)
check(west.pushes==before+1,"still cooling down at 4.25 s")
ms=10000+5000
check(B.onRoar(player)==true and west.pushes==before+2,"knockback returns after ROAR_COOLDOWN (5 s), no Rage charge")
check(WTAGarou.CrinosShiftBurst.ROAR_COOLDOWN==5,"cooldown is 5 seconds")
ms=ms+6000
player.sneaking=true; B.onRoar(player); player.sneaking=false
player.dead=true; B.onRoar(player); player.dead=false
player.data.WTAGarou.form="Hispo"; B.onRoar(player); player.data.WTAGarou.form="Crinos"
player.data.WTAGarou.isGarou=false; B.onRoar(player); player.data.WTAGarou.isGarou=true
client=true; B.onRoar(player); client=false
check(west.pushes==before+2,"crouch, death, other forms, non-Garou and client authority denied")
for _,z in ipairs({wall,far,up,dead,bandit}) do check(z.pushes==0,"roar retains LOS/floor/range/death/NPC filters") end
server=true
local noise=0
addSound=function(p,x,y,z,r,v)
    check(p==player and x==10 and y==10 and z==0 and r==45 and v==45,"server enforces real-origin roar noise")
    noise=noise+1
end
east.owner={}; east.remote=true; zombies={east,west}
local oldPackets=#packets
B.onRoar(player)
check(noise==1 and #packets==oldPackets+1,"MP roar enforces noise and sends owner-targeted packet")
local roarPacket=packets[#packets]
server,client=false,true
east.remote=false
local prior=east.pushes
B.receive("WTAGarou","CrinosShiftBurst",roarPacket)
B.receive("WTAGarou","CrinosShiftBurst",roarPacket)
check(east.pushes==prior+1,"roar owner applies shared packet exactly once")
-- Bridge edge, not key polling: one request, local player only, no payload.
dofile(root.."/42/media/lua/client/WTAGarouCrinosRoar.lua")
local pending,requests=true,0
WTAGarouJava={consumeCrinosRoar=function(p) local b=pending; pending=false; return b end}
function player:isLocalPlayer() return not self.remote end
WTAGarou.Net.ToServer=function(p,command,args)
    check(p==player and command=="CrinosRoarRequest" and next(args)==nil,"request carries no geometry or targets")
    requests=requests+1
end
WTAGarou.CrinosRoar.onUpdate(player); WTAGarou.CrinosRoar.onUpdate(player)
check(requests==1,"one consumed callout yields one request")
pending=true; player.remote=true; WTAGarou.CrinosRoar.onUpdate(player); player.remote=false
check(pending and requests==1,"remote player is not polled")
player.data.WTAGarou.form="Homid"; WTAGarou.CrinosRoar.onUpdate(player)
check(not pending and requests==1,"stale form edge consumed without sending")
player.data.WTAGarou.form="Crinos"; player.dead=true; pending=true
WTAGarou.CrinosRoar.onUpdate(player)
check(not pending and requests==1,"dead player cannot request roar")
print("PASS: "..n.." Crinos burst filtering/authority/replay assertions.")
