--[[
    WTAGarou - Health panel: "Wyrm Infection" and "Silver Burn" (v0.4.22)

    Lore: the Knox virus is a bioweapon built by Wyrm-corrupted humans. A Garou
    who carries it sees "- Wyrm Infection" in the overall body status of the
    vanilla health panel (vanilla itself only shows the zombie infection in
    debug/cheat mode), plus how far the current form has purged it.

    Implementation: a post-hook on ISHealthPanel:render. Vanilla lays the
    overall-status lines out from scratch every frame and then positions the
    body-part list box under them, so after the original render we draw our
    line at the list box's top and push the list box down by one line. No
    vanilla function is replaced; if anything fails the panel renders as
    vanilla does.
]]

WTAGarou = WTAGarou or {}
WTAGarou.HealthPanel = WTAGarou.HealthPanel or {}
local HP = WTAGarou.HealthPanel

HP.COLOR       = { r = 0.75, g = 0.35, b = 0.95 }   -- Wyrm violet
HP.PURGE_COLOR = { r = 0.45, g = 0.90, b = 0.45 }
-- 0.4.22: silver-burned parts get their own line, light blue-grey (the
-- vanilla body-part list still says "Burn"; that list is not ours to edit).
HP.SILVER_COLOR = { r = 0.70, g = 0.80, b = 0.90 }
HP.SILVER_NAME  = "Silver Burn"

-- Display name for a d.silverBurns key ("Hand_L", "Neck" ...): the engine's
-- own label when it resolves, otherwise the key with spaces.
function HP.partName(key)
    local name
    pcall(function()
        if BodyPartType and BodyPartType.FromString and BodyPartType.getDisplayName then
            local t = BodyPartType.FromString(tostring(key))
            if t then name = BodyPartType.getDisplayName(t) end
        end
    end)
    if type(name) == "string" and name ~= "" then return name end
    return (tostring(key):gsub("_", " "))
end

