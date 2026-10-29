-- Rage engine / berserk-Crinos regression test (0.4.10).
-- Loads the real shared definitions, state and server file against small
-- Build 42.20-shaped mocks (UPPER_SNAKE MoodleType, Stats:get/set with
-- CharacterStat, BodyPart setters). Deterministic: the clock is a variable.
local root = arg[1] or "."
local checks = 0
local function check(v, why) checks = checks + 1; if not v then error("FAIL: " .. why, 2) end end
local function close(a, b, why, eps) check(math.abs(a - b) < (eps or 0.01), why .. ": " .. tostring(a) .. " != " .. tostring(b)) end

-- ---------------------------------------------------------------- mocks ----
local clock = 1000.0
getTimestamp = function() return math.floor(clock) end
getTimestampMs = function() return clock * 1000 end
isClient = function() return false end
isServer = function() return false end
Events = setmetatable({}, { __index = function(t, k)
    t[k] = { handlers = {}, Add = function(f) table.insert(t[k].handlers, f) end }; return t[k] end })
ZombRand = function(n) return 0 end
instanceof = function() return false end
getGameTime = function() return { getWorldAgeHours = function() return 1 end } end
function require(_) end
print = print

MoodleType = { PANIC = "PANIC", STRESS = "STRESS", ENDURANCE = "ENDURANCE", HUNGRY = "HUNGRY",
    UNHAPPY = "UNHAPPY", BORED = "BORED", FOOD_EATEN = "FOOD_EATEN", HAS_A_COLD = "HAS_A_COLD",
    PAIN = "PAIN", INJURED = "INJURED", BLEEDING = "BLEEDING", TIRED = "TIRED", THIRST = "THIRST",
    SICK = "SICK", WET = "WET", HYPERTHERMIA = "HYPERTHERMIA", HYPOTHERMIA = "HYPOTHERMIA",
    WINDCHILL = "WINDCHILL", HEAVY_LOAD = "HEAVY_LOAD", DRUNK = "DRUNK", UNCOMFORTABLE = "UNCOMFORTABLE",
    NOXIOUS_SMELL = "NOXIOUS_SMELL", ANGRY = "ANGRY" }
CharacterStat = { ENDURANCE = "Endurance", ZOMBIE_INFECTION = "ZombieInfection", ZOMBIE_FEVER = "ZombieFever" }

local sent = {}
WTAGarou = WTAGarou or {}
WTAGarou.Net = {
    ToClient = function(p, cmd, args) table.insert(sent, { cmd = cmd, args = args }) end,
    ToServer = function() end,
    RegisterClientHandler = function() end,
    RegisterServerHandler = function() end,
    Broadcast = function(cmd, args) table.insert(sent, { cmd = cmd, args = args }) end,
    IsSinglePlayer = function() return true end,
}
local function sentCmds() local t = {}; for _, m in ipairs(sent) do table.insert(t, m.cmd) end; return table.concat(t, ",") end
local function lastOf(cmd) for i = #sent, 1, -1 do if sent[i].cmd == cmd then return sent[i].args end end end

