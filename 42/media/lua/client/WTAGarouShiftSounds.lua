--[[
    WTAGarou - Shift sound cues (v0.4.19; 0.4.84 fades the channel bed and
    gives the channel a per-form voice, see WTAGarou.ShiftSounds)

    Three author-supplied one-shots, names in WTAGarou.ShiftSounds:
      CHANNEL_START   every time a shift channel starts (WTAGarouTransformAction:start)
      CRINOS_COMPLETE when the Crinos shift lands (TransformCompleted/TransformForced -> Crinos)
      COUNTDOWN       when the forced-Crinos countdown starts (CrinosCountdown)

    Each trigger plays its cue exactly once. Before playing, the previous
    handle of the SAME cue on this player is stopped (a new channel replaces
    the old one anyway), so quick re-triggers never stack. Completion cues
    are also de-duplicated: the same target form confirmed twice within
    DEDUPE_SECONDS plays once (the server may echo a confirm).

    0.4.19:
      - CHANNEL_START repeats while the channel runs: WTAGarouTransformAction
        :update() calls onChannelTick, which restarts the cue every
        WTAGarou.ShiftSounds.REPEAT_SECONDS (the clip length) until
        onChannelEnd (perform/stop/forceCancel). The last instance is left to
        finish; nothing is cut off and nothing overlaps.
      - FORCED_HOMID plays once when the server forces the 0-Rage return to
        Homid (TransformForced with form Homid).

    0.4.67:
      - The repeat comes sooner (REPEAT_SECONDS 1.8 < clip 2.95 s) and plays
        under its own cue slot ("repeat"), so it overlaps the first pass
        instead of cutting it.
      - CHANNEL_END plays once when the channel completes (perform), at
        CHANNEL_END_GAIN of the normal factor. Cancelled channels stay silent.
      - Multiplayer: every cue goes through emitter:playSound, the engine's
        networked path, so nearby clients hear it on the shifter's remote
        copy. Range is set per cue in wtagarou_sounds.txt (12 tiles for the
        quiet FormShift cues, 35 for the Crinos roar).
]]

WTAGarou = WTAGarou or {}
require "WTAGarouAudio"
WTAGarou.ShiftSoundsRuntime = WTAGarou.ShiftSoundsRuntime or {}
local SS = WTAGarou.ShiftSoundsRuntime

SS.DEDUPE_SECONDS = 1.0
SS.handles = SS.handles or {}     -- [playerKey][cue] = { handle = <long>, name = <sound> }
SS.lastCompleted = SS.lastCompleted or {}

local function now()
    if getTimestampMs then return getTimestampMs() / 1000 end
    if getTimestamp then return getTimestamp() end
    return os.time()
end

local function playerKey(player)
    local ok, id = pcall(function() return player:getOnlineID() end)
    if ok and id ~= nil then return tostring(id) end
    return tostring(player)
end

local function emitterOf(player)
    if not player or not player.getEmitter then return nil end
    local ok, em = pcall(function() return player:getEmitter() end)
    return ok and em or nil
end

-- Stop the previous instance of `cue` for this player, then play `name` once.
SS.PRIVATE_CUES = { countdown = true }   -- 0.4.75: heard by the owner only

function SS.play(player, cue, name, gain)
    if not player or not name then return nil end
    local key = playerKey(player)
    SS.handles[key] = SS.handles[key] or {}
    local prev = SS.handles[key][cue]
    local emitter = emitterOf(player)
    if prev and emitter then
        pcall(function()
            if prev.handle and emitter.stopSound then emitter:stopSound(prev.handle) end
            if emitter.stopSoundByName then emitter:stopSoundByName(prev.name) end
        end)
    end
    -- 0.4.40: scaled by the Sound Effects slider and capped (WTAGarou.Audio).
    local handle = WTAGarou.Audio.play(player, name, emitter, gain, SS.PRIVATE_CUES[cue] == true)
    if handle == nil then return nil end
    SS.handles[key][cue] = { handle = handle, name = name, gain = tonumber(gain) or 1 }
    return handle
end

SS.channelRepeat = SS.channelRepeat or {}   -- [playerKey] = time of the last bed start
SS.voice = SS.voice or {}                   -- [playerKey] = { kind, last, idx, suffix }

local function currentFormOf(player)
    local ok, d = pcall(function() return WTAGarou.GetData(player) end)
    return (ok and d and d.form) or "Homid"
