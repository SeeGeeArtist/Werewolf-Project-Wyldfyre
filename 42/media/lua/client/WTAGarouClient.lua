--[[
    WTAGarou - Client bootstrap

    Handles server -> client commands and dispatches to HUD, timed actions,
    visuals, and howl sound feedback.

    Search console.txt for: [WTAGarou][Howl]
]]

WTAGarou = WTAGarou or {}

require "WTAGarouNet"
require "WTAGarouGrant"
require "WTAGarouAudio"
require "WTAGarouLocalPlayers"

-- 0.4.22: silver contact also flashes over the head (vanilla halo text, the
-- same channel as "Bandaged" / "Full"), light blue-grey like the health line.
-- There is no moodle: Build 42 has no Lua API for a custom moodle without a
-- framework mod, so the halo + panel notice + health line carry it.
-- 0.4.79: Build 42's HaloTextHelper has no getColorRGB and no
-- addText(player, text, color); the coloured halos silently did nothing
-- (the Oct 21 playtest never saw "You smell silver" over the head). The
-- real signatures are addText(player, text, separator, r, g, b) with 0-255
-- ints and addBadText/addGoodText(player, text). One helper, so every halo
-- goes through a call that exists.
WTAGarou.HALO_SEPARATOR = "[col=175,175,175], [/]"
function WTAGarou.Halo(player, text, r, g, b)
    if not (player and text) then return false end
    local H = HaloTextHelper
    if not H then return false end
    local R = math.floor(math.max(0, math.min(1, tonumber(r) or 1)) * 255 + 0.5)
    local G = math.floor(math.max(0, math.min(1, tonumber(g) or 1)) * 255 + 0.5)
    local B = math.floor(math.max(0, math.min(1, tonumber(b) or 1)) * 255 + 0.5)
    if H.addText then
        local ok = pcall(H.addText, player, tostring(text), WTAGarou.HALO_SEPARATOR, R, G, B)
        if ok then return true end
    end
    if H.addBadText then
        return pcall(H.addBadText, player, tostring(text)) == true
    end
    return false
end

local function silverColor()
    return (WTAGarou.HealthPanel and WTAGarou.HealthPanel.SILVER_COLOR) or { r = 0.7, g = 0.8, b = 0.9 }
end

function WTAGarou.SilverBurnHalo(player, part)
    if not player then return false end
    local c = silverColor()
    return WTAGarou.Halo(player, "Silver Burn: " .. tostring(part), c.r, c.g, c.b)
end

-- 0.4.41: everything a silver burn application does on the owner's client:
-- panel notice, red warning line, head halo and a per-form cue (vanilla
-- "ouch" voice for Homid/Glabro, growls for the wolf forms). Rate-limited
-- by SilverCue.COOLDOWN so a volley or a multi-part burn reacts once.
local lastSilverCue = setmetatable({}, { __mode = "k" })
-- 0.4.76: silver went in (or came out) of a part: kind "bullet" or "shard".
WTAGarou.LODGED_WORDS = { bullet = "silver-tip bullet", shard = "silver fragments" }
function WTAGarou.SilverLodgedReact(player, key, kind, lodged)
    local d = WTAGarou.GetData(player)
    if lodged then
        d.silverLodged = d.silverLodged or {}
        d.silverLodged[key] = kind or "bullet"
    elseif d.silverLodged then
        d.silverLodged[key] = nil
        local left = false                       -- no next() in Kahlua
        for _ in pairs(d.silverLodged) do left = true; break end
        if not left then d.silverLodged = nil end
    end
    local name = WTAGarou.HealthPanel and WTAGarou.HealthPanel.partName and WTAGarou.HealthPanel.partName(key)
        or (tostring(key or "body"):gsub("_", " "))
    local what = WTAGarou.LODGED_WORDS[kind] or "silver"
    local hud = WTAGarou.HUDFor and WTAGarou.HUDFor(player)
    local text
    if lodged then
        text = (kind == "shard" and "Silver fragments are" or "A silver-tip bullet is") .. " lodged in your " .. name .. ". It burns until it is pulled."
    else
        text = (kind == "shard" and "The silver fragments are" or "The silver-tip bullet is") .. " out of your " .. name .. "."
    end
    if hud and hud.pushNotice then hud:pushNotice(text) end
    if lodged and WTAGarou.SilverBurnHalo then pcall(WTAGarou.SilverBurnHalo, player, name) end
    return what
