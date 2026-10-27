--[[
    WTAGarou - Testing / debug commands (v0.4.45)

    Where "/garou ..." works (0.4.45, after the Oct 7 report that none did):

    1) LUA DEBUG CONSOLE (launch with -debug). The console evaluates Lua, so
       a bare "/garou rage 100" used to fail with "unexpected symbol near
       '/'". WTAGarouVisuals.jar now patches UIDebugConsole.ProcessCommand:
       a line starting with "/garou" is rewritten to garou("rage 100") before
       the console compiles it. Plain Lua still works too:

           garou("rage 100")        WTAGarou.cmd("identity reset")
           WTAGarouSetRage(100)     WTAGarouSetForm("Hispo")
           WTAGarouGrantTrait()     WTAGarouInfo()
           WTAGarouPanicTrace(60)   WTAGarouResetIdentity()

    2) MULTIPLAYER CHAT (T). ISChat sent every "/..." line to the server as an
       admin command (SendCommandToServer), which answered "unknown command";
       the OnAddMessage hook never saw it. ISChat.onCommandEntered is now
       wrapped: "/garou ..." is handled locally and never leaves the client.
       Single player has no chat box, so use the console there.

           /garou cheats            open / close the Werewolf Cheats panel
           /garou rage 100          set rage to an exact value
           /garou rage +25          add rage
           /garou rage -25          drain rage
           /garou form Hispo        force a form INSTANTLY, skipping the channel
                                    and the rage cost
           /garou shift Hispo       run the normal channelled shift
           /garou trait             grant yourself the Werewolf (Garou) trait
           /garou untrait           remove the trait
           /garou wolfspawn         request a test wolf proxy for the current player
           /garou wolfclear         clear the tracked test wolf proxy
           /garou sex               swap male/female for model tests (single player only)
           /garou infamy 40         set infamy
           /garou identity reset    unlock true form / coat / baseline Rage (0.4.39)
           /garou info              dump current state
           /garou panictrace 60     trace panic read-only for 60 seconds
           /garou panictrace 0      stop tracing early
           /garou hudreset          restore the default panel position
           /garou reload            re-read WTAGarouDefinitions.lua
           /garou help              list these

    3) WEREWOLF CHEATS PANEL - 0.4.45: no world context entry for players any
       more; multiplayer admins still get it, everyone else opens it with
       "/garou cheats" (Reset identity lives under Diagnostics/Utility).

    Rage and form are server-authoritative, so these send a command rather than
    poking mod data directly. That means they behave identically in SP and MP.
]]

WTAGarou = WTAGarou or {}

require "WTAGarouNet"
require "WTAGarouGrant"
require "WTAGarouPanicTrace"
WTAGarou.Debug = WTAGarou.Debug or {}

local function say(text)
    if isClient() and not isServer() then
        -- MP: chat only.
        print("[WTAGarou] " .. text)
    end
    print("[WTAGarou] " .. text)
    if WTAGarou.TestPanel then WTAGarou.TestPanel.notify(text) end
    -- The testing window has a wrapped result box. Do not also spill long
    -- diagnostics across the compact main HUD while that window is open.
    if not (WTAGarou.TestPanel and WTAGarou.TestPanel.instance)
            and WTAGarou.HUD and WTAGarou.HUD.instance then
        WTAGarou.HUD.instance:setDebugLine(text)
    end
end
WTAGarou.Debug.say = say

-- ---------------------------------------------------------------------------
-- Primitives
-- ---------------------------------------------------------------------------

--- Set rage to an absolute value, or apply a signed delta.
-- @param value number
-- @param relative boolean  true = add value to current rage
function WTAGarou.Debug.setRage(value, relative)
    local player = getPlayer(); if not player then return end
    WTAGarou.Net.ToServer(player, "DebugSetRage",
        { value = tonumber(value) or 0, relative = relative == true })
end

