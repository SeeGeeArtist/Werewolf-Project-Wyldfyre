-- API-shaped Lua mocks, not proof of engine door-edge or curtain behaviour.
local root = assert(arg[1])
local checks = 0
local function check(ok, why) checks = checks + 1; assert(ok, why) end
local function close(a, b, why) check(math.abs(a-b) < 0.000001, why) end
require = function() end
dofile(root .. "/42/media/lua/shared/WTAGarouDefinitions.lua")
dofile(root .. "/42/media/lua/shared/WTAGarouResolve.lua")
local moon, night, cloud, fog = 0.7, 1, 0, 0
getClimateMoon = function() return {getMoonFloat=function() return moon end} end
getClimateManager = function() return {
    getNightStrength=function() return night end,
    getCloudIntensity=function() return cloud end,
    getFogIntensity=function() return fog end,
} end
local grid = {}
IsoFlagType = {DoorWallN="DoorWallN", DoorWallW="DoorWallW"}
local function key(x,y,z) return x..","..y..","..z end
local cell = {getGridSquare=function(_,x,y,z) return grid[key(x,y,z)] end}
local function square(x,y,z,outside)
    local s = {outside=outside, roof=not outside, windows={}, doors={}, flags={}, blocked={}}
    function s:isOutside() return self.outside end
    function s:haveRoofFull() return self.roof end
    function s:getX() return x end
    function s:getY() return y end
    function s:getZ() return z end
    function s:getCell() return cell end
    function s:getWindowTo(other) return self.windows[other] end
    function s:getDoorTo(other) return self.doors[other] end
    function s:getProperties()
        return {has=function(_, flag) return self.flags[flag] == true end}
    end
    function s:isBlockedTo(other) return self.blocked[other] == true end
    grid[key(x,y,z)] = s
    return s
end
local function setFrame(s, other, present)
    local dx, dy = other:getX()-s:getX(), other:getY()-s:getY()
    local owner = (dx > 0 or dy > 0) and other or s
    owner.flags[dx == 0 and IsoFlagType.DoorWallN or IsoFlagType.DoorWallW] = present
end
local inside = square(0,0,0,false)
local p = {square=inside}
function p:getSquare() return self.square end
function p:isOutside() return true end -- tile result must take precedence
local neighbours = {square(0,-1,0,true), square(1,0,0,true),
    square(0,1,0,true), square(-1,0,0,true)}
local w = {barricaded=false}
function w:isBarricaded() return self.barricaded end
function w:HasCurtains() return self.curtain end
local curtain = {open=false, isCurtainOpen=function(self) return self.open end}
local door = {open=false, barricaded=false}
function door:IsOpen() return self.open end
function door:isBarricaded() return self.barricaded end
local function exposure(expected, why) close(WTAGarou.MoonLightExposure(p), expected, why) end
exposure(0, "a wall beside outside is not an opening")
-- A frame on another edge of the adjacent tile cannot expose this edge.
neighbours[1].flags[IsoFlagType.DoorWallN] = true
neighbours[2].flags[IsoFlagType.DoorWallN] = true
exposure(0, "north/west edge ownership rejects adjacent unrelated frames")
neighbours[1].flags = {}; neighbours[2].flags = {}
for i, other in ipairs(neighbours) do
    inside.windows[other] = w
    exposure(1, "uncovered window on cardinal edge "..i)
    other.roof = true
    exposure(0, "window onto covered porch does not expose edge "..i)
    other.roof = false
    -- Window open/closed is deliberately irrelevant: intact glass transmits.
    w.curtain = curtain; curtain.open = false
    exposure(0, "closed curtain blocks edge "..i)
    curtain.open = true
    exposure(1, "drawn-back curtain exposes edge "..i)
    w.barricaded = true
    exposure(0, "any barricade conservatively blocks edge "..i)
    w.barricaded = false; w.curtain = nil
    other.outside = false
    exposure(0, "an interior-to-interior window does not expose")
    other.outside = true; inside.windows[other] = nil
    inside.doors[other] = door
    door.open = false; exposure(0, "closed exterior door blocks")
    door.open = true; exposure(1, "open exterior door exposes edge "..i)
    other.roof = true
    exposure(0, "open door onto covered porch does not expose edge "..i)
    other.roof = false
    door.barricaded = true; exposure(0, "barricaded door blocks")
    door.barricaded = false; other.outside = false
    exposure(0, "open interior door does not expose")
    other.outside = true; inside.doors[other] = nil
