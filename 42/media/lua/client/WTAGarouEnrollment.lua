-- One first-load offer per character, saved by the server. No debug mode
-- needed in solo, or for ordinary MP users when the host allows it.
require "WTAGarouNet"
require "WTAGarouTraitBundle"
WTAGarou.Enrollment = WTAGarou.Enrollment or {}
local E = WTAGarou.Enrollment
local sessions = setmetatable({}, {__mode = "k"})
local function session(player)
    if not sessions[player] then sessions[player] = {} end
    return sessions[player]
end
local function close(s)
    if s.modal then s.modal:destroy(); s.modal = nil end
end
local function notify(player, text)
    print("[WTAGarou][Enrollment] " .. text)
    local hud = WTAGarou.HUDFor(player)
    if hud and hud.pushNotice then
        hud:pushNotice(text)
    elseif WTAGarou.Halo then
        WTAGarou.Halo(player, text, 0.9, 0.9, 0.75)
    end
    if WTAGarou.TestPanel and WTAGarou.TestPanel.notify then WTAGarou.TestPanel.notify(text) end
end
function E.answer(player, accept)
    if not player or player:isDead() then return end
    local s = session(player)
    close(s)
    s.done, s.pending, s.last = false, accept == true, getTimestamp()
    WTAGarou.Net.ToServer(player, "AnswerWerewolfOffer", {accept = accept == true})
end
local function show(player, s)
    if s.modal or player:isDead() then return end
    require "ISUI/ISModalDialog"
    local text = "Become a werewolf?\n\n"
        .. "Add Werewolf, Cat's Eyes, Fast Healer,\nand Hearty Appetite to this character?\n"
        .. "No trait points required.\n\n"
        .. "Replaces Slow Healer and Light Eater if present.\n"
        .. "Your other traits and learned skills are kept.\n\n"
        .. "Yes opens Werewolf Startup.\nNo keeps you human and stops this offer."
    local n = player:getPlayerNum()
    local w, h = ISModalDialog.CalcSize(440, 280, text)
    local x = getPlayerScreenLeft(n) + (getPlayerScreenWidth(n) - w) / 2
    local y = getPlayerScreenTop(n) + (getPlayerScreenHeight(n) - h) / 2
    local modal = ISModalDialog:new(x, y, w, h, text, true, player,
        function(owner, button)
            s.modal = nil -- vanilla already destroyed it
            E.answer(owner, button and button.internal == "YES")
        end, n)
    s.modal = modal
    modal:initialise()
    modal:addToUIManager()
    if modal.setAlwaysOnTop then modal:setAlwaysOnTop(true) end
    if player.getJoypadBind and player:getJoypadBind() ~= -1 and setJoypadFocus then
        modal.prevFocus = JoypadState and JoypadState.players[n + 1]
            and JoypadState.players[n + 1].focus or nil
        setJoypadFocus(n, modal)
    end
end
-- Only invoked after the normal client router resolves the recipient.
function E.receive(player, args)
    local s = session(player)
    if player:isDead() then close(s); s.done = true; return end
    local status = args.status
    if status == "offer" then
        if not s.done and s.pending == nil then show(player, s) end
        return
    end
    close(s)
    local d = WTAGarou.GetData(player)
    if status == "accepted" or status == "removed" then
        local ok, reason = WTAGarou.TraitBundle.apply(player, status == "removed")
        if not ok then
            notify(player, "Server replied, but local traits could not update: " .. reason)
            s.done = false
            s.last = getTimestamp() -- retry, never claim success locally
            return
        end
        d.isGarou = status == "accepted"
        if status == "removed" then d.form = "Homid" end
        if getPlayerInfoPanel then
            local panel = getPlayerInfoPanel(player:getPlayerNum())
            if panel and panel.charScreen then panel.charScreen.refreshNeeded = true end
        end
    end
    if args.decision then d.werewolfOfferDecision = args.decision end
    s.done, s.pending = true, nil
    if status == "accepted" then
        notify(player, "Werewolf, Cat's Eyes, Fast Healer and Hearty Appetite granted.")
        -- Existing HUD/Startup hooks now see a native Garou. In MP Startup
        -- requests the authoritative locked identity before opening.
    elseif status == "removed" then
        notify(player, "Werewolf removed; companion traits kept.")
    elseif status == "error" or (status == "disabled" and args.reason) then
        notify(player, args.reason or "Werewolf grant failed.")
    end
end
function E.update(player)
    if not player or (player.isLocalPlayer and not player:isLocalPlayer()) then return end
    local s = session(player)
    if player:isDead() then close(s); return end
    if s.done or s.modal then return end
    local now = getTimestamp()
    if s.last and now - s.last < 5 then return end
    s.last = now
    if s.pending ~= nil then
        WTAGarou.Net.ToServer(player, "AnswerWerewolfOffer", {accept = s.pending})
    else
        WTAGarou.Net.ToServer(player, "RequestWerewolfOffer", {})
    end
end
-- A newly created human already chose at character creation. Queue a saved
-- decline on the first update, rather than presenting a retrofit offer or
-- sending a command before the new player has entered the network/world.
if Events.OnNewGame then Events.OnNewGame.Add(function(player)
    if not player or WTAGarou.HasGarouTrait(player) then return end
    local s = session(player)
    close(s)
    s.done, s.pending, s.last = false, false, nil
end) end
if Events.OnPlayerUpdate then Events.OnPlayerUpdate.Add(E.update) end
if Events.OnPlayerDeath then Events.OnPlayerDeath.Add(function(player)
    if sessions[player] then close(sessions[player]); sessions[player] = nil end
end) end
return E
