local root=assert(arg[1])
package.path=root.."/42/media/lua/shared/?.lua;"..package.path
require "WTAGarouDefinitions"
Events={OnGameStart={Add=function() end}}
require "WTAGarouClothing"
local checks=0
local function check(value,why) checks=checks+1; assert(value,why) end
local p={dropped=0}
function p:removeWornItem(item) self.dropped=self.dropped+1 end
function p:getInventory() return {Remove=function() end} end
function p:getCurrentSquare() return {AddWorldInventoryItem=function() end} end
local function item(loc)
    return {
        condition=10,
        getBodyLocation=function() return "base:"..loc end,
        getCondition=function(self) return self.condition end,
        setCondition=function(self,value) self.condition=value end,
    }
end
for _,loc in ipairs({"Hat","FullHat","Bandana","Headband","Mask","MaskEyes","MaskFull"}) do
    local hat=item(loc)
    local result,tore=WTAGarou.Clothing.applyProfile(p,hat,"Crinos",{forced=true})
    check(result==nil and not tore and hat.condition==10,"Crinos retains intact "..loc)
    check(not WTAGarou.Clothing.isShiftSafe(hat),"manual Strip remains available for "..loc)
    check(WTAGarou.CanWear("Crinos",hat),"Crinos can equip "..loc)
    for _,form in ipairs({"Lupus","Hispo"}) do
        result,tore=WTAGarou.Clothing.applyProfile(p,hat,form)
        check(result=="dropped" and not tore and hat.condition==10,form.." still drops "..loc)
    end
end
local jacket=item("Jacket")
local result,tore=WTAGarou.Clothing.applyProfile(p,jacket,"Crinos")
check(result=="dropped" and tore and jacket.condition==6,"ordinary Crinos body clothing still tears/drops")
local hood=item("SweaterHat")
check(WTAGarou.Clothing.applyProfile(p,hood,"Crinos")=="dropped","skinned sweater/hood policy unchanged")
print("PASS: "..checks.." Crinos headwear retention and other-form clothing checks.")
