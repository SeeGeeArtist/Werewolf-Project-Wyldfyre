-- 0.4.82: tough feet on the server. The vanilla barefoot scratch loop runs
-- server-side in multiplayer (IsoPlayer.updateFootInjuries is guarded by
-- !GameClient.client), where the client Java patch cannot reach it; the body
-- sweep clears its fresh foot wounds for tough-footed forms.
local root = arg[1] or "."
package.path = root .. "/42/media/lua/shared/?.lua;" .. root .. "/42/media/lua/server/?.lua;" .. package.path
local checks = 0
local function check(cond, msg) checks = checks + 1; if not cond then error("FAIL: " .. msg, 2) end end

Events = setmetatable({}, { __index = function(t, k) t[k] = { Add = function() end }; return t[k] end })
require "WTAGarouDefinitions"
require "WTAGarouPaws"
local P = WTAGarou.Paws

check(P.toughFeet("Glabro") and P.toughFeet("Crinos") and P.toughFeet("Hispo") and P.toughFeet("Lupus") and not P.toughFeet("Homid"),
    "tough feet follow FormData.toughFeet (every form but Homid)")
check(P.FRESH_TIME == 3.5, "fresh window covers the loop's Rand(1,3) first roll")

local function foot(name, o)
    o = o or {}
    local f = { name = name, scr = o.scr or false, scrT = o.scrT or 0, cut = o.cut or false, cutT = o.cutT or 0, bleed = o.bleed or false, log = {} }
    function f:getType() return self.name end
    function f:scratched() return self.scr end
    function f:isCut() return self.cut end
    function f:getScratchTime() return self.scrT end
    function f:getCutTime() return self.cutT end
    function f:bleeding() return self.bleed end
    function f:setScratched(v) self.scr = v; self.log[#self.log + 1] = "scr=" .. tostring(v) end
    function f:setScratchTime(v) self.scrT = v end
    function f:setCut(v) self.cut = v end
    function f:setCutTime(v) self.cutT = v end
    function f:setBleeding(v) self.bleed = v end
    function f:setBleedingTime(v) end
    return f
end

check(P.isFreshLoopWound(foot("Foot_L", { scr = true, scrT = 2.1 })), "a 1..3 scratch is the loop's roll")
check(not P.isFreshLoopWound(foot("Foot_L", { scr = true, scrT = 9 })), "an older/bigger scratch is left alone")
check(P.isFreshLoopWound(foot("Foot_L", { cut = true, cutT = 1.5 })), "a fresh cut (loop past 30 scratch time) counts")
check(not P.isFreshLoopWound(foot("Foot_L", { scr = true, scrT = 1, cut = true, cutT = 12 })), "fresh scratch but an old cut: not touched")
check(not P.isFreshLoopWound(foot("Foot_L")), "a healthy foot is nothing to do")

-- Sweep -------------------------------------------------------------------
local printed = {}
local realPrint = print
print = function(s) printed[#printed + 1] = tostring(s) end
local function body(parts)
    local bd = { parts = parts, recalcs = 0 }
    function bd:getBodyParts() return { size = function() return #parts end, get = function(_, i) return parts[i + 1] end } end
    function bd:calculateOverallHealth() self.recalcs = self.recalcs + 1 end
    return bd
end
local exposure = "bare"
WTAGarou.Scatter = { exposed = function(player, form, isGarou) return exposure end }
local player = { getUsername = function() return "chris" end }

local L, R = foot("Foot_L", { scr = true, scrT = 2 }), foot("Foot_R", { scr = true, scrT = 25, bleed = true })
local bd = body({ foot("Hand_L", { scr = true, scrT = 1 }), L, R })
local d = { isGarou = true, form = "Glabro" }
check(P.sweep(player, d, bd) == 1, "barefoot Glabro: the fresh foot scratch is cleared, the old one is not")
check(L.scr == false and L.scrT == 0 and R.scr == true and R.scrT == 25, "left foot clean, right foot untouched")
check(bd.parts[1].scr == true, "a hand scratch is never a foot wound")
check(bd.recalcs == 1 and printed[#printed]:find("chris shrugged off a barefoot Glabro on Foot_L", 1, true), "overall health recomputed and the console says which foot")

L = foot("Foot_L", { scr = true, scrT = 2 }); bd = body({ L })
check(P.sweep(player, { isGarou = true, form = "Homid" }, bd) == 0 and L.scr, "Homid feet are human: the scratch stays")
exposure = nil
check(P.sweep(player, d, bd) == 0 and L.scr, "shod Glabro: the loop would not have fired; nothing is touched")
exposure = "bare"
check(P.sweep(player, { isGarou = true, form = "Glabro", silverLodged = { Foot_L = "shard" } }, bd) == 0 and L.scr,
    "a foot with lodged silver is left to the silver module")
check(P.sweep(player, { isGarou = false, form = "Glabro" }, bd) == 0, "not a Garou: nothing")
exposure = "paws"
L = foot("Foot_L", { cut = true, cutT = 1 }); bd = body({ L })
check(P.sweep(player, { isGarou = true, form = "Hispo" }, bd) == 1 and not L.cut, "paw forms count as barefoot; a fresh cut is cleared")
check(P.cleared == 2, "counter")

print = realPrint
print("PASS: " .. checks .. " tough-feet server sweep assertions.")
