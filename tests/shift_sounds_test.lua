-- 0.4.18: shift sound cues play exactly once per trigger and never pile up.
local root = assert(arg[1], "supply WTAGarou directory")
package.path = root .. "/42/media/lua/shared/?.lua;" .. package.path
require "WTAGarouDefinitions"
require "WTAGarouState"
local checks = 0
local function check(ok, message) checks = checks + 1; assert(ok, message) end

local clock = 1000
getTimestampMs = function() return clock * 1000 end
dofile(root .. "/42/media/lua/client/WTAGarouShiftSounds.lua")
local SS = WTAGarou.ShiftSoundsRuntime
check(SS and SS.play and SS.onChannelStart and SS.onTransformCompleted and SS.onCountdown, "runtime loaded")

local names = WTAGarou.ShiftSounds
check(names.CHANNEL_START == "WTAGarou_FormShift" and names.CRINOS_COMPLETE == "WTAGarou_CrinosShift"
    and names.COUNTDOWN == "WTAGarou_CrinosShiftTimer", "cue names")
check(WTAGarou.CrinosCountdownSound == "WTAGarou_CrinosShiftTimer", "countdown no longer uses the growl")

-- Sound bank: the three cues exist, point at the author's files, loop = false.
local bank = assert(io.open(root .. "/42/media/scripts/wtagarou_sounds.txt")):read("*a")
for cue, file in pairs({ WTAGarou_FormShift = "WTAGarou_formshift.ogg", WTAGarou_CrinosShift = "WTAGarou_Crinos_Shift.ogg",
                         WTAGarou_CrinosShiftTimer = "WTAGarou_Crinos_Shift-Timer.ogg" }) do
    local body = bank:match("sound " .. cue .. "%s*{(.-)}%s*}")
    check(body, "sound bank defines " .. cue)
    check(body:find("loop = false", 1, true) and body:find("media/sound/" .. file, 1, true), cue .. " is a one-shot on " .. file)
    local f = io.open(root .. "/common/media/sound/" .. file, "rb")
    check(f ~= nil, "author file present: " .. file)
    if f then f:close() end
end

local function newPlayer(id)
    local p = { id = id, played = {}, stopped = {}, stoppedNames = {}, nextHandle = 0 }
    function p:getOnlineID() return self.id end
    function p:getEmitter()
        local me = self
        return {
            playSound = function(_, name) me.nextHandle = me.nextHandle + 1; table.insert(me.played, name); return me.nextHandle end,
            playSoundImpl = function(_, name, proxy) me.nextHandle = me.nextHandle + 1; table.insert(me.played, name); me.privately = me.privately or {}; table.insert(me.privately, name); return me.nextHandle end,
            stopSound = function(_, h) table.insert(me.stopped, h) end,
            stopSoundByName = function(_, n) table.insert(me.stoppedNames, n) end,
        }
    end
    return p
end

