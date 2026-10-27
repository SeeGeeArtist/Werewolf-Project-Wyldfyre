--[[
    WTAGarou - Bulk forms cannot climb into cars (v0.4.39)

    Authority for "Crinos and Hispo do not fit in a vehicle seat" is the Java
    BulkFormRuntime, which answers true from BaseVehicle.isEnterBlocked for a
    flagged character. This Lua layer is the belt to that suspender: it wraps
    the vanilla enter action so the attempt is refused with a HUD line even
    when the engine hook is unavailable (old WTAGarouVisuals.jar), and so the
    refusal reads like a Garou rather than a silent no-op.

    Vanilla reference (B42 ISUI/ISVehicleMenu.lua, ISVehicleMenu.onEnter and
    TimedActions/ISEnterVehicle.lua): the menu checks isEnterBlocked before
    queuing ISEnterVehicle; the action re-checks in isValid().
]]

WTAGarou = WTAGarou or {}
WTAGarou.VehicleGuard = WTAGarou.VehicleGuard or {}
local G = WTAGarou.VehicleGuard

function G.isBulk(player)
    if not player or not WTAGarou.IsBulkForm then return false end
    if WTAGarou.HasGarouTrait and not WTAGarou.HasGarouTrait(player) then return false end
    local d = WTAGarou.GetData and WTAGarou.GetData(player) or nil
    return d ~= nil and WTAGarou.IsBulkForm(d.form) == true
end

function G.refuse(player)
    local hud = WTAGarou.HUD and WTAGarou.HUD.instance
    if hud and hud.flashDenial then hud:flashDenial("vehicle_blocked") end
    print("[WTAGarou][VehicleGuard] vehicle entry refused in bulk form")
end

local wrapped = false
function G.install()
    if wrapped then return false end
    local changed = false
    if ISEnterVehicle and ISEnterVehicle.isValid and not ISEnterVehicle.WTAGarou_isValid then
        ISEnterVehicle.WTAGarou_isValid = ISEnterVehicle.isValid
        ISEnterVehicle.isValid = function(self, ...)
            if G.isBulk(self.character) then G.refuse(self.character); return false end
            return ISEnterVehicle.WTAGarou_isValid(self, ...)
        end
        changed = true
    end
    if ISVehicleMenu and ISVehicleMenu.onEnter and not ISVehicleMenu.WTAGarou_onEnter then
        ISVehicleMenu.WTAGarou_onEnter = ISVehicleMenu.onEnter
        ISVehicleMenu.onEnter = function(playerObj, vehicle, seat, ...)
            if G.isBulk(playerObj) then G.refuse(playerObj); return end
            return ISVehicleMenu.WTAGarou_onEnter(playerObj, vehicle, seat, ...)
        end
        changed = true
    end
    wrapped = changed
    if changed then print("[WTAGarou][VehicleGuard] vanilla enter-vehicle paths wrapped") end
    return changed
end

if Events and Events.OnGameStart then Events.OnGameStart.Add(G.install) end
