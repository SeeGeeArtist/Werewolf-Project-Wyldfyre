-- WTAGarouSkillTooltip.lua (client)
-- 0.5.0: the Resolve skill tooltip. Vanilla ISSkillProgressBar:updateTooltip
-- builds the text from IGUI_perks_<id>_Description (every box) and
-- IGUI_perks_<id>_Description<level> (the hovered box). IG_UI.json carries
-- both. Playtests still showed a raw underscore key (B42.21 used the
-- translated name, "IGUI_perks_Resolve_Description"), so after vanilla runs
-- this swaps any raw Resolve key for the same text built in Lua
-- (WTAGarou.Resolve.text) and adds the level text if the engine had none.
-- Other skills are untouched. Any error disables the hook; the vanilla
-- tooltip is never lost.
WTAGarou = WTAGarou or {}

local PERK_ID = "WTAGarou_Resolve"
local KEY = "IGUI_perks_" .. PERK_ID .. "_Description"

local function replacePlain(s, find, repl)
    local i, j = string.find(s, find, 1, true)
    if not i then return s, false end
    return string.sub(s, 1, i - 1) .. repl .. string.sub(s, j + 1), true
end

-- Pure: fix a vanilla-built message for the hovered level (1-based).
function WTAGarou.FixResolveTooltip(message, level)
    local T = WTAGarou.Resolve and WTAGarou.Resolve.text
    if type(message) ~= "string" or not T then return message end
    local levelText = T.level(level)
    local msg = message
    if levelText then msg = replacePlain(msg, KEY .. tostring(level), levelText) end
    msg = replacePlain(msg, KEY, T.main())
    -- November 8 playtest: B42.21 built the key from the translated name
    -- ("IGUI_perks_Resolve_Description"), not the perk id. Only Resolve
    -- tooltips reach here, so any leftover raw description key is ours.
    msg = string.gsub(msg, "IGUI_perks_[%w_]-_Description(%d*)", function(n)
        if n ~= "" then return levelText or "" end
        return T.main()
    end)
    if levelText and not string.find(msg, levelText, 1, true) then
        msg = msg .. " <LINE><LINE> " .. levelText
    end
    return msg
end

local function install()
    if WTAGarou.__resolveTooltipWrapped or not ISSkillProgressBar or not ISSkillProgressBar.updateTooltip then return end
    WTAGarou.__resolveTooltipWrapped = true
    local vanilla = ISSkillProgressBar.updateTooltip
    local broken = false
    function ISSkillProgressBar:updateTooltip(lvlSelected)
        vanilla(self, lvlSelected)
        if broken then return end
        local ok, err = pcall(function()
            if not (self.perk and self.perk.getId and self.perk:getId() == PERK_ID) then return end
            self.message = WTAGarou.FixResolveTooltip(self.message, (tonumber(lvlSelected) or 0) + 1)
        end)
        if not ok then
            broken = true
            print("[WTAGarou][SkillTooltip] disabled after error: " .. tostring(err))
        end
    end
end

install()
if Events and Events.OnGameStart then Events.OnGameStart.Add(install) end
