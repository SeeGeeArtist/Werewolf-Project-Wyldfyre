--[[
    WTAGarou - HUD panel (v0.3.1)

    Shows the Rage bar, current Form, Infamy, the five form buttons and Howl.
    Transformation affordability is server-authoritative. The panel therefore
    keeps non-current form buttons clickable, matching the radial menu and
    avoiding stale Rage sync falsely greying out a valid Crinos shift.
]]

require "ISUI/ISCollapsableWindow"
require "keyBinding"
require "WTAGarouLocalPlayers"

WTAGarou = WTAGarou or {}
WTAGarou.HUD = WTAGarou.HUD or {}
WTAGarou.HUD.instances = WTAGarou.HUD.instances or setmetatable({}, {__mode="k"})
local initialized = setmetatable({}, {__mode="k"})

function WTAGarou.HUD.forPlayer(player)
    player=player or WTAGarou.PrimaryLocalPlayer()
    if not player then return nil end
    return WTAGarou.HUD.instances[player]
end

WTAGarouHUD = ISCollapsableWindow:derive("WTAGarouHUD")

local WIDTH  = 300   -- default AND minimum width ("Near-Human" needs 140 a column)
-- 0.4.17 layout (user request, September 26): the five form buttons stack
-- in a LEFT column, Strip / Dress / Howl in a RIGHT column, notices below.
-- 0.4.79 (user request October 21): the panel is resizable in both axes
-- (vanilla corner + bottom-edge handles). The two button columns share the
-- width; the log takes whatever height is left (4 lines by default). The
-- status line that sat between the meter and the buttons is gone: its
-- texts ("Changing to Human... press Esc to stop", denials, the silver
-- warning) are log entries now, so the buttons start straight under the meter.
WTAGarou.HUD.TITLE_H  = 16
WTAGarou.HUD.LINE_H   = 14
WTAGarou.HUD.NOTICE_LINES   = 4     -- log lines in view at the default height
WTAGarou.HUD.MIN_LOG_LINES  = 2
WTAGarou.HUD.MIN_WIDTH      = WIDTH
WTAGarou.HUD.LAYOUT = {
    BTN_H = 20, GAP = 4, PAD = 8, COL_GAP = 8,
    ROW_Y_OFFSET = 42,      -- straight under the meter (0.4.79)
    LOG_PAD = 4,            -- between the last button row and the log
    BOTTOM = 18,            -- debug line / resize handle strip
}
function WTAGarou.HUD.buttonRows() return math.max(#WTAGarou.FormOrder, 6) end
function WTAGarou.HUD.buttonsHeight()
    local L = WTAGarou.HUD.LAYOUT
    return WTAGarou.HUD.buttonRows() * (L.BTN_H + L.GAP) - L.GAP
end
-- Panel height that shows `lines` log lines.
function WTAGarou.HUD.heightFor(lines, titleH)
    local L = WTAGarou.HUD.LAYOUT
    return (titleH or WTAGarou.HUD.TITLE_H) + L.ROW_Y_OFFSET + WTAGarou.HUD.buttonsHeight()
        + L.LOG_PAD + math.max(0, lines or 0) * WTAGarou.HUD.LINE_H + L.BOTTOM
end
-- Whole log lines that fit a panel of `height`.
function WTAGarou.HUD.linesFor(height, titleH)
    return math.max(0, math.floor((height - WTAGarou.HUD.heightFor(0, titleH)) / WTAGarou.HUD.LINE_H))
end
-- Column geometry for a panel `width`: leftX, columnWidth, rightX.
function WTAGarou.HUD.columns(width)
    local L = WTAGarou.HUD.LAYOUT
    local colW = math.floor((width - 2 * L.PAD - L.COL_GAP) / 2)
    return L.PAD, colW, L.PAD + colW + L.COL_GAP
end
local HEIGHT = WTAGarou.HUD.heightFor(WTAGarou.HUD.NOTICE_LINES)   -- default height
WTAGarou.HUD.DEFAULT_HEIGHT = HEIGHT
function WTAGarou.HUD.minHeight() return WTAGarou.HUD.heightFor(WTAGarou.HUD.MIN_LOG_LINES) end
local LAYOUT_KEY = "WTAGarouHUDLayout"
local LAYOUT_VERSION = 3   -- 3: carries the size

local function screenSize(player)
    if player and player.getPlayerNum and getPlayerScreenWidth and getPlayerScreenHeight then
        local n=player:getPlayerNum()
        return getPlayerScreenWidth(n), getPlayerScreenHeight(n),
            getPlayerScreenLeft(n), getPlayerScreenTop(n)
    end
    local core = getCore()
    return core:getScreenWidth(), core:getScreenHeight(), 0, 0
end

function WTAGarou.HUD.defaultPosition(player)
    local width,_,left,top = screenSize(player)
    return left+math.max(0, math.min(math.floor(width / 12) - 16, width - WIDTH)), top
end

local function savedLayout(player)
    player=player or WTAGarou.PrimaryLocalPlayer()
    return player and player:getModData()[LAYOUT_KEY] or nil
end

local function initialPosition(player)
    local width, height, left, top = screenSize(player)
    local saved = savedLayout(player)
    if type(saved) ~= "table" or not tonumber(saved.x) or not tonumber(saved.y) then
        return WTAGarou.HUD.defaultPosition(player)
    end
    -- Move only an unversioned layout exactly at the previous default.
    -- Other saved placements belong to the user and must not be reset.
    local oldDefault = math.max(0, math.min(math.floor(width / 12), width - WIDTH))
    if saved.version == nil and tonumber(saved.x) == oldDefault
            and tonumber(saved.y) == 0 then
        return WTAGarou.HUD.defaultPosition(player)
    end
    local w, h = WTAGarou.HUD.savedSize(player)
    return math.max(left, math.min(tonumber(saved.x), left+width - w)),
        math.max(top, math.min(tonumber(saved.y), top+height - h))
end

-- The saved panel size, clamped to the minimums and the screen; the
-- defaults when nothing (or an older layout) is saved.
function WTAGarou.HUD.savedSize(player)
    local width, height = screenSize(player)
    local saved = savedLayout(player)
    local w = (type(saved) == "table" and tonumber(saved.w)) or WIDTH
    local h = (type(saved) == "table" and tonumber(saved.h)) or HEIGHT
    w = math.max(WTAGarou.HUD.MIN_WIDTH, math.min(w, width))
    h = math.max(WTAGarou.HUD.minHeight(), math.min(h, height))
    return math.floor(w), math.floor(h)
end

-- A form must never be required to define a color for its Rage text to draw.
-- Neutral gray at zero, increasingly saturated red toward 100.
-- 0.4.69 Rage meter markers.
--  * Baseline bracket: a cream-yellow line inside the bottom edge of the
--    meter, centred on the baseline, half width = the server's current
--    bracket (d.bracketHalfWidth, Rage points); drift is halved inside it.
--    0.4.79 (user request): 2 px thick (half the old 4) with a 3 px wide
--    tick rising 4 px above the line at either end: a down-bracket shape.
--  * Baseline centre: a small yellow triangle pointing up, sitting on that line.
--  * Direction: sideways triangles on both sides of the current-value edge
--    pointing the way Rage moved, fading out over TREND_HOLD_MS after the
--    last change; the title shows a small up/down triangle meanwhile.
WTAGarou.HUD.TREND_HOLD_MS  = 1000   -- marker lifetime after the last observed change
WTAGarou.HUD.TREND_PULSE_MS = 1000   -- while Rage keeps moving: full -> clear, repeating
-- Smallest movement that counts as a direction. Rage parked on the baseline
-- is pushed off it and pulled back every tick, and the two float sums do
-- not cancel exactly (49.999999 / 50.000001), which read as a real
-- down/up flip every half second (Oct 18 playtest). Movement accumulates
-- from the last counted value, so a slow drift still registers.
WTAGarou.HUD.TREND_DEADBAND = 0.05
WTAGarou.HUD.BRACKET_RGB  = { 1.0, 0.95, 0.75 }   -- cream yellow
WTAGarou.HUD.MARKER_RGB   = { 1.0, 0.85, 0.20 }   -- yellow
WTAGarou.HUD.BAR = { x = 8, y = 22, h = 14 }      -- relative to the title bar bottom

function WTAGarou.HUD.nowMs()
    if getTimestampMs then return getTimestampMs() end
    return math.floor(os.clock() * 1000)
end

-- Records a movement of the displayed Rage value; returns the direction
-- (-1, 0, 1) and the marker alpha for `nowMs`. A run of changes in one
-- direction shares one pulse clock (started at the first change, or when
-- the direction flips), so a constant drift pulses full -> clear every
-- TREND_PULSE_MS instead of sitting solid; the last pulse also fades out
-- with the hold so it never cuts off mid-alpha.
function WTAGarou.HUD.trackTrend(state, rage, nowMs)
    rage = tonumber(rage) or 0
    local last = state.trendRage
    if last == nil then state.trendRage = rage end
    if last ~= nil and math.abs(rage - last) + 1e-9 >= (WTAGarou.HUD.TREND_DEADBAND or 0) then
        state.trendRage = rage
        local dir = rage > last and 1 or -1
        local running = state.trendAt ~= nil and (nowMs - state.trendAt) < WTAGarou.HUD.TREND_HOLD_MS
        if not running or dir ~= state.trendDir then state.pulseStart = nowMs end
        state.trendDir = dir
        state.trendAt  = nowMs
    end
    return WTAGarou.HUD.trendState(state, nowMs)
end

function WTAGarou.HUD.trendState(state, nowMs)
    local dir, at = state.trendDir or 0, state.trendAt
    if dir == 0 or at == nil then return 0, 0 end
    local age = nowMs - at
    local hold = WTAGarou.HUD.TREND_HOLD_MS
    if age < 0 or age >= hold then return 0, 0 end
    local period = WTAGarou.HUD.TREND_PULSE_MS
    local phase = (nowMs - (state.pulseStart or at)) % period
    return dir, math.min(1 - phase / period, 1 - age / hold)
end

-- Pixel geometry for the markers (pure, so the tests can pin it).
--  bar: { x, w, y, h }; values in Rage points on a 0..max scale.
-- Everything is snapped to whole pixels around one centre column: the
-- fill ends at the exact (fractional) baseline x, the triangle apex sits
-- in the first pixel column at or right of it, and the line extends the
-- same whole number of pixels either side of that column (a fractional
-- rect edge rasterises a pixel short on one side, which read as the line
-- sitting left of the triangle in the Oct 18 playtest).
function WTAGarou.HUD.bracketGeometry(bar, baseline, halfWidth, max)
    max = math.max(1, tonumber(max) or 100)
    local cx = bar.x + bar.w * math.max(0, math.min(1, (tonumber(baseline) or 0) / max))
    local col = math.min(bar.x + bar.w - 1, math.floor(cx))
    local hw = math.floor(bar.w * math.max(0, tonumber(halfWidth) or 0) / max + 0.5)
    local left  = math.max(bar.x, col - hw)
    local right = math.min(bar.x + bar.w, col + hw + 1)   -- exclusive
    if hw <= 0 then right = left end
    local lineH, tickW, tickRise = 2, 3, 4
    return { lineX = left, lineW = right - left, lineY = bar.y + bar.h - lineH, lineH = lineH,
             tickW = tickW, tickH = lineH + tickRise, tickY = bar.y + bar.h - lineH - tickRise,
             centreX = col, topY = bar.y, apexY = bar.y + bar.h - 3,
             stemY = bar.y + 3, stemH = math.max(0, bar.h - 6) }
end

-- 0.4.71 baseline symbol (author's drawing, Oct 18): a small triangle
-- pointing in from the TOP edge of the meter, one pointing in from the
-- BOTTOM edge, and a 1 px vertical line joining them, all on the baseline
-- column. Each triangle is 3 rows (widths 5,3,1 / 1,3,5); the stem fills
-- the rows between. 7 draw calls.
function WTAGarouHUD:drawBaselineSymbol(g, r, gg, b, a)
    local cx = g.centreX
    for i = 0, 2 do                                   -- top: points down
        local w = 5 - 2 * i
        self:drawRect(cx - (2 - i), g.topY + i, w, 1, a, r, gg, b)
    end
    if g.stemH > 0 then
        self:drawRect(cx, g.stemY, 1, g.stemH, a, r, gg, b)
    end
    for i = 0, 2 do                                   -- bottom: points up
        local w = 1 + 2 * i
        self:drawRect(cx - i, g.apexY + i, w, 1, a, r, gg, b)
    end
end

-- Sideways triangle: 5 columns, heights 9,7,5,3,1 away from `x` in `dir`.
-- Columns outside [clipX0, clipX1) are not drawn (masked to the meter).
function WTAGarouHUD:drawSideTriangle(x, midY, dir, r, g, b, a, clipX0, clipX1)
    for i = 0, 4 do
        local h = 9 - 2 * i
        local px = x + dir * i
        if not clipX0 or (px >= clipX0 and px < clipX1) then
            self:drawRect(px, midY - (4 - i), 1, h, a, r, g, b)
        end
    end
end

-- Direction arrow placement: { x, dir } for the single arrow, or nil when
-- no column of it is inside the bar. Rising: a right-pointing arrow whose
-- base starts 2 px right of the fill edge; falling: a left-pointing arrow
-- whose base starts 2 px left of it. Only the side Rage is moving toward
-- gets an arrow, and only the part inside the meter is drawn.
function WTAGarou.HUD.arrowPlacement(bar, rage, rageMax, dir)
    if dir == 0 then return nil end
    local edge = bar.x + bar.w * math.max(0, math.min(1, (tonumber(rage) or 0) / math.max(1, rageMax or 100)))
    local x = dir > 0 and (math.floor(edge) + 2) or (math.floor(edge) - 3)
    local lo, hi = math.min(x, x + dir * 4), math.max(x, x + dir * 4)
    if hi < bar.x or lo >= bar.x + bar.w then return nil end
    return { x = x, dir = dir }
end

function WTAGarouHUD:drawRageMarkers(d, bar, rage, rageMax)
    local B, M = WTAGarou.HUD.BRACKET_RGB, WTAGarou.HUD.MARKER_RGB
    local baseline = WTAGarou.BaselineRage and WTAGarou.BaselineRage(d) or nil
    if baseline then
        local g = WTAGarou.HUD.bracketGeometry(bar, baseline, d.bracketHalfWidth, rageMax)
        if g.lineW > 0 then
            self:drawRect(g.lineX, g.lineY, g.lineW, g.lineH, 0.9, B[1], B[2], B[3])
            if g.lineW >= 2 * g.tickW then   -- the bracket's ends
                self:drawRect(g.lineX, g.tickY, g.tickW, g.tickH, 0.9, B[1], B[2], B[3])
                self:drawRect(g.lineX + g.lineW - g.tickW, g.tickY, g.tickW, g.tickH, 0.9, B[1], B[2], B[3])
            end
        end
        self:drawBaselineSymbol(g, M[1], M[2], M[3], 1)
    end
    local dir, alpha = WTAGarou.HUD.trackTrend(self, rage, WTAGarou.HUD.nowMs())
    if dir ~= 0 and alpha > 0 then
        local a = WTAGarou.HUD.arrowPlacement(bar, rage, rageMax, dir)
        if a then
            local mid = bar.y + math.floor(bar.h / 2)
            self:drawSideTriangle(a.x, mid, a.dir, M[1], M[2], M[3], alpha, bar.x, bar.x + bar.w)
        end
    end
    return dir
end

function WTAGarou.HUD.rageColor(ratio)
    ratio = math.max(0, math.min(1, tonumber(ratio) or 0))
    return 0.45 + 0.55 * ratio, 0.45 * (1 - ratio), 0.45 * (1 - ratio)
end

local KEYBIND_CATEGORY = "[WTAGarou]"
-- New binding id intentionally does not inherit the old saved G/alternate
-- shortcut. Keep the option, but start unbound for existing profiles too.
local KEYBIND_TOGGLE   = "WTAGarou_ToggleRagePanel"
-- 0.4.21: unbound by default (Keyboard.KEY_NONE = 0); set them under
-- Options > Key Bindings > [WTAGarou].
local KEYBIND_RESIST   = "WTAGarou_Resist"
local KEYBIND_STRIP    = "WTAGarou_Strip"
local KEYBIND_DRESS    = "WTAGarou_Dress"
WTAGarou.HUD.KEYBINDS = { TOGGLE = KEYBIND_TOGGLE, RESIST = KEYBIND_RESIST, STRIP = KEYBIND_STRIP, DRESS = KEYBIND_DRESS }

local DENIAL_TEXT = {
    invalid_form         = "That is not a form.",
    already_in_form      = "You are already in that form.",
    cooldown             = "Your body is still settling.",
    not_enough_rage      = "Not enough Rage.",
    not_enough_rage_howl = "Not enough Rage to howl.",
    not_a_garou          = "You are not a werewolf.",
    no_reservation       = "The change slipped away from you.",
    reservation_expired  = "You held the change too long.",
    shift_interrupted    = "The change broke apart.",
    frenzy_forced        = "The Rage takes you!",
    rage_depleted        = "The Rage is spent. Your true form returns.",
    crinos_locked        = "The Rage will not let you go yet.",
    vehicle_blocked      = "You do not fit in there.",
    -- 0.4.58 paw guard (Hispo/Lupus)
    paws_firearm         = "No thumbs. Paws cannot work a firearm. Shift to Homid.",
    paws_craft           = "Paws cannot craft or build. Shift to Homid for that.",
    paws_mechanic        = "Paws cannot do mechanics. Shift to Homid for that.",
    silver_mixed_load    = "Unload the ordinary rounds first.",
    silver_no_rounds     = "No matching silver rounds.",
    silver_worn_off      = "The silver has worn off your weapon.",
}
WTAGarou.HUD.DENIAL_TEXT = DENIAL_TEXT

-- Rich-text tooltip. Leads with the lore name (Homid, Glabro ...) as the
-- emphasised opener -- vanilla rich text has no bold tag, so emphasis is a
-- warm highlight colour at the SAME size -- then the description and the
-- Rage line. No <SIZE:...> anywhere: ISToolTip measures every line with its
-- default font, so any larger face overflows the box (the 0.4.12-0.4.14
-- Crinos tooltip did exactly that).
-- Strip tooltip: what a shift would do to worn clothes, per form.
function WTAGarou.HUD.stripTooltip()
    local SS = WTAGarou.ShiftStrip or {}
    local function pts(f) return SS.damageFor and SS.damageFor(f) or 0 end
    return "Unequip every worn item a beast shift would tear off, one normal unequip per piece; "
        .. "nothing is damaged. Bags, jewellery, belts and held items always stay. <LINE> "
        .. WTAGarou.Rich.lead("Shifting instead:", "rage")
        .. string.format("%s keeps everything on, undamaged; ", WTAGarou.DisplayName("Glabro"))
        .. string.format("%s -%d, %s -%d, %s -%d, all dropped. ", WTAGarou.DisplayName("Lupus"), pts("Lupus"),
            WTAGarou.DisplayName("Hispo"), pts("Hispo"), WTAGarou.DisplayName("Crinos"), pts("Crinos"))
        .. "Hats and masks drop undamaged. Dress puts the same pieces back on."
end

WTAGarou.HUD.TOOLTIP_LORE_RGB = "<RGB:1,0.85,0.45>"
WTAGarou.HUD.TOOLTIP_BODY_RGB = "<RGB:1,1,1>"
WTAGarou.HUD.TOOLTIP_RAGE_RGB = "<RGB:1,0.8,0.35>"

-- Howl (0.4.45): names the baseline the howl settles on.
function WTAGarou.HUD.howlTooltip(data)
    if data == nil and getPlayer and WTAGarou.GetData then
        local ok, d = pcall(function() return WTAGarou.GetData(getPlayer()) end)
        if ok then data = d end
    end
    local base = WTAGarou.BaselineRage and WTAGarou.BaselineRage(data) or 50
    local R = WTAGarou.Rich
    return R.lead("Howl", "action") .. "Pulls Rage toward your baseline of" .. R.kw(tostring(base) .. ".", "rage")
        .. "Hold still while you howl; moving or Esc stops it."
end

function WTAGarou.HUD.formTooltip(formName, data)
    local fd = WTAGarou.GetForm(formName) or {}
    local cost = tonumber(fd.rageCost) or 0
    if data == nil and getPlayer and WTAGarou.GetData then
        local ok, d = pcall(function() return WTAGarou.GetData(getPlayer()) end)
        if ok then data = d end
    end
    local need = WTAGarou.RageRequired and WTAGarou.RageRequired(formName, data) or cost
    local rageLine
    if cost <= 0 and need <= 0 then
        rageLine = "Rage cost: none"
    elseif need > cost then
        rageLine = string.format("Rage cost: %d (requires %d)", cost, need)
    else
        rageLine = string.format("Rage cost: %d", cost)
    end
    local extra = ""
    if formName == "Crinos" then
        -- 0.4.39: breed-aware. Berserkers burn half as fast, revert to
        -- Near-Human and are locked in above 55 Rage (others above 75; 0.4.58).
        local drain = WTAGarou.CrinosDrainPerSecond and -WTAGarou.CrinosDrainPerSecond(data) or 1
        local lock = WTAGarou.CrinosLockAbove and WTAGarou.CrinosLockAbove(data) or 75
        local home = WTAGarou.DisplayName(WTAGarou.BaseForm and WTAGarou.BaseForm(data) or "Homid")
        -- 0.4.69: the burn grows by 1/s for every 90 s the form is held; the
        -- live value arrives from the server (CrinosDrain) while in Crinos.
        local live = data.form == "Crinos" and data.crinosDrainPerSecond and -data.crinosDrainPerSecond or nil
        local burn = live and live > drain and string.format("%s Rage/s (now %s)", tostring(drain), tostring(live)) or (tostring(drain) .. " Rage/s")
        extra = " <LINE> <RGB:0.6,1,0.6> Reduces wyrm infection."
            .. string.format(" <LINE> <RGB:1,0.6,0.6> Burns %s, +1/s every 90 s held; forced back to %s at 0.",
                burn, home)
            .. string.format(" <LINE> <RGB:1,0.6,0.6> Cannot shift out above %d Rage.", lock)
    end
    if WTAGarou.IsBulkForm and WTAGarou.IsBulkForm(formName) then
        extra = extra .. " <LINE> <RGB:1,0.6,0.6> Too big for vehicles; smashes open windows when climbing through."
    end
    -- 0.4.45: the lore name opens the tooltip through WTAGarou.Rich so the gap
    -- after it survives ("Homid Human form", not "HomidHuman form").
    return WTAGarou.Rich.lead(tostring(formName), "lore")
        .. tostring(fd.description or formName)
        .. " <LINE> " .. WTAGarou.Rich.COLORS.rage .. " " .. rageLine .. extra
end

function WTAGarouHUD:new(x, y, player, w, h)
    local o = ISCollapsableWindow.new(self, x, y, w or WIDTH, h or HEIGHT)
    o.player=player or WTAGarou.PrimaryLocalPlayer()
    o.backgroundColor = { r=0, g=0, b=0, a=0.65 }
    o.borderColor     = { r=0.35, g=0.35, b=0.35, a=0.9 }
    o.resizable       = true                    -- 0.4.79: corner + bottom-edge handles
    o.minimumWidth    = WTAGarou.HUD.MIN_WIDTH
    o.minimumHeight   = WTAGarou.HUD.minHeight()
    o.drawFrame       = true
    o.debugLine       = nil
    o.debugUntil      = 0
    o.channelForm     = nil
    o.channelTicks    = 0
    o:setTitle("Rage")
    return o
end

function WTAGarouHUD:createChildren()
    ISCollapsableWindow.createChildren(self)

    local L     = WTAGarou.HUD.LAYOUT
    local btnH  = L.BTN_H

    -- LEFT column: one form per row, wide enough for "Near-Human".
    self.transformButtons = {}
    for _, formName in ipairs(WTAGarou.FormOrder) do
        local b = ISButton:new(0, 0, 100, btnH, WTAGarou.DisplayName(formName),
            self, function() WTAGarou.RequestTransform(formName, self.player) end)
        b:initialise()
        b:setTooltip(WTAGarou.HUD.formTooltip(formName, WTAGarou.GetData(self.player)))
        if formName == "Crinos" then
            -- 0.4.16: the Berzerker button wears a blood-red border
            b.borderColor = { r = 0.85, g = 0.12, b = 0.12, a = 1 }
        end
        self:addChild(b)
        self.transformButtons[formName] = b
    end

    -- RIGHT column: Strip, Dress, Howl, Resist, Guide, Startup.
    -- Strip: channelled vanilla unequip of everything a beast shift would
    -- tear off, so the clothes survive.
    self.stripBtn = ISButton:new(0, 0, 100, btnH, "Strip",
        self, function() if WTAGarou.RequestStrip then WTAGarou.RequestStrip(self.player) end end)
    self.stripBtn:initialise()
    self.stripBtn:setTooltip(WTAGarou.HUD.stripTooltip())
    self:addChild(self.stripBtn)

    -- Dress (0.4.16): put back on the exact items Strip removed or a shift
    -- tore off, from the inventory, any bag, or the floor nearby (0.4.17).
    self.dressBtn = ISButton:new(0, 0, 100, btnH, "Dress",
        self, function() if WTAGarou.RequestDress then WTAGarou.RequestDress(self.player) end end)
    self.dressBtn:initialise()
    self.dressBtn:setTooltip(WTAGarou.HUD.dressTooltip(nil))
    self:addChild(self.dressBtn)

    self.howlBtn = ISButton:new(0, 0, 100, btnH, "Howl",
        self, function() WTAGarou.RequestHowl(self.player) end)
    self.howlBtn:initialise()
    self.howlBtn:setTooltip(WTAGarou.HUD.howlTooltip(WTAGarou.GetData(self.player)))
    self:addChild(self.howlBtn)

    -- Resist (0.4.21): cancel the forced-Crinos countdown. Only useful
    -- while the countdown runs; the label turns into the remaining time.
    self.resistBtn = ISButton:new(0, 0, 100, btnH, "Resist",
        self, function() if WTAGarou.RequestResist then WTAGarou.RequestResist(self.player) end end)
    self.resistBtn:initialise()
    self.resistBtn:setTooltip("Resist the change <LINE> Stops the Berzerker countdown. Every Resist makes the next "
        .. "countdown shorter (one second at a time, then ever smaller steps toward half a second) and the "
        .. "urge returns after a hidden while as long as Rage stays over 95. Bind a key under Options > Key Bindings > [Werewolf].")
    self:addChild(self.resistBtn)

    -- Guide (0.4.18): reopen the paged Werewolf Guide at any time.
    self.guideBtn = ISButton:new(0, 0, 100, btnH, "Guide",
        self, function() if WTAGarou.Tutorial and WTAGarou.Tutorial.open then WTAGarou.Tutorial.open() end end)
    self.guideBtn:initialise()
    self.guideBtn:setTooltip(WTAGarou.Rich.lead("Werewolf Guide", "action")
        .. "How forms, Rage, clothes, wounds and the Wyrm Infection work.")
    self:addChild(self.guideBtn)

    -- Startup (0.4.45): the Werewolf Startup panel (true form, coat,
    -- baseline Rage, wolf gear) moved here from the world context menu.
    self.startupBtn = ISButton:new(0, 0, 100, btnH,
        (WTAGarou.WolfCoat and WTAGarou.WolfCoat.REOPEN_BUTTON) or "Startup",
        self, function() if WTAGarou.WolfCoat and WTAGarou.WolfCoat.toggle then WTAGarou.WolfCoat.toggle(self.player) end end)
    self.startupBtn:initialise()
    self.startupBtn:setTooltip(WTAGarou.Rich.lead("Werewolf Startup", "action")
        .. "True form, coat and baseline Rage (locked once confirmed), and the wolf gear colour.")
    self:addChild(self.startupBtn)
    self.rightButtons = { self.stripBtn, self.dressBtn, self.howlBtn, self.resistBtn, self.guideBtn, self.startupBtn }

    self.notices = {}
    self:layout()
end

-- 0.4.79: place the buttons for the current size and start the log under
-- them. Called from createChildren and after every resize.
local function placeButton(b, x, y, w)
    if not b then return end
    b.x, b.y, b.width = x, y, w            -- plain fields (headless tests)
    if b.setX then b:setX(x) end
    if b.setY then b:setY(y) end
    if b.setWidth then b:setWidth(w) end
end

function WTAGarouHUD:layout()
    local L = WTAGarou.HUD.LAYOUT
    local w = self.width or WIDTH
    local top = self:titleBarHeight()
    local leftX, colW, rightX = WTAGarou.HUD.columns(w)
    local rowY = top + L.ROW_Y_OFFSET
    local function rowAt(row) return rowY + row * (L.BTN_H + L.GAP) end
    for i, formName in ipairs(WTAGarou.FormOrder) do
        placeButton((self.transformButtons or {})[formName], leftX, rowAt(i - 1), colW)
    end
    for i, b in ipairs(self.rightButtons or {}) do
        placeButton(b, rightX, rowAt(i - 1), colW)
    end
    self.noticeY = rowY + WTAGarou.HUD.buttonsHeight() + L.LOG_PAD
    self:rewrap()
end

-- The engine calls this (through ISUIElement) after setWidth/setHeight,
-- including the vanilla resize handles.
function WTAGarouHUD:onResize()
    if ISCollapsableWindow.onResize then ISCollapsableWindow.onResize(self) end
    self:layout()
    self:scrollLog(0)        -- keep the view inside the new window
    self:saveLayout()
end

-- The log under the buttons (0.4.78, user request October 19: "retool the
-- notices of the garou panel to be more like a log"; the 0.4.22 six-second
-- notices overlapped or were gone before they could be read). Every message
-- is time-stamped, word-wrapped to the panel width and KEPT (LOG_MAX
-- entries); the newest sits at the bottom, the mouse wheel over the log
-- scrolls back through it, and a new message while scrolled up does not
-- yank the view (a scroll-to-bottom icon shows instead, lit while unread
-- entries wait). Fresh entries are drawn bright for NOTICE_SECONDS, then
-- dim. The lines in view follow the panel height (0.4.79): NOTICE_LINES at
-- the default size.
WTAGarou.HUD.NOTICE_SECONDS     = 6      -- highlight time for a fresh entry
WTAGarou.HUD.NOTICE_MIN_SECONDS = 4
WTAGarou.HUD.SCROLLBAR_W        = 6      -- kept free at the right of the log
WTAGarou.HUD.NOTICE_WIDTH       = WIDTH - 16 - WTAGarou.HUD.SCROLLBAR_W   -- at the default width
WTAGarou.HUD.LOG_MAX            = 200    -- entries kept
WTAGarou.HUD.LOG_WHEEL_LINES    = 3
WTAGarou.HUD.NOTICE_REPEAT_GAP  = 2      -- the same text again within 2 s is not logged twice
WTAGarou.HUD.JUMP_ICON          = { w = 14, h = 14 }   -- scroll-to-bottom button

-- Pure word wrap. `measure(str)` returns the pixel width of `str`; a word
-- longer than the width gets its own line rather than being cut.
function WTAGarou.HUD.wrapText(text, maxWidth, measure)
    local lines, current = {}, nil
    for word in tostring(text):gmatch("%S+") do
        local candidate = current and (current .. " " .. word) or word
        if current and measure(candidate) > maxWidth then
            lines[#lines + 1] = current
            current = word
        else
            current = candidate
        end
    end
    if current then lines[#lines + 1] = current end
    if #lines == 0 then lines[1] = "" end
    return lines
end

local function measureSmall(str)
    local ok, w = pcall(function() return getTextManager():MeasureStringX(UIFont.Small, str) end)
    if ok and type(w) == "number" then return w end
    return #str * 6   -- headless fallback (tests)
end

-- "14:07" in game time when the clock is up, otherwise nothing.
function WTAGarou.HUD.stamp()
    local ok, text = pcall(function()
        local gt = getGameTime and getGameTime() or nil
        if not gt then return nil end
        local t = gt:getTimeOfDay()
        local h = math.floor(t); local m = math.floor((t - h) * 60)
        return string.format("%02d:%02d", h, m)
    end)
    if ok and text then return text end
    return nil
end

-- Pure: the window of `total` lines shown with `scroll` lines held back
-- from the bottom; returns first and last line index (1-based).
function WTAGarou.HUD.logWindow(total, view, scroll)
    if total <= view then return 1, total end
    scroll = math.max(0, math.min(scroll or 0, total - view))
    local last = total - scroll
    return last - view + 1, last
end

-- Text width available to a log line at the current panel width.
function WTAGarouHUD:noticeWidth()
    return (self.width or WIDTH) - 2 * WTAGarou.HUD.LAYOUT.PAD - WTAGarou.HUD.SCROLLBAR_W
end

-- Re-wrap every entry (after a resize).
function WTAGarouHUD:rewrap()
    local H = WTAGarou.HUD
    local stampW = measureSmall("00:00 ")
    for _, n in ipairs(self.notices or {}) do
        n.lines = H.wrapText(n.text, self:noticeWidth() - stampW, measureSmall)
    end
end

function WTAGarouHUD:pushNotice(text)
    self.notices = self.notices or {}
    local H = WTAGarou.HUD
    local now = getTimestamp()
    local body = tostring(text)
    -- The same line twice in quick succession (a denial repeated by a held
    -- key, a burn reported by two paths) is one entry.
    local lastN = self.notices[#self.notices]
    if lastN and lastN.text == body and now - (lastN.shownAt or 0) < H.NOTICE_REPEAT_GAP then
        return false
    end
    local stamp = H.stamp()
    local lines = H.wrapText(body, self:noticeWidth() - measureSmall("00:00 "), measureSmall)
    self.notices[#self.notices + 1] = {
        text = body, lines = lines, shownAt = now, stamp = stamp,
        until_ = now + math.max(H.NOTICE_SECONDS, H.NOTICE_MIN_SECONDS),
    }
    local dropped = 0
    while #self.notices > H.LOG_MAX do table.remove(self.notices, 1); dropped = dropped + 1 end
    -- Reading back through the log: hold the view where it is.
    if (self.logScroll or 0) > 0 then
        self.logScroll = math.max(0, self.logScroll + #lines - dropped)
        self.logUnread = (self.logUnread or 0) + 1
    end
    return true
end

-- Log lines that fit the log area at the current height.
function WTAGarouHUD:viewLines()
    local y0, y1 = self:logArea()
    return math.max(1, math.floor((y1 - y0) / WTAGarou.HUD.LINE_H))
end

-- Nothing expires any more; kept for callers.
function WTAGarouHUD:promoteNotices() end

-- All wrapped lines of the log, oldest first, as { text, fresh, stamp }.
function WTAGarouHUD:logLines()
    local now = getTimestamp()
    local out = {}
    for _, n in ipairs(self.notices or {}) do
        for i, line in ipairs(n.lines) do
            out[#out + 1] = { text = line, fresh = now < n.until_, stamp = (i == 1) and n.stamp or nil }
        end
    end
    return out
end

-- The wrapped lines currently in view, oldest first (strings).
function WTAGarouHUD:liveNotices()
    local all = self:logLines()
    local first, last = WTAGarou.HUD.logWindow(#all, self:viewLines(), self.logScroll or 0)
    local out = {}
    for i = first, last do out[#out + 1] = all[i].text end
    return out
end

function WTAGarouHUD:scrollLog(lines)
    local total = #self:logLines()
    local maxScroll = math.max(0, total - self:viewLines())
    self.logScroll = math.max(0, math.min(maxScroll, (self.logScroll or 0) + lines))
    if self.logScroll == 0 then self.logUnread = nil end
    return self.logScroll
end

function WTAGarouHUD:scrollToBottom()
    self.logScroll = 0; self.logUnread = nil
end

function WTAGarouHUD:logArea()
    local y0 = self.noticeY or 0
    return y0, (self.height or HEIGHT) - WTAGarou.HUD.LAYOUT.BOTTOM
end

-- The scroll-to-bottom icon: bottom-right of the log, left of the scroll
-- bar. Returns x, y, w, h (panel coordinates).
function WTAGarouHUD:jumpIconRect()
    local I = WTAGarou.HUD.JUMP_ICON
    local _, y1 = self:logArea()
    return (self.width or WIDTH) - 10 - 4 - I.w, y1 - I.h - 2, I.w, I.h
end

function WTAGarouHUD:jumpIconHit(x, y)
    if (self.logScroll or 0) <= 0 then return false end
    local ix, iy, iw, ih = self:jumpIconRect()
    return x >= ix and x < ix + iw and y >= iy and y < iy + ih
end

-- Rows of the icon, relative to its top-left: a 1 px stem, a down-pointing
-- triangle (7,5,3,1) and a 7 px base line, centred. Rectangles, not a
-- glyph: the UI fonts lack the arrow code points.
function WTAGarou.HUD.jumpIconRows()
    local I = WTAGarou.HUD.JUMP_ICON
    local cx = math.floor(I.w / 2)
    local rows = { { dx = cx, dy = 2, w = 1 }, { dx = cx, dy = 3, w = 1 } }
    for i = 0, 3 do
        local w = 7 - 2 * i
        rows[#rows + 1] = { dx = cx - math.floor(w / 2), dy = 4 + i, w = w }
    end
    rows[#rows + 1] = { dx = cx - 3, dy = I.h - 3, w = 7 }
    return rows
end

function WTAGarouHUD:drawJumpIcon()
    if (self.logScroll or 0) <= 0 then return false end
    local x, y, w, h = self:jumpIconRect()
    local hot = (self.logUnread or 0) > 0
    self:drawRect(x, y, w, h, 0.8, 0.12, 0.12, 0.12)
    local r, g, b = 0.8, 0.8, 0.8
    if hot then r, g, b = 1, 0.85, 0.2 end
    for _, row in ipairs(WTAGarou.HUD.jumpIconRows()) do
        self:drawRect(x + row.dx, y + row.dy, row.w, 1, 1, r, g, b)
    end
    return true
end

-- A click on the icon jumps to the newest line; anything else is the
-- window's (title-bar drag, buttons).
function WTAGarouHUD:onMouseDown(x, y)
    if self:jumpIconHit(x, y) then
        self:scrollToBottom()
        return true
    end
    if ISCollapsableWindow.onMouseDown then return ISCollapsableWindow.onMouseDown(self, x, y) end
    return false
end

-- Mouse wheel over the log scrolls it (del > 0 = wheel down = newer).
function WTAGarouHUD:onMouseWheel(del)
    local my = self.getMouseY and self:getMouseY() or nil
    local y0, y1 = self:logArea()
    if my ~= nil and (my < y0 or my > y1) then return false end
    self:scrollLog((del > 0) and -WTAGarou.HUD.LOG_WHEEL_LINES or WTAGarou.HUD.LOG_WHEEL_LINES)
    return true
end

function WTAGarouHUD:clearLog()
    self.notices = {}; self.logScroll = 0; self.logUnread = nil
end

function WTAGarouHUD:drawLog()
    local H = WTAGarou.HUD
    local all = self:logLines()
    local y0, y1 = self:logArea()
    local view = self:viewLines()
    local first, last = H.logWindow(#all, view, self.logScroll or 0)
    local y = y0
    for i = first, last do
        local line = all[i]
        local x = 8
        if line.stamp then
            self:drawText(line.stamp, x, y, 0.55, 0.55, 0.55, 1, UIFont.Small)
            x = x + measureSmall(line.stamp .. " ")
        else
            x = x + measureSmall("00:00 ")
        end
        if line.fresh then
            self:drawText(line.text, x, y, 1, 0.75, 0.6, 1, UIFont.Small)
        else
            self:drawText(line.text, x, y, 0.72, 0.6, 0.5, 1, UIFont.Small)
        end
        y = y + H.LINE_H
    end
    -- scroll bar when the log overflows
    if #all > view and self.drawRect then
        local trackH = (y1 - y0)
        local thumbH = math.max(8, math.floor(trackH * view / #all))
        local maxScroll = #all - view
        local frac = 1 - ((self.logScroll or 0) / maxScroll)
        local thumbY = y0 + math.floor((trackH - thumbH) * frac)
        local barX = (self.width or WIDTH) - 10
        self:drawRect(barX, y0, 3, trackH, 0.25, 1, 1, 1)
        self:drawRect(barX, thumbY, 3, thumbH, 0.8, 1, 0.8, 0.65)
    end
    self:drawJumpIcon()
end

-- Dress tooltip: the wardrobe, one item per line, rebuilt as it changes.
function WTAGarou.HUD.dressTooltip(player)
    local names = (player and WTAGarou.Wardrobe and WTAGarou.Wardrobe.names)
        and WTAGarou.Wardrobe.names(player) or {}
    local head = "Put back on the exact clothes Strip removed or a shift tore off, "
        .. "from your inventory or any bag, one normal wear action per piece. "
        .. "Anything missing is listed in the panel and kept for next time."
    if #names == 0 then
        return head .. " <LINE> <RGB:0.7,0.7,0.7> Nothing remembered yet."
    end
    local lines = { head, " <LINE> " .. WTAGarou.HUD.TOOLTIP_RAGE_RGB .. " Remembered (" .. #names .. "):" }
    for i = #names, 1, -1 do   -- innermost first, the order Dress uses
        lines[#lines + 1] = " <LINE> <RGB:1,1,1> - " .. names[i]
    end
    return table.concat(lines)
end

function WTAGarouHUD:refresh()
    local player = self.player; if not player then return end
    local d = WTAGarou.GetData(player)
    local isGarou = WTAGarou.HasGarouTrait(player)
    local channelling = WTAGarou.IsChannelling and WTAGarou.IsChannelling(player)
    -- 0.4.39: tooltips depend on the breed, which arrives with RageSync.
    local tipKey = tostring(d.trueForm) .. "/" .. tostring(d.auspiceLocked == true and d.auspice or "-")
    for name, btn in pairs(self.transformButtons or {}) do
        -- Do not duplicate the server's Rage/cooldown validation with cached
        -- client data. This is deliberately identical to the radial's policy.
        btn.enable = isGarou and not player:isDead()
            and not channelling and d.form ~= name
        if self.tooltipBreed ~= tipKey and btn.setTooltip then
            btn:setTooltip(WTAGarou.HUD.formTooltip(name, d))
        end
    end
    if self.tooltipBreed ~= tipKey and self.howlBtn and self.howlBtn.setTooltip then
        self.howlBtn:setTooltip(WTAGarou.HUD.howlTooltip(d))
    end
    self.tooltipBreed = tipKey
    if self.howlBtn then
        self.howlBtn.enable = isGarou and not player:isDead() and not channelling
    end
    if self.startupBtn then
        self.startupBtn.enable = isGarou and not player:isDead()
    end
    if self.stripBtn then
        self.stripBtn.enable = isGarou and not player:isDead() and not channelling
    end
    if self.dressBtn then
        local W = WTAGarou.Wardrobe
        local now = getTimestamp()
        if W and (self.dressCheckedAt or 0) + 1 <= now then
            -- once a second: forget entries worn again, refresh the list
            self.dressCheckedAt = now
            W.prune(player)
            local tip = WTAGarou.HUD.dressTooltip(player)
            if tip ~= self.dressTip then
                self.dressTip = tip
                self.dressBtn:setTooltip(tip)
            end
        end
        self.dressBtn.enable = isGarou and not player:isDead() and not channelling
            and W ~= nil and W.count(player) > 0
    end
end

-- 0.4.79: denials are log entries (the status line is gone). The text is
-- still kept in `denialMsg` for anything that reads it.
function WTAGarouHUD:flashDenial(reason)
    self.denialMsg   = DENIAL_TEXT[tostring(reason)] or tostring(reason)
    self.denialUntil = getTimestamp() + 3
    self:pushNotice(self.denialMsg)
end

-- 0.4.41 put the silver warning on the status line; since 0.4.79 the
-- "Silver burns your <part>." log entry (WTAGarou.SilverReact) and the halo
-- over the head carry it, so this only records the part.
function WTAGarouHUD:flashSilverBurn(part)
    self.lastSilverBurnPart = tostring(part or "body")
end

function WTAGarouHUD:setDebugLine(text)
    self.debugLine  = tostring(text)
    self.debugUntil = getTimestamp() + 6
end

function WTAGarouHUD:startCrinosCountdown(seconds)
    self.crinosCountdownEnd = WTAGarou.NowSeconds() + (tonumber(seconds) or 10)
    self:refreshResistButton()
end

function WTAGarouHUD:clearCrinosCountdown()
    self.crinosCountdownEnd = nil
    self:refreshResistButton()
end

-- 0.4.21: "Resist" idle; "RESIST 1.4" while the countdown runs (called
-- from render every frame while a countdown is active).
function WTAGarouHUD:refreshResistButton()
    local b = self.resistBtn
    if not b then return end
    local remaining = self.crinosCountdownEnd and (self.crinosCountdownEnd - WTAGarou.NowSeconds()) or nil
    if remaining and remaining > 0 then
        b:setTitle(string.format("RESIST %.1f", remaining))
        if b.setBackgroundRGBA then b:setBackgroundRGBA(0.55, 0.05, 0.05, 0.9) end
    else
        b:setTitle("Resist")
        if b.setBackgroundRGBA then b:setBackgroundRGBA(0.0, 0.0, 0.0, 0.5) end
    end
end

function WTAGarouHUD:crinosCountdownText()
    if not self.crinosCountdownEnd then return nil end
    local player = self.player
    if player and WTAGarou.GetData(player).form == "Crinos" then
        self:clearCrinosCountdown()
        return nil
    end
    local remaining = self.crinosCountdownEnd - WTAGarou.NowSeconds()
    local name = WTAGarou.DisplayName("Crinos")
    if remaining <= 0 then return "Shifting to " .. name .. "..." end
    return string.format("Shifting to %s in %.1f", name, remaining)
end

-- 0.4.79: the "Changing to X..." line and its Esc hint are log entries.
function WTAGarou.HUD.channelText(formName)
    if formName == "Howl" then return "Howling... run or press Esc to stop." end
    return "Changing to " .. WTAGarou.DisplayName(formName) .. "... press Esc to stop."
end

function WTAGarouHUD:setChannelling(formName, ticks)
    self.channelForm  = formName
    self.channelTicks = ticks or 0
    self:pushNotice(WTAGarou.HUD.channelText(formName))
end

function WTAGarouHUD:clearChannelling()
    self.channelForm  = nil
    self.channelTicks = 0
end

function WTAGarouHUD:saveLayout()
    local player = self.player
    if not player then return end
    local md = player:getModData()
    local old = md[LAYOUT_KEY]
    local x, y, pinned = self:getX(), self:getY(), self.pin ~= false
    local w, h = self.width or WIDTH, self.height or HEIGHT
    if type(old) ~= "table" or old.x ~= x or old.y ~= y or old.pin ~= pinned
            or old.w ~= w or old.h ~= h or old.version ~= LAYOUT_VERSION then
        md[LAYOUT_KEY] = { x = x, y = y, w = w, h = h, pin = pinned, version = LAYOUT_VERSION }
    end
end

function WTAGarouHUD:prerender()
    local w,h,left,top=screenSize(self.player)
    self:setX(math.max(left,math.min(self:getX(),left+w-(self.width or WIDTH))))
    self:setY(math.max(top,math.min(self:getY(),top+h-(self.height or HEIGHT))))
    -- Vanilla titles are plain white. Suppress just that draw and paint our
    -- own compact counter; duplicate at +1px for bold weight at Small size.
    local title = self.title
    self.title = nil
    ISCollapsableWindow.prerender(self)
    self.title = title
    local player = self.player; if not player then return end
    -- Every vanilla panel leaves with the character; so does this one.
    if player:isDead() then
        if self.setVisible then self:setVisible(false) end
        return
    end
    self:saveLayout()
    self:refresh()
    local d    = WTAGarou.GetData(player)
    local top  = self:titleBarHeight()
    self:drawRageTitle(d)
    if self.isCollapsed then return end

    local panelW = self.width or WIDTH
    self:drawText(WTAGarou.DisplayName(d.form or "Homid"), 8, top + 4, 1, 1, 1, 1, UIFont.Small)
    -- 0.4.79: Infamy is a dormant mechanic (no effect yet); the figure is
    -- hidden until it does something. SHOW_INFAMY brings it back.
    if WTAGarou.HUD.SHOW_INFAMY then
        self:drawText(string.format("Infamy: %d/%d",
                math.floor(d.infamy or 0), WTAGarou.Infamy.MAX),
            panelW - 96, top + 4, 1, 0.7, 0.7, 1, UIFont.Small)
    end

    local rageMax = math.max(1, tonumber(WTAGarou.Rage.MAX) or 100)
    local rage = tonumber(d.rage) or 0
    local rageRatio = math.max(0, math.min(1, rage / rageMax))
    local red, green, blue = WTAGarou.HUD.rageColor(rageRatio)
    local BAR = WTAGarou.HUD.BAR
    local bar = { x = BAR.x, w = panelW - 2 * BAR.x, y = top + BAR.y, h = BAR.h }
    self:drawRect(bar.x, bar.y, bar.w, bar.h, 0.35, 0.15, 0.05, 0.9)
    self:drawRect(bar.x, bar.y, bar.w * rageRatio, bar.h,
        0.9, red, green, blue)
    self:drawRageMarkers(d, bar, rage, rageMax)   -- 0.4.69 bracket, baseline, direction
    self:drawText(string.format("Rage %d / %d", math.floor(rage), rageMax),
        12, top + 21, 1, 1, 1, 1, UIFont.Small)

    -- 0.4.79: no status line. The countdown lives on the Resist button and
    -- in the log; channelling, denials and the silver warning are log lines.
    if self.crinosCountdownEnd then
        self:refreshResistButton()
        self:crinosCountdownText()      -- clears itself once Crinos is confirmed
    end

    self:drawLog()

    if self.debugLine and getTimestamp() < (self.debugUntil or 0) then
        self:drawText(self.debugLine, 8, (self.height or HEIGHT) - 16, 0.6, 0.9, 0.6, 1, UIFont.Small)
    end
end

-- 0.4.69: "Rage: 45"; a small up/down triangle to the right of the value
-- shows the direction Rage moved in the last second, in the title colour,
-- fading with the meter arrows. Drawn as rectangles rather than the ▲▼ code
-- points: the UI fonts are AngelCode bitmap fonts and a glyph the font lacks
-- is skipped (or indexes past the glyph table), so the symbols are not safe.
WTAGarou.HUD.TITLE_MARKER = { gap = 5, w = 7, h = 4 }
function WTAGarou.HUD.titleState(data)
    local value = tonumber(data and data.rage) or 0
    return string.format("Rage: %d", math.floor(value)), value < 25 or value > 75
end

-- Rows for the title triangle: { dx, dy, w } relative to its top-left,
-- 4 rows of 7,5,3,1 px (up: wide row at the bottom; down: at the top).
function WTAGarou.HUD.titleMarkerRows(dir)
    local M, rows = WTAGarou.HUD.TITLE_MARKER, {}
    for i = 0, M.h - 1 do
        local w = M.w - 2 * i
        local dy = dir > 0 and (M.h - 1 - i) or i
        rows[#rows + 1] = { dx = i, dy = dy, w = w }
    end
    return rows
end

function WTAGarouHUD:drawRageTitle(data)
    local nowMs = WTAGarou.HUD.nowMs()
    local dir, alpha = WTAGarou.HUD.trendState(self, nowMs)
    if self.isCollapsed then
        -- the body (which normally tracks the value) is not drawn when collapsed
        dir, alpha = WTAGarou.HUD.trackTrend(self, data and data.rage, nowMs)
    end
    local text, danger = WTAGarou.HUD.titleState(data)
    local gb = danger and 0.2 or 1
    -- The normal Lua helper suppresses collapsed text; the Static helper
    -- calls nonexistent getScrollX/getScrollY on B42. Bypass ONLY those
    -- wrappers, using the native UIElement methods verified in 42.21.
    -- Keep isCollapsed and the title-bar/body stencil untouched.
    local ui = self.javaObject
    if not ui then return end
    local x, y = (self.width or WIDTH) / 2 - ui:getXScroll(), 1 - ui:getYScroll()
    ui:DrawTextCentre(UIFont.Small, text, x, y, 1, gb, gb, 1)
    ui:DrawTextCentre(UIFont.Small, text, x + 1, y, 1, gb, gb, 1)
    if dir ~= 0 and alpha > 0 and ui.DrawTextureScaledColor then
        local M = WTAGarou.HUD.TITLE_MARKER
        local left = math.floor(x + measureSmall(text) / 2 + M.gap)
        local topY = math.floor((self:titleBarHeight() - M.h) / 2) - ui:getYScroll()
        for _, row in ipairs(WTAGarou.HUD.titleMarkerRows(dir)) do
            ui:DrawTextureScaledColor(nil, left + row.dx, topY + row.dy, row.w, 1, 1, gb, gb, alpha)
        end
    end
end

function WTAGarouHUD:close()
    self:saveLayout()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    if WTAGarou.HUD.instances[self.player]==self then WTAGarou.HUD.instances[self.player]=nil end
    if WTAGarou.HUD.instance==self then WTAGarou.HUD.instance=nil end
end

function WTAGarou.HUD.open(player)
    player=player or WTAGarou.PrimaryLocalPlayer()
    if not player or (player.isLocalPlayer and not player:isLocalPlayer()) then return end
    local existing=WTAGarou.HUD.forPlayer(player)
    if existing then
        existing:setVisible(true)
        existing:addToUIManager()
        return existing
    end
    local x, y = initialPosition(player)
    local w, h = WTAGarou.HUD.savedSize(player)
    local ui = WTAGarouHUD:new(x, y, player, w, h)
    ui:initialise()
    ui:addToUIManager()
    local saved = savedLayout(player)
    if saved and saved.pin == false then
        ISCollapsableWindow.collapse(ui)
    end
    WTAGarou.HUD.instances[player] = ui
    initialized[player]=true
    -- Compatibility alias only for local slot zero, never last-created.
    if player==WTAGarou.PrimaryLocalPlayer() then WTAGarou.HUD.instance=ui end
    ui:refresh()
    if not WTAGarou.HasGarouTrait(player) then
        ui:pushNotice("Not Garou. Take the trait at creation.")
    end
    return ui
end

function WTAGarouResetHUDPosition(player)
    player=player or WTAGarou.PrimaryLocalPlayer()
    if player then player:getModData()[LAYOUT_KEY] = nil end
    local ui = WTAGarou.HUD.forPlayer(player)
    if ui then
        local x, y = WTAGarou.HUD.defaultPosition(player)
        ui:setX(x)
        ui:setY(y)
        if ui.setWidth then ui:setWidth(WIDTH) end
        if ui.setHeight then ui:setHeight(HEIGHT) end
        ui.width, ui.height = WIDTH, HEIGHT
        ui:layout()
        ui:saveLayout()
    end
end

function WTAGarou.HUD.close(player)
    local ui=WTAGarou.HUD.forPlayer(player)
    if ui then ui:close() end
end

function WTAGarou.HUD.toggle(player)
    player=player or WTAGarou.PrimaryLocalPlayer()
    local ui=WTAGarou.HUD.forPlayer(player)
    if ui and ui:isVisible() then
        WTAGarou.HUD.close(player)
    else
        WTAGarou.HUD.open(player)
    end
end

local KEY_NONE = (Keyboard and Keyboard.KEY_NONE) or 0
Events.OnGameBoot.Add(function()
    table.insert(keyBinding, { value = KEYBIND_CATEGORY })
    table.insert(keyBinding, { value = KEYBIND_TOGGLE, key = KEY_NONE })
    table.insert(keyBinding, { value = KEYBIND_RESIST, key = KEY_NONE })
    table.insert(keyBinding, { value = KEYBIND_STRIP,  key = KEY_NONE })
    table.insert(keyBinding, { value = KEYBIND_DRESS,  key = KEY_NONE })
end)

-- Pure dispatch for tests: returns the action name a key triggers, or nil.
function WTAGarou.HUD.keyAction(key)
    if key == nil or key == KEY_NONE then return nil end
    local core = getCore()
    if core:isKey(KEYBIND_TOGGLE, key) then return "toggle" end
    if core:isKey(KEYBIND_RESIST, key) then return "resist" end
    if core:isKey(KEYBIND_STRIP, key)  then return "strip" end
    if core:isKey(KEYBIND_DRESS, key)  then return "dress" end
    return nil
end

Events.OnKeyPressed.Add(function(key)
    local action = WTAGarou.HUD.keyAction(key)
    if not action then return end
    local player = WTAGarou.PrimaryLocalPlayer()
    if not player then return end
    if action == "toggle" then WTAGarou.HUD.toggle(player); return end
    if not WTAGarou.HasGarouTrait(player) then return end
    if action == "resist" and WTAGarou.RequestResist then WTAGarou.RequestResist(player) end
    if action == "strip"  and WTAGarou.RequestStrip  then WTAGarou.RequestStrip(player)  end
    if action == "dress"  and WTAGarou.RequestDress  then WTAGarou.RequestDress(player)  end
end)

Events.OnGameStart.Add(function()
    for _,player in ipairs(WTAGarou.LocalPlayers()) do
        if WTAGarou.HasGarouTrait(player) then WTAGarou.HUD.open(player) end
    end
end)

if Events.OnPlayerUpdate then Events.OnPlayerUpdate.Add(function(player)
    if not player or (player.isLocalPlayer and not player:isLocalPlayer()) then return end
    if not initialized[player] and not player:isDead() and WTAGarou.HasGarouTrait(player) then
        WTAGarou.HUD.open(player)
    end
end) end

-- Hide with the character. OnGameStart reopens it for the next one.
if Events.OnPlayerDeath then
    Events.OnPlayerDeath.Add(function(player)
        local ui = WTAGarou.HUD.forPlayer(player)
        if not ui then return end
        if player and player.isLocalPlayer and not player:isLocalPlayer() then return end
        if ui.setVisible then ui:setVisible(false) end
        ui:close()
    end)
end
