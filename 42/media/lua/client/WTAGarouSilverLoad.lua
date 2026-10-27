--[[
    WTAGarou - Load silver rounds (v0.4.58, Wits W3 client side; 0.4.63 rework)

    Inventory context menu on a firearm (tube/cylinder guns) or on a
    magazine: "Load silver rounds (n)". Appears only when matching silver
    rounds are in the inventory; refusals (ordinary rounds inside, full,
    no thumbs) flash the HUD line instead of silently doing nothing.

    0.4.63: the actions themselves live in shared/WTAGarouSilverLoadActions.lua
    and ARE the vanilla reload actions with silver rounds, so loading plays
    the reload animation and sounds, obeys reload speed, racks afterwards
    and needs the gun in the primary hand (the menu equips it, as vanilla's
    "Load bullets" does). The firearm radial menu (R held / controller RB)
    gets a "Load silver rounds" slice next to the vanilla one.
]]

require "WTAGarouSilverLoadActions"
require "ISUI/ISFirearmRadialMenu"

WTAGarou = WTAGarou or {}
local S = WTAGarou.SilverAmmo

-- Translation with a built-in English fallback (the mod's JSON strings are
-- not guaranteed to be picked up by every B42 build).
local function T(key, default, ...)
    local text = getTextOrNull and getTextOrNull(key, ...) or nil
    if text and text ~= "" and text ~= key then return text end
    local out = default
    for i, v in ipairs({ ... }) do out = out:gsub("%%" .. i, tostring(v)) end
    return out
end

local function refuse(character, reason)
    local hud = WTAGarou.HUD and WTAGarou.HUD.instance
    if hud and hud.flashDenial then hud:flashDenial(reason or "silver_no_rounds") end
end

-- ---------------------------------------------------------------------------
-- Context menu
-- ---------------------------------------------------------------------------
WTAGarou.SilverLoad = WTAGarou.SilverLoad or {}
local L = WTAGarou.SilverLoad

local function firstItem(items)
    local item = items[1]
    if item and not instanceof(item, "InventoryItem") then item = item.items and item.items[1] end
    return item
end

local function isGun(item)
    return item ~= nil and instanceof(item, "HandWeapon") and item:isRanged() == true
end

local function isLoadTarget(item)
    if not item then return false end
    if isGun(item) then
        return not S.hasMagazine(item)
    end
    -- magazines: ammo type but no trigger
    return S.ammoKeyOf(item) ~= nil and item.getMaxAmmo ~= nil and not instanceof(item, "HandWeapon")
end
L.isLoadTarget = isLoadTarget

-- Vanilla moves the rounds out of bags into the main inventory before the
-- reload action starts (ISInventoryPaneContextMenu.transferBullets).
local function stageRounds(playerObj, target, silverType)
    if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.transferBullets then
        ISInventoryPaneContextMenu.transferBullets(playerObj, silverType, target:getCurrentAmmoCount(), target:getMaxAmmo())
    end
end

-- Queue the right action for the target. `count` caps the rounds loaded.
function L.queue(playerObj, target, count)
    local silverType = S.silverTypeFor(S.ammoKeyOf(target))
    if not silverType then return nil end
    stageRounds(playerObj, target, silverType)
    if isGun(target) then
        -- vanilla "Load bullets into firearm": equip first, the action needs it in hand
        if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.equipWeapon then
            ISInventoryPaneContextMenu.equipWeapon(target, true, false, playerObj:getPlayerNum())
        end
        return ISTimedActionQueue.add(WTAGarouLoadSilverAction:new(playerObj, target, count))
    end
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, target)
    return ISTimedActionQueue.add(WTAGarouLoadSilverMagazineAction:new(playerObj, target, count))
end

function L.onLoad(playerObj, target, count)
    if WTAGarou.Paws and WTAGarou.Paws.isPaws and WTAGarou.Paws.isPaws(playerObj) then
        WTAGarou.Paws.refuse(playerObj, "paws_firearm"); return
    end
    local ok, result = S.canLoad(playerObj, target)
    if not ok then refuse(playerObj, result); return end
    L.queue(playerObj, target, count or result)
end

