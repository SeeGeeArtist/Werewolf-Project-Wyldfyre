--[[
    WTAGarou - Paw guard (v0.4.58)

    Hispo and Lupus have paws and jaws, not thumbs. They may CARRY a firearm
    in their jaws (0.4.20 rule, Java swallows the trigger), but they cannot
    work one: no reload, rack, magazine insert/eject, loading or unloading of
    any kind. The same paws cannot craft, build, fix or do vehicle mechanics
    (siphoning fuel included). Shift to Homid for thumbs.

    Graceful rather than silent:
      * Every refusal flashes a HUD line that says WHY and what to do.
      * The firearm radial does not open for a wolf, and the crafting/build
        windows refuse to open unless a recipe whitelist exists, so the
        player is not shown a menu full of things that will not work.
      * WTAGarou.Paws.RECIPE_WHITELIST lets a server (or a later tuning
        pass) allow specific recipes by name for wolves -- "things that
        barely need thumbs". It ships EMPTY on purpose: every vanilla B42
        recipe we checked (opening cans included) needs a tool held in a
        hand. Adding a recipe name here is the whole configuration.

    Implementation mirrors WTAGarouVehicleGuard: wrap isValid on the owning
    vanilla timed actions once, after the game has loaded them. isValid is
    what ISTimedActionQueue consults at start and every tick, so hotkeys,
    radial menus, inventory context menus and queued follow-ups all go
    through one gate. Nothing is wrapped for Homid, Glabro or Crinos.
]]

WTAGarou = WTAGarou or {}
WTAGarou.Paws = WTAGarou.Paws or {}
local P = WTAGarou.Paws

-- Reason keys map to WTAGarou.HUD.DENIAL_TEXT lines.
P.BLOCKED_ACTIONS = {
    -- firearms: any and all reload actions
    ISReloadWeaponAction        = "paws_firearm",
    ISRackFirearm               = "paws_firearm",
    ISInsertMagazine            = "paws_firearm",
    ISEjectMagazine             = "paws_firearm",
    ISLoadBulletsInMagazine     = "paws_firearm",
    ISUnloadBulletsFromFirearm  = "paws_firearm",
    ISUnloadBulletsFromMagazine = "paws_firearm",
    ISRemoveBullet              = "paws_firearm",
    WTAGarouLoadSilverAction    = "paws_firearm",
    WTAGarouLoadSilverMagazineAction = "paws_firearm",
    -- crafting and building (recipe whitelist consulted for the first two)
    ISHandcraftAction           = "paws_craft",
    ISCraftAction               = "paws_craft",
    ISCraftAnimAction           = "paws_craft",
    ISGenericCraftStart         = "paws_craft",
    ISStartCraftProcessorAction = "paws_craft",
    ISBuildIsoEntity            = "paws_craft",
    ISBuildAction               = "paws_craft",
    ISDismantleAction           = "paws_craft",
    ISFixAction                 = "paws_craft",
    ISFixGenerator              = "paws_craft",
    ISRepairClothing            = "paws_craft",
    -- vehicle mechanics and fuel
    ISOpenMechanicsUIAction     = "paws_mechanic",
    ISInstallVehiclePart        = "paws_mechanic",
    ISUninstallVehiclePart      = "paws_mechanic",
    ISFixVehiclePartAction      = "paws_mechanic",
    ISRepairEngine              = "paws_mechanic",
    ISRepairLightbar            = "paws_mechanic",
    ISInflateTire               = "paws_mechanic",
    ISDeflateTire               = "paws_mechanic",
    ISHotwireVehicle            = "paws_mechanic",
    ISTakeGasolineFromVehicle   = "paws_mechanic",
    ISAddGasolineToVehicle      = "paws_mechanic",
    ISRefuelFromGasPump         = "paws_mechanic",
}

-- Recipe names (craftRecipe script names) a wolf may still perform.
-- Empty by design; see header.
P.RECIPE_WHITELIST = P.RECIPE_WHITELIST or {}

function P.isPaws(player)
    if not player then return false end
    if WTAGarou.HasGarouTrait and not WTAGarou.HasGarouTrait(player) then return false end
    return WTAGarou.Slots and WTAGarou.Slots.isQuadruped
        and WTAGarou.Slots.isQuadruped(player) == true
end

function P.refuse(player, reason)
    local hud = WTAGarou.HUD and WTAGarou.HUD.instance
    if hud and hud.flashDenial then hud:flashDenial(reason or "paws_craft") end
    print("[WTAGarou][PawGuard] refused (" .. tostring(reason) .. ") in quadruped form")
end

