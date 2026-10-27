--[[
    WTAGarou - Scattered silver tile sprites (0.4.82)

    Why this file exists (Oct 22 hosted 0.4.81 playtest: "I don't see the
    scattered silver fragments on the ground"):

    An IsoObject is saved, and sent to clients in the AddItemToMap packet,
    by its sprite's NUMERIC id (IsoObject.save puts sprite.id), not by its
    texture path. The sprite manager's single-texture sprites, the ones
    IsoSpriteManager.getSprite(path) makes for any unknown texture path,
    never get an id, so every client (and every save reload) resolved that
    id to the manager's empty sprite "" and drew nothing. The tile was there
    (it burned feet, lodged fragments, answered the right-click), it just
    had no picture anywhere but inside the process that placed it.

    Fix: register the four tile textures with FIXED ids on both the client
    and the server, before anything can place or receive one. The id block
    follows the engine's own tile-definition formula
        1048576 + (fileNumber - 2) * 262144 + (tileset - 1) * 512 + i
    with a file number (3000) far above the vanilla sheets and the 100..999
    band mod .tiles files use, so it cannot collide with a real tilesheet.
    Done on OnLoadedTileDefinitions (the engine fires it, with the sprite
    manager, right after it has loaded the vanilla and mod tile definitions)
    and lazily from ensure() wherever a sprite is needed, in case the event
    fired before this file loaded (the server loads Lua at a different point
    than a client does).

    Both sides register the same path -> id, so a tile placed by the server
    draws the server-chosen variant on every client. The server has no GPU
    texture for the path (getSharedTexture returns null there), which is
    fine: it only needs the id.

    Shared file on purpose: server Lua is not loaded on a multiplayer
    client, and the client needs the registration most of all.
]]

WTAGarou = WTAGarou or {}
WTAGarou.ScatterSprites = WTAGarou.ScatterSprites or {}
local SS = WTAGarou.ScatterSprites

SS.PATHS = {
    "media/textures/WTAGarou/WTAGarou_SilverScatter_0.png",
    "media/textures/WTAGarou/WTAGarou_SilverScatter_1.png",
    "media/textures/WTAGarou/WTAGarou_SilverScatter_2.png",
    "media/textures/WTAGarou/WTAGarou_SilverScatter_3.png",
}

-- Engine tile-id formula (IsoWorld.LoadTileDefinitionsPropertyStrings):
-- fileNumber 3000, tileset 1. 1048576 + 2998 * 262144 = 786956288.
SS.FILE_NUMBER = 3000
SS.ID_BASE     = 1048576 + (SS.FILE_NUMBER - 2) * 262144

function SS.idFor(index)                -- 1-based index into PATHS
    return SS.ID_BASE + (index - 1)
end

SS.ids = {}                            -- path -> id, filled by register()
SS.UNSET_ID = 20000000                 -- IsoSprite.id default: an id-less single-texture sprite

function SS.isScatterSpriteName(name)
    if not name then return false end
    for _, p in ipairs(SS.PATHS) do
        if p == name then return true end
    end
    return false
end

-- Register every variant with its fixed id. Idempotent: a second call finds
-- the path already in the manager's named map and the engine keeps the
-- first id (which is the same id). Returns true when all four registered.
function SS.register(manager)
    manager = manager or (IsoSpriteManager and IsoSpriteManager.instance)
    if not manager then return false end
    local okAll = true
    for i, path in ipairs(SS.PATHS) do
        local id = SS.idFor(i)
        local ok, err = pcall(function()
            local spr = manager:AddSprite(path, id)
            -- Single-texture sprites have a nil name; vanilla menus and
            -- IsoSprite.getSprite(manager, spr, offset) read it.
            if spr and spr.setName then spr:setName(path) end
            if spr and spr.getID and spr:getID() ~= id then
                -- Something made this path id-less before us (the engine
                -- keeps the first id for a duplicate texture). Saved tiles
                -- would not resolve; say so instead of failing silently.
                error("path already registered with id " .. tostring(spr:getID()))
            end
        end)
        if ok then
            SS.ids[path] = id
        else
            okAll = false
            print("[WTAGarou][Scatter] sprite register failed for " .. path .. ": " .. tostring(err))
        end
    end
    if okAll then
        print(string.format("[WTAGarou][Scatter] %d tile sprites registered, ids %d..%d",
            #SS.PATHS, SS.ID_BASE, SS.ID_BASE + #SS.PATHS - 1))
    end
    return okAll
end

-- True when every variant id resolves in the live manager. Checked by id,
-- not by a Lua flag: IsoWorld.init disposes the whole sprite manager
-- (IsoSpriteManager.Dispose clears both maps) before it loads tile
-- definitions, so anything registered at file load is gone by the time the
-- world exists. OnLoadedTileDefinitions re-registers after that wipe.
function SS.registered()
    local manager = IsoSpriteManager and IsoSpriteManager.instance
    if not manager then return false end
    for i = 1, #SS.PATHS do
        local found
        local ok = pcall(function() found = IsoSprite.getSprite(manager, SS.idFor(i)) end)
        if not ok or not found then return false end
    end
    return true
end

-- Call before placing a tile or looking one up by name.
function SS.ensure()
    if SS.registered() then return true end
    return SS.register()
end

-- Resolve a variant path to its registered IsoSprite (nil when the manager
-- is not up yet). Place tiles with the sprite object, never the bare path,
-- so a sprite that somehow slipped past registration cannot be created
-- id-less by getSprite(path).
function SS.sprite(path)
    SS.ensure()
    if not (IsoSpriteManager and IsoSpriteManager.instance) then return nil end
    local spr
    pcall(function() spr = IsoSpriteManager.instance:getSprite(path) end)
    return spr
end

if Events and Events.OnLoadedTileDefinitions then
    Events.OnLoadedTileDefinitions.Add(function(manager) SS.register(manager) end)
end
if Events and Events.OnGameBoot then
    Events.OnGameBoot.Add(function() SS.ensure() end)
end
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function() SS.ensure() end)
end
-- Early attempt at file load (the manager exists very early on both sides).
SS.ensure()
