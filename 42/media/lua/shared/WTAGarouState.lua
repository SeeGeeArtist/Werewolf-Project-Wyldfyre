--[[
    WTAGarou - Player state helpers (v0.2.0).
    Persistent Garou data lives on player:getModData().WTAGarou.
    Only plain values so PZ serializes them cleanly.
]]

WTAGarou = WTAGarou or {}

-- Saved per character. Existing saves remain Human until a choice is made.
-- 0.4.39: a third breed. "Berserker" (lore: Metis) starts in and reverts to
-- Glabro, the near-human form, and treats Crinos as home ground: no Rage
-- floor to enter it, half the drain, but locked inside until Rage is low.
-- The saved key is the revert form itself: trueForm = "Glabro".
function WTAGarou.BaseForm(data)
    local t = data and data.trueForm
    if t == "Lupus" or t == "Glabro" then return t end
    return "Homid"
end
function WTAGarou.ValidTrueForm(form)
    return form=="Homid" or form=="Lupus" or form=="Glabro"
end
-- Picker / HUD label for a true-form key. Berserker deliberately matches the
-- Crinos display name on the shifting panel (user naming, 0.4.39).
WTAGarou.TRUE_FORM_LABELS = { Homid = "Human", Lupus = "Wolf", Glabro = "Berserker" }
function WTAGarou.TrueFormLabel(form)
    return WTAGarou.TRUE_FORM_LABELS[tostring(form)] or tostring(form)
end
function WTAGarou.IsBerserkerBreed(data)
    return data ~= nil and data.trueForm == "Glabro"
end
-- 0.4.39: true form and coat lock after the player confirms them once
-- (explicit flag only: saves from before 0.4.39 get exactly one more
-- confirmed choice; /garou identity reset clears it for testing).
function WTAGarou.IdentityLocked(data)
    return data ~= nil and data.identityLocked == true
end
-- 0.4.45: the Baseline Rage (auspice) lock. Saves confirmed before 0.4.45
-- have true form and coat locked but may still pick their auspice once.
function WTAGarou.AuspiceLocked(data)
    return data ~= nil and data.auspiceLocked == true
end

-- 0.4.95: the SERVER's table is authoritative and must survive client
-- modData transmissions. Vanilla ISHotbar:savePosition() calls
-- player:transmitModData() on every hotbar refresh (each clothing change,
-- and more), and the receiving ObjectModDataPacket loads nested tables by
-- replacement: the server's md.WTAGarou was swapped for the client's
-- RageSync mirror, which has no crinosCountdownAt / resist / pendingForm /
-- witness fields. Oct 26 co-op test: "the Crinos countdown kept resetting"
-- about once a second while stripping. The server keeps the table it
-- handed out per player object and re-points modData at it whenever the
-- table has been replaced from outside. Clients and single player are
-- untouched (one process, nothing transmitted).
local serverTables = {}
WTAGarou.ModDataClobbers = 0
local function serverGuard(player, md)
    local mine = serverTables[player]
    if mine == nil then
        md.WTAGarou = md.WTAGarou or {}
        serverTables[player] = md.WTAGarou
    elseif md.WTAGarou ~= mine then
        WTAGarou.ModDataClobbers = WTAGarou.ModDataClobbers + 1
        if WTAGarou.ModDataClobbers <= 3 or WTAGarou.ModDataClobbers % 100 == 0 then
            print("[WTAGarou][State] client modData transmit replaced the server's table for "
                .. tostring(player.getUsername and player:getUsername() or player) .. "; restored (#" .. WTAGarou.ModDataClobbers .. ")")
        end
        md.WTAGarou = mine
    end
    return md.WTAGarou
end
-- Forget a server table (player left; a new object on rejoin starts fresh
-- from the server's save). Called from OnDisconnect when available.
function WTAGarou.ForgetServerData(player)
    if player then serverTables[player] = nil end
end

function WTAGarou.GetData(player)
    if not player then return nil end
    local md = player:getModData()
    local d
    if isServer and isServer() then
        d = serverGuard(player, md)
    else
        md.WTAGarou = md.WTAGarou or {}
        d = md.WTAGarou
    end

    -- Defaults to FALSE: being Garou is opt-in via the character trait.
    -- WTAGarou.HasGarouTrait checks the registered CharacterTrait first and
    -- only falls back to this flag, which is what `/garou trait` toggles.
    if d.isGarou     == nil then d.isGarou     = false end
    if d.form        == nil then d.form        = WTAGarou.BaseForm(d) end
    if d.rage        == nil then d.rage        = WTAGarou.Rage.START end
    -- 0.4.45: auspice is chosen on the Werewolf Startup panel (Baseline
    -- Rage) and locked with true form and coat; nil until then.
    if d.tribe       == nil then d.tribe       = "None" end
    if d.isFrenzied  == nil then d.isFrenzied  = false end
    if d.isBSD       == nil then d.isBSD       = false end
    if d.formChangedAt == nil then d.formChangedAt = 0 end
    if d.fullRageSince == nil then d.fullRageSince = 0 end
    if d.lastFrenzyCheck == nil then d.lastFrenzyCheck = 0 end
    if d.infamy       == nil then d.infamy       = 0 end
    if d.witnesses    == nil then d.witnesses    = {} end -- witnessID -> { seenAt, form, escapedAt, isHunter }
    if d.silverBurns  == nil then d.silverBurns  = {} end -- bodyPart -> expiresAt (game minutes)

    return d
end

function WTAGarou.GetFormData(player)
    return WTAGarou.GetForm(WTAGarou.GetData(player).form)
end

function WTAGarou.IsInForm(player, formName)
    return WTAGarou.GetData(player).form == formName
end

function WTAGarou.GetRage(player)
    return WTAGarou.GetData(player).rage or 0
end

function WTAGarou.SetRage(player, value)
    local d = WTAGarou.GetData(player)
    d.rage = math.max(0, math.min(WTAGarou.Rage.MAX, tonumber(value) or 0))
    -- Track "at full rage since"
    if d.rage >= WTAGarou.Rage.MAX and d.fullRageSince == 0 then
        d.fullRageSince = getTimestamp()
    elseif d.rage < WTAGarou.Rage.MAX then
        d.fullRageSince = 0
    end
end

function WTAGarou.AddRage(player, delta)
    WTAGarou.SetRage(player, WTAGarou.GetRage(player) + (tonumber(delta) or 0))
end

function WTAGarou.GetInfamy(player)
    return WTAGarou.GetData(player).infamy or 0
end

function WTAGarou.AddInfamy(player, delta)
    local d = WTAGarou.GetData(player)
    d.infamy = math.max(0, math.min(WTAGarou.Infamy.MAX, (d.infamy or 0) + (tonumber(delta) or 0)))
end

-- Recognition distance for OTHER Garou to spot this one in Homid/Lupus form.
function WTAGarou.RecognitionTiles(player)
    local inf = WTAGarou.GetInfamy(player)
    local base = WTAGarou.Infamy.RECOGNITION_BASE_TILES
    local max  = WTAGarou.Infamy.RECOGNITION_MAX_TILES
    return base + (max - base) * (inf / WTAGarou.Infamy.MAX)
end