end

-- 0.4.77: the sniffer. "You smell silver" over the head and in the panel.
function WTAGarou.SilverScentReact(player, args)
    local c = silverColor()
    local text = "You smell silver"
    WTAGarou.Halo(player, text, c.r, c.g, c.b)
    local hud = WTAGarou.HUDFor and WTAGarou.HUDFor(player)
    if hud and hud.pushNotice then hud:pushNotice(text .. ". Worked silver is close.") end
    if WTAGarou.WolfVoice and WTAGarou.WolfVoice.onScent then pcall(WTAGarou.WolfVoice.onScent, player) end
    return text
end

-- 0.4.81: breathing silver dust (silver smoke bomb). Cough, halo, one log
-- line per cue; the burn itself arrives as the usual SilverBurn command.
-- 0.4.83: the server sends this every body sweep while we stand in silver
-- smoke. Every message keeps the vision veil up (WTAGarouSmokeVeil.lua);
-- the cough halo, voice and log line only fire when args.cough is set
-- (a message with no flag is treated as a cough for older servers).
function WTAGarou.SilverSmokeReact(player, args)
    local seconds = tonumber(args and args.seconds) or 0
    if WTAGarou.SmokeVeil and WTAGarou.SmokeVeil.touch and (not player or player == getPlayer()) then
        pcall(WTAGarou.SmokeVeil.touch)
    end
    local cough = args == nil or args.cough == nil or args.cough == true
    if not cough then return nil end
    local c = silverColor()
    local text = "*cough*"
    pcall(function() if getText then local t = getText("IGUI_PlayerText_Cough"); if t and t ~= "IGUI_PlayerText_Cough" then text = t end end end)
    WTAGarou.Halo(player, text, c.r, c.g, c.b)
    pcall(function() if player.playerVoiceSound then player:playerVoiceSound("Cough") end end)
    local hud = WTAGarou.HUDFor and WTAGarou.HUDFor(player)
    if hud and hud.pushNotice then
        hud:pushNotice(seconds < 1 and "Silver dust. The smoke burns your eyes and throat." or "Silver dust still burns your eyes. Get out of the smoke.")
    end
    return text
end

function WTAGarou.SilverReact(player, part, now)
    if not player then return false end
    part = (tostring(part or "body"):gsub("_", " "))
    local hud = WTAGarou.HUDFor(player)
    if hud and hud.pushNotice then hud:pushNotice("Silver burns your " .. part .. ".") end
    if hud and hud.flashSilverBurn then hud:flashSilverBurn(part) end
    WTAGarou.SilverBurnHalo(player, part)
    local cue = WTAGarou.SilverCue
    if not cue then return true end
    now = now or (WTAGarou.NowSeconds and WTAGarou.NowSeconds()) or os.time()
    local last = lastSilverCue[player]
    if last and (now - last) < cue.COOLDOWN then return true, nil end
    lastSilverCue[player] = now
    local form = WTAGarou.GetData and WTAGarou.GetData(player).form or "Homid"
    local name = cue.forForm(form)
    if cue.isVoice(name) then
        local ok = player.playerVoiceSound and pcall(function() player:playerVoiceSound(name) end)
        if not ok and WTAGarou.Audio then WTAGarou.Audio.play(player, name) end
    elseif WTAGarou.Audio then
        WTAGarou.Audio.play(player, name)
    end
    return true, name
end
WTAGarou.SilverReactReset = function(player) lastSilverCue[player] = nil end

