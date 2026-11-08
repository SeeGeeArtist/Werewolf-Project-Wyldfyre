-- Cosmetic only. The server still owns forms, costs and shift completion.
WTAGarou = WTAGarou or {}
WTAGarou.ShiftScale = {}
local S = WTAGarou.ShiftScale
local states = setmetatable({}, { __mode = "k" })

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
end

function S.progress(player, owner, progress)
    local state = states[player]
    if not state or state.owner ~= owner or state.mode ~= "channel" then return end
    progress = tonumber(progress)
    if not progress or progress ~= progress then return end
    state.value = state.initial + (state.endpoint - state.initial) * ease(progress)
end

function S.cancel(player, owner)
    local state = states[player]
    if not state or state.owner ~= owner then return end
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
