-- 0.4.43: Lupus drives like a drunk (Build 42 CharacterStat.INTOXICATION,
-- 0..100; DRUNK moodle thresholds 10/30/50/70; CarController reads the
-- driver's DRUNK moodle). Fixtures shaped like B42.21 Stats / BaseVehicle.
local root=assert(arg[1])
package.path=root.."/42/media/lua/shared/?.lua;"..root.."/42/media/lua/client/?.lua;"..package.path
local n=0
local function check(ok,why) n=n+1; assert(ok,why) end
isServer=function() return false end
isClient=function() return false end
getTimestamp=function() return 1000 end
local handlers={}
Events=setmetatable({},{__index=function(t,k) t[k]={Add=function(fn) handlers[k]=fn end}; return t[k] end})
WTAGarou=WTAGarou or {}
require "WTAGarouDefinitions"
WTAGarou.HasGarouTrait=function(p) return p.garou~=false end
CharacterStat={INTOXICATION="INTOXICATION"}
MoodleType={DRUNK="DRUNK"}
local function player(form)
    local p={form=form,md={WTAGarou={isGarou=true,form=form}},intox=0}
    p.statsObj={get=function(_,stat) assert(stat=="INTOXICATION"); return p.intox end,
        set=function(_,stat,v) assert(stat=="INTOXICATION"); p.intox=v end}
    function p:getStats() return self.statsObj end
    function p:getModData() return self.md end
    function p:isDead() return self.dead==true end
    function p:isLocalPlayer() return true end
    function p:getVehicle() return self.vehicle end
    function p:getMoodles() return {getMoodleLevel=function(_,t)
        local v=p.intox; return v>=70 and 4 or v>=50 and 3 or v>=30 and 2 or v>=10 and 1 or 0 end} end
    return p
end
local DD=require "WTAGarouDrunkDriving"
check(handlers.OnPlayerUpdate==DD.update,"runs on player update (not the old in-game-minute poll)")

-- The old code's API is gone in B42: no get/setDrunkenness on Stats.
local src=io.open(root.."/42/media/lua/client/WTAGarouDrunkDriving.lua"):read("*a")
check(src:find("CharacterStat.INTOXICATION",1,true),"uses the B42 CharacterStat.INTOXICATION stat")

check(DD.levelFor("Lupus")==65 and DD.levelFor("Hispo")==55,"drunkDriving forms have a 0..100 level")
check(DD.levelFor("Homid")==nil and DD.levelFor("Glabro")==nil and DD.levelFor("Crinos")==nil,"hands-having forms drive sober")

local wolf=player("Lupus")
wolf.intox=5
local car={}; function car:getDriver() return self.driver end
wolf.vehicle=car; car.driver=wolf
check(DD.update(wolf)=="drunk" and wolf.intox==65 and wolf.md.WTAGarou_SavedDrunk==5,"Lupus at the wheel: intoxication held at 65, real value saved")
check(wolf:getMoodles():getMoodleLevel("DRUNK")==3,"65 lands in DRUNK moodle level 3 (car controller swerves above 1)")
wolf.intox=60
for _=1,DD.REAPPLY_UPDATES do DD.update(wolf) end
check(wolf.intox==65,"natural decay is topped back up while driving")
wolf.intox=90
for _=1,DD.REAPPLY_UPDATES do DD.update(wolf) end
check(wolf.intox==90,"an actually drunker wolf is never sobered up by the effect")
wolf.intox=65
car.driver={}
check(DD.update(wolf)=="sober" and wolf.intox==5 and not wolf.md.WTAGarou_DrunkDriveActive,"passenger seat: sober again, real value restored")
check(DD.update(wolf)==nil,"nothing to do as a passenger")
car.driver=wolf; DD.update(wolf)
wolf.vehicle=nil
check(DD.update(wolf)=="sober" and wolf.intox==5,"leaving the car restores")

-- Shifting while driving.
wolf.vehicle=car; car.driver=wolf; DD.update(wolf)
wolf.md.WTAGarou.form="Homid"
check(DD.update(wolf)=="sober" and wolf.intox==5,"shift to Homid at the wheel: sober immediately")
wolf.md.WTAGarou.form="Glabro"
check(DD.update(wolf)==nil and wolf.intox==5,"Glabro drives sober")
wolf.md.WTAGarou.form="Lupus"; DD.update(wolf)
check(wolf.intox==65,"back to Lupus at the wheel: drunk again")

-- Save caught mid-drive, then loaded on foot.
local loaded=player("Lupus"); loaded.intox=65
loaded.md.WTAGarou_DrunkDriveActive=true; loaded.md.WTAGarou_SavedDrunk=12
check(DD.update(loaded)=="sober" and loaded.intox==12,"a save taken mid-drive is cleaned up on foot")

-- Non-Garou, remote and dead players untouched.
local human=player("Lupus"); human.garou=false; human.vehicle=car; car.driver=human
check(DD.update(human)==nil and human.intox==0,"non-Garou unaffected")
local remote=player("Lupus"); function remote:isLocalPlayer() return false end; remote.vehicle=car; car.driver=remote
check(DD.update(remote)==nil and remote.intox==0,"remote players are not touched locally")
local dead=player("Lupus"); dead.vehicle=car; car.driver=dead; DD.update(dead); dead.dead=true
check(DD.update(dead)=="sober" and dead.intox==0,"death restores")

-- Lupus is not a bulk form, so it can still get into the driver seat.
check(not WTAGarou.IsBulkForm("Lupus") and WTAGarou.IsBulkForm("Hispo") and WTAGarou.IsBulkForm("Crinos"),"Lupus may enter vehicles; Hispo/Crinos may not")
print("PASS: "..n.." Lupus drunk-driving assertions.")
