--[[
    WTAGarou - Starting gear for the Garou trait (v0.3.3)

    A Garou begins knowing what they are, which means they have already solved
    the obvious logistical problem: you cannot carry a backpack in your teeth.
    So they start with saddlebags stowed inside their pack, ready to be pulled
    out and strapped on before shifting to Lupus or Hispo.

    Build 42 has no "starting items" field on character_trait_definition, so
    this is done in Lua on OnNewGame.

    FIXED (v0.3.3): findBestBag crashed with "Object tried to call nil in
    findBestBag" at line 36 on every game load (see console.txt). The v0.3.2
    code called container:getMaxCapacity() unconditionally, and that method
    does not exist on every InventoryContainer instance in this B42 build --
    calling a nil method throws instead of returning nil. All capacity
    lookups are now wrapped so a missing method degrades to "0 capacity"
    instead of crashing, and the whole function is wrapped in pcall as a
    second line of defense.
]]

require "WTAGarouDefinitions"

local GRANT_FLAG = "WTAGarou_StartingGearGranted"

-- 0.4.22: the Wolf Panniers container is retired (the saddlebag is a visual
-- for ANY worn container in a wolf form). Nothing is granted any more; the
-- list stays so a future starting item is a one-line change.
local STARTING_ITEMS = {
}

--- Best-effort capacity probe. Different container-bearing items expose
--- capacity under different method names across B42 builds/mods, and calling
--- a method that does not exist on a given object throws rather than
--- returning nil, so each candidate is checked for existence AND wrapped in
--- pcall before being called.
local function tryGetCapacity(container)
    if not container then return 0 end
    local candidates = { "getCapacity", "getMaxCapacity", "getMaxWeight" }
    for _, methodName in ipairs(candidates) do
        if container[methodName] then
            local ok, result = pcall(function() return container[methodName](container) end)
            if ok and type(result) == "number" then
                return result
            end
        end
    end
    return 0
end

--- Find the roomiest container the player is carrying, so the saddlebag ends
--- up inside their backpack rather than loose in their main inventory.
local function findBestBag(player)
    local inv = player:getInventory()
    local best, bestCapacity = nil, -1

    local ok, items = pcall(function() return inv:getItems() end)
    if not ok or not items then return inv end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            local isContainer = false
            pcall(function() isContainer = instanceof(item, "InventoryContainer") end)
            -- 0.4.20: only WORN bags qualify. The key ring is an
            -- InventoryContainer too, and on a character without a backpack
            -- it was the roomiest one, so the Wolf Panniers spawned inside the
            -- key ring (September 26 playtest).
            local worn = false
            if isContainer then
                pcall(function() worn = player:isEquipped(item) or (item.isWorn and item:isWorn()) end)
                local ft = ""
                pcall(function() ft = tostring(item:getFullType() or "") end)
                if ft:find("KeyRing") then worn = false end
            end
            if isContainer and worn then
                local ok2, container = pcall(function() return item:getInventory() end)
                if ok2 and container then
                    local capacity = tryGetCapacity(container)
                    if capacity > bestCapacity then
                        best, bestCapacity = container, capacity
                    end
                end
            end
        end
    end

    return best or inv
end

local function grantStartingGear(player)
    if not player then return end

    local md = player:getModData()
    if md[GRANT_FLAG] then return end

    if not WTAGarou.HasGarouTrait(player) then return end

    local ok, err = pcall(function()
        local target = findBestBag(player)
        for _, fullType in ipairs(STARTING_ITEMS) do
            -- Check the registered type BEFORE constructing the item.
            -- pcall does not prevent engine errors from reaching console.txt.
            local script = getScriptManager():FindItem(fullType)
            if script and script:isItemType(ItemType.CONTAINER) then
                local ok2, err2 = pcall(function()
                    local added = target:AddItem(fullType)
                    if not added then
                        print("[WTAGarou] AddItem returned nil for " .. fullType)
                    end
                end)
                if not ok2 then
                    print("[WTAGarou] could not grant starting item " ..
                          tostring(fullType) .. ": " .. tostring(err2))
                end
            else
                print("[WTAGarou] skipping invalid container definition " .. fullType)
            end
        end
    end)
    if not ok then
        print("[WTAGarou] grantStartingGear failed: " .. tostring(err))
    end

    md[GRANT_FLAG] = true
end

Events.OnNewGame.Add(function(player, _square)
    grantStartingGear(player)
end)

--[[
    OnNewGame does not fire for a character that already exists, so anyone who
    took the trait before this file shipped would never receive the gear. This
    catches them once on first load and then sets the same flag.
]]
Events.OnCreatePlayer.Add(function(_playerIndex, player)
    if not player then return end
    local md = player:getModData()
    if md[GRANT_FLAG] then return end
    if not WTAGarou.HasGarouTrait(player) then return end
    grantStartingGear(player)
end)
