-- 0.5.0 Resolve update: the Crinos Rage buffer, the full shift-channel
-- formula (pair base, centre curve, moonlight, buffer), the Resolve skill
-- helpers (window, unlocks, step tables), the perk registration file, the
-- server XP awards (resist, completed shift, cooldown, nothing for forced or
-- cancelled shifts) and the client-side handlers. Pure Lua; the perk, climate
-- and XP engine calls are stubbed, so nothing here is live-verified.
local root = assert(arg[1], "usage: lua5.1 resolve_test.lua <WTAGarou root>")
local n = 0
local function check(cond, why) n = n + 1; if not cond then error("FAIL: " .. why, 2) end end
local function close(a, b, why, eps) check(math.abs(a - b) < (eps or 0.001), why .. ": " .. tostring(a) .. " != " .. tostring(b)) end

-- ---------------------------------------------------------------- mocks ----
local clock = 1000.0
getTimestamp = function() return math.floor(clock) end
getTimestampMs = function() return clock * 1000 end
isClient = function() return false end
isServer = function() return false end
Events = setmetatable({}, { __index = function(t, k)
    t[k] = { handlers = {}, Add = function(f) table.insert(t[k].handlers, f) end }; return t[k] end })
ZombRand = function() return 0 end
instanceof = function() return false end
getGameTime = function() return { getWorldAgeHours = function() return 1 end } end
function require(_) end
MoodleType = setmetatable({}, { __index = function(_, k) return k end })
CharacterStat = { ENDURANCE = "Endurance", ZOMBIE_INFECTION = "ZombieInfection", ZOMBIE_FEVER = "ZombieFever" }

local sent = {}
WTAGarou = WTAGarou or {}
WTAGarou.Net = {
    ToClient = function(p, cmd, args) table.insert(sent, { cmd = cmd, args = args }) end,
    ToServer = function() end, RegisterClientHandler = function() end, RegisterServerHandler = function() end,
    Broadcast = function(cmd, args) table.insert(sent, { cmd = cmd, args = args }) end,
    IsSinglePlayer = function() return true end,
}
local function lastOf(cmd) for i = #sent, 1, -1 do if sent[i].cmd == cmd then return sent[i].args end end end
local function countOf(cmd) local c = 0; for _, m in ipairs(sent) do if m.cmd == cmd then c = c + 1 end end; return c end

dofile(root .. "/42/media/lua/shared/WTAGarouDefinitions.lua")
dofile(root .. "/42/media/lua/shared/WTAGarouState.lua")
dofile(root .. "/42/media/lua/shared/WTAGarouResolve.lua")

-- ---------------------------------------------------- tuning contract ----
local S, R, T, M = WTAGarou.ShiftBuffer, WTAGarou.Resolve, WTAGarou.TransformTime, WTAGarou.MoonLight
check(WTAGarou.VERSION == "0.5.2", "version 0.5.2")
check(S.WIDTH == 6 and S.MAX_SECONDS == 6 and S.PER_RESOLVE_LEVEL == 1, "buffer: six wide, six seconds, +1 per Resolve")
check(T.BASE == 6.0 and T.FAST == 1.0 and T.PLATEAU == 5 and T.FULL_AT == 20 and T.CRINOS == 1.0 and T.COOLDOWN == 3.0,
    "0.4.61 channel curve and the Crinos snap are untouched")
check(T.CENTER_ON_BASELINE == false and next(T.PAIR) == nil and next(T.PAIR_BERZERKER) == nil, "centre stays 50, no pair offsets by default")
check(M.ENABLED == true and M.MAX_REDUCTION == 0.25 and M.FULL_MOON_FLOAT == 0.7, "moon: up to a quarter off, 0.7 = full moon")
check(R.PERK == "WTAGarou_Resolve" and R.MAX_LEVEL == 10, "perk id and cap")
check(R.UNLOCK.CROWD_CHARGE == 0 and R.UNLOCK.ROAR_STAGGER == 1 and R.UNLOCK.DOOR_CHARGE == 2, "0.5.2 unlock order: charge at 0, roar at 1, door at 2")
check(R.XP.RESIST == 8 and R.XP.RESIST_STREAK == 3 and R.XP.RESIST_SINGLE == R.XP.SHIFT and R.XP.SHIFT == 3 and R.XP.CRINOS_SHIFT == 5 and R.XP.SHIFT_COOLDOWN_S == 60, "XP table")
check(WTAGarou.Rage.DEPLETED_HOLD_S == 2.0, "the 0-Rage forced return still waits its two seconds (0.4.75)")
check(WTAGarou.GetForm("Glabro").rageCost == 20 and WTAGarou.GetForm("Hispo").rageCost == 20
    and WTAGarou.RageRequired("Glabro") == 20 and WTAGarou.RageRequired("Hispo") == 20, "Glabro/Hispo: floor = cost = 20, unchanged")

-- ------------------------------------------------- buffer arithmetic ----
-- Subtle per-level perks; level 0 retains the old countdown and pull.
for lvl = 0, 10 do
    close(WTAGarou.ResolveResistStep(lvl), 2 - lvl * 0.1, "resist step at level " .. lvl)
    close(WTAGarou.ResistCountdownSeconds(1, 10, lvl), 8 + lvl * 0.1, "first resist at level " .. lvl)
    close(WTAGarou.ResolveBaselinePull(0.315, lvl, {}), 0.315 * (1 + lvl * 0.01),
        "fed and watered pull at level " .. lvl)
    for nResists = 1, 100 do
        local seconds = WTAGarou.ResistCountdownSeconds(nResists, 10, lvl)
        check(seconds > 0.5 and seconds < WTAGarou.ResistCountdownSeconds(nResists - 1, 10, lvl),
            "countdown still shrinks above the floor")
        if lvl > 0 then
            check(seconds >= WTAGarou.ResistCountdownSeconds(nResists, 10, lvl - 1),
                "higher Resolve never worsens the timer, including the log transition")
        end
    end
    for _, origin in ipairs({ "Homid", "Lupus", "Glabro" }) do
        local data = { trueForm = origin }
        local pull = WTAGarou.ResolveBaselinePull(0.42, lvl, data)
        close(pull, 0.42 * (1 + lvl * 0.01), "well-fed bonus")
        check(pull < -WTAGarou.CrinosDrainPerSecond(data, 0), "total pull stays below every origin's drain")
        check(pull < -WTAGarou.CrinosDrainPerSecond(data, 180), "escalation still drains")
    end
