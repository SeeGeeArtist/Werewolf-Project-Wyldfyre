--[[
    WTAGarou - Server (v0.2.1)

    Authoritative for: transformation approval + rollback, rage regen/drain,
    form-buff application, damage-to-rage, moodle-to-rage, silver-burn state,
    hunter spawn dice, and witness bookkeeping.

    TRANSFORM PROTOCOL (v0.3.0)
    The form is NOT changed on request. The server only validates and reserves,
    the client then channels a cancellable timed action, and the form is applied
    solely when the client confirms completion. This is what makes the shift a
    real timed action instead of an instant flip.

        client  TransformRequest  { form }
        server  -> TransformAccepted { form, seconds, previousForm }  (reserve)
                or TransformDenied   { reason }
        client  channels WTAGarouTransformAction for `seconds`
        client  TransformConfirm  { form }        on perform()   -> applied
        client  TransformCancel   { form }        on stop()      -> reservation dropped

    HOWL PROTOCOL (ongoing, positional sound)
    HowlRequest -> HowlAccepted (starts the requester's endless timed action)
    and a single HowlStarted broadcast so EVERY client attaches one looping 3D
    sound to that character's emitter. The client then sends periodic HowlTick
    commands; the server alone moves Rage toward WTAGarou.BaselineRage(d) and
    deliberately does NOT end the howl on reaching it. HowlStop (or death)
    clears server state and broadcasts HowlStopped so every client stops that
    owner's loop handle.

    Search console.txt for: [WTAGarou][Howl]

    Client -> Server:
        TransformRequest   { form=<string> }
        TransformConfirm   { form=<string> }   -- channel completed
        TransformCancel    { form=<string> }   -- player-cancelled channel
        HowlRequest        {}
        HowlTick           {}
        HowlStop           { reason=<string> }
        WitnessTick        { witnesses=<table> }
        DeliriumReport     { witnesses=<list> }
        TransformBroadcast { form=<string> }
    Server -> Client:
        TransformAccepted  { form=<string>, seconds=<number>, previousForm=<string> }
        TransformCompleted { form=<string>, previousForm=<string> }
        TransformDenied    { reason=<string> }
        RageSync           { rage=<number>, form=<string>, infamy=<number>, wyrm=<number|nil> }
        HowlAccepted       {}
        HowlStarted        { ownerID, form, x, y, z }   -- broadcast, once per howl
        HowlStopped        { ownerID, reason }          -- broadcast, once per howl
        FrenzyForced       {}
]]

WTAGarou = WTAGarou or {}

require "WTAGarouNet"
require "WTAGarouCrinosBurstServer"
require "WTAGarouVehicleShiftServer"
require "WTAGarouPaws"

local function completedShiftEffects(player,previous,target,forced)
    if WTAGarou.CrinosBurst then
        local ok,err=pcall(WTAGarou.CrinosBurst.onCompleted,player,previous,target)
        if not ok then print("[WTAGarou][CrinosBurst] completion effect failed: "..tostring(err)) end
    end
    -- 0.4.39: a bulk form (Crinos, Hispo) does not fit in a car seat.
    if WTAGarou.VehicleShift and WTAGarou.VehicleShift.onCompleted then
        local ok,err=pcall(WTAGarou.VehicleShift.onCompleted,player,previous,target,forced)
        if not ok then print("[WTAGarou][VehicleShift] completion effect failed: "..tostring(err)) end
    end
end

-- Routed through WTAGarou.Net so these still work in single player, where
-- sendServerCommand has no client to reach. See WTAGarouNet.lua.
local function sendTo(player, cmd, args)
    if not player then return end
    WTAGarou.Net.ToClient(player, cmd, args or {})
end

local function rageSyncArgs(d)
    -- 0.4.22: silver = the silver-burned part keys (health panel line).
    return { rage = d.rage, form = d.form, infamy = d.infamy, wyrm = d.infectionBurn,
             silver = d.silverBurns, lodged = d.silverLodged, trueForm=d.trueForm,
             -- 0.4.85: send FALSE, not nil - a nil key is simply absent on the
             -- wire, so DebugResetIdentity never reached the client's copy and
             -- the startup panel stayed "locked" until a relog.
             identityLocked=d.identityLocked==true,
             auspice=d.auspice, auspiceLocked=d.auspiceLocked==true, baseline=WTAGarou.BaselineRage(d),
             -- 0.4.69 HUD: current baseline-bracket half width in Rage points.
             bracket = WTAGarou.BaselineBracketHalfWidth and WTAGarou.BaselineBracketHalfWidth(d.bracketStacks or 0) or nil }
end
WTAGarou.RageSyncArgs = rageSyncArgs


local function broadcast(cmd, args)
    WTAGarou.Net.Broadcast(cmd, args or {})
end

local function howlLog(message)
    print("[WTAGarou][Howl] server " .. tostring(message))
end

-- getOnlineID() is the only id both the server and every client agree on for a
-- given character. In single player it is a constant, which is fine: the local
-- client looks the owner up with the same call.
local function ownerIDOf(player)
    if not player or not player.getOnlineID then return -1 end
    local ok, id = pcall(function() return player:getOnlineID() end)
    if ok and id ~= nil then return id end
    return -1
end

-- One broadcast per howl. Never call this from HowlTick or clients would
-- restack the loop every half second.
local function broadcastHowlStarted(player, d)
    local ownerID = ownerIDOf(player)
    broadcast("HowlStarted", {
        ownerID = ownerID,
        form    = d.form,
        x       = player:getX(),
        y       = player:getY(),
        z       = player:getZ(),
    })
    howlLog("broadcast start: owner=" .. tostring(ownerID) ..
        " form=" .. tostring(d.form) .. " rage=" .. tostring(d.rage))
end

local function broadcastHowlStopped(player, reason)
    local ownerID = ownerIDOf(player)
    broadcast("HowlStopped", {
        ownerID = ownerID,
        reason  = tostring(reason or "unspecified"),
    })
    howlLog("broadcast stop: owner=" .. tostring(ownerID) ..
        " reason=" .. tostring(reason))
end

-- Single place that clears howl state, so every exit path stays symmetrical.
local function endHowl(player, d, reason)
    if not d.howling then
        howlLog("end ignored: not howling owner=" .. tostring(ownerIDOf(player)) ..
            " reason=" .. tostring(reason))
        return false
    end
    d.howling        = nil
    d.lastHowlTickAt = nil
    d.howlTickCount  = nil
    broadcastHowlStopped(player, reason)
    return true
end

-- ---------------------------------------------------------------------------
-- 0.4.66: on a real server the SERVER strips forbidden clothing when a shift
-- lands (Build 42 MP inventories are server-owned; a client-side drop left
-- the server still believing the shirt was worn). Returns the summary the
-- client presents (rip sound, model reset, notice). Single player returns
-- nil and the client strips itself as before.
-- ---------------------------------------------------------------------------
local function serverStrip(player, target, forced)
    if not (isServer and isServer()) then return nil end
    if not (WTAGarou.Clothing and WTAGarou.Clothing.dropForbidden) then return nil end
    local W = WTAGarou.Wardrobe
    local before = (W and W.count and W.count(player)) or 0
    local ok, dropped, damaged, tore = pcall(WTAGarou.Clothing.dropForbidden, player, target,
        { forced = forced == true })
    if not ok then
        print("[WTAGarou][Strip] server strip failed: " .. tostring(dropped))
        return nil
    end
    local prof = WTAGarou.ShiftStrip and WTAGarou.ShiftStrip.profileFor and WTAGarou.ShiftStrip.profileFor(target)
    return { dropped = dropped or 0, damaged = damaged or 0, tore = tore == true, forced = forced == true,
             modelChanged = (dropped or 0) > 0 or ((damaged or 0) > 0 and ((prof and prof.holes) or 0) > 0),
             -- what the server put on the floor, so the client's Dress can find it
             wardrobe = (W and W.entriesSince and (dropped or 0) > 0) and W.entriesSince(player, before) or nil }
end

-- ---------------------------------------------------------------------------
-- Apply passive stat/hitbox/armor/carry buffs for the character's current form.
-- Safe to call every tick; PZ tolerates repeated setters.
-- ---------------------------------------------------------------------------
local function applyFormBuffs(player)
    if not player then return end
    local d  = WTAGarou.GetData(player)
    local fd = WTAGarou.GetForm(d.form)

    -- NOTE: there is deliberately no setScale() call here.
    -- IsoPlayer / IsoGameCharacter expose no setScale in Build 42, so the old
    -- `if player.setScale then` guard silently did nothing on every shift.
    -- That is why carry weight was the ONLY thing that appeared to change.
    -- Visual size now comes from the per-form `model` script (which carries its
    -- own scale) applied client-side in WTAGarouVisual.lua.

    if player.setMaxWeightBase then
        -- 8 is the vanilla base carry weight. Apply the form multiplier, then
        -- raise the result to the form's floor if it has one, so Lupus stays
        -- usable instead of being unable to carry its own saddlebag.
        local weight = 8 * (fd.maxCarryMultiplier or 1.0)
        if fd.minCarryWeight and weight < fd.minCarryWeight then
            weight = fd.minCarryWeight
        end
        -- setMaxWeightBase(int) -- the engine signature is an INT, so a
        -- fractional pound silently truncated. Round instead of dropping it.
        pcall(function() player:setMaxWeightBase(math.floor(weight + 0.5)) end)
    end

    -- setSpeedMod is kept for compatibility only. In B42.20.2 source,
    -- IsoGameCharacter.speedMod is read by zombie code alone; player movement
    -- comes from the WalkSpeed/RunSpeed animation variables, which the Java
    -- TraitsRuntime multiplies per gait (WTAGarou.Traits, applied from the
    -- client visual refresh). fd.moveSpeed therefore does not move a player.
    if player.setSpeedMod then
        pcall(function() player:setSpeedMod(fd.moveSpeed or 1.0) end)
    end

    if player.setVariable then
        player:setVariable("WTAGarou_SpeedMul", tostring(fd.moveSpeed))
        player:setVariable("WTAGarou_AttackSpeed", tostring(fd.attackSpeedMult or 1.0))
        player:setVariable("WTAGarou_Form", tostring(d.form))
        player:setVariable("WTAGarou_Quadruped", fd.quadruped and "true" or "false")
    end

    local md = player:getModData()
    md.WTAGarou_ArmorReduction   = fd.damageReduction
    md.WTAGarou_HealingMult      = fd.healingMult
    -- meleeDamage was defined in every form since 0.3.0 and read by NOTHING.
    -- It is now published here and consumed by the hit hooks below.
    md.WTAGarou_MeleeMult        = fd.meleeDamage
    md.WTAGarou_AttackSpeedMult  = fd.attackSpeedMult
    md.WTAGarou_InfectionResist  = fd.infectionResist
    md.WTAGarou_UnarmedBonus     = fd.unarmedDamageBonus
    md.WTAGarou_UnarmedPiercing  = fd.unarmedPiercing
    md.WTAGarou_ShoveBonus       = fd.shovePowerBonus
    md.WTAGarou_ToughFeet        = fd.toughFeet
    md.WTAGarou_StealthBonus     = fd.stealthBonus
    md.WTAGarou_ReachBonus       = fd.reachBonus
    md.WTAGarou_Quadruped        = fd.quadruped
    -- Read by WTAGarouVisual on every client that renders this character.
    local modelScript = fd.modelScript

    if fd.modelScriptFemale and player.isFemale then
        local ok, isFemale = pcall(function()
            return player:isFemale()
        end)
    
        if ok and isFemale then
            modelScript = fd.modelScriptFemale
        end
    end

    md.WTAGarou_ModelScript = modelScript
    md.WTAGarou_SkinTexture = fd.skinTextureName

    -- Quadrupeds cannot hold gear in their forepaws. Strip the hands the
    -- moment the form lands so the transition can never leave a rifle floating
    -- in a wolf's mouth-less grip.
    if WTAGarou.Slots and WTAGarou.Slots.enforce then
        WTAGarou.Slots.enforce(player, d.form)
    end
end

WTAGarou.ApplyFormBuffs = applyFormBuffs

Events.OnCreatePlayer.Add(function(playerIndex, player)
    if not player then return end
    local d = WTAGarou.GetData(player)
    applyFormBuffs(player)
    sendTo(player, "RageSync", rageSyncArgs(d))
end)

-- ---------------------------------------------------------------------------
-- Moodle -> rage.
--
-- Build 42.20 registers moodles as UPPER_SNAKE statics (MoodleType.PANIC).
-- The 0.4.x code looked up CamelCase names only, so on 42.20 every lookup was
-- nil and moodles never changed Rage; WTAGarou.MoodleTypeFor handles both.
-- Negative moodles raise Rage (weighted, fear first), sad moodles lower it,
-- and contentment (0.4.45: no Hungry, no Thirst, Well Fed) drifts Rage
-- toward the character's baseline like a slow howl.
-- ---------------------------------------------------------------------------
local MOODLE_SETS
local function moodleSets()
    if MOODLE_SETS then return MOODLE_SETS end
    local function resolve(map)
        local list = {}
        for name, weight in pairs(map or {}) do
            local mt = WTAGarou.MoodleTypeFor(name)
            if mt ~= nil then table.insert(list, { type = mt, weight = weight, name = name }) end
        end
        return list
    end
    MOODLE_SETS = {
        negative = resolve(WTAGarou.Rage.MOODLE_WEIGHTS),
        sad      = resolve(WTAGarou.Rage.SAD_MOODLES),
        hungry   = WTAGarou.MoodleTypeFor("Hungry"),
        thirsty  = WTAGarou.MoodleTypeFor("Thirst"),
        wellFed  = WTAGarou.MoodleTypeFor("FoodEaten"),
    }
    print(string.format("[WTAGarou][Rage] moodle bindings: negative=%d sad=%d contentment=%s/%s/%s",
        #MOODLE_SETS.negative, #MOODLE_SETS.sad, tostring(MOODLE_SETS.hungry ~= nil),
        tostring(MOODLE_SETS.thirsty ~= nil), tostring(MOODLE_SETS.wellFed ~= nil)))
    return MOODLE_SETS
end
WTAGarou.MoodleSets = moodleSets

-- 0.4.69: unweighted sum of the engine moodle levels (0-4) across a list:
-- the "stacks" the baseline bracket widens with.
local function stackLevels(moodles, list)
    local total = 0
    for _, entry in ipairs(list) do
        local lvl = 0
        pcall(function() lvl = moodles:getMoodleLevel(entry.type) or 0 end)
        if lvl > 0 then total = total + lvl end
    end
    return total
end
WTAGarou.MoodleStackLevels = stackLevels

local function weightedLevels(moodles, list, breakdown)
    local total = 0
    for _, entry in ipairs(list) do
        local lvl = 0
        pcall(function() lvl = moodles:getMoodleLevel(entry.type) or 0 end)
        if lvl > 0 then
            total = total + lvl * entry.weight
            if breakdown then
                breakdown[#breakdown + 1] = string.format("%s%d x%.2g", tostring(entry.name or entry.type), lvl, entry.weight)
            end
        end
    end
    return total
end
WTAGarou.RAGE_PRESSURE_LOG_SECONDS = 30

-- Pull Rage toward a center by at most `amount` (howl semantics).
local function pullToward(player, center, amount)
    local d = WTAGarou.GetData(player)
    local delta = center - (d.rage or 0)
    if math.abs(delta) > 0.001 then
        local pull = math.min(amount, math.abs(delta))
        WTAGarou.AddRage(player, delta > 0 and pull or -pull)
    end
end

-- ---------------------------------------------------------------------------
-- Forced shifts.
-- ---------------------------------------------------------------------------
-- At 0 Rage return to this character's true form, no channel or cost.
local function forceDepletedShift(p, d, now)
    local prev = d.form
    d.form          = WTAGarou.BaseForm(d)
    d.formChangedAt = now
    d.isFrenzied    = false
    d.pendingForm, d.pendingFrom, d.pendingCost, d.pendingExpiresAt, d.pendingForced = nil, nil, nil, nil, nil
    d.crinosCountdownAt = nil
    applyFormBuffs(p)
    print("[WTAGarou][Rage] " .. tostring(prev) .. " depleted; forced " .. d.form)
    sendTo(p, "TransformForced", { form = d.form, previousForm = prev, reason = "rage_depleted" })
    sendTo(p, "RageSync", rageSyncArgs(d))
end

-- 100 Rage held for FORCE_CRINOS_SECONDS: reserve Crinos with the short
-- forced channel. The client runs the 0.25 s channel and confirms as usual.
local function forceCrinosShift(p, d, now)
    d.crinosCountdownAt = nil
    local seconds = WTAGarou.Rage.FORCE_CRINOS_CHANNEL or 0.25
    d.pendingForm      = "Crinos"
    d.pendingFrom      = d.form
    d.pendingCost      = WTAGarou.GetForm("Crinos").rageCost or 0
    d.pendingForced    = true
    d.pendingExpiresAt = now + 6
    print("[WTAGarou][Rage] full Rage held; forcing Crinos")
    sendTo(p, "TransformAccepted",
        { form = "Crinos", seconds = seconds, previousForm = d.form, forced = true })
end

-- 0.4.21: the Resist cycle. d.resists counts successful Resists since Rage
-- last fell under FORCE_CRINOS_CANCEL_BELOW (or Crinos was entered);
-- d.resistRestUntil is the hidden rest interval's end. The current countdown
-- length is d.crinosCountdownSeconds.
local function resetResistCycle(p, d, reason)
    if (d.resists or 0) > 0 or d.resistRestUntil then
        print("[WTAGarou][Resist] cycle reset (" .. tostring(reason) .. ") after "
            .. tostring(d.resists or 0) .. " resist(s)")
        sendTo(p, "ResistReset", { reason = reason, resists = d.resists or 0 })
    end
    d.resists = 0
    d.resistRestUntil = nil
end

local function startCrinosCountdown(p, d, now)
    local R = WTAGarou.Rage
    local seconds = WTAGarou.ResistCountdownSeconds(d.resists or 0, R.FORCE_CRINOS_SECONDS or 10)
    d.crinosCountdownAt = now
    d.crinosCountdownSeconds = seconds
    d.resistRestUntil = nil
    print(string.format("[WTAGarou][Rage] Rage %.0f in %s; Crinos countdown %.2fs started (resists=%d)",
        d.rage or 0, tostring(d.form), seconds, d.resists or 0))
    sendTo(p, "CrinosCountdown", { seconds = seconds, resists = d.resists or 0 })
end

local function updateCrinosCountdown(p, d, now)
    local R = WTAGarou.Rage
    local below = R.FORCE_CRINOS_CANCEL_BELOW or 95
    if d.form == "Crinos" or d.pendingForced then
        if d.crinosCountdownAt then
            d.crinosCountdownAt = nil
            sendTo(p, "CrinosCountdownCancelled", { reason = "in_crinos" })
        end
        resetResistCycle(p, d, "in_crinos")
        return
    end
    if d.rage < below then
        if d.crinosCountdownAt then
            d.crinosCountdownAt = nil
            sendTo(p, "CrinosCountdownCancelled", { reason = "rage_dropped" })
        end
        resetResistCycle(p, d, "rage_dropped")
        return
    end
    if d.crinosCountdownAt then
        if (now - d.crinosCountdownAt) >= (d.crinosCountdownSeconds or R.FORCE_CRINOS_SECONDS or 10) then
            forceCrinosShift(p, d, now)
        end
    elseif d.resistRestUntil then
        -- Hidden rest after a Resist: Rage is still >= 95, wait it out.
        if now >= d.resistRestUntil then startCrinosCountdown(p, d, now) end
    elseif d.rage >= R.MAX then
        startCrinosCountdown(p, d, now)
    end
end
WTAGarou.UpdateCrinosCountdown = updateCrinosCountdown

-- 0.4.21: Resist. Succeeds only while a countdown is running.
local function resistCountdown(p, d, now)
    if not d.crinosCountdownAt then
        sendTo(p, "ResistResult", { ok = false, reason = "nothing_to_resist" })
        return false
    end
    local resisted = d.crinosCountdownSeconds or WTAGarou.Rage.FORCE_CRINOS_SECONDS or 10
    d.crinosCountdownAt = nil
    d.resists = (d.resists or 0) + 1
    local rest = WTAGarou.ResistRestSeconds(resisted)
    d.resistRestUntil = now + rest
    local nextSeconds = WTAGarou.ResistCountdownSeconds(d.resists, WTAGarou.Rage.FORCE_CRINOS_SECONDS or 10)
    print(string.format("[WTAGarou][Resist] #%d resisted a %.2fs countdown; hidden rest %.1fs; next countdown %.2fs",
        d.resists, resisted, rest, nextSeconds))
    sendTo(p, "CrinosCountdownCancelled", { reason = "resisted" })
    sendTo(p, "ResistResult", { ok = true, resists = d.resists, resisted = resisted, nextSeconds = nextSeconds })
    return true
end
WTAGarou.ResistCountdown = resistCountdown

-- ---------------------------------------------------------------------------
-- Endurance refund per form (Homid 0 < Glabro < Hispo < Lupus < Crinos).
-- Build 42 stats live behind Stats:get/set(CharacterStat); Build 41 exposed
-- getEndurance/setEndurance. Both are tried.
-- ---------------------------------------------------------------------------
local lastEndurance = {}
local function readEndurance(stats)
    if CharacterStat and CharacterStat.ENDURANCE and stats.get then
        local ok, v = pcall(function() return stats:get(CharacterStat.ENDURANCE) end)
        if ok and v then return v, "b42" end
    end
    if stats.getEndurance then
        local ok, v = pcall(function() return stats:getEndurance() end)
        if ok and v then return v, "b41" end
    end
    return nil
end
local function writeEndurance(stats, value, api)
    value = math.max(0, math.min(1, value))
    if api == "b42" then
        pcall(function() stats:set(CharacterStat.ENDURANCE, value) end)
    elseif api == "b41" then
        pcall(function() stats:setEndurance(value) end)
    end
end
local function refundEndurance(p, d)
    local factor = (WTAGarou.EnduranceRefund or {})[d.form] or 0
    local stats = p.getStats and p:getStats() or nil
    if not stats then return end
    local cur, api = readEndurance(stats)
    if not cur then return end
    local key = p:getOnlineID()
    local prev = lastEndurance[key]
    if prev and factor > 0 and cur < prev then
        local refund = (prev - cur) * factor
        cur = cur + refund
        writeEndurance(stats, cur, api)
    end
    lastEndurance[key] = cur
end
WTAGarou.RefundEndurance = refundEndurance
-- 0.4.68: a deliberate stamina cost (door charge). Written straight through
-- and recorded as the new baseline so the per-form refund does not hand most
-- of it back on the next tick.
local function spendEndurance(p, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return nil end
    local stats = p.getStats and p:getStats() or nil
    if not stats then return nil end
    local cur, api = readEndurance(stats)
    if not cur then return nil end
    local next_ = math.max(0, cur - amount)
    writeEndurance(stats, next_, api)
    if p.getOnlineID then lastEndurance[p:getOnlineID()] = next_ end
    return next_
end
WTAGarou.SpendEndurance = spendEndurance

-- ---------------------------------------------------------------------------
-- Rage engine: form regen/drain, moodles, Crinos berserk rules.
-- Rates are per real second (dt from the wall clock), not per tick.
-- ---------------------------------------------------------------------------
-- 0.4.75: the dry revert has a buffer. Rage must stay under DEPLETED_BELOW
-- for DEPLETED_HOLD_S continuous seconds, and never within DEPLETED_HOLD_S
-- of the last shift: shifting at exactly the form's cost (20 Rage into
-- Glabro or Hispo) used to land on 0 and revert on the very next tick even
-- while Rage was climbing. Returns true when the revert fired.
function WTAGarou.DepletedCheck(p, d, now)
    local R = WTAGarou.Rage
    if d.form == WTAGarou.BaseForm(d) or d.rage >= (R.DEPLETED_BELOW or 0.000001) then
        d.depletedSince = nil
        return false
    end
    local hold = tonumber(R.DEPLETED_HOLD_S) or 0
    d.depletedSince = d.depletedSince or now
    if (now - d.depletedSince) < hold or (now - (d.formChangedAt or 0)) < hold then return false end
    d.rage = 0
    d.depletedSince = nil
    forceDepletedShift(p, d, now)
    return true
end

local function rageTick(p, d, now)
    local R = WTAGarou.Rage
    local dt = now - (d.lastRageTickAt or now)
    d.lastRageTickAt = now
    if dt <= 0 then return end
    dt = math.min(dt, 2.0)

    -- Check before positive moodles can rescue a form that already hit zero.
    if WTAGarou.DepletedCheck(p, d, now) then return end

    -- Base form drain: only Crinos has a non-zero passive rate (burns 1/s;
    -- 0.4.39: half that for the Berserker breed).
    local regen = (R.REGEN_PER_SECOND or {})[d.form] or 0
    if d.form == "Crinos" then
        -- 0.4.69: the drain escalates with time held (see CRINOS_ESCALATION);
        -- the clock lives in the tick so it needs no other code path.
        -- 0.4.70: held time is the sum of the tick deltas (each capped at
        -- 2 s, and the tick only runs while the game updates), so a paused
        -- game does not count toward the escalation; `now - startedAt` did.
        local held = d.crinosHeldSeconds or 0      -- time held before this tick
        d.crinosHeldSeconds = held + dt
        if WTAGarou.CrinosDrainPerSecond then regen = WTAGarou.CrinosDrainPerSecond(d, held) end
        local steps = WTAGarou.CrinosEscalationSteps and WTAGarou.CrinosEscalationSteps(held) or 0
        if steps ~= (d.crinosEscalationSteps or 0) then
            d.crinosEscalationSteps = steps
            print(string.format("[WTAGarou][Rage] Crinos held %.0fs: passive drain now %.2f/s (step %d)", held, regen, steps))
            sendTo(p, "CrinosDrain", { perSecond = regen, steps = steps, held = held })
        end
    elseif d.crinosHeldSeconds or d.crinosEscalationSteps then
        d.crinosHeldSeconds, d.crinosEscalationSteps = nil, nil
    end
    -- 0.4.63: the passive rate, the negative-moodle pressure and the sad
    -- drain are summed and applied ONCE. Applying them one after another
    -- clamped the positive part at 100 and then let the sad drain pull the
    -- result under it, so with one Unhappy level up Rage could never rest on
    -- 100 (Oct 15 playtest: "goes up to 99 and just sits there, even in
    -- Crinos; cheated to 100 and it dropped back to 99") and the 100-Rage
    -- countdown never started.
    local net = regen * dt

    local moodles = p.getMoodles and p:getMoodles() or nil
    if moodles then
        local sets = moodleSets()
        local parts = {}
        local neg = weightedLevels(moodles, sets.negative, parts)
        if neg > 0 then
            net = net + R.ON_MOODLE_LEVEL_PER_SECOND * neg * dt
            -- 0.4.20: name the moodles behind a Rage climb (at most every 30 s).
            if (now - (d.lastRagePressureLog or 0)) >= (WTAGarou.RAGE_PRESSURE_LOG_SECONDS or 30) then
                d.lastRagePressureLog = now
                print(string.format("[WTAGarou][Rage] moodle pressure +%.3f/s in %s: %s",
                    R.ON_MOODLE_LEVEL_PER_SECOND * neg, tostring(d.form), table.concat(parts, ", ")))
            end
        end
        local sad = weightedLevels(moodles, sets.sad)
        if sad > 0 then net = net - R.SAD_MOODLE_LEVEL_PER_SECOND * sad * dt end
        -- 0.4.69: baseline-bracket stacks (every negative moodle level) are
        -- read every tick so the HUD bracket is live even while no drift runs.
        d.bracketStacks = stackLevels(moodles, sets.negative) + stackLevels(moodles, sets.sad)
        if net ~= 0 then WTAGarou.AddRage(p, net) end
        net = 0
        -- 0.4.45 contentment drift toward the baseline (Oct 7 design): no
        -- Hungry moodle 0.75 x, no Thirst moodle 0.75 x, Well Fed +0.5 x the
        -- old well-fed rate. Hungry AND thirsty = no drift.
        local function level(mt)
            local lvl = 0
            if mt ~= nil then pcall(function() lvl = moodles:getMoodleLevel(mt) or 0 end) end
            return lvl
        end
        -- 0.4.45-0.4.69 the drift paused for the whole frenzy band (Rage
        -- >= 95), which is why a fed, watered character cheated to 98 never
        -- pulled back (Oct 18 playtest). 0.4.70: it pauses only while the
        -- 100-Rage countdown is actually running, so that countdown and
        -- its Resist stay exactly as confirmed; the moment a Resist lands
        -- (hidden rest) or Rage is merely high, contentment pulls again.
        local paused = d.crinosCountdownAt ~= nil
        if WTAGarou.ContentPullPaused then paused = WTAGarou.ContentPullPaused(d) end
        if not paused then
            local pull = WTAGarou.ContentPullPerSecond(level(sets.hungry) > 0, level(sets.thirsty) > 0,
                level(sets.wellFed) > 0, d.form)
            if pull > 0 then
                local baseline = WTAGarou.BaselineRage(d)
                -- 0.4.69 baseline bracket: inside PER_STACK x stacks of the
                -- baseline the drift is halved; stacks = every negative
                -- moodle level (Rage-raising and Rage-draining alike).
                if WTAGarou.BaselinePullMultiplier then
                    local stacks = d.bracketStacks or 0
                    local mult = WTAGarou.BaselinePullMultiplier(d.rage, baseline, stacks)
                    if mult ~= 1 and (now - (d.lastBracketLog or 0)) >= (WTAGarou.RAGE_PRESSURE_LOG_SECONDS or 30) then
                        d.lastBracketLog = now
                        print(string.format("[WTAGarou][Rage] baseline bracket: %d stacks, +/-%d around %d, drift x%.2f",
                            stacks, WTAGarou.BaselineBracketHalfWidth(stacks), baseline, mult))
                    end
                    pull = pull * mult
                end
                pullToward(p, baseline, pull * dt)
            end
        end
    end
    if net ~= 0 then WTAGarou.AddRage(p, net) end

    -- Berserk rules.
    -- 0.4.19: dry once the panel reads 0 (Rage < DEPLETED_BELOW), see Definitions.
    if WTAGarou.DepletedCheck(p, d, now) then return end
    updateCrinosCountdown(p, d, now)
end
WTAGarou.RageTick = rageTick

-- The Rage engine used to run ONLY from Events.OnTick over
-- getOnlinePlayers(). The 0.4.11 playtest showed no Rage movement at all in
-- single player (no Homid regen, no Crinos drain, no 100-Rage countdown)
-- while the OnPlayerUpdate regeneration in this same file kept logging, so
-- in single player the engine now runs from OnPlayerUpdate for the player
-- being updated. IsoPlayer.update only raises OnPlayerUpdate for local
-- (non-remote) players, so a dedicated server keeps the OnTick sweep over
-- getOnlinePlayers(). Both paths share rageUpdate, throttled per player.
local RAGE_TICK_SECONDS = 0.5
local rageTickAlive = false
local function rageUpdate(p)
    if not p or p:isDead() then return end
    local d = WTAGarou.GetData(p)
    local now = WTAGarou.NowSeconds()
    if (now - (d.lastRageUpdateAt or 0)) < RAGE_TICK_SECONDS then return end
    d.lastRageUpdateAt = now
    if not rageTickAlive then
        rageTickAlive = true
        print(string.format("[WTAGarou][Rage] engine alive: form=%s rage=%.1f regen/s=%s",
            tostring(d.form), d.rage or 0,
            tostring((WTAGarou.Rage.REGEN_PER_SECOND or {})[d.form] or 0)))
    end
    rageTick(p, d, now)
    refundEndurance(p, d)
    sendTo(p, "RageSync", rageSyncArgs(d))
    applyFormBuffs(p)
end
WTAGarou.RageUpdate = rageUpdate

-- ---------------------------------------------------------------------------
-- 0.4.75: in Build 42 multiplayer the SERVER owns every player's BodyDamage.
-- BodyDamage.Update() returns at once on a client for a living player, the
-- server simulates it, applies PvP/zombie wounds to its copy
-- (hitConsequences -> DamageFromWeapon) and pushes the whole BodyDamage to
-- the owner every 2 s (NetworkPlayerManager damageUpdateLimit) and after
-- each wound (syncDamage). Anything a client writes into its own body
-- (burns, healing, damage scaling) is overwritten within two seconds: the
-- Oct 19 "silver burn healed pretty quick". So in multiplayer the body work
-- below (acute-damage Rage, armour refund, regeneration, health pool) runs
-- HERE in the server sweep, on the authoritative copy; the clients only
-- run it in single player (OnPlayerUpdate, gated further down).
-- ---------------------------------------------------------------------------
local partSnap = setmetatable({}, { __mode = "k" })   -- player -> { [i] = health }
local lastHealth = {}                                   -- onlineID -> overall health (shared with OnPlayerUpdate)
WTAGarou.ACUTE_PART_DROP = 0.75   -- part health lost in one sweep that counts as a hit, not bleeding

-- Pure: refund (1 - intake) of every acute part drop. `parts` = list of
-- { health = n, add = function(v) }, `prev` = last sweep's healths (or nil).
-- Returns the new snapshot and the total refunded.
-- 0.4.79: a drop that CONTINUES sweep after sweep on the same part is
-- damage over time (a burn, a silver burn, heavy bleeding), not a hit, and
-- is not refunded: the Oct 21 server log showed "0.3 part health refunded"
-- every sweep while a Glabro burned, i.e. the toughness refund was quietly
-- undoing a third of every burn tick. Only the FIRST sweep of a drop streak
-- is treated as the hit; the snapshot carries `streak[i] = true` while the
-- part keeps dropping.
function WTAGarou.ToughnessRefund(parts, prev, intake)
    local snap, refunded = {}, 0
    local prevStreak = (prev and prev.streak) or {}
    local streak = {}
    intake = (type(intake) == "number" and intake > 0 and intake <= 1) and intake or 1
    for i, part in ipairs(parts) do
        local h = part.health
        local was = prev and prev[i]
        if was and (was - h) >= WTAGarou.ACUTE_PART_DROP then
            if intake < 1 and not prevStreak[i] then
                local back = (was - h) * (1 - intake)
                part.add(back)
                h = h + back
                refunded = refunded + back
            end
            streak[i] = true
        end
        snap[i] = h
    end
    snap.streak = streak
    return snap, refunded
end

local function bodyParts(bd)
    local list = {}
    pcall(function()
        local parts = bd:getBodyParts()
        for i = 0, parts:size() - 1 do
            local bp = parts:get(i)
            list[#list + 1] = { health = bp:getHealth(), add = function(v) bp:AddHealth(v) end }
        end
    end)
    return list
end

function WTAGarou.BodySweep(player, d, now)
    if not (player and player.getBodyDamage) then return end
    local bd = player:getBodyDamage(); if not bd then return end
    d = d or WTAGarou.GetData(player)
    -- Health pool (0.4.72 numbers) without a Java agent on the server:
    -- refund the untaken share of every acute part drop. A hit that kills
    -- outright in one tick is beyond this (the engine dies before the sweep).
    if d.isGarou then
        local intake = WTAGarou.DamageIntakeFor and WTAGarou.DamageIntakeFor(d.form) or 1
        local snap, back = WTAGarou.ToughnessRefund(bodyParts(bd), partSnap[player], intake)
        partSnap[player] = snap
        if back > 0 then
            pcall(function() bd:calculateOverallHealth() end)
            print(string.format("[WTAGarou] %s took a hit in %s: %.1f part health refunded (intake %.2f)",
                tostring(player:getUsername()), tostring(d.form), back, intake))
        end
    else
        partSnap[player] = nil
    end
    -- Acute-damage Rage and the armour refund (same rule as the client path).
    local id = player:getOnlineID()
    local hp = bd:getOverallBodyHealth()
    local prev = lastHealth[id]
    if prev and hp < prev then
        local taken = prev - hp
        local reduc = player:getModData().WTAGarou_ArmorReduction or 0
        WTAGarou.AddRage(player, WTAGarou.Rage.ON_DAMAGE_TAKEN * taken * (1 - reduc))
    end
    lastHealth[id] = hp
    -- 0.4.82: the vanilla barefoot scratch loop runs on the server in
    -- multiplayer; tough-footed forms shrug its fresh foot wounds off here.
    if WTAGarou.Paws and WTAGarou.Paws.sweep then
        local ok, err = pcall(WTAGarou.Paws.sweep, player, d, bd)
        if not ok then print("[WTAGarou][Paws] sweep failed: " .. tostring(err)) end
    end
    WTAGarou.Regenerate(player, bd)
end

-- Dedicated server: sweep every connected player.
local rageTickAccum = 0
Events.OnTick.Add(function()
    if not isServer() then return end
    rageTickAccum = rageTickAccum + 1
    if rageTickAccum < 10 then return end
    rageTickAccum = 0
    local players = getOnlinePlayers()
    if not players then return end
    for i=0, players:size()-1 do
        local p = players:get(i)
        rageUpdate(p)
        local ok, err = pcall(WTAGarou.BodySweep, p, WTAGarou.GetData(p), WTAGarou.NowSeconds())
        if not ok then print("[WTAGarou] body sweep failed: " .. tostring(err)) end
    end
end)

-- ---------------------------------------------------------------------------
-- Rage on damage taken / dealt.
-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
-- Form melee multiplier.
--
-- Build 42 exposes no setDamageMultiplier and no attack-speed setter on
-- IsoGameCharacter, so a form's extra power is delivered by subtracting the
-- surplus directly from the victim's health after the vanilla hit resolves.
-- IsoGameCharacter.getHealth()/setHealth(float) are both public.
-- ---------------------------------------------------------------------------
local function isRangedWeapon(weapon)
    if not weapon or not weapon.isRanged then return false end
    local ok, ranged = pcall(function() return weapon:isRanged() end)
    return ok and ranged == true
end
WTAGarou.IsRangedWeapon = isRangedWeapon

local function applyMeleeSurplus(attacker, victim, baseDamage, weapon)
    if not attacker or not victim then return end
    if not instanceof(attacker, "IsoPlayer") then return end
    -- 0.4.68: the form multiplier is MELEE power; a bullet is a bullet.
    if isRangedWeapon(weapon) then return end

    local md = attacker:getModData()
    local mult  = md.WTAGarou_MeleeMult or 1.0
    local flat  = md.WTAGarou_UnarmedBonus or 0.0
    local armed = attacker.getPrimaryHandItem and attacker:getPrimaryHandItem() ~= nil
    if not armed then
        baseDamage = (baseDamage or 1) + flat
    end

    local surplus = (baseDamage or 1) * (mult - 1.0)
    if surplus <= 0 then return end

    pcall(function()
        if victim.getHealth and victim.setHealth then
            victim:setHealth(victim:getHealth() - surplus)
        end
    end)
end

Events.OnHitZombie.Add(function(zombie, attacker, bodyPart, weapon)
    if not attacker then return end
    if instanceof(attacker, "IsoPlayer") then
        local dmg = (weapon and weapon.getDamage and weapon:getDamage()) or 1
        -- 0.4.70: flat cost per landed hit, whatever the damage.
        WTAGarou.AddRage(attacker, WTAGarou.Rage.ON_HIT_DEALT or 0)
        applyMeleeSurplus(attacker, zombie, dmg, weapon)
    end
end)

if Events.OnWeaponHitCharacter then
    Events.OnWeaponHitCharacter.Add(function(attacker, target, weapon, damage)
        if attacker and instanceof(attacker, "IsoPlayer") then
            WTAGarou.AddRage(attacker, WTAGarou.Rage.ON_HIT_DEALT or 0)
        end
        if target and instanceof(target, "IsoPlayer") then
            local reduc = target:getModData().WTAGarou_ArmorReduction or 0
            WTAGarou.AddRage(target, WTAGarou.Rage.ON_DAMAGE_TAKEN * (damage or 1) * (1 - reduc))
        end
    end)
end

-- Fallback zombie-melee damage detection via HP delta.
Events.OnPlayerUpdate.Add(function(player)
    if not player then return end
    -- Single player / hosted: the server sweep above does not run.
    if not isServer() and not isClient() then rageUpdate(player) end
    -- 0.4.75: a multiplayer client does not own its body; the server sweep
    -- (BodySweep) does all of this on the authoritative copy.
    if isClient() then return end
    local id = player:getOnlineID()
    local bd = player.getBodyDamage and player:getBodyDamage() or nil
    local hp = bd and bd:getOverallBodyHealth() or 100
    local prev = lastHealth[id]
    if prev and hp < prev then
        local taken = prev - hp
        local reduc = player:getModData().WTAGarou_ArmorReduction or 0
        WTAGarou.AddRage(player, WTAGarou.Rage.ON_DAMAGE_TAKEN * taken * (1 - reduc))
        if reduc > 0 and bd and bd.setOverallBodyHealth then
            local restored = taken * reduc
            pcall(function() bd:setOverallBodyHealth(hp + restored) end)
        end
    end
    lastHealth[id] = hp

    -- Regeneration ("healing factor"), per WTAGarou.Regeneration.
    WTAGarou.Regenerate(player, bd)
end)

-- ---------------------------------------------------------------------------
-- Regeneration.
--
-- Crinos: every body part heals 1.6 HP/s, and
-- each wound flag (bleeding, scratch, cut, deep wound, bite, wound infection,
-- burn, fracture) is cleared without treatment once THAT wound has existed
-- for CLEAR_WOUNDS_AFTER seconds in the form; zombie infection is burned off at
-- INFECTION_PER_SECOND. Hispo/Glabro run at about a third of that. Lupus
-- and Homid keep the vanilla clock. Silver-burned parts are skipped by this
-- boost, so they still heal, only at the normal vanilla body-part pace
-- (the mod grants no Fast Healer trait; the engine trait only shortens
-- wound timers at creation, so no counter-tuning is needed there).
-- Build 42 keeps the zombie virus in CharacterStat.ZOMBIE_INFECTION /
-- ZOMBIE_FEVER plus the BodyDamage.isInfected flag; Build 41 exposed
-- getInfectionLevel/setInfectionLevel. Every setter is pcall-guarded so a
-- missing method on one build never aborts the loop.
-- ---------------------------------------------------------------------------
-- Local split-screen actors may share the same offline online-ID sentinel.
-- Keep this healing-only clock on the character, not on that numeric ID.
local regenClock = setmetatable({}, {__mode="k"})
local function clearWound(bp)
    local function try(f) pcall(f) end
    -- Complete the ordinary wound, not merely its visible flag. Native
    -- bullet/stitch removal can CREATE fresh wound timers, so perform those
    -- operations BEFORE zeroing timers/flags below. Never restore the whole
    -- body or force WalkInjury=0, which would hide unrelated real injuries.
    try(function() if bp.haveGlass and bp:haveGlass() then bp:setHaveGlass(false) end end)
    try(function() if bp.haveBullet and bp:haveBullet() then bp:setHaveBullet(false, 0) end end)
    try(function()
        if bp.stitched and bp:stitched() then
            -- The wound is now regenerated. Use native mature-stitch removal,
            -- not its early-removal branch which reopens a deep wound.
            bp:setStitchTime(50)
            bp:setStitched(false)
        end
    end)
    try(function() if bp.getStitchTime and bp:getStitchTime() > 0 then bp:setStitchTime(0) end end)
    if bp.bleeding and bp:bleeding() then try(function() bp:setBleeding(false) end) end
    try(function() if bp:getBleedingTime() > 0 then bp:setBleedingTime(0) end end)
    if bp.scratched and bp:scratched() then try(function() bp:setScratched(false, true) end) end
    try(function() if bp:getScratchTime() > 0 then bp:setScratchTime(0) end end)
    if bp.isCut and bp:isCut() then try(function() bp:setCut(false, true) end) end
    try(function() if bp:getCutTime() > 0 then bp:setCutTime(0) end end)
    if bp.isDeepWounded and bp:isDeepWounded() then try(function() bp:setDeepWounded(false) end) end
    try(function() if bp:getDeepWoundTime() > 0 then bp:setDeepWoundTime(0) end end)
    if bp.bitten and bp:bitten() then try(function() bp:SetBitten(false) end) end
    try(function() if bp:getBiteTime() > 0 then bp:setBiteTime(0) end end)
    if bp.isInfectedWound and bp:isInfectedWound() then try(function() bp:setInfectedWound(false) end) end
    try(function() bp:setWoundInfectionLevel(0) end)
    if bp.IsInfected and bp:IsInfected() then try(function() bp:SetInfected(false) end) end
    try(function() if bp:getBurnTime() > 0 then bp:setBurnTime(0) end end)
    try(function() if bp:getFractureTime() > 0 then bp:setFractureTime(0) end end)
    try(function() bp:setAdditionalPain(0) end)
end
WTAGarou.ClearWound = clearWound

-- Does this body part carry any wound/infection flag the regeneration clears?
local function hasWound(bp)
    local found = false
    local function check(f)
        if found then return end
        local ok, v = pcall(f)
        if ok and v then found = true end
    end
    check(function() return bp.bleeding and bp:bleeding() end)
    check(function() return bp.scratched and bp:scratched() end)
    check(function() return bp.isCut and bp:isCut() end)
    check(function() return bp.isDeepWounded and bp:isDeepWounded() end)
    check(function() return bp.bitten and bp:bitten() end)
    check(function() return bp.isInfectedWound and bp:isInfectedWound() end)
    check(function() return bp.IsInfected and bp:IsInfected() end)
    check(function() return bp.getBurnTime and bp:getBurnTime() > 0 end)
    check(function() return bp.getFractureTime and bp:getFractureTime() > 0 end)
    -- Bandages can hide flags while timers remain. Older saves can also
    -- have full HP and no visible wound but retained glass/stitch penalties.
    check(function() return bp.haveGlass and bp:haveGlass() end)
    check(function() return bp.haveBullet and bp:haveBullet() end)
    check(function() return bp.stitched and bp:stitched() end)
    for _,getter in ipairs({"getScratchTime","getCutTime","getDeepWoundTime",
            "getBiteTime","getStitchTime","getWoundInfectionLevel"}) do
        check(function() return bp[getter] and bp[getter](bp) > 0 end)
    end
    return found
end
WTAGarou.HasWound = hasWound

-- Is the character carrying the Knox virus (real or "fake")? pcall-guarded
-- across the B41/B42 accessor names.
local function hasZombieInfection(player, bd)
    local found = false
    local function check(f)
        if found then return end
        local ok, v = pcall(f)
        if ok and v then found = true end
    end
    check(function() return bd.isInfected and bd:isInfected() end)
    check(function() return bd.IsInfected and bd:IsInfected() end)
    check(function() return bd.isIsFakeInfected and bd:isIsFakeInfected() end)
    check(function() return bd.IsFakeInfected and bd:IsFakeInfected() end)
    check(function() return bd.getInfectionLevel and (bd:getInfectionLevel() or 0) > 0 end)
    check(function()
        local stats = player.getStats and player:getStats() or nil
        if stats and CharacterStat and stats.get then
            for _, key in ipairs({ "ZOMBIE_INFECTION", "ZOMBIE_FEVER" }) do
                local stat = CharacterStat[key]
                if stat and (stats:get(stat) or 0) > 0 then return true end
            end
        end
        return false
    end)
    return found
end
WTAGarou.HasZombieInfection = hasZombieInfection

-- Remove every trace of the virus. B42 recomputes CharacterStat
-- ZOMBIE_INFECTION every tick from (worldAge - infectionTime) /
-- mortalityDuration while BodyDamage.isInfected is set, and sets isInfected
-- again from any body part that is still IsInfected(). So the flag, the
-- per-part flags, the timers AND the stats all have to go together.
local function clearZombieInfection(player, bd)
    local stats = player.getStats and player:getStats() or nil
    if stats and CharacterStat and stats.set then
        for _, key in ipairs({ "ZOMBIE_INFECTION", "ZOMBIE_FEVER" }) do
            local stat = CharacterStat[key]
            if stat then pcall(function() stats:set(stat, 0) end) end
        end
    end
    pcall(function()
        local parts = bd:getBodyParts()
        for i = 0, parts:size() - 1 do
            local bp = parts:get(i)
            pcall(function() if bp.SetInfected then bp:SetInfected(false) end end)
            pcall(function() if bp.SetFakeInfected then bp:SetFakeInfected(false) end end)
            pcall(function() if bp.DisableFakeInfection then bp:DisableFakeInfection() end end)
        end
    end)
    pcall(function() if bd.setInfectionLevel then bd:setInfectionLevel(0) end end)
    pcall(function() if bd.setInfected then bd:setInfected(false) end end)
    pcall(function() if bd.setIsFakeInfected then bd:setIsFakeInfected(false) end end)
    pcall(function() if bd.setReduceFakeInfection then bd:setReduceFakeInfection(false) end end)
    pcall(function() if bd.setInfectionTime then bd:setInfectionTime(-1) end end)
    pcall(function() if bd.setInfectionMortalityDuration then bd:setInfectionMortalityDuration(-1) end end)
end
WTAGarou.ClearZombieInfection = clearZombieInfection

-- 0.4.18: the client shows the Wyrm Infection purge progress in the health
-- panel, so every RageSync carries d.infectionBurn (nil when not infected).
local function cureZombieInfection(player, bd, amount)
    -- amount: infection points (0..100) to burn off this update; nil = all.
    -- 0.4.17: the burn-off is tracked in the Garou's own mod data
    -- (d.infectionBurn) because B42 overwrites the ZOMBIE_INFECTION stat every
    -- tick; decrementing the stat alone (0.4.11-0.4.16) never cured anyone,
    -- which left "At Breaking Point" stress (and 100 Rage) on an infected
    -- Garou for good. The stat is still lowered for the moodle read-out.
    local d = WTAGarou.GetData(player)
    if not hasZombieInfection(player, bd) then
        d.infectionBurn = nil
        return false
    end
    local stats = player.getStats and player:getStats() or nil
    if amount and stats and CharacterStat and stats.get then
        for _, key in ipairs({ "ZOMBIE_INFECTION", "ZOMBIE_FEVER" }) do
            local stat = CharacterStat[key]
            if stat then
                pcall(function()
                    local v = stats:get(stat) or 0
                    if v > 0 then stats:set(stat, math.max(0, v - amount)) end
                end)
            end
        end
    end
    if amount and bd.getInfectionLevel and bd.setInfectionLevel then
        pcall(function()
            local v = bd:getInfectionLevel() or 0
            if v > 0 then bd:setInfectionLevel(math.max(0, v - amount)) end
        end)
    end
    d.infectionBurn = (d.infectionBurn or 0) + (amount or 100)
    -- 300 ticks of 100/300 sum to 99.99999 in floating point: allow slack.
    if d.infectionBurn >= 100 - 1e-6 then
        clearZombieInfection(player, bd)
        d.infectionBurn = nil
        print("[WTAGarou][Regen] " .. tostring(d.form) .. " purged the Wyrm Infection")
        return true
    end
    return false
end
WTAGarou.CureZombieInfection = cureZombieInfection

function WTAGarou.Regenerate(player, bd)
    if not bd then return end
    local d = WTAGarou.GetData(player)
    local Rg = WTAGarou.Regeneration or {}
    local hpRate = (Rg.HEALTH_PER_SECOND or {})[d.form]
    local now = WTAGarou.NowSeconds()
    local clock = regenClock[player]
    if not clock or clock.form ~= d.form then
        clock = { form = d.form, since = now, last = now }
        regenClock[player] = clock
    end
    local dt = math.min(2.0, math.max(0, now - clock.last))
    clock.last = now
    -- dt == 0 on the priming call: no healing yet, but existing wounds are
    -- stamped now so their clear window starts when the form does.
    if not hpRate then return end

    local parts = bd:getBodyParts()
    if not parts then return end
    local burns = d.silverBurns or {}
    local nowMin = getGameTime():getWorldAgeHours() * 60
    -- Silver-burned parts (0.4.17): `true` while the part's vanilla burn time
    -- is above 0 (the burn heals at the vanilla pace; super healing resumes
    -- once it is gone). Legacy numeric entries are expiry game-minutes.
    local function silverBlocked(bp, key)
        local mark = burns[key]
        if mark == nil then return false end
        if type(mark) == "number" then return mark > nowMin end
        local ok, bt = pcall(function() return bp:getBurnTime() end)
        if ok and (bt or 0) > 0 then return true end
        burns[key] = nil   -- healed naturally: super healing re-enabled
        return false
    end
    local clearAfter = (Rg.CLEAR_WOUNDS_AFTER or {})[d.form]
    -- 0.4.18: bites are Wyrm work and close on the Wyrm Infection clock
    -- (CLEAR_BITES_AFTER: 5 min Crinos, 15 min Hispo/Glabro).
    local clearBitesAfter = (Rg.CLEAR_BITES_AFTER or {})[d.form] or clearAfter
    -- 0.4.11 cleared EVERY wound flag once the form had been held for
    -- CLEAR_WOUNDS_AFTER seconds, so after a minute in Crinos each new bite
    -- vanished the instant it landed. Wounds age individually (0.4.12) and
    -- cumulatively across regenerating forms (0.4.18).
    -- 0.4.18: wound progress is CUMULATIVE across regenerating forms and
    -- lives in mod data (d.woundProgress[part] = 0..1), like the Wyrm purge:
    -- each second in a form adds 1/window for that form (75 s Crinos = the
    -- whole scratch, 300 s Crinos = the whole bite; Hispo/Glabro a third of
    -- that). Homid/Lupus add nothing but keep the progress. Before 0.4.18
    -- the clock was a first-seen timestamp that reset on every form change.
    d.woundProgress = d.woundProgress or {}
    local progress = d.woundProgress
    local cleared = 0
    for i=0, parts:size()-1 do
        local bp = parts:get(i)
        local key = tostring(bp:getType())
        if not silverBlocked(bp, key) then
            if dt > 0 then
                pcall(function()
                    if bp:getHealth() < 100 then bp:AddHealth(hpRate * dt) end
                end)
                -- Bleeding is the killer; taper it continuously.
                pcall(function()
                    if bp:getBleedingTime() > 0 then
                        bp:setBleedingTime(math.max(0, bp:getBleedingTime() - hpRate * dt))
                    end
                end)
            end
            if clearAfter then
                if WTAGarou.HasWound(bp) then
                    local okBite, bitten = pcall(function() return bp:bitten() end)
                    local okBiteTime, biteTime = pcall(function() return bp:getBiteTime() end)
                    local isBite = (okBite and bitten) or (okBiteTime and (biteTime or 0)>0)
                    local window = isBite and clearBitesAfter or clearAfter
                    local prev = progress[key]
                    -- First sight only stamps the wound (progress 0); the
                    -- window counts from here, as the 0.4.12 timestamp did.
                    local prog = prev and (prev + (dt > 0 and window > 0 and (dt / window) or 0)) or 0
                    if prog >= 1 - 1e-6 then   -- float slack
                        clearWound(bp)
                        if WTAGarou.HasWound(bp) then
                            -- A missing/failed setter must not be reported as
                            -- complete or restart a whole healing window.
                            progress[key] = 1
                            clock.woundFailures = clock.woundFailures or {}
                            if not clock.woundFailures[key] then
                                clock.woundFailures[key] = true
                                print("[WTAGarou][Regen] incomplete wound cleanup on "..key
                                    .."; keeping injury active and retrying; no forced movement override")
                            end
                        else
                            progress[key] = nil
                            if clock.woundFailures then clock.woundFailures[key]=nil end
                            cleared = cleared + 1
                        end
                    else
                        progress[key] = prog
                    end
                else
                    progress[key] = nil
                end
            end
        end
    end
    if cleared > 0 then
        print("[WTAGarou][Regen] " .. d.form .. " closed " .. cleared .. " wound(s) (windows "
            .. tostring(clearAfter) .. "s / bites " .. tostring(clearBitesAfter) .. "s)")
    end
    local infRate = (Rg.INFECTION_PER_SECOND or {})[d.form]
    if infRate and dt > 0 then cureZombieInfection(player, bd, infRate * dt) end
end

-- ---------------------------------------------------------------------------
-- 0.4.68: Crinos door charge. The client's Java hook only reports that a
-- sprinting Berzerker ran into a closed door; the SERVER re-checks the door
-- (wooden, closed, not barricaded, in reach), spends Rage and stamina and
-- breaks it through the same path a zombie thump uses (setHealth(0) +
-- Thump(player, 1): Break sound, double doors, plank/hinge drop, removal
-- transmitted to every client). Nothing here needs the Java agent.
-- ---------------------------------------------------------------------------
local function findMapDoor(sq, north)
    if not sq or not sq.getObjects then return nil end
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local o = objs:get(i)
        if o and instanceof(o, "IsoDoor") and (o.getNorth == nil or (o:getNorth() == true) == north) then
            return o
        end
    end
    return nil
end
local function doorIsWooden(door)
    local ok, prefix = pcall(function() return door:getSoundPrefix() end)
    if not ok or prefix == nil then return true end -- IsoDoor defaults to WoodDoor
    return tostring(prefix):find("Wood") ~= nil
end
local function doorCharge(player, d, args)
    local C = WTAGarou.DoorCharge
    if not C or d.form ~= "Crinos" then return "not_crinos" end
    local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z)
    if not x or not y or not z then return "bad_args" end
    local north = args.north == true
    local cell = getCell and getCell() or nil
    local sq = cell and cell:getGridSquare(x, y, z) or nil
    local door = findMapDoor(sq, north)
    if not door then return "no_door" end
    if door:isDestroyed() or door:IsOpen() then return "not_closed" end
    if door.isBarricaded and door:isBarricaded() then return "barricaded" end
    if not doorIsWooden(door) then return "not_wood" end
    local dx, dy = (x + 0.5) - player:getX(), (y + 0.5) - player:getY()
    if math.floor(player:getZ() + 0.5) ~= z or (dx * dx + dy * dy) > (C.MAX_TILES * C.MAX_TILES) then
        return "too_far"
    end
    local locked = (door.isLocked and door:isLocked()) or (door.isLockedByKey and door:isLockedByKey()) or false
    local rage, stamina = WTAGarou.DoorChargeCost(locked)
    if (tonumber(d.rage) or 0) < rage then return "no_rage" end
    local ok, err = pcall(function()
        door:setHealth(0)
        door:Thump(player, 1)
    end)
    if not ok then
        print("[WTAGarou][DoorCharge] break failed: " .. tostring(err))
        return "error"
    end
    WTAGarou.AddRage(player, -rage)
    spendEndurance(player, stamina)
    print(string.format("[WTAGarou][DoorCharge] %s smashed a %swooden door at %d,%d,%d (-%d Rage, -%.3f endurance)",
        tostring(player:getUsername()), locked and "LOCKED " or "", x, y, z, rage, stamina))
    return nil, locked
end
WTAGarou.DoorChargeServer = { charge = doorCharge, findMapDoor = findMapDoor, isWooden = doorIsWooden }

-- ---------------------------------------------------------------------------
-- Client -> Server commands.
-- ---------------------------------------------------------------------------
local function handleClientCommand(module, command, player, args)
    if module ~= "WTAGarou" then return end
    args = args or {}
    local d = WTAGarou.GetData(player)

    -- Every Garou power is gated on the character trait.
    if command == "CrinosRoarRequest" then
        WTAGarou.CrinosBurst.onRoar(player)
        return
    end
    if command == "CrinosDoorCharge" then
        local reason, locked = doorCharge(player, d, args)
        sendTo(player, "DoorChargeResult", { reason = reason, locked = locked == true,
                                             x = args.x, y = args.y, z = args.z })
        return
    end
    if command == "TransformRequest" or command == "HowlRequest" then
        if not WTAGarou.HasGarouTrait(player) then
            sendTo(player, "TransformDenied", { reason = "not_a_garou" }); return
        end
    end

    -- --- Stage 1: validate and RESERVE. The form is not touched here. -------
    if command == "TransformRequest" then
        local target = tostring(args.form or "")
        if not WTAGarou.IsValidForm(target) then
            sendTo(player, "TransformDenied", { reason = "invalid_form" }); return
        end
        if d.form == target then
            sendTo(player, "TransformDenied", { reason = "already_in_form" }); return
        end
        local now = getTimestamp()
        if (now - (d.formChangedAt or 0)) < WTAGarou.TransformTime.COOLDOWN then
            sendTo(player, "TransformDenied", { reason = "cooldown" }); return
        end
        local cost = WTAGarou.GetForm(target).rageCost or 0
        -- 0.4.39: Crinos holds you while the Rage is high (75; 35 for the
        -- Berserker breed). Only the Rage engine's own 0-Rage return bypasses it.
        if WTAGarou.CrinosLocked and WTAGarou.CrinosLocked(d) then
            sendTo(player, "TransformDenied", { reason = "crinos_locked",
                lockAbove = WTAGarou.CrinosLockAbove(d) }); return
        end
        -- Crinos needs 55 Rage to START but only spends 10 (no floor for Berserkers).
        if d.rage < WTAGarou.RageRequired(target, d) then
            sendTo(player, "TransformDenied", { reason = "not_enough_rage" }); return
        end
        local seconds = WTAGarou.ComputeTransformSeconds(d.rage, target)
        -- Reservation only. Rage is NOT spent and the form is NOT changed until
        -- the client reports the channel finished, so a cancelled shift costs
        -- nothing and needs no refund path.
        d.pendingForm      = target
        d.pendingFrom      = d.form
        d.pendingCost      = cost
        d.pendingForced    = nil
        d.pendingExpiresAt = now + math.ceil(seconds) + 5   -- grace for lag
        sendTo(player, "TransformAccepted",
            { form = target, seconds = seconds, previousForm = d.form })
        return
    end

    -- --- Stage 2: the channel completed. Apply for real. --------------------
    if command == "TransformConfirm" then
        local target = tostring(args.form or "")
        if d.pendingForm ~= target then
            sendTo(player, "TransformDenied", { reason = "no_reservation" }); return
        end
        local now = getTimestamp()
        if now > (d.pendingExpiresAt or 0) then
            d.pendingForm = nil
            sendTo(player, "TransformDenied", { reason = "reservation_expired" }); return
        end
        if d.rage < (d.pendingCost or 0) then
            d.pendingForm = nil
            sendTo(player, "TransformDenied", { reason = "not_enough_rage" }); return
        end

        local previousForm = d.form
        local forced = d.pendingForced and true or false
        WTAGarou.AddRage(player, -(d.pendingCost or 0))
        d.form          = target
        d.formChangedAt = now
        d.isFrenzied    = forced
        d.crinosCountdownAt = nil
        d.pendingForm, d.pendingFrom, d.pendingCost, d.pendingExpiresAt, d.pendingForced = nil, nil, nil, nil, nil
        applyFormBuffs(player)

        sendTo(player, "TransformCompleted", { form = target, previousForm = previousForm, forced = forced,
            strip = serverStrip(player, target, forced) })
        sendTo(player, "RageSync", rageSyncArgs(d))
        completedShiftEffects(player,previousForm,target,forced)
        return
    end

    -- --- Stage 2b: the player interrupted the channel. ----------------------
    if command == "TransformCancel" then
        -- Nothing was ever spent or changed, so cancelling is just dropping the
        -- reservation. No rage refund, no form rollback.
        -- A forced Crinos reservation replaces a voluntary channel on the
        -- client; the old action's stop() reports a cancel for ITS form, which
        -- must not drop the new reservation.
        if args.form and d.pendingForm and args.form ~= d.pendingForm then
            return
        end
        if d.pendingForced then return end
        d.pendingForm, d.pendingFrom, d.pendingCost, d.pendingExpiresAt, d.pendingForced = nil, nil, nil, nil, nil
        sendTo(player, "RageSync", rageSyncArgs(d))
        return
    end

    if command == "ResistRequest" then
        if not WTAGarou.HasGarouTrait(player) then
            sendTo(player, "TransformDenied", { reason = "not_a_garou" }); return
        end
        resistCountdown(player, d, WTAGarou.NowSeconds and WTAGarou.NowSeconds() or os.time())
        return
    end

    if command == "HowlRequest" then
        -- Garou may howl in every form, including Homid. Trait validation was
        -- already performed at the top of this command handler.
        if d.howling then
            howlLog("request ignored: already howling owner=" ..
                tostring(ownerIDOf(player)))
            return
        end

        if player:isDead() then
            howlLog("request denied: dead owner=" .. tostring(ownerIDOf(player)))
            return
        end

        d.howling        = true
        d.lastHowlTickAt = 0
        d.howlTickCount  = 0

        howlLog("request accepted: owner=" .. tostring(ownerIDOf(player)) ..
            " form=" .. tostring(d.form) .. " rage=" .. tostring(d.rage))

        -- Starts the endless timed action on the requester only.
        sendTo(player, "HowlAccepted", {})

        -- Net.Broadcast reaches the local client in single player and all
        -- clients in multiplayer, so the howler is covered by this one event.
        -- Do NOT also send a separate per-player sound command, or the howler
        -- would hear two overlapping loops.
        broadcastHowlStarted(player, d)
        return
    end

    if command == "HowlTick" then
        if not d.howling then
            howlLog("tick ignored: no active howl owner=" ..
                tostring(ownerIDOf(player)))
            return
        end

        if player:isDead() then
            endHowl(player, d, "death")
            return
        end

        -- The client requests a tick only. It never supplies a Rage amount or
        -- target; server-side code owns the calculation and clamps it.
        local now = getTimestamp()
        local cooldown = (WTAGarou.Howl and WTAGarou.Howl.SERVER_TICK_COOLDOWN) or 0.40
        if (now - (d.lastHowlTickAt or 0)) < cooldown then return end
        d.lastHowlTickAt = now

        -- 0.4.45: a howl settles Rage on the character's baseline (auspice).
        local target = WTAGarou.BaselineRage(d)
        local amount = (WTAGarou.Howl and WTAGarou.Howl.RAGE_PER_TICK) or 1.0
        local delta = target - (d.rage or 0)

        -- Reaching 50 intentionally does NOT terminate the action. This keeps
        -- the howl available for role-play until the player cancels or runs.
        if math.abs(delta) > 0.001 then
            local pull = math.min(amount, math.abs(delta))
            WTAGarou.AddRage(player, delta > 0 and pull or -pull)
        end

        sendTo(player, "RageSync", rageSyncArgs(d))

        -- Two ticks per second would flood console.txt over a long role-play
        -- howl, so log the opening ticks and then one line every 10 ticks.
        d.howlTickCount = (d.howlTickCount or 0) + 1
        if d.howlTickCount <= 3 or (d.howlTickCount % 10) == 0 then
            howlLog("tick #" .. tostring(d.howlTickCount) ..
                " owner=" .. tostring(ownerIDOf(player)) ..
                " form=" .. tostring(d.form) ..
                " rage=" .. tostring(d.rage) ..
                " target=" .. tostring(target) ..
                " step=" .. tostring(amount))
        end
        return
    end

    if command == "HowlStop" then
        endHowl(player, d, args.reason or "client_stop")
        return
    end

    -- -----------------------------------------------------------------------
    -- Debug / testing commands. See media/lua/client/WTAGarouDebug.lua.
    -- In MP these are restricted to admins; in SP everything is allowed.
    -- -----------------------------------------------------------------------
    if string.sub(command, 1, 5) == "Debug" then
        -- 0.4.83: role capability, not "~= None" (every B42 player is "user").
        local allowed
        if WTAGarou.Access and WTAGarou.Access.privileged then
            allowed = WTAGarou.Access.privileged(player)
        else
            allowed = not isServer()
        end
        if not allowed then
            print("[WTAGarou][Debug] refused " .. tostring(command) .. " from an unprivileged player")
            return
        end

        -- 0.4.39: unlock the confirmed true form / coat so a tester can pick again.
        if command == "DebugResetIdentity" then
            d.identityLocked = nil
            d.auspiceLocked = nil
            d.auspice = nil
            print("[WTAGarou][Debug] identity lock cleared; coat/true form/baseline Rage may be confirmed again")
            sendTo(player, "RageSync", rageSyncArgs(d))
            return
        end

        if command == "DebugSetRage" then
            local v = tonumber(args.value) or 0
            if args.relative then
                WTAGarou.AddRage(player, v)
            else
                WTAGarou.SetRage(player, v)
            end
            sendTo(player, "RageSync", rageSyncArgs(d))
            return
        end

        if command == "DebugSetForm" then
            local target = tostring(args.form or "")
            if not WTAGarou.IsValidForm(target) then return end
            -- Straight to the destination: no channel, no cost, no cooldown.
            d.pendingForm, d.pendingFrom, d.pendingCost, d.pendingExpiresAt = nil, nil, nil, nil
            local previousForm = d.form
            d.form = target
            d.formChangedAt = getTimestamp() - WTAGarou.TransformTime.COOLDOWN
            d.isFrenzied = false
            applyFormBuffs(player)
            sendTo(player, "TransformCompleted", { form = target, previousForm = previousForm, forced = forced,
                strip = serverStrip(player, target, forced) })
            sendTo(player, "RageSync", rageSyncArgs(d))
            completedShiftEffects(player,previousForm,target)
            return
        end

        if command == "DebugSetInfamy" then
            d.infamy = math.max(0, tonumber(args.value) or 0)
            sendTo(player, "RageSync", rageSyncArgs(d))
            return
        end

        if command == "DebugTrait" then
            local removing = args.remove == true
            local trait = _G.WTAGarouTraits and _G.WTAGarouTraits.Garou or nil
            if trait and player.getCharacterTraits then
                pcall(function()
                    local traits = player:getCharacterTraits()
                    if removing then traits:remove(trait) else traits:add(trait) end
                    if player.modifyTraitXPBoost then
                        player:modifyTraitXPBoost(trait, removing)
                    end
                end)
            end
            -- Mirror into mod data so the fallback gate in HasGarouTrait agrees
            -- even if the registry object is unavailable.
            d.isGarou = not removing
            if removing then
                d.form = "Homid"
                applyFormBuffs(player)
            end
            sendTo(player, "RageSync", rageSyncArgs(d))
            return
        end
        return
    end

    if command == "WitnessTick" then
        if WTAGarou.Delirium and WTAGarou.Delirium.ENABLED == false then return end   -- 0.4.79 dormant
        local seen = args.witnesses or {}
        local now = getTimestamp()
        for id, entry in pairs(seen) do
            d.witnesses[id] = d.witnesses[id] or {
                seenAt = now, form = entry.form or d.form,
                isHunter = entry.isHunter or false, escapedAt = nil,
            }
            d.witnesses[id].lastSeenAt = now
        end
        for id, w in pairs(d.witnesses) do
            if (now - (w.lastSeenAt or w.seenAt)) >= WTAGarou.Delirium.ESCAPE_HIDE_SECONDS then
                local gain = w.isHunter and WTAGarou.Infamy.HUNTER_ESCAPE_GAIN
                                        or WTAGarou.Infamy.HUMAN_ESCAPE_GAIN
                WTAGarou.AddInfamy(player, gain)
                d.witnesses[id] = nil
            end
        end
        return
    end
end

-- ---------------------------------------------------------------------------
-- Register the handler on BOTH paths.
--
-- OnClientCommand only fires on a real server, so in single player it never
-- runs at all. WTAGarou.Net.ToServer calls the registered handler directly in
-- that case. Registering both keeps one implementation for both modes.
-- ---------------------------------------------------------------------------
WTAGarou.HandleClientCommand = handleClientCommand
Events.OnClientCommand.Add(handleClientCommand)
WTAGarou.Net.RegisterServerHandler(handleClientCommand)

print("[WTAGarou] Server command handler registered. singlePlayer=" ..
      tostring(WTAGarou.Net.IsSinglePlayer()))
