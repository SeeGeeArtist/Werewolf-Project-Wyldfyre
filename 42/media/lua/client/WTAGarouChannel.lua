--[[
    WTAGarou - Channelled transformation and ongoing howl

    Transformations complete after a cancellable timed action. Howls are
    open-ended timed actions: walking and aiming are allowed, running or the
    standard Cancel Action (Escape/controller B) stops them.

    Search console.txt for: [WTAGarou][Howl]
]]

require "TimedActions/ISBaseTimedAction"

WTAGarou = WTAGarou or {}

require "WTAGarouNet"
require "WTAGarouLocalPlayers"
WTAGarou.Channel = WTAGarou.Channel or {}

local function channelLog(message)
    print("[WTAGarou][Channel] " .. tostring(message))
end

-- ---------------------------------------------------------------------------
-- Action animations
--
-- HOWL tuning lives in Definitions. SHIFT IS NOT CONFIGURABLE: nil, nil only.
-- Do not route transformations through applyActionAnim or an enum/fallback.
-- See tests/channel_hud_test.lua and docs/REGRESSION_CONTRACT.md.
-- ---------------------------------------------------------------------------
--- enumName may be nil to skip the enum path and use a raw anim node directly.
local function applyActionAnim(action, enumName, fallbackNode)
    local anims = CharacterActionAnims
    if enumName and anims and anims[enumName] then
        local ok, err = pcall(function() action:setActionAnim(anims[enumName]) end)
        if ok then
            channelLog("action anim: CharacterActionAnims." .. tostring(enumName))
            return
        end
        channelLog("action anim enum failed: " .. tostring(enumName) ..
            " err=" .. tostring(err))
    elseif enumName then
        channelLog("action anim enum unavailable: " .. tostring(enumName))
    end

    if not fallbackNode or fallbackNode == "" then return end

    local ok, err = pcall(function() action:setActionAnim(fallbackNode) end)
    channelLog("action anim string: " .. tostring(fallbackNode) ..
        " ok=" .. tostring(ok) .. " err=" .. tostring(err))
end

--- Force (or restore) crouch stance for the duration of a channelled action.
--- IsoGameCharacter:setSneaking(boolean) is a confirmed Build 42 method.
local function forceSneak(action, enabled)
    local character = action.character
    if not character then return end

    if enabled then
        local was = false
        pcall(function() was = character:isSneaking() end)
        action.wasSneaking = was and true or false
    end

    local target = enabled and true or (action.wasSneaking and true or false)
    local ok, err = pcall(function() character:setSneaking(target) end)
    channelLog("setSneaking(" .. tostring(target) .. ") ok=" .. tostring(ok) ..
        " err=" .. tostring(err))
end

-- ===========================================================================
-- Transformation
-- ===========================================================================
WTAGarouTransformAction = ISBaseTimedAction:derive("WTAGarouTransformAction")

local function suppressShiftPose(character)
    if not character then return end
    -- BaseAction.setActionAnim can set IsPerformingAnAction=true even when
    -- PerformingAction is nil. That selects the action graph with no named
    -- action. Leave the timed action running, but leave that animation layer.
    character:clearVariable("PerformingAction")
    character:setVariable("IsPerformingAnAction", false)
end

-- Deliberately ignore ANY caller-supplied animation/model arguments.
-- This applies to THIS action only, not ISBaseTimedAction or howling.
function WTAGarouTransformAction:setActionAnim(_ignoredAnimation, _ignoredModels)
    -- B42 can select the enum overload for nil, which dereferences act.toString.
    -- Scope a Java guard to this synchronous call only; keep literal nil,nil.
    local guarded = WTAGarouJava and WTAGarouJava.beginShiftAnimation
        and WTAGarouJava.endShiftAnimation
    if guarded then WTAGarouJava.beginShiftAnimation(self.character) end
    local ok, err = pcall(function()
        ISBaseTimedAction.setActionAnim(self, nil, nil)
    end)
    if guarded then WTAGarouJava.endShiftAnimation() end
    suppressShiftPose(self.character)
    if not ok then error(err) end
end

function WTAGarouTransformAction:isValid()
    if not self.character or self.character:isDead() then return false end
    return true
end

function WTAGarouTransformAction:waitToStart()
    return false
end

function WTAGarouTransformAction:start()
    self.shiftStarted = true
    -- HARD CONTRACT: literal nil, nil, not "None", "", an enum or a fallback.
    local ok, err = pcall(function() self:setActionAnim(nil, nil) end)
    channelLog("shift action anim: nil, nil ok=" .. tostring(ok) ..
        " err=" .. tostring(err))
    -- Still suppress the action layer if the optional base setter threw.
    suppressShiftPose(self.character)

    local anims = WTAGarou.Anims or {}
    forceSneak(self, anims.SHIFT_FORCE_SNEAK ~= false)

    self.character:setVariable("WTAGarou_Shifting", "true")
    self.character:setVariable("WTAGarou_ShiftTarget", tostring(self.targetForm))

    -- 0.4.18: one shift cue per channel start (start() runs once per action;
    -- the runtime also stops the previous instance before playing).
    if not self.shiftSoundPlayed and WTAGarou.ShiftSoundsRuntime then
        self.shiftSoundPlayed = true
        pcall(WTAGarou.ShiftSoundsRuntime.onChannelStart, self.character, tostring(self.targetForm))
    end

    if WTAGarou.Slots and WTAGarou.Slots.enforce then
        WTAGarou.Slots.enforce(self.character, self.targetForm)
    end

    local hud = WTAGarou.HUDFor(self.character)
    if hud then
        hud:setChannelling(self.targetForm, self:getDuration())
    end