local function handleServerCommand(module, command, args, directPlayer)
    if module ~= "WTAGarou" then return end
    args = args or {}
    -- Broadcast audio belongs to its explicit owner, not the local recipient.
    if command == "HowlStarted" or command == "HowlStopped" then
        print("[WTAGarou][Howl] client broadcast "..command.." owner="..tostring(args.ownerID))
        local H=WTAGarou.Howl
        local fn=H and (command=="HowlStarted" and H.onStarted or H.onStopped)
        if fn then fn(args)
        else print("[WTAGarou][Howl] client error: Howl feedback module unavailable") end
        return
    end

    local player = WTAGarou.Net.ClientPlayer(args, directPlayer)
    if not player then return end
    local hud=WTAGarou.HUDFor(player)
    if WTAGarou.Grant and command == WTAGarou.Grant.REPLY then
        -- 0.4.66: the server made the kit items (MP inventories are server-owned)
        local text = WTAGarou.Grant.describeReply(args)
        print("[WTAGarou][Grant] " .. text)
        if WTAGarou.TestPanel and WTAGarou.TestPanel.notify then WTAGarou.TestPanel.notify(text) end
        if hud and hud.pushNotice then hud:pushNotice(text) end
        return
    end
    if command == "WolfCoatSelected" then
        if WTAGarou.WolfCoat then WTAGarou.WolfCoat.receive(args, player) end
        return
    end

    if command == "RageSync" then
        local d = WTAGarou.GetData(player)
        d.rage = args.rage or d.rage
        d.form = args.form or d.form
        d.infamy = args.infamy or d.infamy
        d.infectionBurn = args.wyrm   -- nil = no Wyrm Infection (0.4.18)
        if args.silver ~= nil then d.silverBurns = args.silver end   -- 0.4.22
        if args.lodged ~= nil or isClient() then d.silverLodged = args.lodged end   -- 0.4.76 (nil = nothing lodged)
        if args.bracket ~= nil then d.bracketHalfWidth = tonumber(args.bracket) end   -- 0.4.69 HUD
        if WTAGarou.ValidTrueForm(args.trueForm) then d.trueForm=args.trueForm end
        if args.identityLocked ~= nil then d.identityLocked = args.identityLocked == true or nil end
        -- 0.4.45 auspice / baseline Rage (nil = not chosen yet).
        if args.auspiceLocked ~= nil then
            d.auspiceLocked = args.auspiceLocked == true or nil
            d.auspice = WTAGarou.ValidAuspice(args.auspice) and args.auspice or nil
        end

        if WTAGarou.Visual then WTAGarou.Visual.refresh(player, false) end
        if hud then
            hud:refresh()
        end
        return
    end

    -- 0.4.17: dedicated server told us a body part started a silver burn.
    if command == "SilverLodged" then   -- 0.4.76
        WTAGarou.SilverLodgedReact(player, args.part, args.kind, args.lodged == true)
        return
    end
    if command == "SilverScent" then    -- 0.4.77
        WTAGarou.SilverScentReact(player, args)
        return
    end
    if command == "SilverSmoke" then    -- 0.4.81
        WTAGarou.SilverSmokeReact(player, args)
        return
    end
    if command == "SilverBurn" then
        WTAGarou.SilverReact(player, args.part)
        return
    end
    -- 0.4.72: another player landed a silver hit on us; burn our own body.
    if command == "SilverHitRelay" then
        if WTAGarou.Silver and WTAGarou.Silver.applyRelayedHit then WTAGarou.Silver.applyRelayedHit(player, args) end
        return
    end

    if command == "TransformAccepted" then
        if WTAGarou.TestPanel then
            WTAGarou.TestPanel.notify((args.forced and "FORCED shift: " or "Shift accepted: ")
                .. tostring(args.form) .. ". Channel started.")
        end
        if args.forced and hud then
            hud:clearCrinosCountdown()
            hud:flashDenial("frenzy_forced")
        end
        if WTAGarou.Channel then
            WTAGarou.Channel.startChannel(
                player,
                args.form,
                args.seconds or 5.0,
                args.previousForm or "Homid"
            )
        end
        return
    end

    if command == "TransformCompleted" or command == "TransformForced" then
        if command == "TransformForced" then
            -- Server changed the form outright (Crinos ran dry). Drop any
            -- channel in flight so its confirm/cancel cannot fight the server.
            if WTAGarou.Channel and WTAGarou.Channel.abort then
                WTAGarou.Channel.abort(player)
            end
            if WTAGarou.TestPanel then
                WTAGarou.TestPanel.notify("Forced back to " .. tostring(args.form)
                    .. " (" .. tostring(args.reason) .. ")")
            end
            if hud then
                hud:clearCrinosCountdown()
                hud:flashDenial(args.reason or "rage_depleted")
            end
            -- 0.4.19: the 0-Rage return to Homid has its own cue.
            if args.form == "Homid" and WTAGarou.ShiftSoundsRuntime
                and WTAGarou.ShiftSoundsRuntime.onForcedHomid then
                pcall(WTAGarou.ShiftSoundsRuntime.onForcedHomid, player)
            end
        elseif WTAGarou.TestPanel then
            WTAGarou.TestPanel.notify("Form confirmed: " .. tostring(args.form))
        end
        local d = WTAGarou.GetData(player)
        d.form = args.form or d.form
        if hud then
            hud:clearCrinosCountdown()
            hud:clearChannelling()
        end

        -- 0.4.18: the Crinos arrival cue, once per confirmed shift.
        if WTAGarou.ShiftSoundsRuntime then
            pcall(WTAGarou.ShiftSoundsRuntime.onTransformCompleted, player, args)
        end

        if WTAGarou.Visual then WTAGarou.Visual.refresh(player, true) end
        if WTAGarou.Slots then WTAGarou.Slots.enforce(player, d.form) end
        if WTAGarou.Clothing and WTAGarou.Clothing.dropForbidden then
            if isClient() and not isServer() then
                -- 0.4.66: in multiplayer the SERVER stripped (it owns the
                -- inventory) and attached the result; only present it here.
                if type(args.strip) == "table" and WTAGarou.Clothing.presentStrip then
                    WTAGarou.Clothing.presentStrip(player, args.strip)
                end
            else
                -- 0.4.16: a Rage-forced Crinos tears twice as hard (same holes)
                WTAGarou.Clothing.dropForbidden(player, d.form, { forced = args.forced == true })
            end
            if WTAGarou.Visual and WTAGarou.Visual.refreshSaddlebag then
                WTAGarou.Visual.refreshSaddlebag(player)
            end
        end
        if hud then
            hud:refresh()
        end

        -- Observer visuals are now published from server state by
        -- WTAGarouVisualSyncServer, never from a client-supplied form.
        return
    end

    if command == "CrinosCountdown" then
        if hud then
            hud:startCrinosCountdown(args.seconds or 15)
        end
        -- One timer cue when the countdown starts, never looped (0.4.18:
        -- WTAGarou_CrinosShiftTimer via the shift-sound runtime).
        if WTAGarou.ShiftSoundsRuntime then
            pcall(WTAGarou.ShiftSoundsRuntime.onCountdown, player)
        else
            pcall(function()
                WTAGarou.Audio.play(player, WTAGarou.CrinosCountdownSound or "WTAGarou_CrinosGrowl")
            end)
        end
        if hud and hud.pushNotice then
            hud:pushNotice(string.format("The Beast rises: Berzerker in %.0f s. Resist to hold it.", tonumber(args.seconds) or 0))
        end
        print("[WTAGarou][Rage] Crinos countdown started: " .. tostring(args.seconds) .. "s")
        return
    end

    -- 0.4.69: the server's passive Crinos drain stepped up (every 90 s held).
    if command == "CrinosDrain" then
        local d = WTAGarou.GetData and WTAGarou.GetData(player) or nil
        if d then d.crinosDrainPerSecond = args.perSecond; d.crinosEscalationSteps = args.steps end
        -- 0.4.78: in the panel log, not over the (very tall) Crinos head.
        if (args.steps or 0) > 0 and hud and hud.pushNotice then
            hud:pushNotice(string.format("The beast burns hotter: %.1f Rage/s (held %.0f s)", -(args.perSecond or 1), args.held or 0))
        end
        print(string.format("[WTAGarou][Rage] Crinos drain now %.2f/s (step %d, held %.0fs)",
            args.perSecond or 0, args.steps or 0, args.held or 0))
        return
    end

    if command == "CrinosCountdownCancelled" then
        if hud then
            hud:clearCrinosCountdown()
            if hud.pushNotice and args.reason ~= "in_crinos" then
                hud:pushNotice(args.reason == "rage_dropped" and "The Beast settles: Rage fell back." or "Countdown stopped.")
            end
        end
        print("[WTAGarou][Rage] Crinos countdown cancelled: " .. tostring(args.reason))
        return
    end

    -- 0.4.21 Resist outcome: the panel says what happened; the hidden rest
    -- interval is never shown (only the next countdown length is).
    if command == "ResistResult" then
        local hud = WTAGarou.HUDFor(player)
        if args.ok then
            local text = string.format("Resisted the change (x%d). Next warning lasts %.1fs.",
                tonumber(args.resists) or 1, tonumber(args.nextSeconds) or 0)
            if hud and hud.pushNotice then hud:pushNotice(text) end
            print("[WTAGarou][Resist] " .. text)
        else
            if hud and hud.pushNotice then hud:pushNotice("Nothing to resist.") end
            print("[WTAGarou][Resist] nothing to resist")
        end
        return
    end

    if command == "ResistReset" then
        local hud = WTAGarou.HUDFor(player)
        if hud and hud.pushNotice and (tonumber(args.resists) or 0) > 0 then
            hud:pushNotice("The urge to change fades.")
        end
        print("[WTAGarou][Resist] cycle reset: " .. tostring(args.reason))
        return
    end

    -- 0.4.39: the server resolved a bulk-form shift inside a vehicle. Only
    -- the owning client may leave its own seat (vanilla ISExitVehicle path),
    -- and body damage is client-owned in multiplayer, so the engine's
    -- bare-handed window cut is applied here when the glass went.
    if command == "VehicleEjected" then
        local vehicle = player.getVehicle and player:getVehicle() or nil
        if vehicle then
            local ok, err = pcall(function() vehicle:exit(player) end)
            if not ok then print("[WTAGarou][VehicleShift] exit failed: " .. tostring(err)) end
            -- 0.4.40: metal impact from the vehicle when the shift damaged it.
            local impact = WTAGarou.VehicleShift and WTAGarou.VehicleShift.IMPACT_SOUND
            if impact and impact ~= "" and (tonumber(args.points) or 0) > 0 then
                local played = pcall(function() vehicle:playSound(impact) end)
                if not played then print("[WTAGarou][VehicleShift] impact sound failed: " .. tostring(impact)) end
            end
        end
        if args.smashed then
            pcall(function() player:getBodyDamage():setScratchedWindow() end)
            if player.playerVoiceSound then pcall(function() player:playerVoiceSound("PainFromGlassCut") end) end
        end
        if hud and hud.pushNotice then
            hud:pushNotice(args.smashed and "You burst out through the glass."
                or "You burst out of the vehicle.")
        end
        print("[WTAGarou][VehicleShift] client ejected form=" .. tostring(args.form)
            .. " seat=" .. tostring(args.seat) .. " smashed=" .. tostring(args.smashed)
            .. " points=" .. tostring(args.points))
        if WTAGarou.Visual then WTAGarou.Visual.refresh(player, true) end
        return
    end

    if command == "TransformDenied" then
        if WTAGarou.TestPanel then
            WTAGarou.TestPanel.notify("Shift denied: " .. tostring(args.reason))
        end
        if hud then
            hud:flashDenial(args.reason)
        end
        return
    end

    if command == "HowlAccepted" then
        print("[WTAGarou][Howl] client accepted")
        if WTAGarou.Channel then
            WTAGarou.Channel.startHowl(player)
        else
            print("[WTAGarou][Howl] client error: Channel module unavailable")
        end
        return
    end

    if command == "FrenzyForced" then
        if hud then
            hud:flashDenial("frenzy_forced")
        end
        return
    end
