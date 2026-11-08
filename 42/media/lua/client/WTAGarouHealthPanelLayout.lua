-- Expand the health layout for Garou status lines, not by shrinking injuries.
-- Overrides only our own drawing helpers; vanilla render/update remain intact.
require "WTAGarouHealthPanel"
local HP = WTAGarou.HealthPanel

-- 0.5.0: wrap Garou status text inside the panel's existing width instead of
-- widening the whole health window (too wide on small screens like the Deck).
-- A purge note "(purging ...)" always starts its own line; continuation lines
-- are indented under the text after "- ".
HP.MIN_WRAP_WIDTH = 80

local function wrapWords(tm, text, width, indent, firstPad)
    local lines, line = {}, nil
    for word in string.gmatch(text, "%S+") do
        local candidate = line and (line .. " " .. word) or word
        local pad = (#lines > 0) and indent or (firstPad or 0)
        if line and tm:MeasureStringX(UIFont.Small, candidate) + pad > width then
            lines[#lines + 1] = line
            line = word
        else
            line = candidate
        end
    end
    if line then lines[#lines + 1] = line end
    return lines
end

function HP.wrapLines(text, width)
    local tm = getTextManager()
    local indent = tm:MeasureStringX(UIFont.Small, "- ")
    local head, tail = string.match(text, "^(.-)%s+(%(.*)$")
    local parts = head and { head, tail } or { text }
    local out = {}
    for p, part in ipairs(parts) do
        -- the note's first line is drawn indented too, so measure it that way
        local wrapped = wrapWords(tm, part, width, indent, p > 1 and indent or 0)
        for i, l in ipairs(wrapped) do
            out[#out + 1] = { text = l, indent = (p > 1 or i > 1) and indent or 0 }
        end
    end
    return out
end

function HP.drawSizedLine(panel, text, color)
    local box = panel.listbox
    if not box then return end
    local tm = getTextManager()
    local fontHgt = tm:getFontHeight(UIFont.Small)
    local spacing = 10 -- ISHealthPanel's local UI_BORDER_SPACING
    local footer = fontHgt + spacing * 2
    local x = panel.healthPanel:getRight() + spacing
    local y = box:getY()
    -- Width is left to vanilla; only the height grows by the wrapped lines.
    local wrapWidth = math.max(HP.MIN_WRAP_WIDTH, panel:getWidth() - x - spacing)
    local lines = HP.wrapLines(text, wrapWidth)

    -- Vanilla rebuilds list origin/content each render. Use absolute geometry.
    local top = panel:getY()
    local parent = panel.parent
    while parent and parent.parent do
        top = top + parent:getY()
        parent = parent.parent
    end
    local newY = y + fontHgt * #lines
    local available = math.max(0, getCore():getScreenHeight() - top - footer - newY)
    local height = math.min(box:getScrollHeight(), available)
    box:setY(newY)
    box:setHeight(height)
    if box.vscroll then box.vscroll:setHeight(height) end
    panel.allTextHeight = newY + height
    local desired = math.max(panel.healthPanel:getBottom(), panel.allTextHeight) + footer
    panel:setHeightAndParentHeight(math.min(desired, math.max(0, getCore():getScreenHeight() - top)))
    for i, l in ipairs(lines) do
        panel:drawText(l.text, x + l.indent, y + fontHgt * (i - 1), color.r, color.g, color.b, 1, UIFont.Small)
    end
end

function HP.draw(panel)
    if not panel.listbox then return end
    local text, purging = HP.lineText(panel.character)
    HP.drawSizedLine(panel, text, purging and HP.PURGE_COLOR or HP.COLOR)
end

function HP.drawSilver(panel)
    if not panel.listbox then return end
    local data = WTAGarou.GetData and WTAGarou.GetData(panel.character) or nil
    local text = HP.silverLine(data)
    if text then HP.drawSizedLine(panel, text, HP.SILVER_COLOR) end
end