end
close(WTAGarou.ResolveResistStep(99), 1, "step floors at 1 second")
close(WTAGarou.ResolveResistStep(-1), 2, "negative level is level 0")
close(WTAGarou.ResolveBaselinePull(0, 10, {}), 0, "no nourishment: no new pull")
close(WTAGarou.ResolveBaselinePull(10, 10, { trueForm = "Glabro" }), 0.475,
    "safety cap applies to TOTAL pull, not just the bonus")
close(WTAGarou.ResolveBaselinePull(0.315, 99, {}), 0.3465, "bonus caps at level 10")

check(WTAGarou.ShiftBufferWidth(0) == 6 and WTAGarou.ShiftBufferWidth(3) == 9 and WTAGarou.ShiftBufferWidth(10) == 16, "window = 6 + level")
check(WTAGarou.ShiftBufferWidth(-2) == 6 and WTAGarou.ShiftBufferWidth(nil) == 6 and WTAGarou.ShiftBufferWidth(2.9) == 8, "window clamps and floors the level")
check(WTAGarou.ShiftBufferSeconds(0) == 0 and WTAGarou.ShiftBufferSeconds(5) == 5 and WTAGarou.ShiftBufferSeconds(5.5) == 5.5, "one second per Rage, fractional kept")
check(WTAGarou.ShiftBufferSeconds(6) == 6 and WTAGarou.ShiftBufferSeconds(9) == 6 and WTAGarou.ShiftBufferSeconds(16) == 6, "the time penalty never passes six seconds")

local d = { form = "Homid", rage = 50 }
check(WTAGarou.CrinosEntryShortfall(50, d) == 5 and WTAGarou.CrinosEntryShortfall(55, d) == 0 and WTAGarou.CrinosEntryShortfall(49.5, d) == 5.5, "entry shortfall against 55")
check(WTAGarou.CrinosEntryShortfall(50, { trueForm = "Glabro" }) == 0, "Berzerker Origin: no entry floor, no shortfall")
check(WTAGarou.CrinosExitExcess(80, { form = "Crinos" }) == 5 and WTAGarou.CrinosExitExcess(75, { form = "Crinos" }) == 0, "exit excess above 75")
check(WTAGarou.CrinosExitExcess(80, { form = "Homid" }) == 0, "no exit excess outside Crinos")
check(WTAGarou.CrinosExitExcess(60, { form = "Crinos", trueForm = "Glabro" }) == 5, "Berzerker exit excess above 55")