end
-- Empty exterior doorways. Keep the frame when removing a door, and
-- resample current geometry rather than retaining exposure from history.
for i, other in ipairs(neighbours) do
    setFrame(inside, other, true)
    exposure(1, "bare exterior door frame exposes cardinal edge "..i)
    other.roof = true
    exposure(0, "bare frame onto covered porch does not expose edge "..i)
    other.roof = false
    inside.doors[other] = door; door.open = false
    exposure(0, "closed door takes precedence over its frame "..i)
    inside.doors[other] = nil
    exposure(1, "removed exterior door leaves exposed frame "..i)
    other.roof = true
    exposure(0, "removed door onto covered porch does not expose edge "..i)
    other.roof = false
    inside.blocked[other] = true
    exposure(0, "blocked empty doorway does not expose "..i)
    inside.blocked[other] = nil; other.blocked[inside] = true
    exposure(0, "opposite-side obstruction also blocks empty frame "..i)
    other.blocked[inside] = nil; other.outside = false
    exposure(0, "bare interior-to-interior frame does not expose "..i)
    other.outside = true
    inside.doors[other] = door; door.open = true; door.barricaded = true
    exposure(0, "frame cannot bypass a replacement door barricade "..i)
    door.barricaded = false
    exposure(1, "opening replacement door restores ordinary door rule "..i)
    inside.doors[other] = nil
    WTAGarou.MoonLight.OPENINGS = false
    exposure(0, "openings switch also disables empty door frames")
    WTAGarou.MoonLight.OPENINGS = true
    setFrame(inside, other, nil)
    exposure(0, "no recognised frame means no inferred doorway")
end
setFrame(inside, neighbours[1], true)
night = 0; exposure(0.5, "empty doorway keeps daytime half strength")
cloud = 0.5; exposure(0.25, "empty doorway still obeys weather")
night, cloud = 1, 0
local getFrame = inside.getProperties
inside.getProperties = nil
exposure(0, "missing frame API fails closed")
inside.getProperties = getFrame
local blockedTo = inside.isBlockedTo
inside.isBlockedTo = function() error("unavailable collision state") end
exposure(0, "failed collision API fails closed")
inside.isBlockedTo = blockedTo
setFrame(inside, neighbours[1], nil)
inside.windows[square(1,1,0,true)] = w
inside.windows[square(0,0,1,true)] = w
inside.windows[square(2,0,0,true)] = w
grid[key(1,1,0)].flags[IsoFlagType.DoorWallN] = true
grid[key(0,0,1)].flags[IsoFlagType.DoorWallN] = true
grid[key(2,0,0)].flags[IsoFlagType.DoorWallW] = true
exposure(0, "diagonal, upstairs and two tiles away never count")
inside.windows[neighbours[1]] = w
WTAGarou.MoonLight.OPENINGS = false
exposure(0, "openings switch restores outside-only rule")
WTAGarou.MoonLight.OPENINGS = true
night = 0; exposure(0.5, "window at noon keeps half the moon pull")
cloud = 0.5; exposure(0.25, "window still affected by cloud")
fog = 0.5; exposure(0.125, "window still affected by fog")
moon = 0; exposure(0, "new moon gives no bonus at the window")
moon, night, cloud, fog = 0.7, 1, 0, 0
w.HasCurtains = function() error("missing engine support") end
exposure(0, "failed edge API is not treated as open")
inside.doors[neighbours[2]] = door
exposure(1, "failed north edge does not hide a valid east edge")
inside.windows = {}; inside.doors = {}
p.square = neighbours[1]
exposure(1, "outside stays exposed without openings")
p.square.roof = true
exposure(0, "standing on a roofed exterior porch gives no exposure")
local porchData = {moonExposure=1}
WTAGarou.UpdateMoonExposure(p, porchData)
close(porchData.moonExposure, 0, "stepping under porch roof clears old exposure")
close(WTAGarou.EffectiveBaselineRage(porchData), 50, "porch roof removes moon baseline bonus")
p.square.roof = false
exposure(1, "stepping out from under roof restores exposure")
local roofCheck = p.square.haveRoofFull
p.square.haveRoofFull = nil
exposure(0, "missing roof API cannot grant direct outdoor exposure")
p.square.haveRoofFull = function() return nil end
exposure(0, "unknown roof result cannot grant direct outdoor exposure")
p.square.haveRoofFull = function() error("roof state unavailable") end
exposure(0, "failed roof API cannot grant direct outdoor exposure")
p.square.haveRoofFull = roofCheck
p.square = nil
exposure(0, "player outside flag alone never bypasses a missing tile")
p.square = inside
setFrame(inside, neighbours[1], true)
local otherRoofCheck = neighbours[1].haveRoofFull
neighbours[1].haveRoofFull = nil
exposure(0, "missing neighbour roof API cannot grant doorway exposure")
neighbours[1].haveRoofFull = function() return nil end
exposure(0, "unknown neighbour roof state cannot grant doorway exposure")
neighbours[1].haveRoofFull = otherRoofCheck
exposure(1, "roofed indoor tile can still see an opening onto unroofed outside")
setFrame(inside, neighbours[1], nil)
p.square = neighbours[1]
WTAGarou.MoonLight.ENABLED = false
exposure(0, "disabled moon reads zero")
WTAGarou.MoonLight.ENABLED = true
getClimateManager = nil
exposure(0, "missing climate fails to no bonus")