local p = newPlayer(1)
check(SS.onChannelStart(p) == 1 and #p.played == 1 and p.played[1] == "WTAGarou_FormShift", "channel start plays the form-shift cue once")
check(#p.stopped == 0, "nothing to stop on the first play")
SS.onChannelStart(p)
check(#p.played == 2 and p.stopped[1] == 1 and p.stoppedNames[1] == "WTAGarou_FormShift", "a second channel stops the first cue before playing")

check(SS.onTransformCompleted(p, { form = "Glabro", previousForm = "Homid" }) == nil and #p.played == 2, "non-Crinos completion is silent")
check(SS.onTransformCompleted(p, { form = "Crinos", previousForm = "Homid" }) == 3 and p.played[3] == "WTAGarou_CrinosShift", "Crinos completion plays the Crinos shift cue")
check(SS.onTransformCompleted(p, { form = "Crinos", previousForm = "Homid" }) == nil and #p.played == 3, "an echoed confirm within a second is de-duplicated")
clock = clock + 2
check(SS.onTransformCompleted(p, { form = "Crinos", previousForm = "Homid", forced = true }) == 4, "a later (forced) Crinos arrival plays again")
check(p.stopped[2] == 3, "the previous Crinos cue was stopped first")
check(SS.onTransformCompleted(p, { form = "Homid", previousForm = "Crinos", forced = true }) == nil, "being forced back to Human is silent")

check(SS.onCountdown(p) == 5 and p.played[5] == "WTAGarou_CrinosShiftTimer", "countdown plays the timer cue")
check(p.privately and p.privately[1] == "WTAGarou_CrinosShiftTimer" and #p.privately == 1, "0.4.75: the countdown is the only cue played privately (playSoundImpl, no PlaySound packet); shifts stay public")
check(#p.played == 5, "no cue ever played twice for one trigger")
-- cues are independent per player
local q = newPlayer(2)
check(SS.onTransformCompleted(q, { form = "Crinos" }) == 1 and #q.stopped == 0, "another player has its own handles and dedupe")
-- a broken emitter never throws
local bad = { getOnlineID = function() return 3 end, getEmitter = function() error("no emitter") end }
check(SS.onChannelStart(bad) == nil, "emitter failure is swallowed")


-- 0.4.19: the channel cue repeats while the channel lasts.
-- 0.4.67: the repeat comes sooner (1.8 s) under its own cue slot so the first
-- pass rings on; a completed channel plays the quiet end cue, a cancelled one
-- does not.
check(names.REPEAT_SECONDS == 7.5 and names.CHANNEL_FADE_SECONDS == 1.0 and names.CANCEL_FADE_SECONDS == 0.2 and names.FORCED_HOMID == "WTAGarou_FormShift", "0.4.86: 8 s channel bed repeats only after 7.5 s; 1 s ring-out on completion, 200 ms on cancel; forced-Homid cue")
check(names.CHANNEL_END == "WTAGarou_FormShiftEnd" and names.CHANNEL_END_GAIN == 1.0, "0.4.67 end cue name; 0.4.88 gain 1.0 (no in-logic attenuation)")
local r = newPlayer(4)
clock = 5000
check(SS.onChannelStart(r) == 1 and #r.played == 1, "channel start plays once")
check(SS.onChannelTick(r) == nil and #r.played == 1, "a tick right after the start does not replay")
clock = clock + 6
check(SS.onChannelTick(r) == nil and #r.played == 1, "6 s in (the longest channel): still the first instance, no repeat needed")
clock = clock + 1.5
check(SS.onChannelTick(r) == 2 and r.played[2] == "WTAGarou_FormShift" and #r.stopped == 0, "7.5 s in: the bed plays again and the first pass is NOT stopped (overlap)")
check(SS.onChannelTick(r) == nil and #r.played == 2, "no replay until the next period")
clock = clock + 7.5
check(SS.onChannelTick(r) == 3 and r.stopped[1] == 2, "15 s in: third play replaces the second repeat slot only")
-- 0.4.84: ending the channel fades the bed (both slots) over 200 ms, then stops it
local rVolumes = {}
local rEmitter = r:getEmitter()
r.getEmitter = function() return rEmitter end
rEmitter.setVolume = function(_, h, v) rVolumes[h] = v end
SS.onChannelEnd(r, false)
check(#SS.fades == 2 and #r.stopped == 1, "cancelled end: both bed instances start fading, nothing stopped yet")
clock = clock + 0.1
check(SS.update() == 2 and math.abs(rVolumes[1] - WTAGarou.Audio.factor() * 0.5) < 1e-6 and math.abs(rVolumes[3] - WTAGarou.Audio.factor() * 0.5) < 1e-6, "100 ms in: both at half volume")
clock = clock + 0.1
check(SS.update() == 0 and #r.stopped == 3 and r.stopped[2] == 1 and r.stopped[3] == 3, "200 ms in: both instances stopped, fade list empty")
clock = clock + 5
check(SS.onChannelTick(r) == nil and #r.played == 3, "after a cancelled onChannelEnd the cue never restarts")
check(SS.onForcedHomid(r) == 4 and r.played[4] == "WTAGarou_FormShift", "forced 0-Rage Homid plays the form-shift cue")
check(SS.onChannelTick(r) == nil, "forced Homid does not arm the repeat")
check(names.FORCED_HOMID_SECONDS == 0 and #SS.pendingEnd == 0, "0.4.92: no delay on the forced revert")
check(#r.played == 5 and r.played[5] == "WTAGarou_FormShiftEnd" and #SS.fades >= 1, "forced revert: bed and whoosh start together, bed rings out like a completed channel")
clock = clock + 2
SS.update()
check(#SS.fades == 0, "forced-revert bed finished its ring-out")
-- the delayed variant still works when a server opts in
names.FORCED_HOMID_SECONDS = 1.2
check(SS.onForcedHomid(r) ~= nil and #SS.pendingEnd == 1, "FORCED_HOMID_SECONDS > 0 schedules the completion instead")
local before = #r.played
clock = clock + 1.3
SS.update()
check(#SS.pendingEnd == 0 and #r.played == before + 1 and r.played[#r.played] == "WTAGarou_FormShiftEnd", "delayed completion fires from update")
names.FORCED_HOMID_SECONDS = 0
clock = clock + 2
SS.update()
-- completed channel: end cue at lowered volume
local e = newPlayer(5)
local volumes = {}
local emitter = e:getEmitter()
e.getEmitter = function() return emitter end
emitter.setVolume = function(_, h, v) volumes[h] = v end
WTAGarou.Audio.MAX_VOLUME = 0.75
check(SS.onChannelStart(e) == 1, "completed-channel case starts")
check(SS.onChannelEnd(e, true) == 2 and e.played[2] == "WTAGarou_FormShiftEnd", "perform plays the end cue once")
check(math.abs(volumes[1] - 0.75) < 1e-6 and math.abs(volumes[2] - 0.75) < 1e-6, "0.4.88: end cue plays at the normal factor (no extra gain)")
check(#SS.fades == 1 and SS.fades[1].handle == 1, "0.4.84: the completed channel's bed fades under the end cue")
clock = clock + 0.5
check(SS.update() == 1 and volumes[1] < 0.75 * 0.55 and volumes[1] > 0.75 * 0.45, "0.4.86: halfway through the 1 s ring-out the bed is at half volume")
clock = clock + 0.55
check(SS.update() == 0 and e.stopped[#e.stopped] == 1, "bed stopped after the 1 s fade")
check(SS.onChannelEnd(e) == nil and #e.played == 2, "onChannelEnd without completed=true stays silent")
-- 0.4.67 / 0.4.84: a channel into Crinos opens the bed AND the Crinos start cue (its voice); no bed repeat in 1 s
check(names.CRINOS_START == "WTAGarou_CrinosShiftStart", "Crinos start cue name")
local c = newPlayer(6)
clock = 9000
check(SS.onChannelStart(c, "Crinos") == 1 and c.played[1] == "WTAGarou_FormShift" and c.played[2] == "WTAGarou_CrinosShiftStart",
    "0.4.84: Crinos channel opens the bed, then the Crinos voice")
clock = clock + 4
check(SS.onChannelTick(c) == nil and #c.played == 2, "Crinos channel never repeats its voice (1 s channel)")
check(SS.onChannelEnd(c, true) == 3 and c.played[3] == "WTAGarou_FormShiftEnd", "Crinos channel still gets the quiet end cue on perform")
check(#SS.fades == 2, "both the bed and the Crinos voice fade under the end cue")
SS.fades = {}
local g = newPlayer(7)
check(SS.onChannelStart(g, "Glabro") == 1 and g.played[1] == "WTAGarou_FormShift", "non-Crinos channel keeps the form-shift cue")
clock = clock + 8
check(SS.onChannelTick(g) == 2, "non-Crinos channel repeats once the 8 s bed is nearly spent")
-- 0.4.84: the channel voice follows the current form
check(SS.voiceKind("Crinos", "Homid") == "crinos" and SS.voiceKind("Crinos", "Lupus") == "crinos", "Crinos target -> Crinos voice regardless of current form")
check(SS.voiceKind("Homid", "Crinos") == "crinos", "leaving Crinos -> Crinos voice")
check(SS.voiceKind("Glabro", "Lupus") == "wolf" and SS.voiceKind("Homid", "Hispo") == "wolf", "Lupus/Hispo -> wolf voice")
check(SS.voiceKind("Glabro", "Homid") == "human" and SS.voiceKind("Lupus", "Glabro") == "human", "Homid/Glabro -> vanilla pain voice")
check(names.WOLF_START == nil and names.WOLF_VOICE_GAIN == 0.4 and #names.HUMAN_PAIN_SUFFIXES >= 3 and names.VOICE_REPEAT_SECONDS == 2.4, "voice names and repeat (0.4.86: wolf voice = form growl at 0.4)")
for _, suffix in ipairs(names.HUMAN_PAIN_SUFFIXES) do
    check(suffix ~= "PainFromScratch" and suffix ~= "PainFromLacerate" and suffix ~= "PainFromBite" and suffix ~= "PainFromFallHigh" and suffix ~= "PainFromGlassCut",
        "human channel voice is a discomfort/strain voice, not a wound scream: " .. suffix)
end
-- human voice: the vanilla pain voice is transmitted, cycles suffixes, repeats every 2.4 s, and is cut on cancel
local h = newPlayer(8)
h.voiced, h.voiceStopped = {}, {}
function h:transmitPlayerVoiceSound(suffix) table.insert(self.voiced, suffix); return 100 + #self.voiced end
function h:stopPlayerVoiceSound(suffix) table.insert(self.voiceStopped, suffix); return 1 end
clock = 10000
check(SS.onChannelStart(h, "Glabro") == 1 and #h.played == 1 and h.voiced[1] == "PainMoodle", "human channel: bed + first (subtle) pain voice")
clock = clock + 1
check(SS.onChannelTick(h) == nil and #h.voiced == 1, "no voice repeat before 2.4 s")
clock = clock + 1.5
check(SS.onChannelTick(h) == 102 and h.voiced[2] == "CorpseHighEffort", "voice repeats after 2.4 s with the next suffix")
check(SS.onChannelEnd(h) == nil and h.voiceStopped[1] == "CorpseHighEffort", "a cancelled human channel stops the current pain voice")
check(SS.onChannelTick(h) == nil and #h.voiced == 2, "no voice after the channel ends")
-- wolf voice: own cue in the voice slot, repeats, fades on cancel
local w = newPlayer(9)
w.getModData = nil
local realGetData = WTAGarou.GetData
WTAGarou.GetData = function(player) if player == w then return { form = "Hispo" } end return realGetData(player) end
clock = 11000
check(SS.onChannelStart(w, "Glabro") == 1 and w.played[1] == "WTAGarou_FormShift" and w.played[2] == "WTAGarou_HispoGrowl", "Hispo channel: bed + the Hispo growl as the voice")
clock = clock + 2.5
check(SS.onChannelTick(w) == 3 and w.played[3] == "WTAGarou_HispoGrowl" and w.stopped[#w.stopped] == 2, "wolf voice repeats (previous instance stopped)")
SS.fades = {}
check(SS.onChannelEnd(w) == nil and #SS.fades == 2, "cancel fades the bed and the wolf voice")
WTAGarou.GetData = realGetData
SS.fades = {}
local function clipVolume(cue)
    local body = bank:match("sound " .. cue .. "%s*{(.-)}%s*}")
    return body and tonumber(body:match("volume = ([%d%.]+)"))
end
check(clipVolume("WTAGarou_CrinosShiftStart") == 1.0 and clipVolume("WTAGarou_CrinosShift") == 1.0 and clipVolume("WTAGarou_FormShift") == 1.0, "0.4.88: own clips play at 1.0 in the bank; the files carry their own level")
check(clipVolume("WTAGarou_FormShiftEnd") == 1.0 and clipVolume("WTAGarou_CrinosStep") == 0.45, "0.4.88: end cue at 1.0; only the Crinos footsteps sit lower (0.45)")
local stepBody = bank:match("sound WTAGarou_CrinosStep%s*{(.-)}%s*}%s*/%*")
local stepVols = {}
for v in (stepBody or ""):gmatch("volume = ([%d%.]+)") do stepVols[#stepVols + 1] = tonumber(v) end
check(#stepVols == 2 and stepVols[1] <= 0.55 and stepVols[2] <= 0.55, "0.4.70: Crinos footstep clips at or under 0.55 (was 0.80)")
local pitched = false
for v in (stepBody or ""):gmatch("pitch = ([%d%.]+)") do if tonumber(v) ~= 1 then pitched = true end end
check(not pitched and not (stepBody or ""):find("lowpass") and not (stepBody or ""):find("reverb"), "footstep clips: pitch 1.00, no EQ/effects -- played as authored")
-- bank entries for the new cues
for cue, file in pairs({ WTAGarou_FormShiftEnd = "WTAGarou_formshift_02.ogg", WTAGarou_CrinosStep = "WTAGarou_Crinos_Fstep_01.ogg",
                         WTAGarou_CrinosShiftStart = "WTAGarou_Crinos_Shift-Start.ogg",
                         WTAGarou_WolfBark = "Wolf_Mod_Bark_01.ogg" }) do
    local body = bank:match("sound " .. cue .. "%s*{(.-)}%s*}")
    check(body and body:find("loop = false", 1, true) and body:find("media/sound/" .. file, 1, true), cue .. " one-shot on " .. file)
end
local roar = bank:match("sound WTAGarou_CrinosRoar%s*{(.-)}%s*}%s*/%*")
check(roar and select(2, roar:gsub("clip%s*{", "")) == 3, "Crinos roar has three random clips (0.4.87)")
for _, file in ipairs({ "WTAGarou_Crinos_Roar_Bark.ogg", "WTAGarou_Crinos_Roar_Bark_02.ogg", "WTAGarou_Crinos_Roar_Bark_03.ogg",
                        "WTAGarou_Crinos_Shift-Start.ogg", "WTAGarou_Crinos_Shift.ogg",
                        "WTAGarou_Crinos_Fstep_02.ogg", "WTAGarou_formshift_02.ogg",
                        "WTAGarou_Hispo_Bark_02.ogg", "WTAGarou_Hispo_Bark_03.ogg" }) do
    local f = io.open(root .. "/common/media/sound/" .. file, "rb")
    check(f ~= nil, "renamed/author file present: " .. file)
    if f then f:close() end
end
local parenthesised = false
for file in bank:gmatch("file = ([^,\n]+)") do
    if file:find("[%(%) ]") then parenthesised = true end
end
check(not parenthesised, "no parenthesised or space-containing clip file names")
-- quiet cues keep a short range; the Crinos roar keeps its long one
local function maxRange(cue)
    local body = bank:match("sound " .. cue .. "%s*{(.-)}%s*}")
    return body and tonumber(body:match("distanceMax = (%d+)"))
end
check(maxRange("WTAGarou_FormShift") == 12 and maxRange("WTAGarou_FormShiftEnd") == 12, "non-Crinos shift cues are short range")
check(maxRange("WTAGarou_CrinosShift") == 35, "Crinos completion roar keeps its range")
-- WTAGarouTransformAction wires the tick/end hooks
local channel = io.open(root .. "/42/media/lua/client/WTAGarouChannel.lua"):read("*a")
check(channel:find("onChannelStart, self.character, tostring(self.targetForm)", 1, true), "TransformAction passes the target form to the start cue")
check(channel:find("ShiftSoundsRuntime.onChannelTick", 1, true) and select(2, channel:gsub("endShiftCue%(self%.character%)", "")) >= 2
    and channel:find("endShiftCue(self.character, true)", 1, true),
    "TransformAction update ticks the cue, stop/forceCancel end it silently and perform ends it with the end cue")
local clientSrc = io.open(root .. "/42/media/lua/client/WTAGarouClient.lua"):read("*a")
check(clientSrc:find('args.form == "Homid" and WTAGarou.ShiftSoundsRuntime', 1, true) and clientSrc:find("onForcedHomid", 1, true),
    "TransformForced(Homid) handler plays the forced-Homid cue")

print("PASS: " .. checks .. " shift-sound assertions.")