-- --------------------------------------------------------- admission ----
local function admit(data, target, lvl) local ok, why, info = WTAGarou.ShiftAdmission(data, target, lvl); return ok, why, info end
local ok, why, info
ok, why, info = admit({ form = "Homid", rage = 55 }, "Crinos", 0);  check(ok and info.bufferSeconds == 0, "55: plain entry")
ok, why, info = admit({ form = "Homid", rage = 50 }, "Crinos", 0);  check(ok and info.shortfall == 5 and info.bufferSeconds == 5, "50 (Philodox baseline): admitted, +5 s")
ok, why, info = admit({ form = "Homid", rage = 49 }, "Crinos", 0);  check(ok and info.bufferSeconds == 6, "49: the edge of the window, +6 s")
ok, why, info = admit({ form = "Homid", rage = 48.999 }, "Crinos", 0); check(not ok and why == "not_enough_rage", "48.999: outside the window")
ok, why, info = admit({ form = "Homid", rage = 48 }, "Crinos", 1);  check(ok and info.bufferSeconds == 6 and info.width == 7, "Resolve 1 reaches 48, still +6 s")
ok, why, info = admit({ form = "Homid", rage = 39 }, "Crinos", 10); check(ok and info.shortfall == 16 and info.bufferSeconds == 6, "Resolve 10 reaches 39 (16 short), still +6 s")
ok, why, info = admit({ form = "Homid", rage = 38 }, "Crinos", 10); check(not ok and why == "not_enough_rage", "Resolve 10 does not reach 38")
ok, why, info = admit({ form = "Homid", rage = 9 }, "Crinos", 10);  check(not ok and why == "not_enough_rage", "the 10 Rage cost is never buffered")
ok, why, info = admit({ form = "Glabro", rage = 12, trueForm = "Glabro" }, "Crinos", 0); check(ok and info.bufferSeconds == 0, "Berzerker Origin enters at 12 with no buffer time")
ok, why, info = admit({ form = "Glabro", rage = 9, trueForm = "Glabro" }, "Crinos", 10); check(not ok, "Berzerker Origin still needs the 10 cost")
-- Glabro / Hispo: no buffer at all (the user's decision: waiting IS the buffer)
ok, why, info = admit({ form = "Homid", rage = 19.9 }, "Glabro", 10); check(not ok and why == "not_enough_rage" and info.bufferSeconds == 0, "Glabro at 19.9: refused even at Resolve 10")
ok, why, info = admit({ form = "Homid", rage = 20 }, "Glabro", 0);   check(ok and info.bufferSeconds == 0, "Glabro at 20: plain entry")
ok, why, info = admit({ form = "Homid", rage = 14 }, "Hispo", 10);   check(not ok, "Hispo at 14: refused")
ok, why, info = admit({ form = "Crinos", rage = 0 }, "Homid", 0);    check(ok, "free forms need nothing")
-- exit lock
ok, why, info = admit({ form = "Crinos", rage = 75 }, "Homid", 0);   check(ok and info.bufferSeconds == 0, "75: plain exit")
ok, why, info = admit({ form = "Crinos", rage = 81 }, "Homid", 0);   check(ok and info.excess == 6 and info.bufferSeconds == 6, "81: the edge of the exit window, +6 s")
ok, why, info = admit({ form = "Crinos", rage = 81.5 }, "Homid", 0); check(not ok and why == "crinos_locked", "81.5: held")
ok, why, info = admit({ form = "Crinos", rage = 85 }, "Homid", 4);   check(ok and info.excess == 10 and info.bufferSeconds == 6, "Resolve 4 leaves at 85, +6 s")
ok, why, info = admit({ form = "Crinos", rage = 61, trueForm = "Glabro" }, "Glabro", 0); check(ok and info.bufferSeconds == 6, "Berzerker exits at 61, +6 s")
ok, why, info = admit({ form = "Crinos", rage = 62, trueForm = "Glabro" }, "Glabro", 0); check(not ok and why == "crinos_locked", "Berzerker held at 62")
ok, why, info = admit({ form = "Crinos", rage = 81 }, "Glabro", 0);  check(ok, "exit to Glabro at 81 pays 20 and carries +6 s")
ok, why, info = admit({ form = "Crinos", rage = 19 }, "Glabro", 0);  check(not ok and why == "not_enough_rage", "exit to Glabro still needs its 20")

-- --------------------------------------------------- channel formula ----
local C = WTAGarou.ComputeTransformSeconds
close(C(50, "Glabro"), 6.0, "plateau: 6 s at 50"); close(C(14, "Glabro"), 1.0, "far end: 1 s at 14"); close(C(81, "Homid"), 1.0, "far end: 1 s at 81")
close(C(50, "Crinos"), 1.0, "Crinos snap 1 s at any Rage"); close(C(49, "Crinos"), 1.0, "Crinos snap 1 s at 49")
close(C(61, "Glabro"), 4.8, "curve at 61: 6 - 5 * 6/25")
-- pair offsets (additive, Berzerker table first)
T.PAIR["Homid>Crinos"] = 0.5; T.PAIR_BERZERKER["Homid>Crinos"] = 0.25
close(C(50, "Crinos", { form = "Homid", rage = 50 }), 1.5, "general pair offset adds to the snap")
close(C(50, "Crinos", { form = "Homid", rage = 50, trueForm = "Glabro" }), 1.25, "Berzerker pair offset wins")
close(C(50, "Crinos", { form = "Glabro", rage = 50 }), 1.0, "other pairs unchanged")
close(C(50, "Crinos"), 1.0, "two-argument reading never applies a pair offset")
T.PAIR["Homid>Crinos"] = nil; T.PAIR_BERZERKER["Homid>Crinos"] = nil
-- centre on baseline (off by default)
check(WTAGarou.CenterRage({ auspice = "Ahroun" }) == 50, "centre is 50 by default whatever the auspice")
T.CENTER_ON_BASELINE = true
local ahroun = { auspice = "Ahroun", baselineRage = 70 }
check(WTAGarou.CenterRage(ahroun) == WTAGarou.BaselineRage(ahroun), "CENTER_ON_BASELINE: the plateau follows the baseline")
close(C(WTAGarou.BaselineRage(ahroun), "Glabro", ahroun), 6.0, "...so the slow plateau sits on the baseline")
T.CENTER_ON_BASELINE = false
close(C(50, "Glabro", ahroun), 6.0, "...and back on 50 when off")
-- moon multiplier
close(WTAGarou.MoonLightMultiplier(0), 1.0, "no moon: x1"); close(WTAGarou.MoonLightMultiplier(1), 0.75, "full exposure: x0.75")
close(WTAGarou.MoonLightMultiplier(0.5), 0.875, "half exposure: x0.875"); close(WTAGarou.MoonLightMultiplier(7), 0.75, "exposure clamps at 1")
M.ENABLED = false; close(WTAGarou.MoonLightMultiplier(1), 1.0, "disabled: x1"); M.ENABLED = true
-- the whole thing
local secs, parts
secs, parts = WTAGarou.ShiftSeconds({ form = "Homid", rage = 50 }, "Crinos", { resolveLevel = 0, exposure = 0 })
close(secs, 6.0, "Homid -> Crinos at 50: 1 s snap + 5 s buffer = 6 s (the Philodox example)")
check(parts.body == 1 and parts.buffer == 5 and parts.moon == 1, "breakdown reported")
secs = WTAGarou.ShiftSeconds({ form = "Homid", rage = 49 }, "Crinos", {});           close(secs, 7.0, "Homid -> Crinos at 49: 7 s")
secs = WTAGarou.ShiftSeconds({ form = "Homid", rage = 49.5 }, "Crinos", {});         close(secs, 6.5, "Homid -> Crinos at 49.5: 6.5 s (fractional Rage counts)")
secs = WTAGarou.ShiftSeconds({ form = "Crinos", rage = 81 }, "Homid", {});           close(secs, 7.0, "Crinos -> Homid at 81: 1 s + 6 s = 7 s")
secs = WTAGarou.ShiftSeconds({ form = "Crinos", rage = 61, trueForm = "Glabro" }, "Glabro", {}); close(secs, 10.8, "Berzerker Crinos -> Glabro at 61: 4.8 s + 6 s")
secs = WTAGarou.ShiftSeconds({ form = "Homid", rage = 50 }, "Glabro", { exposure = 1 }); close(secs, 4.5, "full moon cuts the 6 s plateau to 4.5 s")
secs = WTAGarou.ShiftSeconds({ form = "Homid", rage = 50 }, "Crinos", { exposure = 1 }); close(secs, 5.75, "full moon: 0.75 s snap + 5 s buffer; the buffer is added AFTER the moon")
secs = WTAGarou.ShiftSeconds({ form = "Homid", rage = 14 }, "Glabro", {});           close(secs, 1.0, "Glabro at 14 has no buffer (and is refused by admission anyway)")
T.MIN_SECONDS = 2.0
secs = WTAGarou.ShiftSeconds({ form = "Homid", rage = 55 }, "Crinos", { exposure = 1 }); close(secs, 2.0, "MIN_SECONDS floors the lit body time")
T.MIN_SECONDS = 0.25

-- ------------------------------------------------- Resolve helpers ----
check(WTAGarou.ResolveStep({ [1] = 3, [5] = 4, [8] = 5 }, 0, 0) == 0 and WTAGarou.ResolveStep({ [1] = 3, [5] = 4, [8] = 5 }, 4, 0) == 3
    and WTAGarou.ResolveStep({ [1] = 3, [5] = 4, [8] = 5 }, 5, 0) == 4 and WTAGarou.ResolveStep({ [1] = 3, [5] = 4, [8] = 5 }, 10, 0) == 5, "step table: highest key at or below the level")
check(WTAGarou.ResolveUnlocked(0, "CROWD_CHARGE"), "0.5.2: crowd charge from level 0")
check(not WTAGarou.ResolveUnlocked(0, "ROAR_STAGGER") and WTAGarou.ResolveUnlocked(1, "ROAR_STAGGER"), "0.5.2: roar stagger at 1")
check(not WTAGarou.ResolveUnlocked(1, "DOOR_CHARGE") and WTAGarou.ResolveUnlocked(2, "DOOR_CHARGE"), "0.5.2: door charge at 2")
check(WTAGarou.ResolveUnlocked(0, "SOMETHING_UNLISTED"), "abilities not in UNLOCK are never gated")
check(WTAGarou.ResolveCrowdChargeLimit(0) == 3 and WTAGarou.ResolveCrowdChargeLimit(1) == 3 and WTAGarou.ResolveCrowdChargeLimit(4) == 3
    and WTAGarou.ResolveCrowdChargeLimit(5) == 4 and WTAGarou.ResolveCrowdChargeLimit(8) == 5 and WTAGarou.ResolveCrowdChargeLimit(10) == 5, "0.5.2 crowd charge limit 3 from 0, 4 at 5, 5 at 8")
check(WTAGarou.ResolveRoarForce(0) == 0 and WTAGarou.ResolveRoarForce(1) == 1.0 and WTAGarou.ResolveRoarForce(2) == 1.0 and WTAGarou.ResolveRoarForce(6) == 1.5 and WTAGarou.ResolveRoarForce(10) == 2.0, "roar force 0/1/1.5/2")
local lim, win = WTAGarou.CrowdChargeFor("Crinos", 0); check(lim == 3 and win == 3.0, "0.5.2: CrowdChargeFor(Crinos, 0): 3 zombies, window kept")
lim = WTAGarou.CrowdChargeFor("Crinos", 5); check(lim == 4, "CrowdChargeFor(Crinos, 5): 4")
lim = WTAGarou.CrowdChargeFor("Crinos"); check(lim == 3, "legacy two-argument reading keeps the 0.4.69 table value")
lim = WTAGarou.CrowdChargeFor("Hispo", 10); check(lim == 0, "no other form charges")

-- ------------------------------------------- perk lookup and level ----
check(WTAGarou.Resolve.perk() == nil and WTAGarou.Resolve.levelOf({}) == 0, "no Perks global: perk nil, level 0 (abilities locked, base window)")
local perkObj = { id = "WTAGarou_Resolve" }
Perks = { WTAGarou_Resolve = perkObj }
local function fakePlayer(level)
    local p = { md = {}, level = level or 0, xp = 0, levelled = {} }
    function p:getModData() return self.md end
    function p:isDead() return false end
    function p:getOnlineID() return 7 end
    function p:getPerkLevel(perk) check(perk == perkObj, "level read with the registered perk"); return self.level end
    function p:getXp() local me = self; return { AddXP = function(_, perk, amt, callLua, doBoost, remote) check(perk == perkObj, "XP added to the registered perk"); me.boosted = (doBoost ~= false); me.xp = me.xp + amt end } end
    function p:isOutside() return self.outside end
    function p:getSquare()
        return {isOutside=function() return p.outside == true end,
            haveRoofFull=function() return false end, getCell=function() return nil end}
    end
    return p
end
check(WTAGarou.Resolve.perk() == perkObj, "perk found through Perks[id]")
check(WTAGarou.Resolve.levelOf(fakePlayer(4)) == 4 and WTAGarou.ResolveLevelOf(fakePlayer(12)) == 10, "level read and capped")
local gp = fakePlayer(0)
check(WTAGarou.Resolve.grant(gp, 25, "RESIST") == 25 and gp.xp == 25 and gp.boosted == false,
    "no global: XP:AddXP with doXPBoost=false (exact, no 25% no-boost cut)")
addXp = function(p, perk, amt) p.xp = p.xp + amt * 100 end
check(WTAGarou.Resolve.grant(gp, 3, "SHIFT") == 3 and gp.xp == 28, "the boosted addXp global is not preferred (it read +3 as 0.75 in game)")
addXpNoMultiplier = function(p, perk, amt) check(perk == perkObj, "no-multiplier perk"); p.xp = p.xp + amt * 1000 end
check(WTAGarou.Resolve.grant(gp, 5, "CRINOS_SHIFT") == 5 and gp.xp == 5028, "grant prefers the B42.21 addXpNoMultiplier global")
addXpNoMultiplier = nil
gp.getXp = function() error("no XP object") end
check(WTAGarou.Resolve.grant(gp, 3, "SHIFT") == 3 and gp.xp == 5328, "boosted addXp is only the last resort")
gp.getXp = nil
addXp = nil
check(WTAGarou.Resolve.grant(fakePlayer(10), 25, "RESIST") == 0, "no XP at the cap")
R.CLIENT_APPLIES_XP = true
local cp = fakePlayer(0)
check(WTAGarou.Resolve.grant(cp, 25, "RESIST") == 25 and cp.xp == 0, "CLIENT_APPLIES_XP: the server only validates")
check(WTAGarou.Resolve.applyOnClient(cp, 25) and cp.xp == 25, "...and the client applies")
R.CLIENT_APPLIES_XP = false
check(WTAGarou.Resolve.applyOnClient(cp, 25) == false and cp.xp == 25, "default: the client never double-applies")

-- -------------------------------------------- moonlight exposure ----
check(WTAGarou.MoonLightExposure(fakePlayer(0)) == 0, "no climate API: exposure 0")
local climate = { night = 1, cloud = 0, fog = 0 }
getClimateManager = function() return { getNightStrength = function() return climate.night end,
    getCloudIntensity = function() return climate.cloud end, getFogIntensity = function() return climate.fog end } end
local moonFloat = 0.7
getClimateMoon = function() return { getMoonFloat = function() return moonFloat end, getCurrentMoonPhase = function() return 4 end } end
local outside = fakePlayer(0); outside.outside = true
close(WTAGarou.MoonLightExposure(outside), 1.0, "full moon, clear night, outside: exposure 1")
climate.cloud = 0.5; close(WTAGarou.MoonLightExposure(outside), 0.5, "half cloud halves it")
climate.fog = 0.5; close(WTAGarou.MoonLightExposure(outside), 0.25, "fog stacks with cloud")
climate.cloud, climate.fog = 0, 0; climate.night = 0; close(WTAGarou.MoonLightExposure(outside), 0.25, "noon full moon: DAY_SHARE (0.25, 0.5.1) of the night pull")
climate.night = 0.5; close(WTAGarou.MoonLightExposure(outside), 0.625, "dusk: halfway between day and night weight")
climate.night = 0; climate.cloud = 0.5; close(WTAGarou.MoonLightExposure(outside), 0.125, "cloud still cuts the daytime moon")
climate.cloud = 0; WTAGarou.MoonLight.DAY_SHARE = 0; close(WTAGarou.MoonLightExposure(outside), 0, "DAY_SHARE 0: the old night-only rule")
WTAGarou.MoonLight.DAY_SHARE = 0.25
close(WTAGarou.ShiftSeconds({ form = "Homid", rage = 50 }, "Glabro", { exposure = WTAGarou.MoonLightExposure(outside) }), 5.625, "noon full moon: Glabro plateau 6 -> 5.625 s")
moonFloat = 0; close(WTAGarou.MoonLightExposure(outside), 0, "new moon by day: nothing")
moonFloat = 0.7
climate.night = 1; moonFloat = 0.2; close(WTAGarou.MoonLightExposure(outside), 0.2 / 0.7, "crescent: 0.2 / 0.7 of full")
moonFloat = 0.7; outside.outside = false; close(WTAGarou.MoonLightExposure(outside), 0, "indoors: no moon")
getClimateMoon = function() return { getCurrentMoonPhase = function() return 2 end } end
outside.outside = true; close(WTAGarou.MoonLightExposure(outside), 0.4 / 0.7, "no getMoonFloat: the phase table (phase 2 = 0.4)")
getClimateMoon = nil; getClimateManager = nil

-- ------------------------------------------------------ server XP ----
dofile(root .. "/42/media/lua/server/WTAGarouServer.lua")
Perks = { WTAGarou_Resolve = perkObj }
local sp = fakePlayer(0)
function sp:getMoodles() return { getMoodleLevel = function() return 0 end } end
function sp:getStats() local st = { Endurance = 1 }; return { get = function(_, k) return st[k] or 0 end, set = function(_, k, v) st[k] = v end } end
function sp:setSpeedMod() end
function sp:setVariable() end
function sp:isFemale() return false end
function sp:getBodyDamage() return { getOverallBodyHealth = function() return 100 end, setOverallBodyHealth = function() end,
    getBodyParts = function() return { size = function() return 0 end } end, getInfectionLevel = function() return 0 end,
    setInfectionLevel = function() end, isInfected = function() return false end, setInfected = function() end,
    getFakeInfectionLevel = function() return 0 end, setFakeInfectionLevel = function() end } end
function sp:getInventory() return { getItems = function() return { size = function() return 0 end } end } end
function sp:getWornItems() return { size = function() return 0 end } end
function sp:getTraits() return { contains = function() return true end, add = function() end, remove = function() end } end
function sp:HasTrait() return true end
function sp:getCharacterTraits() return { isGarou = function() return true end } end
function sp:getUsername() return "chris" end
function sp:getX() return 10 end function sp:getY() return 10 end function sp:getZ() return 0 end
function sp:getSquare() return nil end
function sp:getVehicle() return nil end
function sp:isSneaking() return false end
local sd = WTAGarou.GetData(sp); sd.isGarou = true; sd.form = "Homid"; sd.rage = 55; sd.formChangedAt = 0
WTAGarou.HasGarouTrait = function() return true end
sent = {}
-- completed voluntary Crinos shift: 5 XP, then nothing inside the minute
WTAGarou.HandleClientCommand("WTAGarou", "TransformRequest", sp, { form = "Crinos" })
check(lastOf("TransformAccepted") and lastOf("TransformAccepted").form == "Crinos", "shift accepted")
WTAGarou.HandleClientCommand("WTAGarou", "TransformConfirm", sp, { form = "Crinos" })
check(sd.form == "Crinos" and lastOf("ResolveXP") and lastOf("ResolveXP").amount == 5 and lastOf("ResolveXP").kind == "CRINOS_SHIFT" and sp.xp == 5, "completed Crinos shift: +5 Resolve")
clock = clock + 10; sd.formChangedAt = 0; sd.rage = 75; sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "TransformRequest", sp, { form = "Homid" })
WTAGarou.HandleClientCommand("WTAGarou", "TransformConfirm", sp, { form = "Homid" })
check(sd.form == "Homid" and not lastOf("ResolveXP") and sp.xp == 5, "a second completed shift 10 s later: no XP (one per minute)")
clock = clock + 60; sd.formChangedAt = 0; sd.rage = 60; sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "TransformRequest", sp, { form = "Glabro" })
WTAGarou.HandleClientCommand("WTAGarou", "TransformConfirm", sp, { form = "Glabro" })
check(sd.form == "Glabro" and lastOf("ResolveXP") and lastOf("ResolveXP").amount == 3 and sp.xp == 8, "after the minute a completed Glabro shift: +3")
-- a cancelled shift gives nothing
clock = clock + 60; sd.formChangedAt = 0; sd.rage = 55; sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "TransformRequest", sp, { form = "Crinos" })
WTAGarou.HandleClientCommand("WTAGarou", "TransformCancel", sp, { form = "Crinos" })
check(sd.form == "Glabro" and not lastOf("ResolveXP") and sp.xp == 8, "cancelled shift: no XP")
-- a forced shift gives nothing
clock = clock + 60; sd.formChangedAt = 0; sd.rage = 100; sent = {}
sd.pendingForm = "Crinos"; sd.pendingFrom = "Glabro"; sd.pendingCost = 10; sd.pendingForced = true; sd.pendingExpiresAt = getTimestamp() + 30
WTAGarou.HandleClientCommand("WTAGarou", "TransformConfirm", sp, { form = "Crinos" })
check(sd.form == "Crinos" and sd.isFrenzied and not lastOf("ResolveXP") and sp.xp == 8, "forced Crinos completion: no XP")
-- resist: +3 on the shift cooldown, +25 on every third resist in a streak
sd.form = "Homid"; sd.isFrenzied = false; sd.rage = 100; sd.resists = 0; sd.resolveShiftXpAt = nil; sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "ResistRequest", sp, {})
check(lastOf("ResistResult").ok == false and not lastOf("ResolveXP") and sp.xp == 8, "nothing to resist: no XP")
sd.crinosCountdownAt = 1; sd.crinosCountdownSeconds = 10; sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "ResistRequest", sp, {})
check(lastOf("ResistResult").ok == true and lastOf("ResolveXP").amount == 3 and lastOf("ResolveXP").kind == "RESIST_SINGLE" and sp.xp == 11, "first resist: +3 (the shift amount)")
sd.crinosCountdownAt = 1; sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "ResistRequest", sp, {})
check(lastOf("ResistResult").ok == true and not lastOf("ResolveXP") and sp.xp == 11, "second resist inside the shift cooldown: nothing")
sd.crinosCountdownAt = 1; sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "ResistRequest", sp, {})
check(lastOf("ResolveXP").amount == 8 and lastOf("ResolveXP").kind == "RESIST" and sp.xp == 19, "third resist in the streak: +8, cooldown or not")
clock = clock + 61; sd.crinosCountdownAt = 1; sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "ResistRequest", sp, {})
check(lastOf("ResolveXP").amount == 3 and sp.xp == 22, "fourth resist after the cooldown: +3 again")
sd.crinosCountdownAt = 1; sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "ResistRequest", sp, {})
check(not lastOf("ResolveXP") and sp.xp == 22, "fifth resist inside the cooldown: nothing")
sd.crinosCountdownAt = 1; sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "ResistRequest", sp, {})
check(lastOf("ResolveXP").amount == 8 and sp.xp == 30, "sixth resist: +8")
sd.resists = 0; sd.crinosCountdownAt = 1; clock = clock + 61; sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "ResistRequest", sp, {})
check(lastOf("ResolveXP").amount == 3 and lastOf("ResolveXP").kind == "RESIST_SINGLE" and sp.xp == 33, "a reset streak starts over at the small award")
sd.resolveShiftXpAt = nil
-- the level widens the admission window on the real server path
sd.form = "Homid"; sd.rage = 45; sd.formChangedAt = 0; sd.crinosCountdownAt = nil; sd.resistRestUntil = nil; sd.resists = 0; sp.level = 0; sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "TransformRequest", sp, { form = "Crinos" })
check(lastOf("TransformDenied") and lastOf("TransformDenied").reason == "not_enough_rage" and lastOf("TransformDenied").width == 6, "Resolve 0 at 45: refused (10 short)")
sp.level = 4; sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "TransformRequest", sp, { form = "Crinos" })
check(lastOf("TransformAccepted") and lastOf("TransformAccepted").buffer == 6, "Resolve 4 at 45: admitted, +6 s")
close(lastOf("TransformAccepted").seconds, 7.0, "...for a 7 s channel")
WTAGarou.HandleClientCommand("WTAGarou", "TransformCancel", sp, { form = "Crinos" })
-- the debug level setter
-- Server uses the actual perk for both the preview and the next countdown.
sp.level = 10; sd.form = "Homid"; sd.rage = 100; sd.resists = 0
sd.crinosCountdownAt = clock; sd.crinosCountdownSeconds = 10; sd.pendingForced = nil; sent = {}
WTAGarou.ResistCountdown(sp, sd, clock)
close(lastOf("ResistResult").nextSeconds, 9, "server previews Resolve 10's nine-second second countdown")
sd.resistRestUntil = clock
WTAGarou.UpdateCrinosCountdown(sp, sd, clock)
close(lastOf("CrinosCountdown").seconds, 9, "server actually starts the nine-second countdown")
sd.rage = 94
WTAGarou.UpdateCrinosCountdown(sp, sd, clock)
check(sd.resists == 0 and sd.crinosCountdownAt == nil, "reset rules unchanged")
-- Exercise the real Rage tick in both directions and both Crinos origins.
for _, origin in ipairs({ "Homid", "Glabro" }) do
    for _, form in ipairs({ "Homid", "Crinos" }) do
        for _, rage in ipairs({ 30, 70 }) do
            sd.trueForm = origin; sd.form = form; sd.rage = rage
            sd.auspice = "Philodox"; sd.moonExposure = 0; sd.crinosHeldSeconds = nil
            sd.crinosEscalationSteps = nil; sd.lastRageTickAt = clock - 1
            local drain = form == "Crinos" and WTAGarou.CrinosDrainPerSecond(sd, 0) or 0
            WTAGarou.RageTick(sp, sd, clock)
            close(sd.rage, rage + drain + (rage < 50 and 0.3465 or -0.3465),
                "server applies level-10 baseline pull without cancelling drain")
        end
    end
