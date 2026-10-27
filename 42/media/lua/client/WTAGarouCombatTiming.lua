-- Skully reference: separate CombatSpeed (swing) from SetMeleeDelay (recovery).
-- Independent Garou-only implementation; no global player AnimSet overrides.
require "WTAGarouDefinitions"
WTAGarou.CombatTiming = WTAGarou.CombatTiming or {}
local Timing = WTAGarou.CombatTiming
local warned = false

function Timing.swingSpeed(base, swing)
    if type(base) ~= "number" or base ~= base or base <= 0 then return base end
    local multiplier, cap = 1.10, 1.11
    if swing == "Heavy" then multiplier, cap = 1.50, 1.51
    elseif swing == "Stab" then multiplier, cap = 1.22, 1.23 end
    -- Unlike a plain min(base*mult, cap), never slow an already faster swing.
    return math.max(base, math.min(base * multiplier, cap))
end

function Timing.onSwing(character, weapon)
    if not character or not weapon or not WTAGarou.HasGarouTrait(character)
            or character:isDead() or weapon:isRanged() then return end
    -- The standalone mod already installs its own OnWeaponSwing handler.
    -- Avoid applying our multiplier a second time regardless of load order.
    local mods = getActivatedMods and getActivatedMods()
    if mods and mods:contains("SkullysFasterSwingSpeed") then
        if not warned then
            warned = true
            print("[WTAGarou] Standalone Skully swing mod active; skipping duplicate swing boost.")
        end
        return
    end
    local base = character:getVariableFloat("CombatSpeed", 0)
    local speed
    if Timing.isJawAttack(character) then
        speed = Timing.biteSpeed(base, weapon, character)
    else
        speed = Timing.swingSpeed(base, weapon:getSwingAnim())
    end
    if speed ~= base then character:setVariable("CombatSpeed", speed) end
end

-- 0.4.58: a quadruped attacks with its jaws no matter what it carries. The
-- engine still rates the carried item (an electric guitar is BaseSpeed 1.1,
-- two-handed and "Heavy": vanilla multiplies CombatSpeed by 1.1 and 1.2,
-- then the Skully Heavy table above pushed it to the 1.51 cap) and the
-- October 13 Hispo playtest showed the result as a machine-gun bite. A bite
-- ignores the weapon's own class factors and takes the generic multiplier.
function Timing.isJawAttack(character)
    return WTAGarou.Slots and WTAGarou.Slots.isQuadruped
        and WTAGarou.Slots.isQuadruped(character) == true
end

-- Vanilla IsoGameCharacter weapon factors on CombatSpeed (B42.20.2):
-- BaseSpeed, x0.77 for a two-hander held in one hand, x1.2 for a two-handed
-- Heavy weapon. Divide them back out so the bite speed is weapon-neutral.
function Timing.weaponFactor(character, weapon)
    local factor = 1
    local ok, baseSpeed = pcall(function() return weapon:getBaseSpeed() end)
    if ok and type(baseSpeed) == "number" and baseSpeed > 0 then factor = factor * baseSpeed end
    local okTwo, twoHanded = pcall(function() return weapon:isTwoHandWeapon() end)
    if okTwo and twoHanded then
        local okSec, secondary = pcall(function() return character:getSecondaryHandItem() end)
        if okSec and secondary ~= weapon then factor = factor * 0.77 end
        local okSwing, swing = pcall(function() return weapon:getSwingAnim() end)
        if okSwing and swing == "Heavy" then factor = factor * 1.2 end
    end
    return factor
end

function Timing.biteSpeed(base, weapon, character)
    if type(base) ~= "number" or base ~= base or base <= 0 then return base end
    local neutral = base / Timing.weaponFactor(character, weapon)
    -- Same shape as swingSpeed's generic row, but computed from the
    -- weapon-neutral base and allowed to LOWER an inflated heavy value.
    return math.min(neutral * 1.10, 1.11)
end

-- Java clamps only the actual SetMeleeDelay animation event, never the
-- per-tick countdown setter. Homid Garou receive the Skully timing too.
function Timing.refresh(character)
    if not character or not WTAGarouJava or not WTAGarouJava.setCombatTiming then return end
    WTAGarouJava.setCombatTiming(character,
        not character:isDead() and WTAGarou.HasGarouTrait(character))
end
Events.OnWeaponSwing.Add(Timing.onSwing)
Events.OnPlayerUpdate.Add(Timing.refresh)
Events.OnCreatePlayer.Add(function(_, character) Timing.refresh(character) end)
Events.OnPlayerDeath.Add(function(character)
    if WTAGarouJava and WTAGarouJava.setCombatTiming then
        WTAGarouJava.setCombatTiming(character, false)
    end
end)
