-- 0.4.68: Crinos door charge (server) and the client relay. Loads the real
-- definitions, state, server and client doorway files against small mocks.
local root = arg[1] or "."
local checks = 0
local function check(v, why) checks = checks + 1; if not v then error("FAIL: " .. why, 2) end end
local function close(a, b, why) check(math.abs(a - b) < 1e-6, why .. ": " .. tostring(a) .. " != " .. tostring(b)) end

local clock = 1000.0
getTimestamp = function() return math.floor(clock) end
getTimestampMs = function() return clock * 1000 end
isClient = function() return false end
isServer = function() return false end
Events = setmetatable({}, { __index = function(t, k)
    t[k] = { handlers = {}, Add = function(f) table.insert(t[k].handlers, f) end }; return t[k] end })
ZombRand = function() return 0 end
getGameTime = function() return { getWorldAgeHours = function() return 1 end } end
function require(_) end
MoodleType = {}
CharacterStat = { ENDURANCE = "Endurance", ZOMBIE_INFECTION = "ZombieInfection", ZOMBIE_FEVER = "ZombieFever" }
instanceof = function(o, cls) return type(o) == "table" and o.__class == cls end

local sent = {}
WTAGarou = WTAGarou or {}
WTAGarou.Net = {
    ToClient = function(p, cmd, args) table.insert(sent, { cmd = cmd, args = args }) end,
    ToServer = function(p, cmd, args) table.insert(sent, { cmd = "->" .. cmd, args = args }) end,
    RegisterClientHandler = function() end, RegisterServerHandler = function() end,
    Broadcast = function() end, IsSinglePlayer = function() return true end,
}
local function lastOf(cmd) for i = #sent, 1, -1 do if sent[i].cmd == cmd then return sent[i].args end end end

