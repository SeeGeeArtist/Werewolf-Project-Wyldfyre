--[[
    WTAGarou - Crinos / Hispo corpse stowing (0.4.40)

    Build 42 already turns a human corpse into an inventory item (the trunk
    path): IsoDeadBody.becomeCorpseItem(boolean) creates the Base.Corpse*
    item with the body's byte data and removes the body from its square;
    IsoGameCharacter.pickUpCorpseItem(item) spawns the body back on the
    character's square and starts dragging it. Both are vanilla engine
    surfaces evidenced in the private B42.21 jar. This module only adds the
    context options for the two bulk forms:

      world  > "Stow corpse"            corpse on the ground, within reach
      world  > "Stow carried corpse"    while dragging one
      inventory corpse item > "Put down corpse"   drop it where you stand

    Weight is left to the vanilla encumbrance moodles (a Garou in these forms
    is meant to be able to carry several). Animals are not stowed here.
]]
WTAGarou = WTAGarou or {}
require "WTAGarouDefinitions"
WTAGarou.CorpseCarryClient = WTAGarou.CorpseCarryClient or {}
local CC = WTAGarou.CorpseCarryClient

local function formOf(player)
    local md = player and player:getModData()
    return md and md.WTAGarou and md.WTAGarou.form or nil
end
function CC.allowed(player)
    if not player or player:isDead() then return false end
    if not (WTAGarou.HasGarouTrait and WTAGarou.HasGarouTrait(player)) then return false end
    return WTAGarou.CorpseCarry and WTAGarou.CorpseCarry.canStow(formOf(player)) or false
end

local function isHumanCorpse(object)
    if not object then return false end
    local ok, body = pcall(function()
        return instanceof(object, "IsoDeadBody") and not object:isAnimal()
    end)
    return ok and body == true
end
CC.isHumanCorpse = isHumanCorpse

local function notice(text)
    if WTAGarou.HUD and WTAGarou.HUD.instance and WTAGarou.HUD.instance.pushNotice then
        WTAGarou.HUD.instance:pushNotice(text)
    end
    print("[WTAGarou][CorpseCarry] " .. text)
end

--- Turn a ground corpse into an inventory item and add it to the player.
function CC.stow(player, body)
    if not CC.allowed(player) or not isHumanCorpse(body) then return false end
    local item
    -- false = the networked IsoGridSquare.removeCorpse path (clients send
    -- the removal; single player removes directly).
    local ok, err = pcall(function() item = body:becomeCorpseItem(false) end)
    if not ok or not item then
        notice("could not stow that corpse" .. (err and (": " .. tostring(err)) or ""))
        return false
    end
    pcall(function() player:getInventory():AddItem(item) end)
    notice("corpse stowed")
    return true
end

--- Stow the corpse the player is dragging right now.
function CC.stowCarried(player)
    if not CC.allowed(player) then return false end
    local ok, err = pcall(function() player:throwGrappledIntoInventory(player:getInventory()) end)
    if not ok then notice("could not stow the carried corpse: " .. tostring(err)); return false end
    return true
end

--- Put a stowed corpse back on the ground (vanilla spawns it and grabs it).
function CC.putDown(player, item)
    if not player or not item then return false end
    local ok, err = pcall(function() player:pickUpCorpseItem(item) end)
    if not ok then notice("could not put the corpse down: " .. tostring(err)); return false end
    return true
end

-- Timed action: walk next to the body, then stow it.
local function stowAction(player, body)
    if not (ISBaseTimedAction and ISBaseTimedAction.derive) then
        return nil
    end
    CC.Action = CC.Action or ISBaseTimedAction:derive("WTAGarouStowCorpseAction")
    local A = CC.Action
    function A:isValid() return isHumanCorpse(self.body) and CC.allowed(self.character) end
    function A:update() if self.character.faceThisObject then self.character:faceThisObject(self.body) end end
    function A:start() if self.setActionAnim then self:setActionAnim("Loot") end end
    function A:stop() ISBaseTimedAction.stop(self) end
    function A:perform()
        CC.stow(self.character, self.body)
        ISBaseTimedAction.perform(self)
    end
    local o = ISBaseTimedAction.new(A, player)
    o.body = body
    o.maxTime = (WTAGarou.CorpseCarry and WTAGarou.CorpseCarry.STOW_TIME) or 40
    if player.isTimedActionInstant and player:isTimedActionInstant() then o.maxTime = 1 end
    return o
end

function CC.queueStow(player, body)
    if not CC.allowed(player) or not isHumanCorpse(body) then return false end
    local sq = body.getSquare and body:getSquare() or nil
    if sq and luautils and luautils.walkAdj then luautils.walkAdj(player, sq, true) end
    local action = stowAction(player, body)
    if action and ISTimedActionQueue and ISTimedActionQueue.add then
        ISTimedActionQueue.add(action)
    else
        CC.stow(player, body)
    end
    return true
end

local function dragging(player)
    local ok, v = pcall(function() return player:isDraggingCorpse() end)
    return ok and v == true
end

function CC.fillWorldMenu(playerNum, context, worldObjects, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)
    if not CC.allowed(player) then return end
    if dragging(player) then
        context:addOption("Stow carried corpse", player, CC.stowCarried)
        return
    end
    local seen = {}
    for _, object in ipairs(worldObjects or {}) do
        local sq = object and object.getSquare and object:getSquare() or nil
        local bodies = {}
        if isHumanCorpse(object) then bodies[1] = object end
        if sq and sq.getDeadBodys then
            pcall(function()
                local list = sq:getDeadBodys()
                for i = 0, list:size() - 1 do bodies[#bodies + 1] = list:get(i) end
            end)
        end
        for _, body in ipairs(bodies) do
            if isHumanCorpse(body) and not seen[body] then
                seen[body] = true
                context:addOption("Stow corpse", player, CC.queueStow, body)
            end
        end
    end
end

function CC.fillInventoryMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() or dragging(player) then return end
    if ISInventoryPane and ISInventoryPane.getActualItems then items = ISInventoryPane.getActualItems(items) end
    for _, item in ipairs(items or {}) do
        local corpse = false
        pcall(function() corpse = item:isHumanCorpse() == true end)
        if corpse and item:getContainer() == player:getInventory() then
            context:addOption("Put down corpse", player, CC.putDown, item)
            return
        end
    end
end

if Events and Events.OnFillWorldObjectContextMenu then Events.OnFillWorldObjectContextMenu.Add(CC.fillWorldMenu) end
if Events and Events.OnFillInventoryObjectContextMenu then Events.OnFillInventoryObjectContextMenu.Add(CC.fillInventoryMenu) end

return CC
