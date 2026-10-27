-- 0.4.58: quadruped lockouts (firearm handling, crafting, mechanics) and
-- the jaws bite-speed normalisation. Fixtures shaped like B42.20.2 timed
-- actions (isValid gate), ISFirearmRadialMenu, ISEntityUI and HandWeapon.
local root=assert(arg[1])
package.path=root.."/42/media/lua/shared/?.lua;"..root.."/42/media/lua/client/?.lua;"..package.path
local n=0
local function check(ok,why) n=n+1; assert(ok,why) end
isServer=function() return false end
isClient=function() return false end
getTimestamp=function() return 1000 end
Events=setmetatable({},{__index=function(t,k) t[k]={handlers={},Add=function(f) table.insert(t[k].handlers,f) end}; return t[k] end})
WTAGarou=WTAGarou or {}
require "WTAGarouDefinitions"
-- minimal Slots.isQuadruped backed by a per-player form
WTAGarou.Slots=WTAGarou.Slots or {}
function WTAGarou.Slots.isQuadruped(p) return p and WTAGarou.GetForm(p.form).quadruped==true end
WTAGarou.HasGarouTrait=function(p) return p.garou~=false end
local flashed={}
WTAGarou.HUD={instance={flashDenial=function(_,r) flashed[#flashed+1]=r end}}
require "WTAGarouPawGuard"
local P=WTAGarou.Paws

local function player(form,opts) opts=opts or {} return {form=form,garou=opts.garou} end
check(P.isPaws(player("Hispo")) and P.isPaws(player("Lupus")),"Hispo and Lupus are paws")
check(not P.isPaws(player("Homid")) and not P.isPaws(player("Glabro")) and not P.isPaws(player("Crinos")),"two-legged forms keep their thumbs")
check(not P.isPaws(player("Hispo",{garou=false})) and not P.isPaws(nil),"non-Garou and nil are never paws")

-- build a fake vanilla environment of action classes
local env={}
local origCalls=0
for cls in pairs(P.BLOCKED_ACTIONS) do
    local klass={} klass.__index=klass
    function klass:isValid() origCalls=origCalls+1 return true end
    env[cls]=klass
end
env.ISFirearmRadialMenu={checkWeapon=function(p) return "orig" end}
env.ISReloadWeaponAction.BeginAutomaticReload=function(p,gun) return "reloaded" end
env.ISReloadWeaponAction.canShoot=function(p,gun) return "bang" end
env.ISEntityUI={OpenHandcraftWindow=function(p) return "crafting" end,OpenBuildWindow=function(p) return "build" end}
local blockedCount=0 for _ in pairs(P.BLOCKED_ACTIONS) do blockedCount=blockedCount+1 end
local wrapped=P.install(env)
check(wrapped==blockedCount+5,"every listed action plus radial, auto-reload, canShoot and two windows wrapped ("..wrapped..")")
check(P.install(env)==0,"install is idempotent")
local function act(cls,chr,fields) local o=setmetatable(fields or {},env[cls]); o.character=chr return o end

local wolf=player("Hispo"); local human=player("Homid"); local crinos=player("Crinos")
-- firearms: any and all reload actions
for _,cls in ipairs({"ISReloadWeaponAction","ISRackFirearm","ISInsertMagazine","ISEjectMagazine","ISLoadBulletsInMagazine","ISUnloadBulletsFromFirearm","ISUnloadBulletsFromMagazine","ISRemoveBullet","WTAGarouLoadSilverAction","WTAGarouLoadSilverMagazineAction"}) do
    flashed={}
    check(act(cls,wolf):isValid()==false and flashed[1]=="paws_firearm",cls.." refused for paws with firearm reason")
    check(act(cls,human):isValid()==true and act(cls,crinos):isValid()==true,cls.." untouched for Homid and Crinos")
end
flashed={}
check(env.ISFirearmRadialMenu.checkWeapon(wolf)==false and flashed[1]=="paws_firearm","firearm radial does not open for paws")
check(env.ISFirearmRadialMenu.checkWeapon(human)=="orig","firearm radial normal for Homid")
flashed={}
check(env.ISReloadWeaponAction.BeginAutomaticReload(wolf,{})==nil and flashed[1]=="paws_firearm","reload key refused for paws")
check(env.ISReloadWeaponAction.BeginAutomaticReload(human,{})=="reloaded","reload key normal for Homid")
flashed={}
check(env.ISReloadWeaponAction.canShoot(wolf,{})==false and flashed[1]=="paws_firearm","0.4.75: vanilla's attack hook asks canShoot before it plays the shot sound; paws get a dry click, no bang")
check(env.ISReloadWeaponAction.canShoot(human,{})=="bang" and env.ISReloadWeaponAction.canShoot(crinos,{})=="bang","Homid and Crinos shoot as before")

-- crafting / building / mechanics
local recipe=function(name) return {getName=function() return name end} end
flashed={}
check(act("ISHandcraftAction",wolf,{craftRecipe=recipe("MakeBarbedWire")}):isValid()==false and flashed[1]=="paws_craft","hand craft refused for paws")
check(act("ISCraftAction",wolf,{recipe=recipe("OpenCan")}):isValid()==false,"legacy craft refused for paws")
check(act("ISBuildIsoEntity",wolf):isValid()==false and act("ISDismantleAction",wolf):isValid()==false,"build and dismantle refused")
flashed={}
check(act("ISTakeGasolineFromVehicle",wolf):isValid()==false and flashed[1]=="paws_mechanic","siphoning refused with mechanic reason")
check(act("ISInstallVehiclePart",wolf):isValid()==false and act("ISOpenMechanicsUIAction",wolf):isValid()==false and act("ISRefuelFromGasPump",wolf):isValid()==false,"mechanics and fuel refused")
check(act("ISHandcraftAction",human,{craftRecipe=recipe("MakeBarbedWire")}):isValid()==true and act("ISTakeGasolineFromVehicle",crinos):isValid()==true,"Homid crafts, Crinos siphons")
flashed={}
check(env.ISEntityUI.OpenHandcraftWindow(wolf)==nil and env.ISEntityUI.OpenBuildWindow(wolf)==nil and #flashed==2,"crafting and build windows closed to paws (empty whitelist)")
check(env.ISEntityUI.OpenHandcraftWindow(human)=="crafting" and env.ISEntityUI.OpenBuildWindow(crinos)=="build","windows open for thumbs")

-- whitelist: the graceful valve
check(next(P.RECIPE_WHITELIST)==nil,"whitelist ships empty on purpose")
P.RECIPE_WHITELIST["OpenCan"]=true
flashed={}
check(act("ISCraftAction",wolf,{recipe=recipe("OpenCan")}):isValid()==true and #flashed==0,"whitelisted recipe passes for paws without a denial")
check(act("ISHandcraftAction",wolf,{craftRecipe=recipe("OpenCan")}):isValid()==true,"whitelist applies to hand crafting too")
check(act("ISHandcraftAction",wolf,{craftRecipe=recipe("MakeBarbedWire")}):isValid()==false,"other recipes still refused")
check(env.ISEntityUI.OpenHandcraftWindow(wolf)=="crafting","with a whitelist the crafting window opens so the allowed recipe can be reached")
check(act("ISTakeGasolineFromVehicle",wolf):isValid()==false,"whitelist never unlocks mechanics")
P.RECIPE_WHITELIST["OpenCan"]=nil
check(P.recipeName(act("ISHandcraftAction",wolf,{}))==nil and P.recipeName(nil)==nil,"missing recipe handled")

-- original isValid is still consulted for allowed cases
local before=origCalls
act("ISReloadWeaponAction",human):isValid()
check(origCalls==before+1,"allowed path reaches the vanilla isValid")

-- ---------------------------------------------------------------- jaws bite speed (0.4.58)
getPlayer=function() return nil end
require "WTAGarouCombatTiming"
local T=WTAGarou.CombatTiming
local function weapon(baseSpeed,twoHand,swing)
    local w={}
    function w:getBaseSpeed() return baseSpeed end
    function w:isTwoHandWeapon() return twoHand end
    function w:getSwingAnim() return swing end
    return w
end
local guitar=weapon(1.1,true,"Heavy")
local bat=weapon(1.0,true,"Bat")
local knife=weapon(1.0,false,"Stab")
local function chr(form,secondary) local c={form=form,secondary=secondary} function c:getSecondaryHandItem() return self.secondary end return c end
local hispo=chr("Hispo",guitar)
check(T.isJawAttack(hispo) and not T.isJawAttack(chr("Homid")),"jaw attack only for quadrupeds")
check(math.abs(T.weaponFactor(hispo,guitar)-1.1*1.2)<1e-6,"guitar factor: BaseSpeed 1.1 x heavy two-hander 1.2")
check(math.abs(T.weaponFactor(chr("Hispo",nil),guitar)-1.1*1.2*0.77)<1e-6,"one-handed two-hander penalty included")
local hispoBat=chr("Hispo",bat)
check(T.weaponFactor(hispoBat,bat)==1.0 and T.weaponFactor(hispo,knife)==1.0,"bat (in both jaws) and knife have no class factor")
-- vanilla hands us CombatSpeed already multiplied by the weapon factors
local vanillaGuitar=1.0*1.1*1.2
local vanillaBat=1.0
check(T.swingSpeed(vanillaGuitar,"Heavy")==1.51,"human Skully table would push the guitar to the 1.51 cap (unchanged for Homid)")
local biteG=T.biteSpeed(vanillaGuitar,guitar,hispo)
local biteB=T.biteSpeed(vanillaBat,bat,hispoBat)
check(math.abs(biteG-biteB)<1e-6 and math.abs(biteB-1.10)<1e-6,"bite speed is weapon-neutral: guitar == bat == 1.10")
check(biteG<vanillaGuitar,"bite normalisation lowers an inflated heavy value")
check(T.biteSpeed(0.6,guitar,hispo)<0.7 and T.biteSpeed(0,guitar,hispo)==0,"tired bites stay slow; zero passes through")
check(T.biteSpeed(5,bat,hispoBat)==1.11,"bite cap 1.11 like the generic row")
print("PASS: "..n.." paw-guard lockout/whitelist and jaws bite-speed assertions; not a controller playtest.")
