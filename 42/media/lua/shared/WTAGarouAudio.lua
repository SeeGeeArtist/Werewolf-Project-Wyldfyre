--[[
    WTAGarou - mod sound volume (0.4.40)

    Why this exists: every WTAGarou cue is a plain OGG `file =` clip, not an
    FMOD bank event. The engine routes file clips to
    FMODManager.channelGroupInGameNonBankSounds and only ever pauses/mutes
    that group; the Sound Effects slider drives the bank VCA
    (vca:/Settings_Sfx) and never touches it. So the roar played at the same
    level however the game volume was set (October 5 playtest).

    Fix: scale each handle we start by the user's Sound Effects slider
    (MAX_VOLUME was a 75% cap until 0.4.88; the files are mastered now). Remote players' copies of a networked
    character.playSound still use the engine path; only our own cues are
    scaled here and in the Java StealthRuntime.
]]
WTAGarou = WTAGarou or {}
WTAGarou.Audio = WTAGarou.Audio or {}
local Audio = WTAGarou.Audio

Audio.MAX_VOLUME = 1.0   -- 0.4.88: no cap (was 0.75); the author masters the files

--- Sound Effects slider, 0..1 (1 when the sound manager is unavailable).
function Audio.sliderVolume()
    local v = 1
    pcall(function()
        local sm = getSoundManager and getSoundManager()
        if sm and sm.getSoundVolume then v = tonumber(sm:getSoundVolume()) or 1 end
    end)
    if v > 1 then v = 1 elseif v < 0 then v = 0 end
    return v
end

--- Playback factor applied to every mod cue.
function Audio.factor()
    return Audio.MAX_VOLUME * Audio.sliderVolume()
end

--- Apply the factor to a started handle. Safe on nil/0 handles.
--- 0.4.67: optional `gain` (0..1) multiplies the factor for quieter cues.
function Audio.scale(emitter, handle, gain)
    if not emitter or not handle then return false end
    local n = tonumber(handle)
    if not n or n == 0 then return false end
    local g = tonumber(gain) or 1
    if g > 1 then g = 1 elseif g < 0 then g = 0 end
    local ok = pcall(function() emitter:setVolume(handle, Audio.factor() * g) end)
    return ok
end

--- Start `name` on the character's emitter (or `emitter` when given) and
--- scale it. Returns the handle (or nil), and the emitter used.
--- `gain` (optional, 0..1) lowers this one cue below the normal factor.
--- Multiplayer: emitter:playSound / character:playSound is the engine's
--- networked path (remote clients receive a PlaySound packet and play the
--- same sound on their copy of the character via playSoundImpl), so the
--- cue's own distanceMax in wtagarou_sounds.txt is what limits its reach.
--- `private` (0.4.75): play on this machine only. CharacterSoundEmitter's
--- playSound sends a PlaySound packet so every nearby client hears it;
--- playSoundImpl is the local half remote copies run, with no packet. The
--- Crinos countdown is the Beast growling INSIDE the Garou's head, so only
--- its owner hears it; shifts themselves stay public.
function Audio.play(source, name, emitter, gain, private)
    if not source or not name or name == "" then return nil, nil end
    local handle
    pcall(function()
        if not emitter and source.getEmitter then emitter = source:getEmitter() end
    end)
    local ok = pcall(function()
        if private and emitter and emitter.playSoundImpl then
            handle = emitter:playSoundImpl(name, nil)
        elseif emitter and emitter.playSound then
            handle = emitter:playSound(name)
        elseif source.playSound then
            handle = source:playSound(name)
            if not emitter and source.getEmitter then emitter = source:getEmitter() end
        end
    end)
    if not ok then return nil, emitter end
    Audio.scale(emitter, handle, gain)
    return handle, emitter
end

return Audio
