-- 0.4.19: movement-lock diagnostics and release (client/WTAGarouStuckGuard.lua).
local root = assert(arg[1], "supply WTAGarou directory")
package.path = root .. "/42/media/lua/shared/?.lua;" .. package.path
require "WTAGarouDefinitions"
require "WTAGarouState"
local checks = 0
local function check(ok, message) checks = checks + 1; assert(ok, message) end

local clock = 100
WTAGarou.NowSeconds = function() return clock end
local updates = {}
Events = { OnPlayerUpdate = { Add = function(fn) table.insert(updates, fn) end } }
local cleared = {}
ISTimedActionQueue = { clear = function(p) cleared[#cleared + 1] = p end }
local logs = {}
local realPrint = print
print = function(...) local s = table.concat({ ... }, " "); table.insert(logs, s); realPrint(s) end

dofile(root .. "/42/media/lua/client/WTAGarouStuckGuard.lua")
local S = WTAGarou.StuckGuard
check(S and S.evaluate and S.release and S.snapshot and #updates == 1, "stuck guard loaded and hooked OnPlayerUpdate")

local function newPlayer(id)
    local p = { id = id, x = 10, y = 10, input = false, state = "IdleState@1a2b", ignore = true, block = true,
                hit = "HitReactionState", calls = {}, animRebuilt = 0 }
    function p:getOnlineID() return self.id end
    function p:getX() return self.x end
    function p:getY() return self.y end
    function p:isInputMoveAxisApplied() return self.input end
    function p:getCurrentState() return self.state end
    function p:getHitReaction() return self.hit end
    function p:getIgnoreMovement() return self.ignore end
    function p:isBlockMovement() return self.block end
    function p:isKnockedDown() return false end
    function p:isBumpFall() return false end
    function p:isBumpStaggered() return false end
    function p:isSitOnGround() return false end
    function p:isOnFloor() return false end
    function p:isBeingGrappled() return false end
    function p:isGrappling() return false end
    function p:getVehicle() return self.vehicle end
    function p:getCharacterActions() return { size = function() return 0 end } end
    function p:getVariableString(k) return "v_" .. k end
    function p:setIgnoreMovement(v) self.ignore = v; table.insert(self.calls, "ignore") end
    function p:setBlockMovement(v) self.block = v; table.insert(self.calls, "block") end
    function p:setHitReaction(v) self.hit = v; table.insert(self.calls, "hit") end
    function p:setBumpFall() table.insert(self.calls, "bumpFall") end
    function p:setBumpStaggered() table.insert(self.calls, "bumpStaggered") end
    function p:setKnockedDown() table.insert(self.calls, "knockedDown") end
    function p:getAdvancedAnimator()
        local me = self
        return { OnAnimDataChanged = function(_, v) me.animRebuilt = me.animRebuilt + 1; me.animArg = v end }
    end
    return p
end

local p = newPlayer(1)
check(S.evaluate(p, "Crinos", clock) == "idle", "no input: idle")
p.input = true
check(S.evaluate(p, "Crinos", clock) == "watch", "input held: start watching")
clock = clock + 2
check(S.evaluate(p, "Crinos", clock) == "watch" and #logs == 0, "2 s without movement: still quiet")
clock = clock + 1.5
local r = S.evaluate(p, "Crinos", clock)
check(r == "report" and #logs == 1, "3.5 s: one diagnostic line")
local line = logs[1]
check(line:find("[WTAGarou][StuckGuard] no movement for 3.5s", 1, true) and line:find("state=IdleState", 1, true)
    and line:find("hitReaction=HitReactionState", 1, true) and line:find("ignoreMovement=true", 1, true)
    and line:find("blockMovement=true", 1, true) and line:find("form=v_WTAGarou_Form", 1, true), "diagnostic names the engine state: " .. line)
check(#p.calls == 0, "no release before RELEASE_AFTER")
clock = clock + 1
check(S.evaluate(p, "Crinos", clock) == "watch" and #logs == 1, "reports are rate-limited")
-- moving resets the window
p.x = 11
check(S.evaluate(p, "Crinos", clock) == "watch", "movement resets the window")
clock = clock + 6.5
check(S.evaluate(p, "Crinos", clock) == "release", "6.5 s stuck in Crinos with input: released")
check(p.ignore == false and p.block == false and p.hit == "" and p.animRebuilt == 1 and p.animArg == false and cleared[1] == p,
    "release clears ignore/block/hitReaction, clears the queue and rebuilds the animator")
check(logs[#logs]:find("released movement lock #1 in Crinos", 1, true), "release is logged")
clock = clock + 3
check(S.evaluate(p, "Crinos", clock) == "watch", "one release per window")
p.input = false
check(S.evaluate(p, "Crinos", clock) == "idle" and S.track["1"] == nil, "letting go of the keys clears the tracker")

-- wolf forms are never released for a generic lock (Java owns their track); still reported
local w = newPlayer(2); w.input = true; w.state = "IdleState@1"
S.evaluate(w, "Hispo", clock); clock = clock + 7
check(S.evaluate(w, "Hispo", clock) == "report" and #w.calls == 0, "Hispo: diagnostics only, no release")

-- 0.4.20: ...except the zombie bite reaction, which the wolf clip never exits on time.
local wb = newPlayer(6); wb.input = true; wb.state = "PlayerHitReactionState@2"; wb.hit = "Bite"
S.evaluate(wb, "Hispo", clock); clock = clock + 1.5
check(S.evaluate(wb, "Hispo", clock) == "watch" and #wb.calls == 0, "Hispo bite lock: 1.5 s is still legitimate")
clock = clock + 0.6
check(S.evaluate(wb, "Hispo", clock) == "release" and wb.hit == "" and wb.ignore == false and wb.animRebuilt == 1,
    "Hispo bite lock released after WOLF_HIT_RELEASE_AFTER (" .. S.WOLF_HIT_RELEASE_AFTER .. " s)")
check(S.WOLF_HIT_RELEASE_AFTER < S.REPORT_AFTER, "wolf bite release comes before the generic report")

-- legitimate long states are left alone
local c = newPlayer(3); c.input = true; c.state = "ClimbOverFenceState@77"
S.evaluate(c, "Crinos", clock); clock = clock + 7
check(S.evaluate(c, "Crinos", clock) == "report" and #c.calls == 0, "climbing is never released")
local v = newPlayer(4); v.input = true; v.vehicle = {}
S.evaluate(v, "Homid", clock); clock = clock + 7
check(S.evaluate(v, "Homid", clock) == "report" and #v.calls == 0, "in a vehicle is never released")

-- a player missing accessors never throws
local bare = { getOnlineID = function() return 5 end, isPlayerMoving = function() return true end }
check(S.evaluate(bare, "Homid", clock) == "watch", "missing accessors fall back to isPlayerMoving")

print = realPrint
print("PASS: " .. checks .. " stuck-guard assertions.")