function L.fillContextMenu(playerNum, context, items)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or not context then return end
    local item = firstItem(items)
    if not isLoadTarget(item) then return end
    local baseKey = S.ammoKeyOf(item)
    local silverType = S.silverTypeFor(baseKey)
    if not silverType then return end
    local available = S.countInInventory(playerObj:getInventory(), silverType)
    local inside = S.count(item)
    if available <= 0 and inside <= 0 then return end
    if available > 0 then
        local ok, result = S.canLoad(playerObj, item)
        local label = T("ContextMenu_WTAGarou_LoadSilver", "Load silver rounds")
        if ok then label = label .. " (" .. tostring(result) .. ")" end
        local option = context:addOption(label, playerObj, L.onLoad, item, ok and result or nil)
        if not ok and option then
            option.notAvailable = true
            local tip = ISToolTip:new(); tip:initialise(); tip:setVisible(false)
            local text = WTAGarou.HUD and WTAGarou.HUD.DENIAL_TEXT and WTAGarou.HUD.DENIAL_TEXT[result]
            tip.description = text or tostring(result)
            option.toolTip = tip
        end
    end
    if inside > 0 and inside ~= math.huge then
        local info = context:addOption(T("ContextMenu_WTAGarou_SilverInside", "Silver rounds loaded: %1", tostring(inside)), nil, nil)
        if info then info.notAvailable = true end
    end
end

if Events and Events.OnFillInventoryObjectContextMenu then
    Events.OnFillInventoryObjectContextMenu.Add(L.fillContextMenu)
end

-- ---------------------------------------------------------------------------
-- Firearm radial menu (hold R / controller RB): "Load silver rounds"
-- ---------------------------------------------------------------------------
-- The fullest not-full magazine of the gun's type that holds no ordinary
-- rounds (vanilla CLoadBulletsInMagazine picks the fullest not-full one).
function L.bestMagazine(playerObj, weapon)
    local magType = weapon.getMagazineType and weapon:getMagazineType() or nil
    if not magType or tostring(magType) == "" then return nil end
    local items = playerObj:getInventory():getItemsFromFullType(tostring(magType))
    local best = nil
    if items and items.size then
        for i = 0, items:size() - 1 do
            local mag = items:get(i)
            if mag:getCurrentAmmoCount() < mag:getMaxAmmo() and S.canLoad(playerObj, mag) == true then
                if not best or mag:getCurrentAmmoCount() > best:getCurrentAmmoCount() then best = mag end
            end
        end
    end
    return best
end

-- The target the radial slice would load, or nil (and the reason) when
-- there is nothing to offer. Pure enough for the tests.
function L.radialTarget(playerObj, weapon)
    if not isGun(weapon) then return nil end
    if S.hasMagazine(weapon) then
        local mag = L.bestMagazine(playerObj, weapon)
        if not mag then return nil end
        return mag, select(2, S.canLoad(playerObj, mag))
    end
    local ok, result = S.canLoad(playerObj, weapon)
    if not ok then return nil, result end
    return weapon, result
end

local function sliceText(target, n)
    local label = T("ContextMenu_WTAGarou_LoadSilver", "Load silver rounds")
    local xln = (target.isRoundChambered and target:isRoundChambered()) and "IGUI_FirearmRadial_AmmoCountChambered" or "IGUI_FirearmRadial_AmmoCount"
    local countText = getTextOrNull and getTextOrNull(xln, target:getCurrentAmmoCount(), target:getMaxAmmo()) or nil
    if not countText or countText == xln then
        countText = tostring(target:getCurrentAmmoCount()) .. "/" .. tostring(target:getMaxAmmo())
    end
    return label .. " (+" .. tostring(n) .. ")\n" .. countText
end

function L.fillRadial(frm, menu, weapon)
    local playerObj = frm.character
    if not (playerObj and menu and weapon) then return false end
    if WTAGarou.Paws and WTAGarou.Paws.isPaws and WTAGarou.Paws.isPaws(playerObj) then return false end
    local target, n = L.radialTarget(playerObj, weapon)
    if not target then return false end
    local icon = S.hasMagazine(weapon) and "media/ui/FirearmRadial_BulletsIntoMagazine.png" or "media/ui/FirearmRadial_BulletsIntoFirearm.png"
    menu:addSlice(sliceText(target, n), getTexture and getTexture(icon) or nil, function()
        L.onLoad(playerObj, target, n)
    end)
    return true
end

if ISFirearmRadialMenu and not ISFirearmRadialMenu.WTAGarou_silver_fillMenu then
    ISFirearmRadialMenu.WTAGarou_silver_fillMenu = ISFirearmRadialMenu.fillMenu
    function ISFirearmRadialMenu:fillMenu(...)
        local result = ISFirearmRadialMenu.WTAGarou_silver_fillMenu(self, ...)
        local ok, err = pcall(function()
            local menu = getPlayerRadialMenu(self.playerNum)
            local weapon = self:getWeapon()
            if menu and weapon then L.fillRadial(self, menu, weapon) end
        end)
        if not ok then print("[WTAGarou][Silver] radial slice failed: " .. tostring(err)) end
        return result
    end
end