-- Recipe name of a crafting action, if the action exposes one.
function P.recipeName(action)
    if type(action) ~= "table" then return nil end
    local recipe = action.craftRecipe or action.recipe
    if not recipe then return nil end
    local ok, name = pcall(function()
        if type(recipe.getName) == "function" then return recipe:getName() end
        return nil
    end)
    if ok and type(name) == "string" then return name end
    return nil
end

function P.isWhitelisted(action)
    local name = P.recipeName(action)
    return name ~= nil and P.RECIPE_WHITELIST[name] == true
end

function P.hasWhitelist()
    for _ in pairs(P.RECIPE_WHITELIST) do return true end   -- no next() in Kahlua
    return false
end

-- Decide for one action instance. Returns reason or nil (allowed).
function P.blockReason(action, className)
    local reason = P.BLOCKED_ACTIONS[className]
    if not reason then return nil end
    if reason == "paws_craft" and P.isWhitelisted(action) then return nil end
    return reason
end

local wrapped = false
local wrappedCount = 0

local function wrapIsValid(className, klass)
    if type(klass) ~= "table" or type(klass.isValid) ~= "function" then return false end
    if klass.WTAGarou_isValid then return false end
    klass.WTAGarou_isValid = klass.isValid
    klass.isValid = function(self, ...)
        if P.isPaws(self and self.character) then
            local reason = P.blockReason(self, className)
            if reason then P.refuse(self.character, reason); return false end
        end
        return klass.WTAGarou_isValid(self, ...)
    end
    return true
end

function P.install(env)
    if wrapped then return 0 end
    env = env or _G
    local count = 0
    for className in pairs(P.BLOCKED_ACTIONS) do
        if wrapIsValid(className, env[className]) then count = count + 1 end
    end
    -- Firearm radial / reload-key menu: do not even open for paws.
    local radial = env.ISFirearmRadialMenu
    if radial and type(radial.checkWeapon) == "function" and not radial.WTAGarou_checkWeapon then
        radial.WTAGarou_checkWeapon = radial.checkWeapon
        radial.checkWeapon = function(playerObj, ...)
            if P.isPaws(playerObj) then P.refuse(playerObj, "paws_firearm"); return false end
            return radial.WTAGarou_checkWeapon(playerObj, ...)
        end
        count = count + 1
    end
    -- Automatic reload entry (reload key) goes through this helper.
    local reload = env.ISReloadWeaponAction
    if reload and type(reload.BeginAutomaticReload) == "function" and not reload.WTAGarou_BeginAutomaticReload then
        reload.WTAGarou_BeginAutomaticReload = reload.BeginAutomaticReload
        reload.BeginAutomaticReload = function(playerObj, ...)
            if P.isPaws(playerObj) then P.refuse(playerObj, "paws_firearm"); return end
            return reload.WTAGarou_BeginAutomaticReload(playerObj, ...)
        end
        count = count + 1
    end
    -- 0.4.75: the trigger itself. Vanilla's Hook.Attack handler
    -- (ISReloadWeaponAction.attackHook) plays the shot sound and raises the
    -- world noise BEFORE DoAttack, and only then does Java swallow the press
    -- for a wolf: a bang with no bullet (Oct 19 report). The handler looks
    -- canShoot up on the table each time, so a wrapper reaches it: paws
    -- cannot pull a trigger, the gun dry-clicks instead.
    if reload and type(reload.canShoot) == "function" and not reload.WTAGarou_canShoot then
        reload.WTAGarou_canShoot = reload.canShoot
        reload.canShoot = function(playerObj, weapon, ...)
            if P.isPaws(playerObj) then P.refuse(playerObj, "paws_firearm"); return false end
            return reload.WTAGarou_canShoot(playerObj, weapon, ...)
        end
        count = count + 1
    end
    -- Crafting and build windows: closed to paws unless a whitelist exists.
    local ui = env.ISEntityUI
    if ui then
        for _, key in ipairs({ "OpenHandcraftWindow", "OpenBuildWindow" }) do
            local saved = "WTAGarou_" .. key
            if type(ui[key]) == "function" and not ui[saved] then
                ui[saved] = ui[key]
                ui[key] = function(player, ...)
                    if P.isPaws(player) and not P.hasWhitelist() then
                        P.refuse(player, "paws_craft"); return nil
                    end
                    return ui[saved](player, ...)
                end
                count = count + 1
            end
        end
    end
    wrapped = count > 0
    wrappedCount = count
    if wrapped then print("[WTAGarou][PawGuard] " .. count .. " vanilla thumb-only paths wrapped for quadruped forms") end
    return count
end

function P.wrappedCount() return wrappedCount end

if Events and Events.OnGameStart then Events.OnGameStart.Add(function() P.install(_G) end) end
