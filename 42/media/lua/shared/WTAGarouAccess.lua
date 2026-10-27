--[[
    WTAGarou - who may use the cheat / debug surfaces (shared, 0.4.83)

    Workshop-release audit, Oct 23: the server gated its Debug* commands and
    the GrantItems kit on `player:getAccessLevel() ~= "None"`. In Build 42
    getAccessLevel() returns the ROLE NAME, and the default role for every
    new multiplayer player is "user" (zombie.characters.Roles), so every
    ordinary player passed the gate and could set their own Rage, clear
    their identity lock or hand themselves silver kits. B41's "None" level
    no longer exists.

    One rule for both sides: privileged means the role carries the AddItem
    capability (admin, moderator and gm in the default role set; the same
    capability vanilla's ClientCommands.lua checks before adding items), or
    the game is single player, or the server runs with -debug. Role names
    are only a fallback for a build without the Capability class.
]]

WTAGarou = WTAGarou or {}
WTAGarou.Access = WTAGarou.Access or {}
local A = WTAGarou.Access

A.CAPABILITY = "AddItem"
A.ROLE_NAMES = { admin = true, moderator = true, gm = true, overseer = true }

local function multiplayer()
    if isServer and isServer() then return true end
    if isClient and isClient() then return true end
    return false
end
A.multiplayer = multiplayer

-- Pure-ish: does this player's role carry the capability?
-- Returns true/false, or nil when the role API is not available.
function A.roleHasCapability(player, name)
    name = name or A.CAPABILITY
    local ok, res = pcall(function()
        if not player.getRole then return nil end
        local role = player:getRole()
        if not role or not role.hasCapability then return nil end
        local cap = Capability and Capability[name] or nil
        if cap == nil then return nil end
        return role:hasCapability(cap) == true
    end)
    if ok then return res end
    return nil
end

function A.privileged(player)
    if not player then return false end
    if not multiplayer() then return true end                  -- single player: everything is allowed
    if type(getDebug) == "function" then
        local ok, dbg = pcall(getDebug)
        if ok and dbg == true then return true end             -- -debug server / client
    end
    local has = A.roleHasCapability(player, A.CAPABILITY)
    if has ~= nil then return has end
    local ok, level = pcall(function() return player:getAccessLevel() end)
    if ok and level ~= nil then
        return A.ROLE_NAMES[string.lower(tostring(level))] == true
    end
    return false
end

return A