end
sd.trueForm = "Homid"; sd.form = "Homid"; sp.level = 4
sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "DebugSetResolve", sp, { level = 7 })
check(lastOf("ResolveSetLevel") and lastOf("ResolveSetLevel").level == 7, "DebugSetResolve tells the client the clamped level")
sent = {}
WTAGarou.HandleClientCommand("WTAGarou", "DebugSetResolve", sp, { level = 99 })
check(lastOf("ResolveSetLevel").level == 10, "...clamped to MAX_LEVEL")

-- ------------------------------------------------- perks.txt file ----
local f = assert(io.open(root .. "/42/media/perks.txt"), "media/perks.txt exists")
local perks = f:read("*a"); f:close()
check(perks:find("^VERSION = 1,"), "perks.txt starts with VERSION = 1,")
check(perks:find("perk WTAGarou_Garou%s*{") and perks:find("parent = None,"), "a Garou category (parent None)")
check(perks:find("perk WTAGarou_Resolve%s*{") and perks:find("parent = WTAGarou_Garou,") and perks:find("translation = WTAGarou_Resolve,"), "the Resolve skill under it")
local xps = {}
for lvl, v in perks:gmatch("xp(%d+) = (%d+),") do xps[tonumber(lvl)] = tonumber(v) end
local prev = 0
for lvl = 1, 10 do
    local v = xps[lvl] -- the LAST block (Resolve) wins in this map, which is the one we want
    check(v ~= nil, "Resolve xp" .. lvl .. " present")
    check(v > prev, "Resolve xp" .. lvl .. " grows (" .. tostring(v) .. " > " .. tostring(prev) .. ")")
    prev = v
