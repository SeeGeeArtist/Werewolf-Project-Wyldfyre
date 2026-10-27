--[[
    WTAGarou - Strip (v0.4.16)

    "Strip" in the Garou panel and the form radial queues a normal, channelled
    unequip (vanilla ISUnequipAction, the same action the inventory's
    "Unequip" uses) for every worn item a shift to Hispo, Lupus or Crinos
    would otherwise tear off and drop damaged. Containers, jewellery and the
    other WTAGarou.ShiftStrip.SAFE_LOCATIONS are left alone, as are held
    items. Nothing is damaged and nothing is dropped: the clothes land in the
    inventory exactly as if each piece had been unequipped by hand, one after
    another. Purely client-side; the engine syncs worn items itself.

    0.4.16: every item Strip takes off is remembered by exact id in the
    player's Wardrobe (WTAGarouWardrobe.lua) so "Dress" (WTAGarouDress.lua)
    can put the same pieces back on.
]]

WTAGarou = WTAGarou or {}
WTAGarou.Strip = WTAGarou.Strip or {}
local Strip = WTAGarou.Strip

local UNEQUIP_TIME = 50   -- vanilla ISInventoryPaneContextMenu.unequipItem uses 50

local function notify(text)
    if WTAGarou.TestPanel and WTAGarou.TestPanel.notify then WTAGarou.TestPanel.notify(text) end
    if WTAGarou.HUD and WTAGarou.HUD.instance and WTAGarou.HUD.instance.setDebugLine then
        WTAGarou.HUD.instance:setDebugLine(text)
    end
end

-- Returns the number of unequip actions queued (0 when nothing applies).
function Strip.queue(player)
    player = player or (getPlayer and getPlayer())
    if not player or player:isDead() then return 0 end
    if not WTAGarou.HasGarouTrait(player) then return 0 end
    if WTAGarou.IsChannelling and WTAGarou.IsChannelling(player) then
        notify("Finish the change first.")
        return 0
    end
    if not (ISTimedActionQueue and ISTimedActionQueue.add and ISUnequipAction and ISUnequipAction.new) then
        print("[WTAGarou][Strip] vanilla unequip action unavailable; nothing queued")
        return 0
    end
    local items = WTAGarou.Clothing and WTAGarou.Clothing.stripCandidates
        and WTAGarou.Clothing.stripCandidates(player) or {}
    if #items == 0 then
        notify("Nothing worn that a shift would tear.")
        return 0
    end
    local queued = 0
    for _, item in ipairs(items) do
        local ok, err = pcall(function()
            ISTimedActionQueue.add(ISUnequipAction:new(player, item, UNEQUIP_TIME))
        end)
        if ok then
            queued = queued + 1
            if WTAGarou.Wardrobe and WTAGarou.Wardrobe.record then
                WTAGarou.Wardrobe.record(player, item, "strip")
            end
        else print("[WTAGarou][Strip] unequip queue failed: " .. tostring(err)) end
    end
    if queued > 0 then
        notify("Stripping " .. queued .. " item(s)...")
    end
    return queued
end

function WTAGarou.RequestStrip(player)
    return Strip.queue(player or (getPlayer and getPlayer() or nil))
end
