--[[
    WTAGarou - Scattered silver: the right-click actions (0.4.77)

    "Scatter silver fragments here" / "Scatter silver filings here" on any
    walkable square while the player carries either; "Pick up scattered
    silver" on a scattered tile. Both walk adjacent first (luautils.walkAdj),
    run a short Loot-style timed action and then hand the world change to
    the server (multiplayer) or do it locally (single player). Filings are
    drained on this client (vanilla drainable pattern); a whole unit of
    Silver Fragments (Base.SilverScrap) is taken by the server by item id
    (REGRESSION_CONTRACT 0.4.66 / 0.4.74); the server hands either back on
    pickup.

    0.4.79: the Oct 21 playtest found no scatter option at all. The options
    are now ALSO on the inventory right-click menu of the fragments /
    filings item (acting on the player's own square), the world-menu
    handler reports its first error to the console instead of vanishing,
    and Silver Fragments count (the user had fragments and filings and
    tried the fragments).
]]

WTAGarou = WTAGarou or {}
WTAGarou.ScatterClient = WTAGarou.ScatterClient or {}
local C = WTAGarou.ScatterClient
local function SC() return WTAGarou.Scatter end

C.ACTION_TIME = 60

-- First filings item with at least COST_USES left (main inventory, bags).
function C.findFilings(player)
    local found
    local ok, err = pcall(function()
        local inv = player:getInventory()
        local items = inv:getAllTypeRecurse(SC().ITEM)
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            local uses = it.getCurrentUses and it:getCurrentUses() or 0
            if uses >= SC().COST_USES then found = it; return end
        end
    end)
    if not ok then C.report("findFilings", err) end
    return found
end

-- First whole unit of Silver Fragments (main inventory, bags).
function C.findScrap(player)
    local found
    local ok, err = pcall(function()
        local inv = player:getInventory()
        local items = inv:getAllTypeRecurse(SC().SCRAP_ITEM)
        if items:size() > 0 then found = items:get(0) end
    end)
    if not ok then C.report("findScrap", err) end
    return found
end

-- Is `item` something that can be scattered? Returns "scrap" / "filings" / nil.
function C.kindOf(item)
    if not item then return nil end
    local kind
    pcall(function()
        local ft = tostring(item:getFullType())
        if ft == SC().SCRAP_ITEM then kind = "scrap"
        elseif ft == SC().ITEM then
            local uses = item.getCurrentUses and item:getCurrentUses() or 0
            if uses >= SC().COST_USES then kind = "filings" end
        end
    end)
    return kind
end

-- First error of each kind goes to the console once (a silent handler
-- was the Oct 21 symptom).
C.reported = {}
function C.report(where, err)
    if C.reported[where] then return end
    C.reported[where] = true
    print("[WTAGarou][Scatter] " .. tostring(where) .. " failed: " .. tostring(err))
end

function C.canScatterOn(square)
    if not square then return false end
    local ok, res = pcall(function()
        if SC().find(square) then return false end
        if square:isSolid() or square:isSolidTrans() then return false end
        if not square:getFloor() then return false end
        return true
    end)
    return ok and res == true
end

local function singlePlayer() return not (isServer and isServer()) and not (isClient and isClient()) end

local function send(player, command, square, kind, item)
    local args = { x = square:getX(), y = square:getY(), z = square:getZ(), kind = kind }
    if kind == "scrap" and item then
        local ok, id = pcall(function() return item:getID() end)
        if ok then args.id = id end
    end
    if singlePlayer() then
        if command == SC().CMD_SCATTER then return SC().serveScatter(player, args) end
        return SC().servePickup(player, args)
    end
    if WTAGarou.Net and WTAGarou.Net.ToServer then WTAGarou.Net.ToServer(player, command, args) end
    return true
end

-- Drain COST_USES from the filings on this client.
function C.drain(item)
    local n = SC().COST_USES
    pcall(function()
        for _ = 1, n do item:Use() end
    end)
    return true
end

local function action(player, square, mode, item)
    if not (ISBaseTimedAction and ISBaseTimedAction.derive) then return nil end
    C.Action = C.Action or ISBaseTimedAction:derive("WTAGarouScatterAction")
    local A = C.Action
    function A:isValid()
        if self.mode == "scatter" then
            return self.item ~= nil and self.item:getContainer() ~= nil and C.canScatterOn(self.square)
        end
        return SC().find(self.square) ~= nil
    end
    function A:update() end
    function A:start()
        if self.setActionAnim then self:setActionAnim("Loot") end
        if self.character.SetVariable then self.character:SetVariable("LootPosition", "Low") end
        if self.setOverrideHandModels then self:setOverrideHandModels(nil, nil) end
    end
    function A:stop() ISBaseTimedAction.stop(self) end
    function A:perform()
        if self.mode == "scatter" then
            if self.kind ~= "scrap" then C.drain(self.item) end
            send(self.character, SC().CMD_SCATTER, self.square, self.kind, self.item)
        else
            send(self.character, SC().CMD_PICKUP, self.square)
        end
        ISBaseTimedAction.perform(self)
    end
    local o = ISBaseTimedAction.new(A, player)
    o.square = square; o.mode = mode; o.item = item; o.kind = C.kindOf(item)
    o.maxTime = C.ACTION_TIME
    if player.isTimedActionInstant and player:isTimedActionInstant() then o.maxTime = 1 end
    return o
end

function C.queue(player, square, mode, item)
    if luautils and luautils.walkAdj then
        if not luautils.walkAdj(player, square, true) then return false end
    end
    local a = action(player, square, mode, item)
    if a and ISTimedActionQueue and ISTimedActionQueue.add then
        ISTimedActionQueue.add(a)
    else
        local kind = C.kindOf(item)
        if mode == "scatter" and kind ~= "scrap" then C.drain(item) end
        send(player, mode == "scatter" and SC().CMD_SCATTER or SC().CMD_PICKUP, square, kind, item)
    end
    return true
end

function C.onScatter(player, square, item) return C.queue(player, square, "scatter", item) end
function C.onPickup(player, square) return C.queue(player, square, "pickup") end

C.LABEL = { scrap = "Scatter silver fragments here", filings = "Scatter silver filings here", pickup = "Pick up scattered silver" }

local function tooltip(opt, text)
    if not (opt and ISToolTip) then return end
    pcall(function()
        local tip = ISToolTip:new(); tip:initialise(); tip:setVisible(false)
        tip.description = text
        opt.toolTip = tip
    end)
end

-- Add the scatter / pick-up options for `square` to `context`. Returns the
-- number of options added.
function C.addOptions(player, context, square)
    if not (player and context and square) then return 0 end
    if context.WTAGarouScatterDone == square then return 0 end
    context.WTAGarouScatterDone = square
    if SC().find(square) then
        local opt = context:addOption(C.LABEL.pickup, player, C.onPickup, square)
        if WTAGarou.HasGarouTrait and WTAGarou.HasGarouTrait(player) then tooltip(opt, "Bare hands burn.") end
        return 1
    end
    if not C.canScatterOn(square) then return 0 end
    local n = 0
    local scrap = C.findScrap(player)
    if scrap then
        tooltip(context:addOption(C.LABEL.scrap, player, C.onScatter, square, scrap), "One unit of Silver Fragments. Burns bare Garou feet and paws.")
        n = n + 1
    end
    local filings = C.findFilings(player)
    if filings then
        tooltip(context:addOption(C.LABEL.filings, player, C.onScatter, square, filings), SC().COST_USES .. " uses of filings. Burns bare Garou feet and paws.")
        n = n + 1
    end
    return n
end

-- The square a world right-click was on: the first clicked object's square,
-- else the square under the cursor.
function C.clickedSquare(playerNum, context, worldObjects)
    for _, o in ipairs(worldObjects or {}) do
        local ok, sq = pcall(function() return o and o.getSquare and o:getSquare() end)
        if ok and sq then return sq end
    end
    local sq
    pcall(function()
        local player = getSpecificPlayer(playerNum)
        local x = screenToIsoX(playerNum, context.x, context.y, player:getZ())
        local y = screenToIsoY(playerNum, context.x, context.y, player:getZ())
        sq = getCell():getGridSquare(math.floor(x), math.floor(y), math.floor(player:getZ() + 0.5))
    end)
    return sq
end

function C.fillWorldMenu(playerNum, context, worldObjects, test)
    if test or not SC() then return end
    local ok, err = pcall(function()
        local player = getSpecificPlayer(playerNum)
        if not player or player:isDead() then return end
        local square = C.clickedSquare(playerNum, context, worldObjects)
        if square then C.addOptions(player, context, square) end
    end)
    if not ok then C.report("world menu", err) end
end

-- Right-click on the fragments / filings item in the inventory: scatter on
-- the player's own square (0.4.79).
function C.fillInventoryMenu(playerNum, context, items)
    if not SC() then return end
    local ok, err = pcall(function()
        local player = getSpecificPlayer(playerNum)
        if not player or player:isDead() then return end
        local list = (ISInventoryPane and ISInventoryPane.getActualItems) and ISInventoryPane.getActualItems(items) or items
        local chosen
        for _, it in ipairs(list or {}) do
            local item = it
            if type(it) == "table" and it.items then item = it.items[1] end
            if C.kindOf(item) then chosen = item; break end
        end
        if not chosen then return end
        local square = player:getCurrentSquare()
        if not square or not C.canScatterOn(square) then return end
        if context.WTAGarouScatterDone == square then return end
        context.WTAGarouScatterDone = square
        local kind = C.kindOf(chosen)
        tooltip(context:addOption(C.LABEL[kind], player, C.onScatter, square, chosen),
            kind == "scrap" and "One unit of Silver Fragments on the square you stand on. Burns bare Garou feet and paws."
                            or (SC().COST_USES .. " uses of filings on the square you stand on. Burns bare Garou feet and paws."))
    end)
    if not ok then C.report("inventory menu", err) end
end

if Events and Events.OnFillWorldObjectContextMenu then Events.OnFillWorldObjectContextMenu.Add(C.fillWorldMenu) end
if Events and Events.OnFillInventoryObjectContextMenu then Events.OnFillInventoryObjectContextMenu.Add(C.fillInventoryMenu) end

return C