--- Jump straight into a form. No channel, no rage cost, no cooldown.
function WTAGarou.Debug.setForm(formName)
    local player = getPlayer(); if not player then return end
    if not WTAGarou.IsValidForm(formName) then
        say("not a form: " .. tostring(formName) ..
            " (valid: " .. table.concat(WTAGarou.FormOrder, ", ") .. ")")
        return
    end
    WTAGarou.Net.ToServer(player, "DebugSetForm", { form = formName })
end

-- 0.4.39: forget the confirmed true form / coat (testing only).
function WTAGarou.Debug.resetIdentity()
    local player = getPlayer(); if not player then return end
    WTAGarou.Net.ToServer(player, "DebugResetIdentity", {})
    say("identity lock cleared; Rage panel > Startup to choose again")
end

function WTAGarou.Debug.setInfamy(value)
    local player = getPlayer(); if not player then return end
    WTAGarou.Net.ToServer(player, "DebugSetInfamy", { value = tonumber(value) or 0 })
end

function WTAGarou.Debug.grantTrait(remove)
    local player = getPlayer(); if not player then return end
    WTAGarou.Net.ToServer(player, "DebugTrait", { remove = remove == true })
end

-- 0.4.94: swap the character's sex for model testing (the vanilla body
-- under the Crinos parts differs; the parts themselves are unisex).
-- Single player only: in multiplayer the server owns the descriptor and
-- a local change would desync the other clients' view of this player.
-- Returns the new isFemale value, or nil with a reason.
function WTAGarou.Debug.swapSex(player)
    player = player or getPlayer()
    if not player then return nil, "no player" end
    if isClient and isClient() then return nil, "sex swap is single-player only (the server owns the descriptor)" end
    local desc = player.getDescriptor and player:getDescriptor() or nil
    if not (desc and desc.setFemale and desc.isFemale) then return nil, "no descriptor" end
    local female = not desc:isFemale()
    desc:setFemale(female)
    if player.setFemale then pcall(player.setFemale, player, female) end
    if player.resetModelNextFrame then pcall(player.resetModelNextFrame, player)
    elseif player.resetModel then pcall(player.resetModel, player) end
    -- the Crinos/wolf visuals are keyed by character; force them onto the new body
    if WTAGarou.Visual and WTAGarou.Visual.refresh then pcall(WTAGarou.Visual.refresh, player, true) end
    say("sex swapped: now " .. (female and "female" or "male") .. " (model test; single player)")
    return female
end

function WTAGarou.Debug.spawnWolf()
    local player = getPlayer(); if not player then return end

    WTAGarou.Net.ToServer(player, "DebugSpawnWolf", {})
    say("wolf proxy spawn requested; check console.txt for [WolfProxy]")
end

function WTAGarou.Debug.clearWolf()
    local player = getPlayer(); if not player then return end

    WTAGarou.Net.ToServer(player, "DebugClearWolf", {})
    say("wolf proxy clear requested; check console.txt for [WolfProxy]")
end

function WTAGarou.Debug.info()
    local player = getPlayer(); if not player then return end
    local d  = WTAGarou.GetData(player)
    local fd = WTAGarou.GetForm(d.form)
    say(string.format(
        "form=%s rage=%.1f/%d infamy=%.1f garou=%s model=%s scale=%.2f carry=%.1f",
        tostring(d.form), d.rage or 0, WTAGarou.Rage.MAX, d.infamy or 0,
        tostring(WTAGarou.HasGarouTrait(player)),
        tostring(fd.modelScript), fd.modelScale or 1,
        player:getMaxWeight() or 0))
    -- 0.4.45: identity and baseline.
    say(string.format("trueForm=%s coat=%s identityLocked=%s auspice=%s baseline=%d",
        tostring(d.trueForm), tostring(d.wolfCoat), tostring(d.identityLocked == true),
        tostring(d.auspiceLocked == true and d.auspice or "unset"),
        WTAGarou.BaselineRage and WTAGarou.BaselineRage(d) or 50))
end

