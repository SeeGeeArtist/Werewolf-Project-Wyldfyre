-- Development tools; opt-in, no -debug or console required.
require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "WTAGarouDebug"

WTAGarou.TestPanel = WTAGarou.TestPanel or {}
local Panel = WTAGarou.TestPanel
local LAYOUT_KEY = "WTAGarouTestPanelLayout"
WTAGarouTestWindow = ISCollapsableWindow:derive("WTAGarouTestWindow")

-- Existing debug commands operate on getPlayer(). Do not silently target
-- player zero from another split-screen player's context menu.
function Panel.allowed(player)
    if not player or player ~= getPlayer() or player:isDead() then return false end
    if not isClient() then return true end
    -- 0.4.83: same rule as the server (role capability), so the panel never
    -- shows what the server will refuse.
    if WTAGarou.Access and WTAGarou.Access.privileged then return WTAGarou.Access.privileged(player) end
    return false
end

function Panel.notify(text)
    if Panel.instance then Panel.instance:setOutput(text) end
end

local function measure(text)
    return getTextManager():MeasureStringX(UIFont.Small, text)
end

-- Plain text only: Java diagnostics must not be interpreted as rich-text tags.
function Panel.wrap(text, width)
    local lines, line = {}, ""
    for paragraph in (tostring(text) .. "\n"):gmatch("(.-)\n") do
        for word in paragraph:gmatch("%S+") do
            local joined = line == "" and word or line .. " " .. word
            if line ~= "" and measure(joined) > width then
                lines[#lines + 1], line = line, ""
            end
            -- Also split long unbroken diagnostics/paths.
            for i = 1, #word do
                local char = word:sub(i, i)
                local prefix = i == 1 and line ~= "" and " " or ""
                if measure(line .. prefix .. char) > width and line ~= "" then
                    lines[#lines + 1], line, prefix = line, "", ""
                end
                line = line .. prefix .. char
            end
        end
        lines[#lines + 1], line = line, ""
    end
    return lines
end

function WTAGarouTestWindow:new(x, y)
    local fontHeight = getTextManager():getFontHeight(UIFont.Small)
    local cellWidth = math.max(84, measure("Crinos") + 20)
    local width = 24 + cellWidth * 5 + 4 * 4
    local lineHeight = fontHeight + 4
    local buttonHeight = math.max(24, fontHeight + 8)
    local o = ISCollapsableWindow.new(self, x, y, width, 600)
    o.lineHeight, o.buttonHeight, o.cellWidth = lineHeight, buttonHeight, cellWidth
    o.resizable = false
    o.backgroundColor = {r=0.04, g=0.04, b=0.05, a=0.95}
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    o:setTitle("Werewolf Cheats")
    o.labels, o.buttons = {}, {}
    o.outputLines, o.outputOffset = {}, 0
    return o
end

function WTAGarouTestWindow:button(text, column, columns, y, command, kind)
    local width = (self.width - 24 - (columns - 1) * 4) / columns
    local b = ISButton:new(12 + (column - 1) * (width + 4), y,
        width, self.buttonHeight, text, self, WTAGarouTestWindow.onButton)
    b.testCommand, b.testKind = command, kind
    b:initialise()
    if kind == "instant" then
        b:setTooltip("Instant test: skips the channel, Rage cost and cooldown. May drop form-forbidden gear.")
    end
    self:addChild(b)
    self.buttons[#self.buttons + 1] = b
end

function WTAGarouTestWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local y = self:titleBarHeight() + 8
    self.summaryY = y
    y = y + self.lineHeight * 3 + 6
    local function label(text)
        self.labels[#self.labels + 1] = {text=text, y=y}
        y = y + self.lineHeight
    end
    local function row(items, kind)
        for i, item in ipairs(items) do
            self:button(item[1], i, #items, y, item[2], kind)
        end
        y = y + self.buttonHeight + 6
    end
    label("Normal shift: channel, Rage cost and cooldown")
    local normal, instant = {}, {}
    for _, form in ipairs(WTAGarou.FormOrder) do
        normal[#normal + 1] = {form, "shift " .. form}
        instant[#instant + 1] = {form, "form " .. form}
    end
    row(normal, "shift")
    label("Instant form: bypasses costs; gear rules still apply")
    row(instant, "instant")
    label("Rage")
    row({{"0", "rage 0"}, {"50", "rage 50"}, {"100", "rage 100"},
        {"-25", "rage -25"}, {"+25", "rage +25"}}, "rage")
    label("Direct wolf prototype: visuals only")
    row({{"Wolf ON", "wolf on"}, {"Wolf OFF", "wolf off"},
        {"Status", "visual-status"}}, "visual")
    label("Diagnostics")
    row({{"Player info", "info"}, {"Trace panic", "panictrace 60"},
        {"Stop trace", "panictrace 0"}}, "diagnostic")
    row({{"Grant trait", "trait"}, {"Reset HUD", "hudreset"}, {"Reload defs", "reload"}}, "utility")
    row({{"Reset identity", "identity reset"}, {"Swap sex (SP)", "sex"}}, "utility")
    label("Silver: kit = wearable silver + nitrate ingredients (1 fertilizer bag, battery), tools, empty jar + jar of finished nitrate, gloves, fragments, shells; rounds flag the held gun")
    row({{"Silver kit", "silver"}, {"Silver rounds", "silverrounds"}, {"Gear kit", "gearkit"}}, "utility")
    row({{"Firearm kit", "firearmkit"}}, "utility")
    self.outputLabelY = y
    self.outputY = y + self.lineHeight
    self.outputRows = 6
    self:setHeight(self.outputY + self.outputRows * self.lineHeight + 12)
    self:setOutput("Ready. Use a test save. Instant form changes can drop restricted gear. Normal shifts use the existing nil-animation channel.")
    self:refreshButtons()
end

function WTAGarouTestWindow:setOutput(text)
    self.outputLines = Panel.wrap(text, self.width - 32)
    self.outputOffset = 0
end

function WTAGarouTestWindow:refreshButtons()
    local player = getPlayer()
    local allowed = Panel.allowed(player)
    local garou = allowed and WTAGarou.HasGarouTrait(player)
    local busy = allowed and WTAGarou.IsChannelling and WTAGarou.IsChannelling(player)
    for _, b in ipairs(self.buttons) do
        b.enable = allowed
        if b.testKind == "shift" or b.testKind == "instant" then
            b.enable = garou and not busy
        elseif b.testCommand == "trait" then
            b.enable = allowed and not garou and not busy
        end
    end
end

function WTAGarouTestWindow:onButton(button)
    self:refreshButtons()
    if not button.enable then return end
    local command = button.testCommand
    self:setOutput("Requested: " .. command .. ". Live state above reflects the result.")
    local ok, err = pcall(function()
        if command == "visual-status" then
            if WTAGarouJava and WTAGarouJava.status then
                local status = tostring(WTAGarouJava.status())
                print("[WTAGarou][TestPanel] " .. status)
                self:setOutput(status)
            else
                self:setOutput("Java API unavailable. Check that ZombieBuddy is enabled and the WTAGarou Java module is approved.")
            end
        else
            WTAGarou.Debug.handle(command)
            if command == "wolf on" or command == "wolf off" then
                self:setOutput(command .. " requested. This changes visuals, not the form. Use Status for Java diagnostics; appearance still needs an in-game check.")
            end
        end
    end)
    if not ok then
        print("[WTAGarou][TestPanel] " .. tostring(err))
        self:setOutput("ERROR: " .. tostring(err))
    end
    self:refreshButtons()
end

function WTAGarouTestWindow:onMouseWheel(delta)
    local maximum = math.max(0, #self.outputLines - self.outputRows)
    self.outputOffset = math.max(0, math.min(maximum, self.outputOffset + delta))
    return true
end

function WTAGarouTestWindow:saveLayout()
    local player = getPlayer()
    if player then
        player:getModData()[LAYOUT_KEY] = {x=self:getX(), y=self:getY()}
    end
end

function WTAGarouTestWindow:clampPosition()
    local core = getCore()
    self:setX(math.max(0, math.min(self:getX(), core:getScreenWidth() - self.width)))
    self:setY(math.max(0, math.min(self:getY(), core:getScreenHeight() - self.height)))
end

function WTAGarouTestWindow:prerender()
    self:clampPosition()
    ISCollapsableWindow.prerender(self)
    self:refreshButtons()
    local player = getPlayer()
    if not player or player:isDead() then self:close(); return end
    local d = WTAGarou.GetData(player)
    local fd = WTAGarou.GetForm(d.form)
    local summaries = {
        string.format("Form: %s    Rage: %.1f / %d    Scale: %.2f",
            tostring(d.form), d.rage or 0, WTAGarou.Rage.MAX, fd.modelScale or 1),
        "Werewolf: " .. tostring(WTAGarou.HasGarouTrait(player)) ..
            "    Wolf requested: " .. tostring(WTAGarou.EnableDirectWolf == true),
        "Java API: " .. (WTAGarouJava and "available" or "unavailable") ..
            "    Channel: " .. ((WTAGarou.IsChannelling and WTAGarou.IsChannelling(player)) and "active" or "idle"),
    }
    -- 0.4.70: the body text hides only while the window is actually rolled
    -- up. It used to key off `self.pin`, which ISCollapsableWindow clears
    -- the moment the collapse (pin) button is pressed -- so an un-pinned
    -- window that is open under the mouse drew its buttons and no text.
    if self.isCollapsed then return end
    for i, text in ipairs(summaries) do
        self:drawText(text, 12, self.summaryY + (i - 1) * self.lineHeight,
            0.85, 0.9, 1, 1, UIFont.Small)
    end
    for _, label in ipairs(self.labels) do
        self:drawText(label.text, 12, label.y, 0.85, 0.85, 0.85, 1, UIFont.Small)
    end
    self:drawText("Latest result (mouse wheel scrolls; details in console.txt)",
        12, self.outputLabelY, 0.75, 0.75, 0.75, 1, UIFont.Small)
    self:drawRect(12, self.outputY, self.width - 24, self.outputRows * self.lineHeight,
        0.5, 0, 0, 0)
    for i = 1, self.outputRows do
        self:drawText(self.outputLines[self.outputOffset + i] or "",
            16, self.outputY + (i - 1) * self.lineHeight, 0.8, 1, 0.8, 1, UIFont.Small)
    end
end

function WTAGarouTestWindow:close()
    self:saveLayout()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    Panel.instance = nil
end

function Panel.open()
    local player = getPlayer()
    if not Panel.allowed(player) then return end
    if Panel.instance then return Panel.instance end
    local saved = player:getModData()[LAYOUT_KEY]
    local x = type(saved) == "table" and tonumber(saved.x)
    local y = type(saved) == "table" and tonumber(saved.y)
    local ui = WTAGarouTestWindow:new(x or 0, y or 40)
    ui:initialise()
    if not x then ui:setX(getCore():getScreenWidth() - ui.width - 24) end
    ui:clampPosition()
    ui:addToUIManager()
    Panel.instance = ui
    return ui
end

function WTAGarouToggleTestPanel()
    if Panel.instance then Panel.instance:close() else Panel.open() end
end

-- 0.4.45: the world context entry is admin-only (multiplayer role). Single
-- player and non-admins open the panel with "/garou cheats" (Lua console
-- or chat) so nothing cheat-like sits in a player's right-click menu.
Panel.MENU_LABEL = "Werewolf Cheats"
function Panel.menuVisible(player)
    if not Panel.allowed(player) then return false end
    if not isClient() then return false end
    local ok, admin = pcall(function() return isAdmin() end)
    return ok and admin == true
end
Events.OnFillWorldObjectContextMenu.Add(function(playerNum, context, worldObjects, test)
    if test then return end
    if not Panel.menuVisible(getSpecificPlayer(playerNum)) then return end
    context:addOption(Panel.MENU_LABEL, nil, Panel.open)
end)

Events.OnPlayerDeath.Add(function(player)
    if player == getPlayer() and Panel.instance then Panel.instance:close() end
end)