end

-- 0.4.84: which voice a channel gets. Pure, so the tests can pin it.
function SS.voiceKind(targetForm, currentForm)
    if targetForm == "Crinos" or currentForm == "Crinos" then return "crinos" end
    if currentForm == "Lupus" or currentForm == "Hispo" then return "wolf" end
    return "human"
end

-- Play (or re-play) the channel voice for this player.
function SS.playVoice(player, key)
    local v = SS.voice[key]
    if not v then return nil end
    local names = WTAGarou.ShiftSounds or {}
    v.last = now()
    if v.kind == "crinos" then
        return SS.play(player, "voice", names.CRINOS_START)
    elseif v.kind == "wolf" then
        -- 0.4.86: the current form's own growl, quietly (the author's call)
        local byForm = (WTAGarou.SilverCue and WTAGarou.SilverCue.BY_FORM) or {}
        return SS.play(player, "voice", byForm[v.form] or byForm.Hispo, tonumber(names.WOLF_VOICE_GAIN) or 0.4)
    end
    -- human: the character's own vanilla pain voice (networked by the engine)
    local list = names.HUMAN_PAIN_SUFFIXES or { "PainFromScratch" }
    v.idx = (v.idx or 0) % #list + 1
    v.suffix = list[v.idx]
    local ok, handle = pcall(function()
        if player.transmitPlayerVoiceSound then return player:transmitPlayerVoiceSound(v.suffix) end
        if player.playerVoiceSound then return player:playerVoiceSound(v.suffix) end
        return nil
    end)
    return ok and handle or nil
end

-- `targetForm` (0.4.67 / 0.4.84): every channel opens the rustle bed; the
-- voice depends on the target and the current form (SS.voiceKind).
function SS.onChannelStart(player, targetForm)
    local names = WTAGarou.ShiftSounds or {}
    local key = playerKey(player)
    SS.channelRepeat[key] = now()
    local bed = SS.play(player, "start", names.CHANNEL_START)
    local current = currentFormOf(player)
    local kind = SS.voiceKind(tostring(targetForm), current)
    SS.voice[key] = { kind = kind, idx = 0, form = current }
    SS.playVoice(player, key)
    return bed
end

-- Called every update while a shift channel owns the timed action. Restarts
-- the bed once the previous instance has had its full clip length, and the
-- voice every VOICE_REPEAT_SECONDS (Crinos channels are 1 s, so their voice
-- never repeats in practice).
function SS.onChannelTick(player)
    local key = playerKey(player)
    local last = SS.channelRepeat[key]
    if not last then return nil end
    local names = WTAGarou.ShiftSounds or {}
    local t = now()
    local result = nil
    local v = SS.voice[key]
    if v and v.kind ~= "crinos" and (t - (v.last or 0)) >= (tonumber(names.VOICE_REPEAT_SECONDS) or 2.4) then
        result = SS.playVoice(player, key)
    end
    local period = tonumber(names.REPEAT_SECONDS) or 1.8
    if (t - last) >= period then
        SS.channelRepeat[key] = t
        -- 0.4.67: own cue slot, so the first pass keeps ringing underneath.
        result = SS.play(player, "repeat", names.CHANNEL_START)
    end
    return result
end

-- 0.4.84: the channel bed (CHANNEL_START instances in the "start" and
-- "repeat" slots) is faded over CHANNEL_FADE_SECONDS and then stopped, so a
-- channel that ends early does not leave a rustle ringing over the end cue.
-- setVolume is local-only and stopSound is the engine's networked stop, so
-- the shifter hears the fade and remote copies simply stop at its end.
SS.fades = SS.fades or {}

function SS.beginFade(player, emitter, entry, gain, seconds)
    if not entry or not entry.handle then return false end
    local names = WTAGarou.ShiftSounds or {}
    SS.fades[#SS.fades + 1] = { emitter = emitter, handle = entry.handle, name = entry.name,
                                t0 = now(), gain = tonumber(gain) or 1,
                                seconds = tonumber(seconds) or tonumber(names.CHANNEL_FADE_SECONDS) or 0.2 }
    return true
end

