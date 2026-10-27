--[[
    WTAGarou - Werewolf Guide / tutorial window (infrastructure, v0.4.18)

    A paged rich-text window that explains the Garou mechanics to a new
    player. The mechanics are still moving, so this file is the plumbing:

      * WTAGarou.Tutorial.PAGES     ordered pages { title = "...", body = "rich text" }
                                    (edit the text here; nothing else changes)
      * Back / Next / Close buttons, page counter in the title
      * "Don't show again" tick box, remembered per character (player mod
        data WTAGarou_TutorialSeen) AND per install (Lua/WTAGarou_tutorial.txt),
        so a fresh character does not re-trigger it once dismissed
      * opens automatically on the first Garou character (OnCreatePlayer,
        one frame later so the HUD exists), and on demand from the Garou
        panel's "Guide" button or WTAGarou.Tutorial.open()

    Body text uses ISRichTextPanel markup: <LINE>, <RGB:r,g,b>, <INDENT:n>,
    <SPACE> (0.4.22, around coloured keywords; 0.4.45: every tag stands
    alone between spaces, see WTAGarou.Rich). Never <SIZE>/<H1> (the same
    overflow rule as the tooltips).
]]

WTAGarou = WTAGarou or {}
WTAGarou.Tutorial = WTAGarou.Tutorial or {}
local T = WTAGarou.Tutorial

T.WIDTH        = 460
T.HEIGHT       = 380   -- 0.4.75: a little more room; page copy is capped at 1000 plain chars (tests)
T.SEEN_FILE    = "WTAGarou_tutorial.txt"      -- Zomboid/Lua/<file>
T.SEEN_KEY     = "WTAGarou_TutorialSeen"      -- player mod data
T.ENABLED      = true                         -- master switch for the auto-show

local function names()
    local D = WTAGarou.DisplayName or function(f) return f end
    return D("Homid"), D("Glabro"), D("Crinos"), D("Hispo"), D("Lupus")
end

-- 0.4.22: coloured keywords mid-sentence. ISRichTextPanel drops the plain
-- spaces on either side of a tag, which is why the 0.4.19 copy kept every
-- <RGB> at the start of a line. 0.4.45: the parser also cuts a token at the
-- first ">" and treats any token holding "<" and ">" as a command, so the
-- 0.4.22 shape "<SPACE><RGB:...>word<RGB:body><SPACE>" lost "word" (and the
-- word glued in front of the opening <SPACE>). Keywords now come from
-- WTAGarou.Rich.kw: " <SPACE> <RGB:...> word <SPACE> <RGB:body> ", every
-- tag alone between spaces. Punctuation that follows a keyword goes inside
-- it ("Berzerker.") or it would float.
T.BODY_RGB = "<RGB:1,1,1>"
T.COLORS = {
    form   = "<RGB:1,0.85,0.45>",     -- form names (gold, as the tooltips)
    war    = "<RGB:1,0.55,0.55>",     -- Berzerker
    rage   = "<RGB:1,0.8,0.35>",      -- Rage
    action = "<RGB:0.6,0.9,1>",       -- Strip / Dress / Howl / Resist / Guide
    wyrm   = "<RGB:0.75,0.35,0.95>",  -- Wyrm
    silver = "<RGB:0.7,0.8,0.9>",     -- Silver
}
function T.kw(text, kind)
    local rgb = T.COLORS[kind or "form"] or T.COLORS.form
    return " <SPACE> " .. rgb .. " " .. tostring(text) .. " <SPACE> " .. T.BODY_RGB .. " "
end
-- Plain reading of a body: tags gone, runs of spaces collapsed. Used by
-- tests and the copy checks.
function T.plain(body)
    return WTAGarou.Rich.plain(body)
end

