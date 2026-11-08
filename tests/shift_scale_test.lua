-- State-machine tests; rendered appearance still needs an in-game test.
local root = assert(arg[1])
package.path = root .. "/42/media/lua/shared/?.lua;" .. root .. "/42/media/lua/client/?.lua;" .. package.path
require "WTAGarouDefinitions"
require "WTAGarouShiftScale"
local S = WTAGarou.ShiftScale
local clock, checks = 100, 0
getTimestampMs = function() return clock * 1000 end
local function check(ok, label) checks = checks + 1; assert(ok, label) end
local function near(a, b, label) check(math.abs(a - b) < 0.000001, label) end
local player, other, owner = {}, {}, {}
local function value(form)
    return S.value(player, form, WTAGarou.GetForm(form).modelScale)
end

-- Every direction, including shrinking, equal forms and wolf forms.
for _, from in ipairs(WTAGarou.FormOrder) do
    for _, target in ipairs(WTAGarou.FormOrder) do
        S.clear(player)
        local base, dest = WTAGarou.GetForm(from).modelScale, WTAGarou.GetForm(target).modelScale
        local endpoint = base + (dest - base) * 0.75
        S.start(player, owner, from, target)
        near(value(from), base, "starts at current form scale")
        S.progress(player, owner, 0.5)
        near(value(from), (base + endpoint) / 2, "half channel is halfway to endpoint")
        near(S.value(other, from, base), base, "another player is unchanged")
        S.progress(player, owner, 1)
        near(value(from), endpoint, "end channel reaches 75% of the size difference")
        S.finish(player, owner)
        clock = clock + 0.25
        near(value(from), endpoint, "holds through server reply delay")
        if from ~= target then
            near(value(target), dest, "confirmed form uses exact destination")
        else
            S.clear(player) -- explicit TransformCompleted also covers equal forms
            near(value(target), dest, "equal-form completion clears state")
        end
    end
end

S.clear(player)
S.start(player, owner, "Homid", "Crinos")
S.progress(player, owner, 0.5)
local cancelledAt = value("Homid")
S.cancel(player, owner)
near(value("Homid"), cancelledAt, "cancel has no instantaneous size jump")
clock = clock + 0.5
near(value("Homid"), (cancelledAt + 1) / 2, "half second return")
S.cancel(player, owner) -- repeated stop/forceCancel must not restart the timer
clock = clock + 0.5
local restored, active = value("Homid")
near(restored, 1, "one second return")
check(not active, "recovery releases state")

S.start(player, owner, "Homid", "Crinos")
S.progress(player, owner, 0.8)
S.cancel(player, owner)
clock = clock + 0.2
local visible = value("Homid")
local nextOwner = {}
S.start(player, nextOwner, "Homid", "Hispo")
near(value("Homid"), visible, "new shift during recovery has no pop")
S.cancel(player, owner)
S.progress(player, owner, 1)
S.finish(player, owner)
near(value("Homid"), visible, "stale action cannot change a new channel")
S.progress(player, nextOwner, 1)
near(value("Homid"), 1.4125, "replacement has its own endpoint")
S.denied(player)
near(value("Homid"), 1.4125, "unrelated denied request leaves active shift alone")
S.finish(player, nextOwner)
S.denied(player)
clock = clock + 1
near(value("Homid"), 1, "denied completion recovers")

S.start(player, owner, "Homid", "Crinos")
S.finish(player, owner)
clock = clock + 5
near(value("Homid"), 1.4875, "missing reply begins recovery without a pop")
clock = clock + 1
near(value("Homid"), 1, "missing reply cannot leave scale stuck")
S.start(player, owner, "Homid", "Crinos")
S.progress(player, owner, -2)
near(value("Homid"), 1, "negative progress clamped")
S.progress(player, owner, 5)
near(value("Homid"), 1.4875, "excess progress clamped")
S.progress(player, owner, 0/0)
near(value("Homid"), 1.4875, "NaN progress ignored")
near(value("Lupus"), 1.15, "forced form change overrides interpolation")
S.clear(player)
-- Tuning is sampled for each new channel. Definitions reload must neither
-- replace runtime helpers nor abruptly retarget an already-running shift.
for _,fraction in ipairs({0, 0.5, 0.75, 1}) do
    for _,forms in ipairs({{"Homid","Crinos"},{"Crinos","Homid"}}) do
        local from, target = forms[1], forms[2]
        local base, dest = WTAGarou.GetForm(from).modelScale, WTAGarou.GetForm(target).modelScale
        WTAGarou.ShiftScaleFraction = fraction
        S.clear(player)
        S.start(player, owner, from, target)
        S.progress(player, owner, 1)
        near(value(from), base + (dest-base)*fraction, "configured endpoint in either direction")
        S.cancel(player, owner)
        clock=clock+1
        near(value(from), base, "all endpoint settings keep one-second cancellation")
    end
end
S.clear(player)
WTAGarou.ShiftScaleFraction=1
S.start(player, owner, "Homid", "Crinos")
dofile(root .. "/42/media/lua/shared/WTAGarouDefinitions.lua")
check(WTAGarou.ShiftScale==S, "Definitions reload preserves runtime")
near(WTAGarou.ShiftScaleFraction,0.75,"Definitions reload picks up tuning")
S.progress(player, owner, 1)
near(value("Homid"),1.65,"reload leaves active channel endpoint unchanged")
S.clear(player)
S.start(player, owner, "Homid", "Crinos")
S.progress(player, owner, 1)
near(value("Homid"),1.4875,"next shift uses reloaded fraction")
for _,setting in ipairs({-1, 2, "invalid", 0/0}) do
    WTAGarou.ShiftScaleFraction=setting
    S.clear(player)
    S.start(player, owner, "Homid", "Crinos")
    S.progress(player, owner, 1)
    local expected = setting==-1 and 1 or setting==2 and 1.65 or 1.4875
    near(value("Homid"),expected,"out-of-range and invalid settings are safe")
end
WTAGarou.ShiftScaleFraction=0.75
S.clear(player)
WTAGarou.EnableJavaScale = false
S.start(player, owner, "Homid", "Crinos")
S.progress(player, owner, 1)
near(value("Homid"), 1, "disabled Java scaling creates no transition")
print("PASS: " .. checks .. " shift-scale assertions.")