-- ---------------------------------------------------------------------------
-- Console globals
-- ---------------------------------------------------------------------------
function WTAGarouSetRage(v)    WTAGarou.Debug.setRage(v, false) end
function WTAGarouAddRage(v)    WTAGarou.Debug.setRage(v, true)  end
function WTAGarouSetForm(f)    WTAGarou.Debug.setForm(f)        end
function WTAGarouGrantTrait()  WTAGarou.Debug.grantTrait(false) end
function WTAGarouRemoveTrait() WTAGarou.Debug.grantTrait(true)  end
function WTAGarouInfo()        WTAGarou.Debug.info()            end
function WTAGarouPanicTrace(seconds) return WTAGarou.PanicTrace.start(seconds) end
-- 0.4.40: the Lua debug console evaluates Lua, so "/garou ..." there fails
-- with "unexpected symbol near '/'". These run any chat command from the
-- console instead:  WTAGarou.cmd("identity reset")  or  garou("rage 100").
function WTAGarouResetIdentity()   WTAGarou.Debug.resetIdentity()   end
function WTAGarou.cmd(line)        return WTAGarou.Debug.handle(tostring(line or "help")) end
function garou(line)               return WTAGarou.cmd(line) end

-- ---------------------------------------------------------------------------
-- Chat command parsing
-- ---------------------------------------------------------------------------
local HELP = {
    "/garou cheats          open / close the Werewolf Cheats panel (alias: panel)",
    "/garou rage <n|+n|-n>  set or adjust rage",
    "/garou form <Form>     force a form instantly (no cost, no channel)",
    "/garou shift <Form>    run the normal channelled shift",
    "/garou trait           grant the Werewolf (Garou) trait",
    "/garou untrait         remove the Werewolf trait",
    "/garou wolfspawn       request a test wolf proxy",
    "/garou wolfclear       clear the tracked test wolf proxy",
    "/garou sex             swap the character's sex (model testing; single player only)",
    "/garou infamy <n>      set infamy",
    "/garou info            dump current state",
    "/garou panictrace [seconds]  read-only panic trace (default 60; 0 stops)",
    "/garou hudreset        restore the default panel position",
    "/garou identity reset  unlock the confirmed true form / coat / baseline Rage (testing)",
    "/garou reload          re-read WTAGarouDefinitions.lua (tuning tables), then reshift",
    "/garou wolf <on|off|status>  direct player-body prototype",
}

