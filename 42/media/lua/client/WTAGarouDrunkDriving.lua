--[[
    WTAGarou - Drunken driving (v0.2.2, rebuilt for Build 42 in 0.4.43)

    A quadruped Garou can try to drive, but poorly: while a drunkDriving form
    (Lupus; Hispo too, though bulk forms cannot get into a seat since 0.4.39)
    is the DRIVER, the character's intoxication is held at a fixed level and
    the vanilla car controller does the rest.

    Why it never worked before: the 0.2.2 code called Stats:get/setDrunkenness,
    which Build 42 removed (stats are CharacterStat entries now), and the guard
    `if not s.setDrunkenness then return end` made it silently do nothing.

    Build 42.21 engine facts (private jar, nothing shipped):
      - CharacterStat.INTOXICATION, range 0..100.
      - MoodleStat.DRUNK thresholds 10 / 30 / 50 / 70 -> moodle levels 1..4.
      - CarController reads the DRIVER's DRUNK moodle level: above 1 it
        delays steering / throttle / brake commands (delayCommandWhileDrunk,
        timer 4 x level frames) and adds the drunk swerve.
    So LEVEL.Lupus = 65 sits in moodle level 3.

    The real intoxication is saved on taking the wheel and restored on
    leaving the driver seat, on a shift to a form that can drive, on death,
    and on load if a save caught the effect mid-drive.
]]

WTAGarou = WTAGarou or {}
WTAGarou.DrunkDriving = WTAGarou.DrunkDriving or {}
local DD = WTAGarou.DrunkDriving

-- Intoxication (0..100) held while driving, per form.
DD.LEVEL = DD.LEVEL or { Lupus = 65, Hispo = 55 }
-- Player updates between re-applications (intoxication decays naturally).
DD.REAPPLY_UPDATES = DD.REAPPLY_UPDATES or 10

local function formOf(player)
    if WTAGarou.GetData then return WTAGarou.GetData(player).form end
    local md = player:getModData()
    return md.WTAGarou and md.WTAGarou.form or "Homid"
end

local function stats(player)
    local ok, s = pcall(function() return player:getStats() end)
    return ok and s or nil
end

--- Current intoxication 0..100 (nil when unavailable).
function DD.getIntoxication(player)
    local s = stats(player); if not s then return nil end
    if CharacterStat and CharacterStat.INTOXICATION and s.get then
        local ok, v = pcall(function() return s:get(CharacterStat.INTOXICATION) end)
        if ok and type(v) == "number" then return v end
    end
    if s.getDrunkenness then
        local ok, v = pcall(function() return s:getDrunkenness() end)
        if ok and type(v) == "number" then return v end
    end
    return nil
end

function DD.setIntoxication(player, value)
    local s = stats(player); if not s then return false end
    value = math.max(0, math.min(100, tonumber(value) or 0))
    if CharacterStat and CharacterStat.INTOXICATION and s.set then
        local ok = pcall(function() s:set(CharacterStat.INTOXICATION, value) end)
        if ok then return true end
    end
    if s.setDrunkenness then
        return pcall(function() s:setDrunkenness(value) end)
    end
    return false
end

function DD.isDriving(player)
    if not player then return false end
    local ok, driving = pcall(function()
        local vehicle = player:getVehicle()
        if not vehicle then return false end
        if vehicle.getDriver then return vehicle:getDriver() == player end
        return vehicle.isDriver and vehicle:isDriver(player) or false
    end)
    return ok and driving == true
end

function DD.levelFor(form)
    local fd = WTAGarou.GetForm and WTAGarou.GetForm(form) or nil
    if not (fd and fd.drunkDriving) then return nil end
    return tonumber(DD.LEVEL[tostring(form)]) or 55
end

local function moodleLevel(player)
    local level
    pcall(function() level = player:getMoodles():getMoodleLevel(MoodleType.DRUNK) end)
    return level
end

function DD.begin(player, level)
    local md = player:getModData()
    if not md.WTAGarou_DrunkDriveActive then
        md.WTAGarou_SavedDrunk = DD.getIntoxication(player) or 0
        md.WTAGarou_DrunkDriveActive = true
        print(string.format("[WTAGarou][DrunkDriving] %s takes the wheel: intoxication %.0f -> %.0f",
            tostring(formOf(player)), md.WTAGarou_SavedDrunk, level))
    end
    local current = DD.getIntoxication(player) or 0
    if current < level then DD.setIntoxication(player, level) end
    return true
end

function DD.finish(player)
    local md = player and player:getModData() or nil
    if not md or not md.WTAGarou_DrunkDriveActive then return false end
    DD.setIntoxication(player, md.WTAGarou_SavedDrunk or 0)
    print(string.format("[WTAGarou][DrunkDriving] off the wheel: intoxication restored to %.0f", md.WTAGarou_SavedDrunk or 0))
    md.WTAGarou_SavedDrunk = nil
    md.WTAGarou_DrunkDriveActive = false
    return true
end

local counters = setmetatable({}, { __mode = "k" })
local logged = setmetatable({}, { __mode = "k" })
--- One update for a local player. Returns "drunk", "sober" or nil.
function DD.update(player)
    if not player then return nil end
    if player.isLocalPlayer and not player:isLocalPlayer() then return nil end
    local md = player:getModData()
    local driving = not player:isDead() and WTAGarou.HasGarouTrait and WTAGarou.HasGarouTrait(player)
        and DD.isDriving(player)
    local level = driving and DD.levelFor(formOf(player)) or nil
    if level then
        local n = (counters[player] or DD.REAPPLY_UPDATES) + 1
        if n >= DD.REAPPLY_UPDATES or not md.WTAGarou_DrunkDriveActive then
            n = 0
            DD.begin(player, level)
            if not logged[player] then
                local m = moodleLevel(player)
                -- Moodles refresh on their own update; log once it has caught up.
                if m and m > 0 then
                    logged[player] = true
                    print("[WTAGarou][DrunkDriving] drunk moodle level " .. tostring(m) .. " (car controller swerves above 1)")
                end
            end
        end
        counters[player] = n
        return "drunk"
    end
    counters[player] = nil
    logged[player] = nil
    if md.WTAGarou_DrunkDriveActive then DD.finish(player); return "sober" end
    return nil
end

if Events and Events.OnPlayerUpdate then Events.OnPlayerUpdate.Add(DD.update) end
if Events and Events.OnPlayerDeath then Events.OnPlayerDeath.Add(function(player) DD.finish(player) end) end

return DD