end

function WTAGarouTransformAction:update()
    -- Only called while this shift owns the timed action. Do not repeatedly
    -- call setActionAnim here: that setter is what enables the action layer.
    suppressShiftPose(self.character)
    -- 0.4.19: the channel cue repeats for as long as the channel lasts.
    if self.shiftStarted and WTAGarou.ShiftSoundsRuntime and WTAGarou.ShiftSoundsRuntime.onChannelTick then
        pcall(WTAGarou.ShiftSoundsRuntime.onChannelTick, self.character)
    end
end

-- `completed` is true only from perform(): 0.4.67 plays the end cue then.
local function endShiftCue(character, completed)
    if character and WTAGarou.ShiftSoundsRuntime and WTAGarou.ShiftSoundsRuntime.onChannelEnd then
        pcall(WTAGarou.ShiftSoundsRuntime.onChannelEnd, character, completed == true)
    end
end

local function clearShiftVars(character)
    if not character then return end
    character:clearVariable("WTAGarou_Shifting")
    character:clearVariable("WTAGarou_ShiftTarget")
    suppressShiftPose(character)
end

function WTAGarouTransformAction:stop()
    forceSneak(self, false)
    clearShiftVars(self.character)
    endShiftCue(self.character)
    self.shiftStarted = false
    if self.character and not self.suppressServerCancel then
        WTAGarou.Net.ToServer(self.character, "TransformCancel", {
            form = self.targetForm,
        })
    end
    local hud = WTAGarou.HUDFor(self.character)
    if hud then
        hud:clearChannelling()
        hud:flashDenial("shift_interrupted")
    end
    ISBaseTimedAction.stop(self)
end

function WTAGarouTransformAction:forceCancel()
    -- A queued action may be cancelled before it starts. Do not clear
    -- another action's animation variables in that case.
    if self.shiftStarted then
        forceSneak(self, false)
        clearShiftVars(self.character)
        endShiftCue(self.character)
        self.shiftStarted = false
    end
    if self.character and not self.suppressServerCancel then
        WTAGarou.Net.ToServer(self.character, "TransformCancel", {
            form = self.targetForm,
        })
    end
    local hud = WTAGarou.HUDFor(self.character)
    if hud then
        hud:clearChannelling()
    end
end

function WTAGarouTransformAction:perform()
    forceSneak(self, false)
    clearShiftVars(self.character)
    endShiftCue(self.character, true)
    self.shiftStarted = false
    WTAGarou.Net.ToServer(self.character, "TransformConfirm", {
        form = self.targetForm,
    })

    local hud = WTAGarou.HUDFor(self.character)
    if hud then
        hud:clearChannelling()
    end
    ISBaseTimedAction.perform(self)
end

function WTAGarouTransformAction:new(character, targetForm, seconds, previousForm)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.targetForm = targetForm
    o.previousForm = previousForm or "Homid"
    o.maxTime = WTAGarou.SecondsToTicks(seconds or 5)
    -- Your chosen shift rule: only the standard Cancel Action (Escape /
    -- controller B) interrupts a transformation. Movement and aiming do not.
    o.stopOnWalk = false
    o.stopOnRun = false
    o.stopOnAim = false
    o.useProgressBar = true
    o.forceProgressBar = true
    o.caloriesModifier = 3
    o.ignoreHandsWounds = true
    return o
end

-- Drop a transform channel without telling the server anything: used when
-- the server has already changed the form itself (TransformForced).
function WTAGarou.Channel.abort(player)
    if not player then return end
    local queue = ISTimedActionQueue.getTimedActionQueue and ISTimedActionQueue.getTimedActionQueue(player)
    local current = queue and queue.queue and queue.queue[1]
    if current and current.Type == "WTAGarouTransformAction" then
        current.suppressServerCancel = true
        ISTimedActionQueue.clear(player)
    end
    local hud = WTAGarou.HUDFor(player)
    if hud then
        hud:clearChannelling()
    end
end

function WTAGarou.Channel.startChannel(player, targetForm, seconds, previousForm)
    if not player then return end
    ISTimedActionQueue.clear(player)
    ISTimedActionQueue.add(
        WTAGarouTransformAction:new(player, targetForm, seconds, previousForm)
    )
end

-- ===========================================================================
-- Howl
-- ===========================================================================
-- 0.4.69: forms whose howl keeps only the head and neck of the Drink pose.
WTAGarou.HOWL_MASK_FORMS = WTAGarou.HOWL_MASK_FORMS or { Glabro = true, Crinos = true }
function WTAGarou.HowlMasksArm(player)
    local data = player and WTAGarou.GetData and WTAGarou.GetData(player) or nil
    local form = data and data.form or "Homid"
    return WTAGarou.HOWL_MASK_FORMS[form] == true
