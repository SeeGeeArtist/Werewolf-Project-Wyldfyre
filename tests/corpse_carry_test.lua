-- 0.4.40: Crinos/Hispo corpse stowing (vanilla B42 corpse <-> item surfaces),
-- the wolf grapple-forward push, and the mod audio scaling helper.
local root=assert(arg[1])
package.path=root.."/42/media/lua/shared/?.lua;"..root.."/42/media/lua/client/?.lua;"..package.path
local n=0
local function check(ok,why) n=n+1; assert(ok,why) end
isServer=function() return false end
isClient=function() return false end
getTimestamp=function() return 1000 end
Events=setmetatable({},{__index=function(t,k) t[k]={Add=function(fn) t[k].fn=fn end}; return t[k] end})
WTAGarou=WTAGarou or {}
require "WTAGarouDefinitions"
WTAGarou.HasGarouTrait=function(p) return p.garou~=false end
local CC=require "WTAGarouCorpseCarry"

-- Definitions shape.
check(WTAGarou.CorpseCarry.canStow("Crinos") and WTAGarou.CorpseCarry.canStow("Hispo"),"Crinos and Hispo can stow corpses")
check(not WTAGarou.CorpseCarry.canStow("Lupus") and not WTAGarou.CorpseCarry.canStow("Homid") and not WTAGarou.CorpseCarry.canStow("Glabro"),
    "other forms cannot stow corpses")
check(WTAGarou.CorpseCarry.grappleForward("Hispo")==1.0 and WTAGarou.CorpseCarry.grappleForward("Lupus")>0
    and WTAGarou.CorpseCarry.grappleForward("Crinos")==0 and WTAGarou.CorpseCarry.grappleForward("Homid")==0,
    "wolf forms get a forward grapple offset (Hispo a full metre); bipeds none")

