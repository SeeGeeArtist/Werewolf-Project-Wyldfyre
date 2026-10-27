--[[
    WTAGarou - Attached-item locations (v0.4.13, harness 0.4.23)

    The saddlebag stand-in is an ATTACHED item (like a holstered weapon), not
    worn clothing, so its location has to exist in the "Human" attached
    location group before anything asks AttachedItems.getItem(location) about
    it. 0.4.12 registered it lazily inside the attach path, so the very first
    query on load (and every clothing change before the first wolf shift)
    threw `no such location "WTAGarou_Saddlebags"`. Register once, at load,
    on both sides; vanilla does the same in Definitions/AttachedLocations.lua.
]]

WTAGarou = WTAGarou or {}
WTAGarou.AttachedLocationsReady = WTAGarou.AttachedLocationsReady or {}

function WTAGarou.EnsureAttachedLocation(loc)
    loc = loc or (WTAGarou.SaddlebagAttachment or "WTAGarou_Saddlebags")
    if WTAGarou.AttachedLocationsReady[loc] then return true end
    if not (AttachedLocations and AttachedLocations.getGroup) then return false end
    local ok = pcall(function()
        local group = AttachedLocations.getGroup("Human")
        if not group then return end
        local location = group.getLocation and group:getLocation(loc) or nil
        if not location and group.getOrCreateLocation then
            location = group:getOrCreateLocation(loc)
        end
        if location and location.setAttachmentName then location:setAttachmentName(loc) end
        WTAGarou.AttachedLocationsReady[loc] = location ~= nil
    end)
    return ok and WTAGarou.AttachedLocationsReady[loc] == true
end

WTAGarou.EnsureAttachedLocation()
-- 0.4.23: the harness stand-in has its own location, registered the same way.
WTAGarou.EnsureAttachedLocation(WTAGarou.HarnessAttachment or "WTAGarou_Harness")
