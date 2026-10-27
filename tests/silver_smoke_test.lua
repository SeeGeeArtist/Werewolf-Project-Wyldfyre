-- 0.4.81: the silver smoke bomb (server/WTAGarouSilverSmoke.lua).
local root = assert(arg[1])
package.path = root .. "/42/media/lua/shared/?.lua;" .. root .. "/42/media/lua/server/?.lua;" .. root .. "/42/media/lua/client/?.lua;" .. package.path
local n = 0
local function check(ok, why) n = n + 1; assert(ok, why) end

isServer = function() return false end
isClient = function() return false end
getTimestamp = function() return 1000 end
Events = setmetatable({}, { __index = function(t, k) t[k] = { handlers = {}, Add = function(f) table.insert(t[k].handlers, f) end }; return t[k] end })
WTAGarou = WTAGarou or {}
require "WTAGarouDefinitions"
require "WTAGarouState"
WTAGarou.HasGarouTrait = function(p) return p.garou ~= false end
require "WTAGarouClothing"
require "WTAGarouGrant"

-- engine mocks
local hours = 100.0
getGameTime = function() return { getWorldAgeHours = function() return hours end } end
local blocked = {}                       -- "x:y" squares the line test cannot reach
local losCalls = 0
LosUtil = { lineClear = function(_, x0, y0, z0, x1, y1, z1) losCalls = losCalls + 1; return blocked[x1 .. ":" .. y1] or "Clear" end }
local cellSquares = {}
local function key(x, y, z) return x .. ":" .. y .. ":" .. z end
local function square(x, y, z)
    local s = { x = x, y = y, z = z or 0 }
    function s:getX() return self.x end
    function s:getY() return self.y end
    function s:getZ() return self.z end
    cellSquares[key(x, y, z or 0)] = s
    return s
