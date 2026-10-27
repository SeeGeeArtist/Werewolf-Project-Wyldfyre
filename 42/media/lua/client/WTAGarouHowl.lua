--[[
    WTAGarou - Ongoing howl audio and feedback

    This module owns client-side howl sound instances. The server broadcasts
    HowlStarted and HowlStopped once per howl; each client attaches the loop to
    the matching player emitter so it follows that character in 3D space.

    Search console.txt for: [WTAGarou][Howl]
]]

WTAGarou = WTAGarou or {}
require "WTAGarouAudio"
WTAGarou.Howl = WTAGarou.Howl or {}

local Howl = WTAGarou.Howl
Howl.activeSounds = Howl.activeSounds or {} -- [ownerOnlineID] = entry

local SOUND_NAME = "WTAGarou_Howl"

-- Approximate shout/voice radius. The actual sound engine clamps effective
-- range near 90 tiles regardless of sandbox FollowSoundDistance, but the base
-- radius is still fed into WorldSoundManager; matching shout keeps howl and
-- Q-voice on the same footing.[web:460][web:357]
local HOWL_RADIUS_TILES = 40

-- Watchdog: how often to verify the loop is still audible, and how long to wait
-- after a (re)start before believing isPlaying() -- FMOD queues events through
-- hasSoundsToStart, so a fresh handle can read as not-playing for a moment.[web:424]
local WATCHDOG_TICKS = 30
local RESTART_GRACE_MS = 1500
local MAX_RESTARTS = 240

local function log(message)
    print("[WTAGarou][Howl] " .. tostring(message))
end

local function nowMS()
    local ok, ms = pcall(function() return getTimestampMs() end)
    if ok and ms then return ms end
    return (getTimestamp() or 0) * 1000
end

local function emitterOf(character)
    if not character then return nil end
    local emitter = nil
    pcall(function() emitter = character:getEmitter() end)
    return emitter
end

-- ---------------------------------------------------------------------------
-- Sound playback
--
-- IsoGameCharacter:getEmitter() returns a BaseCharacterSoundEmitter, NOT a
-- BaseSoundEmitter. That class exposes only:
--   playSound(String), playSound(String, IsoObject), playVocals(String),
--   stopSound(long), stopSoundByName(String), stopOrTriggerSound(long),
--   stopAll(), isPlaying(long), isPlaying(String), setVolume, setPitch, set(x,y,z).
-- It has NO playSoundLooped and NO set3D/setPos -- calling playSoundLooped is
-- exactly the "Object tried to call nil" error in console.txt.[cite:446]
-- The character emitter is already attached to the character, so it is
-- positional by design; looping comes from `loop = true` in
-- scripts/wtagarou_sounds.txt.[web:374]
--
-- If the sound script is not looping (or a clip ends early), the watchdog below
-- retriggers it, so a plain non-looping OGG still sustains for the whole howl.
-- ---------------------------------------------------------------------------
local function triggerSound(character)
    local emitter = emitterOf(character)

    if emitter then
        local handle = nil
        local ok, err = pcall(function() handle = emitter:playSound(SOUND_NAME) end)
        if ok and handle and tonumber(handle) and tonumber(handle) ~= 0 then
            if WTAGarou.Audio then WTAGarou.Audio.scale(emitter, handle) end
            return handle, "emitter:playSound", nil
        end
        if not ok then
            log("emitter:playSound errored err=" .. tostring(err))
        end
    end

    -- Fallback: IsoGameCharacter:playSound(String) exists in its own right.
    local handle = nil
    local ok, err = pcall(function() handle = character:playSound(SOUND_NAME) end)
    if ok and handle and tonumber(handle) and tonumber(handle) ~= 0 then
        if WTAGarou.Audio then pcall(function() WTAGarou.Audio.scale(character:getEmitter(), handle) end) end
        return handle, "character:playSound", nil
    end

    return nil, nil, "emitter=" .. tostring(emitter ~= nil) ..
        " charPlayOK=" .. tostring(ok) .. " handle=" .. tostring(handle) ..
        " err=" .. tostring(err)
end

local function ownerKey(ownerID)
    return tostring(ownerID or "")
end

local function findPlayerByOnlineID(ownerID)
    local wanted = tonumber(ownerID)
    local localPlayer = getPlayer()

    if localPlayer and localPlayer.getOnlineID then
        local ok, id = pcall(function() return localPlayer:getOnlineID() end)
        if ok and tonumber(id) == wanted then
            return localPlayer
        end
    end

    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players then
        for i = 0, players:size() - 1 do
            local player = players:get(i)
            if player and player.getOnlineID then
                local ok, id = pcall(function() return player:getOnlineID() end)
                if ok and tonumber(id) == wanted then
                    return player
                end
            end
        end
    end

    return nil
end

