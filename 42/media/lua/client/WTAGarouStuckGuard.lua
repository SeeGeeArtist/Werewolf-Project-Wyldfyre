--[[
    WTAGarou - Stuck guard (v0.4.19)

    0.4.18 playtest: after a Hispo -> Crinos shift the player could neither
    move nor attack and was eaten by two zombies. The console recorded no
    error between the shift landing and the death, so the cause is not in
    the log. This file does two things for the next time it happens:

      1. DIAGNOSE. While the local Garou is holding a movement direction and
         has not moved for REPORT_AFTER seconds, print one line with the
         engine state that decides whether input is honoured: current AI
         state, hit reaction, knocked down / bump fall / bump staggered,
         sit-on-ground / on-floor, ignoreMovement / blockMovement, grapple
         flags, timed-action count and our own animation variables.
         Repeats every REPORT_EVERY seconds while still stuck.

      2. RELEASE. If the lock lasts RELEASE_AFTER seconds in a human-bodied
         form (Homid/Glabro/Crinos) with none of the legitimate long states
         active (climbing, vehicle, furniture, sleeping, grapple animation),
         clear the movement blockers the engine's own states clear on exit
         (setIgnoreMovement(false), setBlockMovement(false), setHitReaction(""),
         bump/knockdown flags), clear the timed-action queue and rebuild the
         animation state (OnAnimDataChanged(false), the same call every
         form change already makes). Logged as [WTAGarou][StuckGuard] released.

    Pure logic (S.evaluate) is exercised by tests/stuck_guard_test.lua with
    a mock player; the in-game effect is unverified until the next playtest.
]]

WTAGarou = WTAGarou or {}
WTAGarou.StuckGuard = WTAGarou.StuckGuard or {}
local S = WTAGarou.StuckGuard

S.REPORT_AFTER  = 3.0
S.REPORT_EVERY  = 5.0
S.RELEASE_AFTER = 6.0
-- 0.4.20: in Hispo/Lupus the zombie bite reaction (PlayerHitReactionState)
-- is played on a substituted wolf clip whose end never lines up with the
-- human graph's exit, so the wolf stood locked for several seconds
-- (September 26 playtest). Release that one state early in wolf forms.
S.WOLF_HIT_RELEASE_AFTER = 2.0
S.MIN_MOVE      = 0.05   -- tiles; less than this in a window counts as "did not move"
S.HUMAN_FORMS   = { Homid = true, Glabro = true, Crinos = true }
-- AI states that legitimately hold the player for a while; never release inside these.
S.LEGIT_STATE_PATTERNS = { "Climb", "Grappled", "Vehicle", "Bed", "Fitness", "Sleep", "Window", "OnGround" }

S.track = S.track or {}   -- [playerKey] = { x, y, since, lastReport, releases }

local function now()
    if WTAGarou.NowSeconds then return WTAGarou.NowSeconds() end
    if getTimestampMs then return getTimestampMs() / 1000 end
    return os.time()
end

local function safe(obj, method, ...)
    if not obj or not obj[method] then return nil end
    local ok, res = pcall(obj[method], obj, ...)
    if ok then return res end
    return nil
end

local function playerKey(player)
    local id = safe(player, "getOnlineID")
    if id ~= nil then return tostring(id) end
    return tostring(player)
end

-- Is the player pushing a movement direction right now? 42.20.2:
-- IsoGameCharacter implements CharacterInputComponentEntity, whose
-- isInputMoveAxisApplied() is true while the keyboard/gamepad movement axis
-- is non-zero (CharacterInputComponent.getInputMovementRate() ~= 0).
-- isPlayerMoving() is the engine's own "did I actually move" flag, which is
-- exactly what goes false when the character is stuck, so it is only used
-- as a fallback where the input accessor is missing.
local function hasMoveInput(player)
    local applied = safe(player, "isInputMoveAxisApplied")
    if applied ~= nil then return applied == true end
    return safe(player, "isPlayerMoving") == true
end

-- 42.20.2 accessor names: getIgnoreMovement() (no isIgnoreMovement),
-- isBeingGrappled()/isGrappling()/isOnFloor() are IGrappleableWrapper
-- defaults on IsoGameCharacter.
local function ignoreMovement(player)
    local v = safe(player, "getIgnoreMovement")
    if v == nil then v = safe(player, "isIgnoreMovement") end
    return v
end

local function stateName(player)
    local st = safe(player, "getCurrentState")
    if st == nil then return "nil" end
    local s = tostring(st)
    return (s:match("([%w_]+)@") or s:match("%.([%w_]+)$") or s)
end

local function isLegitState(name)
    for _, pat in ipairs(S.LEGIT_STATE_PATTERNS) do
        if name:find(pat) then return true end
    end
    return false
end

