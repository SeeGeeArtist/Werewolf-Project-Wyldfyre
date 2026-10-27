--[[
    WTAGarou - Witness / Delirium dispatcher (v0.3.1)

    Resolves player and Bandits/Bandits Week One witnesses by stable adapter ID,
    applies the configured flee/attack response, and removes confirmed dead
    witnesses before they can generate Infamy.
]]

WTAGarou = WTAGarou or {}

require "WTAGarouNet"

-- 0.4.76: `getPlayerFromRealName` does not exist and `getPlayerFromUsername`
-- is client-side; on a hosted/dedicated server every DeliriumReport that
-- named a player witness raised "Object tried to call nil" (1137 times in
-- one Oct 19 session). Resolve names through whatever the side offers.
local function playerByName(name)
    if not name or name == "" then return nil end
    if getPlayerFromUsername then
        local ok, p = pcall(getPlayerFromUsername, name)
        if ok and p then return p end
    end
    if getOnlinePlayers then
        local ok, list = pcall(getOnlinePlayers)
        if ok and list then
            for i = 0, list:size() - 1 do
                local p = list:get(i)
                if p and p.getUsername and p:getUsername() == name then return p end
            end
        end
    end
    return nil
end
WTAGarou.WitnessPlayerByName = playerByName

local function handleWitnessCommand(module, command, player, args)
    if module ~= "WTAGarou" or not player then return end
    args = args or {}

    if command == "WitnessDeath" then
        local d = WTAGarou.GetData(player)
        for id, dead in pairs(args.witnesses or {}) do
            if dead then d.witnesses[id] = nil end
        end
        return
    end

    if command ~= "DeliriumReport" then return end
    if WTAGarou.Delirium and WTAGarou.Delirium.ENABLED == false then return end   -- 0.4.79 dormant

    local d = WTAGarou.GetData(player)
    if not WTAGarou.IsSupernatural(d.form) then return end

    local tier = WTAGarou.GetForm(d.form).deliriumTier or 0
    for _, w in ipairs(args.witnesses or {}) do
        local npc
        if w.name and w.name ~= "" then
            npc = playerByName(w.name)
        end
        if not npc then
            npc = WTAGarou.Adapters.findHumanByID(
                tostring(w.id or ""), w.x, w.y, w.z, 2)
        end

        -- 0.4.79: a player is never a witness
        local isPlayerChar = npc ~= nil and (
            (instanceof and (function() local ok, r = pcall(instanceof, npc, "IsoPlayer"); return ok and r end)())
            or npc.getUsername ~= nil)
        if isPlayerChar and not (WTAGarou.Delirium and WTAGarou.Delirium.PLAYERS_WITNESS) then npc = nil end
        if npc and npc ~= player and not WTAGarou.Adapters.isGarou(npc) then
            if tier >= 3 and WTAGarou.Adapters.isBrave(npc) then
                WTAGarou.Adapters.makeAttack(npc, player)
            elseif tier >= 1 then
                WTAGarou.Adapters.makeFlee(npc, player)
            end
        end
    end
end

Events.OnClientCommand.Add(handleWitnessCommand)
WTAGarou.Net.RegisterServerHandler(handleWitnessCommand)