end
check(xps[1] == 50 and xps[10] == 2600, "level 1 at 50 XP (75 in game after the engine's 1.5x), level 10 at 2600")
-- Translator routes IGUI_ keys to IG_UI.json, not UI.json.
local ui = assert(io.open(root .. "/42/media/lua/shared/Translate/EN/IG_UI.json")):read("*a")
check(ui:find('"IGUI_perks_WTAGarou_Garou": "Werewolf"', 1, true) and ui:find('"IGUI_perks_WTAGarou_Resolve": "Resolve"', 1, true)
    and ui:find('"IGUI_perks_WTAGarou_Resolve_Description"', 1, true), "IG_UI.json names the category, the skill and its description")
-- 0.5.0 ship: the description and every level text match the Lua builder.
local keys = {}
for k, v in string.gmatch(ui, '"([%w_]+)": "(.-)",?\n') do keys[k] = v end
local RT = WTAGarou.Resolve.text
check(keys.IGUI_perks_WTAGarou_Resolve_Description == RT.main(), "IG_UI description == Resolve.text.main()")
for lvl = 1, 10 do
    check(keys["IGUI_perks_WTAGarou_Resolve_Description" .. lvl] == RT.level(lvl), "IG_UI level " .. lvl .. " text matches the live tables")
    check(not RT.level(lvl):find("_", 1, true), "level " .. lvl .. " text has no raw key")