-- "- Silver Burn: Neck, Left Hand" or nil when no part is silver-burned.
-- Pure: `data` is the WTAGarou mod-data table (d.silverBurns = {key=true}).
function HP.silverLine(data)
    local burns = data and data.silverBurns
    if type(burns) ~= "table" then return nil end
    local names = {}
    for key, flagged in pairs(burns) do
        if flagged then names[#names + 1] = HP.partName(key) end
    end
    if #names == 0 then return nil end
    table.sort(names)
    return "- " .. HP.SILVER_NAME .. ": " .. table.concat(names, ", ")
end

-- True when the character carries the Knox/Wyrm infection. Server and
-- client both own BodyDamage for the local player, so read it directly.
function HP.isInfected(character)
    if not character or not character.getBodyDamage then return false end
    local ok, bd = pcall(function() return character:getBodyDamage() end)
    if not ok or not bd then return false end
    if WTAGarou.HasZombieInfection then
        local okH, has = pcall(WTAGarou.HasZombieInfection, character, bd)
        if okH then return has and true or false end
    end
    local okI, inf = pcall(function() return bd:isInfected() end)
    if okI and inf then return true end
    local okI2, inf2 = pcall(function() return bd:IsInfected() end)
    return okI2 and inf2 and true or false
end

-- Line text: "- Wyrm Infection" plus the purge progress of the current form.
function HP.lineText(character)
    local d = WTAGarou.GetData and WTAGarou.GetData(character) or {}
    local name = (WTAGarou.WyrmInfection and WTAGarou.WyrmInfection.NAME) or "Wyrm Infection"
    local burn = tonumber(d.infectionBurn) or 0
    local rate = ((WTAGarou.Regeneration or {}).INFECTION_PER_SECOND or {})[d.form]
    -- 0.4.19: plain "- Wyrm Infection" unless a purge is running; then the
    -- percentage and time left only (no form name, no advice text).
    local text = "- " .. name
    if rate and rate > 0 then
        local left = math.max(0, math.ceil((100 - burn) / rate))
        text = text .. string.format(" (purging %d%%, %d:%02d left)",
            math.floor(burn), math.floor(left / 60), left % 60)
    end
    return text, rate ~= nil
end

function HP.shouldShow(panel)
    local character = panel and panel.character
    if not character then return false end
    if WTAGarou.HasGarouTrait and not WTAGarou.HasGarouTrait(character) then return false end
    return HP.isInfected(character)
end

function HP.shouldShowSilver(panel)
    local character = panel and panel.character
    if not character then return false end
    if WTAGarou.HasGarouTrait and not WTAGarou.HasGarouTrait(character) then return false end
    local d = WTAGarou.GetData and WTAGarou.GetData(character) or nil
    return HP.silverLine(d) ~= nil
end

-- Draw the Wyrm line where the list box starts and push the list down.
local function drawLine(panel, text, c)
    local fontHgt = getTextManager():getFontHeight(UIFont.Small)
    local x = (panel.healthPanel and panel.healthPanel:getRight() or 0) + (UI_BORDER_SPACING or 10)
    local y = panel.listbox:getY()
    panel:drawText(text, x, y, c.r, c.g, c.b, 1, UIFont.Small)
    panel.listbox:setY(y + fontHgt)
    panel.listbox:setHeight(math.max(fontHgt, panel.listbox:getHeight() - fontHgt))
    if panel.listbox.vscroll then panel.listbox.vscroll:setHeight(panel.listbox:getHeight()) end
end

function HP.draw(panel)
    if not panel.listbox then return end
    local text, purging = HP.lineText(panel.character)
    drawLine(panel, text, purging and HP.PURGE_COLOR or HP.COLOR)
end

function HP.drawSilver(panel)
    if not panel.listbox then return end
    local d = WTAGarou.GetData and WTAGarou.GetData(panel.character) or nil
    local text = HP.silverLine(d)
    if text then drawLine(panel, text, HP.SILVER_COLOR) end
end

-- ---------------------------------------------------------------------------
-- 0.4.76: lodged silver (d.silverLodged[key] = "bullet" | "shard") reads
-- "- Lodged silver-tip bullet" in the silver colour instead of the vanilla
-- "- Lodged Bullet". Vanilla draws that line inside
-- ISHealthBodyPartListBox:doDrawItem through self:drawText; we wrap
-- doDrawItem and, for a part with a silver mark, shadow drawText on the
-- instance for the duration of that one item. Nothing vanilla is replaced
-- permanently and any failure falls back to the vanilla line.
-- 0.4.79 (user request Oct 21): the silver BURN is a per-part line the same
-- way. A silver burn is a vanilla burn (burnTime) flagged in d.silverBurns,
-- so the vanilla "- Burned" / "- Burned (Needs Cleaning)" line of that part
-- becomes "- Silver Burn" / "- Silver Burn (Needs Cleaning)" in the silver
-- colour. When vanilla draws no burn line for the part (bandaged) a plain
-- "- Silver Burn" is appended under the part so the mark never disappears. The old summary
-- line at the top of the panel ("- Silver Burn: Neck, Left Hand") is gone.
-- ---------------------------------------------------------------------------
HP.LODGED_NAMES = { bullet = "Lodged silver-tip bullet", shard = "Lodged silver fragments" }
HP.LODGED_KEYS  = { bullet = "IGUI_health_LodgedBullet", shard = "IGUI_health_LodgedGlassShards" }
HP.BULLET_NAME = HP.LODGED_NAMES.bullet
HP.BURN_KEY    = "IGUI_health_Burned"
HP.WOUND_LINE_X = 15      -- vanilla ISHealthBodyPartListBox:doDrawItem "local x = 15"
HP.SUMMARY_LINE = false   -- 0.4.79: per-part lines instead of the summary

-- kind ("bullet"/"shard") lodged in `key`, or nil.
function HP.silverLodgedKind(d, key)
    local k = d and d.silverLodged and d.silverLodged[tostring(key)]
    return k ~= nil and tostring(k) or nil
end
function HP.hasSilverBullet(d, key) return HP.silverLodgedKind(d, key) == "bullet" end

function HP.silverBurned(d, key)
    local burns = d and d.silverBurns
    return type(burns) == "table" and burns[tostring(key)] == true
end

function HP.lodgedLine(kind)
    local t = getTextOrNull and getTextOrNull("IGUI_health_WTAGarou_Lodged" .. (kind == "shard" and "SilverShards" or "SilverBullet"))
    return "- " .. (t or HP.LODGED_NAMES[kind] or HP.LODGED_NAMES.bullet)
end
function HP.bulletLine() return HP.lodgedLine("bullet") end

-- "- Silver Burn" plus whatever vanilla appended (" (Needs Cleaning)").
function HP.silverBurnLine(suffix)
    local t = getTextOrNull and getTextOrNull("IGUI_health_WTAGarou_SilverBurn")
    return "- " .. (t or HP.SILVER_NAME) .. (suffix or "")
end

-- Pure: swap the vanilla line of `kind` (text given) for the silver one.
-- Kept for callers; the list hook uses swapDrawTextRules.
function HP.swapDrawText(baseDraw, vanillaText, kind)
    kind = kind or "bullet"
    return HP.swapDrawTextRules(baseDraw, { { exact = vanillaText, text = HP.lodgedLine(kind) } })
end

-- Pure: one shadow drawText applying a list of rules. A rule is
-- { exact = "..", text = ".." } or { prefix = "..", textFn = function(rest) }.
-- `rule.hit` is set when it fired.
function HP.swapDrawTextRules(baseDraw, rules)
    return function(self, str, x, y, r, g, b, a, font, ...)
        for _, rule in ipairs(rules) do
            local out
            if rule.exact and str == rule.exact then
                out = rule.text
            elseif rule.prefix and type(str) == "string" and str:sub(1, #rule.prefix) == rule.prefix then
                out = rule.textFn and rule.textFn(str:sub(#rule.prefix + 1)) or rule.text
            end
            if out then
                rule.hit = true
                local c = HP.SILVER_COLOR
                return baseDraw(self, out, x, y, c.r, c.g, c.b, a, font, ...)
            end
        end
        return baseDraw(self, str, x, y, r, g, b, a, font, ...)
    end
end

-- The rules for one body part of one character, or nil when it has no mark.
function HP.rulesFor(d, key)
    local rules = {}
    local kind = HP.silverLodgedKind(d, key)
    if kind and HP.LODGED_KEYS[kind] then
        rules[#rules + 1] = { exact = "- " .. getText(HP.LODGED_KEYS[kind]), text = HP.lodgedLine(kind) }
    end
    if HP.silverBurned(d, key) then
        local prefix = "- " .. getText(HP.BURN_KEY)
        rules[#rules + 1] = { prefix = prefix, burn = true,
            textFn = function(rest) return HP.silverBurnLine(rest) end }
    end
    if #rules == 0 then return nil end
    return rules
end

local function smallFontHeight()
    local ok, h = pcall(function() return getTextManager():getFontHeight(UIFont.Small) end)
    if ok and type(h) == "number" then return h end
    return 10
end

function HP.installBullet()
    if not ISHealthBodyPartListBox or HP.bulletInstalled then return false end
    local original = ISHealthBodyPartListBox.doDrawItem
    if type(original) ~= "function" then return false end
    ISHealthBodyPartListBox.doDrawItem = function(self, y, item, alt)
        local rules
        pcall(function()
            local bp = item and item.item and item.item.bodyPart
            local panel = self.parent
            local character = panel and (panel.otherPlayer or panel.character)
            if bp and character and WTAGarou.GetData then
                rules = HP.rulesFor(WTAGarou.GetData(character), bp:getType())
            end
        end)
        if not rules then return original(self, y, item, alt) end
        self.drawText = HP.swapDrawTextRules(self.drawText, rules)
        local ok, res = pcall(original, self, y, item, alt)
        self.drawText = nil
        if not ok then error(res, 0) end
        -- a silver-burned part whose vanilla burn line was not drawn
        -- (vanilla hides wounds under a bandage): add the plain line under
        -- the part so the mark never disappears. 0.4.82: same x as vanilla's
        -- own wound lines (ISHealthBodyPartListBox:doDrawItem, local x = 15;
        -- the old healthPanel:getRight() put it far to the right) and no
        -- "(bandaged)" suffix: the part already says "- Bandaged" above it.
        for _, rule in ipairs(rules) do
            if rule.burn and not rule.hit and type(res) == "number" then
                local c = HP.SILVER_COLOR
                local fontHgt = smallFontHeight()
                pcall(function() self:drawText(HP.silverBurnLine(""), HP.WOUND_LINE_X, res - 5, c.r, c.g, c.b, 1, UIFont.Small) end)
                res = res + fontHgt
            end
        end
        return res
    end
    HP.bulletInstalled = true
    return true
end

-- ---------------------------------------------------------------------------
-- 0.4.82: "Remove Glass" -> "Remove Silver Fragments" (Oct 22 playtest).
-- Lodged silver fragments ride the engine's haveGlass state on purpose
-- (vanilla hand/tweezers removal, vanilla pain and Doctor XP), so vanilla's
-- health-panel menu offers getText("ContextMenu_Remove_Glass") for them.
-- The handler that adds it is a local table inside ISHealthPanel.lua, so
-- the menu is post-processed instead: after ISHealthPanel:doBodyPartContextMenu
-- built it, the option whose name is the vanilla label is renamed when the
-- part's lodged silver kind is "shard". The submenu (tools / Hand) and the
-- vanilla ISRemoveGlass action behind it are untouched.
-- Duration note for testers: ISRemoveGlass:getDuration() returns 1 tick in
-- multiplayer for a role with Capability.CanMedicalCheat (the admin host),
-- and that role also removes it painlessly. That is vanilla; the mod does
-- not touch the timer.
-- ---------------------------------------------------------------------------
HP.REMOVE_GLASS_KEY = "ContextMenu_Remove_Glass"
HP.REMOVE_SILVER_KEY = "ContextMenu_WTAGarou_RemoveSilverFragments"
HP.REMOVE_SILVER_NAME = "Remove Silver Fragments"

function HP.removeSilverLabel()
    local t = getTextOrNull and getTextOrNull(HP.REMOVE_SILVER_KEY)
    return t or HP.REMOVE_SILVER_NAME
end

-- Rename the vanilla Remove Glass option in `context` for `bodyPart` of
-- `character` when silver fragments are what is lodged. Returns true when
-- a rename happened.
function HP.relabelRemoveGlass(context, character, bodyPart)
    if not (context and character and bodyPart and WTAGarou.GetData) then return false end
    local renamed = false
    pcall(function()
        local key = bodyPart.getType and bodyPart:getType() or bodyPart
        if HP.silverLodgedKind(WTAGarou.GetData(character), key) ~= "shard" then return end
        local vanilla = getText(HP.REMOVE_GLASS_KEY)
        local option = context.getOptionFromName and context:getOptionFromName(vanilla)
        if not option and type(context.options) == "table" then
            for _, o in ipairs(context.options) do
                if o.name == vanilla then option = o; break end
            end
        end
        if option then option.name = HP.removeSilverLabel(); renamed = true end
    end)
    return renamed
end

function HP.installRemoveGlass()
    if not ISHealthPanel or HP.removeGlassInstalled then return false end
    local original = ISHealthPanel.doBodyPartContextMenu
    if type(original) ~= "function" then return false end
    ISHealthPanel.doBodyPartContextMenu = function(self, bodyPart, x, y, ...)
        local result = original(self, bodyPart, x, y, ...)
        pcall(function()
            local playerNum = self.otherPlayer and self.otherPlayer:getPlayerNum() or self.character:getPlayerNum()
            -- the same object vanilla filled: ISContextMenu.get(playerNum, ...)
            -- returns getPlayerContextMenu(playerNum) (ISContextMenu.lua)
            local context = getPlayerContextMenu and getPlayerContextMenu(playerNum) or nil
            local character = self.otherPlayer or self.character
            HP.relabelRemoveGlass(context, character, bodyPart)
        end)
        return result
    end
    HP.removeGlassInstalled = true
    return true
end

function HP.install()
    HP.installBullet()
    HP.installRemoveGlass()
    if not ISHealthPanel or HP.installed then return false end
    local original = ISHealthPanel.render
    if type(original) ~= "function" then return false end
    ISHealthPanel.render = function(self, ...)
        original(self, ...)
        local ok, err = pcall(function()
            if HP.shouldShow(self) then HP.draw(self) end
            if HP.SUMMARY_LINE and HP.shouldShowSilver(self) then HP.drawSilver(self) end
        end)
        if not ok and not HP.warned then
            HP.warned = true
            print("[WTAGarou][HealthPanel] Wyrm line failed: " .. tostring(err))
        end
    end
    HP.installed = true
    return true
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function() HP.install() end)
end
