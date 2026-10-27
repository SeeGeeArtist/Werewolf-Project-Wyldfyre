local root=assert(arg[1])
package.path=root.."/42/media/lua/shared/?.lua;"..root.."/42/media/lua/client/?.lua;"..package.path
require "WTAGarouDefinitions"
require "WTAGarouState"
local n=0
local function check(ok,msg) n=n+1; assert(ok,msg) end
local player={data={WTAGarou={isGarou=true,form="Homid"}}, speed=1, dead=false}
function player:getModData() return self.data end
function player:isDead() return self.dead end
function player:getVariableFloat() return self.speed end
function player:setVariable(key,v)
    if key=="CombatSpeed" then self.speed=v
    else self.variables=self.variables or {}; self.variables[key]=v end
end
function player:getVehicle() return self.vehicle end
function player:isFemale() return false end
function player:getHumanVisual() error("no HumanVisual access allowed in direct path") end
local weapon={swing="Heavy",ranged=false}
function weapon:isRanged() return self.ranged end
function weapon:getSwingAnim() return self.swing end
Events={}
for _,key in ipairs({"OnWeaponSwing","OnPlayerUpdate","OnCreatePlayer","OnPlayerDeath"}) do
    Events[key]={Add=function() end}
end
local standalone=false
getActivatedMods=function() return {contains=function(_,id)
    return standalone and id=="SkullysFasterSwingSpeed"
end} end
local timing,wolf,scale,requests=nil,false,nil,0
local response="wolf"
WTAGarouJava={
    setCombatTiming=function(_,value) timing=value end,
    setScale=function(_,value) scale=value; return true end,
    clearScale=function() scale=nil end,
    clear=function() scale=nil; wolf=false; timing=false end,
    setWolf=function(_,value) requests=requests+1; wolf=value; return value and response or "human" end,
    status=function() return "mock status" end,
}
local time=10
getTimestamp=function() return time end
getPlayer=function() return player end
dofile(root.."/42/media/lua/client/WTAGarouCombatTiming.lua")
local combat=WTAGarou.CombatTiming
for _,row in ipairs({{"Heavy",1.5},{"Stab",1.22},{"1Handed",1.1}}) do
    player.speed=1; weapon.swing=row[1]; combat.onSwing(player,weapon)
    check(math.abs(player.speed-row[2])<0.00001,"Skully swing category "..row[1])
end
check(combat.swingSpeed(2,"Heavy")==2,"never reduces already faster speed")
check(combat.swingSpeed(0,"Heavy")==0,"zero not accelerated")
weapon.ranged=true; player.speed=1; combat.onSwing(player,weapon)
check(player.speed==1,"firearms excluded")
weapon.ranged=false; player.data.WTAGarou.isGarou=false; combat.onSwing(player,weapon)
check(player.speed==1,"non-Garou excluded")
player.data.WTAGarou.isGarou=true; standalone=true; combat.onSwing(player,weapon)
check(player.speed==1,"standalone mod not doubled")
standalone=false
combat.refresh(player); check(timing,"recovery registered")
player.dead=true; combat.refresh(player); check(not timing,"dead excluded")
player.dead=false
dofile(root.."/42/media/lua/client/WTAGarouVisual.lua")
local refresh=WTAGarou.Visual.refresh
refresh(player,false); check(not wolf and scale==1,"Homid human")
player.data.WTAGarou.form="Hispo"; refresh(player,false)
check(wolf and scale==1.55,"Hispo direct wolf at 1.55 (0.4.22)")
local count=requests
for i=1,100 do refresh(player,false) end
check(requests==count,"no repeated wolf activation")
player.data.WTAGarou.form="Lupus"; refresh(player,false)
check(wolf and scale==1.15,"Lupus wolf 1.15 (0.4.22 +15%)")
WTAGarou.EnableJavaScale=false; refresh(player,false)
check(wolf and scale==nil,"scale toggle does not clear wolf")
player.data.WTAGarou.form="Crinos"; refresh(player,false)
check(not wolf,"back to biped")
player.data.WTAGarou.form="Hispo"; player.vehicle={}; refresh(player,false)
check(not wolf,"vehicle suspends wolf")
player.vehicle=nil; refresh(player,false); check(wolf,"exit vehicle resumes")
WTAGarouDirectWolf(false); check(not wolf,"escape command restores body")
WTAGarouDirectWolf(true); check(wolf,"retry command enables body")
player.dead=true; refresh(player,false); check(not wolf,"death clears wolf")
player.dead=false; player.data.WTAGarou.isGarou=false; refresh(player,false)
check(not wolf,"trait loss clears wolf")
player.data.WTAGarou.isGarou=true; response="pending"; refresh(player,true)
count=requests; refresh(player,false); check(requests==count,"pending retries throttled")
time=time+1; response="wolf"; refresh(player,false)
check(requests==count+1 and wolf,"ready asset retries successfully")
response="failed"; refresh(player,true); count=requests
for i=1,100 do time=time+1; refresh(player,false) end
check(requests==count,"failed API never retried every tick")
print("PASS: "..n.." combat/direct-wolf Lua assertions.")