-- Pages are built lazily so display names and tuning constants are final.
function T.buildPages()
    local homid, glabro, crinos, hispo, lupus = names()
    local W = WTAGarou.WyrmInfection or {}
    local purge = (W.PURGE_SECONDS or {}).Crinos or 300
    local need = (WTAGarou.RageRequired and WTAGarou.RageRequired("Crinos")) or 55
    local kw = T.kw
    local B = T.BODY_RGB
    local function F(name) return kw(name, name == crinos and "war" or "form") end
    -- Two keywords in a row would double the <SPACE>; collapse after building.
    local pages = {
        { title = "You are a werewolf",
          body  = "<RGB:0.9,0.85,0.7> You are a werewolf of the Garou Nation, not a victim of the outbreak. "
               .. "The Knox virus is a" .. kw("Wyrm", "wyrm") .. "bioweapon; your blood fights it. <LINE> <LINE> "
               .. B .. " The Rage panel (top left) lists your five forms on the left and"
               .. kw("Strip,", "action") .. kw("Dress,", "action") .. kw("Howl,", "action") .. kw("Resist,", "action")
               .. "this" .. kw("Guide", "action") .. "and" .. kw("Startup", "action")
               .. "on the right. Hover any button for details." },
        { title = "Who you are",
          body  = B .. " The" .. kw("Startup", "action") .. "panel asks three things, then locks them for this character. <LINE> <LINE>"
               .. kw("Origin:", "lore") .. "Human-born starts as, and falls back to," .. F(homid .. ";") .. "Wolf-born to" .. F(lupus .. ";")
               .. "Metis to" .. F(glabro .. ".") .. "A Metis enters" .. F(crinos) .. "at any" .. kw("Rage", "rage")
               .. "(cost 10), burns it half as fast, and may leave it at 55" .. kw("Rage", "rage") .. "or below; everyone else needs 55 to enter and 75 or below to leave. <LINE>"
               .. kw("Coat:", "lore") .. "the fur colour of your beast forms. <LINE>"
               .. kw("Auspice:", "lore") .. "the moon you were born under sets your" .. kw("baseline", "rage") .. "(30 to 70), the Rage you drift back to when fed, watered and calm. <LINE> <LINE>"
               .. " Wolf Gear (black or camo harness and bags) can be changed any time." },
        { title = "Five forms",
          body  = B .. F(homid .. ":") .. "the human you were. Nothing marks you. <LINE>"
               .. F(glabro .. ":") .. "bigger, stronger, still passes at a distance. <LINE>"
               .. F(crinos .. ":") .. "the war form. Needs " .. need .. kw("Rage,", "rage") .. "burns 1"
               .. kw("Rage", "rage") .. "a second (one more each 90 seconds you hold it) and throws you back to human at 0. Double melee damage, "
               .. "shrugs off most flinches. Sprint into a closed wooden door to smash it (12"
               .. kw("Rage,", "rage") .. "18 if locked, plus stamina). Sprint into zombies and the first three go down "
               .. "under you; a fourth inside a few seconds stops the charge. <LINE>"
               .. F(hispo .. ":") .. "the dire wolf. Fast, tough, wears its bags as saddlebags. <LINE>"
               .. F(lupus .. ":") .. "a true wolf. Quiet, quick, harmless-looking." },
        { title = "Paws, jaws and vehicles",
          body  = B .. F(hispo) .. "and" .. F(lupus) .. "have no hands. They carry one thing in their jaws, and any bag you wear rides as saddlebags on the harness. "
               .. "No firearms (you can carry a gun, not fire, reload or rack it), no crafting, building, mechanics or siphoning. Shift back for thumb work. <LINE> <LINE>"
               .. F(crinos) .. "keeps its thumbs: tools, doors and melee work, double damage. <LINE> <LINE>"
               .. F(crinos) .. "and" .. F(hispo) .. "are too big for a car seat; shift into either while seated and you go out through the door, and the car pays for it. "
               .. F(lupus) .. "can drive, badly, as if drunk. <LINE> <LINE>"
               .. " Beast forms cannot wear shoes." .. F(homid) .. "and" .. F(glabro) .. "can, which matters once silver is on the floor. "
               .. F(glabro) .. "keeps its clothes through the shift; the other three tear out of them." },
        { title = "Rage",
          body  = B .. kw("Rage", "rage") .. "is situational. Fear, stress, pain and taking damage raise it. "
               .. "Dealing damage spends it. Being fed and watered, or howling, settles it toward your" .. kw("baseline", "rage")
               .. "(30 to 70, chosen once on the" .. kw("Startup", "action") .. "panel). Sadness, exhaustion and drowsiness drain it to 0. "
               .. "Every bad moodle level widens a band around the baseline where that settling runs at half speed. <LINE> <LINE> "
               .. "Shifts channel for six seconds near the middle of the bar (45 to 55" .. kw("Rage)", "rage")
               .. "and quicken toward either end: at 20 or 80" .. kw("Rage", "rage") .. "and beyond, any shift but"
               .. kw(crinos, "war") .. "takes one second. <LINE> <LINE> "
               .. "At 100" .. kw("Rage", "rage") .. "the beast takes over: after a countdown you are forced into"
               .. kw(crinos .. ".", "war")
               .. kw("Strip", "action") .. "before that if you want to keep your clothes. <LINE> <LINE>"
               .. kw("Resist", "action") .. "(panel button, radial slice next to Howl, or a key you bind) stops the countdown. "
               .. "Every" .. kw("Resist", "action") .. "makes the next countdown shorter, and the urge comes back after a while "
               .. "for as long as" .. kw("Rage", "rage") .. "stays over 95. Calm down or give in." },
        { title = "Clothes, Strip and Dress",
          body  = B .. " Beast forms tear whatever you wear." .. kw("Strip", "action") .. "takes it all off first,"
               .. kw("Dress", "action") .. "puts the same items back on from your bags or the floor nearby. "
               .. "Any form can dress again; the beast forms just tear it on the next shift. <LINE> <LINE> "
               .. "Hats and masks are dropped, but never damaged. "
               .. "Bags, jewelry, watches and held items are never dropped or damaged." },
        { title = "Wounds, silver and the Wyrm",
          body  = B .. F(crinos) .. "closes ordinary wounds in about 100 seconds;" .. F(hispo) .. "and" .. F(glabro) .. "take about 3 minutes 45 seconds. <LINE>"
               .. " Completed regeneration clears embedded glass and ordinary bullets, stitches and wound pain; no suturing is required for those healed wounds. <LINE>"
               .. kw("Wyrm Infection", "wyrm") .. "(a zombie bite) shows in your health panel and is purged only "
               .. "by time in" .. F(crinos .. ":") .. "about " .. math.floor(purge / 60) .. " minutes for the whole infection, "
               .. "three times that in" .. F(hispo) .. "or" .. F(glabro .. ".") .. "Bites close on the same clock. <LINE> <LINE>"
               .. kw("Silver", "silver") .. "burns wherever it touches bare skin and stops your healing there until the burn heals. "
               .. "The health panel lists the" .. kw("Silver Burn", "silver") .. "parts." },
        { title = "Silver: the hunters' edge",
          body  = B .. " Humans brave enough to hunt you have real tools. All of it is craftable from a counter or table, no skill needed unless noted. <LINE> <LINE>"
               .. kw("Silver Fragments", "silver") .. "come from four pieces of silver jewellery and pliers, or one piece of silverware. A file turns one fragment into Silver Filings (20 uses). <LINE>"
               .. kw("Silver rounds:", "silver") .. "queued in bulk: a shell takes three filings uses and pliers; a bullet two uses, file and pliers. "
               .. "Load from the gun's context menu or reload radial, gun in hand; a gun holds silver or ordinary rounds, never both. A silver round burns the wound it makes, and one that stays in burns until pulled (pliers, tweezers, forceps). <LINE> You smell worked silver before you see it. <LINE>"
               .. kw("Forged silver:", "silver") .. "a metal melee weapon, two fragments, charcoal, hammer and tongs at a forge. Permanent. "
               .. "Needs the Blacksmith level it takes to forge that weapon in the first place." },
        { title = "Silver nitrate",
          body  = B .. kw("Silver nitrate:", "silver") .. "a quarter bag of fertilizer (two uses) or one cold pack, a car battery (destroyed), fragments and any empty glass vessel (jar, beaker, bottle, glass; nothing plastic), opened with a knife, screwdriver or pliers. "
               .. "The vessel comes back full of raw silver nitrate. Set it inside a lit campfire, barbecue or stove like a pot of tainted water and it finishes on its own. <LINE>"
               .. " Silver nitrate is a fluid: pour it between containers, and never drink it (it is poison, like bleach). A litre coats five metal melee weapons anywhere, no table needed (hammers and kitchen steel included); the vessel stays, empty when the last coat is poured. "
               .. "A coat eats 10% of the weapon's condition, burns for twelve landed hits, then wears off; hover the weapon to see the hits left. Wear gloves: a charged coat burns a bare Garou hand too. <LINE> <LINE>"
               .. " Silver in a vessel does not burn: anyone can carry it. Silver rounds inside a gun do not burn either. Held or worn silver still does." },
        { title = "Silver: traps",
          body  = B .. kw("Scattered silver:", "silver") .. "right-click a floor square, or the item itself, to scatter one unit of Silver Fragments or five uses of filings there. "
               .. "It burns bare feet and paws and the pieces work their way in, stopping healing until they are pulled; shoes save Homid and Glabro, and beast forms cannot wear shoes. Anyone can pick a tile up again: right-click its square, Pick up scattered silver (bare Garou hands burn). It is a floor mark, not loot: the ground window and the furniture pick-up tool never list it. <LINE> <LINE>"
               .. kw("Silver smoke bomb:", "silver") .. "pack ten filings uses into a vanilla Smoke Bomb. Throw it like the ordinary one. "
               .. "A Garou in the smoke takes a silver burn to the face, can barely see through the stinging silver haze, gains Rage and coughs; healing there waits until the burn heals. Only a gas mask with a filter keeps the dust out. Humans breathe it like plain smoke." },
    }
    for _, pg in ipairs(pages) do
        pg.body = WTAGarou.Rich.tidy(pg.body)
    end
    return pages
