--[[
    WTAGarou - Umbra / Gnosis / Spirit Gifts (v0.2.0 STUB)

    Reserved API for v0.3. Right now we only:
      - Persist a Gnosis stat per player (0..100)
      - Read Gift books to add stat marks

    Umbra fast-travel and spirit-gift effects (rat -> Electrical, spider ->
    Electronics, wolf -> Trapping) are queued but not applied in-game yet.
]]

WTAGarou = WTAGarou or {}
WTAGarou.Umbra = WTAGarou.Umbra or {}

local function ensureGnosis(player)
    local d = WTAGarou.GetData(player)
    if d.gnosis == nil then d.gnosis = 0 end
    return d
end

Events.OnCreatePlayer.Add(function(_, player) ensureGnosis(player) end)

-- Reading a Gift book bumps gnosis and stores a pending gift for v0.3.
Events.OnPlayerAttackFinished = Events.OnPlayerAttackFinished or nil
if Events.OnLiteratureReadFinished then
    Events.OnLiteratureReadFinished.Add(function(player, item)
        if not item or not item.getFullType then return end
        local ft = item:getFullType()
        local d  = ensureGnosis(player)
        if ft == "WTAGarou.GiftRatSpirit" then
            d.gnosis = math.min(100, (d.gnosis or 0) + 5)
            d.pendingGifts = d.pendingGifts or {}
            table.insert(d.pendingGifts, "RatSpirit")
        elseif ft == "WTAGarou.GiftSpiderSpirit" then
            d.gnosis = math.min(100, (d.gnosis or 0) + 5)
            d.pendingGifts = d.pendingGifts or {}
            table.insert(d.pendingGifts, "SpiderSpirit")
        elseif ft == "WTAGarou.GiftWolfSpirit" then
            d.gnosis = math.min(100, (d.gnosis or 0) + 5)
            d.pendingGifts = d.pendingGifts or {}
            table.insert(d.pendingGifts, "WolfSpirit")
        end
    end)
end