local function newPlayer()
    local p = { md = {}, moodles = {}, stats = { Endurance = 1.0, ZombieInfection = 0, ZombieFever = 0 },
        parts = {}, vars = {}, dead = false, infected = false }
    function p:getModData() return self.md end
    function p:isDead() return self.dead end
    function p:getOnlineID() return 7 end
    function p:getMoodles()
        local m = self.moodles
        return { getMoodleLevel = function(_, mt) return m[mt] or 0 end }
    end
    function p:getStats()
        local st = self.stats
        return { get = function(_, k) return st[k] end, set = function(_, k, v) st[k] = v end }
    end
    function p:setSpeedMod() end
    function p:setVariable(k, v) self.vars[k] = v end
    function p:isFemale() return false end
    function p:getBodyDamage()
        local me = self
        return {
            getOverallBodyHealth = function() return 100 end,
            setOverallBodyHealth = function() end,
            getBodyParts = function() return { size = function() return #me.parts end, get = function(_, i) return me.parts[i + 1] end } end,
            setInfected = function(_, v) me.infected = v end,
            isInfected = function() return me.infected end,
            setIsFakeInfected = function() end,
            setInfectionTime = function(_, v) me.infectionTime = v end,
            setInfectionMortalityDuration = function(_, v) me.mortality = v end,
        }
    end
    return p
end
local function newPart(name)
    local bp = { health = 40, bleedingTime = 10, deepWoundTime = 5, bittenFlag = true, scratchedFlag = true,
        infectedWound = true, woundInf = 50, zInfected = true, fracture = 3, burn = 2, pain = 20 }
    function bp:getType() return name end
    function bp:getHealth() return self.health end
    function bp:AddHealth(v) self.health = math.min(100, self.health + v) end
    function bp:bleeding() return self.bleedingTime > 0 end
    function bp:setBleeding(v) if not v then self.bleedingTime = 0 end end
    function bp:getBleedingTime() return self.bleedingTime end
    function bp:setBleedingTime(v) self.bleedingTime = v end
    function bp:scratched() return self.scratchedFlag end
    function bp:setScratched(v) self.scratchedFlag = v end
    function bp:getScratchTime() return 0 end
    function bp:setScratchTime() end
    function bp:isCut() return false end
    function bp:setCut() end
    function bp:getCutTime() return 0 end
    function bp:setCutTime() end
    function bp:isDeepWounded() return self.deepWoundTime > 0 end
    function bp:setDeepWounded(v) if not v then self.deepWoundTime = 0 end end
    function bp:getDeepWoundTime() return self.deepWoundTime end
    function bp:setDeepWoundTime(v) self.deepWoundTime = v end
    function bp:bitten() return self.bittenFlag end
    function bp:SetBitten(v) self.bittenFlag = v end
    function bp:getBiteTime() return 0 end
    function bp:setBiteTime() end
    function bp:isInfectedWound() return self.infectedWound end
    function bp:setInfectedWound(v) self.infectedWound = v end
    function bp:setWoundInfectionLevel(v) self.woundInf = v end
    function bp:IsInfected() return self.zInfected end
    function bp:SetInfected(v) self.zInfected = v end
    function bp:getBurnTime() return self.burn end
    function bp:setBurnTime(v) self.burn = v end
    function bp:getFractureTime() return self.fracture end
    function bp:setFractureTime(v) self.fracture = v end
    function bp:setAdditionalPain(v) self.pain = v end
    return bp
end

dofile(root .. "/42/media/lua/shared/WTAGarouDefinitions.lua")
dofile(root .. "/42/media/lua/shared/WTAGarouState.lua")
WTAGarou.HasGarouTrait = function() return true end
WTAGarou.Slots = { enforce = function() end }
local burstCalls={}
WTAGarou.CrinosBurst={onCompleted=function(player,previous,target)
    burstCalls[#burstCalls+1]={previous=previous,target=target}
end}
dofile(root .. "/42/media/lua/server/WTAGarouServer.lua")

-- ------------------------------------------------------- definitions ----
check(WTAGarou.VERSION=="0.4.99", "version bumped")
check(WTAGarou.GetForm("Glabro").rageCost == 20, "Glabro costs 20, same as Hispo")
for form, target in pairs({Glabro=26, Hispo=32}) do
    local fd=WTAGarou.GetForm(form)
    local base=math.floor(math.max(8*fd.maxCarryMultiplier,fd.minCarryWeight)+0.5)
    check(math.floor(base*1.92)==target, form.." carry at Strength 7 before moodles")
end
check(WTAGarou.GetForm("Crinos").rageCost == 10, "Crinos costs 10")
check(WTAGarou.RageRequired("Crinos") == 55, "Crinos requires 55 (0.4.13, was 60)")
check(WTAGarou.RageRequired("Hispo") == 20, "other forms require their cost")
-- 0.4.39 Berserker breed (saved trueForm "Glabro") and the Crinos exit lock.
check(WTAGarou.ValidTrueForm("Glabro") and WTAGarou.BaseForm({trueForm="Glabro"})=="Glabro", "Glabro is a true form that reverts to Glabro")
check(WTAGarou.TrueFormLabel("Glabro")=="Berserker" and WTAGarou.TrueFormLabel("Homid")=="Human" and WTAGarou.TrueFormLabel("Lupus")=="Wolf", "true-form labels")
check(WTAGarou.IsBerserkerBreed({trueForm="Glabro"}) and not WTAGarou.IsBerserkerBreed({trueForm="Lupus"}) and not WTAGarou.IsBerserkerBreed(nil), "breed predicate")
check(WTAGarou.RageRequired("Crinos", {trueForm="Glabro"}) == 10, "Berserker Crinos has no floor beyond its 10 cost")
check(WTAGarou.RageRequired("Crinos", {trueForm="Lupus"}) == 55 and WTAGarou.RageRequired("Crinos", nil) == 55, "other breeds keep the 55 floor")
check(WTAGarou.RageRequired("Hispo", {trueForm="Glabro"}) == 20, "Berserker other forms unchanged")
close(WTAGarou.CrinosDrainPerSecond({trueForm="Glabro"}), -0.5, "Berserker Crinos drains 1 Rage per 2 s")
close(WTAGarou.CrinosDrainPerSecond({trueForm="Homid"}), -1.0, "default Crinos drains 1 Rage/s")
check(WTAGarou.CrinosLockAbove({trueForm="Glabro"}) == 55 and WTAGarou.CrinosLockAbove({}) == 75, "Crinos exit lock lines 55 / 75 (0.4.58)")
check(WTAGarou.CrinosLocked({form="Crinos", rage=76}) and not WTAGarou.CrinosLocked({form="Crinos", rage=75})
    and not WTAGarou.CrinosLocked({form="Hispo", rage=100}), "lock applies only in Crinos above the line")
check(WTAGarou.CrinosLocked({form="Crinos", rage=56, trueForm="Glabro"}) and not WTAGarou.CrinosLocked({form="Crinos", rage=55, trueForm="Glabro"}), "Berserker lock at 55 (0.4.58)")
check(WTAGarou.CrinosLocked({form="Crinos", rage=40, trueForm="Glabro"}) == false, "Berserker at 40 is no longer locked")
check(WTAGarou.IsBulkForm("Crinos") and WTAGarou.IsBulkForm("Hispo") and not WTAGarou.IsBulkForm("Glabro") and not WTAGarou.IsBulkForm("Lupus"), "bulk forms are Crinos and Hispo")
check(WTAGarou.VehicleShift.damageFor("Crinos") == 38 and WTAGarou.VehicleShift.damageFor("Crinos", true) == 75
    and WTAGarou.VehicleShift.damageFor("Hispo") == 25 and WTAGarou.VehicleShift.damageFor("Glabro") == 0, "vehicle part damage follows the clothing fractions of a 100-condition part (Glabro free since 0.4.82)")
check(WTAGarou.VehicleShift.SMASH_CHANCE == 0.02, "two percent window smash")
close(WTAGarou.ComputeTransformSeconds(0, "Crinos"), 1.0, "Crinos channel is 1 s at 0 rage")
close(WTAGarou.ComputeTransformSeconds(100, "Crinos"), 1.0, "Crinos channel is 1 s at 100 rage")
-- 0.4.61: plateau around the middle, one-second shifts near either end.
local C = WTAGarou.ComputeTransformSeconds
close(C(50, "Hispo"), 6.0, "non-Crinos: 6 s at the middle of the bar")
close(C(45, "Lupus"), 6.0, "45 Rage is still on the plateau")
close(C(55, "Glabro"), 6.0, "55 Rage is still on the plateau")
close(C(20, "Hispo"), 1.0, "20 Rage: scaling maxed, one-second channel")
close(C(80, "Hispo"), 1.0, "80 Rage: scaling maxed, one-second channel")
close(C(0, "Lupus"), 1.0, "0 Rage: one second")
close(C(100, "Lupus"), 1.0, "100 Rage: one second")
close(C(32.5, "Hispo"), 3.5, "32.5 Rage: halfway down the ramp (6 -> 1)")
close(C(67.5, "Hispo"), 3.5, "67.5 Rage: symmetric halfway point")
check(C(40, "Hispo") > C(30, "Hispo") and C(30, "Hispo") > C(20, "Hispo"), "channel shortens monotonically toward 0")
check(C(60, "Hispo") > C(70, "Hispo") and C(70, "Hispo") > C(80, "Hispo"), "channel shortens monotonically toward 100")
close(C(30, "Hispo"), C(70, "Hispo"), "curve is symmetric about 50")
close(C(-5, "Hispo"), 1.0, "rage below 0 clamps")
close(C(120, "Hispo"), 1.0, "rage above 100 clamps")
close(C(nil, "Hispo"), 1.0, "nil rage treated as 0")
close(C(0, "Crinos"), 1.0, "Crinos stays its fixed snap regardless of the curve")
close(C(50, "Crinos"), 1.0, "Crinos at 50 is still 1 s")
check(WTAGarou.TransformTime.MIN == nil and WTAGarou.TransformTime.MAX == nil, "old 10 -> 2 ramp constants are gone")
-- 0.4.45: the howl / contentment target is the per-character baseline: 50
-- until the auspice is locked, then 30/40/50/60/70.
check(WTAGarou.Howl.TARGET_RAGE == nil and WTAGarou.Rage.HOWL_CENTER == nil and WTAGarou.Rage.BASELINE_DEFAULT == 50
    and WTAGarou.Rage.START == 50, "no fixed 60 target any more; baseline and starting Rage default to 50")
check(WTAGarou.BaselineRage({}) == 50 and WTAGarou.BaselineRage({ auspice = "Ahroun" }) == 50
    and WTAGarou.BaselineRage({ auspice = "Ahroun", auspiceLocked = true }) == 70
    and WTAGarou.BaselineRage({ auspice = "Ragabash", auspiceLocked = true }) == 30, "baseline follows the LOCKED auspice only")
local names = {}
for _, a in ipairs(WTAGarou.Auspices) do names[#names + 1] = a.key .. "=" .. a.baseline .. "/" .. a.moon end
check(table.concat(names, " ") == "Ragabash=30/New Moon Theurge=40/Crescent Moon Philodox=50/Half Moon Galliard=60/Gibbous Moon Ahroun=70/Full Moon",
    "five auspices in moon order: " .. table.concat(names, " "))
-- 0.4.46: contributions now use 70% of the old 0.30/s rate.
local R = WTAGarou.Rage.CONTENT_PULL_PER_SECOND
check(R == 0.21, "R is reduced by 30% from 0.30")
close(WTAGarou.ContentPullPerSecond(true, true, false), 0, "hungry and thirsty: no drift")
close(WTAGarou.ContentPullPerSecond(false, true, false), 0.75 * R, "no hunger moodle alone: 75% of R")
close(WTAGarou.ContentPullPerSecond(true, false, false), 0.75 * R, "no thirst moodle alone: 75% of R")
close(WTAGarou.ContentPullPerSecond(false, false, false), 1.5 * R, "fed and watered: 150% of R")
close(WTAGarou.ContentPullPerSecond(true, true, true), 0.5 * R, "well fed while hungry and thirsty: 50% of R")
close(WTAGarou.ContentPullPerSecond(false, false, true), 2.0 * R, "well fed, fed and watered: 200% of R")
close(WTAGarou.Rage.REGEN_PER_SECOND.Crinos, -1.0, "Crinos drains 1/s")
check(WTAGarou.EnduranceRefund.Homid < WTAGarou.EnduranceRefund.Glabro and WTAGarou.EnduranceRefund.Glabro < WTAGarou.EnduranceRefund.Hispo
    and WTAGarou.EnduranceRefund.Hispo < WTAGarou.EnduranceRefund.Lupus and WTAGarou.EnduranceRefund.Lupus < WTAGarou.EnduranceRefund.Crinos,
    "exhaustion order Homid > Glabro > Hispo > Lupus > Crinos")
check(WTAGarou.Stability.Crinos >= 0.95 and WTAGarou.Stability.Hispo >= 0.9 and WTAGarou.Stability.Homid == 0, "Crinos/Hispo near-unknockable")
local sets = WTAGarou.MoodleSets()
check(#sets.negative >= 16, "UPPER_SNAKE moodle names resolve on 42.20: " .. #sets.negative)
check(#sets.sad == 4 and sets.hungry == "HUNGRY" and sets.thirsty == "THIRST" and sets.wellFed == "FOOD_EATEN", "sad / contentment moodles resolve")

-- --------------------------------------------------------- rage tick ----
local p = newPlayer()
local d = WTAGarou.GetData(p)
d.isGarou = true
d.form = "Hispo"; d.rage = 50
local function tick(dtSeconds)
    clock = clock + dtSeconds
    WTAGarou.RageTick(p, d, WTAGarou.NowSeconds())
end
tick(0)  -- prime the clock
-- 0.4.14: Rage is situational. No form except Crinos moves it on its own.
for _, f in ipairs({ "Homid", "Glabro", "Hispo", "Lupus" }) do
    d.form = f; d.rage = 50
    for _ = 1, 30 do tick(1.0) end
    close(d.rage, 50, "healthy " .. f .. " holds Rage for 30 s (no passive change)")
    check((WTAGarou.Rage.REGEN_PER_SECOND[f] or 0) == 0, f .. " passive rate is exactly 0")
end
check(WTAGarou.Rage.REGEN_PER_SECOND.Crinos == -1.0, "Crinos is the only form with a passive rate")
d.form = "Hispo"
p.moodles.PANIC = 4; p.moodles.ENDURANCE = 3; p.moodles.STRESS = 2; p.moodles.HUNGRY = 1
d.rage = 50
tick(1.0)
-- 0.4.20: Stress weighs 0.4 (a lone Tense moodle is about 2 Rage a minute).
-- 0.4.45: hungry but not thirsty, so contentment still drifts 0.75 x R
-- (0.1575/s) back toward the 50 baseline inside the same tick.
-- 0.4.68: exertion (Endurance 3) now DRAINS at the sad rate (0.03/level/s).
-- 0.4.69: 4+3+2+1 = 10 moodle stacks open a +/-20 bracket around the 50
-- baseline, so the drift inside it is halved (0.75 x R x 0.5).
local expected = 50 + 0.08 * (4 * 2.0 + 2 * 0.4 + 1) - 0.03 * 3 - 0.75 * R * 0.5
close(d.rage, expected, "fear (x2), stress (x0.4), hunger raise Rage in Hispo; exertion drains; no-thirst drift (halved in the bracket) pulls back")
check(WTAGarou.Rage.MOODLE_WEIGHTS.Stress == 0.4, "Stress weight is 0.4")
close(0.08 * 1 * 0.4 * 60, 1.92, "Tense alone builds about 2 Rage a minute")
check(d.rage > 50, "alarmed Hispo gains Rage despite the exertion drain")
p.moodles = { UNHAPPY = 3, BORED = 2 }
d.form = "Homid"; d.rage = 50
tick(1.0)
-- Sad moodles drain 0.12; fed and watered (no Hungry/Thirst moodle) drifts
-- 0.315 toward 50 in the same tick, so Rage lands back on the baseline.
close(d.rage, 50, "sad moodles tick Rage down (0.03/level/s) but the fed-and-watered drift (0.315/s) returns it to the 50 baseline")
p.moodles = { UNHAPPY = 3, BORED = 2, HUNGRY = 1, THIRST = 1 }
d.rage = 50
tick(1.0)
close(d.rage, 50 - 0.03 * (3 * 1.0 + 2 * 0.5) + 0.08 * 2, "hungry and thirsty: no drift; sadness drains, hunger/thirst add 0.08 each")
-- 0.4.63: the Oct 15 "sits at 99" bug. Pain 3, Endurance 1, Tired 4, Hungry 2,
-- Sick 1, Hyperthermia 1 (+0.84/s) with ONE Unhappy level (-0.03/s): the
-- old tick added the pressure (clamped at 100) and then subtracted the sad
-- drain, so Rage ended every tick at 99.985 and the countdown never armed.
-- 0.4.68: Endurance and Tired moved to the sad (draining) set, so the same
-- moodle set is now Pain 3, Hungry 2, Sick 1, Hyperthermia 1 (+0.52/s) against
-- Unhappy 1, Endurance 1, Tired 4 (-0.15/s): still net positive at the cap.
p.moodles = { PAIN = 3, ENDURANCE = 1, TIRED = 4, HUNGRY = 2, SICK = 1, HYPERTHERMIA = 1, UNHAPPY = 1, THIRST = 1 }
d.form = "Hispo"; d.rage = 100
for _ = 1, 10 do tick(0.5) end
close(d.rage, 100, "net-positive pressure with sad moodles holds Rage ON 100 (not 99.x)")
d.rage = 99.9; tick(0.5)
close(d.rage, 100, "and climbs the last tenth onto 100")
d.rage = 50; tick(1.0)
close(d.rage, 50 + 0.08 * (3 + 2 + 0.75 + 0.75) + 0.08 - 0.03 * (1 + 1 + 4 * 0.75),
    "0.4.68: exhaustion (1.0) and drowsiness (0.75) drain at the sad rate while pain/hunger/sickness/heat still build")
p.moodles = { PAIN = 3, HUNGRY = 2, SICK = 1, HYPERTHERMIA = 1, UNHAPPY = 1, THIRST = 1 }
d.form = "Crinos"; d.rage = 100
tick(0.5)
-- Crinos drains 1/s: -0.5 + 0.52*0.5 + 0.08*0.5 (thirst) - 0.015 = net -0.215 -> dips (expected without the old Endurance/Tired pressure)
check(d.rage < 100 and d.rage > 99.7, "Crinos at the cap with a fresh body: the 1/s burn wins by a sliver: " .. tostring(d.rage))
p.moodles = { PANIC = 4, PAIN = 4, HUNGRY = 2, SICK = 1, HYPERTHERMIA = 1, UNHAPPY = 1, THIRST = 1 }
d.rage = 100; tick(0.5)
check(d.rage > 99.9, "Crinos in a panic with heavy moodles and one Unhappy level holds the top: " .. tostring(d.rage))
p.moodles = { UNHAPPY = 1, HUNGRY = 1, THIRST = 1 }
d.form = "Hispo"; d.rage = 100
tick(1.0)
close(d.rage, 100, "a small net-positive sum at the cap stays clamped on 100")
d.rage = 50; tick(1.0)
close(d.rage, 50 + 0.08 * 2 - 0.03, "below the cap the sum equals the old separate adds")
d.form = "Hispo"
p.moodles = { FOOD_EATEN = 2 }
d.rage = 20
tick(1.0)
close(d.rage, 20 + 2.0 * R, "well fed and watered pulls toward baseline at 0.42/s")
d.rage = 90
tick(1.0)
close(d.rage, 90 - 2.0 * R, "well fed pulls Rage DOWN toward 50 when above it")
d.rage = 60; p.moodles = {}
d.form = "Lupus"
tick(1.0)
close(d.rage, 60 - 1.5 * R, "Lupus with no moodles drifts toward 50 at 0.315/s")
d.rage = 50; tick(1.0)
close(d.rage, 50, "Lupus holds Rage at the baseline")
-- Locked auspice moves the target: an Ahroun (70) drifts up from 60.
d.auspice = "Ahroun"; d.auspiceLocked = true; d.rage = 60; tick(1.0)
close(d.rage, 60 + 1.5 * R, "locked Ahroun drifts toward 70")
d.rage = 69.9; tick(1.0)
close(d.rage, 70, "drift stops at the baseline, no overshoot")
d.auspice = nil; d.auspiceLocked = nil

-- ------------------------------------------ 0.4.69 baseline bracket ----
-- Pure curve: PER_STACK 2, cap 10 stacks, drift x0.5 inside (inclusive).
local BB = WTAGarou.Rage.BASELINE_BRACKET
check(BB.PER_STACK == 2 and BB.MAX_STACKS == 10 and BB.SLOW == 0.5 and BB.BASE_HALF_WIDTH == 0, "bracket constants")
close(WTAGarou.BaselineBracketHalfWidth(0), 0, "no stacks: no bracket")
close(WTAGarou.BaselineBracketHalfWidth(3), 6, "3 stacks: +/-6")
close(WTAGarou.BaselineBracketHalfWidth(10), 20, "10 stacks: +/-20")
close(WTAGarou.BaselineBracketHalfWidth(12), 20, "stacks cap at 10 (12 -> +/-20)")
close(WTAGarou.BaselinePullMultiplier(50, 70, 10), 0.5, "baseline 70, 10 stacks: 50 is inside (inclusive)")
close(WTAGarou.BaselinePullMultiplier(90, 70, 10), 0.5, "...and so is 90")
close(WTAGarou.BaselinePullMultiplier(49.9, 70, 10), 1, "49.9 is outside: full drift")
close(WTAGarou.BaselinePullMultiplier(90.1, 70, 10), 1, "90.1 is outside: full drift")
close(WTAGarou.BaselinePullMultiplier(70, 70, 0), 1, "no stacks: full drift even on the baseline")
-- Stacks are engine moodle LEVELS per category, Rage-raising and
-- Rage-draining categories alike; Well Fed is not a stack.
p.moodles = { PANIC = 3, PAIN = 3, TIRED = 3, BORED = 3, FOOD_EATEN = 2 }
local sets2 = WTAGarou.MoodleSets()
local stacks = WTAGarou.MoodleStackLevels(p:getMoodles(), sets2.negative) + WTAGarou.MoodleStackLevels(p:getMoodles(), sets2.sad)
check(stacks == 12, "Fear 3 + Pain 3 + Drowsy 3 + Bored 3 (+ Well Fed) = 12 stacks: " .. tostring(stacks))
p.moodles = { PAIN = 3 }
check(WTAGarou.MoodleStackLevels(p:getMoodles(), sets2.negative) == 3, "Agony is level 3 of the Pain category, not its own moodle")
-- Live: baseline 70 (Ahroun-style), well fed and watered (0.42/s), ten+
-- stacks. Inside 50..90 the drift is 0.21/s; just outside it is 0.42/s.
d.auspice = "Ahroun"; d.auspiceLocked = true
local base70 = WTAGarou.BaselineRage(d)
check(base70 == 70, "Ahroun baseline 70 for the bracket scenario: " .. tostring(base70))
d.form = "Homid"; sent = {}
p.moodles = { PANIC = 3, PAIN = 3, TIRED = 3, BORED = 3, FOOD_EATEN = 2 }
local pressure = 0.08 * (3 * 2.0 + 3 * 1.0) - 0.03 * (3 * 0.75 + 3 * 0.5)
d.rage = 60; tick(1.0)
close(d.rage, 60 + pressure + 2.0 * R * 0.5, "inside the +/-20 bracket of 70: fed-and-watered drift halved (0.21/s)")
d.rage = 40; tick(1.0)
close(d.rage, 40 + pressure + 2.0 * R, "20.x below the band edge (40): full 0.42/s drift")
d.rage = 50; tick(1.0)
close(d.rage, 50 + pressure + 2.0 * R * 0.5, "exactly on the band edge (50): halved")
d.rage = 94; tick(1.0)
close(d.rage, 94 + pressure - 2.0 * R, "above the band (94 > 90): full drift pulls DOWN toward 70")
-- 0.4.69 HUD: the tick records the stacks and the sync carries the half width.
check(d.bracketStacks == 12, "tick stores the bracket stacks for the HUD: " .. tostring(d.bracketStacks))
check(WTAGarou.RageSyncArgs(d).bracket == 20, "RageSync carries the bracket half width (12 stacks -> cap 10 -> 20): " .. tostring(WTAGarou.RageSyncArgs(d).bracket))
p.moodles = { FOOD_EATEN = 2 }
d.rage = 60; tick(1.0)
close(d.rage, 60 + 2.0 * R, "no negative stacks: the bracket is gone, full drift")
check(d.bracketStacks == 0 and WTAGarou.RageSyncArgs(d).bracket == 0, "no stacks: sync says 0 bracket")
p.moodles = {}
d.auspice = nil; d.auspiceLocked = nil

-- ----------------------------------------------- Crinos drain + forced ----
-- 0.4.46: fed and watered also drifts a Crinos 0.315/s toward the baseline
-- (the old well-fed pull did the same at 0.30/level). Pin that down, then
-- make the character hungry and thirsty so the burn tests read the burn
-- alone. SKIP_FORMS can remove the drift from a form if the user wants.
d.form = "Crinos"; d.rage = 2.5; sent = {}
tick(1.0)
close(d.rage, 2.5 - 1.0 + 1.5 * R, "fed-and-watered Crinos burns 1/s minus the 0.315/s drift toward 50")
WTAGarou.Rage.CONTENTMENT.SKIP_FORMS.Crinos = true
d.rage = 2.5; tick(1.0)
close(d.rage, 1.5, "SKIP_FORMS.Crinos restores the bare 1/s burn")
WTAGarou.Rage.CONTENTMENT.SKIP_FORMS.Crinos = nil
local function starve() p.moodles.HUNGRY = 1; p.moodles.THIRST = 1 end

-- ------------------------------------- 0.4.69 Crinos drain escalation ----
-- Pure: -1/s, then -1/s more for every full 90 s held (Berserker -0.5 base).
local E = WTAGarou.Rage.CRINOS_ESCALATION
check(E.EVERY_SECONDS == 90 and E.STEP == -1.0, "escalation constants")
check(WTAGarou.CrinosEscalationSteps(0) == 0 and WTAGarou.CrinosEscalationSteps(89.9) == 0, "under 90 s: base drain")
check(WTAGarou.CrinosEscalationSteps(90) == 1 and WTAGarou.CrinosEscalationSteps(179) == 1 and WTAGarou.CrinosEscalationSteps(180) == 2, "one step per full 90 s")
close(WTAGarou.CrinosDrainPerSecond({trueForm="Homid"}, 0), -1.0, "fresh Crinos: -1/s")
close(WTAGarou.CrinosDrainPerSecond({trueForm="Homid"}, 90), -2.0, "held 90 s: -2/s")
close(WTAGarou.CrinosDrainPerSecond({trueForm="Homid"}, 200), -3.0, "held 200 s: -3/s")
close(WTAGarou.CrinosDrainPerSecond({trueForm="Glabro"}, 90), -1.5, "Berserker held 90 s: -0.5 - 1 = -1.5/s")
close(WTAGarou.CrinosDrainPerSecond({trueForm="Homid"}), -1.0, "no held time given: base (HUD call)")
-- Live: the tick keeps its own held clock, steps at 90 s, resets on exit.
p.moodles = {}; starve(); d.form = "Crinos"; d.rage = 100; d.crinosHeldSeconds = nil; sent = {}
tick(1.0)
check(d.crinosHeldSeconds ~= nil and (d.crinosEscalationSteps or 0) == 0 and not lastOf("CrinosDrain"), "first Crinos tick starts the held clock at step 0, no message")
for _ = 1, 89 do d.rage = 100; tick(1.0) end     -- 89 s held
check((d.crinosEscalationSteps or 0) == 0 and not lastOf("CrinosDrain"), "89 s held: still the base drain")
d.rage = 50; tick(1.0)                           -- 90 s held: this tick is at -2/s
local cdm = lastOf("CrinosDrain")
check(cdm and cdm.steps == 1 and math.abs(cdm.perSecond + 2.0) < 1e-6, "90 s held: CrinosDrain step 1 at -2/s announced")
close(d.rage, 50 - 2.0 + 0.16, "the 90th second already burns 2/s (hunger/thirst +0.16)")
for _ = 1, 89 do d.rage = 100; tick(1.0) end     -- 179 s held (Rage topped up so the burn cannot deplete it)
check(lastOf("CrinosDrain").steps == 1, "179 s held: still step 1")
d.rage = 50; tick(1.0)                           -- 180 s held
check(lastOf("CrinosDrain").steps == 2, "180 s held: step 2")
close(d.rage, 50 - 3.0 + 0.16, "...burning 3/s")
d.form = "Homid"; tick(1.0)
check(d.crinosHeldSeconds == nil and d.crinosEscalationSteps == nil, "leaving Crinos drops the held clock and step")
d.form = "Crinos"; d.rage = 50; tick(1.0)
close(d.rage, 50 - 1.0 + 0.16, "back in Crinos: base 1/s again (the clock restarted)")
-- 0.4.70: held time is summed from the (2 s capped) tick deltas, so a
-- pause -- no ticks, then one big wall-clock gap -- adds at most 2 s.
d.form = "Crinos"; d.crinosHeldSeconds = nil; d.crinosEscalationSteps = nil; sent = {}
for _ = 1, 80 do d.rage = 100; tick(1.0) end        -- 80 s held
d.rage = 100; tick(600)                              -- a 10 minute pause: counts as 2 s
check(math.abs(d.crinosHeldSeconds - 82) < 1e-6 and not lastOf("CrinosDrain"), "10 min of paused wall clock adds 2 s of held time, no escalation: " .. tostring(d.crinosHeldSeconds))
for _ = 1, 8 do d.rage = 100; tick(1.0) end
check(not lastOf("CrinosDrain"), "89 s of played time: still step 0")
d.rage = 100; tick(1.0)
check(lastOf("CrinosDrain") and lastOf("CrinosDrain").steps == 1, "...the step lands at 90 s of played time, not of wall clock")
d.form = "Crinos"; d.crinosHeldSeconds = nil; d.crinosEscalationSteps = nil

p.moodles = {}; starve()
d.rage = 2.5 - 0.16; sent = {}
tick(1.0)
close(d.rage, 1.5, "Crinos burns 1/s (hunger/thirst add 0.08 each, no drift)")
check(#sent == 0, "no forced shift while Rage remains")
tick(1.0)
check(d.form == "Crinos" and d.depletedSince and #sent == 0, "0.4.75: the first dry tick starts the hold; no revert yet")
d.rage = 1.5; tick(0.5)
check(d.form == "Crinos" and d.depletedSince == nil, "Rage climbing back over the line clears the hold")
d.rage = 0.5; tick(0.5); d.rage = 0.5; tick(1.0); d.rage = 0.5
tick(1.0)
check(d.form == "Homid" and d.rage == 0, "Crinos below 1 Rage for DEPLETED_HOLD_S is forced to Homid (0.4.19 / 0.4.75)")
check(lastOf("TransformForced") and lastOf("TransformForced").reason == "rage_depleted", "TransformForced sent with reason")
check(lastOf("TransformForced").previousForm == "Crinos", "previous form reported")
-- 0.4.75, the reported case: 20 Rage into Glabro (cost 20) lands on 0 while Rage is climbing.
d.form = "Glabro"; d.rage = 0; d.formChangedAt = WTAGarou.NowSeconds(); sent = {}; p.moodles = {}
tick(1.0); d.rage = 0.7; tick(1.0); d.rage = 1.4; tick(1.0); tick(1.0)
check(d.form == "Glabro" and not lastOf("TransformForced") and d.depletedSince == nil, "a fresh shift that lands on 0 holds while Rage climbs back over 1 inside the buffer")
d.form = "Glabro"; d.rage = 0; d.formChangedAt = WTAGarou.NowSeconds(); sent = {}
tick(1.0); tick(1.0); check(d.form == "Glabro", "...and still holds at 2 s"); tick(1.0)
check(d.form == "Homid" and lastOf("TransformForced"), "...but reverts once the buffer passes with Rage still dry")
check(WTAGarou.Rage.DEPLETED_HOLD_S == 2.0, "the buffer is two seconds")
-- 0.4.75: "dry" = Rage pinned at 0 across the DEPLETED_HOLD_S buffer.
local function dry(n) for _ = 1, n do d.rage = 0; tick(1) end end
for _,form in ipairs({"Glabro","Crinos","Hispo","Lupus"}) do
    d.form=form; d.rage=0; sent={}; p.moodles={PANIC=4}
    dry(3)
    check(d.form=="Homid" and d.rage==0,"zero Rage forces Homid before moodle gains: "..form)
    check(lastOf("TransformForced").previousForm==form,"forced message preserves previous "..form)
end
p.moodles={}; sent={}; tick(1)
check(not lastOf("TransformForced"),"zero Rage Homid does not repeatedly force itself")
d.trueForm="Lupus"
for _,form in ipairs({"Homid","Glabro","Crinos","Hispo"}) do
    d.form=form; d.rage=0; sent={}; dry(3)
    check(d.form=="Lupus" and d.rage==0,"Wolf-born depletion returns to Lupus from "..form)
end
sent={}; tick(1)
check(d.form=="Lupus" and not lastOf("TransformForced"),"Wolf-born Lupus stable at zero Rage")
d.trueForm=nil; d.form="Homid"

-- ------------------------------------------------ 100 Rage countdown ----
-- 0.4.70: the drift pauses only while the 100-Rage countdown runs (or Rage
-- sits on MAX about to start it); a fed, watered Homid at 96-99 is pulled
-- toward the baseline like anywhere else (Oct 18: cheated to 98, no pull).
d.form = "Homid"; sent = {}; p.moodles = {}
check(WTAGarou.Rage.CONTENTMENT.PAUSE_ABOVE == nil and WTAGarou.Rage.FORCE_CRINOS_CANCEL_BELOW == 95, "no whole-band pause any more; the countdown still cancels below 95")
check(not WTAGarou.ContentPullPaused({ rage = 98 }) and WTAGarou.ContentPullPaused({ rage = 100 })
    and WTAGarou.ContentPullPaused({ rage = 97, crinosCountdownAt = 1 })
    and not WTAGarou.ContentPullPaused({ rage = 100, resistRestUntil = 5 }), "ContentPullPaused: only at MAX (outside a Resist rest) or while a countdown runs")
WTAGarou.SetRage(p, 98); tick(1.0)
close(d.rage, 98 - 1.5 * R, "fed and watered Homid at 98 drifts toward the baseline (was frozen in 0.4.45-0.4.69)")
WTAGarou.SetRage(p, 94.9); tick(1.0)
close(d.rage, 94.9 - 1.5 * R, "just below 95 as before")
WTAGarou.SetRage(p, 100)
tick(0.5)
close(d.rage, 100, "Rage on MAX is not pulled before the countdown can start")
check(lastOf("CrinosCountdown") and lastOf("CrinosCountdown").seconds == 10, "countdown starts at 100 Rage with 10 s (0.4.17, was 10)")
check(d.crinosCountdownAt ~= nil, "countdown timestamp stored")
for _ = 1, 8 do tick(1.0) end
check(d.rage == 100, "Rage clamps at MAX")
check(d.form == "Homid" and not d.pendingForm, "no forced shift before 10 s")
WTAGarou.SetRage(p, 94); tick(1.0)
check(lastOf("CrinosCountdownCancelled") and lastOf("CrinosCountdownCancelled").reason == "rage_dropped", "dropping below 95 cancels")
check(d.crinosCountdownAt == nil, "countdown cleared")
sent = {}
WTAGarou.SetRage(p, 100); tick(1.0)
check(lastOf("CrinosCountdown"), "countdown restarts on returning to 100")
WTAGarou.SetRage(p, 97); tick(1.0)
check(not lastOf("CrinosCountdownCancelled"), "97 Rage keeps the countdown running")
for _ = 1, 9 do tick(1.0) end
local accepted = lastOf("TransformAccepted")
check(accepted and accepted.form == "Crinos" and accepted.forced == true, "forced Crinos reservation sent after 10 s")
close(accepted.seconds, 0.25, "forced channel is 250 ms")
check(d.pendingForm == "Crinos" and d.pendingForced, "server holds a forced reservation")
-- A stale cancel from the replaced voluntary channel must not drop it.
check(WTAGarou.HandleClientCommand ~= nil, "server exposes its client-command handler for tests")
WTAGarou.HandleClientCommand("WTAGarou", "TransformCancel", p, { form = "Hispo" })
check(d.pendingForm == "Crinos", "cancel for another form does not drop the forced reservation")
WTAGarou.HandleClientCommand("WTAGarou", "TransformCancel", p, { form = "Crinos" })
check(d.pendingForm == "Crinos", "a forced reservation cannot be cancelled by the client")
sent = {}
check(#burstCalls==0,"no burst before forced channel completion")
WTAGarou.HandleClientCommand("WTAGarou", "TransformConfirm", p, { form = "Crinos" })
check(#burstCalls==1 and burstCalls[1].target=="Crinos" and burstCalls[1].previous=="Homid","forced completion invokes burst once")
check(d.form == "Crinos", "forced Crinos applied on confirm")
close(d.rage, 87, "forced Crinos spent the 10 Rage cost (97 -> 87; a calm Homid no longer refills to 100)")
check(d.isFrenzied == true, "forced shift marks frenzy")
check(lastOf("TransformCompleted") ~= nil, "completion broadcast")
check(lastOf("TransformCompleted").forced == true, "0.4.16: completion carries forced=true so the client doubles the clothing damage")
WTAGarou.HandleClientCommand("WTAGarou", "TransformConfirm", p, { form = "Crinos" })
check(#burstCalls==1,"duplicate confirmation cannot repeat completion effect")
tick(1.0)
check(d.crinosCountdownAt == nil, "no countdown while in Crinos")

-- ------------------------------------------------- 0.4.21 Resist cycle ----
-- Countdown length curve: 10,8,6,4,2 (linear, 4 resists; 0.4.69: two
-- seconds per Resist, was one), then log toward 0.5.
local F = WTAGarou.ResistCountdownSeconds
check(WTAGarou.Rage.RESIST.LINEAR_STEP == 2.0, "0.4.69: each Resist takes two seconds off the next countdown")
close(F(0), 10, "0 resists: base 10 s")
close(F(1), 8, "1 resist: two seconds shorter")
close(F(2), 6, "2 resists: 6 s")
close(F(4), 2, "4 resists: linear phase ends at LOG_BELOW (2 s)")
close(F(5), 0.5 + 1.5 / (1 + math.log(2)), "5 resists: first logarithmic step")
check(F(5) < F(4) and F(6) < F(5) and F(50) < F(6) and F(1000) < F(50), "the countdown keeps shrinking")
check(F(4) - F(5) > F(5) - F(6) and F(5) - F(6) > F(6) - F(7), "...by ever smaller steps")
check(F(1000000) > 0.5 and F(1000000) < 0.61 and F(1e12) > 0.5, "...but never reaches half a second (1e6 resists: " .. string.format("%.3f", F(1000000)) .. " s)")
check(WTAGarou.Rage.RESIST.MIN_SECONDS == 0.5 and WTAGarou.Rage.RESIST.REST_MIN_MULT == 3 and WTAGarou.Rage.RESIST.REST_MAX_MULT == 12, "Resist constants")
-- Hidden rest interval: [3, 12] x the countdown just resisted.
close(WTAGarou.ResistRestSeconds(10, 0), 30, "rest at roll 0 = 3 x countdown")
close(WTAGarou.ResistRestSeconds(10, 1), 120, "rest at roll 1 = 12 x countdown")
close(WTAGarou.ResistRestSeconds(2, 0.5), 15, "rest scales with the (shorter) countdown")
local rr = WTAGarou.ResistRestSeconds(10)
check(rr >= 30 and rr <= 120, "random rest lands inside [30, 120] for a 10 s countdown: " .. tostring(rr))

d.form = "Homid"; d.pendingForm = nil; d.pendingForced = nil; d.isFrenzied = false
d.resists = 0; d.resistRestUntil = nil; sent = {}
WTAGarou.SetRage(p, 100); tick(0.5)
check(lastOf("CrinosCountdown") and lastOf("CrinosCountdown").seconds == 10 and lastOf("CrinosCountdown").resists == 0, "fresh countdown: 10 s, 0 resists")
sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "ResistRequest", p, {})
local rres = lastOf("ResistResult")
check(rres and rres.ok == true and rres.resists == 1 and rres.resisted == 10, "Resist during the countdown succeeds: " .. tostring(rres and rres.ok))
close(rres.nextSeconds, 8, "...and announces the next 8 s countdown")
check(lastOf("CrinosCountdownCancelled") and lastOf("CrinosCountdownCancelled").reason == "resisted", "the countdown is cancelled with reason resisted")
check(d.crinosCountdownAt == nil and d.resistRestUntil and d.resistRestUntil - clock >= 30 and d.resistRestUntil - clock <= 120,
    "hidden rest set within [30, 120] s")
sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "ResistRequest", p, {})
check(lastOf("ResistResult") and lastOf("ResistResult").ok == false and lastOf("ResistResult").reason == "nothing_to_resist", "Resist with no countdown fails softly")
check(d.resists == 1, "a failed Resist does not count")
-- 0.4.70: fed and watered, the drift works again the moment the Resist
-- lands (the whole-band pause is gone), so hold Rage above 95 here by
-- starving the character; the fed case is covered below.
starve()
-- Rage stays at 97 (>= 95): the rest runs out, an 8 s countdown starts
-- (0.4.69: two seconds off per Resist).
WTAGarou.SetRage(p, 97); sent = {}
for _ = 1, 29 do tick(1.0) end
check(not lastOf("CrinosCountdown"), "no countdown before the rest interval ends (29 s < 30 s)")
for _ = 1, 140 do tick(1.0); if lastOf("CrinosCountdown") then break end end
local cd2 = lastOf("CrinosCountdown")
check(cd2 and cd2.resists == 1 and math.abs(cd2.seconds - 8) < 1e-6, "after the hidden rest at 97 Rage the next countdown is 8 s")
check(d.crinosCountdownAt ~= nil and math.abs(d.crinosCountdownSeconds - 8) < 1e-6, "server holds the 8 s length")
-- Let it run out: forced Crinos after 8 s, not 10.
sent = {}
for _ = 1, 7 do tick(1.0) end
check(not lastOf("TransformAccepted"), "7 s: not yet")
tick(1.0)
check(lastOf("TransformAccepted") and lastOf("TransformAccepted").forced == true, "8 s: forced Crinos reservation")
-- Cycle reset: pendingForced ends it.
tick(0.5)
check(d.resists == 0 and d.resistRestUntil == nil and lastOf("ResistReset") and lastOf("ResistReset").reason == "in_crinos", "entering Crinos resets the Resist cycle")
d.pendingForm = nil; d.pendingForced = nil
-- Rage under 95 also resets the cycle.
d.form = "Homid"; d.resists = 0; d.resistRestUntil = nil; sent = {}
WTAGarou.SetRage(p, 100); tick(0.5)
WTAGarou.HandleClientCommand("WTAGarou", "ResistRequest", p, {})
check(d.resists == 1, "one resist banked")
WTAGarou.SetRage(p, 94); sent = {}; tick(1.0)
check(d.resists == 0 and d.resistRestUntil == nil and lastOf("ResistReset") and lastOf("ResistReset").reason == "rage_dropped", "Rage under 95 ends the cycle")
WTAGarou.SetRage(p, 100); sent = {}; tick(0.5)
check(lastOf("CrinosCountdown") and lastOf("CrinosCountdown").seconds == 10, "back at 100 the countdown is the full 10 s again")
-- 0.4.70: fed and watered (no Hungry, no Thirst moodle), the countdown
-- itself still holds Rage on 100, but a Resist lets contentment pull.
p.moodles = {}
for _ = 1, 3 do tick(1.0) end
close(d.rage, 100, "while the countdown runs the drift is paused: Rage stays on 100")
WTAGarou.HandleClientCommand("WTAGarou", "ResistRequest", p, {})
check(d.crinosCountdownAt == nil and d.resistRestUntil, "Resist lands: hidden rest running")
tick(1.0)
close(d.rage, 100 - 1.5 * R, "the second after a Resist a fed, watered Garou drifts toward the baseline (Oct 18)")
for _ = 1, 40 do tick(1.0); if d.rage < 95 then break end end
check(d.rage < 95 and d.resists == 0 and d.resistRestUntil == nil, "...and leaves the frenzy band inside the hidden rest, ending the cycle")
d.crinosCountdownAt = nil; d.resistRestUntil = nil; d.resists = 0

-- ----------------------------------------------- voluntary Crinos gate ----
d.form = "Homid"; d.rage = 54; d.formChangedAt = 0; sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "TransformRequest", p, { form = "Crinos" })
check(lastOf("TransformDenied") and lastOf("TransformDenied").reason == "not_enough_rage", "54 Rage cannot start Crinos")
d.rage = 55; sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "TransformRequest", p, { form = "Crinos" })
local acc = lastOf("TransformAccepted")
check(acc and acc.form == "Crinos" and not acc.forced, "55 Rage starts a voluntary Crinos shift (0.4.13)")
close(acc.seconds, 1.0, "voluntary Crinos channel is 1 s")
WTAGarou.HandleClientCommand("WTAGarou", "TransformConfirm", p, { form = "Crinos" })
check(lastOf("TransformCompleted") and lastOf("TransformCompleted").forced == false, "voluntary completion carries forced=false")
check(d.form == "Crinos", "voluntary Crinos applied")
close(d.rage, 45, "voluntary Crinos spent only 10 (55 -> 45)")
check(d.isFrenzied == false, "voluntary shift is not frenzy")
check(#burstCalls==2 and burstCalls[2].previous=="Homid","voluntary completion invokes exactly one additional burst")
-- 0.4.39: Crinos exit lock (75 for everyone; 35 for Berserkers); 0-Rage return bypasses it.
d.rage = 80; d.formChangedAt = 0; sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "TransformRequest", p, { form = "Homid" })
check(lastOf("TransformDenied") and lastOf("TransformDenied").reason == "crinos_locked" and lastOf("TransformDenied").lockAbove == 75,
    "Crinos at 80 Rage cannot shift out (crinos_locked, 75)")
check(d.form == "Crinos" and not d.pendingForm, "locked request reserves nothing")
d.rage = 75; sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "TransformRequest", p, { form = "Homid" })
check(lastOf("TransformAccepted") and lastOf("TransformAccepted").form == "Homid", "Crinos at 75 Rage may shift out")
WTAGarou.HandleClientCommand("WTAGarou", "TransformCancel", p, { form = "Homid" })
d.form = "Crinos"; d.rage = 70; d.trueForm = "Glabro"; sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "TransformRequest", p, { form = "Glabro" })
check(lastOf("TransformDenied") and lastOf("TransformDenied").reason == "crinos_locked" and lastOf("TransformDenied").lockAbove == 55,
    "Berserker Crinos at 70 Rage is locked (55)")
d.rage = 55; sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "TransformRequest", p, { form = "Glabro" })
check(lastOf("TransformAccepted") and lastOf("TransformAccepted").form == "Glabro", "Berserker at 55 may leave Crinos")
WTAGarou.HandleClientCommand("WTAGarou", "TransformCancel", p, { form = "Glabro" })
d.form = "Crinos"; d.rage = 50; sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "TransformRequest", p, { form = "Glabro" })
check(lastOf("TransformAccepted") and lastOf("TransformAccepted").form == "Glabro", "Berserker at 50 may leave Crinos (0.4.58)")
WTAGarou.HandleClientCommand("WTAGarou", "TransformCancel", p, { form = "Glabro" })
-- Berserker Crinos entry: no 55 floor, cost 10, half drain, Glabro at 0.
d.form = "Glabro"; d.rage = 12; d.formChangedAt = 0; sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "TransformRequest", p, { form = "Crinos" })
check(lastOf("TransformAccepted") and lastOf("TransformAccepted").form == "Crinos", "Berserker enters Crinos at 12 Rage")
WTAGarou.HandleClientCommand("WTAGarou", "TransformConfirm", p, { form = "Crinos" })
check(d.form == "Crinos", "Berserker Crinos applied")
close(d.rage, 2, "Berserker Crinos spent 10 (12 -> 2)")
d.rage = 30; p.moodles = {}; sent = {}; tick(2.0)
close(d.rage, 29 + 3 * R, "fed-and-watered Berserker Crinos: 0.5/s burn minus 0.315/s drift toward 50", 0.05)
d.rage = 30; p.moodles = {}; starve(); sent = {}; tick(2.0)
close(d.rage, 29 + 0.32, "Berserker Crinos burns 0.5/s (30 -> 29 over 2 s, +0.16/s hunger and thirst)", 0.05)
d.rage = 0.5; sent = {}; dry(3)
check(d.form == "Glabro" and lastOf("TransformForced") and lastOf("TransformForced").form == "Glabro", "Berserker depleted Crinos returns to Near-Human")
sent = {}; tick(1)
check(d.form == "Glabro" and not lastOf("TransformForced"), "Berserker Glabro is stable at zero Rage")
d.form = "Hispo"; d.rage = 0; sent = {}; dry(3)
check(d.form == "Glabro", "Berserker depleted Hispo returns to Near-Human")
d.form = "Homid"; d.rage = 0; sent = {}; dry(3)
check(d.form == "Glabro", "Berserker depleted Human returns to Near-Human")
d.trueForm = nil; d.form = "Crinos"; d.rage = 45; d.formChangedAt = 0
d.form = "Crinos"; d.rage = 30; p.moodles = {}; starve(); sent = {}; tick(2.0)
close(d.rage, 28 + 0.32, "default Crinos still burns 1/s (30 -> 28 over 2 s, +0.16/s hunger and thirst)", 0.05)
p.moodles = {}
d.rage = 45
local cancelPlayer=newPlayer()
local cancelData=WTAGarou.GetData(cancelPlayer)
cancelData.isGarou=true; cancelData.form="Homid"; cancelData.rage=80; cancelData.formChangedAt=0
WTAGarou.HandleClientCommand("WTAGarou","TransformRequest",cancelPlayer,{form="Crinos"})
WTAGarou.HandleClientCommand("WTAGarou","TransformCancel",cancelPlayer,{form="Crinos"})
WTAGarou.HandleClientCommand("WTAGarou","TransformConfirm",cancelPlayer,{form="Crinos"})
check(#burstCalls==3 and cancelData.form=="Homid","cancelled reservation cannot pulse (3 = Homid, voluntary, Berserker confirms)")

-- ------------------------------------------- rage engine scheduling ----
-- 0.4.12: single player runs the Rage engine from OnPlayerUpdate (the OnTick
-- sweep over getOnlinePlayers() never moved Rage in the 0.4.11 playtest); a
-- dedicated server keeps the OnTick sweep. Both are throttled per player.
local function fireUpdate(pl) for _, h in ipairs(Events.OnPlayerUpdate.handlers) do h(pl) end end
local function fireTick() for _, h in ipairs(Events.OnTick.handlers) do h() end end
local up = newPlayer(); function up:getOnlineID() return 8 end
local ud = WTAGarou.GetData(up); ud.isGarou = true
-- 0.4.45: switch the drift off for these two forms so the throttle / path
-- assertions read the burn and the moodle gains alone; re-enabled below.
WTAGarou.Rage.CONTENTMENT.SKIP_FORMS.Crinos = true; WTAGarou.Rage.CONTENTMENT.SKIP_FORMS.Homid = true
ud.form = "Crinos"; ud.rage = 80; sent = {}
clock = clock + 5
fireUpdate(up)                       -- primes the per-player clocks
clock = clock + 1
fireUpdate(up)
close(ud.rage, 79, "OnPlayerUpdate drains Crinos 1/s in single player")
check(lastOf("RageSync") and math.abs(lastOf("RageSync").rage - 79) < 0.01, "RageSync sent from the update path")
clock = clock + 0.2
fireUpdate(up)
close(ud.rage, 79, "throttled: a 0.2 s later update does not tick again")
ud.form = "Homid"; ud.rage = 10
clock = clock + 1; fireUpdate(up)
clock = clock + 1; fireUpdate(up)
close(ud.rage, 10, "calm Homid does not gain Rage from the update path (0.4.14)")
up.moodles = { PANIC = 2 }
clock = clock + 1; fireUpdate(up)
close(ud.rage, 10 + 0.08 * 2 * 2.0, "panic still raises Rage from the update path")
WTAGarou.Rage.CONTENTMENT.SKIP_FORMS.Crinos = nil; WTAGarou.Rage.CONTENTMENT.SKIP_FORMS.Homid = nil
ud.rage = 10; up.moodles = {}
clock = clock + 1; fireUpdate(up)
close(ud.rage, 10 + 1.5 * R, "fed and watered Homid drifts toward 50 from the update path too")
up.moodles = {}
ud.rage = 100; sent = {}
clock = clock + 1; fireUpdate(up)
check(lastOf("CrinosCountdown") ~= nil, "full Rage from the update path starts the Crinos countdown")
-- dedicated server: OnPlayerUpdate is ignored, OnTick sweeps online players
isServer = function() return true end
local sp = newPlayer(); function sp:getOnlineID() return 9 end
local sd = WTAGarou.GetData(sp); sd.isGarou = true; sd.form = "Crinos"; sd.rage = 50
sp.moodles = { HUNGRY = 1, THIRST = 1 }   -- 0.4.45: no contentment drift; +0.16/s from the two moodles
getOnlinePlayers = function() return { size = function() return 1 end, get = function() return sp end } end
clock = clock + 1; fireUpdate(sp); clock = clock + 1; fireUpdate(sp)
close(sd.rage, 50, "server ignores OnPlayerUpdate for Rage")
for _ = 1, 10 do fireTick() end       -- prime (10 ticks per sweep)
clock = clock + 1
for _ = 1, 10 do fireTick() end
close(sd.rage, 49 + 0.16, "server OnTick sweep drains Crinos 1/s (plus 0.16 hunger/thirst)")
-- 0.4.95: a client modData transmit (ISHotbar:savePosition on every hotbar
-- refresh) replaces the server's nested WTAGarou table with the client's
-- mirror; the server must keep its own table or the countdown resets.
do
    local md = sp:getModData()
    check(md.WTAGarou == sd, "server table lives in modData")
    sd.rage = 100; sd.form = "Glabro"; sd.crinosCountdownAt = clock
    local clobbers = WTAGarou.ModDataClobbers
    md.WTAGarou = { rage = 100, form = "Glabro", isGarou = true }     -- what the client's packet leaves behind
    local again = WTAGarou.GetData(sp)
    check(again == sd and md.WTAGarou == sd and again.crinosCountdownAt == clock,
        "server GetData restores its own table (countdown survives the transmit)")
    check(WTAGarou.ModDataClobbers == clobbers + 1, "clobber counted")
    -- a fresh player object (rejoin) adopts whatever the server loaded
    local np = newPlayer(); function np:getOnlineID() return 10 end
    np:getModData().WTAGarou = { rage = 42, isGarou = true }
    check(WTAGarou.GetData(np).rage == 42, "new player object: the loaded table is adopted, not replaced")
    WTAGarou.ForgetServerData(np)
    np:getModData().WTAGarou = { rage = 7, isGarou = true }
    check(WTAGarou.GetData(np).rage == 7, "after ForgetServerData the next table is adopted")
end
isServer = function() return false end
getOnlinePlayers = nil

-- ------------------------------------------------- endurance refund ----
d.form = "Crinos"
p.stats.Endurance = 1.0
WTAGarou.RefundEndurance(p, d)      -- prime
p.stats.Endurance = 0.8              -- engine drained 0.2
WTAGarou.RefundEndurance(p, d)
close(p.stats.Endurance, 0.8 + 0.2 * 0.9, "Crinos refunds 90% of stamina loss")
d.form = "Homid"; p.stats.Endurance = 0.5
WTAGarou.RefundEndurance(p, d)
p.stats.Endurance = 0.3
WTAGarou.RefundEndurance(p, d)
close(p.stats.Endurance, 0.3, "Homid refunds nothing")
d.form = "Hispo"; p.stats.Endurance = 0.5
WTAGarou.RefundEndurance(p, d)
p.stats.Endurance = 0.4
WTAGarou.RefundEndurance(p, d)
close(p.stats.Endurance, 0.4 + 0.1 * 0.55, "Hispo refunds 55%")

-- ------------------------------------------------------ regeneration ----
-- 0.4.68: Crinos closes ordinary wounds in W = 100 s (was 75) and heals HP = 1.2/s (was 1.6).
local W = WTAGarou.Regeneration.CLEAR_WOUNDS_AFTER.Crinos
local HP = WTAGarou.Regeneration.HEALTH_PER_SECOND.Crinos

-- Native-like foot state, including the side effects of removing stitches
-- and bullets. Flags/timers are intentionally independent, as in BodyPart.
local function injuryFoot(name)
    local f=newPart(name)
    WTAGarou.ClearWound(f)
    f.health=100; f.glass=false; f.bullet=false; f.stitchFlag=false; f.stitchTime=0
    f.deepFlag=false; f.scratchTime=0; f.cutTime=0; f.biteTime=0
    function f:haveGlass() return self.glass end
    function f:setHaveGlass(v) self.glass=v end
    function f:haveBullet() return self.bullet end
    function f:setHaveBullet(v,doctor)
        if self.bullet and not v then
            self.deepFlag=true; self.deepWoundTime=18; self.bleedingTime=7
            self.stitchFlag=false -- native setDeepWounded(true)
        end
        self.bullet=v
    end
    function f:stitched() return self.stitchFlag end
    function f:getStitchTime() return self.stitchTime end
    function f:setStitchTime(v) self.stitchTime=v end
    function f:setStitched(v)
        if not v and self.stitchFlag then
            if self.stitchTime<40 then self.deepFlag=true; self.deepWoundTime=10; self.bleedingTime=10
            else self.scratchedFlag=true; self.scratchTime=5 end
        end
        self.stitchFlag=v
    end
    function f:isDeepWounded() return self.deepFlag end
    function f:setDeepWounded(v) self.deepFlag=v end
    function f:getScratchTime() return self.scratchTime end
    function f:setScratchTime(v) self.scratchTime=v end
    function f:getCutTime() return self.cutTime end
    function f:setCutTime(v) self.cutTime=v end
    function f:getBiteTime() return self.biteTime end
    function f:setBiteTime(v) self.biteTime=v end
    function f:getWoundInfectionLevel() return self.woundInf end
    -- Relevant independent penalties from native calculateInjurySpeed.
    function f:movementPenalty()
        if self.bullet then return 1 end
        local v=(self.glass or self.deepFlag or self.fracture>0 or self.burn>5 or self.biteTime>0) and 1 or 0
        if self.stitchTime>0 then v=.7 end
        return v+self.scratchTime/20+self.cutTime/20+self.deepWoundTime/20+self.biteTime/20
    end
    return f
end
for _,name in ipairs({"Foot_L","Foot_R"}) do
    local f=injuryFoot(name)
    check(not WTAGarou.HasWound(f),"clean foot is not a hidden wound")
    f.glass=true
    check(WTAGarou.HasWound(f) and f:movementPenalty()>0 and f.health==100,
        "reproduce full-HP, closed-looking glass foot: "..name)
    WTAGarou.ClearWound(f)
    check(not f.glass and f:movementPenalty()==0 and not WTAGarou.HasWound(f),
        "completed wound removes glass and its real movement penalty")
    f.stitchFlag=true; f.stitchTime=12
    WTAGarou.ClearWound(f)
    check(not f.stitchFlag and f.stitchTime==0 and f:movementPenalty()==0
        and f.scratchTime==0 and f.bleedingTime==0,"stitch removal side effects are cleared AFTER removal")
    f.stitchTime=8
    check(WTAGarou.HasWound(f),"orphan stitch timer discovered without visible stitched flag")
    WTAGarou.ClearWound(f)
    check(f:movementPenalty()==0,"orphan stitch timer repaired")
    f.bullet=true
    WTAGarou.ClearWound(f)
    check(not f.bullet and not f.deepFlag and f.deepWoundTime==0 and f.bleedingTime==0,
        "ordinary bullet expelled before removal-generated deep wound is closed")
    for _,timer in ipairs({"scratchTime","cutTime","deepWoundTime","biteTime"}) do
        f[timer]=6
        check(WTAGarou.HasWound(f),"orphan timer discovered: "..timer)
        WTAGarou.ClearWound(f)
        check(f[timer]==0,"orphan timer removed: "..timer)
    end
end
local function advanceRegen(pl,seconds)
    for _=1,seconds do clock=clock+1; WTAGarou.Regenerate(pl,pl:getBodyDamage()) end
end
local oldCase=newPlayer()
local oldData=WTAGarou.GetData(oldCase); oldData.isGarou=true; oldData.form="Crinos"
oldCase.parts={injuryFoot("Foot_L")}; oldCase.parts[1].glass=true
WTAGarou.Regenerate(oldCase,oldCase:getBodyDamage())
advanceRegen(oldCase,W-1)
check(oldCase.parts[1].glass,"existing hidden-glass case waits the real W s regeneration, not an instant cheat")
advanceRegen(oldCase,1)
check(not oldCase.parts[1].glass and oldCase.parts[1]:movementPenalty()==0,"existing stuck save repaired on ordinary completion")
oldCase.parts[1].glass=true; oldData.form="Homid"
WTAGarou.Regenerate(oldCase,oldCase:getBodyDamage()); advanceRegen(oldCase,W+5)
check(oldCase.parts[1].glass,"Homid does not secretly auto-cure retained glass")
oldData.form="Crinos"; oldCase.parts[1].burn=10; oldData.silverBurns={Foot_L=true}
WTAGarou.Regenerate(oldCase,oldCase:getBodyDamage()); advanceRegen(oldCase,W+5)
check(oldCase.parts[1].glass and oldCase.parts[1].burn==10,"silver blocks foreign-body cleanup too")
oldCase.parts[1].burn=0
WTAGarou.Regenerate(oldCase,oldCase:getBodyDamage()); advanceRegen(oldCase,W)
check(not oldCase.parts[1].glass,"foreign-body repair resumes after silver burn heals naturally")
oldCase.parts[1].glass=true
local glassSetter=oldCase.parts[1].setHaveGlass
oldCase.parts[1].setHaveGlass=function() error("simulate incompatible setter") end
WTAGarou.Regenerate(oldCase,oldCase:getBodyDamage()); advanceRegen(oldCase,W)
check(oldCase.parts[1].glass and oldData.woundProgress.Foot_L==1,
    "failed cleanup retains mature progress instead of falsely declaring cured")
oldCase.parts[1].setHaveGlass=glassSetter; advanceRegen(oldCase,1)
check(not oldCase.parts[1].glass and oldData.woundProgress.Foot_L==nil,
    "recovered setter completes repair on next tick without another full window")
oldCase.parts[1].biteTime=12
WTAGarou.Regenerate(oldCase,oldCase:getBodyDamage()); advanceRegen(oldCase,W)
check(oldCase.parts[1].biteTime==12,"hidden/bandaged bite timer still uses 300s, not the ordinary W s")
advanceRegen(oldCase,300-W)
check(oldCase.parts[1].biteTime==0,"hidden bite closes on unchanged full bite window")
local twinA,twinB=newPlayer(),newPlayer() -- identical numeric online ID!
for _,who in ipairs({twinA,twinB}) do
    local data=WTAGarou.GetData(who); data.form="Crinos"; data.isGarou=true
    who.parts={injuryFoot("Foot_L")}; who.parts[1].glass=true; who.parts[1].health=50
    WTAGarou.Regenerate(who,who:getBodyDamage())
end
for _=1,W do
    clock=clock+1
    WTAGarou.Regenerate(twinA,twinA:getBodyDamage())
    WTAGarou.Regenerate(twinB,twinB:getBodyDamage())
end
check(not twinA.parts[1].glass and not twinB.parts[1].glass
    and twinA.parts[1].health==100 and twinB.parts[1].health==100,
    "two local characters sharing an offline ID heal independently")
local function freshRegen(form)
    p = newPlayer(); d = WTAGarou.GetData(p); d.isGarou = true; d.form = form
    p.parts = { newPart("Hand_L"), newPart("Torso_Upper") }
    p.parts[2].bittenFlag = false      -- 0.4.19: only the hand carries the bite
    p.stats.ZombieInfection = 30
    p.infected = true
end
freshRegen("Crinos")
local bd = p:getBodyDamage()
WTAGarou.Regenerate(p, bd)          -- prime clock
clock = clock + 1
WTAGarou.Regenerate(p, bd)
close(p.parts[1].health, 40 + HP, "Crinos heals HP (1.2)/s per part")
close(p.stats.ZombieInfection, 30 - 100 / 300, "Crinos purges the Wyrm Infection at 100/300 per second (0.4.19, was 100/60)")
check(p.parts[1].bittenFlag, "bite flag not cleared before the clear window")
for _ = 1, 59 do clock = clock + 1; WTAGarou.Regenerate(p, bd) end
check(p.parts[1].health >= 100, "part fully healed within a minute")
-- 0.4.19: the bitten part keeps its bite (and, with it, the scratch on the
-- same part) for the Wyrm clock; ordinary wounds now clear at 75 s.
check(p.parts[1].bittenFlag, "bite NOT cleared after 60 s in Crinos (0.4.19: bites run on the 300 s Wyrm clock)")
check(p.parts[1].bleedingTime == 0 and p.parts[2].fracture > 0,
    "bleeding tapers but ordinary flags remain at 60s after modest slowdown")
check(p.parts[1].infectedWound and p.parts[1].deepWoundTime == 5,
    "a bitten part keeps its wound flags together until the bite clock (clearWound is per part)")
check(p.infected == true, "Wyrm Infection still present after 60 s in Crinos")
check(d.infectionBurn and d.infectionBurn > 19 and d.infectionBurn < 21, "purge progress about 20% after 60 s")
for _ = 1, W - 60 do clock = clock + 1; WTAGarou.Regenerate(p, bd) end
check(p.parts[2].fracture==0 and p.parts[2].burn==0,"ordinary wound completes at W s")
for _ = 1, 300 - W - 1 do clock = clock + 1; WTAGarou.Regenerate(p, bd) end
check(p.parts[1].bittenFlag and p.infected == true, "bite and Wyrm Infection still present at 299 s")
clock = clock + 1; WTAGarou.Regenerate(p, bd)
check(not p.parts[1].bittenFlag and not p.parts[1].scratchedFlag, "bite closed after 300 s in Crinos")
check(p.stats.ZombieInfection == 0 and p.infected == false, "Wyrm Infection gone after five minutes in Crinos")
check(d.infectionBurn == nil, "burn-off counter reset once cured")
-- 0.4.12: wounds age individually. A NEW scratch after the form has been held
-- is NOT cleared on the next tick (0.4.11 did exactly that: "wounds
-- disappeared instantly"); it closes 75 s after it landed.
p.parts[1].scratchedFlag = true
clock = clock + 1; WTAGarou.Regenerate(p, bd)      -- wound first seen here
check(p.parts[1].scratchedFlag, "fresh scratch survives the next tick in long-held Crinos")
for _ = 1, W - 1 do clock = clock + 1; WTAGarou.Regenerate(p, bd) end
check(p.parts[1].scratchedFlag, "fresh scratch still present W-1 s after first seen")
clock = clock + 1; WTAGarou.Regenerate(p, bd)
check(not p.parts[1].scratchedFlag, "fresh scratch closed W s after it landed")
-- A fresh bite on a long-held Crinos also waits its full 300 s.
p.parts[1].bittenFlag = true
clock = clock + 1; WTAGarou.Regenerate(p, bd)
for _ = 1, 299 do clock = clock + 1; WTAGarou.Regenerate(p, bd) end
check(p.parts[1].bittenFlag, "fresh bite still present 299 s after it landed")
clock = clock + 1; WTAGarou.Regenerate(p, bd)
check(not p.parts[1].bittenFlag, "fresh bite closed 300 s after it landed")
p.parts[2].fracture = 5
clock = clock + 30; WTAGarou.Regenerate(p, bd)
check(p.parts[2].fracture == 5, "a fracture on another part keeps its own clock")
freshRegen("Hispo"); bd = p:getBodyDamage()
WTAGarou.Regenerate(p, bd); clock = clock + 1; WTAGarou.Regenerate(p, bd)
close(p.parts[1].health, 40.56, "Hispo heals at about a third of Crinos")
close(p.stats.ZombieInfection, 30 - 100 / 900, "Hispo purges the Wyrm Infection at a third of the Crinos rate")
for _ = 1, 100 do clock = clock + 1; WTAGarou.Regenerate(p, bd) end
check(p.parts[2].scratchedFlag, "Hispo does not clear flags before its 225 s window")
for _ = 1, 124 do clock = clock + 1; WTAGarou.Regenerate(p, bd) end
check(not p.parts[2].scratchedFlag and p.parts[2].fracture == 0, "Hispo clears the un-bitten part's flags after 225 s")
check(p.parts[1].bittenFlag and p.parts[1].scratchedFlag and p.infected == true,
    "Hispo keeps the bitten part's flags and the Wyrm Infection past 225 s")
for _ = 1, 674 do clock = clock + 1; WTAGarou.Regenerate(p, bd) end   -- 899 s held
check(p.parts[1].bittenFlag and p.infected == true, "Hispo: bite and Wyrm Infection still there at 899 s")
clock = clock + 1; WTAGarou.Regenerate(p, bd)
check(not p.parts[1].bittenFlag and p.infected == false, "Hispo clears the bite and the Wyrm Infection after 900 s")
freshRegen("Lupus"); bd = p:getBodyDamage()
WTAGarou.Regenerate(p, bd); clock = clock + 60; WTAGarou.Regenerate(p, bd)
close(p.parts[1].health, 40, "Lupus keeps the vanilla healing clock")
check(p.stats.ZombieInfection == 30, "Lupus does not cure the virus")
freshRegen("Crinos"); bd = p:getBodyDamage()
d.silverBurns = { Hand_L = 1e9 }
WTAGarou.Regenerate(p, bd); clock = clock + 1; WTAGarou.Regenerate(p, bd)
close(p.parts[1].health, 40, "silver-burned part never regenerates")
close(p.parts[2].health, 40 + HP, "other parts still regenerate")


-- 0.4.17: B42 recomputes the ZOMBIE_INFECTION stat every tick while
-- BodyDamage.isInfected. Decrementing the stat never cured anyone (the
-- "At Breaking Point" moodle that never left). The cure is now counted in
-- mod data and, once it reaches 100, clears the flag, parts and timers.
-- 0.4.19: that takes 300 s of Crinos.
freshRegen("Crinos"); bd = p:getBodyDamage()
WTAGarou.Regenerate(p, bd)
for _ = 1, 299 do
    clock = clock + 1
    p.stats.ZombieInfection = 30          -- engine pins the stat every tick
    WTAGarou.Regenerate(p, bd)
    check(p.infected == true, "not cured before 300 s of Crinos even with a pinned stat")
end
clock = clock + 1; p.stats.ZombieInfection = 30; WTAGarou.Regenerate(p, bd)
check(p.infected == false and p.stats.ZombieInfection == 0 and p.infectionTime == -1,
    "pinned infection cleared after 300 s: flag, stat and infection time")
check(not p.parts[1].zInfected and not p.parts[2].zInfected, "per-part infection flags cleared with the cure")
check(d.infectionBurn == nil, "burn-off counter reset once cured")
-- RageSync payload carries the purge progress for the health panel line.
freshRegen("Crinos"); bd = p:getBodyDamage()
WTAGarou.Regenerate(p, bd)
for _ = 1, 30 do clock = clock + 1; WTAGarou.Regenerate(p, bd) end
local sync = WTAGarou.RageSyncArgs(d)
check(sync.wyrm and sync.wyrm > 9 and sync.wyrm < 11, "RageSync carries wyrm purge progress (~10% after 30 s)")
check(sync.form == "Crinos" and sync.rage == d.rage, "RageSync still carries rage and form")
-- 0.4.85: an unlocked identity is sent as FALSE (a nil key never reaches the client, so
-- DebugResetIdentity left the startup panel locked until a relog).
d.identityLocked = nil; d.auspiceLocked = nil
check(WTAGarou.RageSyncArgs(d).identityLocked == false and WTAGarou.RageSyncArgs(d).auspiceLocked == false,
    "RageSync says identityLocked=false / auspiceLocked=false explicitly when unlocked")
d.identityLocked = true; d.auspiceLocked = true
check(WTAGarou.RageSyncArgs(d).identityLocked == true and WTAGarou.RageSyncArgs(d).auspiceLocked == true, "...and true when locked")
d.identityLocked = nil; d.auspiceLocked = nil

-- 0.4.19: the Wyrm purge AND wound progress are cumulative across forms.
-- 2 min Crinos (40%) then 9 min Hispo (60%) cures the bite and the virus;
-- a Homid stretch in between pauses without losing anything.
freshRegen("Crinos"); bd = p:getBodyDamage()
WTAGarou.Regenerate(p, bd)
for _ = 1, 120 do clock = clock + 1; WTAGarou.Regenerate(p, bd) end
check(p.infected == true and p.parts[1].bittenFlag, "2 min Crinos: still infected and bitten")
check(d.infectionBurn > 39.9 and d.infectionBurn < 40.1, "2 min Crinos = 40% purged")
check(d.woundProgress.Hand_L > 0.399 and d.woundProgress.Hand_L < 0.401, "2 min Crinos = 40% of the bite")
d.form = "Homid"
WTAGarou.Regenerate(p, bd)
for _ = 1, 300 do clock = clock + 1; WTAGarou.Regenerate(p, bd) end
check(d.infectionBurn > 39.9 and d.infectionBurn < 40.1 and d.woundProgress.Hand_L > 0.399, "5 min Homid pauses both clocks, nothing lost")
d.form = "Hispo"
WTAGarou.Regenerate(p, bd)
for _ = 1, 539 do clock = clock + 1; WTAGarou.Regenerate(p, bd) end
check(p.infected == true and p.parts[1].bittenFlag, "8:59 in Hispo: not quite there")
clock = clock + 1; WTAGarou.Regenerate(p, bd)
check(p.infected == false and not p.parts[1].bittenFlag and d.infectionBurn == nil and d.woundProgress.Hand_L == nil,
    "2 min Crinos + 9 min Hispo cures the Wyrm Infection and closes the bite")
-- Ordinary wounds are cumulative too: 30 s Crinos (30/W of the way) plus the
-- remainder of the 225 s Glabro window closes a scratch (0.4.68: 30 + 158 s).
local glabroRest = math.ceil((1 - 30 / W) * WTAGarou.Regeneration.CLEAR_WOUNDS_AFTER.Glabro - 1e-9)
freshRegen("Crinos"); bd = p:getBodyDamage(); p.parts[2].fracture = 0; p.parts[2].burn = 0
WTAGarou.Regenerate(p, bd)
for _ = 1, 30 do clock = clock + 1; WTAGarou.Regenerate(p, bd) end
check(p.parts[2].scratchedFlag, "30 s Crinos: scratch still open")
d.form = "Glabro"; WTAGarou.Regenerate(p, bd)
for _ = 1, glabroRest - 1 do clock = clock + 1; WTAGarou.Regenerate(p, bd) end
check(p.parts[2].scratchedFlag, "30 s Crinos + " .. (glabroRest - 1) .. " s Glabro: scratch still open")
clock = clock + 1; WTAGarou.Regenerate(p, bd)
check(not p.parts[2].scratchedFlag, "30 s Crinos + " .. glabroRest .. " s Glabro closes the scratch")
freshRegen("Homid"); bd = p:getBodyDamage()
WTAGarou.Regenerate(p, bd); clock = clock + 100; WTAGarou.Regenerate(p, bd)
check(p.infected == true, "Homid never cures the virus")

-- 0.4.17 silver contact burns (server/WTAGarouSilver.lua).
dofile(root .. "/42/media/lua/shared/WTAGarouSilverAmmo.lua")  -- 0.4.59: coat bookkeeping used by the hit handler
dofile(root .. "/42/media/lua/server/WTAGarouSilver.lua")
local S = WTAGarou.Silver
local function mkItem(fullType, location, name)
    return {
        getFullType = function() return fullType end,
        getDisplayName = function() return name or fullType end,
        getBodyLocation = function() return location and ("base:" .. location) or nil end,
        getModData = function() return {} end,
        hasTag = function() return false end,
    }
end
local function mkWorn(items)
    return { size = function() return #items end, get = function(_, i) return { getItem = function() return items[i + 1] end } end }
end
freshRegen("Homid"); bd = p:getBodyDamage()
p.parts = { newPart("Hand_R"), newPart("Hand_L"), newPart("Head"), newPart("Neck") }
for _, bp in ipairs(p.parts) do bp.burn = 0; bp.health = 40 end
p.worn = {}
function p:getWornItems() return mkWorn(self.worn) end
function p:getPrimaryHandItem() return self.primary end
function p:getSecondaryHandItem() return self.secondary end
check(S.itemIsSilver(mkItem("Base.Necklace_Silver", "Necklace")), "Silver in the type marks an item")
check(S.itemIsSilver(mkItem("Base.Pendant", "Necklace", "Silver Pendant")), "Silver in the display name marks an item")
check(not S.itemIsSilver(mkItem("Base.Necklace_Gold", "Necklace", "Gold Necklace")), "gold is not silver")
p.primary = mkItem("Base.SilverKnife", nil, "Silver Knife")
S.scan(p, 0.5)
check(p.parts[1].burn == 0, "held silver has not burned the hand before CONTACT_SECONDS")
local fresh = S.scan(p, 0.5)
check(p.parts[1].burn == WTAGarou.Silver.INITIAL_BURN and fresh[1] == "Hand_R", "1 s of bare-hand silver starts a mild burn")
check(d.silverBurns.Hand_R == true and p.parts[2].burn == 0, "only the holding hand is flagged")
for _ = 1, 10 do S.scan(p, 1.0) end
close(p.parts[1].burn, S.contactSeverity(11), "contact follows the S-curve")
close(S.contactSeverity(1),2,"mild onset")
close(S.contactSeverity(60),75,"one-minute severity plateau")
close(S.contactSeverity(120),75,"prolonged contact remains capped")
check(S.contactSeverity(35)-S.contactSeverity(25)>S.contactSeverity(11)-S.contactSeverity(1),
    "middle of curve steepens relative to onset")
p.worn = { mkItem("Base.Gloves_Leather", "Hands", "Leather Gloves") }
p.parts[2].burn = 0; d.silverContact = {}
for _ = 1, 30 do S.scan(p, 1.0) end
check(p.parts[2].burn == 0, "gloves protect a hand from HELD silver")
p.worn = { mkItem("Base.Gloves_Leather", "Hands", "Leather Gloves"), mkItem("Base.Earrings_Silver", "Ears", "Silver Earrings"),
           mkItem("Base.Necklace_Silver", "Necklace", "Silver Necklace") }
p.primary = nil
for _ = 1, 20 do S.scan(p, 1.0) end
check(p.parts[3].burn > 0 and d.silverBurns.Head == true, "silver earrings burn the head (Ears -> Head)")
check(p.parts[4].burn > 0 and d.silverBurns.Neck == true, "silver necklace burns the neck")
-- Regeneration skips the flagged parts while their burn heals, then resumes.
d.form = "Crinos"
WTAGarou.Regenerate(p, bd); clock = clock + 1; WTAGarou.Regenerate(p, bd)
close(p.parts[3].health, 40, "silver-burned head does not regenerate")
close(p.parts[2].health, 40 + HP, "unburned hand regenerates")
check(p.parts[3].burn > 0, "Crinos regeneration does not clear the silver burn")
p.parts[3].burn = 0   -- healed at the vanilla pace
clock = clock + 1; WTAGarou.Regenerate(p, bd)
check(d.silverBurns.Head == nil, "flag lifted once the burn has healed")
close(p.parts[3].health, 40 + HP, "super healing resumes the moment the burn is gone")

-- 0.4.59/0.4.62: sealed silver (glass between silver and skin) is a contact
-- exception. Silver nitrate is a fluid now, so the exemption is "any fluid
-- container that is not itself a silvered/forged item": the jar of nitrate,
-- a bottle of it, a saucepan of it. The name rule still marks a vessel whose
-- UI name says Silver as silver for weapon hits.
local function sealed(fullType, name, md, fluidContainer)
    local it = mkItem(fullType, nil, name)
    it.getModData = function() return md or {} end
    it.isFluidContainer = function() return fluidContainer ~= false end
    return it
end
local jar = sealed("Base.EmptyJar", "Jar (Silver Nitrate)")
local rawJar = sealed("Base.BeerEmpty", "Beer Bottle (Raw Silver Nitrate)")
local coatedPan = sealed("Base.Saucepan", "Saucepan", { WTAGarou_SilverCoat = 7 })
local forgedPan = sealed("Base.Saucepan", "Silver Saucepan", { WTAGarou_Silver = true })
check(S.itemIsSilver(jar) and S.contactExempt(jar) and not S.contactSilver(jar), "jar of silver nitrate: silver by name, but sealed")
check(S.contactExempt(rawJar), "any fluid container is a sealed vessel")
check(not S.contactExempt(coatedPan) and S.contactSilver(coatedPan), "a coated saucepan (fluid container) still burns through its coat")
check(not S.contactExempt(forgedPan) and S.contactSilver(forgedPan), "a forged silver saucepan still burns")
check(not S.contactExempt(mkItem("Base.SilverKnife", nil, "Silver Knife")) and S.contactSilver(mkItem("Base.SilverKnife", nil, "Silver Knife")), "a silver knife is bare silver")
check(not S.contactExempt(sealed("Base.Necklace_Silver", "Silver Necklace", nil, false)), "non-container silver is never exempt")
p.worn = {}; p.primary = jar; p.secondary = nil
p.parts[1].burn = 0; d.silverContact = {}; d.silverBurns = {}
for _ = 1, 30 do S.scan(p, 1.0) end
check(p.parts[1].burn == 0 and d.silverBurns.Hand_R == nil, "30 s holding the jar bare-handed burns nothing")
check(next(S.contacts(p)) == nil, "contact set is empty for sealed silver")
p.primary = nil


-- 0.4.19: silver detection never calls InventoryItem.hasTag(String) (Java
-- exception in 42.20.2); tags are compared by name through getTags().
local function tagged(fullType, location, name, tags)
    local it = mkItem(fullType, location, name)
    it.hasTag = function() error("hasTag(Clothing, String) has no implementation in 42.20.2") end
    it.getTags = function()
        local i = 0
        return { iterator = function() return { hasNext = function() return i < #tags end, next = function() i = i + 1; return tags[i] end } end }
    end
    return it
end
check(S.itemIsSilver(tagged("Base.Ring", "Ring", "Plain Ring", { "Silver" })), "a Silver item tag marks an item without hasTag(String)")
check(S.itemIsSilver(tagged("Base.Ring", "Ring", "Plain Ring", { "base:silver" })), "0.4.62: the namespaced lower-case id getTags() really yields in-game matches too")
check(S.tagKey("base:Silver") == "silver" and S.tagKey(nil) == "", "tagKey strips the namespace")
check(not S.itemIsSilver(tagged("Base.Ring", "Ring", "Plain Ring", { "Jewelry" })), "other tags do not")
check(not S.itemIsSilver(tagged("Base.Shirt", "Tshirt", "T-Shirt", {})), "no tags, no silver, no exception")
-- 0.4.20: silver rounds.
local function gun(ammo, md, ranged)
    local g = mkItem("Base.HuntingRifle", nil, "Hunting Rifle")
    g.isRanged = function() return ranged ~= false end
    g.getAmmoType = function() return ammo end
    g.getModData = function() return md or {} end
    return g
end
check(S.firesSilver(gun("Base.Bullets308", { WTAGarou_SilverAmmo = true })), "a firearm flagged WTAGarou_SilverAmmo fires silver")
check(S.firesSilver(gun("Base.Bullets308Silver")), "a silver-named ammo type fires silver")
check(not S.firesSilver(gun("Base.Bullets308")), "plain rounds are not silver")
check(not S.firesSilver(gun("Base.Bullets308Silver", nil, false)), "a melee weapon never 'fires'")
check(not S.itemIsSilver(gun("Base.Bullets308", { WTAGarou_SilverAmmo = true })), "silver rounds do not make the rifle itself silver to the touch")
-- lower-case Build 42 location ids resolve to body parts and gloves
p.parts = { newPart("Hand_R"), newPart("Hand_L"), newPart("Head"), newPart("Neck") }
for _, bp in ipairs(p.parts) do bp.burn = 0; bp.health = 40 end
d.silverBurns = {}; d.silverContact = {}
p.worn = { mkItem("Base.Earrings_Silver", "ears", "Silver Earrings"), mkItem("Base.Necklace_Silver", "necklace", "Silver Necklace") }
p.primary = nil
for _ = 1, 20 do S.scan(p, 1.0) end
check(p.parts[3].burn > 0 and d.silverBurns.Head == true, "lower-case 'ears' burns the head")
check(p.parts[4].burn > 0 and d.silverBurns.Neck == true, "lower-case 'necklace' burns the neck")
for _, bp in ipairs(p.parts) do bp.burn = 0 end
d.silverBurns = {}; d.silverContact = {}
p.worn = { mkItem("Base.Gloves_Leather", "hands", "Leather Gloves") }
p.primary = mkItem("Base.SilverKnife", nil, "Silver Knife")
for _ = 1, 30 do S.scan(p, 1.0) end
check(p.parts[1].burn == 0, "lower-case 'hands' gloves still protect from held silver")
p.primary = nil; p.worn = {}
-- 0.4.28: every spelling/case and modded named item is eligible; this is
-- unrelated to which items the debug kit happens to grant.
check(S.itemIsSilver(mkItem("OtherMod.SILVER_Tool",nil,"Tool")),"all-uppercase silver type")
check(S.itemIsSilver(mkItem("OtherMod.Tool",nil,"sIlVeR Tool")),"mixed-case display name")
local factors={}
WTAGarouJava={setSilverBurnDamage=function(bp,factor) factors[bp]=factor end}
p.parts={newPart("Neck"),newPart("Torso_Upper"),newPart("Hand_R")}
for _,bp in ipairs(p.parts) do
    bp.burn=0
    function bp:setNeedBurnWash(v) self.needsWash=v end
    function bp:setLastTimeBurnWash(v) self.lastWash=v end
end
d.silverBurns={}; d.silverContact={}
p.worn={mkItem("Base.NecklaceLong_Silver","Necklace_Long")}
S.scan(p,1)
check(p.parts[1].burn==2 and p.parts[2].burn==2 and p.parts[3].burn==0,"long necklace starts mild neck and torso wounds")
check(p.parts[1].needsWash and p.parts[2].needsWash,"silver burns still need washing")
close(factors[p.parts[1]],0.04,"new burn gets four-percent vanilla damage factor")
p.worn={}
S.scan(p,1)
check(p.parts[1].burn==2 and factors[p.parts[1]]==0.04,"removal stops growth but wound/reduced damage remain")
p.parts[1].burn=80; p.worn={mkItem("Base.Necklace_Silver","Necklace")}
S.scan(p,1)
check(p.parts[1].burn==80,"lower new cap must never heal a pre-existing severe burn")
close(factors[p.parts[1]],0.85,"severe existing burn capped at eighty-five-percent native tick damage")
p.worn={}; p.parts[1].burn=0; S.scan(p,1)
close(factors[p.parts[1]],1,"healed wound clears damage override")
WTAGarouJava=nil
-- 0.4.41: every burn application is announced to the owner (contact scan
-- AND silver weapon hits), through one path, so the client can react.
local reacted={}
WTAGarou.SilverReact=function(player,part) reacted[#reacted+1]={player=player,part=part} end
d.silverBurns={}; d.silverContact={}; p.parts[1].burn=0; p.parts[2].burn=0
p.worn={mkItem("Base.NecklaceLong_Silver","Necklace_Long")}
S.scanPlayer(p)
check(#reacted==2 and reacted[1].player==p and reacted[1].part=="Neck" and reacted[2].part=="Torso_Upper",
    "contact scan announces each freshly burned part to the owner")
S.scanPlayer(p); S.scanPlayer(p)
check(#reacted==2,"continued contact is not a new application")
p.worn={}
local hitHandler=Events.OnWeaponHitCharacter.handlers[#Events.OnWeaponHitCharacter.handlers]
local blade=mkItem("Base.SilverKnife",nil,"Silver Knife")
d.silverBurns={}
p.parts[1].burn=0
hitHandler({},p,blade,1)
check(#reacted==3 and reacted[3].part==p.parts[1]:getType(),"a silver weapon hit announces the struck part")
hitHandler({},p,blade,1)
check(#reacted==4,"a second hit is a second application (the client cue rate-limits)")
hitHandler({},p,mkItem("Base.Axe",nil,"Axe"),1)
check(#reacted==4,"a plain weapon never announces a silver burn")
-- 0.4.58 (Wits W4): with the Java weapon-hit recorder present, the burn
-- waits one tick and lands on the part the engine actually wounded.
local recorded={}
WTAGarouJava={takeWeaponHitPart=function(target,window) local v=recorded[target]; recorded[target]=nil; return v or -1 end}
check(S.locatedBurnAvailable(),"located burn available with the recorder")
for _,bp in ipairs(p.parts) do bp.burn=0 end
d.silverBurns={}
hitHandler({},p,blade,1)
check(#reacted==4 and p.parts[1].burn==0 and p.parts[3].burn==0,"with the recorder, nothing burns at hit time")
recorded[p]=2 -- engine wounded parts[3] (Hand_R)
check(S.resolvePendingHits()==1,"next tick resolves one pending hit")
check(p.parts[3].burn>0 and p.parts[1].burn==0 and p.parts[2].burn==0,"the wounded part burns, not a random one")
check(#reacted==5 and reacted[5].part=="Hand_R","announce names the wounded part")
hitHandler({},p,blade,1) -- clothing absorbed the hit: no record
check(S.resolvePendingHits()==0 and #reacted==5,"a hit the clothing stopped burns nothing")
check(S.resolvePendingHits()==0,"queue drained")
hitHandler({},p,blade,1); hitHandler({},p,blade,1)
recorded[p]=0
check(S.resolvePendingHits()==1 and p.parts[1].burn>0,"two hits in one tick share the recorder's single latest part")
-- silver rounds: per-shot flag decides
local gunShot=gun("Base.Bullets308",{WTAGarou_SilverShot=true,WTAGarou_SilverAmmo=3})
check(S.firesSilver(gunShot),"a shot flagged silver fires silver")
check(not S.firesSilver(gun("Base.Bullets308",{WTAGarou_SilverShot=false,WTAGarou_SilverAmmo=3})),"silver still in the tube but this shot ordinary: no burn")
check(S.firesSilver(gun("Base.Bullets308",{WTAGarou_SilverAmmo=2})),"no shot flag yet: a counted silver load counts")
check(not S.firesSilver(gun("Base.Bullets308",{WTAGarou_SilverAmmo=0})),"zero count is not silver (Lua 0 is truthy)")
WTAGarouJava=nil
check(not S.locatedBurnAvailable(),"without the recorder the random-part fallback is used")
-- 0.4.59: a silver nitrate coat is silver while charges remain and spends
-- one charge per landed hit, zombie or Garou, then tells the wielder.
local coatMd = { WTAGarou_SilverCoat = 2, WTAGarou_CoatName = "Axe" }
local coated = mkItem("Base.Axe", nil, "Silvered Axe (2)")
coated.getModData = function() return coatMd end
coated.setName = function(_, v) coated.newName = v end
coated.getDisplayName = function() return coated.newName or "Silvered Axe (2)" end
check(S.itemIsSilver(coated), "a coated weapon is silver while charges remain")
local flashes = {}
WTAGarou.HUD = { instance = { flashDenial = function(_, r) flashes[#flashes + 1] = r end } }
getSpecificPlayer = nil
local zombie = { getBodyDamage = function() return nil end }
local before = #reacted
hitHandler({}, zombie, coated, 1)
check(coatMd.WTAGarou_SilverCoat == 1 and coated.newName == "Silvered Axe (1)" and #flashes == 0, "a zombie hit spends a charge, no message yet")
hitHandler({}, p, coated, 1)
check(coatMd.WTAGarou_SilverCoat == nil and coated.newName == "Axe" and flashes[1] == "silver_worn_off", "last charge: name restored, wielder told")
check(#reacted == before + 1, "that final coated hit still burned the Garou")
hitHandler({}, p, coated, 1)
check(#reacted == before + 1 and #flashes == 1, "a worn-off axe is an ordinary axe")
local hudText = assert(io.open(root .. "/42/media/lua/client/WTAGarouHUD.lua")):read("*a")
check(hudText:find("silver_worn_off", 1, true) ~= nil, "HUD has a line for the worn-off coat")
WTAGarou.HUD = nil
-- 0.4.72: multiplayer relay. On a client, a hit on ANOTHER player is not
-- burned locally (she is a proxy here) but sent to the server; the server
-- checks the attacker's weapon and reach and forwards it to her client,
-- which burns itself through the usual path.
isClient = function() return true end
local toServer = {}
local oldToServer = WTAGarou.Net.ToServer
WTAGarou.Net.ToServer = function(who, cmd, args) toServer[#toServer + 1] = { who = who, cmd = cmd, args = args } end
local wife = newPlayer(); wife.isLocalPlayer = function() return false end; wife.getOnlineID = function() return 11 end
wife.getBodyDamage = p.getBodyDamage; wife.parts = p.parts
local shooter = newPlayer(); shooter.isLocalPlayer = function() return true end
for _, bp in ipairs(p.parts) do bp.burn = 0 end
local reactedBefore = #reacted
hitHandler(shooter, wife, blade, 1.5)
check(#toServer == 0, "0.4.75: the attacker's client sends no relay (the server sees the hit itself)")
check(p.parts[1].burn == 0 and p.parts[2].burn == 0 and p.parts[3].burn == 0 and #reacted == reactedBefore, "client: nothing is burned on the proxy")
p.isLocalPlayer = function() return true end
hitHandler(shooter, p, blade, 1)
check(#toServer == 0 and #reacted == reactedBefore + 1, "client: a hit on the LOCAL player (self) still burns directly")
-- 0.4.75: the server burns the part the wound lands on. OnWeaponHitCharacter
-- fires on the server before the wound; the next tick's diff finds it.
isClient = function() return false end; isServer = function() return true end
for _, bp in ipairs(p.parts) do bp.burn = 0; bp.health = 100; bp.scratchedFlag = false; bp.bittenFlag = false; bp.bleedingTime = 0; bp.deepWoundTime = 0 end
p.parts[2].AddDamage = function(self, v) self.health = self.health - v end
wife.getOnlineID = function() return 11 end
wife.md = { WTAGarou = { isGarou = true } }
local pushed = {}
reactedBefore = #reacted
hitHandler(shooter, wife, blade, 1.5)
check(S.serverPendingCount() == 1 and p.parts[1].burn == 0 and p.parts[2].burn == 0, "server: the hit is queued with a snapshot; nothing burns before the wound exists")
p.parts[2].health = 88; p.parts[2].scratchedFlag = true        -- the engine's wound lands on part 2
check(S.resolveServerHits(function(pl) pushed[#pushed + 1] = pl end) == 1, "server: one part burned")
check(p.parts[2].burn > 0 and p.parts[1].burn == 0 and p.parts[3].burn == 0, "server: the WOUNDED part burns, not a random one")
check(math.abs(p.parts[2].health - (88 - 1.5)) < 1e-6, "server: Garou take the silver damage multiplier on that part (2x: +1.5)")
check(#pushed == 1 and pushed[1] == wife and #reacted == reactedBefore + 1 and reacted[#reacted].player == wife, "server: body pushed to her client at once and the owner told")
hitHandler(shooter, wife, blade, 1.5)
check(S.resolveServerHits(function(pl) pushed[#pushed + 1] = pl end) == 0 and #pushed == 1, "server: a hit the clothing absorbed (no part changed) burns nothing")
check(#S.woundedParts({ [0] = { health = 100 }, [1] = { health = 100, scratched = false } }, { [0] = { health = 100 }, [1] = { health = 100, scratched = true } }) == 1, "woundedParts: a new wound flag alone counts")
check(#S.woundedParts({ [0] = { health = 100 } }, { [0] = { health = 99.5 } }) == 1 and #S.woundedParts({ [0] = { health = 100 } }, { [0] = { health = 100 } }) == 0, "woundedParts: a health drop counts, no change does not")
check(S.WOUND_FLAGS[3] == "isDeepWounded" and S.WOUND_FLAGS[4] == "haveBullet", "wound flags use the engine's BodyPart method names")
-- 0.4.76: a silver round that stays in burns until it is pulled.
do
    local rifle = gun("Base.Bullets308Silver")
    for _, bp in ipairs(p.parts) do bp.burn = 0; bp.health = 100; bp.scratchedFlag = false; bp.bullet = false end
    for _, bp in ipairs(p.parts) do bp.haveBullet = function(self) return self.bullet == true end end
    p.parts[3].AddDamage = function(self, v) self.health = self.health - v end
    local cmds = {}
    local oldSSC = sendServerCommand
    sendServerCommand = function(pl, mod, cmd, args) cmds[#cmds + 1] = { pl = pl, cmd = cmd, args = args }; if oldSSC then oldSSC(pl, mod, cmd, args) end end
    hitHandler(shooter, wife, rifle, 1.2)
    p.parts[3].health = 70; p.parts[3].bullet = true; p.parts[3].bleedingTime = 5   -- the round lodges in part 3
    check(S.resolveServerHits(function() end) == 1 and p.parts[3].burn > 0, "server: the silver round burns the part it entered")
    local wd = WTAGarou.GetData(wife)
    check(wd.silverLodged and wd.silverLodged[p.parts[3]:getType()] == "bullet", "server: the part is marked as holding a silver-tip bullet")
    local lodgedCmd; for _, c in ipairs(cmds) do if c.cmd == S.LODGED_COMMAND then lodgedCmd = c end end
    check(lodgedCmd and lodgedCmd.pl == wife and lodgedCmd.args.lodged == true and lodgedCmd.args.kind == "bullet" and lodgedCmd.args.part == p.parts[3]:getType(), "server: the owner is told a silver-tip bullet is lodged")
    -- the knife: a melee silver hit never marks a bullet, even on a part that already holds a lead one
    p.parts[1].bullet = true
    hitHandler(shooter, wife, blade, 1.0); p.parts[1].health = 90; S.resolveServerHits(function() end)
    check(wd.silverLodged[p.parts[1]:getType()] == nil, "server: a blade hit on a part with a lead bullet does not mark it silver")
    p.parts[1].bullet = false
    -- the lodged step: creeping burn with its own low cap, never out while the bullet is in
    local key3 = p.parts[3]:getType()
    p.parts[3].burn = 0
    local bd = wife:getBodyDamage()
    check(S.lodgedStep(wife, wd, bd, 1) == 1 and p.parts[3].burn >= 0.5, "lodged: a healed burn is re-lit while the bullet is in")
    for _ = 1, 400 do S.lodgedStep(wife, wd, bd, 1) end
    check(math.abs(p.parts[3].burn - S.LODGED_MAX_BURN) < 1e-6 and S.LODGED_MAX_BURN < 75, "lodged: the burn creeps up to the small-piece cap, well under the contact plateau")
    check(wd.silverBurns[key3] == true, "lodged: the part keeps its silver-burn mark (regeneration stays blocked there)")
    p.parts[3].burn = 60
    S.lodgedStep(wife, wd, bd, 1)
    check(p.parts[3].burn == 60, "lodged: a bigger existing burn is never lowered")
    local n = #cmds
    p.parts[3].bullet = false                                   -- pulled with pliers / tweezers
    check(S.lodgedStep(wife, wd, bd, 1) == 0 and wd.silverLodged == nil, "lodged: once the bullet is out the mark is gone (the burn then heals like any other)")
    check(#cmds == n + 1 and cmds[#cmds].cmd == S.LODGED_COMMAND and cmds[#cmds].args.lodged == false and cmds[#cmds].args.part == key3, "lodged: the owner is told it is out")
    -- 0.4.77: silver fragments in a foot (engine haveGlass) use the same clock
    p.parts[2].haveGlass = function(self) return self.glass == true end
    p.parts[2].glass = true; p.parts[2].burn = 0
    check(S.markLodged(wife, p.parts[2], "shard") == true and wd.silverLodged[p.parts[2]:getType()] == "shard", "shard: fragments in a part are marked by kind")
    check(S.lodgedStep(wife, wd, bd, 1) == 1 and p.parts[2].burn >= 0.5, "shard: burns like a lodged bullet")
    p.parts[2].glass = false
    check(S.lodgedStep(wife, wd, bd, 1) == 0 and wd.silverLodged == nil and cmds[#cmds].args.kind == "shard" and cmds[#cmds].args.lodged == false, "shard: pulled with tweezers -> mark gone, owner told")
    sendServerCommand = oldSSC
end
isServer = function() return false end; isClient = function() return true end
-- server side
isClient = function() return false end; isServer = function() return true end
local sentBefore = #sent
shooter.getPrimaryHandItem = function() return blade end
shooter.getX = function() return 10 end; shooter.getY = function() return 10 end
wife.getX = function() return 14 end; wife.getY = function() return 10 end
local roster = { [11] = wife }
local function findPlayer(id) return roster[id] end
check(S.onHitCommand("WTAGarou", S.HIT_COMMAND, shooter, { target = 11, damage = 1.5 }, findPlayer) == true, "server: silver in hand + in reach -> relayed")
check(#sent == sentBefore + 1 and sent[#sent].cmd == S.HIT_RELAY and sent[#sent].args.damage == 1.5, "server: SilverHitRelay goes to the struck player's client")
shooter.getPrimaryHandItem = function() return mkItem("Base.Axe", nil, "Axe") end
check(S.onHitCommand("WTAGarou", S.HIT_COMMAND, shooter, { target = 11, damage = 1.5 }, findPlayer) == false, "server: a plain axe is refused")
shooter.getPrimaryHandItem = function() return blade end
wife.getX = function() return 10 + S.HIT_MAX_TILES + 1 end
check(S.onHitCommand("WTAGarou", S.HIT_COMMAND, shooter, { target = 11, damage = 1.5 }, findPlayer) == false, "server: out of reach is refused")
wife.getX = function() return 14 end
check(S.onHitCommand("WTAGarou", S.HIT_COMMAND, shooter, { target = 99 }, findPlayer) == false, "server: unknown target is ignored")
check(S.onHitCommand("WTAGarou", "Other", shooter, { target = 11 }, findPlayer) == false, "server: other commands untouched")
check(S.relayCount() == 1, "one relay counted")
-- struck player's client
isServer = function() return false end; isClient = function() return true end
for _, bp in ipairs(p.parts) do bp.burn = 0 end
d.silverBurns = {}
reactedBefore = #reacted
check(S.applyRelayedHit(p, { damage = 1.5 }) == true, "client: relayed hit applied")
local burned = 0; for _, bp in ipairs(p.parts) do if bp.burn > 0 then burned = burned + 1 end end
check(burned == 1 and #reacted == reactedBefore + 1 and reacted[#reacted].player == p, "client: one of our own parts burns and the owner is told")
isClient = function() return false end
WTAGarou.Net.ToServer = oldToServer
WTAGarou.SilverReact=nil
check(WTAGarou.SilverCue.forForm("Homid")=="PainFromScratch" and WTAGarou.SilverCue.forForm("Glabro")=="PainFromScratch"
    and WTAGarou.SilverCue.forForm("Crinos")=="WTAGarou_CrinosGrowl" and WTAGarou.SilverCue.forForm("Hispo")=="WTAGarou_HispoGrowl"
    and WTAGarou.SilverCue.forForm("Lupus")=="WTAGarou_WolfGrowl","silver cue per form: vanilla ouch, Crinos/Hispo/wolf growls")
check(WTAGarou.SilverCue.isVoice("PainFromScratch") and not WTAGarou.SilverCue.isVoice("WTAGarou_WolfGrowl"),"only the ouch is a vanilla voice event")
check(WTAGarou.SilverCue.forForm(nil)=="PainFromScratch","unknown form falls back to the ouch")
-- 0.4.75: health pool on the server without Java: refund the untaken share
-- of every acute part drop between sweeps (bleeding ticks are too small).
do
    local function mk(h) local t = { health = h }; t.add = function(v) t.health = t.health + v end; return t end
    local parts = { mk(100), mk(100), mk(100) }
    local snap = WTAGarou.ToughnessRefund(parts, nil, 0.4)
    check(snap[1] == 100 and #snap == 3, "first sweep only records")
    parts[2].health = 60                                   -- a 40-point hit on part 2
    local snap2, back = WTAGarou.ToughnessRefund(parts, snap, 0.4)
    check(math.abs(back - 24) < 1e-6 and math.abs(parts[2].health - 84) < 1e-6 and math.abs(snap2[2] - 84) < 1e-6, "Crinos keeps 40% of a 40-point hit: part back to 84")
    parts[1].health = 99.5                                 -- bleeding tick, under ACUTE_PART_DROP
    local snap3, back3 = WTAGarou.ToughnessRefund(parts, snap2, 0.4)
    check(back3 == 0 and parts[1].health == 99.5 and snap3[1] == 99.5, "small ongoing losses are not refunded")
    parts[3].health = 50
    local _, back4 = WTAGarou.ToughnessRefund(parts, snap3, 1.0)
    check(back4 == 0 and parts[3].health == 50, "Homid/Lupus (intake 1) get nothing back")
    check(WTAGarou.ACUTE_PART_DROP == 0.75, "acute threshold 0.75 part health per sweep")
    -- 0.4.79: damage over time is not a hit. A part that keeps dropping
    -- every sweep (a burn) is refunded on the first sweep only.
    local burn = { mk(100), mk(100) }
    local bs = WTAGarou.ToughnessRefund(burn, nil, 0.4)
    burn[1].health = 99                                    -- burn tick 1 (>= 0.75)
    local bs2, b2 = WTAGarou.ToughnessRefund(burn, bs, 0.4)
    check(math.abs(b2 - 0.6) < 1e-6 and bs2.streak[1] == true, "first sweep of a drop: refunded (it could be a hit) and the streak starts")
    burn[1].health = burn[1].health - 1                    -- burn tick 2
    local bs3, b3 = WTAGarou.ToughnessRefund(burn, bs2, 0.4)
    check(b3 == 0 and bs3.streak[1] == true, "second consecutive sweep of a drop on the same part: damage over time, nothing back")
    burn[1].health = burn[1].health - 1                    -- burn tick 3
    local bs4, b4 = WTAGarou.ToughnessRefund(burn, bs3, 0.4)
    check(b4 == 0, "and so on while it burns")
    local bs5, b5 = WTAGarou.ToughnessRefund(burn, bs4, 0.4)   -- a quiet sweep ends the streak
    check(b5 == 0 and bs5.streak[1] == nil, "a sweep without a drop ends the streak")
    burn[2].health = 60                                    -- a real hit on the other part meanwhile
    local _, b6 = WTAGarou.ToughnessRefund(burn, bs5, 0.4)
    check(math.abs(b6 - 24) < 1e-6, "a hit on another part is still refunded in full")
end
-- 0.4.19: Crinos is dry once the panel reads 0 (Rage < 1), not only at exactly 0.
check(WTAGarou.Rage.DEPLETED_BELOW == 1, "depletion threshold is one Rage point")

local roarPlayer
WTAGarou.CrinosBurst.onRoar=function(who, ...)
    check(select("#",...)==0,"roar route discards client-provided geometry")
    roarPlayer=who
end
local rageBefore=WTAGarou.GetData(p).rage
WTAGarou.HandleClientCommand("WTAGarou","CrinosRoarRequest",p,{radius=999,force=999,x=999,targets={1}})
check(roarPlayer==p,"command uses authenticated sender, not payload player")
check(WTAGarou.GetData(p).rage==rageBefore,"Q roar adds no Rage cost")
print("PASS: " .. checks .. " rage-engine / berserk-Crinos assertions.")
