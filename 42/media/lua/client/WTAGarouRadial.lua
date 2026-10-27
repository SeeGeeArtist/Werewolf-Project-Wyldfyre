-- 0.4.47: direct form/Resist slices on the native D-pad-right map wheel.
-- Do not open another shared radial from a release callback, or register a
-- keyboard opener that can inherit the previous wheel's release/focus state.
require "ISUI/ISDPadWheels"
require "WTAGarouLocalPlayers"

WTAGarou = WTAGarou or {}
WTAGarou.Radial = WTAGarou.Radial or {}

local function iconFor(name)
    return getTexture("media/ui/WTAGarou/wta_" .. string.lower(name) .. ".png")
end

function WTAGarou.Radial.addMapSlices(menu, player)
    local d = WTAGarou.GetData(player)
    for _, formName in ipairs(WTAGarou.FormOrder) do
        local form = WTAGarou.GetForm(formName)
        local shown = WTAGarou.DisplayName(formName)
        local label
        if formName == d.form then
            label = shown .. "\n(current)"
        elseif (form.rageCost or 0) <= 0 then
            label = shown .. "\nfree"
        elseif WTAGarou.RageRequired and WTAGarou.RageRequired(formName, d) > (form.rageCost or 0) then
            label = string.format("%s\nRage %d (need %d)", shown, form.rageCost,
                WTAGarou.RageRequired(formName, d))
        else
            label = string.format("%s\nRage %d", shown, form.rageCost)
        end
        menu:addSlice(label, iconFor(formName), WTAGarou.RequestTransform, formName, player)
    end
    local hud = WTAGarou.HUDFor(player)
    local remaining = hud and hud.crinosCountdownEnd
        and (hud.crinosCountdownEnd - WTAGarou.NowSeconds()) or nil
    local label = (remaining and remaining > 0) and string.format("RESIST\n%.1fs", remaining)
        or "Resist\nThe Change"
    menu:addSlice(label, iconFor("resist"), WTAGarou.RequestResist, player)
end

local originalDisplayRight = ISDPadWheels.onDisplayRight
function ISDPadWheels.onDisplayRight(joypadData)
    -- Preserve vanilla's pause gate, all map/zone/guide slices, centering,
    -- focus, aim-centering and DPadRight release/cancel lifecycle.
    local controls = UIManager.getSpeedControls()
    if controls and controls:getCurrentGameSpeed() == 0 then
        return originalDisplayRight(joypadData)
    end
    originalDisplayRight(joypadData)
    local player = getSpecificPlayer(joypadData.player)
    if not player or not WTAGarou.HasGarouTrait(player) then return end
    local menu = getPlayerRadialMenu(joypadData.player)
    if not menu or not menu:isVisible() then return end
    WTAGarou.Radial.addMapSlices(menu, player)
end