end
getCell = function() return { getGridSquare = function(_, x, y, z) return cellSquares[key(x, y, z)] end } end
local function jlist(t) return { size = function() return #t end, get = function(_, i) return t[i + 1] end } end
local function part(name)
    local bp = { name = name, burn = 0 }
    function bp:getType() return self.name end
    function bp:getBurnTime() return self.burn end
    function bp:setBurnTime(v) self.burn = v end
    function bp:haveGlass() return false end
    function bp:haveBullet() return false end
    return bp
end
local function player(name, x, y, z, opts)
    opts = opts or {}
    local p = { name = name, x = x, y = y, z = z or 0, garou = opts.garou, worn = {}, md = { WTAGarou = { form = opts.form or "Crinos", isGarou = opts.garou ~= false } } }
    p.parts = { part("Neck"), part("Head"), part("Hand_L") }
    p.bd = { getBodyParts = function() return jlist(p.parts) end,
             getBodyPart = function(_, t) for _, bp in ipairs(p.parts) do if bp.name == t then return bp end end end }
    function p:getModData() return self.md end
    function p:getUsername() return self.name end
    function p:getBodyDamage() return self.bd end
    function p:getX() return self.x end
    function p:getY() return self.y end
    function p:getZ() return self.z end
    function p:getSquare() return cellSquares[key(math.floor(self.x), math.floor(self.y), self.z)] or square(math.floor(self.x), math.floor(self.y), self.z) end
    function p:getWornItems()
        local list = {}
        for _, it in ipairs(self.worn) do list[#list + 1] = { getItem = function() return it end } end
        return jlist(list)
    end
    function p:neck() return self.parts[1] end
    function p:head() return self.parts[2] end
    return p
end
-- 42.20.2 items: hasTag takes ItemTag objects (a String THROWS, 0.4.19 /
-- 0.4.83); getTags() is a Java Set of ItemTags whose toString is the
-- namespaced id ("base:gasmask").
local function jset(t)
    return { size = function() return #t end,
             iterator = function() local i = 0; return { hasNext = function() return i < #t end, next = function() i = i + 1; return t[i] end } end }
end
local function wornItem(tag)
    local tagObj = setmetatable({}, { __tostring = function() return "base:" .. tostring(tag):lower() end })
    return {
        hasTag = function(_, t) if type(t) == "string" then error("No implementation found for function: hasTag(Clothing, String)") end return false end,
        getTags = function() return jset({ tagObj }) end,
        getFullType = function() return "Base.X" end,
    }
end

WTAGarou.Silver = WTAGarou.Silver or {}
require "WTAGarouSilver"
local S = WTAGarou.Silver
local announced = {}
S.announce = function(p, label) announced[#announced + 1] = { p = p, label = label } end
local rage = {}
WTAGarou.AddRage = function(p, delta) rage[p.name] = (rage[p.name] or 0) + delta end
local coughs, veils = {}, {}
WTAGarou.SilverSmokeReact = function(p, args)
    veils[#veils + 1] = { p = p, seconds = args and args.seconds, cough = args and args.cough }
    if args == nil or args.cough == nil or args.cough == true then coughs[#coughs + 1] = { p = p, seconds = args and args.seconds } end
end
local scents = {}
WTAGarou.SilverScentReact = function(p) scents[#scents + 1] = p end

require "WTAGarouScatter"
local SC = WTAGarou.Scatter
local SM = require "WTAGarouSilverSmoke"
check(WTAGarou.SilverSmoke == SM and SM.step and SM.onExplode and SM.near, "module loaded")
check(#Events.OnThrowableExplode.handlers == 1 and Events.OnThrowableExplode.handlers[1] == SM.onExplode, "OnThrowableExplode registered")

-- scripts: item cloned from the vanilla bomb, recipe consumes a bomb + 10 filings uses
local items = assert(io.open(root .. "/42/media/scripts/silver_items.txt")):read("*a")
local body = items:match("item SilverSmokeBomb%s*{(.-)}")
check(body ~= nil, "item SilverSmokeBomb defined")
for _, f in ipairs({ "PhysicsObject = ExplosiveTrap", "SmokeRange = 5", "ExplosionDuration = 10", "WeaponSprite = SmokeBomb", "WorldStaticModel = SmokeBomb", "SwingAnim = Throw", "UseSelf = TRUE", "ItemType = base:weapon", "Icon = Smokebomb" }) do
    check(body:find(f, 1, true) ~= nil, "silver smoke bomb keeps the vanilla field: " .. f)
end
check(SM.DEFAULT_RADIUS == 5 and SM.DEFAULT_MINUTES == 10, "module defaults match the script")
local recipes = assert(io.open(root .. "/42/media/scripts/silver_recipes.txt")):read("*a")
local rec = recipes:match("craftRecipe WTAGarou_PackSilverSmokeBomb%s*{(.-)outputs")
check(rec and rec:find("item 1 [Base.SmokeBomb]", 1, true) and rec:find("item 10 [WTAGarou.SilverFilings]", 1, true), "recipe: one vanilla bomb and ten filings uses")
check(recipes:match("craftRecipe WTAGarou_PackSilverSmokeBomb.-outputs%s*{(.-)}"):find("WTAGarou.SilverSmokeBomb", 1, true), "recipe output is the silver bomb")
check(not (rec:find("SkillRequired", 1, true) or rec:find("NeedToBeLearn", 1, true)), "no skill or magazine gate on the repack")
local tr = assert(io.open(root .. "/42/media/lua/shared/Translate/EN/Recipes.json")):read("*a")
check(tr:find('"Recipe_WTAGarou_PackSilverSmokeBomb": "Pack Silver Filings into Smoke Bomb"', 1, true), "recipe name translated")
check(items:find("Tags = WTAGarouSilverSmoke", 1, true) and SC.workedSilver({ getFullType = function() return "WTAGarou.SilverSmokeBomb" end }), "the bomb in a bag smells like worked silver")
local A = require "WTAGarouSilverAmmo"
local line = (WTAGarou.SilverAmmo or A).tooltipLine({ getFullType = function() return "WTAGarou.SilverSmokeBomb" end })
check(type(line) == "string" and line:find("Silver dust", 1, true), "tooltip line for the bomb: " .. tostring(line))

-- the explosion: only our item registers a cloud
local function trap(full, x, y, z, r, minutes)
    return { getItem = function() return { getFullType = function() return full end } end,
             getSmokeRange = function() return r end, getExplosionDuration = function() return minutes end,
             getSquare = function() return square(x, y, z) end }
end
check(SM.onExplode(trap("Base.SmokeBomb", 50, 50, 0, 5, 10), square(50, 50, 0)) == nil and #SM.clouds == 0, "a vanilla smoke bomb leaves no silver dust")
local cloud = SM.onExplode(trap(SM.ITEM, 50, 50, 0, 5, 10), square(50, 50, 0))
check(cloud and #SM.clouds == 1 and cloud.x == 50 and cloud.y == 50 and cloud.z == 0 and cloud.r == 5, "our bomb registers a cloud at the square with SmokeRange")
check(math.abs(cloud.untilHours - (hours + 10 / 60)) < 1e-6, "the cloud lasts ExplosionDuration game minutes")
check(SM.onExplode(trap(SM.ITEM, 70, 70, 1, 0, 0), square(70, 70, 1)).r == 5 and SM.clouds[2].untilHours - hours > 0.16, "zero ranges fall back to the script defaults")
SM.clouds[2] = nil

-- geometry
check(SM.cloudAt(53, 54, 0) == cloud, "inside the radius (3,4 -> 5)")
check(SM.cloudAt(54, 54, 0) == nil, "outside the radius (4,4 -> 5.66)")
check(SM.cloudAt(50, 50, 1) == nil, "another floor")
blocked["52:50"] = "Blocked"
check(SM.cloudAt(52, 50, 0) == nil, "the engine's line test blocks a wall")
blocked["52:50"] = "ClearThroughClosedDoor"
check(SM.cloudAt(52, 50, 0) == nil, "a closed door keeps the dust out")
blocked["52:50"] = "ClearThroughOpenDoor"
check(SM.cloudAt(52, 50, 0) == cloud, "an open door lets it through")
blocked["52:50"] = nil
check(SM.cloudAt(56, 50, 0, nil, 2) == cloud and SM.near(square(56, 50, 0), 0) == true and SM.near(square(58, 50, 0), 0) == false, "the scent reaches SCENT_EXTRA past the smoke edge")

-- breathing: burn on the face (Head), Rage, cough cues, veil cue every sweep, scent
check(SM.BREATH_PARTS[1] == "Head" and SM.BREATH_PARTS[2] == "Neck" and #SM.BREATH_PARTS == 2 and SM.BREATH_LABEL == "face and throat", "0.4.94: the dust burns the Head and Neck parts, called the face and throat")
local g = player("Garou", 51.5, 50.5, 0)
local r1 = SM.step(g, WTAGarou.GetData(g), g.bd, 2)
check(r1 == cloud, "a Garou in the smoke breathes dust")
check(g:head().burn > 0 and WTAGarou.GetData(g).silverBurns and WTAGarou.GetData(g).silverBurns["Head"], "silver burn on the Head, flagged as silver")
check(g:neck().burn > 0 and WTAGarou.GetData(g).silverBurns["Neck"], "0.4.94: silver burn on the Neck too, flagged as silver")
check(#announced == 1 and announced[1].label == SM.BREATH_LABEL, "announced once, as the face and throat")
check(math.abs((rage.Garou or 0) - SM.RAGE_PER_SECOND * 2) < 1e-6, "Rage per second in the dust")
check(#coughs == 1 and coughs[1].seconds == 2 and veils[1].cough == true, "first breath coughs")
SM.step(g, WTAGarou.GetData(g), g.bd, 2)
check(#coughs == 1 and #announced == 1, "no second cough or announcement inside the gap")
check(#veils == 2 and veils[2].cough == false and veils[2].seconds == 4, "but every sweep in the dust sends the veil cue with cough=false")
SM.step(g, WTAGarou.GetData(g), g.bd, 3)
check(#coughs == 2 and #veils == 3, "the next cough after COUGH_GAP seconds")
check(g:head().burn >= 2, "the burn is at least the initial silver burn while breathing: " .. tostring(g:head().burn))
check(SC.smell(g, "Homid") == true, "the sniffer smells the dust")

local h = player("Human", 51.5, 50.5, 0, { garou = false })
local d = WTAGarou.GetData(h)
S.scan(h, 2)
check(h:head().burn == 0 and not rage.Human, "a human breathes ordinary smoke")

local far = player("Far", 60.5, 50.5, 0)
local veilsBefore = #veils
check(SM.step(far, WTAGarou.GetData(far), far.bd, 2) == nil and far:head().burn == 0 and #veils == veilsBefore, "outside the cloud: nothing, no veil cue")

local masked = player("Masked", 50.5, 51.5, 0)
masked.worn = { wornItem("GasMask") }
check(SM.itemIsMask(masked.worn[1]) == true, "a GasMask tag is found through getTags() names, never hasTag(String)")
check(SM.step(masked, WTAGarou.GetData(masked), masked.bd, 2) == nil and masked:head().burn == 0, "a gas mask keeps the dust out")
masked.worn = { wornItem("ImprovisedGasMask") }
check(SM.step(masked, WTAGarou.GetData(masked), masked.bd, 2) == nil and masked:head().burn == 0, "an improvised gas mask too")
masked.worn = { wornItem("GasMaskNoFilter") }
check(SM.step(masked, WTAGarou.GetData(masked), masked.bd, 2) == cloud, "a gas mask with no filter does not")
masked.worn = { wornItem("IsLowerDisguise") }
check(SM.step(masked, WTAGarou.GetData(masked), masked.bd, 2) == cloud, "a bandana is not a gas mask")

-- the sweep hook in Silver.scan reaches the smoke step
local g2 = player("Garou2", 49.5, 49.5, 0)
S.scan(g2, 2)
check(g2:head().burn > 0, "Silver.scan runs the smoke step")

-- expiry
hours = hours + 11 / 60
check(SM.step(g, WTAGarou.GetData(g), g.bd, 2) == nil and #SM.clouds == 0 and WTAGarou.GetData(g).silverSmokeSeconds == nil, "after ExplosionDuration the cloud is gone")
check(SC.smell(g, "Homid") == false, "and it no longer smells")

print("PASS: " .. n .. " silver smoke bomb assertions.")
