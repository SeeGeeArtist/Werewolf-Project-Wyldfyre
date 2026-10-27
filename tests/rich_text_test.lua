-- 0.4.45: rich text spacing. Build 42's ISRichTextPanel:paginate (the
-- tooltip description panel and the Guide) splits on plain spaces, cuts a
-- token at the first ">", and treats ANY token holding "<" and ">" as a
-- command, so "<RGB:..> Homid <RGB:..>Human" renders "HomidHuman" and
-- "word<RGB:..>" loses "word". Below is a faithful port of that tokenizer
-- (text and <SPACE>/<LINE> layout only; colours do not move the pen). It
-- renders every tooltip and Guide page the mod ships and compares the
-- words and gaps with the plain reading. A static check of the vanilla
-- algorithm, not an in-game render.
local root = assert(arg[1], "supply WTAGarou directory")
package.path = root .. "/42/media/lua/shared/?.lua;" .. root .. "/42/media/lua/client/?.lua;" .. package.path
isServer = function() return false end
isClient = function() return false end
require "WTAGarouDefinitions"
require "WTAGarouState"
local checks = 0
local function check(ok, message) checks = checks + 1; assert(ok, message) end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
-- Port of ISRichTextPanel:paginate (B42, ProjectZomboid-Vanilla-Lua) with a
-- monospace "font": one unit per character, <SPACE> = 1 unit + 0 (the +2
-- pixel nudge is ignored), no wrapping.
local function render(text)
    local leftText = text .. ' '
    leftText = leftText:gsub("\n", " <LINE> ")
    local cur, x = 0, 0
    local lines, lineX = {}, {}
    local idx = 1
    local rows = { {} }
    while true do
        cur = string.find(leftText, " ", cur + 1, true)
        if not cur then break end
        local token = string.sub(leftText, 1, cur)
        if string.find(token, "<", 1, true) and string.find(token, ">", 1, true) then
            cur = string.find(token, ">", 1, true) + 1
            token = string.sub(leftText, 1, cur - 1)
        end
        leftText = string.sub(leftText, cur)
        cur = 1
        if string.find(token, "<", 1, true) and string.find(token, ">", 1, true) then
            if not lines[idx] then lines[idx] = ''; lineX[idx] = x end
            rows[#rows][#rows[#rows] + 1] = { x = lineX[idx], text = lines[idx] }
            idx = idx + 1
            local st, en = string.find(token, "<", 1, true), string.find(token, ">", 1, true)
            local cmd = string.sub(token, st + 1, en - 1)
            if cmd == "LINE" or cmd == "BR" then
                x = 0; rows[#rows + 1] = {}
            elseif cmd == "SPACE" then
                if x > 0 then x = x + 1 end
            end
        else
            local chunkText = lines[idx] or ''
            local chunkX = lineX[idx] or x
            if chunkText == '' then chunkText = trim(token)
            elseif trim(token) ~= '' then chunkText = chunkText .. ' ' .. trim(token) end
            if not lines[idx] then lines[idx] = ''; lineX[idx] = x end
            lines[idx] = chunkText
            x = lineX[idx] + #chunkText
        end
    end
    if lines[idx] and not (rows[#rows][#rows[#rows]] and rows[#rows][#rows[#rows]].text == lines[idx]) then
        rows[#rows][#rows[#rows] + 1] = { x = lineX[idx], text = lines[idx] }
    end
    if trim(leftText) ~= '' then rows[#rows][#rows[#rows] + 1] = { x = x, text = trim(leftText) } end
    -- Paint each row: a chunk starting right where the previous one ended
    -- glues to it (that is the "HomidHuman" bug); a gap of >= 1 is a space.
    local out = {}
    for _, row in ipairs(rows) do
        local buf, penX = "", 0
        for _, c in ipairs(row) do
            if c.text ~= '' then
                if buf ~= "" and c.x > penX then buf = buf .. " " end
                buf = buf .. c.text
                penX = c.x + #c.text
            end
        end
        out[#out + 1] = buf
    end
    return (table.concat(out, "\n"):gsub("\n+$", ""))
end

-- The tokenizer port reproduces the two vanilla failure shapes.
check(render("<RGB:1,0.85,0.45> Homid <RGB:1,1,1> Human form.") == "HomidHuman form.", "port: spaces beside a tag are lost")
check(render("The Knox virus is a<SPACE><RGB:0.75,0.35,0.95>Wyrm<RGB:1,1,1><SPACE>bioweapon.") == "The Knox virus is bioweapon.",
    "port: the 0.4.22 <SPACE><RGB>word<RGB><SPACE> shape loses the word and the one before it")
check(render("A<LINE>B") == "A\nB" or render("A <LINE> B") == "A\nB", "port: <LINE> breaks")

local R = WTAGarou.Rich
local function reads(body, label)
    local plain = R.plain(body)
    local drawn = render(body)
    check(drawn == plain, label .. ": rendered '" .. drawn .. "' ~= plain '" .. plain .. "'")
end
reads(R.lead("Homid") .. "Human form." .. R.line() .. R.COLORS.rage .. " Rage cost: none", "Rich.lead + line")
reads("Needs" .. R.kw("55", "rage") .. "to shift; " .. "every" .. R.kw("Resist", "action") .. "shortens it.", "Rich.kw mid-sentence")
reads(R.tidy("Buttons:" .. R.kw("Strip,", "action") .. R.kw("Dress,", "action") .. "and" .. R.kw("Guide", "action") .. "here."), "Rich.tidy keyword run")
check(R.plain(R.kw("Rage", "rage")) == "Rage", "plain of a lone keyword")
check(not R.tidy("a <SPACE> <RGB:1,1,1>  <SPACE> <RGB:1,0.8,0.35> b"):find("<SPACE> <RGB:1,1,1>  <SPACE>", 1, true), "tidy drops the body reset between two keywords")

-- Startup panel: Baseline Rage tooltips.
WTAGarou.WolfCoat = WTAGarou.WolfCoat or {}
local coatSrc = assert(io.open(root .. "/42/media/lua/client/WTAGarouWolfCoat.lua")):read("*a")
local tipBody = coatSrc:match("function Coat%.auspiceTooltip%(auspice%)(.-)\nend")
assert(tipBody, "auspiceTooltip present")
local tipFn = assert(loadstring("local Coat={} function Coat.auspiceTooltip(auspice)" .. tipBody .. "\nend return Coat.auspiceTooltip"))()
for _, a in ipairs(WTAGarou.Auspices) do
    local tip = tipFn(a)
    reads(tip, "auspice tooltip " .. a.key)
    check(R.plain(tip) == string.format("%s Werewolf. As a %s, rage value gravitates to %d when you're healthy and happy.", a.moon, a.key, a.baseline),
        "auspice tooltip wording " .. a.key)
    check(tip:find(R.COLORS.lore .. " " .. a.moon, 1, true) and tip:find(R.COLORS.lore .. " " .. a.key, 1, true)
        and tip:find(R.COLORS.rage .. " " .. a.baseline, 1, true), "moon, auspice and value are highlighted " .. a.key)
end

-- HUD tooltips (form, strip, howl, guide, startup) through the same port.
WTAGarou.ShiftStrip = { damageFor = function(f) return ({ Glabro = 10, Lupus = 20, Hispo = 30, Crinos = 40 })[f] end }
WTAGarou.DisplayName = WTAGarou.DisplayName or function(f) return f end
getPlayer = function() return nil end
Events = setmetatable({}, { __index = function() return { Add = function() end, Remove = function() end } end })
ISButton = {}; ISUIElement = {}; UIFont = { Small = 1, Medium = 2 }; Keyboard = { KEY_G = 34, KEY_NONE = 0 }
keyBinding = {}
getTextManager = function() return { getFontHeight = function() return 14 end, MeasureStringX = function() return 10 end } end
getCore = function() return { getScreenWidth = function() return 1280 end, getScreenHeight = function() return 720 end, getKey = function() return 0 end } end
getKeyName = function() return "G" end
getText = function(k) return k end
package.loaded["ISUI/ISCollapsableWindow"] = true
package.loaded.keyBinding = true
ISCollapsableWindow = { derive = function(self, name) local c = {}; c.__index = c; return c end }
local okHUD, errHUD = pcall(dofile, root .. "/42/media/lua/client/WTAGarouHUD.lua")
assert(okHUD, errHUD)
if WTAGarou.HUD and WTAGarou.HUD.formTooltip then
    for _, f in ipairs(WTAGarou.FormOrder) do
        local tip = WTAGarou.HUD.formTooltip(f, { trueForm = "Homid", form = "Homid", rage = 0 })
        reads(tip, "form tooltip " .. f)
        check(R.plain(tip):find("^" .. f .. " "), "form tooltip opens with the lore name and a gap: " .. f)
    end
    reads(WTAGarou.HUD.stripTooltip(), "strip tooltip")
    local howl = WTAGarou.HUD.howlTooltip({ auspice = "Ragabash", auspiceLocked = true })
    reads(howl, "howl tooltip")
    check(R.plain(howl):find("baseline of 30.", 1, true), "howl tooltip names the locked baseline")
    check(R.plain(WTAGarou.HUD.howlTooltip({})):find("baseline of 50.", 1, true), "howl tooltip defaults to 50 before lock")
else
    error("HUD did not load in the test harness")
end

-- Guide pages.
local okT, errT = pcall(dofile, root .. "/42/media/lua/client/WTAGarouTutorial.lua")
assert(okT, errT)
if WTAGarou.Tutorial and WTAGarou.Tutorial.buildPages then
    for i, pg in ipairs(WTAGarou.Tutorial.buildPages()) do reads(pg.body, "guide page " .. i) end
    local p1 = R.plain(WTAGarou.Tutorial.buildPages()[1].body)
    check(p1:find("The Rage panel (top left) lists your five forms on the left and Strip, Dress, Howl, Resist, this Guide and Startup on the right.", 1, true),
        "guide page 1 reads with every gap")
else
    error("Tutorial did not load in the test harness")
end

print("PASS: " .. checks .. " rich text spacing assertions against a port of ISRichTextPanel:paginate; not an in-game render.")