local function stopEntry(key, reason)
    local entry = Howl.activeSounds[key]
    if not entry then
        log("sound stop ignored: no active entry owner=" .. key .. " reason=" .. tostring(reason))
        return false
    end

    local emitter = emitterOf(entry.character)

    if emitter then
        -- isPlaying is only logged, never used as a gate. If it ever reported a
        -- false negative the loop would play forever, so always stop it, both by
        -- handle and by name.
        local checkOK, playing = pcall(function()
            return entry.handle and emitter:isPlaying(entry.handle) or false
        end)

        local stopOK, stopErr = pcall(function()
            if entry.handle then emitter:stopSound(entry.handle) end
        end)
        local nameOK, nameErr = pcall(function()
            emitter:stopSoundByName(SOUND_NAME)
        end)

        log("sound stop: owner=" .. key .. " handle=" .. tostring(entry.handle) ..
            " wasPlaying=" .. tostring(checkOK and playing or "unknown") ..
            " byHandle=" .. tostring(stopOK) .. "/" .. tostring(stopErr) ..
            " byName=" .. tostring(nameOK) .. "/" .. tostring(nameErr) ..
            " restarts=" .. tostring(entry.restarts or 0) ..
            " reason=" .. tostring(reason))
    else
        log("sound stop: emitter unavailable owner=" .. key ..
            " reason=" .. tostring(reason))
    end

    Howl.activeSounds[key] = nil
    return true
end

--- Start a looping, positional howl attached to the matching player character.
--- Called from the HowlStarted server broadcast on every client.
function Howl.startSound(args)
    args = args or {}
    local key = ownerKey(args.ownerID)
    if key == "" then
        log("sound start rejected: missing ownerID")
        return false
    end

    -- A duplicate start should replace the old handle rather than stacking loops.
    if Howl.activeSounds[key] then
        stopEntry(key, "duplicate_start")
    end

    local character = findPlayerByOnlineID(args.ownerID)
    if not character then
        log("sound start deferred/failed: owner not found owner=" .. key ..
            " form=" .. tostring(args.form))
        return false
    end

    local handle, via, failure = triggerSound(character)

    -- Track the howl even when the audio asset is missing, so the watchdog can
    -- retry and so HowlStopped still has an entry to clean up. Gameplay (Rage,
    -- wolf attraction, HUD) must never depend on the sound succeeding.
    Howl.activeSounds[key] = {
        character = character,
        handle = handle,
        via = via,
        startedMS = nowMS(),
        lastTriggerMS = nowMS(),
        restarts = 0,
        soundMissing = (handle == nil),
    }

    if handle then
        log("sound start: owner=" .. key .. " form=" .. tostring(args.form) ..
            " handle=" .. tostring(handle) .. " via=" .. tostring(via))
        return true
    end

    log("sound start failed: owner=" .. key .. " form=" .. tostring(args.form) ..
        " event=" .. SOUND_NAME .. " " .. tostring(failure) ..
        " (is media/sound/" .. SOUND_NAME .. ".ogg installed?)")
    return false
end

--- Stop the loop belonging to a player. Called from HowlStopped.
function Howl.stopSound(args)
    args = args or {}
    local key = ownerKey(args.ownerID)
    if key == "" then
        log("sound stop rejected: missing ownerID")
        return false
    end
    return stopEntry(key, args.reason or "server_stop")
end

--- Stop every locally tracked howl loop. Safe for player death and disconnects.
function Howl.stopAllSounds(reason)
    local keys = {}
    for key, _ in pairs(Howl.activeSounds) do
        table.insert(keys, key)
    end
    for _, key in ipairs(keys) do
        stopEntry(key, reason or "stop_all")
    end
end

local function isWolf(animal)
    if not animal or not animal.getAnimalType then return false end
    local t = tostring(animal:getAnimalType() or ""):lower()
    return t:find("wolf") ~= nil
end

--- One cosmetic/gameplay response at howl start. Do not call this for every
--- Rage tick: it would repeatedly re-path animals.
function Howl.attractWolves(args)
    if not args or args.form ~= "Lupus" then return end

    local cell = getCell()
    if not cell or not cell.getStaticMovingObjects then
        log("wolf attraction skipped: no cell/static moving objects")
        return
    end

    local list = cell:getStaticMovingObjects()
    local attracted = 0
    for i = 0, list:size() - 1 do
        local obj = list:get(i)
        if isWolf(obj) and obj.pathToLocation then
            local ok = pcall(function()
                obj:pathToLocation(args.x, args.y, args.z)
            end)
            if ok then attracted = attracted + 1 end
        end
    end

    log("wolf attraction: owner=" .. tostring(args.ownerID) ..
        " count=" .. tostring(attracted))
end

