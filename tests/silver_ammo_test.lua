-- 0.4.58 (Wits W1-W4): silver ammunition catalogue, homogeneous loading,
-- per-shot flags, magazine carry, unload hand-back, forge callbacks and the
-- vanilla action wrappers, on fixtures shaped like B42.20.2 HandWeapon /
-- ItemContainer / ISBaseTimedAction. Static evidence, not a firing range.
local root=assert(arg[1])
package.path=root.."/42/media/lua/shared/?.lua;"..root.."/42/media/lua/client/?.lua;"..root.."/42/media/lua/server/?.lua;"..package.path
local n=0
local function check(ok,why) n=n+1; assert(ok,why) end
isServer=function() return false end
isClient=function() return false end
getTimestamp=function() return 1000 end
Events=setmetatable({},{__index=function(t,k) t[k]={handlers={},Add=function(f) table.insert(t[k].handlers,f) end}; return t[k] end})
WTAGarou=WTAGarou or {}
instanceof=function(obj,cls) return obj and obj.__class==cls end
require "WTAGarouSilverAmmo"
local S=WTAGarou.SilverAmmo

-- ---------------------------------------------------------------- fixtures
local function tagset(list) local t={} for _,x in ipairs(list or {}) do t[x]=true end return t end
local function Item(fullType,opts)
    opts=opts or {}
    local it={__class=opts.class or "InventoryItem",fullType=fullType,md={},name=opts.name or fullType,tags=tagset(opts.tags),metal=opts.metal or 0}
    function it:getFullType() return self.fullType end
    function it:getModData() return self.md end
    function it:getDisplayName() return self.name end
    function it:setName(v) self.name=v end
    function it:setCustomName(v) self.custom=v end
    function it:getMetalValue() return self.metal end
    function it:getContainer() return self.container end
    function it:getTags() local arr={} for k in pairs(self.tags) do arr[#arr+1]=k end return arr end
    return it
end
local function Weapon(fullType,opts)
    opts=opts or {}
    local w=Item(fullType,{class="HandWeapon",name=opts.name,tags=opts.tags,metal=opts.metal})
    w.ranged=opts.ranged==true; w.ammoKey=opts.ammo; w.magType=opts.mag; w.chamber=opts.chamber==true
    w.rackAfter=opts.rackAfter==true; w.count=0; w.max=opts.max or 6; w.chambered=false; w.perShot=opts.perShot or 1
    function w:isRanged() return self.ranged end
    function w:getAmmoType() if not self.ammoKey then return nil end local k=self.ammoKey return {getItemKey=function() return k end} end
    function w:getMagazineType() return self.magType end
    function w:getCurrentAmmoCount() return self.count end
    function w:setCurrentAmmoCount(v) self.count=v end
    function w:getMaxAmmo() return self.max end
    function w:haveChamber() return self.chamber end
    function w:isRoundChambered() return self.chambered end
    function w:setRoundChambered(v) self.chambered=v end
    function w:isRackAfterShoot() return self.rackAfter end
    function w:getAmmoPerShoot() return self.perShot end
    w.cond=opts.cond or 10; w.condMax=opts.condMax or 10
    function w:getCondition() return self.cond end
    function w:getConditionMax() return self.condMax end
    function w:setCondition(v) self.cond=v end
    return w
end
local function Magazine(ammo,max)
    local m=Item("Base.9mmClip",{class="InventoryItem"})
    m.ammoKey=ammo; m.count=0; m.max=max or 15
    function m:getAmmoType() local k=self.ammoKey return {getItemKey=function() return k end} end
    function m:getCurrentAmmoCount() return self.count end
    function m:setCurrentAmmoCount(v) self.count=v end
    function m:getMaxAmmo() return self.max end
    return m
end
local function Inventory()
    local inv={items={}}
    function inv:AddItem(fullType) local it=Item(fullType); it.container=self; self.items[#self.items+1]=it; return it end
    function inv:add(it) it.container=self; self.items[#self.items+1]=it; return it end
    function inv:Remove(it) for i,x in ipairs(self.items) do if x==it then table.remove(self.items,i) return end end end
    function inv:getCountTypeRecurse(t) local c=0 for _,x in ipairs(self.items) do if x.fullType==t then c=c+1 end end return c end
    function inv:getFirstTypeRecurse(t) for _,x in ipairs(self.items) do if x.fullType==t then return x end end return nil end
    function inv:getItemsFromFullType(t) local arr={} for _,x in ipairs(self.items) do if x.fullType==t then arr[#arr+1]=x end end
        return {size=function() return #arr end,get=function(_,i) return arr[i+1] end} end
    function inv:contains(it) for _,x in ipairs(self.items) do if x==it then return true end end return false end
    return inv
end
local function Player()
    local p={inv=Inventory()}
    function p:getInventory() return self.inv end
    return p
end

-- ---------------------------------------------------------------- catalogue
check(S.silverTypeFor("Base.ShotgunShells")=="WTAGarou.SilverShotgunShells","shells map to silver shells")
check(S.baseTypeFor("WTAGarou.Silver556Bullets")=="Base.556Bullets","reverse map")
local calibres=0 for _ in pairs(S.CATALOG) do calibres=calibres+1 end
check(calibres==9,"one silver variant per vanilla calibre (9: shells, 9mm, .45, .44, .38, .357, .30-30, .308, 5.56)")
check(S.CATALOG["Base.223Bullets"]==nil,"no .223 entry: B42.14 removed .223 ammunition (MSR700 uses 5.56)")
check(S.silverTypeFor("Base.Bullets357")=="WTAGarou.SilverBullets357" and S.silverTypeFor("Base.3030Bullets")=="WTAGarou.Silver3030Bullets",".357 Magnum and .30-30 variants exist")
-- every item block uses the B42 ItemType keyword; the legacy `Type =` keyword is silently ignored and the engine then cannot instantiate the item (NPE in Item.InstanceItem)

check(S.silverTypeFor("Base.Nails")==nil and not S.isSilverRound("Base.Bullets9mm"),"non-ammo and ordinary rounds are not silver")
-- every catalogue entry exists in the item script
local script=assert(io.open(root.."/42/media/scripts/silver_items.txt")):read("*a")
for _,silver in pairs(S.CATALOG) do
    local short=silver:gsub("^WTAGarou%.","")
    check(script:find("item "..short.." ",1,true)~=nil,"item script defines "..silver)
end
do
    local legacy=0 for _ in script:gmatch("\n%s*Type = ") do legacy=legacy+1 end
    local typed=0 for _ in script:gmatch("\n%s*ItemType = base:%l+,") do typed=typed+1 end
    local blocks=0 for _ in script:gmatch("\n%s*item [%w_]+ ") do blocks=blocks+1 end
    check(legacy==0 and typed==blocks and blocks>=11,"every silver item block declares ItemType = base:<type> (B42 keyword), none use legacy Type = ("..blocks.." blocks)")
end
local recipes=assert(io.open(root.."/42/media/scripts/silver_recipes.txt")):read("*a")
for _,silver in pairs(S.CATALOG) do check(recipes:find(silver,1,true)~=nil,"a recipe produces "..silver) end
check(recipes:find("OnCreate = WTAGarou.SilverAmmo.OnForgeWeapon",1,true) and recipes:find("OnTest = WTAGarou.SilverAmmo.OnTestForgeInput",1,true),"forge recipe wires the Lua callbacks")
check(recipes:find("tags%[Tongs%] mode:keep") and recipes:find("tags = PrimitiveForge"),"forge recipe needs tongs at a forge")
check(not recipes:find("tags%[[^%]]*Smeltable[^%]]*%] mode:keep flags%[IsNotWorn%]"),"weapon slot excludes the Smeltable tags tongs and hammers carry")

-- ---------------------------------------------------------------- loading a tube gun
local p=Player()
local shotgun=Weapon("Base.Shotgun",{ranged=true,ammo="Base.ShotgunShells",chamber=true,rackAfter=true,max=6})
local ok,reason=S.canLoad(p,shotgun)
check(ok==false and reason=="silver_no_rounds","no silver shells: refused with a reason")
for _=1,4 do p.inv:AddItem("WTAGarou.SilverShotgunShells") end
ok,reason=S.canLoad(p,shotgun)
check(ok==true and reason==4,"four silver shells fit six-shell tube: loads 4")
shotgun.count=2 -- ordinary shells inside
ok,reason=S.canLoad(p,shotgun)
check(ok==false and reason=="silver_mixed_load","ordinary rounds inside: mixed load refused")
shotgun.count=0
local loaded=S.load(p,shotgun)
check(loaded==4 and shotgun.count==4 and S.count(shotgun)==4,"load moves 4 shells into the tube and counts them")
check(p.inv:getCountTypeRecurse("WTAGarou.SilverShotgunShells")==0,"silver items consumed")
check(S.hasOrdinary(shotgun)==false,"a silver-only tube has no ordinary rounds")
check(S.refusesOrdinaryReload(shotgun)==true,"vanilla reload refused while silver sits inside")
for _=1,4 do p.inv:AddItem("WTAGarou.SilverShotgunShells") end
ok,reason=S.canLoad(p,shotgun)
check(ok==true and reason==2,"top-up to capacity only")
S.load(p,shotgun,1)
check(shotgun.count==5 and S.count(shotgun)==5,"partial load of one")

-- rack chambers from the tube (pump shotgun)
local before=S.snapshot(shotgun)
shotgun.count=4; shotgun.chambered=true
S.afterRack(shotgun,before)
check(S.chamberSilver(shotgun)==true and S.count(shotgun)==4,"rack chambers a silver shell and decrements the tube")
check(S.nextShotIsSilver(shotgun)==true,"next shot is silver")
-- shot: pre flag, vanilla empties the chamber (rack-after-shoot keeps count)
local shot=S.onSwing(p,shotgun)
check(shot==true and shotgun.md.WTAGarou_SilverShot==true,"swing flags the shot as silver")
shotgun.chambered=false
S.afterShot(p,shotgun)
check(S.chamberSilver(shotgun)==false and S.count(shotgun)==4,"after a pump shot the chamber is empty, tube unchanged")
check(S.shotIsSilver(shotgun)==true,"hit code still sees the shot that was fired")
-- tube emptied by racking and shooting
for _=1,4 do
    before=S.snapshot(shotgun); shotgun.count=shotgun.count-1; shotgun.chambered=true; S.afterRack(shotgun,before)
    S.onSwing(p,shotgun); shotgun.chambered=false; S.afterShot(p,shotgun)
end
check(shotgun.count==0 and S.count(shotgun)==0 and shotgun.md.WTAGarou_SilverAmmo==nil,"empty tube clears the silver count")
check(S.refusesOrdinaryReload(shotgun)==false,"ordinary reload allowed again once the silver is gone")
shotgun.count=3 -- ordinary reload
S.onSwing(p,shotgun)
check(shotgun.md.WTAGarou_SilverShot==false,"ordinary shells fire ordinary shots")

-- ---------------------------------------------------------------- revolver (no chamber)
local revolver=Weapon("Base.Revolver",{ranged=true,ammo="Base.Bullets44",chamber=false,max=6})
for _=1,6 do p.inv:AddItem("WTAGarou.SilverBullets44") end
check(S.load(p,revolver)==6,"six silver .44 into the cylinder")
check(S.nextShotIsSilver(revolver)==true,"cylinder gun: silver when count>0")
S.onSwing(p,revolver); revolver.count=5; S.afterShot(p,revolver)
check(S.count(revolver)==5 and S.shotIsSilver(revolver)==true,"cylinder shot decrements silver")

-- ---------------------------------------------------------------- unload hands silver back
for _=1,3 do p.inv:AddItem("WTAGarou.SilverShotgunShells") end
shotgun.count=0; S.load(p,shotgun)
local before2=S.snapshot(shotgun)
-- vanilla unload step: one ordinary shell appears, count drops by one
p.inv:AddItem("Base.ShotgunShells"); shotgun.count=before2.count-1
local swapped=S.swapUnloadedRounds(p,shotgun,before2.silver,before2.count-shotgun.count)
check(swapped==1 and p.inv:getCountTypeRecurse("Base.ShotgunShells")==0 and p.inv:getCountTypeRecurse("WTAGarou.SilverShotgunShells")==1,"unloaded ordinary shell swapped for a silver shell")
check(S.count(shotgun)==before2.silver-1 and S.count(shotgun)==shotgun.count,"tube silver count follows the unload")

-- ---------------------------------------------------------------- magazines
local pistol=Weapon("Base.Pistol",{ranged=true,ammo="Base.Bullets9mm",mag="Base.9mmClip",chamber=true,max=15})
ok,reason=S.canLoad(p,pistol)
check(ok==false and reason=="silver_use_magazine","magazine guns load through the magazine")
local mag=Magazine("Base.Bullets9mm",15)
for _=1,15 do p.inv:AddItem("WTAGarou.SilverBullets9mm") end
check(S.load(p,mag)==15 and S.count(mag)==15,"magazine takes 15 silver 9mm")
check(S.refusesOrdinaryReload(mag)==true,"ordinary rounds refused into a silver magazine")
-- insert: gun mirrors the magazine
pistol.count=15; S.afterInsert(pistol,S.clamp(mag))
check(S.count(pistol)==15,"inserted magazine's silver count moves to the gun")
-- auto rack after insert
before=S.snapshot(pistol); pistol.count=14; pistol.chambered=true; S.afterRack(pistol,before)
check(S.chamberSilver(pistol) and S.count(pistol)==14,"rack after insert chambers silver")
-- semi-auto shot auto-chambers
S.onSwing(p,pistol); pistol.count=13; S.afterShot(p,pistol)
check(S.shotIsSilver(pistol) and S.chamberSilver(pistol) and S.count(pistol)==13,"semi-auto: silver shot, next silver chambered, count 13")
-- eject: new magazine inherits
local newMag=Magazine("Base.Bullets9mm",15); newMag.count=13
S.afterEject(pistol,newMag,S.clamp(pistol))
check(S.count(newMag)==13 and S.count(pistol)==0 and S.chamberSilver(pistol)==true,"ejected magazine carries 13 silver; chambered silver round stays in the gun")
S.onSwing(p,pistol); pistol.chambered=false; S.afterShot(p,pistol)
check(S.shotIsSilver(pistol)==true and S.chamberSilver(pistol)==false,"last chambered silver round fires silver, then the chamber is empty")

-- ---------------------------------------------------------------- legacy debug flag
local debugGun=Weapon("Base.Shotgun",{ranged=true,ammo="Base.ShotgunShells",chamber=true,rackAfter=true})
debugGun.md.WTAGarou_SilverAmmo=true; debugGun.count=3
check(S.count(debugGun)==math.huge and S.nextShotIsSilver(debugGun) and S.refusesOrdinaryReload(debugGun)==false,"Test Panel flag: unlimited silver, reload untouched")
ok,reason=S.canLoad(p,debugGun)
check(ok==false and reason=="silver_debug","no real loading onto the debug flag")
S.onSwing(p,debugGun); debugGun.count=2; S.afterShot(p,debugGun)
check(debugGun.md.WTAGarou_SilverAmmo==true,"debug flag never decremented")

-- ---------------------------------------------------------------- forge callbacks
local machete=Weapon("Base.Machete",{name="Machete",tags={"HasMetal","Sharpenable"}})
local bat=Weapon("Base.BaseballBat",{name="Baseball Bat",tags={"RepairWithTape"}})
local hammer=Weapon("Base.Hammer",{name="Hammer",tags={"Hammer","HasMetal"}})
local tongs=Item("Base.Tongs",{tags={"Tongs","SmeltableIronMedium"}})
local scrap=Item("Base.SilverScrap")
local rifle=Weapon("Base.VarmintRifle",{ranged=true,ammo="Base.556Bullets",tags={"HasMetal"}})
check(S.canSilverWeapon(machete) and not S.canSilverWeapon(bat) and not S.canSilverWeapon(hammer) and not S.canSilverWeapon(tongs) and not S.canSilverWeapon(rifle),"only metal melee weapons that are not tools can take silver")
check(S.OnTestForgeInput(tongs)==true and S.OnTestForgeInput(scrap)==true and S.OnTestForgeInput(hammer)==true,"tools and fragments pass the input test")
check(S.OnTestForgeInput(machete)==true and S.OnTestForgeInput(bat)==false and S.OnTestForgeInput(rifle)==false,"weapon slot: metal melee yes, wooden bat and rifle no")
local kept={machete,hammer,tongs}
local data={getAllKeepInputItems=function() return {size=function() return #kept end,get=function(_,i) return kept[i+1] end} end}
check(S.OnForgeWeapon(data,p)==1,"forge marks exactly the weapon")
check(machete.md.WTAGarou_Silver==true and machete.name=="Silver Machete","silvered machete renamed and flagged")
check(hammer.md.WTAGarou_Silver==nil and tongs.md.WTAGarou_Silver==nil,"tools untouched")
check(S.OnTestForgeInput(machete)==false and S.canSilverWeapon(machete)==false,"an already silver weapon cannot be silvered again")
check(S.OnForgeWeapon(data,p)==0 and machete.name=="Silver Machete","repeat forge adds nothing and never double-prefixes")
check(S.silverName("Silver Axe")=="Silver Axe","name helper idempotent")

-- ---------------------------------------------------------------- forge skill rule (0.4.59)
Perks={Blacksmith="Blacksmith"}
local function smith(level) local c={} function c:getPerkLevel(p) return level end return c end
local macheteF=Weapon("Base.MacheteForged",{name="Machete",tags={"HasMetal"}})
local macheteLoot=Weapon("Base.Machete",{name="Machete",tags={"HasMetal"}})
local smallKnife=Weapon("Base.SmallKnife",{name="Small Knife",tags={"HasMetal"}})
local crowbar=Weapon("Base.Crowbar",{name="Crowbar",tags={"HasMetal"}})
check(S.forgeLevelFor(macheteF)==9 and S.forgeLevelFor(macheteLoot)==9,"machete (forged or loot) asks for Blacksmith 9 like vanilla's blade")
check(S.forgeLevelFor(smallKnife)==1 and S.forgeLevelFor(crowbar)==S.FORGE_LEVEL_DEFAULT,"small knife 1; unforgeable weapons use the floor")
check(S.OnTestForgeInput(macheteLoot,smith(3))==false and S.OnTestForgeInput(macheteLoot,smith(9))==true,"a level-3 smith cannot silver a machete, a level-9 smith can")
check(S.OnTestForgeInput(smallKnife,smith(1))==true and S.OnTestForgeInput(smallKnife,smith(0))==false,"small knife follows its own level")
check(S.OnTestForgeInput(macheteLoot,nil)==true,"no character: defer to the recipe's SkillRequired floor")
check(S.OnTestForgeInput(tongs,smith(0))==true and S.OnTestForgeInput(hammer,smith(0))==true,"tools never consult the skill")
check(S.canForgeAtSkill(macheteLoot,{})==true,"character without perks API passes (fail open to the floor)")
local recipes2=assert(io.open(root.."/42/media/scripts/silver_recipes.txt")):read("*a")
check(recipes2:find("SkillRequired = Blacksmith:1",1,true)~=nil,"forge recipe keeps the level-1 floor in the script")

-- ---------------------------------------------------------------- silver nitrate coat (0.4.59)
check(recipes2:find("craftRecipe WTAGarou_PrepareSilverNitrate",1,true) and recipes2:find("item 2 %[Base.Fertilizer;1:Base.Coldpack%]") and recipes2:find("CarBattery1;Base.CarBattery2;Base.CarBattery3%] mode:destroy") and recipes2:find("item 1 tags%[Glass;GlassBottle%] mode:keep flags%[ItemIsFluid;IsEmpty%]") and not recipes2:find("item 1 %[Base.EmptyJar%]"),"nitrate recipe: 2 fertilizer uses, a destroyed battery, any empty glass vessel (0.4.60), kept (0.4.62)")
check(recipes2:find("OnTest = WTAGarou.SilverAmmo.OnTestNitrateInput",1,true)~=nil,"nitrate recipe wires the vessel OnTest")
-- 0.4.60 vessel rule: glass fluid containers that are empty; nothing plastic, no windshields/shards
local function Vessel(fullType,opts)
    local v=Item(fullType,{tags=opts.tags})
    v.fc=opts.fc; v.empty=opts.empty
    function v:isFluidContainer() return self.fc==true end
    function v:getFluidContainer() if not self.fc then return nil end local e=self.empty return {isEmpty=function() return e end} end
    return v
end
local jarV=Vessel("Base.EmptyJar",{tags={"Glass"},fc=true,empty=true})
local beer=Vessel("Base.BeerBottle",{tags={"Glass","GlassBottle"},fc=true,empty=true})
local fullBeer=Vessel("Base.BeerBottle",{tags={"Glass","GlassBottle"},fc=true,empty=false})
local windshield=Vessel("Base.Windshield1",{tags={"Glass"},fc=false})
local plastic=Vessel("Base.WaterBottleEmpty",{tags={"Plastic"},fc=true,empty=true})
check(S.OnTestNitrateInput(jarV)==true and S.OnTestNitrateInput(beer)==true,"jar and empty beer bottle are accepted vessels")
check(S.OnTestNitrateInput(fullBeer)==false,"a bottle with fluid in it is refused")
check(S.OnTestNitrateInput(windshield)==false,"Glass-tagged non-container (windshield) is refused")
check(S.isEmptyGlassVessel(plastic)==false and S.OnTestNitrateInput(Item("Base.Fertilizer",{tags={}}))==true,"plastic is never a vessel; non-glass inputs pass through untouched")
check(S.OnTestNitrateInput(nil)==false,"nil input refused")
check(recipes2:find("tags%[SharpKnife;Screwdriver;Pliers;MetalworkingPliers%] mode:keep"),"knife, screwdriver or pliers opens the battery and is kept")
check(not recipes2:find("WTAGarou_PrepareSilverNitrate.-SkillRequired.-craftRecipe WTAGarou_CoatSilverNitrate") ,"nitrate recipes carry no skill requirement")
-- 0.4.62: silver nitrate is a fluid in two stages; the vessel is kept and filled.
check(recipes2:find("item 1 tags%[Glass;GlassBottle%] mode:keep flags%[ItemIsFluid;IsEmpty%],%s*%+fluid 1%.0 WTAGarou_SilverNitrateRaw,"),"prepare recipe keeps the empty glass vessel and pours 1.0 L of raw nitrate into it")
check(recipes2:find("item 2 %[Base%.Fertilizer;1:Base%.Coldpack%]") and recipes2:find("item 1 %[Base%.SilverScrap%]") and recipes2:find("CarBattery1[^\n]*mode:destroy"),"two fertilizer USES or one cold pack (0.4.65), one fragment, the battery destroyed")
check(not recipes2:find("WTAGarou%.SilverNitrateRaw") and not recipes2:find("%[WTAGarou%.SilverNitrate%]"),"no nitrate ITEM is referenced any more")
check(recipes2:find("OnTest = WTAGarou.SilverAmmo.OnTestCoatInput",1,true) and recipes2:find("OnCreate = WTAGarou.SilverAmmo.OnCoatWeapon",1,true),"coat recipe wires the callbacks")
check(recipes2:find("item 1 %[%*%] mode:keep flags%[ItemIsFluid%],%s*%-fluid 0%.2 %[WTAGarou_SilverNitrate%],"),"coat recipe drinks 0.2 L of finished nitrate out of any fluid container, which is kept")
check(S.COAT_FLUID==0.2 and S.FLUID_RAW=="WTAGarou_SilverNitrateRaw" and S.FLUID_DONE=="WTAGarou_SilverNitrate","Lua constants match the script")
-- 0.4.65: a hosted co-op server has no ZombieBuddy, so the Java-added tags are
-- empty there and `tags[wtagarou:coatable]` aborted world load ("Tag has no
-- items"). Both weapon slots are explicit, generated item lists; the coat slot
-- also unions the vanilla metal tags (OnTestCoatInput trims the junk).
check(not recipes2:find("item %d+ tags%[wtagarou:") and not recipes2:find("%] tags%[wtagarou:"),"no recipe input depends on a Java-added tag (server-safe)")
local coatLine=recipes2:match("GENERATED coatable list[^\n]*\n%s*(item 1 [^\n]*)")
local forgeLine=recipes2:match("GENERATED forgeable list[^\n]*\n%s*(item 1 [^\n]*)")
check(coatLine and coatLine:find("^item 1 %[Base%.[^%]]+%] tags%[HasMetal;Sharpenable;SmeltableIronSmall;[^%]]*SmeltableSteelLarge%] mode:keep,$"),"coat weapon slot = explicit list UNION metal tags, kept")
check(forgeLine and forgeLine:find("^item 1 %[Base%.[^%]]+%] mode:keep,$") and not forgeLine:find("tags%["),"forge weapon slot = explicit list only (no HasMetal union: hammers stay out)")
local function listOf(line) local t={} for n in line:match("%[([^%]]+)%]"):gmatch("[^;]+") do t[n]=true end return t end
local coatList,forgeList=listOf(coatLine),listOf(forgeLine)
local nCoat,nForge=0,0 for _ in pairs(coatList) do nCoat=nCoat+1 end for _ in pairs(forgeList) do nForge=nForge+1 end
check(nCoat>=180 and nForge>=170 and nForge<nCoat,"lists are populated ("..nCoat.." coatable, "..nForge.." forgeable)")
for _,n in ipairs({"Base.Hammer","Base.ClubHammer","Base.BallPeenHammer","Base.File","Base.HammerForged"}) do
    check(coatList[n] and not forgeList[n],n.." is coatable but not the forge weapon")
end
for _,n in ipairs({"Base.Machete","Base.HuntingKnife","Base.KitchenKnife","Base.Crowbar","Base.CarvingFork2","Base.IceAxe","Base.Katana","Base.WoodAxe","Base.MeatCleaver"}) do
    check(coatList[n] and forgeList[n],n.." is coatable and forgeable")
end
for _,n in ipairs({"Base.SilverScrap","Base.Fertilizer","Base.Pistol","Base.Shotgun","Base.StoneAxe","Base.Plank","Base.Aluminum","Base.TinCanEmpty","Base.LightBulb"}) do
    check(not coatList[n],n.." is not in the coat list")
end
check(not recipes2:find("flags%[IsNotWorn%]") and not recipes2:find("tags%[HasMetal;Sharpenable;SharpKnife;ChopTree%]"),"no IsNotWorn (it rejected equipped weapons), no bare 0.4.61 tag line")
-- 0.4.63: coating needs no surface; mixing still does
check(recipes2:find("craftRecipe WTAGarou_CoatSilverNitrate%s*{%s*Time = %d+,%s*Tags = InHandCraft,"),"coat recipe is InHandCraft (no surface)")
check(recipes2:find("craftRecipe WTAGarou_PrepareSilverNitrate%s*{%s*Time = %d+,%s*Tags = AnySurfaceCraft,"),"mixing the raw nitrate still wants a surface")
-- 0.4.63: one round per craft, filings as the silver source
check(recipes2:find("craftRecipe WTAGarou_FileSilverFragments") and recipes2:find("item 1 %[Base%.SilverScrap%],%s*item 1 tags%[File%] mode:keep") and recipes2:find("item 1 WTAGarou%.SilverFilings,"),"a fragment is filed into Silver Filings with a file")
check(recipes2:find("craftRecipe WTAGarou_SilverShotgunShells%s*{%s*Time = 30,") and recipes2:find("item 1 %[Base%.ShotgunShells%],%s*item 3 %[WTAGarou%.SilverFilings%],") and recipes2:find("item 1 WTAGarou%.SilverShotgunShells,"),"shells: one per craft, 3 filings uses, 30 time (180/6)")
-- (0.4.81: the smoke bomb repack legitimately takes "item 10" filings uses; it is not a batch round recipe)
local roundsOnly=recipes2:gsub("craftRecipe WTAGarou_PackSilverSmokeBomb.-\n    }\n","")
check(select(2,recipes2:gsub("Time = 24,",""))==8 and select(2,recipes2:gsub("item 2 %[WTAGarou%.SilverFilings%],",""))==8 and not roundsOnly:find("item 10 "),"bullets: eight calibres, one per craft, 2 filings uses, 24 time (240/10)")
local fluids=assert(io.open(root.."/42/media/scripts/silver_fluids.txt")):read("*a")
check(fluids:find("fluid WTAGarou_SilverNitrateRaw",1,true) and fluids:find("fluid WTAGarou_SilverNitrate\n",1,true),"both nitrate fluids are defined")
check(select(2,fluids:gsub("Hazardous,",""))==2 and fluids:find("maxEffect%s*=%s*Deadly") and fluids:find("minAmount%s*=%s*0%.2") and fluids:find("diluteRatio%s*=%s*0%.1"),"finished nitrate poisons like bleach (Deadly, 0.2 L, 10% dilution), both hazardous")
check(fluids:find("DisplayName%s*=%s*Fluid_Name_WTAGarou_SilverNitrateRaw") and fluids:find("DisplayName%s*=%s*Fluid_Name_WTAGarou_SilverNitrate,"),"fluid display names are translation keys")
check(select(2,fluids:gsub("\n%s*BlendWhiteList",""))==2 and fluids:find("fluids%s*{%s*WTAGarou_SilverNitrate,%s*}") and fluids:find("fluids%s*{%s*WTAGarou_SilverNitrateRaw,%s*}"),"the two nitrates blend only with each other (raw turns into finished inside one vessel)")
local items2=assert(io.open(root.."/42/media/scripts/silver_items.txt")):read("*a")
check(not items2:find("item SilverNitrate",1,true) and not items2:find("WTAGarouSealedSilver",1,true),"the nitrate jar items are gone")
check(select(2,items2:gsub("Tags = Ammo;wtagarou:silverammo,",""))>=7 and not items2:find("WTAGarouSilverAmmo,",1,true),"silver rounds carry the REGISTERED namespaced tag (unregistered tags resolve to null)")
local reg=assert(io.open(root.."/42/media/registries.lua")):read("*a")
check(items2:find("item SilverFilings {",1,true) and items2:find("ItemType = base:drainable",1,true) and items2:find("UseDelta = 0.05,",1,true),"Silver Filings is a 20-use drainable")
check(reg:find('itemTag("wtagarou:forgeable")',1,true),"registries.lua registers the forgeable tag")
check(reg:find('itemTag("wtagarou:silverammo")',1,true) and reg:find('itemTag("wtagarou:coatable")',1,true) and reg:find("ItemTag.get(ResourceLocation.of(id))",1,true),"registries.lua registers both tags, get-before-register")
local fl=assert(io.open(root.."/42/media/lua/shared/Translate/EN/Fluids.json")):read("*a")
check(fl:find("Fluid_Name_WTAGarou_SilverNitrateRaw",1,true) and fl:find("Fluid_Name_WTAGarou_SilverNitrate\"",1,true),"Fluids.json names both fluids")
check(io.open(root.."/42/media/lua/shared/Translate/EN/Tooltip.json")==nil,"Tooltip.json is gone (its literal % broke the translator: 'Missing arguments for Tooltip_WTAGarou_SilverNitrate')")
check(assert(io.open(root.."/42/media/lua/shared/Translate/EN/Recipes.json")):read("*a"):find("SilverNitrate",1,true)~=nil,"Recipes.json names the nitrate recipes")
-- namespaced tag strings ("base:hasmetal") are what getTags() yields in-game
check(S.tagKey("base:HasMetal")=="hasmetal" and S.tagKey("Tongs")=="tongs" and S.tagKey(nil)=="","tagKey strips namespace and case")
check(S.hasAnyTag(Item("Base.X",{tags={"base:hasmetal"}}),S.METAL_TAGS)==true and S.hasAnyTag(Item("Base.X",{tags={"base:tongs"}}),{Tongs=true})==true,"namespaced in-game tags match")
check(S.canCoatWeapon(Weapon("Base.Tongs",{name="Tongs",tags={"base:tongs","base:hasmetal"}}))==true and S.canSilverWeapon(Weapon("Base.Tongs",{name="Tongs",tags={"base:tongs","base:hasmetal"}}))==false,"0.4.63: namespaced Tongs are coatable but not forgeable")
-- 0.4.63: missing weapons from the Oct 16 playtest
check(S.canCoatWeapon(Weapon("Base.SmithingHammer",{name="Smithing Hammer",tags={"base:hammer"},metal=25}))==true and S.canCoatWeapon(hammer)==true,"smithing hammer and claw hammer coat")
check(S.canCoatWeapon(Weapon("Base.CarvingFork2",{name="Carving Fork",tags={}}))==true,"carving fork (no tags, no MetalValue) coats by name")
check(S.canCoatWeapon(Weapon("Base.IceAxe",{name="Ice Axe",tags={}}))==true,"ice axe coats by name")
check(S.canCoatWeapon(Weapon("Base.FireplacePoker",{name="Fireplace Poker",tags={"base:smeltableironsmall"}}))==true,"Smeltable* tag counts as metal")
check(S.canCoatWeapon(Weapon("Base.PipeWrench",{name="Pipe Wrench",tags={"base:smeltablesteelmediumplus"}}))==true,"any smeltable* prefix counts")
check(S.canCoatWeapon(Weapon("Base.FlintKnife",{name="Stone Knife",tags={"base:sharpknife","base:killanimal"}}))==false,"stone knife (SharpKnife only) does not coat")
check(S.canCoatWeapon(Weapon("Base.StoneAxe",{name="Stone Axe",tags={"base:choptree"}}))==false,"stone axe (ChopTree only) does not coat")
check(S.canSilverWeapon(Weapon("Base.CarvingFork2",{name="Carving Fork",tags={}}))==true,"carving fork can also be forged")
check(S.canCoatWeapon(Weapon("Base.Pan",{name="Saucepan",tags={"base:hasmetal"}}))==true,"namespaced HasMetal weapon can be coated")
check(S.COAT_HITS==12 and S.COAT_CONDITION_FRACTION==0.10,"user-chosen numbers: 12 hits, 10% condition")
local axe2=Weapon("Base.Axe",{name="Axe",tags={"HasMetal","ChopTree"},cond=10,condMax=10})
local jar=Vessel("Base.EmptyJar",{tags={"Glass"},fc=true,empty=false})
local emptyJar=Vessel("Base.EmptyJar",{tags={"Glass"},fc=true,empty=true})
local foil=Item("Base.AluminumFoil",{tags={"HasMetal"}})
check(S.OnTestCoatInput(jar)==true and S.OnTestCoatInput(axe2)==true and S.OnTestCoatInput(bat)==false and S.OnTestCoatInput(rifle)==false,"coat test: filled vessel passes, metal axe yes, bat and rifle no")
check(S.OnTestCoatInput(emptyJar)==false and S.OnTestCoatInput(foil)==false,"an empty vessel or a non-weapon HasMetal item (foil) is refused")
check(S.isFilledFluidContainer(jar) and not S.isFilledFluidContainer(emptyJar) and not S.isFilledFluidContainer(axe2),"isFilledFluidContainer")
local dataPan={getAllKeepInputItems=function() local k={jar,axe2} return {size=function() return #k end,get=function(_,i) return k[i+1] end} end}
check(S.OnCoatWeapon(dataPan,p)==1 and S.coatLeft(axe2)==12 and S.coatLeft(jar)==0,"the kept vessel is never coated, the weapon is")
axe2.md={}; axe2.name="Axe"; axe2.cond=10
check(S.OnTestCoatInput(machete)==false,"a forged Silver weapon cannot be coated")
check(not S.isCoated(axe2) and S.coatLeft(axe2)==0 and S.spendCoat(axe2)==nil,"uncoated: no charges, nothing to spend")
local data2={getAllKeepInputItems=function() local k={axe2} return {size=function() return #k end,get=function(_,i) return k[i+1] end} end}
check(S.OnCoatWeapon(data2,p)==1,"coating marks the kept axe")
check(S.coatLeft(axe2)==12 and axe2.name=="Silvered Axe (12)" and axe2.cond==9,"12 charges, renamed, 1 of 10 condition eaten")
check(axe2.custom==true,"renamed items are flagged customName so the name survives a save")
local tl,tr,tg,tb=S.tooltipLine(axe2)
check(tl=="Silver coat: 12 of 12 hits left" and tr and tg and tb,"tooltip line shows only the charge meter, without the bare-hand warning")
check(S.tooltipLine(bat)==nil and S.tooltipLine(nil)==nil,"plain items get no line")
check(S.tooltipLine(machete)=="Silver-Clad: burns werewolves, prevents healing.","forged silver gets its own line (0.4.79 wording)")
check(S.canSilverWeapon(axe2)==false,"a coated weapon cannot be forged while the coat lasts")
for i=1,11 do check(S.spendCoat(axe2)==12-i,"hit "..i.." leaves "..(12-i)) end
check(axe2.name=="Silvered Axe (1)","name tracks the count")
check(S.spendCoat(axe2)==0 and axe2.name=="Axe" and not S.isCoated(axe2) and axe2.md[S.COAT_NAME_KEY]==nil,"last hit: coat gone, name restored")
check(axe2.custom==false and S.tooltipLine(axe2)==nil,"customName cleared with the coat; tooltip line gone")
check(S.canSilverWeapon(axe2)==true,"a worn-off weapon can be forged again")
S.OnCoatWeapon(data2,p); S.spendCoat(axe2); S.OnCoatWeapon(data2,p)
check(S.coatLeft(axe2)==12 and axe2.name=="Silvered Axe (12)" and axe2.cond==7,"re-coat refreshes to 12 and costs condition again")
local weak=Weapon("Base.KitchenKnife",{name="Kitchen Knife",tags={"HasMetal"},cond=1,condMax=10})
S.applyCoat(weak)
check(weak.cond==1,"a coat never breaks the weapon (condition floor 1)")
local big=Weapon("Base.Sledgehammer",{name="Sledgehammer",tags={"HasMetal"},cond=15,condMax=15})
S.applyCoat(big)
check(big.cond==13,"10% of 15 rounds to 2")

-- ---------------------------------------------------------------- vanilla wrappers
local env={}
local function action(cls,fields)
    local klass={} klass.__index=klass
    function klass:isValid() return "orig" end
    function klass:animEvent(ev) self.events=(self.events or 0)+1; if self.onEvent then self:onEvent() end return "orig" end
    function klass:loadAmmo() self.gun.count=self.magazine.count end
    function klass:unloadAmmo() local m=Magazine(self.gun.ammoKey,15); m.count=self.gun.count; self.gun.count=0; self.character.inv:add(m); m.fullType=self.gun.magType end
    function klass:removeBullet() self.character.inv:AddItem(self.gun.ammoKey); self.vanillaRemoved=(self.vanillaRemoved or 0)+1 end
    env[cls]=klass
    return function(f) return setmetatable(f or {},klass) end
end
local Reload=action("ISReloadWeaponAction")
local LoadMag=action("ISLoadBulletsInMagazine")
local UnloadGun=action("ISUnloadBulletsFromFirearm")
local UnloadMag=action("ISUnloadBulletsFromMagazine")
local Insert=action("ISInsertMagazine")
local Eject=action("ISEjectMagazine")
local Rack=action("ISRackFirearm")
local flashed={}
WTAGarou.HUD={instance={flashDenial=function(_,r) flashed[#flashed+1]=r end}}
check(S.install(env)==8,"eight vanilla ammunition paths wrapped")
check(S.install(env)==0,"install is idempotent")
local p2=Player()
local sg=Weapon("Base.Shotgun",{ranged=true,ammo="Base.ShotgunShells",chamber=true,rackAfter=true,max=6})
for _=1,2 do p2.inv:AddItem("WTAGarou.SilverShotgunShells") end
S.load(p2,sg)
check(Reload({character=p2,gun=sg}):isValid()==false and flashed[#flashed]=="silver_mixed_load","vanilla reload into a silver tube refused with HUD reason")
sg.count=0; S.setCount(sg,0)
check(Reload({character=p2,gun=sg}):isValid()=="orig","empty tube: vanilla reload passes through")
local m2=Magazine("Base.Bullets9mm",15); for _=1,3 do p2.inv:AddItem("WTAGarou.SilverBullets9mm") end; S.load(p2,m2)
check(LoadMag({character=p2,magazine=m2}):isValid()==false,"vanilla bullets-into-silver-magazine refused")
-- unload gun wrapper: vanilla step creates an ordinary shell and drops count
for _=1,2 do p2.inv:AddItem("WTAGarou.SilverShotgunShells") end; S.load(p2,sg)
local ug=UnloadGun({character=p2,gun=sg})
ug.onEvent=function(self) self.character.inv:AddItem("Base.ShotgunShells"); self.gun.count=self.gun.count-1 end
ug:animEvent("playReloadSound"); ug:animEvent("playReloadSound")
check(p2.inv:getCountTypeRecurse("Base.ShotgunShells")==0 and p2.inv:getCountTypeRecurse("WTAGarou.SilverShotgunShells")==2 and S.count(sg)==0,"unload wrapper hands both shells back as silver")
local um=UnloadMag({character=p2,magazine=m2})
um.onEvent=function(self) self.character.inv:AddItem("Base.Bullets9mm"); self.magazine.count=self.magazine.count-1 end
um:animEvent("x")
check(p2.inv:getCountTypeRecurse("Base.Bullets9mm")==0 and p2.inv:getCountTypeRecurse("WTAGarou.SilverBullets9mm")==1 and S.count(m2)==2,"magazine unload step swaps one round")
-- insert / eject wrappers
local pistol2=Weapon("Base.Pistol",{ranged=true,ammo="Base.Bullets9mm",mag="Base.9mmClip",chamber=true,max=15})
Insert({character=p2,gun=pistol2,magazine=m2}):loadAmmo()
check(S.count(pistol2)==2 and pistol2.count==2,"insert wrapper moves the magazine's silver count to the gun")
Eject({character=p2,gun=pistol2}):unloadAmmo()
local ejected=p2.inv:getItemsFromFullType("Base.9mmClip")
check(ejected:size()==1 and S.count(ejected:get(0))==2 and S.count(pistol2)==0,"eject wrapper finds the new magazine and gives it the silver count")
-- rack wrapper
sg.count=0; for _=1,2 do p2.inv:AddItem("WTAGarou.SilverShotgunShells") end; S.load(p2,sg)
local rk=Rack({character=p2,gun=sg})
local tubeBefore=sg.count
check(tubeBefore>0 and S.count(sg)==tubeBefore and sg.chambered==false,"rack scenario starts with a silver-only tube and an empty chamber")
rk.onEvent=function(self) self.gun.count=self.gun.count-1; self.gun.chambered=true end
rk:animEvent("x")
check(S.chamberSilver(sg)==true and S.count(sg)==tubeBefore-1,"rack wrapper chambers silver and decrements the tube")
-- 0.4.63: racking a chambered silver shell hands back a SILVER shell
check(S.ejectedRoundType(sg)=="WTAGarou.SilverShotgunShells","chambered silver shell: the rack ejects the silver type")
local plainBefore=p2.inv:getCountTypeRecurse("Base.ShotgunShells")
local silverBefore=p2.inv:getCountTypeRecurse("WTAGarou.SilverShotgunShells")
rk:removeBullet()
check(p2.inv:getCountTypeRecurse("Base.ShotgunShells")==plainBefore and p2.inv:getCountTypeRecurse("WTAGarou.SilverShotgunShells")==silverBefore+1 and not rk.vanillaRemoved,"rack ejection returns a silver shell, vanilla removeBullet skipped")
S.setChamberSilver(sg,false)
check(S.ejectedRoundType(sg)==nil,"ordinary chambered round: vanilla path")
rk:removeBullet()
check(rk.vanillaRemoved==1 and p2.inv:getCountTypeRecurse("Base.ShotgunShells")==plainBefore+1,"vanilla removeBullet runs for an ordinary round")
local rev=Weapon("Base.Revolver",{ranged=true,ammo="Base.Bullets44",chamber=false,max=6})
S.setCount(rev,2); rev.count=2
check(S.ejectedRoundType(rev)=="WTAGarou.SilverBullets44","chamberless gun with silver rounds ejects silver")
S.setCount(rev,0)
check(S.ejectedRoundType(rev)==nil and S.ejectedRoundType(nil)==nil,"empty cylinder / nil: vanilla")
check(#Events.OnWeaponSwing.handlers==1 and #Events.OnWeaponSwingHitPoint.handlers==1 and #Events.OnGameStart.handlers==1,"swing, hit-point and game-start hooks registered once")

-- melee weapons and nil never touch the shot flag
local axe=Weapon("Base.Axe",{name="Axe"})
check(S.onSwing(p,axe)==nil and axe.md.WTAGarou_SilverShot==nil,"melee swing ignored")
S.afterShot(p,nil); S.onSwing(nil,nil)
-- 0.4.65: recipe drift report (client has Java tags; recipes carry explicit lists)
do
    local COAT, FORGE = {id="coatable"}, {id="forgeable"}
    local function JList(items) return { size=function() return #items end, get=function(_,i) return items[i+1] end } end
    local function JSet(items) local t={} for _,x in ipairs(items) do t[x]=true end
        return { contains=function(_,x) return t[x]==true end } end
    local function SItem(full,tags) return { getFullName=function() return full end, getTags=function() return JSet(tags) end } end
    local function Input(names) local items={} for _,nm in ipairs(names) do items[#items+1]=SItem(nm,{}) end
        return { getPossibleInputItems=function() return JList(items) end } end
    local recipes = {
        WTAGarou_CoatSilverNitrate = { getInputs=function() return JList({ Input({"Base.Axe","Base.Hammer"}), Input({"Base.WaterBottle"}) }) end },
        WTAGarou_SilverWeapon = { getInputs=function() return JList({ Input({"Base.Axe"}), Input({"Base.SilverScrap"}), Input({"Base.Hammer"}) }) end },
    }
    local all = { SItem("Base.Axe",{COAT,FORGE}), SItem("Base.Hammer",{COAT}), SItem("Base.NewSword",{COAT,FORGE}), SItem("Base.Plank",{}) }
    local sm = { getCraftRecipe=function(_,name) return recipes[name] end, getAllItems=function() return JList(all) end }
    local reg = { Coatable=COAT, Forgeable=FORGE }
    local d = S.recipeDrift(sm, reg)
    check(d and d.tagged==3 and #d.coat==1 and d.coat[1]=="Base.NewSword" and #d.forge==1 and d.forge[1]=="Base.NewSword","drift lists the tagged sword both recipes miss; the hammer is coatable-only and the forge list is not asked for it")
    local msg = S.reportRecipeDrift(sm, reg)
    check(msg:find("1 rule%-coatable item%(s%) missing from the coat list %[Base%.NewSword%]") and msg:find("gen_coatable_lists%.py %-%-extra"),"report names the missing item and the tool")
    recipes.WTAGarou_CoatSilverNitrate = { getInputs=function() return JList({ Input({"Base.Axe","Base.Hammer","Base.NewSword"}) }) end }
    recipes.WTAGarou_SilverWeapon = { getInputs=function() return JList({ Input({"Base.Axe","Base.NewSword"}) }) end }
    check(S.reportRecipeDrift(sm, reg):find("drift: none; recipes cover all 3"),"no drift once the lists include the sword")
    check(S.recipeDrift(nil, {})==nil and S.reportRecipeDrift({ getCraftRecipe=function() error("boom") end, getAllItems=function() return JList({}) end }, reg):find("not measurable"),"missing registry / failing script manager degrade to nil and a plain message")
end
print("PASS: "..n.." silver ammunition catalogue/loading/shot/magazine/forge/skill/nitrate-coat/wrapper assertions; no firing-range evidence.")
