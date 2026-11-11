--[[
    WTAGarou - Resolve skill and shift environment (0.5.0)

    Engine-facing half of the Resolve update. The tuning tables and every
    pure formula live in WTAGarouDefinitions.lua (ShiftBuffer, MoonLight,
    Resolve, ShiftAdmission, ShiftSeconds, Resolve* helpers); this file only
    touches the game:

      * WTAGarou.Resolve.perk()          the PerkFactory perk from media/perks.txt
      * WTAGarou.Resolve.levelOf(p)      0..10, 0 when the perk is missing
      * WTAGarou.Resolve.grant(p, amt)   server-side XP (addXp / XP:AddXP)
      * WTAGarou.Resolve.applyOnClient   the owning client adds XP itself when
                                         Resolve.CLIENT_APPLIES_XP is set
      * WTAGarou.Resolve.setLevel(p, n)  testing only (/garou resolve n)
      * WTAGarou.MoonLightExposure(p)    0..1 from ClimateManager / ClimateMoon

    Every engine call is pcall-guarded and fails to "no effect": a missing
    perk reads level 0 (abilities locked, buffer at its base width), a
    missing climate API reads exposure 0 (no moonlight cut). Nothing here is
    live-verified until the Resolve playtest.
]]

WTAGarou = WTAGarou or {}
require "WTAGarouDefinitions"
WTAGarou.Resolve = WTAGarou.Resolve or {}
local R = WTAGarou.Resolve

local function clamp01(v)
    v = tonumber(v) or 0
    if v ~= v then return 0 end
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

-- ---------------------------------------------------------------------------
-- Perk lookup
-- ---------------------------------------------------------------------------
local cachedPerk = nil
function R.perk()
    if cachedPerk then return cachedPerk end
    local id = R.PERK or "WTAGarou_Resolve"
    local ok, perk = pcall(function()
        if type(Perks) == "table" or type(Perks) == "userdata" then
            local direct = Perks[id]
            if direct then return direct end
            if Perks.FromString then
                local p = Perks.FromString(id)
                if p then return p end
            end
        end
        if PerkFactory and PerkFactory.getPerkFromName then
            return PerkFactory.getPerkFromName(id)
        end
        return nil
    end)
    if ok and perk then cachedPerk = perk; return perk end
    return nil
end

-- The character's Resolve level (0..MAX_LEVEL). Overridable in tests.
function R.levelOf(player)
    if not player then return 0 end
    local perk = R.perk()
    if not perk then return 0 end
    local ok, lvl = pcall(function() return player:getPerkLevel(perk) end)
    if not ok then return 0 end
    lvl = math.floor(tonumber(lvl) or 0)
    return math.max(0, math.min(tonumber(R.MAX_LEVEL) or 10, lvl))
end
WTAGarou.ResolveLevelOf = function(player) return R.levelOf(player) end

-- ---------------------------------------------------------------------------
-- XP
-- ---------------------------------------------------------------------------
local function addXpTo(player, perk, amount)
    -- 0.5.0 playtest: plain addXp/AddXP apply the trait XP-boost table, and a
    -- skill with no starting boost (Resolve) learns at 25%: +3 showed as 0.75
    -- (3 + 5 + 3 read 2.75 in the skills panel). Resolve awards are exact, so
    -- use the engine's no-multiplier path first (B42.21 LuaManager
    -- addXpNoMultiplier -> GameServer.addXp(..., true) / AddXP(perk, amt, true,
    -- false, false)). This also skips sandbox XP multipliers for Resolve.
    if addXpNoMultiplier ~= nil then -- Java globals may not report type "function"
        local ok = pcall(function() addXpNoMultiplier(player, perk, amount) end)
        if ok then return true end
    end
    local okDirect = pcall(function() player:getXp():AddXP(perk, amount, true, false, false) end)
    if okDirect then return true end
    print("[WTAGarou][Resolve] no-multiplier XP API unavailable; falling back to boosted addXp")
    if type(addXp) == "function" then
        local ok = pcall(function() addXp(player, perk, amount) end)
        if ok then return true end
    end
    local ok = pcall(function() player:getXp():AddXP(perk, amount) end)
    return ok
end

-- Server side (and single player): grant validated Resolve XP. Returns the
-- amount actually granted (0 when the perk is missing or the level is capped).
function R.grant(player, amount, why)
    amount = tonumber(amount) or 0
    if not player or amount <= 0 then return 0 end
    local perk = R.perk()
    if not perk then
        print("[WTAGarou][Resolve] perk " .. tostring(R.PERK) .. " is not registered; no XP for " .. tostring(why))
        return 0
    end
    if R.levelOf(player) >= (tonumber(R.MAX_LEVEL) or 10) then return 0 end
    if R.CLIENT_APPLIES_XP then return amount end  -- the client applies; the server only validated
    if not addXpTo(player, perk, amount) then
        print("[WTAGarou][Resolve] addXp failed for " .. tostring(why))
        return 0
    end
    return amount
