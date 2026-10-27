--[[
    WTAGarou - item granting that survives multiplayer (0.4.66)

    Build 42 multiplayer inventories are server-owned. An item a client makes
    with inventory:AddItem exists on that client only: the server never hears
    of it, so every timed action on it (equip, wear, drop, craft input) is
    rejected when the server rebuilds the action and cannot find the item.
    The first hosted playtest (Oct 16) showed exactly that: debug kits added
    hundreds of items, "can't equip anything", the nitrate mix channel ran
    and nothing happened. Vanilla's own item list does the same thing in MP
    with SendCommandToServer("/additem ...").

    This module is the one way the mod creates inventory items:

      local batch = WTAGarou.Grant.begin(player, "silver kit")
      WTAGarou.Grant.add(batch, "Base.Fertilizer", 1)
      ...
      WTAGarou.Grant.commit(batch)

    - Single player and the server itself: items are created on the spot
      (plus sendAddItemToContainer on a server) and `add` returns the first.
    - A remote client: `add` only records the request; `commit` sends one
      GrantItems command and the server creates everything, then answers
      GrantItemsDone. `add` returns nil there, so callers must not post-
      process items they asked for (they will not be in hand yet).

    The server grants when it runs in debug (a hosted game inherits the
    host's -debug) or when the player holds any access level above None.
]]
WTAGarou = WTAGarou or {}
WTAGarou.Grant = WTAGarou.Grant or {}
local G = WTAGarou.Grant

G.COMMAND = "GrantItems"
G.REPLY = "GrantItemsDone"
-- The firearm kit is about 250 items; leave room, refuse silliness.
G.MAX_ITEMS = 600
G.MAX_ENTRIES = 200

local function safeIsClient() return type(isClient) == "function" and isClient() == true end
local function safeIsServer() return type(isServer) == "function" and isServer() == true end

-- A client talking to a real server (hosted or dedicated). False in single
-- player and on the server itself.
function G.isRemoteClient()
    return safeIsClient() and not safeIsServer()
end

function G.begin(player, reason)
    return { player = player, reason = reason or "items", list = {}, added = 0,
             missing = {}, remote = G.isRemoteClient() }
end

local function scriptExists(full)
    if type(getScriptManager) ~= "function" then return true end
    local ok, found = pcall(function() return getScriptManager():FindItem(full) end)
    return ok and found ~= nil
end
G.scriptExists = scriptExists

-- 0.4.74: a granted vessel may come pre-filled: `fluid = { name, litres }`.
-- Only this mod's fluids (WTAGarou_*) and at most MAX_LITRES, so the
-- request cannot be bent into a water or fuel dispenser. The fill happens
-- where the item is made (single player, or the server), BEFORE
-- sendAddItemToContainer so the client's copy arrives already full.
G.MAX_LITRES = 5
G.FLUID_PREFIX = "WTAGarou_"
function G.validFluid(fluid)
    if type(fluid) ~= "table" then return nil end
    local name, litres = fluid.name or fluid[1], tonumber(fluid.litres or fluid[2])
    if type(name) ~= "string" or name:sub(1, #G.FLUID_PREFIX) ~= G.FLUID_PREFIX then return nil end
    if not litres or litres <= 0 then return nil end
    return { name = name, litres = math.min(litres, G.MAX_LITRES) }
end
-- `getFluid` injectable for tests (defaults to the engine's Fluid.Get).
function G.fill(item, fluid, getFluid)
    fluid = G.validFluid(fluid)
    if not (item and fluid) then return false, "no fluid" end
    getFluid = getFluid or (Fluid and Fluid.Get)
    if not getFluid then return false, "no Fluid registry" end
    local ok, err = pcall(function()
        local fc = item.getFluidContainer and item:getFluidContainer()
        if not fc then error("not a fluid container") end
        local f = getFluid(fluid.name)
        if not f then error("unknown fluid " .. fluid.name) end
        local cap = fc.getCapacity and tonumber(fc:getCapacity()) or fluid.litres
        fc:addFluid(f, math.min(fluid.litres, cap or fluid.litres))
    end)
    if not ok then return false, tostring(err) end
    return true
end

-- Ask for `count` of `full`. Returns the first created item, or nil when the
-- request was only queued (remote client) or the script does not exist.
function G.add(batch, full, count, fluid)
    if not (batch and full) then return nil end
    count = math.max(1, math.floor(tonumber(count) or 1))
    fluid = G.validFluid(fluid)
    if not scriptExists(full) then
        batch.missing[#batch.missing + 1] = tostring(full)
        return nil
    end
    if batch.remote then
        if #batch.list >= G.MAX_ENTRIES or batch.added + count > G.MAX_ITEMS then
            batch.missing[#batch.missing + 1] = tostring(full) .. " (over the per-request cap)"
            return nil
        end
        batch.list[#batch.list + 1] = { type = full, count = count, fluid = fluid }
        batch.added = batch.added + count
        return nil
    end
    local inv = batch.player and batch.player.getInventory and batch.player:getInventory()
    if not inv then batch.missing[#batch.missing + 1] = tostring(full); return nil end
    local first
    for _ = 1, count do
        local ok, item = pcall(function() return inv:AddItem(full) end)
        if not ok or not item then
            batch.missing[#batch.missing + 1] = tostring(full)
            break
        end
        batch.added = batch.added + 1
        first = first or item
        if fluid then
            local filled, why = G.fill(item, fluid)
            if not filled then batch.missing[#batch.missing + 1] = tostring(full) .. " fill: " .. tostring(why) end
        end
        if safeIsServer() and type(sendAddItemToContainer) == "function" then
            pcall(sendAddItemToContainer, inv, item)
        end
    end
    return first
end

-- Finish the batch. On a remote client this is what actually asks the
-- server. Returns a short status string for the caller's message.
function G.commit(batch)
    if not batch then return "" end
    if batch.remote then
        if #batch.list == 0 then return "nothing to request" end
        if WTAGarou.Net and WTAGarou.Net.ToServer then
            WTAGarou.Net.ToServer(batch.player, G.COMMAND, { reason = batch.reason, items = batch.list })
        end
        return tostring(batch.added) .. " item(s) requested from the server (multiplayer: items are server-made; watch for the confirmation)"
    end
    return tostring(batch.added) .. " item(s) added"
end

-- Server policy (0.4.83): single player, a -debug server, or a role with
-- the AddItem capability (admin / moderator / gm). "any level above None"
-- let every Build 42 player through, because their role is "user".
function G.allowedOnServer(player)
    if not player then return false end
    if WTAGarou.Access and WTAGarou.Access.privileged then
        return WTAGarou.Access.privileged(player)
    end
    return not (isServer and isServer())
end

-- Server side of GrantItems. Pure enough to unit test: `reply(player, args)`
-- is how the answer leaves.
function G.serve(player, args, reply)
    args = args or {}
    reply = reply or function(p, a)
        if WTAGarou.Net and WTAGarou.Net.ToClient then WTAGarou.Net.ToClient(p, G.REPLY, a) end
    end
    local reason = tostring(args.reason or "items")
    if not G.allowedOnServer(player) then
        print("[WTAGarou][Grant] denied " .. reason .. " for " .. tostring(player and player.getUsername and player:getUsername() or "?"))
        reply(player, { reason = reason, added = 0, denied = true })
        return 0
    end
    local batch = G.begin(player, reason)
    batch.remote = false -- we ARE the server (or single player)
    local entries, total = 0, 0
    for _, entry in ipairs(type(args.items) == "table" and args.items or {}) do
        entries = entries + 1
        if entries > G.MAX_ENTRIES then break end
        local count = math.max(1, math.floor(tonumber(entry.count) or 1))
        if total + count > G.MAX_ITEMS then break end
        total = total + count
        G.add(batch, tostring(entry.type), count, entry.fluid)
    end
    print("[WTAGarou][Grant] " .. reason .. ": " .. batch.added .. " item(s) for "
        .. tostring(player.getUsername and player:getUsername() or "?")
        .. (#batch.missing > 0 and ("; missing " .. table.concat(batch.missing, ", ")) or ""))
    reply(player, { reason = reason, added = batch.added, missing = batch.missing })
    return batch.added
end

-- Client side of GrantItemsDone: one line for the console/test panel.
function G.describeReply(args)
    args = args or {}
    local reason = tostring(args.reason or "items")
    if args.denied then
        return reason .. ": the server refused (not a debug server and no admin access)"
    end
    local text = reason .. ": " .. tostring(args.added or 0) .. " item(s) placed in your inventory by the server"
    local missing = args.missing
    if type(missing) == "table" and #missing > 0 then
        text = text .. "; missing " .. table.concat(missing, ", ")
    end
    return text
end