-- 0.4.20: one of every vanilla (or modded) item whose type contains "Silver"
-- and that can be worn, straight into the main inventory. Returns the count.
function WTAGarou.Debug.grantSilverKit()
    local player = getPlayer(); if not player then return 0 end
    local pattern = (WTAGarou.Silver and WTAGarou.Silver.NAME_PATTERN) or "[Ss]ilver"
    local added, seen = 0, {}
    -- 0.4.66: every kit item goes through WTAGarou.Grant, so a hosted game's
    -- server creates them (client-made items are invisible to it).
    local batch = WTAGarou.Grant.begin(player, "silver kit")
    local ok, err = pcall(function()
        local all = getScriptManager():getAllItems()
        for i = 0, all:size() - 1 do
            local script = all:get(i)
            local full = tostring(script:getFullName())
            local wearable = false
            pcall(function()
                -- 42.20.2: Item.getItemType() returns the ItemType enum
                -- (CLOTHING); older builds exposed getTypeString().
                local t = script.getItemType and script:getItemType()
                    or (script.getTypeString and script:getTypeString()) or nil
                wearable = (tostring(t):upper() == "CLOTHING")
            end)
            if wearable and full:find(pattern) and not seen[full] and added < 12 then
                seen[full] = true
                local before = batch.added
                WTAGarou.Grant.add(batch, full, 1)
                if batch.added > before then
                    added = added + 1
                    print("[WTAGarou][Debug] silver kit: " .. full)
                end
            end
        end
    end)
    if not ok then print("[WTAGarou][Debug] silver kit failed: " .. tostring(err)) end
    if added == 0 then
        -- Fallback: the well-known vanilla pieces (0.4.20; names as in B42 scripts).
        for _, full in ipairs({ "Base.Necklace_Silver", "Base.NecklaceLong_Silver", "Base.Ring_Silver",
                                "Base.Earring_Stud_Silver", "Base.Bracelet_ChainSilver" }) do
            local before = batch.added
            WTAGarou.Grant.add(batch, full, 1)
            if batch.added > before then added = added + 1 end
        end
    end
    -- 0.4.60: the crafting half of the kit, so the silver chain can be tested
    -- outside debug mode (Steam Deck): nitrate ingredients and tools, plus
    -- fragments and a box of shells to tip. Everything is a vanilla item; a
    -- missing script (older build) is skipped, never an error.
    local crafting = 0
    for _, entry in ipairs(WTAGarou.Debug.SILVER_CRAFT_KIT) do
        local full, count = entry[1], entry[2] or 1
        local before = batch.added
        WTAGarou.Grant.add(batch, full, count, entry.fluid)
        crafting = crafting + (batch.added - before)
    end
    if crafting > 0 then print("[WTAGarou][Debug] silver kit: " .. crafting .. " crafting item(s) " .. (batch.remote and "requested" or "added")) end
    print("[WTAGarou][Debug] silver kit: " .. WTAGarou.Grant.commit(batch))
    -- 0.4.62: say whether the Java side of the nitrate feature is live
    if WTAGarouJava then
        for _, fn in ipairs({ "coatableStatus", "nitrateStatus" }) do
            local okS, v = pcall(function() return WTAGarouJava[fn] and WTAGarouJava[fn]() end)
            if okS and v then print("[WTAGarou][Silver] " .. tostring(v)) end
        end
        pcall(WTAGarou.SilverAmmo.reportRecipeDrift)
    end
    -- 0.4.72: in multiplayer the warming is a Lua scan near the player
    if WTAGarou.NitrateSync and WTAGarou.NitrateSync.status then
        local okN, line = pcall(WTAGarou.NitrateSync.status)
        if okN and line then print("[WTAGarou][Silver] " .. tostring(line)) end
    end
    return added + crafting
end

--- 0.4.60: what `/garou silver` adds besides the wearable silver. The battery
--- comes in at full charge (vanilla CarBattery1 spawns drained or not; the
--- recipe takes it either way). 0.4.62: ONE fertilizer bag: the recipe's
--- `item 2 [Base.Fertilizer]` is two USES of a drainable bag (eight per bag,
--- CraftRecipeManager takes uses from one item unless the input says
--- ItemCount), so two bags was overkill. Leather gloves, because a silvered
--- weapon burns a bare Garou hand while its coat is charged. 0.4.63: twenty
--- Silver Fragments (Oct 16 request); file them into Silver Filings for rounds.
--- 0.4.74: a SECOND jar arrives already holding a litre of finished silver
--- nitrate (five coats), so coating and silver-strike tests never wait on
--- the cooking step. The empty jar is still there for the mix/cook chain.
WTAGarou.Debug.SILVER_CRAFT_KIT = {
    { "Base.Fertilizer",   1 },
    { "Base.Coldpack",     2 },
    { "Base.CarBattery1",  1 },
    { "Base.Pliers",       1 },
    { "Base.File",         1 },
    { "Base.Screwdriver",  1 },
    { "Base.EmptyJar",     1 },
    { "Base.EmptyJar",     1, fluid = { name = "WTAGarou_SilverNitrate", litres = 1.0 } },
    { "Base.SilverScrap",  20 },
    { "Base.ShotgunShellsBox", 1 },
    { "Base.Gloves_LeatherGloves", 1 },
    { "Base.SmokeBomb", 2 },                 -- 0.4.81: repack into silver smoke bombs
    { "WTAGarou.SilverSmokeBomb", 2 },       -- 0.4.81: two ready to throw
    { "WTAGarou.SilverFilings", 2 },         -- 0.4.81: for scatter + repack without filing first
}