end
check(RT.level(0) == nil and RT.level(11) == nil, "no text outside 1..10")
check(RT.level(1):find("start Crinos from 48 Rage", 1, true) and RT.level(1):find("1.9 s", 1, true)
    and RT.level(1):find("1% faster", 1, true) and RT.level(1):find("New: roar stagger", 1, true), "0.5.2 level 1 text: roar stagger")
check(RT.main():find("zombie charge", 1, true) and RT.main():find("first 3 zombies", 1, true), "0.5.2: the main text says the zombie charge comes from the start")
check(not RT.level(3):find("New:", 1, true), "0.5.2: level 3 gives only passives")
check(RT.level(2):find("New: door charge", 1, true) and RT.level(2):find("12 Rage, 18 if locked", 1, true), "0.5.2 level 2 door text uses DoorCharge costs")
check(RT.level(10):find("1.0 s", 1, true) and RT.level(10):find("(2x)", 1, true), "level 10 text")
check(not RT.level(4):find("New:", 1, true), "level 4 has no unlock line")
-- client safety net: raw keys are swapped, missing level text is added, other skills untouched
dofile(root .. "/42/media/lua/client/WTAGarouSkillTooltip.lua")
local FT = WTAGarou.FixResolveTooltip
local raw = "Resolve Level 2 <LINE> Locked <LINE><LINE> IGUI_perks_WTAGarou_Resolve_Description"
local fixed = FT(raw, 2)
check(fixed:find(RT.main(), 1, true) and fixed:find(RT.level(2), 1, true) and not fixed:find("IGUI_", 1, true), "raw description key replaced and level text added")
local both = FT(raw .. " <LINE><LINE> IGUI_perks_WTAGarou_Resolve_Description2", 2)
check(not both:find("IGUI_", 1, true) and select(2, both:gsub("Crinos window", "")) == 1, "raw level key replaced once, not duplicated")
local byName = FT("Resolve level 4 <LINE> Unlocked <LINE><LINE> IGUI_perks_Resolve_Description", 4)
check(byName:find(RT.main(), 1, true) and byName:find(RT.level(4), 1, true) and not byName:find("IGUI_", 1, true),
    "Nov 8 playtest: key built from the translated name is replaced too")
