-- Observer-only state. Never overwrite the local player's authoritative
require "WTAGarouWolfCoats"
require "WTAGarouWolfGear"
-- gameplay data, inventory, Rage, traits, or action queue.
WTAGarou = WTAGarou or {}
WTAGarou.VisualSync = WTAGarou.VisualSync or {}
local Sync = WTAGarou.VisualSync
local snapshots, tracked = {}, {}
local lastSequence, lastPoll = -1, -1

function Sync.receive(module, command, args)
    if not isClient() or module ~= "WTAGarou" or command ~= "VisualSnapshot" then return end
    if type(args) ~= "table" or type(args.sequence) ~= "number"
            or args.sequence ~= args.sequence or args.sequence == math.huge
            or args.sequence % 1 ~= 0 or args.sequence <= lastSequence
            or type(args.players) ~= "table" then return end
    local nextState, count = {}, 0
    for _, row in pairs(args.players) do
        count = count + 1
        if count > 1024 then return end
        if type(row) ~= "table" or type(row.id) ~= "number" or row.id ~= row.id
                or row.id < 0 or row.id > 32767 or row.id % 1 ~= 0
                or type(row.username) ~= "string" or #row.username > 256
                or type(row.garou) ~= "boolean" or type(row.alive) ~= "boolean"
                or not WTAGarou.IsValidForm(row.form) or nextState[row.id]
                or (row.wolfCoat ~= nil and not WTAGarou.ValidWolfCoat(row.wolfCoat))
                or (row.wolfGearVariant ~= nil and not WTAGarou.ValidWolfGear(row.wolfGearVariant))
                or (row.crinosTail ~= nil and type(row.crinosTail) ~= "boolean") then return end
        nextState[row.id] = {username=row.username, form=row.form,
            garou=row.garou, alive=row.alive, wolfCoat=row.wolfCoat or "default",
            wolfGearVariant=WTAGarou.WolfGearKey(row.wolfGearVariant),
            crinosTail=WTAGarou.CrinosTailOn(row.crinosTail)}
    end
    snapshots, lastSequence = nextState, args.sequence
    lastPoll = -1 -- Apply immediately on the next game-thread tick.
end

function Sync.tick()
    if not isClient() or not WTAGarou.Visual or not WTAGarou.Visual.setRemoteState then return end
    local now = getTimestamp()
    if now == lastPoll then return end
    lastPoll = now
    local seen, list = {}, getOnlinePlayers()
    for i = 0, list:size() - 1 do
        local player = list:get(i)
        if not player:isLocalPlayer() then
            local state = snapshots[player:getOnlineID()]
            if state and state.username == player:getUsername() then
                seen[player] = true
                local old = tracked[player]
                local changed = not old or old.form ~= state.form or old.garou ~= state.garou
                    or old.alive ~= state.alive or old.username ~= state.username or old.wolfCoat ~= state.wolfCoat
                    or old.wolfGearVariant ~= state.wolfGearVariant
                    or old.crinosTail ~= state.crinosTail
                WTAGarou.Visual.setRemoteState(player, state, changed)
                tracked[player] = state
            end
        end
    end
    for player in pairs(tracked) do
        if not seen[player] then
            WTAGarou.Visual.setRemoteState(player, nil, true)
            tracked[player] = nil
        end
    end
end

function Sync.reset()
    if WTAGarou.Visual and WTAGarou.Visual.setRemoteState then
        for player in pairs(tracked) do WTAGarou.Visual.setRemoteState(player,nil,true) end
    end
    snapshots, tracked, lastSequence, lastPoll = {}, {}, -1, -1
end
Events.OnServerCommand.Add(Sync.receive)
Events.OnTick.Add(Sync.tick)
Events.OnGameStart.Add(Sync.reset)
