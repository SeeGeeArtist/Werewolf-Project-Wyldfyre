-- Runtime counterpart to the character-creation GrantedTraits script.
-- Authority first; the owning client mirrors ONLY its addressed reply.
WTAGarou = WTAGarou or {}
WTAGarou.TraitBundle = WTAGarou.TraitBundle or {}
local B = WTAGarou.TraitBundle

local function resolve()
    local garou = WTAGarouTraits and WTAGarouTraits.Garou
    local T = CharacterTrait
    if not garou or not T then return nil end
    local list = {
        {trait = T.SLOW_HEALER, wanted = false},
        {trait = T.LIGHT_EATER, wanted = false},
        {trait = T.FAST_HEALER, wanted = true},
        {trait = T.HEARTY_APPETITE, wanted = true},
        {trait = T.NIGHT_VISION, wanted = true},
        {trait = garou, wanted = true},
    }
    for _,entry in ipairs(list) do if not entry.trait then return nil end end
    return list
end

-- Only actual membership changes call modifyTraitXPBoost. Repeated replies,
-- commands and reconnects cannot stack the trait's XP modifiers.
-- Do not apply creation-time skill levels, reset XP, or strip unrelated
-- creation-screen exclusions from an already played character.
function B.apply(player, removing)
    if not player or not player.getCharacterTraits or not player.modifyTraitXPBoost then
        return false, "Character trait API unavailable."
    end
    local list
    if removing then
        local trait = WTAGarouTraits and WTAGarouTraits.Garou
        if trait then list = {{trait = trait, wanted = false}} end
    else
        list = resolve()
    end
    if not list then return false, "Werewolf trait registry unavailable; nothing granted." end
    local changed, traits = {}, nil
    local ok, err = pcall(function()
        traits = player:getCharacterTraits()
        for _,entry in ipairs(list) do entry.before = traits:get(entry.trait) == true end
        for _,entry in ipairs(list) do
            if entry.before ~= entry.wanted then
                changed[#changed + 1] = entry
                traits:set(entry.trait, entry.wanted)
                if traits:get(entry.trait) ~= entry.wanted then error("trait change refused") end
                player:modifyTraitXPBoost(entry.trait, not entry.wanted)
                entry.boostApplied = true
            end
        end
    end)
    if not ok then
        for i = #changed, 1, -1 do
            local entry = changed[i]
            pcall(function()
                traits:set(entry.trait, entry.before)
                if entry.boostApplied then player:modifyTraitXPBoost(entry.trait, not entry.before) end
            end)
        end
        print("[WTAGarou][Enrollment] trait change failed: " .. tostring(err))
        return false, "Trait change failed. Check the log; no success was recorded."
    end
    return true, #changed > 0
end
return B
