--[[
    WTAGarou - Bulk forms versus car seats (v0.4.39)

    A shift INTO Crinos or Hispo that completes while the player sits in a
    vehicle is resolved here, on authority (single player runs this file in
    process; a dedicated server runs it for every client):

      1. the seat's own door part takes WTAGarou.VehicleShift.damageFor(form)
         condition points (the form's clothing fraction of a 100-condition
         part; a forced 100-Rage Crinos doubles it exactly like clothes);
      2. the window in that door takes the same points, or with
         SMASH_CHANCE is smashed outright through VehicleWindow.hit, the
         engine's own bare-handed smash (VehicleWindowSmash world sound,
         broken glass, zombie-audible noise, car alarm, item removed);
      3. the owning client is told to leave the seat through the vanilla
         BaseVehicle.exit path and, when the glass went, takes the engine's
         bare-handed window cut (BodyDamage.setScratchedWindow).

    Entering a vehicle while already in a bulk form is refused by the Java
    BulkFormRuntime through BaseVehicle.isEnterBlocked; nothing here.
    Clients never send geometry, seats or damage; the server reads them.
]]

require "WTAGarouNet"
WTAGarou = WTAGarou or {}
WTAGarou.VehicleShift = WTAGarou.VehicleShift or {}
local V = WTAGarou.VehicleShift

local function windowPartOf(doorPart)
    if not doorPart then return nil end
    local child = doorPart.getChildWindow and doorPart:getChildWindow() or nil
    if child and child.getWindow and child:getWindow() then return child end
    local window = doorPart.findWindow and doorPart:findWindow() or nil
    if window and window.getPart then return window:getPart() end
    return nil
end

local function roll()
    if ZombRandFloat then return ZombRandFloat(0, 1) end
    return math.random()
end

function V.onCompleted(player, previous, target, forced)
    if isClient() or V.ENABLED == false then return end
    if not (WTAGarou.IsBulkForm and WTAGarou.IsBulkForm(target)) then return end
    if not player or player:isDead() or not WTAGarou.HasGarouTrait(player) then return end
    local vehicle = player.getVehicle and player:getVehicle() or nil
    if not vehicle then return end
    local seat = vehicle:getSeat(player)
    if seat == nil or seat < 0 then return end
    local points = V.damageFor(target, forced)
    local door = vehicle:getPassengerDoor(seat)
    local doorBefore, doorAfter = nil, nil
    if door and points > 0 then
        doorBefore = door:getCondition()
        door:damage(points)
        doorAfter = door:getCondition()
    end
    local windowPart = windowPartOf(door)
    local window = windowPart and windowPart:getWindow() or nil
    local smashed = false
    if window and not window:isDestroyed() then
        if roll() < (tonumber(V.SMASH_CHANCE) or 0.02) then
            window:hit(player)          -- engine bare-handed smash, full noise
            smashed = true
        elseif points > 0 then
            windowPart:damage(points)   -- VehiclePart routes glass to VehicleWindow.damage
        end
    end
    if vehicle.updatePartStats then pcall(function() vehicle:updatePartStats() end) end
    print(string.format("[WTAGarou][VehicleShift] %s in seat %d forced out of vehicle %s; door %s->%s; window %s; points=%d",
        tostring(target), seat, tostring(vehicle:getId()), tostring(doorBefore), tostring(doorAfter),
        smashed and "smashed" or (window and "damaged" or "none"), points))
    WTAGarou.Net.ToClient(player, "VehicleEjected", {
        form = target, seat = seat, points = points, smashed = smashed,
        vehicleId = vehicle:getId(), forced = forced and true or false,
    })
    return true
end