local byNameLvl = FT("x IGUI_perks_Resolve_Description <LINE><LINE> IGUI_perks_Resolve_Description4", 4)
check(not byNameLvl:find("IGUI_", 1, true) and select(2, byNameLvl:gsub("Crinos window", "")) == 1, "name-based level key replaced once")
local good = "Resolve Level 2 <LINE><LINE> " .. RT.main() .. " <LINE><LINE> " .. RT.level(2)
check(FT(good, 2) == good, "a correctly translated tooltip is left alone")
ISSkillProgressBar = { updateTooltip = function(self) self.message = "x IGUI_perks_WTAGarou_Resolve_Description" end }
WTAGarou.__resolveTooltipWrapped = nil
dofile(root .. "/42/media/lua/client/WTAGarouSkillTooltip.lua")
local bar = { perk = { getId = function() return "WTAGarou_Resolve" end } }
ISSkillProgressBar.updateTooltip(bar, 0)
check(bar.message:find(RT.level(1), 1, true) and not bar.message:find("IGUI_", 1, true), "hook fixes the Resolve bar (level box 1)")
local axe = { perk = { getId = function() return "Axe" end } }
ISSkillProgressBar.updateTooltip(axe, 0)
check(axe.message == "x IGUI_perks_WTAGarou_Resolve_Description", "other skills untouched")
ISSkillProgressBar = nil