end

-- Owning client: apply XP the server validated (only when CLIENT_APPLIES_XP).
function R.applyOnClient(player, amount)
    if not R.CLIENT_APPLIES_XP then return false end
    local perk = R.perk()
    if not perk or not player then return false end
    return addXpTo(player, perk, tonumber(amount) or 0)
end

-- Testing only: force a level on the local character (/garou resolve n).
function R.setLevel(player, level)
    local perk = R.perk()
    if not perk or not player then return false end
    level = math.max(0, math.min(tonumber(R.MAX_LEVEL) or 10, math.floor(tonumber(level) or 0)))
    local ok = pcall(function()
        local xp = player:getXp()
        if xp.setXPToLevel then xp:setXPToLevel(perk, level); return end
        player:level0(perk)
        for _ = 1, level do player:LevelPerk(perk) end
    end)
    return ok
end

-- ---------------------------------------------------------------------------
-- Moonlight exposure (0..1) for the shift formula.
--   sky access x moon brightness x sky weight x (1 - cloud) x (1 - fog)
--   sky weight = DAY_SHARE + (1 - DAY_SHARE) x night strength
-- ---------------------------------------------------------------------------
function WTAGarou.MoonBrightness()
    local M = WTAGarou.MoonLight or {}
    local full = tonumber(M.FULL_MOON_FLOAT) or 0.7
    local ok, v = pcall(function()
        local moon = getClimateMoon and getClimateMoon() or (ClimateMoon and ClimateMoon.getInstance and ClimateMoon.getInstance())
        if not moon then return nil end
        if moon.getMoonFloat then
            local f = moon:getMoonFloat()
            if f ~= nil then return clamp01((tonumber(f) or 0) / full) end
        end
        if moon.getCurrentMoonPhase then
            local phase = tonumber(moon:getCurrentMoonPhase())
            local light = phase and (M.PHASE_LIGHT or {})[phase]
            if light then return clamp01(light / full) end
        end
        return nil
    end)
    if ok and v then return v end
    return 0
end

-- A tile-local rule, not rendered brightness (which includes lamps).
-- Only an edge to an UNROOFED outdoor cardinal neighbour qualifies. No diagonals,
-- whole-room exposure, wall penetration, or recursive doorway chains.
local function openingExposed(square, other)
    if not other or not other:isOutside() or other:haveRoofFull() ~= false then return false end
    local window = square:getWindowTo(other)
    if window then
        if window:isBarricaded() then return false end
        local curtain = window:HasCurtains()
        return not curtain or curtain:isCurtainOpen()
    end
    local door = square:getDoorTo(other)
    if door then return door:IsOpen() and not door:isBarricaded() end
    -- Only fall back when the door object is absent. A frame behind a
    -- closed/replacement door must not leak exposure. This covers a bare
    -- doorway and the remaining frame after removal/destruction alike,
    -- without remembering deleted objects or trusting arbitrary wall gaps.
    -- B42.21 has no getDoorFrameTo. DoorWallN/W belong to the tile
    -- south/east of their edge, as in the engine's isDoorSquare().
    local dx, dy = other:getX() - square:getX(), other:getY() - square:getY()
    local owner, flag
    if dx == 0 and math.abs(dy) == 1 then
        owner = dy < 0 and square or other
        flag = IsoFlagType and IsoFlagType.DoorWallN
    elseif dy == 0 and math.abs(dx) == 1 then
        owner = dx < 0 and square or other
        flag = IsoFlagType and IsoFlagType.DoorWallW
    end
    if not owner or not flag or not owner.getProperties
        or not square.isBlockedTo or not other.isBlockedTo then return false end
    local properties = owner:getProperties()
    return properties ~= nil and properties.has ~= nil and properties:has(flag)
        and not square:isBlockedTo(other) and not other:isBlockedTo(square)
end

function WTAGarou.MoonSkyAccess(player)
    if not player then return 0 end
    local ok, access = pcall(function()
        local square = player.getSquare and player:getSquare()
        -- Exterior does not establish open sky: a covered porch may still
        -- be outside. Require an explicit unroofed result. Missing tile or
        -- roof API fails closed; never fall back to player:isOutside().
        if not square then return 0 end
        if square:isOutside() then return square:haveRoofFull() == false and 1 or 0 end
        if (WTAGarou.MoonLight or {}).OPENINGS == false then return 0 end
        local cell = square:getCell()
        if not cell then return 0 end
        local x, y, z = square:getX(), square:getY(), square:getZ()
        for _, offset in ipairs({{0,-1}, {1,0}, {0,1}, {-1,0}}) do
            -- A missing tile/API fails closed for this edge, not the others.
            local edgeOK, exposed = pcall(function()
                return openingExposed(square, cell:getGridSquare(x + offset[1], y + offset[2], z))
            end)
            if edgeOK and exposed then return 1 end
        end
        return 0
    end)
    return ok and access or 0