-- Advance every running fade; called from OnTick (and by tests). Returns the
-- number of fades still running.
function SS.update()
    if #SS.pendingEnd > 0 then SS.firePendingEnds(now()) end
    if #SS.fades == 0 then return 0 end
    local t = now()
    local factor = (WTAGarou.Audio and WTAGarou.Audio.factor and WTAGarou.Audio.factor()) or 1
    local i = 1
    while i <= #SS.fades do
        local f = SS.fades[i]
        local k = 1 - (t - f.t0) / (f.seconds or 0.2)
        if k <= 0 then
            pcall(function() if f.emitter and f.emitter.stopSound then f.emitter:stopSound(f.handle) end end)
            table.remove(SS.fades, i)
        else
            pcall(function() if f.emitter and f.emitter.setVolume then f.emitter:setVolume(f.handle, factor * f.gain * k) end end)
            i = i + 1
        end
    end
    return #SS.fades
end

-- The channel finished or was cancelled: stop repeating and fade the bed
-- out (0.4.84; before that the last instance rang out). `completed` is true
-- from perform() only; that is the one case that plays the end cue (0.4.67).
function SS.onChannelEnd(player, completed)
    local key = playerKey(player)
    SS.channelRepeat[key] = nil
    local names = WTAGarou.ShiftSounds or {}
    local slots = SS.handles[key]
    if slots then
        local emitter = emitterOf(player)
        -- 0.4.86: completion lets the bed and the voice ring 1 s under the
        -- whoosh; a cancel cuts them in 200 ms.
        local seconds = (completed == true) and (tonumber(names.CHANNEL_FADE_SECONDS) or 1.0)
                        or (tonumber(names.CANCEL_FADE_SECONDS) or 0.2)
        for _, slot in ipairs({ "start", "repeat", "voice" }) do
            local entry = slots[slot]
            if entry then
                SS.beginFade(player, emitter, entry, entry.gain or 1, seconds)
                slots[slot] = nil
            end
        end
    end
    -- a cancelled human channel also cuts the vanilla pain voice short
    local v = SS.voice[key]
    SS.voice[key] = nil
    if v and v.kind == "human" and v.suffix and completed ~= true then
        pcall(function() if player.stopPlayerVoiceSound then player:stopPlayerVoiceSound(v.suffix) end end)
    end
    if completed ~= true then return nil end
    if not names.CHANNEL_END then return nil end
    return SS.play(player, "end", names.CHANNEL_END, names.CHANNEL_END_GAIN or 0.6)
end

if Events and Events.OnTick then Events.OnTick.Add(SS.update) end

-- 0-Rage forced return to Homid: the bed and the completion whoosh start
-- together and the bed rings out over CHANNEL_FADE_SECONDS, exactly like a
-- channel that completed (0.4.92). FORCED_HOMID_SECONDS > 0 delays the
-- completion instead (0.4.91 behaviour); 0 is the default.
SS.pendingEnd = SS.pendingEnd or {}
function SS.onForcedHomid(player)
    local names = WTAGarou.ShiftSounds or {}
    local handle = SS.play(player, "start", names.FORCED_HOMID or names.CHANNEL_START)
    if handle ~= nil and names.CHANNEL_END then
        local delay = tonumber(names.FORCED_HOMID_SECONDS) or 0
        if delay > 0 then
            SS.pendingEnd[#SS.pendingEnd + 1] = { player = player, at = now() + delay }
        else
            pcall(SS.onChannelEnd, player, true)
        end
    end
    return handle
end

-- Fire the delayed forced-Homid completions that are due (called from update).
function SS.firePendingEnds(t)
    local i = 1
    while i <= #SS.pendingEnd do
        local p = SS.pendingEnd[i]
        if t >= p.at then
            table.remove(SS.pendingEnd, i)
            pcall(SS.onChannelEnd, p.player, true)
        else
            i = i + 1
        end
    end
end

-- args = { form=, previousForm=, forced= } from TransformCompleted/TransformForced.
function SS.onTransformCompleted(player, args)
    if not args or args.form ~= "Crinos" then return nil end
    local key = playerKey(player)
    local t = now()
    local last = SS.lastCompleted[key]
    if last and (t - last) < SS.DEDUPE_SECONDS then return nil end
    SS.lastCompleted[key] = t
    local names = WTAGarou.ShiftSounds or {}
    return SS.play(player, "crinos", names.CRINOS_COMPLETE)
end

function SS.onCountdown(player)
    local names = WTAGarou.ShiftSounds or {}
    return SS.play(player, "countdown", WTAGarou.CrinosCountdownSound or names.COUNTDOWN)
end
