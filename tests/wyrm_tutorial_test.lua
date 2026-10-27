-- 0.4.18: Wyrm Infection health-panel line and the Garou Guide (tutorial)
-- infrastructure. Pure-Lua mocks of the vanilla UI classes; this proves the
-- logic, page plumbing and persistence, NOT the in-game rendering.
local root = assert(arg[1], "supply WTAGarou directory")
package.path = root .. "/42/media/lua/shared/?.lua;" .. package.path
require "WTAGarouDefinitions"
require "WTAGarouState"
local checks = 0
local function check(ok, message) checks = checks + 1; assert(ok, message) end
local function derive(self, name)
    local cls = { Type = name }; cls.__index = cls
    return setmetatable(cls, { __index = self })
end

-- ------------------------------------------------------------ mocks ----
Events = { OnGameStart = { Add = function() end }, OnCreatePlayer = { Add = function(f) Events.createPlayer = f end },
           OnTick = { Add = function(f) Events.tick = f end, Remove = function() Events.tick = nil end } }
UIFont = { Small = 1 }
UI_BORDER_SPACING = 10
getTextManager = function() return { getFontHeight = function() return 14 end } end
getCore = function() return { getScreenWidth = function() return 1280 end, getScreenHeight = function() return 720 end } end
local files = {}
getFileWriter = function(name, create, append)
    local buf = {}
    return { write = function(_, s) buf[#buf + 1] = s end, close = function() files[name] = table.concat(buf) end }
end
getFileReader = function(name)
    local content = files[name]
    if not content then return nil end
    local lines, i = { content }, 0
    return { readLine = function() i = i + 1; return lines[i] end, close = function() end }
end

local function newPlayer(garou, infected)
    local md = { WTAGarou = { isGarou = garou and true or false } }   -- trait gate fallback
    local p = { md = md, infected = infected }
    function p:getModData() return md end
    function p:getOnlineID() return 1 end
    function p:getBodyDamage() return { isInfected = function() return p.infected end } end
    return p
end

-- ------------------------------------------------ health panel line ----
dofile(root .. "/42/media/lua/client/WTAGarouHealthPanel.lua")
local HP = WTAGarou.HealthPanel
check(HP and HP.lineText and HP.install, "health panel module loaded")
check(WTAGarou.WyrmInfection.NAME == "Wyrm Infection", "lore name is Wyrm Infection")
check(WTAGarou.Regeneration.INFECTION_PER_SECOND.Crinos * 300 > 99.9, "Crinos purges the whole infection in 300 s")
check(WTAGarou.Regeneration.INFECTION_PER_SECOND.Hispo * 900 > 99.9, "Hispo purges the whole infection in 900 s")
check(WTAGarou.Regeneration.INFECTION_PER_SECOND.Glabro * 900 > 99.9, "Glabro purges the whole infection in 900 s")
check(WTAGarou.Regeneration.CLEAR_BITES_AFTER.Crinos == 300 and WTAGarou.Regeneration.CLEAR_BITES_AFTER.Hispo == 900
    and WTAGarou.Regeneration.CLEAR_BITES_AFTER.Glabro == 900, "bites close on the Wyrm clock")
check(WTAGarou.Regeneration.CLEAR_WOUNDS_AFTER.Crinos == 100, "ordinary wounds use the 100 s Crinos window (0.4.68, was 75)")

local p = newPlayer(true, true)
local d = WTAGarou.GetData(p)
d.isGarou = true; d.form = "Crinos"; d.infectionBurn = 40
local text, purging = HP.lineText(p)
check(text:find("- Wyrm Infection", 1, true) == 1, "line starts with - Wyrm Infection: " .. text)
check(purging and text == "- Wyrm Infection (purging 40%, 3:00 left)", "Crinos purge read-out (0.4.19 wording): " .. text)
d.form = "Homid"
text, purging = HP.lineText(p)
check(not purging and text == "- Wyrm Infection", "Homid read-out is the plain line (0.4.19): " .. text)
d.form = "Hispo"; d.infectionBurn = nil
text = HP.lineText(p)
check(text == "- Wyrm Infection (purging 0%, 15:00 left)", "Hispo read-out: " .. text)
check(HP.isInfected(p) == true, "isInfected reads BodyDamage")
check(HP.isInfected(newPlayer(true, false)) == false, "not infected when the flag is off")
check(HP.shouldShow({ character = newPlayer(false, true) }) == false, "non-Garou never gets the Wyrm line")
check(HP.shouldShow({ character = p }) == true, "infected Garou shows the Wyrm line")

-- 0.4.22: "Silver Burn" line in light blue-grey, one entry per burned part.
check(HP.SILVER_NAME == "Silver Burn" and HP.SILVER_COLOR.b > HP.SILVER_COLOR.r, "silver line is named Silver Burn and tinted blue-grey")
check(HP.silverLine(d) == nil and HP.silverLine(nil) == nil, "no silver line without burns")
d.silverBurns = { Neck = true, Hand_L = true, Torso_Upper = false }
local sl = HP.silverLine(d)
check(sl == "- Silver Burn: Hand L, Neck", "silver line lists the burned parts, sorted, underscores gone: " .. tostring(sl))
check(HP.shouldShowSilver({ character = p }) == true, "Garou with a silver burn shows the line")
check(HP.shouldShowSilver({ character = newPlayer(false, true) }) == false, "non-Garou never gets the Silver line")
d.silverBurns = {}
check(HP.silverLine(d) == nil, "all burns healed: line gone")

-- 0.4.76: lodged silver-tip bullet line in the body-part list.
do
    getText = getText or function(k) return k == "IGUI_health_LodgedBullet" and "Lodged Bullet" or (k == "IGUI_health_LodgedGlassShards" and "Lodged Glass Shards") or (k == "IGUI_health_Burned" and "Burned") or k end
    local Box = {}; Box.__index = Box
    function Box:drawText(str, x, y, r, g, b, a, font) self.drawn[#self.drawn + 1] = { str = str, r = r, g = g, b = b, x = x, y = y } end
    Box.burnSuffix = ""
    Box.drawBurn = true
    function Box:doDrawItem(y, item, alt)
        self:drawText("- Lodged Bullet", 0, y, 1, 1, 1, 1, "Small")   -- the vanilla line
        if self.drawBurn then self:drawText("- Burned" .. self.burnSuffix, 0, y, 0.89, 0.28, 0.28, 1, "Small") end
        self:drawText("- Lodged Glass Shards", 0, y, 0.89, 0.28, 0.28, 1, "Small")
        return y + 10
    end
    ISHealthBodyPartListBox = Box
    check(HP.installBullet() == true and HP.installBullet() == false, "body-part list hook installed exactly once")
    local function part(name) return { getType = function() return name end } end
    local box = setmetatable({ drawn = {}, parent = { character = p } }, Box)
    d.silverLodged = { Hand_L = "bullet" }
    box:doDrawItem(5, { item = { bodyPart = part("Hand_L") } }, false)
    check(box.drawn[1].str == "- Lodged silver-tip bullet" and box.drawn[1].b == HP.SILVER_COLOR.b and box.drawn[1].r == HP.SILVER_COLOR.r,
        "silver bullet: the lodged line reads silver-tip in the silver colour")
    check(box.drawn[2].str == "- Burned" and box.drawn[2].r == 0.89 and box.drawn[3].str == "- Lodged Glass Shards", "other lines of that part untouched (a bullet mark leaves the burn and glass lines alone)")
    check(rawget(box, "drawText") == nil, "the instance drawText shadow is removed after the item")
    box.drawn = {}
    box:doDrawItem(5, { item = { bodyPart = part("Neck") } }, false)
    check(box.drawn[1].str == "- Lodged Bullet" and box.drawn[1].r == 1, "a lead bullet in another part stays vanilla")
    d.silverLodged = nil
    box.drawn = {}
    box:doDrawItem(5, { item = { bodyPart = part("Hand_L") } }, false)
    check(box.drawn[1].str == "- Lodged Bullet", "bullet pulled: vanilla line again")
    -- 0.4.77: silver fragments in a foot swap the glass line instead
    d.silverLodged = { Foot_L = "shard" }
    box.drawn = {}
    box:doDrawItem(5, { item = { bodyPart = part("Foot_L") } }, false)
    check(box.drawn[1].str == "- Lodged Bullet" and box.drawn[1].r == 1, "shard mark: the bullet line stays vanilla")
    check(box.drawn[3].str == "- Lodged silver fragments" and box.drawn[3].b == HP.SILVER_COLOR.b, "shard mark: the glass line reads silver fragments in the silver colour")
    local other = setmetatable({ drawn = {}, parent = { character = newPlayer(false, true), otherPlayer = p } }, Box)
    d.silverLodged = { Neck = "bullet" }
    other:doDrawItem(5, { item = { bodyPart = part("Neck") } }, false)
    check(other.drawn[1].str == "- Lodged silver-tip bullet", "looking at another player's panel uses that player's data")
    d.silverLodged = nil
    -- 0.4.79: the silver burn is a per-part line, replacing the vanilla
    -- "- Burned" line of that part; the summary line at the top is gone.
    check(HP.SUMMARY_LINE == false, "no summary line at the top any more")
    d.silverBurns = { Hand_L = true }
    box.drawn = {}
    local h = box:doDrawItem(5, { item = { bodyPart = part("Hand_L") } }, false)
    check(box.drawn[2].str == "- Silver Burn" and box.drawn[2].b == HP.SILVER_COLOR.b and box.drawn[2].r == HP.SILVER_COLOR.r, "a silver-burned part: its burn line reads Silver Burn in the silver colour")
    check(box.drawn[1].str == "- Lodged Bullet" and box.drawn[1].r == 1 and #box.drawn == 3 and h == 15, "the other lines and the item height are untouched")
    box.burnSuffix = " (Needs Cleaning)"
    box.drawn = {}
    box:doDrawItem(5, { item = { bodyPart = part("Hand_L") } }, false)
    check(box.drawn[2].str == "- Silver Burn (Needs Cleaning)", "vanilla's suffix is kept")
    box.burnSuffix = ""
    box.drawn = {}
    box:doDrawItem(5, { item = { bodyPart = part("Neck") } }, false)
    check(box.drawn[2].str == "- Burned" and box.drawn[2].r == 0.89, "an ordinary burn on another part stays vanilla red")
    -- bandaged: vanilla draws no burn line, so one is appended under the part
    box.drawBurn = false
    box.drawn = {}
    h = box:doDrawItem(5, { item = { bodyPart = part("Hand_L") } }, false)
    check(#box.drawn == 3 and box.drawn[3].str == "- Silver Burn" and box.drawn[3].b == HP.SILVER_COLOR.b and h == 15 + 14 and box.drawn[3].y == 10, "bandaged silver burn: a plain line (no '(bandaged)' suffix, 0.4.82) is added in the padding and the item grows by one font height")
    check(box.drawn[3].x == 15 and box.drawn[3].x == HP.WOUND_LINE_X, "the added line sits at vanilla's wound-line x (15), not off to the right")
    box.drawBurn = true
    d.silverBurns = { Hand_L = true }; d.silverLodged = { Hand_L = "bullet" }
    box.drawn = {}
    box:doDrawItem(5, { item = { bodyPart = part("Hand_L") } }, false)
    check(box.drawn[1].str == "- Lodged silver-tip bullet" and box.drawn[2].str == "- Silver Burn", "a part with both marks gets both silver lines")
    d.silverBurns = nil; d.silverLodged = nil
end

-- Render hook: post-hook draws once and pushes the list box down one line.
-- 0.4.82: the body-part context menu's vanilla "Remove Glass" is renamed
-- "Remove Silver Fragments" when the part's lodged silver kind is a shard.
local menus = {}
local function fakeMenu()
    local m = { options = {} }
    function m:addOption(name) local o = { name = name }; table.insert(self.options, o); return o end
    function m:getOptionFromName(name) for _, o in ipairs(self.options) do if o.name == name then return o end end end
    return m
end
getPlayerContextMenu = function(n) menus[n] = menus[n] or fakeMenu(); return menus[n] end
local menuCalls = 0
ISHealthPanel = {
    render = function(self) self.rendered = (self.rendered or 0) + 1 end,
    doBodyPartContextMenu = function(self, bodyPart, x, y)
        menuCalls = menuCalls + 1
        local ctx = getPlayerContextMenu(self.character:getPlayerNum())
        ctx.options = {}
        ctx:addOption("Bandage")
        ctx:addOption(getText("ContextMenu_Remove_Glass"))
        return "vanilla-result"
    end,
}
check(HP.install() == true and HP.install() == false, "render hook installed exactly once")
do
    local pl = newPlayer(true, false)
    pl.getPlayerNum = function() return 0 end
    local d = WTAGarou.GetData(pl)
    local function part(t) return { getType = function() return t end } end
    local hp = { character = pl }
    d.silverLodged = { Foot_R = "shard", Hand_L = "bullet" }
    check(ISHealthPanel.doBodyPartContextMenu(hp, part("Foot_R"), 1, 2) == "vanilla-result" and menuCalls == 1, "vanilla menu builder still runs and its result passes through")
    check(menus[0].options[2].name == "Remove Silver Fragments" and menus[0].options[1].name == "Bandage", "silver fragments: Remove Glass reads Remove Silver Fragments, other options untouched")
    ISHealthPanel.doBodyPartContextMenu(hp, part("Hand_L"), 1, 2)
    check(menus[0].options[2].name == "ContextMenu_Remove_Glass", "a lodged bullet part keeps vanilla's Remove Glass label")
    ISHealthPanel.doBodyPartContextMenu(hp, part("Foot_L"), 1, 2)
    check(menus[0].options[2].name == "ContextMenu_Remove_Glass", "ordinary glass keeps vanilla's label")
    d.silverLodged = nil
    check(HP.relabelRemoveGlass(nil, pl, part("Foot_R")) == false, "no context: nothing to do, no error")
end
local listY, listH = 100, 200
local panel = {
    character = p, texts = {},
    healthPanel = { getRight = function() return 300 end },
    listbox = { getY = function() return listY end, setY = function(_, y) listY = y end,
                getHeight = function() return listH end, setHeight = function(_, h) listH = h end },
    drawText = function(self, s, x, y) table.insert(self.texts, { s = s, x = x, y = y }) end,
}
ISHealthPanel.render(panel)
check(panel.rendered == 1, "original render still runs")
check(#panel.texts == 1 and panel.texts[1].x == 310 and panel.texts[1].y == 100, "Wyrm line drawn at the list box top")
check(listY == 114 and listH == 186, "list box pushed down by one font height")
panel.character = newPlayer(true, false); panel.texts = {}
ISHealthPanel.render(panel)
check(#panel.texts == 0 and panel.rendered == 2, "no line when not infected")
panel.character = { getBodyDamage = function() error("boom") end, getModData = function() return { WTAGarou = { isGarou = true } } end }
ISHealthPanel.render(panel)
check(panel.rendered == 3, "hook failure never blocks the vanilla render")

-- -------------------------------------------------------- tutorial ----
ISCollapsableWindow = { derive = derive }
function ISCollapsableWindow:new(x, y, w, h) return setmetatable({ x = x, y = y, width = w, height = h, children = {} }, self) end
function ISCollapsableWindow:setTitle(s) self.title = s end
function ISCollapsableWindow:titleBarHeight() return 16 end
function ISCollapsableWindow:createChildren() end
function ISCollapsableWindow:initialise() self:createChildren() end
function ISCollapsableWindow:addChild(c) table.insert(self.children, c) end
function ISCollapsableWindow:addToUIManager() self.inUI = true end
function ISCollapsableWindow:removeFromUIManager() self.inUI = false end
function ISCollapsableWindow:setVisible(v) self.visible = v end
ISButton = { new = function(_, x, y, w, h, title, target, fn)
    return { title = title, target = target, fn = fn, initialise = function() end, setTooltip = function() end,
             setEnable = function(self, v) self.enabled = v end, click = function(self) self.fn(self.target) end } end }
ISRichTextPanel = { new = function(_, x, y, w, h)
    return { initialise = function() end, setText = function(self, t) self.text = t end, paginate = function(self) self.paginated = true end } end }
ISTickBox = { new = function(_, x, y, w, h, title, target, fn)
    return { target = target, fn = fn, options = {}, initialise = function() end,
             addOption = function(self, s) table.insert(self.options, s) end,
             setSelected = function(self, i, v) self.selected = v end,
             tick = function(self, v) self.selected = v; self.fn(self.target, 1, v) end } end }
getSpecificPlayer = function() return nil end

dofile(root .. "/42/media/lua/client/WTAGarouTutorial.lua")
local T = WTAGarou.Tutorial
check(T and WTAGarouTutorial, "tutorial module and window class loaded")
local pages = T.pages()
check(#pages >= 4, "guide has several pages (" .. #pages .. ")")
for i, pg in ipairs(pages) do
    check(type(pg.title) == "string" and #pg.title > 0 and type(pg.body) == "string" and #pg.body > 20, "page " .. i .. " has title and body")
    check(not pg.body:find("<SIZE", 1, true) and not pg.body:find("<H1", 1, true), "page " .. i .. " never uses <SIZE>/<H1>")
end
check(pages[3].body:find("Berzerker", 1, true) and pages[3].body:find("Near-Wolf", 1, true), "form page uses display names")
check(pages[7].body:find("Wyrm Infection", 1, true) and pages[7].body:find("5 minutes", 1, true), "Wyrm page quotes the five-minute purge")
-- 0.4.59: the hunters' silver page documents every silver route and the sealed-glass exception
-- 0.4.75: split in two (page six overran the panel; last visible line was Forged silver).
check(pages[8] and pages[8].title:find("Silver", 1, true) and pages[8].body:find("Silver rounds", 1, true) and pages[8].body:find("Blacksmith level", 1, true)
    and not pages[8].body:find("car battery", 1, true), "silver page covers fragments, rounds and forging skill")
check(pages[9] and pages[9].title == "Silver nitrate" and pages[9].body:find("twelve landed hits", 1, true)
    and pages[9].body:find("car battery", 1, true) and pages[9].body:find("in a vessel does not burn", 1, true) and pages[9].body:find("hits left", 1, true), "nitrate page covers the fluid coats, the charge meter and the vessel exception")
-- 0.4.81: the traps page (scatter + silver smoke bomb) sits after the nitrate page
check(pages[10] and pages[10].title == "Silver: traps" and pages[10].body:find("Scattered silver", 1, true) and pages[10].body:find("smoke bomb", 1, true)
    and pages[10].body:find("gas mask", 1, true), "traps page covers scatter and the silver smoke bomb")
-- 0.4.97: the Startup page (origin, coat, auspice) sits second; the paws/vehicles page fourth.
check(pages[2].title == "Who you are" and pages[2].body:find("Metis", 1, true) and pages[2].body:find("Auspice", 1, true)
    and pages[2].body:find("Wolf Gear", 1, true), "startup page covers origin, coat, auspice and gear")
check(pages[4].title == "Paws, jaws and vehicles" and pages[4].body:find("saddlebags", 1, true) and pages[4].body:find("No firearms", 1, true)
    and pages[4].body:find("drunk", 1, true) and pages[4].body:find("shoes", 1, true), "paws page covers jaws, guns, cars and shoes")
for i, pg in ipairs(pages) do check(#T.plain(pg.body) <= 1000, "page " .. i .. " fits the panel (" .. #T.plain(pg.body) .. " chars; page 3 at 898 renders, the old page 6 at 1830 did not)") end

-- 0.4.45 guide copy: every tag stands alone between spaces and <SPACE>
-- marks each visible gap (the 0.4.22 glued shape lost words; see
-- tests/rich_text_test.lua, which renders every page through a port of
-- the vanilla tokenizer). Here: the structural rule plus the plain reading.
for i, pg in ipairs(pages) do
    check(not pg.body:find("[^%s>]<") and not pg.body:find(">[^%s<]"), "page " .. i .. ": every tag is separated from text by spaces")
    check(not pg.body:find("<SPACE> <RGB:1,1,1>  <SPACE>", 1, true), "page " .. i .. ": no doubled gap between two keywords")
end
check(T.kw("Rage", "rage") == " <SPACE> <RGB:1,0.8,0.35> Rage <SPACE> <RGB:1,1,1> ", "kw shape (0.4.45)")
check(T.plain("into" .. T.kw("Berzerker.", "war") .. "Strip") == "into Berzerker. Strip", "plain() reads a keyword with single spaces")
local P = {}
for i, pg in ipairs(pages) do P[i] = T.plain(pg.body) end
check(P[2]:find("Human-born starts as, and falls back to, Human; Wolf-born to Wolf; Metis to Near-Human.", 1, true), "startup page: origin sentence reads with spaces: " .. P[2])
check(P[4]:find("Near-Wolf and Wolf have no hands.", 1, true) and P[4]:find("Berzerker and Near-Wolf are too big for a car seat", 1, true), "paws page reads with spaces: " .. P[4])
check(P[1]:find("The Rage panel (top left) lists your five forms on the left and Strip, Dress, Howl, Resist, this Guide and Startup on the right.", 1, true), "page 1: 'The Rage panel' reads with spaces")
check(P[3]:find("Berzerker: the war form. Needs 55 Rage, burns 1 Rage a second (one more each 90 seconds you hold it)", 1, true), "form page: Berzerker line reads with spaces (0.4.69 escalation)")
check(P[5]:find("Fear, stress, pain and taking damage raise it. Dealing damage spends it. Being fed and watered, or howling, settles it toward your baseline (30 to 70, chosen once on the Startup panel). Sadness, exhaustion and drowsiness drain it to 0. Every bad moodle level widens a band around the baseline where that settling runs at half speed.", 1, true), "Rage page (0.4.69): damage dealt spends Rage; sad drains; baseline bracket sentence")
check(P[3]:find("shrugs off most flinches. Sprint into a closed wooden door to smash it (12 Rage, 18 if locked, plus stamina).", 1, true)
      and not P[3]:find("Too tall for doorways", 1, true), "form page (0.4.71): door-charge sentence reads with spaces; doorway duck sentence gone, no window charge")
check(P[5]:find("forced into Berzerker. Strip before that if you want to keep your clothes.", 1, true), "Rage page: Strip before the forced shift")
check(P[5]:find("Shifts channel for six seconds near the middle of the bar (45 to 55 Rage) and quicken toward either end: at 20 or 80 Rage and beyond, any shift but Berzerker takes one second.", 1, true), "Rage page: 0.4.61 channel-time curve sentence reads with spaces")
check(P[5]:find("Every Resist makes the next countdown shorter", 1, true), "Rage page: Resist sentence")
check(P[6]:find("Strip takes it all off first, Dress puts the same items back", 1, true), "page 6: Strip/Dress read with spaces")
check(P[6]:find("Any form can dress again", 1, true), "page 6: 0.4.22 wear rule")
check(P[6]:find("Hats and masks are dropped, but never damaged. Bags, jewelry, watches and held items are never dropped or damaged.", 1, true),
    "page 6: hats/masks and never-dropped list")
check(P[7]:find("Wyrm Infection (a zombie bite)", 1, true) and P[7]:find("Silver burns wherever", 1, true), "page 7: plain Wyrm/Silver words")
check(P[7]:find("Berzerker closes ordinary wounds in about 100 seconds; Near-Wolf and Near-Human take about 3 minutes 45 seconds.", 1, true), "page 7: updated healing sentence reads with spaces")
check(P[7]:find("The health panel lists the Silver Burn parts.", 1, true), "page 7: Silver Burn mention")

local fresh = newPlayer(true, false)
check(T.hasSeen(fresh) == false and T.shouldAutoShow(fresh) == true, "fresh werewolf auto-shows the guide")
check(T.shouldAutoShow(newPlayer(false, false)) == false, "non-Garou never auto-shows")

local win = T.open(fresh)
check(win and win.inUI and T.instance == win, "guide window opened and added to the UI")
check(win.page == 1 and win.title:find("1/" .. #pages, 1, true) and win.text.text == pages[1].body and win.text.paginated, "page 1 shown")
check(win.backBtn.enabled == false and win.nextBtn.enabled == true, "Back disabled on the first page")
win.nextBtn:click()
check(win.page == 2 and win.title:find("2/" .. #pages, 1, true) and win.text.text == pages[2].body, "Next advances")
for _ = 1, 10 do win.nextBtn:click() end
check(win.page == #pages and win.nextBtn.enabled == false and win.backBtn.enabled == true, "Next clamps at the last page")
win.backBtn:click()
check(win.page == #pages - 1, "Back goes back one page")
check(win.tick.options[1] == "Don't show again" and win.tick.selected == false, "tick box present and unticked")
win.tick:tick(true)
check(fresh.md[T.SEEN_KEY] == true and files[T.SEEN_FILE] == "seen=1", "Don't show again persisted to mod data and file")
check(T.hasSeen(fresh) == true and T.shouldAutoShow(fresh) == false, "dismissed guide does not auto-show again")
check(T.shouldAutoShow(newPlayer(true, false)) == false, "a NEW character honours the per-install file")
win.tick:tick(false)
check(fresh.md[T.SEEN_KEY] == nil and files[T.SEEN_FILE] == "seen=0" and T.shouldAutoShow(newPlayer(true, false)) == true,
    "unticking re-enables the auto-show")
win.closeBtn:click()
check(T.instance == nil and win.inUI == false, "Close removes the window")
local again = T.open(fresh)
check(again ~= win and again.page == 1, "Guide button reopens at page 1")
local same = T.open(fresh)
check(same == again and same.visible == true, "reopening while open just re-shows the window")
T.close()

-- Auto-show: OnCreatePlayer defers to the next tick, once.
check(type(Events.createPlayer) == "function", "OnCreatePlayer handler registered")
files[T.SEEN_FILE] = nil
Events.createPlayer(0, newPlayer(true, false))
check(type(Events.tick) == "function", "auto-show waits one tick")
Events.tick()
check(Events.tick == nil and T.instance ~= nil and T.instance.inUI, "guide opened on the first tick and the tick hook removed")
T.close()
Events.createPlayer(0, newPlayer(false, false))
check(Events.tick == nil and T.instance == nil, "non-Garou create never schedules the guide")

print("PASS: " .. checks .. " Wyrm health-panel / Garou Guide assertions.")
