-- 0.4.63: loading silver rounds IS the vanilla reload (ISReloadWeaponAction /
-- ISLoadBulletsInMagazine derivatives): same animation hooks, primary-hand
-- rule, per-round silver bookkeeping; plus the firearm radial slice. Fixtures
-- shaped like B42.20.2 timed actions. Static evidence, not a firing range.
local root=assert(arg[1])
package.path=root.."/42/media/lua/shared/?.lua;"..root.."/42/media/lua/client/?.lua;"..package.path
local n=0
local function check(ok,why) n=n+1; assert(ok,why) end

-- ---------------------------------------------------------------- engine stubs
local server=false
isServer=function() return server end
isClient=function() return false end
isMultiplayer=function() return false end
getTimestamp=function() return 1000 end
instanceof=function(o,cls) return o and o.__class==cls end
Events=setmetatable({},{__index=function(t,k) t[k]={handlers={},Add=function(f) table.insert(t[k].handlers,f) end}; return t[k] end})
local removedSync,syncedGun,syncedItem={},0,0
sendRemoveItemFromContainer=function(inv,it) removedSync[#removedSync+1]=it end
syncHandWeaponFields=function() syncedGun=syncedGun+1 end
syncItemFields=function() syncedItem=syncedItem+1 end
Perks={Reloading="Reloading"}
ZombRand=function() return 1 end
addXp=function() end
CharacterActionAnims={Reload="Reload",InsertBullets="InsertBullets"}
local racksQueued={}
ISRackFirearm={new=function(_,chr,gun) local r={gun=gun}; racksQueued[#racksQueued+1]=r; return r end}
ISTimedActionQueue={queue={},addAfter=function(after,act) table.insert(ISTimedActionQueue.queue,act) end,add=function(act) table.insert(ISTimedActionQueue.queue,act); return act end}
getTextOrNull=function(k,...) if k=="IGUI_FirearmRadial_AmmoCount" then return "Ammo: "..tostring(select(1,...)).."/"..tostring(select(2,...)) end return nil end
getTexture=function(p) return {path=p} end
getPlayerRadialMenu=function() return nil end

-- vanilla timed-action skeletons (only what the mod touches)
ISBaseTimedAction={Type="ISBaseTimedAction"}; ISBaseTimedAction.__index=ISBaseTimedAction
function ISBaseTimedAction:derive(t) local o={Type=t}; o.__index=o; setmetatable(o,self); return o end
function ISBaseTimedAction.new(self,character) local o=setmetatable({},self); o.character=character; return o end
function ISBaseTimedAction:forceComplete() self.completed=true end
function ISBaseTimedAction:forceStop() self.stopped=true end
function ISBaseTimedAction:setAnimVariable(k,v) self.anim=self.anim or {}; self.anim[k]=v end
function ISBaseTimedAction:setOverrideHandModels(a,b) self.handModels={a,b} end
function ISBaseTimedAction:setActionAnim(a) self.actionAnim=a end
ISReloadWeaponAction=ISBaseTimedAction:derive("ISReloadWeaponAction")
local reloadSpeedCalls=0
ISReloadWeaponAction.setReloadSpeed=function(chr,rack) reloadSpeedCalls=reloadSpeedCalls+1 end
function ISReloadWeaponAction:new(character,gun)
    local o=ISBaseTimedAction.new(self,character)
    o.stopOnAim=false; o.stopOnWalk=false; o.stopOnRun=true; o.gun=gun; o.reloading=true; o.maxTime=-1; o.useProgressBar=false
    return o
end
function ISReloadWeaponAction:isValid() return self.character:getPrimaryHandItem()==self.gun end
ISLoadBulletsInMagazine=ISBaseTimedAction:derive("ISLoadBulletsInMagazine")
function ISLoadBulletsInMagazine:new(character,magazine,ammoCount)
    local o=ISBaseTimedAction.new(self,character)
    o.magazine=magazine; o.ammoCount=ammoCount; o.useProgressBar=false; o.maxTime=-1
    return o
end
function ISLoadBulletsInMagazine:isValid() return self.character:getInventory():contains(self.magazine) end
function ISLoadBulletsInMagazine:isLocal() return true end
function ISLoadBulletsInMagazine:updateLoadingTime() self.timeUpdated=true end
function ISLoadBulletsInMagazine:initVars() ISReloadWeaponAction.setReloadSpeed(self.character,false) end
ISFirearmRadialMenu={fillMenu=function(self) self.vanillaFilled=true return "orig" end}
ISInventoryPaneContextMenu={
    transferred={},equipped={},
    transferBullets=function(p,key,cur,max) ISInventoryPaneContextMenu.transferred[#ISInventoryPaneContextMenu.transferred+1]=key return 0 end,
    equipWeapon=function(w) ISInventoryPaneContextMenu.equipped[#ISInventoryPaneContextMenu.equipped+1]=w end,
    transferIfNeeded=function() end,
}

-- vanilla modules are stubbed above; let `require` of them be a no-op
local realRequire=require
require=function(name) if name:find("^TimedActions/") or name:find("^ISUI/") then return true end return realRequire(name) end

WTAGarou=WTAGarou or {}
local flashed={}
WTAGarou.HUD={instance={flashDenial=function(_,r) flashed[#flashed+1]=r end},DENIAL_TEXT={}}
WTAGarou.Paws={isPaws=function(p) return p.paws==true end,refuse=function(_,r) flashed[#flashed+1]=r end}
require "WTAGarouSilverAmmo"
local S=WTAGarou.SilverAmmo
require "WTAGarouSilverLoadActions"
require "WTAGarouSilverLoad"
local L=WTAGarou.SilverLoad

-- ---------------------------------------------------------------- fixtures
local function Item(fullType)
    local it={__class="InventoryItem",fullType=fullType,md={},id=math.random(1e6)}
    function it:getFullType() return self.fullType end
    function it:getModData() return self.md end
    function it:getID() return self.id end
    function it:getContainer() return self.container end
    return it
end
local function Gun(fullType,opts)
    local w=Item(fullType); w.__class="HandWeapon"
    w.ammoKey=opts.ammo; w.magType=opts.mag; w.chamber=opts.chamber==true; w.count=0; w.max=opts.max or 6; w.chambered=false
    w.insertAll=opts.insertAll==true; w.needClose=opts.needClose==true
    function w:isRanged() return true end
    function w:getAmmoType() local k=self.ammoKey return k and {getItemKey=function() return k end} or nil end
    function w:getMagazineType() return self.magType end
    function w:getCurrentAmmoCount() return self.count end
    function w:setCurrentAmmoCount(v) self.count=v end
    function w:getMaxAmmo() return self.max end
    function w:haveChamber() return self.chamber end
    function w:isRoundChambered() return self.chambered end
    function w:needToBeClosedOnceReload() return self.needClose end
    function w:isInsertAllBulletsReload() return self.insertAll end
    function w:setJobDelta() end
    return w
end
local function Magazine(ammo,max)
    local m=Item("Base.9mmClip"); m.ammoKey=ammo; m.count=0; m.max=max or 15
    function m:getAmmoType() local k=self.ammoKey return {getItemKey=function() return k end} end
    function m:getCurrentAmmoCount() return self.count end
    function m:setCurrentAmmoCount(v) self.count=v end
    function m:getMaxAmmo() return self.max end
    function m:setJobDelta() end
    return m
end
local function JavaList(arr)
    return {isEmpty=function() return #arr==0 end,get=function(_,i) return arr[i+1] end,
        remove=function(_,it) for i,x in ipairs(arr) do if x==it then table.remove(arr,i) return end end end,size=function() return #arr end}
end
local function Inventory()
    local inv={items={}}
    function inv:AddItem(fullType) local it=Item(fullType); it.container=self; self.items[#self.items+1]=it; return it end
    function inv:add(it) it.container=self; self.items[#self.items+1]=it; return it end
    function inv:Remove(it) for i,x in ipairs(self.items) do if x==it then table.remove(self.items,i) return end end end
    function inv:RemoveOneOf(t) for i,x in ipairs(self.items) do if x.fullType==t then table.remove(self.items,i) return x end end end
    function inv:getCountTypeRecurse(t) local c=0 for _,x in ipairs(self.items) do if x.fullType==t then c=c+1 end end return c end
    inv.getItemCountRecurse=inv.getCountTypeRecurse
    function inv:containsWithModule(t) return self:getCountTypeRecurse(t)>0 end
    function inv:getFirstTypeRecurse(t) for _,x in ipairs(self.items) do if x.fullType==t then return x end end return nil end
    function inv:getSomeType(t,count) local arr={} for _,x in ipairs(self.items) do if x.fullType==t and #arr<count then arr[#arr+1]=x end end return JavaList(arr) end
    function inv:getItemsFromFullType(t) local arr={} for _,x in ipairs(self.items) do if x.fullType==t then arr[#arr+1]=x end end
        return {size=function() return #arr end,get=function(_,i) return arr[i+1] end} end
    function inv:contains(it) for _,x in ipairs(self.items) do if x==it then return true end end return false end
    function inv:getItemById(id) for _,x in ipairs(self.items) do if x.id==id then return x end end return nil end
    return inv
end
local function Player()
    local p={inv=Inventory(),vars={}}
    function p:getInventory() return self.inv end
    function p:getPrimaryHandItem() return self.primary end
    function p:getPlayerNum() return 0 end
    function p:clearVariable(k) self.vars[k]=nil end
    function p:setVariable(k,v) self.vars[k]=v end
    function p:getPerkLevel() return 0 end
    function p:playSound(s) self.sounds=self.sounds or {}; self.sounds[#self.sounds+1]=s end
    return p
end

-- ---------------------------------------------------------------- gun action
check(getmetatable(WTAGarouLoadSilverAction)==ISReloadWeaponAction and WTAGarouLoadSilverAction.Type=="WTAGarouLoadSilverAction","gun action derives from the vanilla reload action (same AnimSet events)")
local p=Player()
local sg=Gun("Base.Shotgun",{ammo="Base.ShotgunShells",chamber=true,max=6})
p.inv:add(sg)
for _=1,4 do p.inv:AddItem("WTAGarou.SilverShotgunShells") end
local a=WTAGarouLoadSilverAction:new(p,sg)
check(a.gun==sg and a.character==p and a.count==nil and a.maxTime==-1 and a.useProgressBar==false,"new() keeps vanilla fields (anim-driven, no progress bar)")
check(a:isValid()==false,"not in the primary hand: invalid (vanilla rule, Oct 16 request)")
p.primary=sg
check(a:isValid()==true,"equipped: valid")
sg.count=2
check(a:isValid()==false,"ordinary shells inside: refused (no mixing)")
sg.count=0
a:initVars()
check(reloadSpeedCalls==1 and a.ammoCount==4 and a.bullets and a.bullets:size()==4,"initVars: reload speed set, four SILVER shells staged")
check(a.bullets:get(0).fullType=="WTAGarou.SilverShotgunShells","the staged rounds are the silver type")
-- one 'loadFinished' per shell, as the shotgun AnimSet fires it
a:loadAmmo()
check(sg.count==1 and S.count(sg)==1 and p.inv:getCountTypeRecurse("WTAGarou.SilverShotgunShells")==3,"one shell in: tube 1, silver count 1, one item gone")
check(#removedSync==1 and syncedGun==1,"vanilla MP sync calls made per round")
a:loadAmmo(); a:loadAmmo()
check(sg.count==3 and S.count(sg)==3 and not a.completed,"three in, still loading")
a:loadAmmo()
check(sg.count==4 and S.count(sg)==4 and a.completed==true and p.vars.isLoading==nil,"last shell completes the action and clears isLoading")
check(#racksQueued==1 and racksQueued[1].gun==sg,"empty chamber: a rack is queued after loading, like vanilla")
-- capped count
local p2=Player(); local rev=Gun("Base.Revolver",{ammo="Base.Bullets44",chamber=false,max=6,insertAll=true}); p2.inv:add(rev); p2.primary=rev
for _=1,6 do p2.inv:AddItem("WTAGarou.SilverBullets44") end
local b=WTAGarouLoadSilverAction:new(p2,rev,2)
b:initVars()
check(b.ammoCount==2 and b.bullets:size()==2,"count cap: only two staged")
b:loadAmmo()
check(rev.count==2 and S.count(rev)==2 and b.completed==true and #racksQueued==1,"insert-all gun loads both in one step; no chamber, no rack")
-- no silver rounds: nothing staged (vanilla start() then forceStops)
local p3=Player(); local sg3=Gun("Base.Shotgun",{ammo="Base.ShotgunShells",chamber=true}); p3.inv:add(sg3); p3.primary=sg3
local c=WTAGarouLoadSilverAction:new(p3,sg3); c:initVars()
check(c.bullets==nil and c.ammoCount==nil,"no silver shells: nothing staged")
-- paws
local wolf=Player(); wolf.paws=true; wolf.primary=sg3; wolf.inv:add(sg3)
check(WTAGarouLoadSilverAction:new(wolf,sg3):isValid()==false,"paws: invalid")
-- server side: loadAmmo completes through netAction
server=true
local p4=Player(); local sg4=Gun("Base.Shotgun",{ammo="Base.ShotgunShells",chamber=true,max=1}); p4.inv:add(sg4); p4.primary=sg4; p4.inv:AddItem("WTAGarou.SilverShotgunShells")
local d=WTAGarouLoadSilverAction:new(p4,sg4); d.netAction={forceComplete=function(self) self.done=true end}
d:initVars(); d:loadAmmo()
check(sg4.count==1 and S.count(sg4)==1 and d.netAction.done==true and #racksQueued==1,"server: completes via netAction, queues no rack")
server=false

-- ---------------------------------------------------------------- magazine action
check(getmetatable(WTAGarouLoadSilverMagazineAction)==ISLoadBulletsInMagazine,"magazine action derives from the vanilla magazine loader")
local p5=Player(); local mag=Magazine("Base.Bullets9mm",15); p5.inv:add(mag)
for _=1,3 do p5.inv:AddItem("WTAGarou.SilverBullets9mm") end
local m=WTAGarouLoadSilverMagazineAction:new(p5,mag,3)
check(m.magazine==mag and m.count==3 and m.ammoCount==3,"new() keeps vanilla fields")
check(m:isValid()==true,"magazine in inventory: valid")
mag.count=1
check(m:isValid()==false,"ordinary rounds inside: refused")
mag.count=0
m:start()
check(m.actionAnim=="InsertBullets" and m.handModels[2]=="GunMagazine" and m.ammoCountStart==0 and not m.stopped,"start: vanilla InsertBullets anim with the magazine in hand")
m:animEvent("InsertBulletSound","InsertBullet9mm")
check(p5.sounds and p5.sounds[1]=="InsertBullet9mm","per-round insert sound plays")
m:animEvent("InsertBullet")
check(mag.count==1 and S.count(mag)==1 and p5.inv:getCountTypeRecurse("WTAGarou.SilverBullets9mm")==2 and syncedItem==1,"InsertBullet: one silver round in, count up, item removed, synced")
m:animEvent("InsertBullet")
check(mag.count==1,"same anim loop: second InsertBullet ignored (loadedThisLoop)")
m.loadedThisLoop=false; m:animEvent("InsertBullet")
m.loadedThisLoop=false; m:animEvent("InsertBullet")
check(mag.count==3 and S.count(mag)==3 and m:isLoadFinished()==true,"three rounds in; the count cap finishes the load")
m:animEvent("loadFinished")
check(m.loadFinished==true,"loadFinished flag set (vanilla update() then completes)")
m.loadedThisLoop=false; m:animEvent("InsertBullet")
check(mag.count==3,"finished: late InsertBullet events ignored")
local p6=Player(); local mag6=Magazine("Base.Bullets9mm",15); p6.inv:add(mag6)
local m6=WTAGarouLoadSilverMagazineAction:new(p6,mag6)
m6:start()
check(m6.stopped==true,"no silver rounds: start() force-stops like vanilla")
local wolfMag=WTAGarouLoadSilverMagazineAction:new(wolf,mag)
check(wolfMag:isValid()==false,"paws: magazine action invalid")

-- ---------------------------------------------------------------- context menu queueing
local p7=Player(); local sg7=Gun("Base.Shotgun",{ammo="Base.ShotgunShells",chamber=true,max=6}); p7.inv:add(sg7)
for _=1,2 do p7.inv:AddItem("WTAGarou.SilverShotgunShells") end
ISTimedActionQueue.queue={}
L.onLoad(p7,sg7)
check(#ISInventoryPaneContextMenu.equipped==1 and ISInventoryPaneContextMenu.equipped[1]==sg7,"menu equips the gun first, as vanilla 'Load bullets' does")
check(ISInventoryPaneContextMenu.transferred[#ISInventoryPaneContextMenu.transferred]=="WTAGarou.SilverShotgunShells","silver rounds are staged out of bags first")
check(#ISTimedActionQueue.queue==1 and getmetatable(ISTimedActionQueue.queue[1])==WTAGarouLoadSilverAction and ISTimedActionQueue.queue[1].count==2,"gun: the animated reload action is queued with the count")
local mag7=Magazine("Base.Bullets9mm",15); p7.inv:add(mag7); p7.inv:AddItem("WTAGarou.SilverBullets9mm")
ISTimedActionQueue.queue={}
L.onLoad(p7,mag7)
check(#ISTimedActionQueue.queue==1 and getmetatable(ISTimedActionQueue.queue[1])==WTAGarouLoadSilverMagazineAction and #ISInventoryPaneContextMenu.equipped==1,"magazine: the magazine action is queued, nothing equipped")
flashed={}
L.onLoad(wolf,sg7)
check(flashed[1]=="paws_firearm","paws refused from the menu")

-- ---------------------------------------------------------------- firearm radial slice
check(ISFirearmRadialMenu.WTAGarou_silver_fillMenu~=nil,"firearm radial fillMenu wrapped")
local function Menu() local mm={slices={}}; function mm:addSlice(text,icon,fn) self.slices[#self.slices+1]={text=text,icon=icon,fn=fn} end return mm end
local p8=Player(); local sg8=Gun("Base.Shotgun",{ammo="Base.ShotgunShells",chamber=true,max=6}); p8.inv:add(sg8); p8.primary=sg8
local menu=Menu()
check(L.fillRadial({character=p8},menu,sg8)==false and #menu.slices==0,"no silver shells: no slice")
for _=1,3 do p8.inv:AddItem("WTAGarou.SilverShotgunShells") end
check(L.fillRadial({character=p8},menu,sg8)==true and #menu.slices==1,"silver shells in the bag: one slice")
check(menu.slices[1].text:find("Load silver rounds (+3)",1,true) and menu.slices[1].text:find("Ammo: 0/6",1,true) and menu.slices[1].icon.path:find("BulletsIntoFirearm"),"slice names the rounds and shows vanilla ammo count: "..menu.slices[1].text)
ISTimedActionQueue.queue={}
menu.slices[1].fn()
check(#ISTimedActionQueue.queue==1 and ISTimedActionQueue.queue[1].count==3,"slice queues the load for all three")
sg8.count=2
local menu2=Menu()
check(L.fillRadial({character=p8},menu2,sg8)==false,"ordinary shells inside: no slice")
-- magazine gun: picks the fullest silver-compatible magazine
local p9=Player(); local m9=Gun("Base.Pistol",{ammo="Base.Bullets9mm",mag="Base.9mmClip",chamber=true,max=15}); p9.inv:add(m9); p9.primary=m9
local magA=Magazine("Base.Bullets9mm",15); magA.fullType="Base.9mmClip"; p9.inv:add(magA)
local magB=Magazine("Base.Bullets9mm",15); magB.fullType="Base.9mmClip"; magB.count=5; S.setCount(magB,5); p9.inv:add(magB)
local magC=Magazine("Base.Bullets9mm",15); magC.fullType="Base.9mmClip"; magC.count=7; p9.inv:add(magC) -- ordinary rounds
for _=1,4 do p9.inv:AddItem("WTAGarou.SilverBullets9mm") end
local target,cnt=L.radialTarget(p9,m9)
check(target==magB and cnt==4,"magazine gun: the fullest magazine WITHOUT ordinary rounds is the target")
local menu3=Menu()
check(L.fillRadial({character=p9},menu3,m9)==true and menu3.slices[1].icon.path:find("BulletsIntoMagazine") and menu3.slices[1].text:find("Ammo: 5/15",1,true),"magazine slice uses the magazine icon and count")
ISTimedActionQueue.queue={}
menu3.slices[1].fn()
check(getmetatable(ISTimedActionQueue.queue[1])==WTAGarouLoadSilverMagazineAction and ISTimedActionQueue.queue[1].magazine==magB,"magazine slice queues the magazine action on that magazine")
check(L.fillRadial({character=wolf},Menu(),sg8)==false,"paws: no slice")
local frm={character=p8,playerNum=0,getWeapon=function() return sg8 end}
check(ISFirearmRadialMenu.fillMenu(frm)=="orig" and frm.vanillaFilled==true,"wrapper calls vanilla fillMenu and survives a nil radial menu")

print("PASS: "..n.." silver load action (vanilla-reload derivative), menu and radial assertions; animation itself needs the game.")