function Howl.onStarted(args)
    Howl.startSound(args)
    Howl.attractWolves(args)

    -- Explicit world sound so zombies treat howl like Q-shouting. addSound()
    -- is the Lua wrapper around WorldSoundManager.addSound; radius is in tiles
    -- and volume is a small integer.[web:357][web:472]
    local character = findPlayerByOnlineID(args.ownerID)
    local radius = (WTAGarou.Howl and WTAGarou.Howl.RADIUS_TILES) or HOWL_RADIUS_TILES
    if character and addSound then
        local ok, err = pcall(function()
            addSound(character,
                     character:getX(), character:getY(), character:getZ(),
                     radius, 2)
        end)
        if ok then
            log("world sound: howl radius=" .. tostring(radius) ..
                " owner=" .. ownerKey(args.ownerID))
        else
            log("world sound failed: owner=" .. ownerKey(args.ownerID) ..
                " err=" .. tostring(err))
        end
    else
        log("world sound skipped: no character or addSound()")
    end
end

function Howl.onStopped(args)
    Howl.stopSound(args)
end

-- ---------------------------------------------------------------------------
-- Watchdog
--
-- Runs on OnTick. Two jobs:
--   1. Drop loops whose owner died or went invalid (Build 42 has no
--      Events.OnPlayerDeath, so this replaces it).[cite:475]
--   2. Retrigger the event if it stopped early -- covers a non-looping OGG or a
--      clip that FMOD let finish.
-- ---------------------------------------------------------------------------
local watchdogCounter = 0

local function watchdogEntry(key, entry)
    local character = entry.character
    if not character then
        stopEntry(key, "watchdog_no_character")
        return
    end

    local dead = false
    local ok = pcall(function() dead = character:isDead() end)
    if not ok or dead then
        stopEntry(key, "watchdog_owner_dead")
        return
    end

    if entry.soundMissing then return end

    local since = nowMS() - (entry.lastTriggerMS or 0)
    if since < RESTART_GRACE_MS then return end

    local emitter = emitterOf(character)
    if not emitter then return end

    local playing = false
    local checkOK = pcall(function()
        playing = (entry.handle and emitter:isPlaying(entry.handle)) or
                  emitter:isPlaying(SOUND_NAME)
    end)
    if not checkOK or playing then return end

    if (entry.restarts or 0) >= MAX_RESTARTS then
        entry.soundMissing = true
        log("watchdog: restart cap reached owner=" .. key .. " -- giving up on audio")
        return
    end

    local handle, via = triggerSound(character)
    entry.lastTriggerMS = nowMS()
    entry.restarts = (entry.restarts or 0) + 1

    if handle then
        entry.handle = handle
        entry.via = via
        -- Only log the first few restarts, then every tenth, to keep the log
        -- readable during a long howl.
        if entry.restarts <= 3 or entry.restarts % 10 == 0 then
            log("watchdog retrigger #" .. entry.restarts .. " owner=" .. key ..
                " handle=" .. tostring(handle) .. " via=" .. tostring(via))
        end
    else
        entry.soundMissing = true
        log("watchdog retrigger failed owner=" .. key ..
            " -- audio disabled for this howl (gameplay unaffected)")
    end
end

--- Build 42's Kahlua does NOT expose the standard Lua `next` global. Calling
--- it threw "Object tried to call nil" on EVERY tick that a howl was active,
--- which is the error counter you watched climb.[cite:475]
--- pairs() is available, so the emptiness test is done with it instead.
local function hasActiveSounds()
    for _ in pairs(Howl.activeSounds) do return true end
    return false
end

local function onWatchdogTick()
    if not hasActiveSounds() then return end

    watchdogCounter = watchdogCounter + 1
    if watchdogCounter < WATCHDOG_TICKS then return end
    watchdogCounter = 0

    local keys = {}
    for key, _ in pairs(Howl.activeSounds) do table.insert(keys, key) end
    for _, key in ipairs(keys) do
        local entry = Howl.activeSounds[key]
        if entry then watchdogEntry(key, entry) end
    end
end

-- Event registration is guarded: Events.OnPlayerDeath does NOT exist in Build
-- 42, and the unguarded .Add() call aborted this whole file at load time ("Add
-- of non-table: null"), which also silently skipped everything below it.[cite:475]
local function addEvent(name, callback)
    local event = Events[name]
    if event and event.Add then
        event.Add(callback)
        log("registered event " .. name)
    else
        log("event unavailable in this build, skipped: " .. name)
    end
end

addEvent("OnTick", onWatchdogTick)

addEvent("OnPlayerDeath", function(player)
    if not player or not player.getOnlineID then return end
    local id = nil
    pcall(function() id = player:getOnlineID() end)
    Howl.stopSound({ ownerID = id, reason = "player_death" })
end)

addEvent("OnCharacterDeath", function(character)
    if not character or not character.getOnlineID then return end
    -- 0.4.17: zombies and animals die here too (onlineID -1) and every one
    -- logged "sound stop ignored". Only players can own a howl.
    if instanceof and not instanceof(character, "IsoPlayer") then return end
    local id = nil
    pcall(function() id = character:getOnlineID() end)
    if id then
        Howl.stopSound({ ownerID = id, reason = "character_death" })
    end
end)

addEvent("OnGameExit", function()
    Howl.stopAllSounds("game_exit")
end)
