-- 0.4.47: direct Howl / Strip / Dress slices on the social wheel.
-- No Garou submenu: selecting a slice never refills/reopens the shared wheel.
require "ISUI/ISEmoteRadialMenu"

WTAGarou = WTAGarou or {}
WTAGarou.Emote = WTAGarou.Emote or {}

local function iconFor(name)
    return getTexture("media/ui/WTAGarou/wta_" .. string.lower(name) .. ".png")
end

local originalFillMenu = ISEmoteRadialMenu.fillMenu
function ISEmoteRadialMenu:fillMenu(submenu)
    originalFillMenu(self, submenu)
    if submenu then return end
    local player = self.character or getSpecificPlayer(self.playerNum)
    if not player or not WTAGarou.HasGarouTrait(player) then return end
    local menu = getPlayerRadialMenu(self.playerNum)
    if not menu then return end

    local target = WTAGarou.BaselineRage(WTAGarou.GetData(player))
    menu:addSlice(string.format("Howl\nRage %d", target), iconFor("howl"),
        WTAGarou.RequestHowl, player)
    menu:addSlice("Toggle\nRage panel", iconFor("shift"), function(owner)
        if WTAGarou.HUD and WTAGarou.HUD.toggle then WTAGarou.HUD.toggle(owner) end
    end, player)

    -- Keep stable slice positions even when the action has nothing to do.
    -- The existing wardrobe actions safely handle zero eligible items.
    local candidates = WTAGarou.Clothing and WTAGarou.Clothing.stripCandidates
        and WTAGarou.Clothing.stripCandidates(player) or {}
    menu:addSlice(string.format("Strip\n%d item(s)", #candidates), iconFor("strip"),
        WTAGarou.RequestStrip, player)
    local remembered = WTAGarou.Wardrobe and WTAGarou.Wardrobe.count
        and WTAGarou.Wardrobe.count(player) or 0
    menu:addSlice(string.format("Dress\n%d item(s)", remembered), iconFor("dress"),
        WTAGarou.RequestDress, player)
    -- addSlice updates the native radial immediately. originalFillMenu has
    -- already displayed it; do not display again or touch joypad focus here.
end
