--[[
    WTAGarou - NPC mod adapters (v0.3.1)

    Detects Knox Event Expanded NPCs and Bandits/Bandits Week One. Bandits
    Week One depends on the core Bandits framework, so both are handled through
    the same Bandit/ BanditBrain API without modifying either upstream mod.
]]

WTAGarou = WTAGarou or {}
WTAGarou.Adapters = WTAGarou.Adapters or {}

local A = WTAGarou.Adapters
A.hasKnox    = A.hasKnox or false
A.hasBandits = A.hasBandits or false

local function detect()
    A.hasKnox = _G.KnoxEventExpandedNpc ~= nil or _G.KENpc ~= nil
    A.hasBandits = _G.Bandit ~= nil or _G.BanditBrain ~= nil
    return A.hasKnox, A.hasBandits
end

detect()

function A.summary()
    detect()
    return string.format("Knox=%s Bandits=%s", tostring(A.hasKnox), tostring(A.hasBandits))
end

function A.isBandit(char)
    if not char or not char.getModData then return false end
    local md
    local ok = pcall(function() md = char:getModData() end)
    if not ok or not md then return false end
    if md.brain ~= nil then return true end
    if _G.BanditBrain and BanditBrain.Get then
        local brain
        ok = pcall(function() brain = BanditBrain.Get(char) end)
        if ok and brain ~= nil then return true end
    end
    return false
end

function A.getCharacterID(char)
    if not char then return "missing" end
    if A.isBandit(char) and _G.BanditUtils and BanditUtils.GetCharacterID then
        local ok, id = pcall(function() return BanditUtils.GetCharacterID(char) end)
        if ok and id ~= nil then return "bandit:" .. tostring(id) end
    end
    if char.getOnlineID then
        local ok, id = pcall(function() return char:getOnlineID() end)
        if ok and id ~= nil and id ~= -1 then return "player:" .. tostring(id) end
    end
    if char.getPersistentOutfitID then
        local ok, id = pcall(function() return char:getPersistentOutfitID() end)
        if ok and id ~= nil then return "npc:" .. tostring(id) end
    end
    return tostring(char)
end

function A.getHumansInRange(centerX, centerY, centerZ, tileRadius)
    detect()
    local out, added = {}, {}
    local cell = getCell()
    if not cell then return out end

    local function add(char)
        if not char then return end
        local dead = false
        if char.isDead then pcall(function() dead = char:isDead() end) end
        if dead then return end
        if math.abs(char:getX() - centerX) > tileRadius
           or math.abs(char:getY() - centerY) > tileRadius
           or char:getZ() ~= centerZ then return end
        local id = A.getCharacterID(char)
        if not added[id] then
            added[id] = true
            table.insert(out, char)
        end
    end

    local players = getOnlinePlayers()
    if players then
        for i = 0, players:size() - 1 do add(players:get(i)) end
    else
        add(getPlayer and getPlayer() or nil)
    end

    -- Bandits and Bandits Week One NPCs are IsoZombie objects with a `brain`
    -- entry in mod data. The old adapter checked non-existent `Bandit` and
    -- `BanditsWeekOne` flags, which made every NPC invisible to Delirium.
    if A.hasBandits and cell.getZombieList then
        local zl = cell:getZombieList()
        if zl then
            for i = 0, zl:size() - 1 do
                local z = zl:get(i)
                if A.isBandit(z) then add(z) end
            end
        end
    end

    return out
end

function A.findHumanByID(id, x, y, z, radius)
    local list = A.getHumansInRange(x, y, z, radius or 2)
    for _, char in ipairs(list) do
        if A.getCharacterID(char) == tostring(id) then return char end
    end
    return list[1]
end

function A.isGarou(char)
    if not char then return false end
    local md = char:getModData()
    return md and md[WTAGarou.Tags.GAROU] == true
end

function A.isBlackSpiral(char)
    if not char then return false end
    local md = char:getModData()
    return md and md[WTAGarou.Tags.BSD] == true
end

function A.isHunter(char)
    if not char then return false end
    local md = char:getModData()
    if md and md[WTAGarou.Tags.HUNTER] == true then return true end
    if A.isBandit(char) then
        local brain = md and md.brain
        if brain and brain.exp and _G.Bandit and Bandit.Expertise then
            for _, exp in pairs(brain.exp) do
                if exp == Bandit.Expertise.Assasin
                   or exp == Bandit.Expertise.Recon
                   or exp == Bandit.Expertise.Tracker then return true end
            end
        end
    end
    return false
end

