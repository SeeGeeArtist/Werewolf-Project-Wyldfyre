-- 0.4.76: the Witness / Delirium dispatcher on a hosted or dedicated server.
-- The Oct 19 hosted console had 1137x "Object tried to call nil in
-- handleWitnessCommand" (WTAGarouWitness.lua:34): `getPlayerFromRealName`
-- does not exist in the engine and `getPlayerFromUsername` is a client
-- global, so every DeliriumReport that named a player witness threw.
local root=assert(arg[1])
package.path=root.."/42/media/lua/shared/?.lua;"..root.."/42/media/lua/server/?.lua;"..root.."/42/media/lua/client/?.lua;"..package.path
local n=0
local function check(ok,why) n=n+1; assert(ok,why) end
isServer=function() return true end
isClient=function() return false end
getTimestamp=function() return 1000 end
Events=setmetatable({},{__index=function(t,k) t[k]={handlers={},Add=function(f) table.insert(t[k].handlers,f) end}; return t[k] end})
WTAGarou=WTAGarou or {}
require "WTAGarouDefinitions"
require "WTAGarouState"
require "WTAGarouAdapters"

local function player(name, form, garou)
    local p = { name = name, md = { WTAGarou = { form = form or "Homid", witnesses = {} } } }
    p.md[WTAGarou.Tags.GAROU] = garou ~= false
    function p:getUsername() return self.name end
    function p:getModData() return self.md end
    function p:getOnlineID() return 7 end
    return p
end
local host = player("Chris", "Crinos")
local wife = player("Wife", "Homid")
local list = { items = { host, wife } }
function list:size() return #self.items end
function list:get(i) return self.items[i + 1] end

-- server: no client globals at all
getPlayerFromUsername = nil
getPlayerFromRealName = nil
getOnlinePlayers = function() return list end
require "WTAGarouNet"
require "WTAGarouWitness"
local handler = Events.OnClientCommand.handlers[#Events.OnClientCommand.handlers]
check(type(handler) == "function", "witness handler registered")

check(WTAGarou.WitnessPlayerByName("Wife") == wife, "server: a player witness is resolved through getOnlinePlayers")
check(WTAGarou.WitnessPlayerByName("Nobody") == nil and WTAGarou.WitnessPlayerByName("") == nil and WTAGarou.WitnessPlayerByName(nil) == nil,
    "unknown / empty names resolve to nil, no exception")

local fled, attacked = {}, {}
WTAGarou.Adapters.makeFlee = function(npc, who) fled[#fled + 1] = npc; return true end
WTAGarou.Adapters.makeAttack = function(npc, who) attacked[#attacked + 1] = npc; return true end
WTAGarou.Adapters.findHumanByID = function() return nil end
local ok, err = pcall(handler, "WTAGarou", "DeliriumReport", host,
    { witnesses = { { id = "7", name = "Wife", x = 1, y = 2, z = 0 }, { id = "99", name = "", x = 1, y = 2, z = 0 } } })
check(ok, "server: a DeliriumReport naming a player witness no longer throws: " .. tostring(err))
check(#fled == 0 and #attacked == 0, "a Garou witness is left alone")
wife.md[WTAGarou.Tags.GAROU] = false
ok = pcall(handler, "WTAGarou", "DeliriumReport", host, { witnesses = { { id = "7", name = "Wife" } } })
check(ok and #fled == 0, "0.4.79: witnesses are dormant (Delirium.ENABLED=false): nothing happens")
-- switched back on: a PLAYER is still never a witness (Oct 21: two friends
-- shifting with PvP on raised each other's Infamy)
WTAGarou.Delirium.ENABLED = true
ok = pcall(handler, "WTAGarou", "DeliriumReport", host, { witnesses = { { id = "7", name = "Wife" } } })
check(ok and #fled == 0, "a human PLAYER witness is ignored even with witnesses on")
WTAGarou.Delirium.PLAYERS_WITNESS = true
ok = pcall(handler, "WTAGarou", "DeliriumReport", host, { witnesses = { { id = "7", name = "Wife" } } })
check(ok and #fled == 1 and fled[1] == wife, "only the PLAYERS_WITNESS switch brings the player flee response back")
WTAGarou.Delirium.PLAYERS_WITNESS = false
WTAGarou.Delirium.ENABLED = false

-- client-style global present: it is preferred
getPlayerFromUsername = function(name) return name == "Wife" and "clientCopy" or nil end
check(WTAGarou.WitnessPlayerByName("Wife") == "clientCopy", "client: getPlayerFromUsername is used when it exists")
check(WTAGarou.WitnessPlayerByName("Chris") == host, "falls through to the online list when the client lookup misses")

print("PASS: " .. n .. " witness server assertions.")
