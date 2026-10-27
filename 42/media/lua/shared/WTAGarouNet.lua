--[[
    WTAGarou - Command routing (v0.3.3)

    Routes the server-authoritative protocol through the normal PZ network in
    multiplayer and directly between registered handlers in single player.
    Multiple server handlers are supported so witness/Delirium commands use
    the same path as transformations instead of disappearing in local games.
]]

WTAGarou = WTAGarou or {}
WTAGarou.Net = WTAGarou.Net or {}
require "WTAGarouLocalPlayers"

local Net = WTAGarou.Net

Net._serverHandlers = Net._serverHandlers or {}
Net._clientHandler  = Net._clientHandler or nil

function Net.IsSinglePlayer()
    return not isServer() and not isClient()
end

function Net.RegisterServerHandler(fn)
    if not fn then return end
    for _, registered in ipairs(Net._serverHandlers) do
        if registered == fn then return end
    end
    table.insert(Net._serverHandlers, fn)
    -- Preserve the old field for compatibility with diagnostics or add-ons.
    Net._serverHandler = fn
end

function Net.RegisterClientHandler(fn)
    Net._clientHandler = fn
end

function Net.ToServer(player, command, args)
    if not player then return end
    args = args or {}

    if Net.IsSinglePlayer() then
        if #Net._serverHandlers > 0 then
            for _, handler in ipairs(Net._serverHandlers) do
                handler("WTAGarou", command, player, args)
            end
        elseif Net._serverHandler then
            Net._serverHandler("WTAGarou", command, player, args)
        else
            print("[WTAGarou] Net.ToServer: no server handler registered. " ..
                  "command=" .. tostring(command))
        end
        return
    end

    sendClientCommand(player, "WTAGarou", command, args)
end

function Net.ToClient(player, command, args)
    args = args or {}

    if Net.IsSinglePlayer() then
        if Net._clientHandler then
            Net._clientHandler("WTAGarou", command, args, player)
        else
            print("[WTAGarou] Net.ToClient: no client handler registered. " ..
                  "command=" .. tostring(command))
        end
        return
    end

    if not player then return end
    -- PZ delivers OnServerCommand to a connection, not a specific local
    -- split-screen character. Stamp the authoritative reply destination.
    -- Never mutate a reusable payload or trust an incoming destination.
    local routed={}
    for k,v in pairs(args) do routed[k]=v end
    routed._wtaRecipientID=nil
    if player.getOnlineID then
        local id=tonumber(player:getOnlineID())
        if id and id>=0 then routed._wtaRecipientID=id end
    end
    sendServerCommand(player, "WTAGarou", command, routed)
end

function Net.ClientPlayer(args, directPlayer)
    if directPlayer and Net.IsSinglePlayer() then return directPlayer end
    local players=WTAGarou.LocalPlayers()
    if args and args._wtaRecipientID~=nil then
        local wanted=tonumber(args._wtaRecipientID)
        if not wanted or wanted<0 then return nil end
        for _,p in ipairs(players) do
            if p.getOnlineID and p:getOnlineID()==wanted then return p end
        end
        return nil -- unknown/stale/remote recipient: never touch player 0
    end
    -- Compatibility with an older server is safe only with ONE local actor.
    if #players==1 then return players[1] end
    return nil
end

function Net.Broadcast(command, args)
    args = args or {}

    if Net.IsSinglePlayer() then
        if Net._clientHandler then Net._clientHandler("WTAGarou", command, args) end
        return
    end

    sendServerCommand("WTAGarou", command, args)
end

print("[WTAGarou] Net loaded. singlePlayer=" .. tostring(Net.IsSinglePlayer()))