end

Events.OnServerCommand.Add(handleServerCommand)
WTAGarou.Net.RegisterClientHandler(handleServerCommand)

function WTAGarou.RequestTransform(formName, player)
    player = player or getPlayer()
    if not player then return end
    local hud=WTAGarou.HUDFor(player)

    if not WTAGarou.HasGarouTrait(player) then
        if hud then
            hud:flashDenial("not_a_garou")
        end
        return
    end

    WTAGarou.Net.ToServer(player, "TransformRequest", { form = formName })
end

-- 0.4.21: Resist the forced Crinos countdown (HUD button, keybind, radial).
function WTAGarou.RequestResist(player)
    player = player or getPlayer()
    if not player then return end
    if not WTAGarou.HasGarouTrait(player) then return end
    print("[WTAGarou][Resist] client request")
    WTAGarou.Net.ToServer(player, "ResistRequest", {})
end

function WTAGarou.RequestHowl(player)
    player = player or getPlayer()
    if not player then return end

    if not WTAGarou.HasGarouTrait(player) then return end

    print("[WTAGarou][Howl] client request")
    WTAGarou.Net.ToServer(player, "HowlRequest", {})
end

function WTAGarou.IsChannelling(player)
    player = player or getPlayer()
    if not player then return false end

    local q = ISTimedActionQueue.getTimedActionQueue(player)
    if not q or not q.queue then return false end

    for _, action in ipairs(q.queue) do
        if action.Type == "WTAGarouTransformAction" or action.Type == "WTAGarouHowlAction" then
            return true
        end
    end

    return false
end
