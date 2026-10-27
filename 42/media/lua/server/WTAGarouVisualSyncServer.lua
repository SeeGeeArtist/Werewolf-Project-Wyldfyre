-- Visual replication is authored from server state, never a client-supplied
-- form/model/scale. Dedicated servers do not load the client Java renderer.
require "WTAGarouNet"
require "WTAGarouWolfCoats"
require "WTAGarouWolfGear"
WTAGarou.VisualSyncServer = WTAGarou.VisualSyncServer or {}
local Sync = WTAGarou.VisualSyncServer
local lastPoll, lastSent, sequence, previous = -1, -100, 0, nil

function Sync.collect()
    local list = getOnlinePlayers()
    local rows = {}
    for i = 0, list:size() - 1 do
        local player = list:get(i)
        local id = player:getOnlineID()
        if id and id >= 0 then
            local d = WTAGarou.GetData(player)
            local garou = WTAGarou.HasGarouTrait(player) == true
            rows[#rows + 1] = {
                id=id, username=player:getUsername(), garou=garou,
                alive=not player:isDead(),
                form=garou and WTAGarou.IsValidForm(d.form) and d.form or "Homid",
                wolfCoat=WTAGarou.ValidWolfCoat(d.wolfCoat) and d.wolfCoat or "default",
                wolfGearVariant=WTAGarou.WolfGearKey(d.wolfGearVariant),
                crinosTail=WTAGarou.CrinosTailOn(d.crinosTail),
            }
        end
    end
    table.sort(rows, function(a,b) return a.id < b.id end)
    return rows
end

function Sync.tick()
    if not isServer() then return end
    local now = getTimestamp()
    if now == lastPoll then return end
    lastPoll = now
    local rows = Sync.collect()
    local changed = not previous or #rows ~= #previous
    if not changed then
        for i, row in ipairs(rows) do
            local old = previous[i]
            if row.id ~= old.id or row.username ~= old.username or row.form ~= old.form
                    or row.garou ~= old.garou or row.alive ~= old.alive or row.wolfCoat ~= old.wolfCoat
                    or row.wolfGearVariant ~= old.wolfGearVariant
                    or row.crinosTail ~= old.crinosTail then
                changed = true; break
            end
        end
    end
    -- Heartbeats give late joiners current forms without trusting a client
    -- snapshot request. Poll once/second; send changes or a 10-second refresh.
    if not changed and now - lastSent < 10 then return end
    sequence = sequence + 1
    WTAGarou.Net.Broadcast("VisualSnapshot", {sequence=sequence, players=rows})
    previous, lastSent = rows, now
end
Events.OnTick.Add(Sync.tick)
