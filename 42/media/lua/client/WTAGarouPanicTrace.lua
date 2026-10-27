-- Opt-in, read-only diagnosis. Never hold a moodle level or write player stats.
-- Off by default; samples each client tick while active, logs level/form
-- transitions plus one heartbeat per second, and stops after <=120 seconds.
WTAGarou = WTAGarou or {}
WTAGarou.PanicTrace = WTAGarou.PanicTrace or {}
local Trace = WTAGarou.PanicTrace
local active

local function read(fn)
    local ok, value = pcall(fn)
    if ok then return value end
end

local function now()
    return read(function() return getTimestampMs() / 1000 end)
        or read(function() return getTimestamp() end)
end

local function stat(stats, name, legacy)
    local value = read(function()
        local kind = CharacterStat and CharacterStat[name]
        if kind ~= nil then return stats:get(kind) end
    end)
    if value == nil then
        value = read(function() return stats[legacy](stats) end)
    end
    return value
end

local function level(moodles, name, legacy)
    local value = read(function()
        local kind = MoodleType and MoodleType[name]
        if kind ~= nil then return moodles:getMoodleLevel(kind) end
    end)
    if value == nil then
        value = read(function()
            local kind = MoodleType and MoodleType[legacy]
            if kind ~= nil then return moodles:getMoodleLevel(kind) end
        end)
    end
    return value
end

function Trace.snapshot(player)
    local stats = read(function() return player:getStats() end)
    local moodles = read(function() return player:getMoodles() end)
    local md = read(function() return player:getModData() end) or {}
    local data = md.WTAGarou or {}
    return {
        form = data.form or "unknown",
        rage = data.rage,
        panic = stat(stats, "PANIC", "getPanic"),
        panicLevel = level(moodles, "PANIC", "Panic"),
        stress = stat(stats, "STRESS", "getStress"),
        stressLevel = level(moodles, "STRESS", "Stress"),
        panicIncrease = read(function() return player:getBodyDamage():getPanicIncreaseValue() end),
    }
end

local function emit(text)
    print("[WTAGarou][PanicTrace] " .. text)
end

function Trace.start(seconds)
    local duration = seconds == nil and 60 or tonumber(seconds)
    if not duration or duration ~= duration or duration < 0 or duration > 120 then
        return false, "panictrace: use 1-120 seconds, or 0 to stop"
    end
    if duration == 0 then
        active = nil
        emit("stopped")
        return true, "Panic trace stopped"
    end
    if duration < 1 then return false, "panictrace: use 1-120 seconds, or 0 to stop" end
    local player = getPlayer()
    local time = now()
    if not player or not time then return false, "Panic trace needs a loaded player and clock" end
    active = {player=player, started=time, deadline=time+duration, lines=0}
    emit("started seconds=" .. duration .. "; read-only; unavailable fields show nil")
    return true, "Panic trace running; reproduce the flicker, then send console.txt"
end

function Trace.update()
    if not active then return end
    local time = now()
    if not time or time < active.started or time >= active.deadline
            or getPlayer() ~= active.player or active.player:isDead() then
        active = nil
        emit("finished")
        return
    end
    local s = Trace.snapshot(active.player)
    local key = tostring(s.panicLevel) .. "/" .. tostring(s.stressLevel) .. "/" .. tostring(s.form)
    if key ~= active.key or not active.lastLog or time - active.lastLog >= 1 then
        emit(string.format(
            "t=%.3f form=%s rage=%s panic=%s panicLevel=%s stress=%s stressLevel=%s panicIncrease=%s",
            time-active.started, tostring(s.form), tostring(s.rage), tostring(s.panic),
            tostring(s.panicLevel), tostring(s.stress), tostring(s.stressLevel), tostring(s.panicIncrease)))
        active.key, active.lastLog = key, time
        active.lines = active.lines + 1
        -- A pathological every-frame flicker must not flood console.txt.
        if active.lines >= 600 then
            active = nil
            emit("finished at 600-line safety limit")
        end
    end
end

Events.OnTick.Add(Trace.update)