-- Resolve a vanilla trait object from its script name ("Brave"). Returns nil
-- (never raises) when the registry or the trait is missing. 0.4.66.
local traitCache = {}
function WTAGarou.Adapters.traitByName(name)
    if type(name) ~= "string" or name == "" then return nil end
    if traitCache[name] ~= nil then return traitCache[name] or nil end
    local found = nil
    if CharacterTrait then
        local upper = name:gsub("(%l)(%u)", "%1_%2"):upper()
        local okF, field = pcall(function() return CharacterTrait[upper] end)
        if okF and field ~= nil and type(field) ~= "function" then found = field end
        if not found and CharacterTrait.get and ResourceLocation and ResourceLocation.of then
            -- ResourceLocation.of lower-cases and defaults the namespace
            local okL, loc = pcall(ResourceLocation.of, name)
            if okL and loc then
                local okG, t = pcall(CharacterTrait.get, loc)
                if okG and t ~= nil then found = t end
            end
        end
    end
    traitCache[name] = found or false
    return found
end

function A.isBrave(char)
    if not char then return false end

    if A.isHunter(char) then return true end

    -- Bandits do not carry vanilla CharacterTraits consistently. Treat an
    -- already-hostile or combat-ready armed NPC as brave enough to fight the
    -- Delirium; ordinary Week One civilians will flee.
    if A.isBandit(char) then
        local md = char:getModData()
        local brain = md and md.brain
        if brain then
            if brain.hostile or brain.hostileP then return true end
            local weapons = brain.weapons or {}
            local primary = weapons.primary or {}
            local secondary = weapons.secondary or {}
            if primary.name or secondary.name then return true end
        end
        return false
    end

    if char.getCharacterTraits then
        local traits
        local ok = pcall(function() traits = char:getCharacterTraits() end)
        if ok and traits then
            for _, name in ipairs(WTAGarou.Delirium.BRAVE_TRAITS) do
                local hit = false
                pcall(function()
                    -- 0.4.66: CharacterTrait.get takes a ResourceLocation (a
                    -- bare string raised inside this pcall on every witness
                    -- scan and Kahlua printed each one). Ask by location, or
                    -- the static field (CharacterTrait.BRAVE); never a string.
                    local t = WTAGarou.Adapters.traitByName(name)
                    if t and traits.contains then hit = traits:contains(t) end
                end)
                if hit then return true end
            end
            local known
            pcall(function() known = traits:getKnownTraits() end)
            if known then
                for i = 0, known:size() - 1 do
                    local id = string.lower(tostring(known:get(i)))
                    for _, name in ipairs(WTAGarou.Delirium.BRAVE_TRAITS) do
                        if string.find(id, string.lower(name), 1, true) then return true end
                    end
                end
            end
        end
    elseif char.getTraits then
        local traits = char:getTraits()
        if traits and traits.contains then
            for _, name in ipairs(WTAGarou.Delirium.BRAVE_TRAITS) do
                if traits:contains(name) then return true end
            end
        end
    end
    return false
end

local function reactionReady(npc, kind)
    local md = npc:getModData()
    local now = getTimestamp()
    local key = "WTAGarou_" .. kind .. "Until"
    if (md[key] or 0) > now then return false end
    md[key] = now + 4
    return true
end

function A.makeFlee(npc, targetChar)
    if not npc then return false end
    detect()
    if A.hasKnox and npc.setTask then
        pcall(function() npc:setTask("flee", targetChar) end)
        return true
    end
    if A.isBandit(npc) and reactionReady(npc, "Flee") then
        local ok = pcall(function()
            local dx = npc:getX() - targetChar:getX()
            local dy = npc:getY() - targetChar:getY()
            local len = math.sqrt(dx * dx + dy * dy)
            if len < 0.01 then
                dx, dy, len = (ZombRand(2) == 0 and -1 or 1),
                              (ZombRand(2) == 0 and -1 or 1), 1.414
            end
            local distance = 35
            local x = npc:getX() + (dx / len) * distance
            local y = npc:getY() + (dy / len) * distance
            local task = BanditUtils.GetMoveTask(-0.06, x, y, npc:getZ(), "Run", distance, false)
            Bandit.ClearTasks(npc)
            Bandit.AddTask(npc, task)
            local md = npc:getModData()
            md.WTAGarou_ForcedFlee = getTimestamp() + 20
        end)
        return ok
    end
    return false
end

function A.makeAttack(npc, targetChar)
    if not npc then return false end
    detect()
    if A.hasKnox and npc.setTask then
        pcall(function() npc:setTask("attack", targetChar) end)
        return true
    end
    if A.isBandit(npc) and reactionReady(npc, "Attack") then
        local ok = pcall(function()
            Bandit.SetHostileP(npc, true)
            Bandit.SetProgram(npc, "Bandit")
            Bandit.ClearTasks(npc)
            if targetChar and _G.BanditUtils then
                local tid = BanditUtils.GetCharacterID(targetChar)
                local dx = targetChar:getX() - npc:getX()
                local dy = targetChar:getY() - npc:getY()
                local dist = math.sqrt(dx * dx + dy * dy)
                Bandit.AddTask(npc, BanditUtils.GetMoveTaskTarget(
                    -0.02, targetChar:getX(), targetChar:getY(), targetChar:getZ(),
                    tid, true, "Run", dist))
            end
            npc:getModData().WTAGarou_ForcedAttack = targetChar and A.getCharacterID(targetChar) or ""
        end)
        return ok
    end
    return false
end
