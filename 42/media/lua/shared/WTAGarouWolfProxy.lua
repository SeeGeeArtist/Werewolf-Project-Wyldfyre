--[[
    WTAGarou - Wolf proxy lifecycle (v0.3.5-dev)

    This module owns the future Lupus/Hispo animal proxy.

    It deliberately does NOT guess at a Build 42 IsoAnimal construction API.
    The project needs the exact working WolfMod companion-spawn call before
    spawnAnimalNearPlayer() can be implemented safely.

    Current behavior:
      * stores owner -> proxy state in player mod data;
      * handles requested spawn/despawn lifecycle;
      * logs actionable diagnostics;
      * gives debug commands a stable entry point;
      * keeps all future animal-specific code out of WTAGarouServer.lua.
]]

require "WTAGarouDefinitions"

WTAGarou = WTAGarou or {}
WTAGarou.WolfProxy = WTAGarou.WolfProxy or {}

local WolfProxy = WTAGarou.WolfProxy

WolfProxy.MOD_DATA_KEY = "WTAGarou_WolfProxy"

WolfProxy.FORMS = {
    Lupus = true,
    Hispo = true,
}

WolfProxy.TYPE_BY_FORM = {
    Lupus = "WTAGarou_Wolf",
    Hispo = "WTAGarou_DireWolf",
}

local function log(message)
    print("[WTAGarou][WolfProxy] " .. tostring(message))
end

local function now()
    if getTimestamp then
        local ok, value = pcall(getTimestamp)
        if ok and type(value) == "number" then
            return value
        end
    end
    return 0
end

local function playerID(player)
    if not player then return -1 end

    if player.getOnlineID then
        local ok, id = pcall(function()
            return player:getOnlineID()
        end)
        if ok and id ~= nil then
            return id
        end
    end

    return -1
end

local function getData(player)
    if not player then return nil end

    local md = player:getModData()
    if not md then return nil end

    md[WolfProxy.MOD_DATA_KEY] = md[WolfProxy.MOD_DATA_KEY] or {}
    return md[WolfProxy.MOD_DATA_KEY]
end

function WolfProxy.IsQuadrupedForm(form)
    return WolfProxy.FORMS[form] == true
end

function WolfProxy.GetTypeForForm(form)
    return WolfProxy.TYPE_BY_FORM[form] or WolfProxy.TYPE_BY_FORM.Lupus
end

function WolfProxy.GetState(player)
    return getData(player)
end

function WolfProxy.HasProxy(player)
    local data = getData(player)
    return data ~= nil and data.active == true
end

function WolfProxy.GetAnimalID(player)
    local data = getData(player)
    if not data then return nil end
    return data.animalID
end

function WolfProxy.ClearState(player, reason)
    local data = getData(player)
    if not data then return end

    local oldID = data.animalID

    data.active = nil
    data.animalID = nil
    data.animalType = nil
    data.form = nil
    data.spawnRequestedAt = nil
    data.lastSyncAt = nil
    data.lastReason = tostring(reason or "cleared")

    log(
        "cleared state: owner=" .. tostring(playerID(player)) ..
        " oldAnimalID=" .. tostring(oldID) ..
        " reason=" .. tostring(reason or "unspecified")
    )
end

--[[
    TODO: Replace this with the exact working creation call used by WolfMod's
    companion trait.

    Requirements for the eventual implementation:
      1. Execute on server/SP authority only.
      2. Spawn in a valid loaded square near the player.
      3. Return a real IsoAnimal.
      4. Put that animal into world/network relevance correctly.
      5. Return an ID that can later be resolved consistently.
]]
local function spawnAnimalNearPlayer(_player, _animalType)
    return nil, "spawn_api_not_wired"
end

--[[
    TODO: Replace this with the exact WolfMod/vanilla removal path once known.
    Do not call animal:removeFromWorld(), getCell():remove..., or destroy APIs
    speculatively: animal lifecycle and network replication must match the
    method that created it.
]]
local function despawnAnimal(_animalID)
    return false, "despawn_api_not_wired"
end

function WolfProxy.RequestSpawn(player, form, source)
    if not player then return false, "no_player" end

    form = tostring(form or "")
    if not WolfProxy.IsQuadrupedForm(form) then
        return false, "not_quadruped_form"
    end

    local data = getData(player)
    local wantedType = WolfProxy.GetTypeForForm(form)

    -- Reusing an existing proxy is intentional. The final implementation will
    -- change visual state/scale when Lupus <-> Hispo changes rather than making
    -- duplicate animals for one player.
    if data.active and data.animalID then
        data.form = form
        data.animalType = wantedType
        data.lastReason = "reused:" .. tostring(source or "unknown")

        log(
            "reused state: owner=" .. tostring(playerID(player)) ..
            " animalID=" .. tostring(data.animalID) ..
            " form=" .. form
        )
        return true, "already_tracked"
    end

    data.form = form
    data.animalType = wantedType
    data.spawnRequestedAt = now()
    data.lastReason = "requested:" .. tostring(source or "unknown")

    local animal, err = spawnAnimalNearPlayer(player, wantedType)
    if not animal then
        data.active = nil
        data.animalID = nil

        log(
            "spawn not performed: owner=" .. tostring(playerID(player)) ..
            " form=" .. form ..
            " type=" .. wantedType ..
            " source=" .. tostring(source or "unknown") ..
            " reason=" .. tostring(err)
        )

        return false, err
    end

    -- This section will be completed only once the working API tells us which
    -- stable identifier an IsoAnimal exposes and how it is resolved later.
    data.active = true
    data.animalID = nil
    data.lastReason = "spawned:" .. tostring(source or "unknown")

    log(
        "spawn returned animal but no ID adapter exists yet: owner=" ..
        tostring(playerID(player)) ..
        " type=" .. wantedType
    )

    return true, "spawned"
end

function WolfProxy.RequestDespawn(player, reason)
    if not player then return false, "no_player" end

    local data = getData(player)
    if not data or not data.active then
        WolfProxy.ClearState(player, reason or "not_active")
        return true, "already_clear"
    end

    local animalID = data.animalID
    if not animalID then
        WolfProxy.ClearState(player, reason or "missing_animal_id")
        return true, "cleared_unresolved"
    end

    local ok, err = despawnAnimal(animalID)
    if not ok then
        log(
            "despawn not performed: owner=" .. tostring(playerID(player)) ..
            " animalID=" .. tostring(animalID) ..
            " reason=" .. tostring(err)
        )
        return false, err
    end

    WolfProxy.ClearState(player, reason or "despawned")
    return true, "despawned"
end

function WolfProxy.OnFormChanged(player, previousForm, newForm)
    if not player then return end

    if WolfProxy.IsQuadrupedForm(newForm) then
        WolfProxy.RequestSpawn(player, newForm, "form_change:" .. tostring(previousForm))
        return
    end

    if WolfProxy.HasProxy(player) then
        WolfProxy.RequestDespawn(player, "form_change:" .. tostring(newForm))
    end
end

function WolfProxy.DebugSpawn(player)
    local form = "Lupus"

    if player and WTAGarou.GetData then
        local data = WTAGarou.GetData(player)
        if data and WolfProxy.IsQuadrupedForm(data.form) then
            form = data.form
        end
    end

    return WolfProxy.RequestSpawn(player, form, "debug_command")
end

function WolfProxy.DebugClear(player)
    return WolfProxy.RequestDespawn(player, "debug_command")
end

log("loaded; runtime animal spawn adapter is intentionally disabled until WolfMod call is mapped")

return WolfProxy