end

function T.pages()
    T.PAGES = T.PAGES or T.buildPages()
    return T.PAGES
end

-- ---------------------------------------------------------------------------
-- "Don't show again" persistence.
function T.fileSeen()
    if not getFileReader then return false end
    local ok, seen = pcall(function()
        local r = getFileReader(T.SEEN_FILE, false)
        if not r then return false end
        local line, found = r:readLine(), false
        while line do
            if tostring(line):find("seen=1", 1, true) then found = true end
            line = r:readLine()
        end
        r:close()
        return found
    end)
    return ok and seen or false
end

function T.setSeen(player, seen)
    if player and player.getModData then
        pcall(function() player:getModData()[T.SEEN_KEY] = seen and true or nil end)
    end
    if getFileWriter then
        pcall(function()
            local w = getFileWriter(T.SEEN_FILE, true, false)
            if w then w:write(seen and "seen=1" or "seen=0"); w:close() end
        end)
    end
end

function T.hasSeen(player)
    if player and player.getModData then
        local ok, v = pcall(function() return player:getModData()[T.SEEN_KEY] end)
        if ok and v then return true end
    end
    return T.fileSeen()
end

function T.shouldAutoShow(player)
    if not T.ENABLED or not player then return false end
    if WTAGarou.HasGarouTrait and not WTAGarou.HasGarouTrait(player) then return false end
    return not T.hasSeen(player)