-- One-line engine snapshot.
function S.snapshot(player)
    local actions = safe(player, "getCharacterActions")
    local nActions = actions and safe(actions, "size") or -1
    return string.format(
        "state=%s hitReaction=%s knockedDown=%s bumpFall=%s bumpStaggered=%s sitOnGround=%s onFloor=%s"
        .. " ignoreMovement=%s ignoreForDirection=%s blockMovement=%s grappled=%s grappling=%s actions=%s"
        .. " shifting=%s howling=%s form=%s",
        stateName(player), tostring(safe(player, "getHitReaction")),
        tostring(safe(player, "isKnockedDown")), tostring(safe(player, "isBumpFall")),
        tostring(safe(player, "isBumpStaggered")), tostring(safe(player, "isSitOnGround")),
        tostring(safe(player, "isOnFloor")), tostring(ignoreMovement(player)),
        tostring(safe(player, "isIgnoreMovementForDirection")), tostring(safe(player, "isBlockMovement")), tostring(safe(player, "isBeingGrappled")),
        tostring(safe(player, "isGrappling")), tostring(nActions),
        tostring(safe(player, "getVariableString", "WTAGarou_Shifting")),
        tostring(safe(player, "getVariableString", "WTAGarou_Howling")),
        tostring(safe(player, "getVariableString", "WTAGarou_Form")))
end

-- Clear what the engine's own states clear on exit, then rebuild the animator.
function S.release(player)
    pcall(function() player:setIgnoreMovement(false) end)
    pcall(function() player:setBlockMovement(false) end)
    pcall(function() player:setHitReaction("") end)
    pcall(function() player:setBumpFall(false) end)
    pcall(function() player:setBumpStaggered(false) end)
    pcall(function() player:setKnockedDown(false) end)
    pcall(function()
        if ISTimedActionQueue and ISTimedActionQueue.clear then ISTimedActionQueue.clear(player) end
    end)
    pcall(function()
        local animator = player:getAdvancedAnimator()
        if animator then animator:OnAnimDataChanged(false) end
    end)
end

-- Pure decision step. `form` is the current form name, `t` the clock.
-- Returns "idle" | "watch" | "report" | "release".
function S.evaluate(player, form, t)
    local key = playerKey(player)
    local x, y = safe(player, "getX") or 0, safe(player, "getY") or 0
    local entry = S.track[key]
    local pushing = hasMoveInput(player)
    if not pushing then
        S.track[key] = nil
        return "idle"
    end
    if not entry then
        S.track[key] = { x = x, y = y, since = t, lastReport = nil, releases = 0 }
        return "watch"
    end
    if math.abs(x - entry.x) > S.MIN_MOVE or math.abs(y - entry.y) > S.MIN_MOVE then
        entry.x, entry.y, entry.since, entry.lastReport = x, y, t, nil
        return "watch"
    end
    local stuckFor = t - entry.since
    local state = stateName(player)
    -- 0.4.20: wolf-form bite reaction lock (see WOLF_HIT_RELEASE_AFTER); it
    -- is checked before the generic report threshold because it fires sooner.
    local wolfHitLock = (not S.HUMAN_FORMS[tostring(form)]) and tostring(state):find("HitReaction") ~= nil
        and stuckFor >= S.WOLF_HIT_RELEASE_AFTER
    if stuckFor < S.REPORT_AFTER and not wolfHitLock then return "watch" end
    local result = "watch"
    if stuckFor >= S.REPORT_AFTER and (not entry.lastReport or (t - entry.lastReport) >= S.REPORT_EVERY) then
        entry.lastReport = t
        print(string.format("[WTAGarou][StuckGuard] no movement for %.1fs with input held: %s",
            stuckFor, S.snapshot(player)))
        result = "report"
    end
    if (wolfHitLock or (stuckFor >= S.RELEASE_AFTER and S.HUMAN_FORMS[tostring(form)]))
        and not isLegitState(state) and safe(player, "getVehicle") == nil then
        entry.since = t   -- one release per RELEASE_AFTER window
        entry.releases = entry.releases + 1
        print("[WTAGarou][StuckGuard] released movement lock #" .. entry.releases
            .. " in " .. tostring(form) .. ": " .. S.snapshot(player))
        S.release(player)
        if WTAGarou.HUD and WTAGarou.HUD.instance and WTAGarou.HUD.instance.pushNotice then
            pcall(function() WTAGarou.HUD.instance:pushNotice("You shake yourself loose.") end)
        end
        result = "release"
    end
    return result
end

local function onPlayerUpdate(player)
    if not player then return end
    if player.isLocalPlayer and not player:isLocalPlayer() then return end
    if safe(player, "isDead") then return end
    if WTAGarou.HasGarouTrait and not WTAGarou.HasGarouTrait(player) then return end
    local d = WTAGarou.GetData and WTAGarou.GetData(player) or {}
    pcall(S.evaluate, player, d.form or "Homid", now())
end

if Events and Events.OnPlayerUpdate then
    Events.OnPlayerUpdate.Add(onPlayerUpdate)
end
