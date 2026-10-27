--[[
    WTAGarou - server side of GrantItems (0.4.66)
    See WTAGarouGrant.lua. Items a client asks for are created HERE so the
    server-owned inventory knows them; single player never sends the command
    (the same module creates items directly there).
]]
require "WTAGarouNet"
require "WTAGarouGrant"

local function onGrantCommand(module, command, player, args)
    if module ~= "WTAGarou" or command ~= WTAGarou.Grant.COMMAND then return end
    if not player then return end
    local ok, err = pcall(WTAGarou.Grant.serve, player, args)
    if not ok then print("[WTAGarou][Grant] failed: " .. tostring(err)) end
end

Events.OnClientCommand.Add(onGrantCommand)
WTAGarou.Net.RegisterServerHandler(onGrantCommand)