end

-- ---------------------------------------------------------------------------
-- Window.
WTAGarouTutorial = ISCollapsableWindow and ISCollapsableWindow:derive("WTAGarouTutorial") or nil

function T.pageTitle(index, total, title)
    return string.format("Werewolf Guide  %d/%d  -  %s", index, total, title)
end

if WTAGarouTutorial then
    function WTAGarouTutorial:new(x, y, player)
        local o = ISCollapsableWindow.new(self, x, y, T.WIDTH, T.HEIGHT)
        o.player          = player
        o.page            = 1
        o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.8 }
        o.borderColor     = { r = 0.45, g = 0.35, b = 0.2, a = 1 }
        o.resizable       = false
        o.drawFrame       = true
        o:setTitle("Werewolf Guide")
        return o
    end

    function WTAGarouTutorial:createChildren()
        ISCollapsableWindow.createChildren(self)
        local top, pad = self:titleBarHeight(), 10
        local btnH, btnW = 22, 80
        local textH = self.height - top - pad * 3 - btnH
        self.text = ISRichTextPanel:new(pad, top + pad, self.width - pad * 2, textH)
        self.text:initialise()
        self.text.autosetheight = false
        self.text.clip = true
        self.text.background = false
        self:addChild(self.text)

        local y = self.height - pad - btnH
        self.backBtn = ISButton:new(pad, y, btnW, btnH, "< Back", self, WTAGarouTutorial.onBack)
        self.backBtn:initialise(); self:addChild(self.backBtn)
        self.nextBtn = ISButton:new(pad + btnW + 6, y, btnW, btnH, "Next >", self, WTAGarouTutorial.onNext)
        self.nextBtn:initialise(); self:addChild(self.nextBtn)
        self.closeBtn = ISButton:new(self.width - pad - btnW, y, btnW, btnH, "Close", self, WTAGarouTutorial.onClose)
        self.closeBtn:initialise(); self:addChild(self.closeBtn)

        self.tick = ISTickBox:new(pad + (btnW + 6) * 2 + 8, y + 2, 160, btnH - 4, "", self, WTAGarouTutorial.onTick)
        self.tick:initialise()
        self.tick:addOption("Don't show again")
        self.tick:setSelected(1, T.hasSeen(self.player))
        self:addChild(self.tick)
        self:showPage(1)
    end

    function WTAGarouTutorial:showPage(index)
        local pages = T.pages()
        self.page = math.max(1, math.min(#pages, index))
        local p = pages[self.page]
        self:setTitle(T.pageTitle(self.page, #pages, p.title))
        self.text:setText(p.body)
        self.text:paginate()
        if self.backBtn then self.backBtn:setEnable(self.page > 1) end
        if self.nextBtn then self.nextBtn:setEnable(self.page < #pages) end
    end

    function WTAGarouTutorial:onBack() self:showPage(self.page - 1) end
    function WTAGarouTutorial:onNext() self:showPage(self.page + 1) end
    function WTAGarouTutorial:onTick(index, selected) T.setSeen(self.player, selected and true or false) end
    function WTAGarouTutorial:onClose() T.close() end
end

function T.open(player)
    player = player or (getSpecificPlayer and getSpecificPlayer(0)) or nil
    if not WTAGarouTutorial then return nil end
    if T.instance then T.instance:showPage(1); T.instance:setVisible(true); T.instance:addToUIManager(); return T.instance end
    local sw = getCore and getCore():getScreenWidth() or 1280
    local sh = getCore and getCore():getScreenHeight() or 720
    local win = WTAGarouTutorial:new(math.floor((sw - T.WIDTH) / 2), math.floor((sh - T.HEIGHT) / 2), player)
    win:initialise()
    win:addToUIManager()
    T.instance = win
    return win
end

function T.close()
    if T.instance then
        T.instance:setVisible(false)
        T.instance:removeFromUIManager()
        T.instance = nil
    end
end

function T.maybeShow(player)
    if T.shouldAutoShow(player) then return T.open(player) ~= nil end
    return false
end

if Events and Events.OnCreatePlayer then
    Events.OnCreatePlayer.Add(function(_index, player)
        if not T.shouldAutoShow(player) then return end
        -- One tick later: the Garou panel and UI manager are up by then.
        local function once()
            Events.OnTick.Remove(once)
            T.maybeShow(player)
        end
        Events.OnTick.Add(once)
    end)
end
