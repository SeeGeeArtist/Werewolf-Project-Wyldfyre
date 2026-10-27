-- WTAGarouSilverTooltip.lua (client)
-- 0.4.62: one extra line under the inventory tooltip of a silvered weapon:
--   "Silver coat: 7 of 12 hits left"
--   "Silver-Clad: burns werewolves, prevents healing."
-- The vanilla tooltip body is drawn by Java (InventoryItem.DoTooltip) from
-- ISToolTipInv:render, and a fluid-container weapon (saucepan, kettle) shows
-- its FluidContainer's UI name instead of the renamed item name, so the
-- "Silvered X (n)" rename alone was invisible on the pan the playtest used.
-- We wrap ISToolTipInv:render: call vanilla, then draw a strip below it.
-- Any error inside the strip is swallowed and the hook disables itself, so
-- a tooltip can never be lost to this file.

require "ISUI/ISToolTipInv"

WTAGarou = WTAGarou or {}
WTAGarou.SilverTooltip = WTAGarou.SilverTooltip or {}
local T = WTAGarou.SilverTooltip

T.PAD_X = 6
T.PAD_Y = 3

-- Pure: which line, if any, for this item (delegates to the shared module).
function T.lineFor(item)
    local S = WTAGarou.SilverAmmo
    if not S or not S.tooltipLine then return nil end
    return S.tooltipLine(item)
end

function T.drawStrip(self, text, r, g, b)
    local font = UIFont.Small
    local tm = getTextManager()
    local lineH = tm:getFontHeight(font) + T.PAD_Y * 2
    local textW = tm:MeasureStringX(font, text) + T.PAD_X * 2
    local y = self:getHeight()
    if textW > self:getWidth() then self:setWidth(textW) end
    self:setHeight(y + lineH)
    self:drawRect(0, y, self:getWidth(), lineH, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, y - 1, self:getWidth(), lineH + 1, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    self:drawText(text, T.PAD_X, y + T.PAD_Y, r, g, b, 1, font)
end

if ISToolTipInv and not T.installed then
    T.installed = true
    local vanillaRender = ISToolTipInv.render
    T.disabled = false
    function ISToolTipInv:render()
        vanillaRender(self)
        if T.disabled or not self.item then return end
        -- vanilla draws nothing while a context menu is up; neither do we
        if ISContextMenu and ISContextMenu.instance and ISContextMenu.instance.visibleCheck then return end
        local text, r, g, b = T.lineFor(self.item)
        if not text then return end
        local ok, err = pcall(T.drawStrip, self, text, r or 1, g or 1, b or 1)
        if not ok then
            T.disabled = true
            print("[WTAGarou][Silver] tooltip strip disabled: " .. tostring(err))
        end
    end
    print("[WTAGarou][Silver] inventory tooltip shows silver coat charges / forged silver")
end