end

WTAGarouHowlAction = ISBaseTimedAction:derive("WTAGarouHowlAction")

function WTAGarouHowlAction:isValid()
    if not self.character or self.character:isDead() then return false end
    return WTAGarou.HasGarouTrait(self.character)
end

function WTAGarouHowlAction:waitToStart()
    return false
end

function WTAGarouHowlAction:start()
    local anims = WTAGarou.Anims or {}
    -- 0.4.71: authored Bob_WTAGarouHowl when the clip is loaded (Glabro /
    -- Crinos): the action name selects AnimSets/player/actions/WTAGarouHowl.xml
    -- and no arm mask is needed. Otherwise the Drink path below.
    local authored = WTAGarou.UseAuthoredHowl and WTAGarou.UseAuthoredHowl(self.character) == true
    if authored then
        applyActionAnim(self, nil, anims.HOWL_AUTHORED)
    else
        applyActionAnim(self, anims.HOWL, anims.HOWL_FALLBACK)
    end
    forceSneak(self, anims.HOWL_FORCE_SNEAK == true)

    self.character:setVariable("WTAGarou_Howling", "true")
    -- 0.4.69: in Glabro/Crinos the Drink node's raised left arm is masked
    -- away by Java (HowlMaskRuntime): head and neck tilt, limbs keep their
    -- idle/walk layer. Homid keeps the full vanilla drink pose; the wolf
    -- forms are WolfRuntime's (Wolf_howl clip when authored, else Wolf_eat).
    self.character:setVariable("WTAGarou_HowlMask", (not authored) and WTAGarou.HowlMasksArm(self.character) == true)
    self.authoredHowl = authored
    self.tickAccum = 0
    self.sentStop = false
    print("[WTAGarou][Howl] action start")

    local hud = WTAGarou.HUDFor(self.character)
    if hud then
        hud:setChannelling("Howl", 0)
    end
end

function WTAGarouHowlAction:update()
    if self.sentStop then return end

    self.tickAccum = (self.tickAccum or 0) + getGameTime():getMultiplier()
    local tickSeconds = (WTAGarou.Howl and WTAGarou.Howl.TICK_SECONDS) or 0.5
    local requiredTicks = math.max(1, math.floor(
        tickSeconds * (WTAGarou.TICKS_PER_SECOND or 30)
    ))

    if self.tickAccum >= requiredTicks then
        self.tickAccum = self.tickAccum - requiredTicks
        WTAGarou.Net.ToServer(self.character, "HowlTick", {})
        -- 0.4.70: once per howl, half a second in, dump the live tracks and
        -- their bone masks (which track moves the arm?). Read-only.
        if not self.diagDone and WTAGarouJava and WTAGarouJava.debugHowl
                and (self.authoredHowl or self.character:getVariableBoolean("WTAGarou_HowlMask")) then
            self.diagDone = true
            local ok, text = pcall(WTAGarouJava.debugHowl, self.character)
            print("[WTAGarou][HowlDiag] " .. (ok and tostring(text) or ("failed: " .. tostring(text))))
        end
    end
end

local function endHowlAction(action, reason)
    if action.character then
        action.character:clearVariable("WTAGarou_Howling")
        action.character:clearVariable("WTAGarou_HowlMask")
        if not action.sentStop then
            action.sentStop = true
            print("[WTAGarou][Howl] action stop reason=" .. tostring(reason))
            WTAGarou.Net.ToServer(action.character, "HowlStop", {
                reason = tostring(reason),
            })
        end
    end

    -- 0.4.69: this is a plain function, not a method; `self` was nil here
    -- ("attempted index: character of non-table: null" on every cancelled
    -- howl), so the HUD never cleared its "Howl" channelling line.
    local hud = action.character and WTAGarou.HUDFor(action.character) or nil
    if hud then
        hud:clearChannelling()
    end
end
WTAGarou.EndHowlAction = endHowlAction

function WTAGarouHowlAction:stop()
    endHowlAction(self, "cancel_or_run")
    ISBaseTimedAction.stop(self)
end

function WTAGarouHowlAction:forceCancel()
    endHowlAction(self, "force_cancel")
end

function WTAGarouHowlAction:perform()
    -- maxTime is intentionally huge. This is only a defensive cleanup path.
    endHowlAction(self, "forced_completion")
    ISBaseTimedAction.perform(self)
end

function WTAGarouHowlAction:new(character)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.maxTime = 2147483647
    o.stopOnWalk = false
    o.stopOnRun = true
    o.stopOnAim = false
    o.useProgressBar = false
    o.forceProgressBar = false
    return o
end

function WTAGarou.Channel.startHowl(player)
    if not player then return end
    print("[WTAGarou][Howl] startHowl received")
    ISTimedActionQueue.clear(player)
    ISTimedActionQueue.add(WTAGarouHowlAction:new(player))
end