-- world: one square with a wooden door on its north edge
local squares = {}
local function square(x, y, z)
    local key = x .. "," .. y .. "," .. z
    if not squares[key] then
        local objs = {}
        squares[key] = { x = x, y = y, z = z, objs = objs,
            getX = function() return x end, getY = function() return y end, getZ = function() return z end,
            getObjects = function() return { size = function() return #objs end, get = function(_, i) return objs[i + 1] end } end }
    end
    return squares[key]
end
getCell = function() return { getGridSquare = function(_, x, y, z) return squares[x .. "," .. y .. "," .. z] end } end
local function newDoor(sq, opts)
    opts = opts or {}
    local d = { __class = "IsoDoor", health = 100, thumps = 0, open = opts.open or false, locked = opts.locked or false,
        prefix = opts.prefix or "WoodDoor", barricaded = opts.barricaded or false, north = opts.north ~= false, destroyed = false }
    function d:getSquare() return sq end
    function d:getNorth() return self.north end
    function d:isDestroyed() return self.destroyed end
    function d:IsOpen() return self.open end
    function d:isBarricaded() return self.barricaded end
    function d:getSoundPrefix() return self.prefix end
    function d:isLocked() return self.locked end
    function d:isLockedByKey() return false end
    function d:setHealth(h) self.health = h end
    function d:Thump(who, n) self.thumps = self.thumps + 1; self.thumper = who; if self.health <= 0 then self.destroyed = true end end
    table.insert(sq.objs, d)
    return d
end

local function newPlayer(x, y, z)
    local p = { md = {}, stats = { Endurance = 1.0 }, x = x, y = y, z = z or 0, moodles = {} }
    function p:getModData() return self.md end
    function p:getOnlineID() return 7 end
    function p:getUsername() return "chris" end
    function p:getX() return self.x end function p:getY() return self.y end function p:getZ() return self.z end
    function p:getStats() local st = self.stats; return { get = function(_, k) return st[k] end, set = function(_, k, v) st[k] = v end } end
    function p:getMoodles() return { getMoodleLevel = function() return 0 end } end
    function p:isDead() return false end
    function p:setSpeedMod() end
    function p:setVariable() end
    function p:isFemale() return false end
    function p:isLocalPlayer() return true end
    return p
end

dofile(root .. "/42/media/lua/shared/WTAGarouDefinitions.lua")
dofile(root .. "/42/media/lua/shared/WTAGarouState.lua")
WTAGarou.HasGarouTrait = function() return true end
WTAGarou.Slots = { enforce = function() end }
WTAGarou.CrinosBurst = { onCompleted = function() end, onRoar = function() end }
dofile(root .. "/42/media/lua/server/WTAGarouServer.lua")
local handler = Events.OnClientCommand.handlers[1]
check(type(handler) == "function", "server client-command handler wired")

-- ----------------------------------------------------------- definitions ----
check(WTAGarou.DoorCharge.RAGE == 12 and WTAGarou.DoorCharge.RAGE_LOCKED == 18, "12 Rage, 18 locked (0.4.69 +50%)")
close(WTAGarou.DoorCharge.STAMINA_LOCKED / WTAGarou.DoorCharge.STAMINA, 1.5, "locked stamina cost is relative (1.5x)")
check(WTAGarou.Rage.ON_HIT_DEALT < 0, "landing a hit spends Rage")
check(WTAGarou.FormData.Crinos.meleeDamage == 2.0 and WTAGarou.FormData.Glabro.meleeDamage == 1.5, "Crinos 2x melee (was 4x)")
check(WTAGarou.FormData.Crinos.modelScale == 1.65 and WTAGarou.Traits.Crinos.stride == 1.65, "1.65x model with matching stride (0.4.69)")
close(WTAGarou.Traits.Crinos.walk * WTAGarou.Traits.Crinos.stride, 1.3035, "net Crinos walk speed kept at 1.30")
close(WTAGarou.Traits.Crinos.sprint * WTAGarou.Traits.Crinos.stride, 1.2045, "net Crinos sprint kept at about 1.20")

-- ------------------------------------------------------------ the charge ----
local sq = square(10, 10, 0)
local door = newDoor(sq)
local p = newPlayer(10.5, 11.2)
local d = WTAGarou.GetData(p); d.isGarou = true; d.form = "Crinos"; d.rage = 60
WTAGarou.RefundEndurance(p, d)                   -- prime the refund baseline at 1.0
local args = { x = 10, y = 10, z = 0, north = true }

d.form = "Hispo"
handler("WTAGarou", "CrinosDoorCharge", p, args)
check(lastOf("DoorChargeResult").reason == "not_crinos" and door.thumps == 0, "only a Crinos charges")
d.form = "Crinos"
handler("WTAGarou", "CrinosDoorCharge", p, { x = 10, y = 10, z = 0, north = false })
check(lastOf("DoorChargeResult").reason == "no_door", "no door on that edge")
handler("WTAGarou", "CrinosDoorCharge", p, args)
local r = lastOf("DoorChargeResult")
check(r.reason == nil and r.locked == false, "wooden door charged: " .. tostring(r.reason))
check(door.health == 0 and door.thumps == 1 and door.destroyed and door.thumper == p, "door health zeroed and thumped by the player (vanilla break path)")
close(d.rage, 48, "12 Rage spent")
close(p.stats.Endurance, 0.85, "0.15 endurance spent")
WTAGarou.RefundEndurance(p, d)
close(p.stats.Endurance, 0.85, "the Crinos endurance refund does NOT hand the door cost back")
p.stats.Endurance = 0.75; WTAGarou.RefundEndurance(p, d)
close(p.stats.Endurance, 0.75 + 0.10 * 0.90, "ordinary exertion after the charge is still refunded at 0.90")

-- locked door: 18 Rage, 0.225 endurance
local sq2 = square(20, 20, 0); local locked = newDoor(sq2, { locked = true })
p.x, p.y = 20.5, 21.3; p.stats.Endurance = 1.0; WTAGarou.RefundEndurance(p, d)
d.rage = 17
handler("WTAGarou", "CrinosDoorCharge", p, { x = 20, y = 20, z = 0, north = true })
check(lastOf("DoorChargeResult").reason == "no_rage" and locked.thumps == 0, "17 Rage cannot smash a locked door")
d.rage = 18
handler("WTAGarou", "CrinosDoorCharge", p, { x = 20, y = 20, z = 0, north = true })
r = lastOf("DoorChargeResult")
check(r.reason == nil and r.locked == true and locked.destroyed, "18 Rage smashes the locked door")
close(d.rage, 0, "18 Rage spent to the floor")
close(p.stats.Endurance, 0.775, "0.225 endurance spent (relative)")

-- refusals
local sq3 = square(30, 30, 0)
d.rage = 60
newDoor(sq3, { prefix = "MetalDoor" }); p.x, p.y = 30.5, 31.2
handler("WTAGarou", "CrinosDoorCharge", p, { x = 30, y = 30, z = 0, north = true })
check(lastOf("DoorChargeResult").reason == "not_wood", "metal doors do not give")
local sq4 = square(40, 40, 0); local barred = newDoor(sq4, { barricaded = true }); p.x, p.y = 40.5, 41.2
handler("WTAGarou", "CrinosDoorCharge", p, { x = 40, y = 40, z = 0, north = true })
check(lastOf("DoorChargeResult").reason == "barricaded" and barred.thumps == 0, "barricades hold")
local sq5 = square(50, 50, 0); newDoor(sq5, { open = true }); p.x, p.y = 50.5, 51.2
handler("WTAGarou", "CrinosDoorCharge", p, { x = 50, y = 50, z = 0, north = true })
check(lastOf("DoorChargeResult").reason == "not_closed", "an open door is not a target")
local sq6 = square(60, 60, 0); local far = newDoor(sq6); p.x, p.y = 65.5, 61.2
handler("WTAGarou", "CrinosDoorCharge", p, { x = 60, y = 60, z = 0, north = true })
check(lastOf("DoorChargeResult").reason == "too_far" and far.thumps == 0, "a door five tiles away is refused (client payload is not trusted)")
check(WTAGarou.DoorChargeServer.isWooden({ getSoundPrefix = function() return nil end }), "a door without a DoorSound property is wooden (IsoDoor default)")
close(d.rage, 60, "refusals spend nothing")

-- ------------------------------------------------- melee surplus is melee ----
local hitHandler = Events.OnHitZombie.handlers[1]
check(type(hitHandler) == "function", "server OnHitZombie handler wired")
p.__class = "IsoPlayer"
p.md.WTAGarou_MeleeMult = WTAGarou.FormData.Crinos.meleeDamage
function p:getPrimaryHandItem() return self.weapon end
local zombie = { hp = 10, getHealth = function(self) return self.hp end, setHealth = function(self, v) self.hp = v end }
local bat = { getDamage = function() return 2 end, isRanged = function() return false end }
local rifle = { getDamage = function() return 2 end, isRanged = function() return true end }
d.rage = 60; p.weapon = bat
hitHandler(zombie, p, nil, bat)
close(zombie.hp, 10 - 2 * (2.0 - 1.0), "melee hit: 2x surplus taken off the zombie (was 4x)")
close(d.rage, 60 - 0.25, "0.4.82: a landed hit spends a flat 0.25 Rage (0.4.70 flat rule, halved), whatever the damage")
zombie.hp = 10; p.weapon = rifle
hitHandler(zombie, p, nil, rifle)
close(zombie.hp, 10, "firearm hit: no form surplus at all")
close(d.rage, 60 - 0.5, "...a firearm hit costs the same flat 0.25")
local heavy = { getDamage = function() return 40 end, isRanged = function() return false end }
zombie.hp = 100; p.weapon = heavy
hitHandler(zombie, p, nil, heavy)
close(d.rage, 60 - 0.75, "overkill damage (40) still costs only 0.25 Rage per hit")
check(WTAGarou.IsRangedWeapon(rifle) and not WTAGarou.IsRangedWeapon(bat) and not WTAGarou.IsRangedWeapon(nil), "ranged guard helper")

-- ------------------------------------------------------- client relay ----
WTAGarouJava = {
    ticks = {}, polls = 0, costs = nil, duck = nil,
    tickDoorway = function(pl, rage) WTAGarouJava.ticks[#WTAGarouJava.ticks + 1] = rage; return WTAGarouJava.hint == true end,
    pollDoorCharge = function(pl) WTAGarouJava.polls = WTAGarouJava.polls + 1; local x = WTAGarouJava.pending; WTAGarouJava.pending = nil; return x end,
    setDoorChargeCosts = function(a, b) WTAGarouJava.costs = { a, b } end,
    setDoorwayDuckRule = function(a, b) WTAGarouJava.duck = { a, b } end,
}
local denials, notices = {}, {}
WTAGarou.HUDFor = function() return { flashDenial = function(_, t) denials[#denials + 1] = t end, pushNotice = function(_, t) notices[#notices + 1] = t end } end
getSpecificPlayer = function() return p end
dofile(root .. "/42/media/lua/client/WTAGarouDoorway.lua")
local DW = WTAGarou.DoorwayClient
sent = {}
d.form = "Hispo"; DW.onUpdate(p)
check(#WTAGarouJava.ticks == 0, "non-tall form: Java is not ticked")
d.form = "Crinos"; d.rage = 33; DW.onUpdate(p)
check(WTAGarouJava.ticks[1] == 33 and WTAGarouJava.costs[1] == 12 and WTAGarouJava.costs[2] == 18 and WTAGarouJava.duck[1] == 1.0,
    "tall form: Rage pushed each frame, costs and duck rule pushed once")
check(#denials == 0 and lastOf("->CrinosDoorCharge") == nil, "nothing to report")
WTAGarouJava.hint = true; DW.onUpdate(p); DW.onUpdate(p)
check(#denials == 1 and denials[1] == WTAGarou.Doorway.HINT, "crouch-to-pass hint shown once a second, not every frame")
clock = clock + 1.5; DW.onUpdate(p)
check(#denials == 2, "...and again after the interval")
WTAGarouJava.hint = false
WTAGarouJava.pending = door; DW.onUpdate(p)
local relayed = lastOf("->CrinosDoorCharge")
check(relayed and relayed.x == 10 and relayed.y == 10 and relayed.z == 0 and relayed.north == true, "charged door relayed as square + edge")
check(DW.chargeArgs(nil) == nil, "no door, no payload")
DW.onServerCommand("WTAGarou", "DoorChargeResult", { reason = nil, locked = true })
check(notices[1] == "You smash through the locked door. -18 Rage.", "success notice names the cost: " .. tostring(notices[1]))
DW.onServerCommand("WTAGarou", "DoorChargeResult", { reason = "no_rage" })
check(denials[#denials] == "Not enough Rage to smash the door.", "no-Rage denial on the red line")
local before = #denials
DW.onServerCommand("WTAGarou", "DoorChargeResult", { reason = "no_door" })
check(#denials == before, "silent reasons stay silent")

print("PASS: " .. checks .. " door-charge server/client assertions.")
