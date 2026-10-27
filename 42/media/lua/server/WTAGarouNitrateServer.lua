--[[
    WTAGarou - server side of NitrateCooked (0.4.66, 0.4.72 pace clamp)
    A client that simulated a nitrate vessel warming reports its litres; the
    server (which has no Java and owns the item) mirrors them and pushes the
    item stats to everyone. See WTAGarou.SilverAmmo.applyNitrateReport for
    the acceptance rules. 0.4.72: the server also owns the PACE: per vessel
    it allows at most nitrateAllowance(minutes since the last accepted
    report) litres per report, so two clients watching the same oven cannot
    finish a jar twice as fast.
]]
require "WTAGarouNet"
require "WTAGarouSilverAmmo"

WTAGarou.NitrateServer = WTAGarou.NitrateServer or {}
local NSrv = WTAGarou.NitrateServer
NSrv.lastAccepted = {}    -- itemID -> game minutes of the last accepted report
NSrv.clamped = 0

local function gameMinutes()
    if getGameTime then
        local ok, gt = pcall(getGameTime)
        if ok and gt and gt.getWorldAgeHours then
            local ok2, h = pcall(function() return gt:getWorldAgeHours() end)
            if ok2 and h then return h * 60 end
        end
    end
    return nil
end

-- Apply one report. `minutesNow` is injectable for tests. Returns ok, moved, clamped.
function NSrv.apply(item, raw, done, minutesNow)
    local S = WTAGarou.SilverAmmo
    local curRaw, curDone = S.readNitrate(item)
    if not curRaw then return S.applyNitrateReport(item, raw, done) end
    local id = item.getID and item:getID() or tostring(item)
    minutesNow = minutesNow or gameMinutes()
    local clamped = false
    if minutesNow then
        local last = NSrv.lastAccepted[id]
        -- first report of a vessel: allow the full warm-up+boil elapsed so far? No:
        -- unknown history gets the slack only; the client re-reports anyway.
        local since = last and math.max(0, minutesNow - last) or 0
        raw, done, clamped = S.clampNitrateReport(curRaw, curDone, raw, done, S.nitrateAllowance(since))
    end
    local ok, moved = S.applyNitrateReport(item, raw, done)
    if ok and minutesNow and (tonumber(moved) or 0) > 0 then NSrv.lastAccepted[id] = minutesNow end
    if clamped then NSrv.clamped = NSrv.clamped + 1 end
    return ok, moved, clamped
end

-- The live vessel for a report. In multiplayer args.item (if present at all)
-- is a detached copy made by the command serializer and must be ignored;
-- the id/square locator finds the real one. Single player passes the object.
function NSrv.resolve(player, args, cell)
    local S = WTAGarou.SilverAmmo
    if isServer and isServer() then
        local item = S.findVessel(player, args, cell)
        if not item then print("[WTAGarou][Silver] nitrate report: vessel id " .. tostring(args.id) .. " not found at " .. tostring(args.x) .. "," .. tostring(args.y) .. "," .. tostring(args.z)) end
        return item
    end
    return args.item or S.findVessel(player, args, cell)
end

local function onNitrateCommand(module, command, player, args)
    if module ~= "WTAGarou" or command ~= WTAGarou.SilverAmmo.NITRATE_COMMAND then return end
    args = args or {}
    local item = NSrv.resolve(player, args)
    if item == nil then return end
    local ok, moved, clamped = NSrv.apply(item, args.raw, args.done)
    if not ok then
        print("[WTAGarou][Silver] nitrate report refused: " .. tostring(moved))
        return
    end
    if type(sendItemStats) == "function" then pcall(sendItemStats, item) end
    if (tonumber(moved) or 0) > 0 then
        print(string.format("[WTAGarou][Silver] nitrate warmed on the server: %.3f L finished%s (report raw %.3f, done %.3f)",
            moved, clamped and " (pace-clamped)" or "", tonumber(args.raw) or 0, tonumber(args.done) or 0))
    end
end

Events.OnClientCommand.Add(onNitrateCommand)
WTAGarou.Net.RegisterServerHandler(onNitrateCommand)
