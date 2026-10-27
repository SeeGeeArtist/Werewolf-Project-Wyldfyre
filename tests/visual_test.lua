-- Lua 5.1 mocks: tests our flow, not PZ's Java/Lua bindings or asset loader.
local root = assert(arg[1], "supply WTAGarou directory")
package.path = root .. "/42/media/lua/shared/?.lua;" .. root .. "/42/media/lua/client/?.lua;" .. package.path
Events = {}
for _, name in ipairs({"OnCreatePlayer", "OnPlayerUpdate", "OnPlayerDeath", "OnNewGame"}) do
    Events[name] = { handlers = {} }
    Events[name].Add = function(fn) table.insert(Events[name].handlers, fn) end
end
local checks = 0
local function check(ok, message)
    checks = checks + 1
    assert(ok, message)
end
local typedSlot = {}
CharacterTrait = { register = function(id) return id end }
local registeredTags = {}
ItemTag = {
    register = function(id) assert(not registeredTags[id], "duplicate tag " .. id); registeredTags[id] = id; return id end,
    get = function(loc) return registeredTags[loc] end,
}
ResourceLocation = { of = function(id) return id end }
ItemBodyLocation = { register = function(id)
    check(id == "wtagarou:saddlebag", "namespaced slot")
    return typedSlot
end }
BodyLocations = { getGroup = function() return {
    getOrCreateLocation = function(_, slot) check(slot == typedSlot, "typed slot, no string") end
} end }
dofile(root .. "/42/media/registries.lua")
local javaScales, javaCalls, fur = {}, 0, {}
local crowd, crowdCalls = {}, 0
WTAGarouJava = {
    setScale = function(player, value)
        javaCalls = javaCalls + 1
        javaScales[player] = value
        return true
    end,
    clear = function(player) javaScales[player] = nil; fur[player] = nil end,
    setFurInsulation = function(player,value) fur[player]=value; return true end,
    -- 0.4.69: crowd charge per form (limit 0 clears)
    setCrowdCharge = function(player, limit, window) crowd[player] = { limit, window }; crowdCalls = crowdCalls + 1; return true end,
    status = function() return "mock" end,
}
local function player(garou)
    local p = { data = { WTAGarou = { form = "Homid", isGarou = garou } }, resets = 0 }
    local v = { skin = "OriginalSkin" }
    function v:getForceModelScript() return self.model end
    function v:getSkinTextureName() return self.skin end
    function v:setForceModelScript(value) self.model = value end
    function v:setSkinTextureName(value) self.skin = value end
    function p:getModData() return self.data end
    function p:getHumanVisual() return v end
    function p:isDead() return self.dead end
    function p:isFemale() return self.female end
    function p:resetModelNextFrame() self.resets = self.resets + 1 end
    function p:getOnlineID() return -1 end
    return p
end
dofile(root .. "/42/media/lua/client/WTAGarouVisual.lua")
local p, p2, normal = player(true), player(true), player(false)
getPlayer = function() return p end
local refresh = WTAGarou.Visual.refresh
for _, row in ipairs({{"Homid",1},{"Glabro",1.24},{"Crinos",1.65},{"Hispo",1.55},{"Lupus",1.15}}) do
    p.data.WTAGarou.form = row[1]
    refresh(p, false)
    check(javaScales[p] == row[2], row[1] .. " scale")
    check(fur[p]==((row[1]=="Homid" or row[1]=="Glabro") and 0 or 0.5),row[1].." fur insulation pushed")
    check(p:getHumanVisual().model == nil, "default no mesh swap")
    -- 0.4.69: only the Berzerker charges crowds (3 knockdowns per 3 s)
    local rule = crowd[p]
    if row[1] == "Crinos" then check(rule[1] == 3 and rule[2] == 3.0, "Crinos crowd charge 3 per 3 s pushed")
    else check(rule[1] == 0 and rule[2] == 0, row[1] .. " clears the crowd charge") end
end
local count, crowdCount = javaCalls, crowdCalls
for _ = 1,100 do refresh(p, false) end
check(javaCalls == count, "no repeated Java setter on unchanged form")
check(crowdCalls == crowdCount, "crowd-charge rule pushed once per form change")
p2.data.WTAGarou.form = "Crinos"
refresh(p2, false)
check(javaScales[p2] == 1.65 and javaScales[p] == 1.15, "distinct objects with same onlineID")
refresh(normal, false)
check(javaScales[normal] == nil, "non-Garou no scaling")
check(fur[normal]==nil,"ordinary character has no fur profile")
WTAGarouTestWolfMesh(true)
check(p:getHumanVisual().model == "WTAGarou_Lupus", "explicit wolf probe")
check(p:getHumanVisual().skin == "WTAGarou_Wolf", "wolf texture")
WTAGarouTestWolfMesh(false)
check(p:getHumanVisual().model == nil, "disable clears wolf")
check(p:getHumanVisual().skin == "OriginalSkin", "restore original skin")
p.dead = true
refresh(p, false)
check(javaScales[p] == nil, "death clears scale")
check(fur[p]==nil,"death clears fur")
p.dead = false
p.data.WTAGarou.form = "Crinos"
refresh(p, true)
p.data.WTAGarou.isGarou = false
refresh(p, false)
check(javaScales[p] == nil, "trait loss clears")
check(fur[p]==nil,"trait loss clears fur")
local savedJava = WTAGarouJava
WTAGarouJava = nil
p.data.WTAGarou.isGarou = true
refresh(p, true)
check(p:getHumanVisual().model == nil, "missing Java safe")
WTAGarouJava = savedJava
refresh(p, false)
check(javaScales[p] == 1.65, "Java availability recovers")
WTAGarou.EnableJavaScale = false
refresh(p, false)
check(javaScales[p] == nil, "disabling scaling clears")

-- This build does NOT expose getForceModelScript. Default mesh-off code
-- must not call it; a pcall returning false is not a successful test.
local realPrint, logCount = print, 0
print = function() logCount = logCount + 1 end
p:getHumanVisual().getForceModelScript = nil
for _ = 1,5 do refresh(p, true) end
check(logCount == 0, "mesh-off refresh does not probe unavailable getter")
WTAGarouTestWolfMesh(true)
check(p:getHumanVisual().model == nil, "missing getter refuses unsafe wolf probe")
WTAGarouTestWolfMesh(false)
print = realPrint

-- Invalid starting item type must never reach AddItem.
ItemType = { CONTAINER = "container" }
local adds, validType = 0, false
getScriptManager = function() return { FindItem = function() return {
    isItemType = function() return validType end
} end } end
local inv = {}
function inv:getItems() return { size = function() return 0 end } end
function inv:AddItem() adds = adds + 1; return {} end
function p:getInventory() return inv end
dofile(root .. "/42/media/lua/client/WTAGarouStartingItems.lua")
Events.OnNewGame.handlers[1](p)
check(adds == 0, "invalid container skipped before construction")
p.data.WTAGarou_StartingGearGranted = nil
validType = true
Events.OnNewGame.handlers[1](p)
check(adds == 0, "0.4.22: the Wolf Panniers container is retired; nothing is granted")
check(p.data.WTAGarou_StartingGearGranted == true, "grant flag still set so old logic stays idempotent")
print("PASS: " .. checks .. " Lua assertions.")