-- 0.4.20: flag the held firearm's rounds as silver (WTAGarou_SilverAmmo).
--- 0.4.22: reload the Definitions file in place so MouthCarry / Saddlebag /
--- WolfGait / form tables can be tuned without restarting the game.
--- 0.4.24: Kahlua has NO loadstring (the September 27 console: "reload
--- failed: Object tried to call nil in pcall"), so the engine's own
--- reloadLuaFile is used with the path the game loaded the file under
--- (found through getLoadedLuaCount/getLoadedLua - the same call the debug
--- menu's "Reload Lua" makes). loadstring is used only where it exists
--- (test host). Definitions is a plain table-assignment file, so running it
--- twice is safe; the Guide pages are rebuilt and the local wolf is
--- re-requested so the new values reach Java. Returns a one-line report.
local function loadedDefinitionsPath(filename)
    filename=filename or "WTAGarouDefinitions.lua"
    if not (getLoadedLuaCount and getLoadedLua) then return nil end
    local count = getLoadedLuaCount() or 0
    for i = 0, count - 1 do
        local path = getLoadedLua(i)
        if type(path) == "string" and path:sub(-#filename) == filename then
            return path
        end
    end
    return nil
end
WTAGarou.Debug.loadedDefinitionsPath = loadedDefinitionsPath

function WTAGarou.Debug.reloadDefinitions(player)
    local path = "media/lua/shared/WTAGarouDefinitions.lua"
    local how
    local ok, err = pcall(function()
        local loaded = reloadLuaFile and loadedDefinitionsPath()
        if loaded then
            reloadLuaFile(loaded)
            how = "reloadLuaFile"
        elseif loadstring and getModFileReader then
            local reader = getModFileReader("WTAGarou", path, false)
            if not reader then error("no file reader") end
            local lines, line = {}, reader:readLine()
            while line ~= nil do lines[#lines + 1] = line; line = reader:readLine() end
            reader:close()
            local chunk, cerr = loadstring(table.concat(lines, "\n"), "WTAGarouDefinitions")
            if not chunk then error(cerr) end
            chunk()
            how = "loadstring (" .. #lines .. " lines)"
        elseif reloadLuaFile then
            reloadLuaFile(path)
            how = "reloadLuaFile (mod path)"
        else
            error("no reloadLuaFile and no loadstring")
        end
    end)
    if not ok then return "reload failed: " .. tostring(err) end
    local coatsOK,coatsError=pcall(function()
        local coatPath="media/lua/shared/WTAGarouWolfCoats.lua"
        if reloadLuaFile then
            reloadLuaFile(loadedDefinitionsPath("WTAGarouWolfCoats.lua") or coatPath)
        elseif loadstring and getModFileReader then
            local reader=getModFileReader("WTAGarou",coatPath,false)
            if not reader then error("coat registry reader unavailable") end
            local lines,line={},reader:readLine()
            while line~=nil do lines[#lines+1]=line; line=reader:readLine() end
            reader:close()
            assert(loadstring(table.concat(lines,"\n"),"WTAGarouWolfCoats"))()
        end
    end)
    if not coatsOK then print("[WTAGarou] coat registry reload failed: "..tostring(coatsError)) end
    if WTAGarou.Tutorial and WTAGarou.Tutorial.PAGES then WTAGarou.Tutorial.PAGES = nil end
    player = player or getPlayer()
    if player and WTAGarou.Visual then
        if WTAGarou.Visual.forgetWolf then WTAGarou.Visual.forgetWolf(player) end
        if WTAGarou.Visual.refresh then
            local refreshed, refreshError = pcall(WTAGarou.Visual.refresh, player, true)
            if not refreshed then
                return "Definitions reloaded; visual refresh failed: " .. tostring(refreshError)
            end
        end
    end
    local v = WTAGarou.VERSION or "?"
    local timing = ""
    if player and WTAGarouJava and WTAGarouJava.refreshWolfAnimations then
        local resetOK, resetError = pcall(WTAGarouJava.refreshWolfAnimations, player)
        if not resetOK then return "Definitions reloaded; animation refresh failed: " .. tostring(resetError) end
    end
    if WTAGarouJava and WTAGarouJava.wolfTimingStatus then
        local timingOK, value = pcall(WTAGarouJava.wolfTimingStatus)
        if timingOK then timing = "; Java active: " .. tostring(value) end
    end
    local sb = WTAGarou.Saddlebag or {}
    local so = sb.offset or {}
    return "Definitions " .. tostring(v) .. " reloaded via " .. tostring(how)
        .. "; saddlebag offset " .. tostring(so[1]) .. "," .. tostring(so[2]) .. "," .. tostring(so[3])
        .. "; gait slowdown " .. tostring((WTAGarou.WolfGait or {}).CYCLE_SLOWDOWN)
        .. timing .. ". Wolf animation tracks refreshed; lower STOMP_SPEED means slower."
        .. (coatsOK and " Coat list refreshed; close/reopen picker. New assets may still need restart."
            or " Coat list reload failed; see console.")
end

-- B42 AmmoType.toString() is a registry id (base:bullets_308), NOT
-- an InventoryItem key. getItemKey() supplies Base.Bullets308.
function WTAGarou.Debug.ammoItemKey(ammo)
    if ammo==nil then return nil end
    if type(ammo)~="string" then
        local ok,key=pcall(function() return ammo:getItemKey() end)
        if ok and type(key)=="string" and key~="" then return key end
        return nil
    end
    -- Legacy string getters and modded full types remain supported.
    if ammo:find(".",1,true) and not ammo:find(":",1,true) then return ammo end
    return nil
end
-- Resolve ammo/magazines from actual spawned weapons, not guessed ammo IDs.
function WTAGarou.Debug.grantFirearmKit(player)
    player=player or getPlayer()
    if not player then return "no player" end
    -- 0.4.66: items come through WTAGarou.Grant (server-made in MP), so the
    -- ammo/magazine types are read from a loose instanceItem probe, never
    -- from the granted gun (which does not exist yet on a remote client).
    local batch=WTAGarou.Grant.begin(player,"firearm kit")
    local missing=batch.missing
    local function add(full,count) return WTAGarou.Grant.add(batch,full,count) end
    for _,name in ipairs({"Base.HuntingRifle","Base.Shotgun","Base.Pistol","Base.Revolver_Short"}) do
        local before=batch.added
        add(name)
        if batch.added>before then
            local pok,probe=pcall(function() return instanceItem and instanceItem(name) or nil end)
            local gun=(pok and probe) or nil
            local ok,ammo=pcall(function() return gun and gun:getAmmoType() end)
            local key=ok and WTAGarou.Debug.ammoItemKey(ammo) or nil
            if key then add(key,60)
            else missing[#missing+1]="ammo item key for "..name end
            local mok,mag=pcall(function() return gun and gun:getMagazineType() end)
            if mok and mag and tostring(mag)~="" then add(tostring(mag),2) end
        end
    end
    for _,name in ipairs({"Base.HolsterAnkle","Base.HolsterSimple","Base.HolsterDouble","Base.HolsterShoulder",
            "Base.FlashLight_AngleHead","Base.Bag_ALICE_BeltSus","Base.Battery"}) do add(name) end
    local status=WTAGarou.Grant.commit(batch)
    return "Firearm kit: "..status.."; guns unloaded, equip/load manually."
        .. (#missing>0 and (" Missing: "..table.concat(missing,", ")) or "")
end

function WTAGarou.Debug.markSilverRounds()
    local player = getPlayer(); if not player then return "no player" end
    local weapon = player:getPrimaryHandItem()
    if not weapon or not (weapon.isRanged and weapon:isRanged()) then
        return "hold a firearm in the primary hand first"
    end
    weapon:getModData().WTAGarou_SilverAmmo = true
    return "silver rounds: " .. tostring(weapon:getDisplayName()) .. " now burns Garou it hits"
end

function WTAGarou.Debug.handle(argstring)
    local args = {}
    for word in string.gmatch(argstring or "", "%S+") do table.insert(args, word) end
    local cmd = string.lower(args[1] or "help")

    if cmd == "panel" or cmd == "cheats" then
        require "WTAGarouTestPanel"
        WTAGarouToggleTestPanel()
        return true
    end
    if cmd == "wolf" then
        local value = string.lower(args[2] or "status")
        if value == "on" or value == "off" then
            if WTAGarouDirectWolf then WTAGarouDirectWolf(value == "on") end
        elseif value == "status" then
            if WTAGarouVisualStatus then WTAGarouVisualStatus() end
        else say("usage: /garou wolf <on|off|status>") end
        return true
    end
    if cmd == "panictrace" then
        local _, message = WTAGarou.PanicTrace.start(args[2])
        say(message)
        return true
    end
    if cmd == "hudreset" then
        if WTAGarouResetHUDPosition then WTAGarouResetHUDPosition() end
        say("HUD position reset")
        return true
    end

    if cmd == "rage" then
        local raw = args[2]
        if not raw then say("usage: /garou rage <n|+n|-n>"); return true end
        local relative = (string.sub(raw, 1, 1) == "+" or string.sub(raw, 1, 1) == "-")
        local n = tonumber(raw)
        if n == nil then say("not a number: " .. raw); return true end
        WTAGarou.Debug.setRage(n, relative)
        say((relative and "rage " or "rage = ") .. raw)
        return true
    end

    if cmd == "form" then
        WTAGarou.Debug.setForm(args[2])
        return true
    end

    if cmd == "identity" then
        if args[2] == "reset" then WTAGarou.Debug.resetIdentity() else say("usage: /garou identity reset") end
        return true
    end

    if cmd == "shift" then
        local f = args[2]
        if not WTAGarou.IsValidForm(f) then
            say("not a form: " .. tostring(f)); return true
        end
        WTAGarou.RequestTransform(f)
        return true
    end

        if cmd == "trait"   then WTAGarou.Debug.grantTrait(false); say("Garou trait granted"); return true end
    if cmd == "untrait" then WTAGarou.Debug.grantTrait(true);  say("Garou trait removed"); return true end

    if cmd == "wolfspawn" then
        WTAGarou.Debug.spawnWolf()
        return true
    end
    if cmd == "sex" then
        local female, why = WTAGarou.Debug.swapSex()
        if female == nil then say(why or "sex swap failed") end
        return true
    end

    if cmd == "wolfclear" then
        WTAGarou.Debug.clearWolf()
        return true
    end

    if cmd == "infamy" then
        WTAGarou.Debug.setInfamy(args[2])
        say("infamy = " .. tostring(args[2]))
        return true
    end

    if cmd == "info" then WTAGarou.Debug.info(); return true end

    -- 0.4.20: quick silver-burn testing without hunting for jewellery.
    if cmd == "silver" then
        local n = WTAGarou.Debug.grantSilverKit()
        say("silver kit: " .. tostring(n) .. " item(s) added (wearable silver + fertilizer, car battery, pliers, file, "
            .. "screwdriver, empty jar + jar of finished silver nitrate, fragments, shells); wear silver against bare skin for "
            .. tostring((WTAGarou.Silver and WTAGarou.Silver.CONTACT_SECONDS) or 20) .. "s")
        return true
    end
    if cmd == "silverrounds" then
        say(WTAGarou.Debug.markSilverRounds())
        return true
    end
    if cmd == "gearkit" then
        local p=getPlayer()
        if not p then return true end
        local batch=WTAGarou.Grant.begin(p,"gear kit")
        for _,full in ipairs({"Base.SleepingBag_Green_Packed","Base.Bag_DuffelBagTINT",
                "Base.Bag_NormalHikingBag","Base.Wrench","Base.MeatCleaver"}) do
            WTAGarou.Grant.add(batch,full,1)
        end
        say("Gear kit: "..WTAGarou.Grant.commit(batch).." (inventory only; equip manually).")
        return true
    end
    if cmd == "firearmkit" then
        say(WTAGarou.Debug.grantFirearmKit(getPlayer()))
        return true
    end
    -- 0.4.22: re-read WTAGarouDefinitions.lua without leaving the game.
    if cmd == "reload" then
        -- No local player exists in handle(); the engine has a global
        -- `player` table which is NOT an IsoPlayer.
        say(WTAGarou.Debug.reloadDefinitions(getPlayer()))
        return true
    end

    for _, line in ipairs(HELP) do say(line) end
    return true
end

-- 0.4.45: multiplayer chat. Vanilla ISChat:onCommandEntered forwards every
-- "/..." line to the server (SendCommandToServer -> "unknown command"), so
-- "/garou ..." never reached the OnAddMessage hook below. Wrap the handler:
-- our lines are handled on this client and swallowed. The text entry keeps
-- a reference to the function it was created with, so the wrap happens at
-- load (before ISChat.instance exists) and is re-applied on game start.
WTAGarou.Debug.CHAT_PATTERN = "^%s*/garou(.*)$"
function WTAGarou.Debug.chatLine(text)
    if type(text) ~= "string" then return nil end
    local rest = string.match(text, WTAGarou.Debug.CHAT_PATTERN)
    if not rest then return nil end
    -- "/garoux" is somebody else's command.
    if rest ~= "" and not string.match(rest, "^%s") then return nil end
    return (string.gsub(rest, "^%s+", ""))
end
function WTAGarou.Debug.wrapChat()
    if not ISChat or type(ISChat.onCommandEntered) ~= "function" then return false end
    if not ISChat.WTAGarouOriginalOnCommandEntered then
        ISChat.WTAGarouOriginalOnCommandEntered = ISChat.onCommandEntered
        ISChat.onCommandEntered = function(self, ...)
            local chat = ISChat.instance or self
            local text
            pcall(function() text = chat.textEntry:getText() end)
            local body = WTAGarou.Debug.chatLine(text)
            if body then
                pcall(function() chat:unfocus() end)
                pcall(function() chat:logChatCommand(text) end)
                WTAGarou.Debug.handle(body)
                pcall(function() doKeyPress(false) end)
                chat.timerTextEntry = 20
                return
            end
            return ISChat.WTAGarouOriginalOnCommandEntered(self, ...)
        end
    end
    local inst = ISChat.instance
    if inst and inst.textEntry and inst.textEntry.onCommandEntered ~= ISChat.onCommandEntered then
        inst.textEntry.onCommandEntered = ISChat.onCommandEntered
    end
    return true
end
WTAGarou.Debug.wrapChat()
Events.OnGameStart.Add(function() WTAGarou.Debug.wrapChat() end)
-- 0.4.65: once per session, say which rule-coatable weapons the generated
-- recipe lists miss (the lists are what a Java-less hosted server uses).
Events.OnGameStart.Add(function()
    if WTAGarou.SilverAmmo and WTAGarou.SilverAmmo.reportRecipeDrift then
        pcall(WTAGarou.SilverAmmo.reportRecipeDrift)
    end
end)

-- Intercept chat before it becomes speech (kept for chat streams that do
-- not go through onCommandEntered).
Events.OnAddMessage.Add(function(message, tabId)
    if not message or not message.getText then return end
    local text = message:getText()
    if type(text) ~= "string" then return end

    local body = WTAGarou.Debug.chatLine(text)
    if not body then return end

    -- Stop it appearing over the character's head.
    pcall(function() message:setOverHeadSpeech(false) end)
    pcall(function() message:setShowInChat(false) end)

    WTAGarou.Debug.handle(body)
end)
