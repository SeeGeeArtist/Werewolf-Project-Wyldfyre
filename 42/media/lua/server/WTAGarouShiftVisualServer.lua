-- 0.5.1: cosmetic progress only. Never changes a form, reservation or Rage.
require "WTAGarouNet"
WTAGarou.ShiftVisualServer = {}
local S = WTAGarou.ShiftVisualServer
local states = setmetatable({}, { __mode = "k" })
local nextToken = 0
local function now()
    if getTimestampMs then return getTimestampMs() / 1000 end
    return getTimestamp()
end
local function ease(t)
    t = math.max(0, math.min(1, t))
    return t * t * (3 - 2 * t)
end
local function dirty()
    if WTAGarou.VisualSyncServer then WTAGarou.VisualSyncServer.dirty = true end
end
local function clear(player)
    if states[player] then states[player] = nil; dirty() end
end
local function value(s, at)
    if s.mode == "return" then
        return s.returnFrom + (s.base - s.returnFrom) * ease(at - s.returnAt)
    end
    return s.value
end
local function cancel(s, at)
    if s.mode == "return" then return end
    s.mode, s.returnAt, s.returnFrom = "return", at, s.value
    s.revision = s.revision + 1
    dirty()
end

-- Reconcile against live authoritative state, including deaths, forced
-- changes, expired reservations and lost/disconnected action owners.
function S.sample(player)
    local s = states[player]
    if not s then return nil end
    local d, at = WTAGarou.GetData(player), now()
    if player:isDead() or not WTAGarou.HasGarouTrait(player) or d.form ~= s.form then
        clear(player); return nil
    end
    if s.mode == "channel" and (d.pendingForm ~= s.target
            or getTimestamp() > (d.pendingExpiresAt or 0)
            or at - s.lastUpdate > 3) then
        cancel(s, at)
    end
    if s.mode == "return" and at - s.returnAt >= 1 then
        clear(player); return nil
    end
    return {token=s.token, revision=s.revision, mode=s.mode, value=value(s, at),
        remaining=s.mode == "return" and math.max(0, 1 - (at - s.returnAt)) or 0}
end

-- Called only for existing server replies. Every accepted reservation gets
-- a fresh token; a delayed packet from an old shift cannot affect its replacement.
function S.reply(player, command, args)
    if not isServer() then return end
    if command == "TransformAccepted" then
        local d = WTAGarou.GetData(player)
        if player:isDead() or not WTAGarou.HasGarouTrait(player)
                or not WTAGarou.IsValidForm(args.form) or d.pendingForm ~= args.form then return end
        local base = WTAGarou.GetForm(d.form).modelScale or 1
        local old = states[player]
        local initial = old and old.form == d.form and value(old, now()) or base
        local fraction = tonumber(WTAGarou.ShiftScaleFraction) or 0.75
        if fraction ~= fraction then fraction = 0.75 end
        fraction = math.max(0, math.min(1, fraction))
        local targetScale = WTAGarou.GetForm(args.form).modelScale or 1
        nextToken = nextToken + 1
        states[player] = {token=nextToken, revision=1, mode="channel",
            form=d.form, target=args.form, base=base, initial=initial,
            endpoint=base + (targetScale - base) * fraction, value=initial,
            progress=0, lastUpdate=now(), lastPacket=-100}
        args.shiftVisualToken = nextToken
        dirty()
    elseif command == "TransformCompleted" or command == "TransformForced" then
        clear(player)
    elseif command == "TransformDenied" or command == "RageSync" then
        S.sample(player)
    end
end

function S.receive(module, command, player, args)
    if not isServer() or module ~= "WTAGarou" or command ~= "ShiftVisualProgress"
            or not player or type(args) ~= "table" then return end
    local s = states[player]
    if not s or args.token ~= s.token or s.mode ~= "channel" then return end
    local d = WTAGarou.GetData(player)
    if player:isDead() or not WTAGarou.HasGarouTrait(player) or d.form ~= s.form
            or d.pendingForm ~= s.target or getTimestamp() > (d.pendingExpiresAt or 0) then return end
    local at = now()
    -- Cancellation is one terminal cosmetic message, including cancellation
    -- of a forced action whose gameplay reservation the server may retain.
    if args.cancel == true then cancel(s, at); return end
    if args.cancel ~= nil or type(args.progress) ~= "number"
            or args.progress ~= args.progress or args.progress < s.progress
            or args.progress < 0 or args.progress > 1 or at - s.lastPacket < 0.15 then return end
    s.progress, s.lastPacket, s.lastUpdate = args.progress, at, at
    s.value = s.initial + (s.endpoint - s.initial) * ease(s.progress)
    s.revision = s.revision + 1
    dirty()
end

function S.prune(seen)
    for player in pairs(states) do
        if not seen[player] then clear(player) end
    end
end
Events.OnClientCommand.Add(S.receive)
