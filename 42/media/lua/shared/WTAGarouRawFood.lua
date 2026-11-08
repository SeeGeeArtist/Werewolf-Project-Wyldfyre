-- Fresh raw-food immunity at the authoritative Build 42 eating boundary.
-- Java still covers direct engine meals in SP; hosted servers need this Lua path.
require "WTAGarouDefinitions"
require "WTAGarouState"
require "TimedActions/ISEatFoodAction"

WTAGarou.RawFood = WTAGarou.RawFood or {}
local R = WTAGarou.RawFood

function R.before(action)
    if isClient() then return nil end
    local ok, stats, value = pcall(function()
        local player, food = action.character, action.item
        if not player or not food or not WTAGarou.HasGarouTrait
            or not WTAGarou.HasGarouTrait(player) then return end
        -- Match TraitsRuntime.isDangerousUncooked; never suppress real poison.
        if not food:isbDangerousUncooked() or food:isCooked()
            or food:isRotten() or food:isTainted() or food:getPoisonPower() > 0 then return end
        local s = player:getStats()
        return s, s:get(CharacterStat.POISON)
    end)
    if ok and stats and type(value) == "number" then
        return { stats = stats, value = value }
    end
    return nil
end

function R.after(saved)
    if not saved then return end
    local ok, err = pcall(function()
        -- Keep pre-existing poisoning, and do not undo a legitimate reduction.
        if saved.stats:get(CharacterStat.POISON) > saved.value then
            saved.stats:set(CharacterStat.POISON, saved.value)
        end
    end)
    if not ok and not R.warned then
        R.warned = true
        print("[WTAGarou][RawFood] poison restore failed: " .. tostring(err))
    end
end

local function wrap(original)
    return function(self, ...)
        local saved = R.before(self)
        local ok, result = pcall(original, self, ...)
        R.after(saved)
        if not ok then error(result, 0) end
        return result
    end
end

-- complete eats the selected portion; eat is called by serverStop for a
-- partly consumed interrupted meal. Never call Eat ourselves or patch perform.
function R.install()
    if ISEatFoodAction.WTAGarou_rawFoodHook then return false end
    if type(ISEatFoodAction.complete) ~= "function"
        or type(ISEatFoodAction.eat) ~= "function" then return false end
    ISEatFoodAction.complete = wrap(ISEatFoodAction.complete)
    ISEatFoodAction.eat = wrap(ISEatFoodAction.eat)
    ISEatFoodAction.WTAGarou_rawFoodHook = true
    return true
end
R.install()