-- Fixtures shaped like IsoDeadBody / IsoPlayer / ItemContainer.
local removed={}
local function body(animal)
    local b={animal=animal==true,square={}}
    function b:isAnimal() return self.animal end
    function b:getSquare() return self.square end
    function b:becomeCorpseItem(networked) removed[#removed+1]={body=self,networked=networked}; return {corpse=true,body=self} end
    return b
end
instanceof=function(o,cls) return cls=="IsoDeadBody" and type(o)=="table" and o.isAnimal~=nil end
local function player(form)
    local p={form=form,items={},dragging=false,thrown=nil,pickedUp=nil}
    function p:isDead() return false end
    function p:getModData() return {WTAGarou={form=self.form}} end
    function p:getInventory() return self.inventory end
    p.inventory={AddItem=function(_,item) p.items[#p.items+1]=item end}
    function p:isDraggingCorpse() return self.dragging end
    function p:throwGrappledIntoInventory(container) self.thrown=container end
    function p:pickUpCorpseItem(item) self.pickedUp=item end
    return p
end
local crinos,lupus=player("Crinos"),player("Lupus")
getSpecificPlayer=function(num) return num==0 and crinos or lupus end
check(CC.allowed(crinos) and not CC.allowed(lupus),"only bulk forms are allowed")
crinos.form="Homid"; check(not CC.allowed(crinos),"Human cannot stow"); crinos.form="Crinos"

-- Stow a ground corpse: vanilla becomeCorpseItem(false) (networked removal) + AddItem.
local human=body(false)
check(CC.stow(crinos,human)==true and #crinos.items==1 and crinos.items[1].body==human
    and #removed==1 and removed[1].networked==false,"stow turns the body into the vanilla corpse item through the networked removal path")
check(CC.stow(crinos,body(true))==false,"animals are not stowed")
check(CC.stow(lupus,body(false))==false and #lupus.items==0,"Lupus cannot stow")

-- World menu: ground corpses from the clicked objects/squares; dragging offers the carried corpse.
local function menu() local m={options={}}; function m:addOption(name,target,fn,arg) self.options[#self.options+1]={name=name,target=target,fn=fn,arg=arg} end; return m end
local m=menu()
local b1,b2=body(false),body(true)
b1.square={getDeadBodys=function() return {size=function() return 2 end,get=function(_,i) return ({[0]=b1,[1]=b2})[i] end} end}
CC.fillWorldMenu(0,m,{b1},false)
check(#m.options==1 and m.options[1].name=="Stow corpse" and m.options[1].arg==b1,"one Stow corpse option per human corpse (animal skipped, no duplicates)")
m=menu(); CC.fillWorldMenu(1,m,{b1},false)
check(#m.options==0,"Lupus gets no stow option")
m=menu(); crinos.dragging=true; CC.fillWorldMenu(0,m,{b1},false)
check(#m.options==1 and m.options[1].name=="Stow carried corpse","dragging offers to stow the carried corpse")
m.options[1].fn(m.options[1].target)
check(crinos.thrown==crinos.inventory,"carried corpse goes through the vanilla throwGrappledIntoInventory with the player's own inventory")
crinos.dragging=false
m=menu(); CC.fillWorldMenu(0,m,{b1},true)
check(#m.options==0,"test pass adds nothing")

-- Inventory menu: a stowed corpse can be put down (vanilla pickUpCorpseItem).
local corpseItem={isHumanCorpse=function() return true end,getContainer=function() return crinos.inventory end}
local other={isHumanCorpse=function() return false end,getContainer=function() return crinos.inventory end}
m=menu(); CC.fillInventoryMenu(0,m,{other,corpseItem})
check(#m.options==1 and m.options[1].name=="Put down corpse","corpse item offers Put down corpse")
m.options[1].fn(m.options[1].target,m.options[1].arg)
check(crinos.pickedUp==corpseItem,"put down uses vanilla pickUpCorpseItem (spawn + grab)")
m=menu(); crinos.dragging=true; CC.fillInventoryMenu(0,m,{corpseItem}); crinos.dragging=false
check(#m.options==0,"no put-down while already dragging")
m=menu(); crinos.form="Homid"; CC.fillInventoryMenu(0,m,{corpseItem}); crinos.form="Crinos"
check(#m.options==1,"a stowed corpse can be put down in any form (never stuck in the bag)")
check(Events.OnFillWorldObjectContextMenu.fn==CC.fillWorldMenu and Events.OnFillInventoryObjectContextMenu.fn==CC.fillInventoryMenu,"menus registered")

-- Queued stow: walks adjacent, then a timed action performs the stow.
local walked
luautils={walkAdj=function(p,sq,flag) walked={p=p,sq=sq} end}
ISBaseTimedAction={derive=function(self,name) local c={name=name}; c.__index=c; return setmetatable(c,{__index=self}) end,
    new=function(cls,character) return setmetatable({character=character},cls) end,
    perform=function(self) self.performed=true end,stop=function(self) self.stopped=true end}
local queued={}
ISTimedActionQueue={add=function(a) queued[#queued+1]=a end}
local ground=body(false)
check(CC.queueStow(crinos,ground)==true and walked.sq==ground.square and #queued==1,"stow walks adjacent and queues one action")
local a=queued[1]
check(a:isValid() and a.maxTime==WTAGarou.CorpseCarry.STOW_TIME,"action valid with the configured duration")
a:perform()
check(a.performed and #crinos.items==2 and crinos.items[2].body==ground,"performing the action stows the corpse")
ground.animal=true
check(not a:isValid(),"action invalid once the body is no longer a human corpse")

-- Visual pushes the per-form grapple offset to Java.
local visualSrc=io.open(root.."/42/media/lua/client/WTAGarouVisual.lua"):read("*a")
check(visualSrc:find("setGrappleForward",1,true) and visualSrc:find("CorpseCarry.grappleForward",1,true),"Visual pushes the grapple-forward offset per form")

-- 0.4.42: Hispo/Lupus melee reach +30%, pushed with the other per-form flags
-- and forgotten on clear so a re-refresh re-pushes after Java clear().
check(WTAGarou.WolfMelee.rangeFor("Hispo")==1.3 and WTAGarou.WolfMelee.rangeFor("Lupus")==1.3
    and WTAGarou.WolfMelee.rangeFor("Crinos")==1 and WTAGarou.WolfMelee.rangeFor("Homid")==1,"wolf forms reach 30% further; bipeds unchanged")
check(visualSrc:find("setMeleeRange",1,true) and visualSrc:find("WolfMelee.rangeFor",1,true),"Visual pushes the melee range per form")
check(visualSrc:find("grappleForward[player] = nil",1,true) and visualSrc:find("meleeRange[player] = nil",1,true),"Visual.clear forgets the pushed values")
local coatSrc=io.open(root.."/42/media/lua/client/WTAGarouWolfCoat.lua"):read("*a")
check(not coatSrc:find('context:addOption(',1,true) and not coatSrc:find('"Wolf coat..."',1,true)
    and coatSrc:find('Coat.TITLE = "Werewolf Startup"',1,true) and coatSrc:find('function Coat.toggle(player)',1,true),
    "0.4.45: no world context entry; the Werewolf Startup panel opens from the Rage panel's Startup button")

-- Audio helper: Sound Effects slider x 75% cap on every started handle.
require "WTAGarouAudio"
local A=WTAGarou.Audio
check(A.MAX_VOLUME==1.0,"0.4.88: mod cues are not capped (slider only)")
getSoundManager=function() return {getSoundVolume=function() return 0.4 end} end
check(math.abs(A.factor()-0.4)<1e-6,"factor = slider (x 1.0)")
getSoundManager=function() return {getSoundVolume=function() return 7 end} end
check(A.factor()==1.0,"slider clamped to 1")
getSoundManager=nil
check(A.factor()==1.0,"no sound manager: full volume")
local emitter={volumes={}}
function emitter:playSound(name) return 77 end
function emitter:setVolume(handle,v) self.volumes[handle]=v end
local src={getEmitter=function() return emitter end}
local handle,used=A.play(src,"WTAGarou_CrinosRoar")
check(handle==77 and used==emitter and emitter.volumes[77]==1.0,"play starts on the emitter and scales the handle")
check(A.play(src,nil)==nil and A.play(nil,"x")==nil,"nil-safe")
check(A.scale(emitter,0)==false and A.scale(emitter,nil)==false,"zero/nil handles are not scaled")
local chr={playSound=function() return 5 end}
check(A.play(chr,"WTAGarou_WolfBark")==5 and emitter.volumes[5]==nil,"character:playSound fallback still plays when no emitter is reachable")
-- Every mod play site routes through the helper (or scales its handle).
for _,f in ipairs({"client/WTAGarouWolfVoice.lua","client/WTAGarouShiftSounds.lua","client/WTAGarouClient.lua","client/WTAGarouHowl.lua","shared/WTAGarouClothing.lua"}) do
    local s=io.open(root.."/42/media/lua/"..f):read("*a")
    check(s:find("WTAGarou.Audio",1,true),"play site uses WTAGarou.Audio: "..f)
end
local java=io.open(root.."/java/src/wtagarou/visuals/StealthRuntime.java"):read("*a")
check(java:find("MAX_VOLUME = 1.0f",1,true) and java:find("scaleHandle(character, Reflect.call(character, \"playSound\"",1,true),"Java roar/fall cues are scaled too")
print("PASS: "..n.." corpse-carry / grapple-offset / audio-scaling assertions.")
