-- Cosmetic only. The server still owns forms, costs and shift completion.
WTAGarou = WTAGarou or {}
WTAGarou.ShiftScale = {}
local S = WTAGarou.ShiftScale
local states = setmetatable({}, { __mode = "k" })
local remoteSeen = setmetatable({}, { __mode = "k" })

local function now()
    if getTimestampMs then return getTimestampMs() / 1000 end
    return getTimestamp()
end

local function ease(t)
    t = math.max(0, math.min(1, t))
    return t * t * (3 - 2 * t)
end

function S.clear(player)
    states[player] = nil
    remoteSeen[player] = nil
end

local function report(player, state, progress, cancelled)
    local token = state.owner and state.owner.shiftVisualToken
    if not (isClient and isClient() and type(token) == "number"
            and WTAGarou.Net and WTAGarou.Net.ToServer) then return end
    local at = now()
    if not cancelled and state.lastReport and at - state.lastReport < 0.2 then return end
    state.lastReport = at
    WTAGarou.Net.ToServer(player, "ShiftVisualProgress",
        {token=token, progress=not cancelled and progress or nil, cancel=cancelled or nil})
end

local function returnToForm(state, at)
    if state.mode == "return" then return end
    state.mode, state.returnAt, state.returnFrom = "return", at, state.value
end

-- Called by the ordinary visual refresh, including forced refreshes.
function S.value(player, form, base)
    local state = states[player]
    if not state then return base, false end
    if form ~= state.form then
        S.clear(player)
        return base, false
    end
    local at = now()
    if state.remote then
        if state.mode == "channel" and at >= state.expires then
            -- No packets: finish any current interpolation before recovering.
            state.value = state.destination
            returnToForm(state, at)
        end
        if state.mode == "return" then
            local elapsed = at - state.returnAt
            if elapsed >= state.returnDuration then
                states[player] = nil -- retain revision: old snapshots cannot replay it
                return base, false
            end
            state.value = state.returnFrom + (base - state.returnFrom) * ease(elapsed / state.returnDuration)
        else
            -- The samples already contain the channel's easing. Linear
            -- in-between frames avoid stopping/starting at every packet.
            local t = math.max(0, math.min(1, (at - state.sampleAt) / 0.2))
            state.value = state.initial + (state.destination - state.initial) * t
        end
        return state.value, true
    end
    -- Do not leave a player stretched if a completion reply never arrives.
    if state.mode == "pending" and at >= state.pendingUntil then
        returnToForm(state, at)
    end
    if state.mode == "return" then
        local elapsed = at - state.returnAt
        if elapsed >= 1 then
            S.clear(player)
            return base, false
        end
        state.value = state.returnFrom + (base - state.returnFrom) * ease(elapsed)
    end
    return state.value, true
end

function S.start(player, owner, form, target)
    if not WTAGarou.EnableJavaScale or not WTAGarou.GetForm then return end
    local base = WTAGarou.GetForm(form).modelScale or 1
    local destination = WTAGarou.GetForm(target).modelScale or 1
    -- Read at channel start, not module load, so Reload defs can tune it.
    local fraction = tonumber(WTAGarou.ShiftScaleFraction) or 0.75
    if fraction ~= fraction then fraction = 0.75 end
    fraction = math.max(0, math.min(1, fraction))
    -- Restarting during the one-second recovery begins at the visible size.
    local initial = S.value(player, form, base)
    states[player] = {
        owner = owner, form = form, mode = "channel",
        initial = initial, value = initial, endpoint = base + (destination - base) * fraction,
    }
    report(player, states[player], 0)
end

function S.progress(player, owner, progress)
    local state = states[player]
    if not state or state.owner ~= owner or state.mode ~= "channel" then return end
    progress = tonumber(progress)
    if not progress or progress ~= progress then return end
    state.value = state.initial + (state.endpoint - state.initial) * ease(progress)
    report(player, state, math.max(0, math.min(1, progress)))
end

function S.cancel(player, owner)
    local state = states[player]
    if not state or state.owner ~= owner then return end
    if state.mode ~= "return" then report(player, state, nil, true) end
    returnToForm(state, now())
end

function S.finish(player, owner)
    local state = states[player]
    if not state or state.owner ~= owner then return end
    state.value, state.mode = state.endpoint, "pending"
    state.pendingUntil = now() + 5
end

function S.denied(player)
    local state = states[player]
    -- A denied new request must not cancel an unrelated running channel.
    if state and state.mode == "pending" then returnToForm(state, now()) end
end

function S.validRemote(shift)
    if shift == nil then return true end
    return type(shift) == "table"
        and type(shift.token) == "number" and shift.token > 0 and shift.token < 9007199254740991
        and shift.token % 1 == 0
        and type(shift.revision) == "number" and shift.revision > 0 and shift.revision < 9007199254740991
        and shift.revision % 1 == 0
        and (shift.mode == "channel" or shift.mode == "return")
        and type(shift.value) == "number" and shift.value >= 0.5 and shift.value <= 2
        and type(shift.remaining) == "number" and shift.remaining >= 0 and shift.remaining <= 1
end

-- Validated server-only descriptors; never write remote gameplay modData.
function S.remote(player, shift, form, receivedAt)
    if not shift then S.clear(player); return end
    local old = remoteSeen[player]
    if old and (shift.token < old.token
            or (shift.token == old.token and shift.revision <= old.revision)) then return end
    local at = now()
    local age = math.max(0, at - receivedAt)
    local base = WTAGarou.GetForm(form).modelScale or 1
    local current = states[player] and S.value(player, form, base) or shift.value
    remoteSeen[player] = {token=shift.token, revision=shift.revision}
    if age >= 3 or (shift.mode == "return" and age >= shift.remaining) then
        states[player] = nil; return
    end
    states[player] = {remote=true, form=form, mode=shift.mode, value=current,
        initial=current, destination=shift.value, sampleAt=at, expires=receivedAt + 3,
        returnFrom=current, returnAt=at,
        returnDuration=shift.mode == "return" and (shift.remaining - age) or 1}
end