end

function WTAGarou.MoonLightExposure(player)
    local M = WTAGarou.MoonLight or {}
    if M.ENABLED == false or not player then return 0 end
    local ok, exposure = pcall(function()
        local access = WTAGarou.MoonSkyAccess(player)
        if access == 0 then return 0 end
        local cm = getClimateManager and getClimateManager() or nil
        if not cm then return 0 end
        local night = clamp01(cm:getNightStrength())
        local cloud = clamp01(cm:getCloudIntensity())
        local fog = clamp01(cm:getFogIntensity())
        local day = clamp01(tonumber(M.DAY_SHARE) or 0)
        local sky = day + (1 - day) * night
        return clamp01(access * WTAGarou.MoonBrightness() * sky * (1 - cloud) * (1 - fog))
    end)
    if ok and exposure then return exposure end
    return 0
end

-- Called by the authoritative Rage tick and immediately before a howl/shift.
-- Always overwrite, including zero, so moving indoors cannot retain a bonus.
function WTAGarou.UpdateMoonExposure(player, data)
    data.moonExposure = WTAGarou.MoonLightExposure(player)
    return data.moonExposure
end

-- ---------------------------------------------------------------------------
-- Skill-panel tooltip text (0.5.0 ship). Vanilla ISSkillProgressBar shows
-- IGUI_perks_<id>_Description under every level box and, when present,
-- IGUI_perks_<id>_Description<level> for the box hovered. IG_UI.json holds
-- these exact strings (tests/resolve_test.lua compares them); the client
-- hook in WTAGarouSkillTooltip.lua swaps in the same text if a raw key ever
-- shows. Built from the live tables so the numbers cannot drift.
-- ---------------------------------------------------------------------------
R.text = R.text or {}
function R.text.main()
    return "Your control over the Rage. Train it by shifting or by resisting the forced change at 100 Rage;"
        .. " every third resist in a row gives the most XP. Every werewolf starts with the Crinos zombie charge:"
        .. " sprinting knocks down the first " .. tostring((R.CROWD_CHARGE_LIMIT or {})[0] or 3) .. " zombies you run into."
end

local function changesAt(level)
    local out = {}
    local U = R.UNLOCK or {}
    local crowd = (R.CROWD_CHARGE_LIMIT or {})[level]
    if level == U.CROWD_CHARGE then
        out[#out + 1] = string.format("New: zombie charge. Sprinting in Crinos knocks down the first %d zombies you run into.", crowd or 3)
    elseif crowd then
        out[#out + 1] = string.format("Zombie charge: knocks down %d zombies.", crowd)
    end
    local roar = (R.ROAR_FORCE or {})[level]
    if level == U.ROAR_STAGGER then
        out[#out + 1] = "New: roar stagger. The Q roar in Crinos pushes nearby zombies back."
    elseif roar then
        out[#out + 1] = string.format("Roar stagger: pushes harder (%gx).", roar)
    end
    if level == U.DOOR_CHARGE then
        local D = WTAGarou.DoorCharge or {}
        out[#out + 1] = string.format("New: door charge. Sprinting in Crinos smashes closed wooden doors (%d Rage, %d if locked, plus stamina).",
            D.RAGE or 12, D.RAGE_LOCKED or 18)
    end
    return out
end

function R.text.level(level)
    level = math.floor(tonumber(level) or 0)
    if level < 1 or level > (R.MAX_LEVEL or 10) then return nil end
    local width = WTAGarou.ShiftBufferWidth(level)
    local entry = (tonumber((WTAGarou.GetForm("Crinos") or {}).rageRequired) or 55) - width
    local lock = tonumber(WTAGarou.Rage.CRINOS_LOCK_ABOVE) or 75
    local lockB = tonumber(WTAGarou.Rage.CRINOS_LOCK_ABOVE_BERSERKER) or 55
    local lines = {
        string.format("Crinos window %d Rage: start Crinos from %d Rage, leave it at up to %d (Berzerker: leave at up to %d).",
            width, entry, lock + width, lockB + width),
        string.format("Each resist takes %.1f s off the next countdown.", WTAGarou.ResolveResistStep(level)),
        string.format("Rage settles back to baseline %d%% faster.", math.floor(level * (R.BASELINE_PULL_BONUS_PER_LEVEL or 0) * 100 + 0.5)),
    }
    for _, l in ipairs(changesAt(level)) do lines[#lines + 1] = l end
    return table.concat(lines, " <LINE> ")
end