for _, a in ipairs(WTAGarou.Auspices) do
    local d = {auspice=a.key, auspiceLocked=true}
    for _, e in ipairs({0, 0.125, 0.5, 1}) do
        d.moonExposure = e
        close(WTAGarou.BaselineRage(d), a.baseline, "Startup baseline never changes")
        close(WTAGarou.EffectiveBaselineRage(d), a.baseline + 15*e, "effective baseline follows exposure")
        check(d.auspice == a.key and d.auspiceLocked, "saved identity untouched")
    end
end
local d = {moonExposure=1}
close(WTAGarou.EffectiveBaselineRage(d), 65, "unselected default baseline + exposure")
WTAGarou.UpdateMoonExposure(p, d)
close(d.moonExposure, 0, "missing climate overwrites stale exposure")
close(WTAGarou.EffectiveBaselineRage(d), 50, "zero removes bonus")
d.moonExposure = 0/0
close(WTAGarou.EffectiveBaselineRage(d), 50, "NaN exposure cannot corrupt Rage")
d.moonExposure = 10
close(WTAGarou.EffectiveBaselineRage(d), 65, "exposure capped at one")
d.moonExposure = -1
close(WTAGarou.EffectiveBaselineRage(d), 50, "negative exposure capped at zero")
-- Requested balance examples: admission uses actual Rage, not the target.
check(WTAGarou.MoonLight.BASELINE_BONUS == 15, "maximum moon baseline bonus is 15")
local ahroun = {auspice="Ahroun", auspiceLocked=true, moonExposure=1}
close(WTAGarou.EffectiveBaselineRage(ahroun), 85, "Ahroun reaches an 85 target")
local theurge = {auspice="Theurge", auspiceLocked=true, moonExposure=1, form="Homid", trueForm="Homid"}
theurge.rage = WTAGarou.EffectiveBaselineRage(theurge)
local allowed, reason, info = WTAGarou.ShiftAdmission(theurge, "Crinos", 0)
check(theurge.rage == 55 and allowed and info.bufferSeconds == 0, "Theurge at 55: no buffer penalty at Resolve 0")
close(WTAGarou.ShiftSeconds(theurge, "Crinos", {exposure=1, resolveLevel=0}), 0.75,
    "Theurge still channels: 1 s snap reduced 25 percent at full exposure")
theurge.rage = 40
check(not WTAGarou.ShiftAdmission(theurge, "Crinos", 0), "moon target alone does not grant current Rage or admission")
local ragabash = {auspice="Ragabash", auspiceLocked=true, moonExposure=1, form="Homid", trueForm="Homid"}
ragabash.rage = WTAGarou.EffectiveBaselineRage(ragabash)
check(ragabash.rage == 45, "Ragabash full-exposure target is 45")
for level=0,3 do
    check(not WTAGarou.ShiftAdmission(ragabash, "Crinos", level), "Ragabash at 45 is short of the window at Resolve "..level)
end
allowed, reason, info = WTAGarou.ShiftAdmission(ragabash, "Crinos", 4)
check(allowed and info.shortfall == 10 and info.width == 10 and info.bufferSeconds == 6,
    "Ragabash at 45 needs Resolve 4: ten-point window, six-second penalty")
close(WTAGarou.ShiftSeconds(ragabash, "Crinos", {exposure=1, resolveLevel=4}), 6.75,
    "Ragabash total is 0.75 s body plus six-second penalty, not six seconds total")
print("PASS: "..checks.." moon exposure / baseline assertions.")