-- ------------------------------------------------- client handlers ----
-- Doorway: the no_resolve denial text; Visual and HUD covered in their own suites.
getSpecificPlayer = function() return sp end
getPlayer = function() return sp end
local notices = {}
WTAGarou.HUDFor = function() return { flashDenial = function(_, t) notices[#notices + 1] = t end, pushNotice = function(_, t) notices[#notices + 1] = t end } end
WTAGarouJava = nil
dofile(root .. "/42/media/lua/client/WTAGarouDoorway.lua")
WTAGarou.DoorwayClient.onServerCommand("WTAGarou", "DoorChargeResult", { reason = "no_resolve" })
check(notices[#notices]:find("Resolve 2", 1, true), "door denial names the Resolve level: " .. tostring(notices[#notices]))

-- The client command handler is wired by Events in the real game; here the
-- source is checked the way shift_sounds_test checks its handlers.
local clientSrc = assert(io.open(root .. "/42/media/lua/client/WTAGarouClient.lua")):read("*a")
check(clientSrc:find('command == "ResolveXP"', 1, true) and clientSrc:find("R.applyOnClient(player, args.amount)", 1, true), "client handles ResolveXP and applies only through applyOnClient")
check(clientSrc:find('command == "ResolveSetLevel"', 1, true) and clientSrc:find("R.setLevel(player, args.level)", 1, true), "client handles ResolveSetLevel")
check(clientSrc:find('command == "CrinosRoarResult"', 1, true) and clientSrc:find('args.reason == "no_resolve"', 1, true), "client explains a roar without Resolve")
check(clientSrc:find("You reach for Rage you do not quite have", 1, true) and clientSrc:find("The Rage clings to you", 1, true), "TransformAccepted names the buffer cost in seconds")
local visualSrc = assert(io.open(root .. "/42/media/lua/client/WTAGarouVisual.lua")):read("*a")
check(visualSrc:find('require "WTAGarouResolve"', 1, true) and visualSrc:find("WTAGarou.CrowdChargeFor(form, level)", 1, true), "Visual pushes the crowd charge by Resolve level")
local serverSrc = assert(io.open(root .. "/42/media/lua/server/WTAGarouServer.lua")):read("*a")
check(serverSrc:find('require "WTAGarouResolve"', 1, true) and serverSrc:find("WTAGarou.ShiftAdmission(d, target, resolveLevel)", 1, true)
    and serverSrc:find("WTAGarou.ShiftSeconds(d, target, { resolveLevel = resolveLevel, exposure = exposure })", 1, true), "server admits and times through the 0.5.0 formula")
local debugSrc = assert(io.open(root .. "/42/media/lua/client/WTAGarouDebug.lua")):read("*a")
check(debugSrc:find('cmd == "resolve"', 1, true) and debugSrc:find('"DebugSetResolve"', 1, true), "/garou resolve <n> exists")
-- "True Form" became "Origin" in the player-facing strings; the saved key stays trueForm.
for _, file in ipairs({ "client/WTAGarouWolfCoat.lua", "client/WTAGarouHUD.lua", "client/WTAGarouDebug.lua" }) do
    local src = assert(io.open(root .. "/42/media/lua/" .. file)):read("*a")
    for str in src:gmatch('"[^"\n]-"') do check(not str:lower():find("true form", 1, true), file .. " player string still says true form: " .. str) end
end
check(serverSrc:find("d.trueForm", 1, true) or serverSrc:find("trueForm", 1, true), "the saved trueForm field is untouched")

-- 0.5.1: exercise the actual server handler's existing reply paths with the
-- cosmetic helper present, not only the helper's standalone state machine.
dofile(root .. "/42/media/lua/server/WTAGarouShiftVisualServer.lua")
isServer=function() return true end
local hotfixData=WTAGarou.GetData(sp)
hotfixData.form,hotfixData.rage,hotfixData.lastTransformAt="Homid",60,0
hotfixData.pendingForm,hotfixData.pendingForced=nil,nil
clock=clock+100
WTAGarou.HandleClientCommand("WTAGarou","TransformRequest",sp,{form="Glabro"})
local hotfixReply=lastOf("TransformAccepted")
check(hotfixReply and type(hotfixReply.shiftVisualToken)=="number",
    "real acceptance reply carries visual token")
WTAGarou.ShiftVisualServer.receive("WTAGarou","ShiftVisualProgress",sp,
    {token=hotfixReply.shiftVisualToken,progress=0.5})
close(WTAGarou.ShiftVisualServer.sample(sp).value,1.09,"real reservation accepts cosmetic progress")
WTAGarou.HandleClientCommand("WTAGarou","TransformCancel",sp,{form="Glabro"})
check(WTAGarou.ShiftVisualServer.sample(sp).mode=="return"
    and hotfixData.form=="Homid" and hotfixData.rage==60,"normal cancel reply starts cosmetic recovery without spending Rage")
clock=clock+2
WTAGarou.HandleClientCommand("WTAGarou","TransformRequest",sp,{form="Glabro"})
WTAGarou.HandleClientCommand("WTAGarou","TransformConfirm",sp,{form="Glabro"})
check(hotfixData.form=="Glabro" and WTAGarou.ShiftVisualServer.sample(sp)==nil,
    "real successful confirmation clears cosmetic preview")
isServer=function() return false end

print(string.format("PASS: %d Resolve / Crinos Rage buffer / shift formula assertions (pure Lua; perk, climate, XP sync and the Java charge are not live-verified).", n))
