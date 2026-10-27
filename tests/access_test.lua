-- 0.4.83: who may use the cheat/debug surfaces (Workshop-release audit).
local root = arg[1] or "."
package.path = root .. "/42/media/lua/shared/?.lua;" .. package.path
local n = 0
local function check(ok, why) n = n + 1; assert(ok, why) end

WTAGarou = WTAGarou or {}
local mode = { server = false, client = false }
isServer = function() return mode.server end
isClient = function() return mode.client end
getDebug = function() return mode.debug == true end

local A = require "WTAGarouAccess"
check(A == WTAGarou.Access and A.privileged, "module loaded")

-- B42 role fixtures: getAccessLevel() is the role NAME; "user" is the default.
local function player(roleName, caps)
    local role = { name = roleName, caps = caps or {} }
    function role:getName() return self.name end
    function role:hasCapability(c) return self.caps[c] == true end
    local p = { role = role }
    function p:getRole() return self.role end
    function p:getAccessLevel() return self.role.name end
    return p
end
Capability = { AddItem = "AddItem", CanMedicalCheat = "CanMedicalCheat", LoginOnServer = "LoginOnServer" }

local user = player("user", { LoginOnServer = true })
local priority = player("priority", { LoginOnServer = true })
local observer = player("observer", { LoginOnServer = true, CanMedicalCheat = true })
local gm = player("gm", { LoginOnServer = true, AddItem = true })
local admin = player("admin", { LoginOnServer = true, AddItem = true, CanMedicalCheat = true })

-- single player: everything allowed
check(A.privileged(user) == true, "single player: allowed")

-- multiplayer server
mode.server = true
check(A.privileged(user) == false, "MP: the default 'user' role is NOT privileged (the old ~= 'None' gate let it through)")
check(A.privileged(priority) == false, "MP: priority users are not privileged")
check(A.privileged(observer) == false, "MP: observers cannot add items, so no cheats")
check(A.privileged(gm) == true, "MP: gm has AddItem")
check(A.privileged(admin) == true, "MP: admin")
check(A.privileged(nil) == false, "no player: refused")

-- -debug server: a test host
mode.debug = true
check(A.privileged(user) == true, "a -debug server hands out to everyone")
mode.debug = false

-- a build without the Capability class: fall back to role names
Capability = nil
check(A.privileged(user) == false and A.privileged(admin) == true and A.privileged(gm) == true, "name fallback: admin/gm yes, user no")
local custom = player("None")
check(A.privileged(custom) == false, "B41-style 'None' is refused too")
Capability = { AddItem = "AddItem" }

-- a role object that throws: refused, never allowed
local broken = player("user"); broken.getRole = function() error("boom") end
check(A.privileged(broken) == false, "errors fail closed")

-- client side uses the same rule
mode.server = false; mode.client = true
check(A.privileged(user) == false and A.privileged(admin) == true, "client: same answer as the server")

-- the Grant policy and the server Debug gate route through it
require "WTAGarouGrant"
local G = WTAGarou.Grant
mode.client = false; mode.server = true
check(G.allowedOnServer(user) == false and G.allowedOnServer(admin) == true, "GrantItems server policy uses Access.privileged")
local server = io.open(root .. "/42/media/lua/server/WTAGarouServer.lua"):read("*a")
check(server:find('WTAGarou.Access.privileged(player)', 1, true) ~= nil, "server Debug* gate uses Access.privileged")
check(server:find('lvl ~= "None"', 1, true) == nil, "the old ~= None gate is gone")
local panel = io.open(root .. "/42/media/lua/client/WTAGarouTestPanel.lua"):read("*a")
check(panel:find('WTAGarou.Access.privileged(player)', 1, true) ~= nil, "the cheat panel uses Access.privileged")

print(string.format("PASS: %d access/privilege assertions.", n))
