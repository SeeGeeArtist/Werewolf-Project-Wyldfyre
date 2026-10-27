--[[
    WTAGarou - Silver smoke veil (client, 0.4.83)

    Oct 23 hosted playtest: the silver smoke bomb burned and made the Garou
    cough, "but there was no visual change ... Maybe it should cause head
    silver burn and greatly impaired vision, as if it's silver burning the
    werewolf's eyes."

    The engine's smoke-bomb smoke is IsoFire objects started by
    IsoFireManager.StartSmoke, which drawCircleExplosion only starts on a
    FireStartingChance roll and which multiplayer clients do not own, so a
    thrown smoke bomb can show nothing at all in a hosted game. The blur
    the engine uses for short-sightedness is a private field with no
    setter. So the Garou's impaired vision is drawn here: a pale silver
    veil over the whole screen with a heavy dark vignette while the server
    says the player is breathing dust, fading out over a few seconds once
    they are clear of it.

    Driven only by the server's SilverSmoke command (0.4.75: the server
    owns the body; this is pure presentation). The server sends one every
    body sweep (~1 s) while the player stands in a cloud, with cough=true
    on the cough cadence. touch() keeps the veil up; silence lets it fade.

    The element wants no mouse events and sits behind the other UI, so
    menus, the inventory and the Rage panel stay usable through it.
]]

WTAGarou = WTAGarou or {}
WTAGarou.SmokeVeil = WTAGarou.SmokeVeil or {}
local V = WTAGarou.SmokeVeil

V.MAX_ALPHA   = 0.90     -- fully in the dust (0.4.94: heavier, "could be more opaque")
V.HOLD        = 2.0      -- seconds a touch keeps the target up (server sweeps ~1 s apart)
V.RISE_PER_S  = 2.0      -- alpha per second while rising (stings fast)
V.FALL_PER_S  = 0.25     -- alpha per second while clearing (~3 s to see again)
V.HAZE        = { r = 0.84, g = 0.86, b = 0.90 }   -- pale silver haze
V.EDGE        = { r = 0.10, g = 0.10, b = 0.13 }   -- vignette
V.BANDS       = 14       -- fallback vignette rings (no texture), outermost darkest
V.BAND_SPAN   = 0.48     -- fallback: fraction of the short screen side the rings cover
-- 0.4.94: the vignette is a radial-gradient texture stretched over the
-- screen (bilinear filtered, so no banding or blocky steps); the ring
-- fallback only draws when the texture is missing.
V.TEXTURE     = "media/ui/WTAGarou/smoke_vignette.png"
V.texture     = nil
V.textureTried = false

V.alpha     = 0
V.target    = 0
V.lastTouch = nil
V.lastTick  = nil
V.element   = nil

local function nowSeconds()
    if getTimestampMs then return getTimestampMs() / 1000 end
    return os.time()
end

-- Server said: breathing silver dust right now.
function V.touch(now)
    V.lastTouch = now or nowSeconds()
    V.target = V.MAX_ALPHA
end

-- Pure step: advance alpha by dt seconds. Returns the new alpha.
function V.step(dt, now)
    dt = math.max(0, math.min(0.5, tonumber(dt) or 0))
    now = now or nowSeconds()
    if V.lastTouch and (now - V.lastTouch) <= V.HOLD then
        V.target = V.MAX_ALPHA
    else
        V.target = 0
    end
    if V.alpha < V.target then
        V.alpha = math.min(V.target, V.alpha + V.RISE_PER_S * dt)
    elseif V.alpha > V.target then
        V.alpha = math.max(V.target, V.alpha - V.FALL_PER_S * dt)
    end
    return V.alpha
end

function V.active() return V.alpha > 0.005 end

function V.vignetteTexture()
    if V.texture or V.textureTried then return V.texture end
    V.textureTried = true
    if getTexture then pcall(function() V.texture = getTexture(V.TEXTURE) end) end
    return V.texture
end

-- Draw with any object offering drawRect(x, y, w, h, a, r, g, b) and,
-- for the gradient, drawTextureScaled(tex, x, y, w, h, a, r, g, b).
function V.paint(ui, w, h, alpha)
    alpha = alpha or V.alpha
    if alpha <= 0.005 then return 0 end
    local n = 0
    -- haze
    ui:drawRect(0, 0, w, h, alpha * 0.70, V.HAZE.r, V.HAZE.g, V.HAZE.b); n = n + 1
    local e = V.EDGE
    local tex = V.vignetteTexture()
    if tex and ui.drawTextureScaled then
        -- radial gradient: clear window in the centre, solid silver-dark by the edges
        ui:drawTextureScaled(tex, 0, 0, w, h, alpha * 0.98, e.r, e.g, e.b)
        return n + 1
    end
    -- fallback vignette: rings from the edge inward, each fainter (smooth curve)
    local bands = V.BANDS
    local thick = math.max(1, math.floor(math.min(w, h) * V.BAND_SPAN / bands))
    for i = 0, bands - 1 do
        local inset = i * thick
        local f = 1 - i / bands
        local a = alpha * (0.98 * f * f)
        -- top, bottom, left, right strips of this ring
        ui:drawRect(inset, inset, w - 2 * inset, thick, a, e.r, e.g, e.b)
        ui:drawRect(inset, h - inset - thick, w - 2 * inset, thick, a, e.r, e.g, e.b)
        ui:drawRect(inset, inset + thick, thick, h - 2 * inset - 2 * thick, a, e.r, e.g, e.b)
        ui:drawRect(w - inset - thick, inset + thick, thick, h - 2 * inset - 2 * thick, a, e.r, e.g, e.b)
        n = n + 4
    end
    return n
end

-- UI element -------------------------------------------------------------
if ISUIElement then
    local Veil = ISUIElement:derive("WTAGarouSmokeVeil")
    V.Veil = Veil

    function Veil:new()
        local w, h = 1920, 1080
        pcall(function() w, h = getCore():getScreenWidth(), getCore():getScreenHeight() end)
        local o = ISUIElement:new(0, 0, w, h)
        setmetatable(o, self)
        self.__index = self
        o.wantMouseEvents = false
        o.anchorRight = true
        o.anchorBottom = true
        return o
    end

    function Veil:prerender()
        local now = nowSeconds()
        local dt = V.lastTick and (now - V.lastTick) or 0
        V.lastTick = now
        V.step(dt, now)
        if not V.active() then return end
        pcall(function()
            local w, h = getCore():getScreenWidth(), getCore():getScreenHeight()
            if w ~= self:getWidth() or h ~= self:getHeight() then self:setWidth(w); self:setHeight(h) end
        end)
        V.paint(self, self:getWidth(), self:getHeight(), V.alpha)
    end

    function Veil:render() end
    function Veil:onMouseDown() return false end
    function Veil:onMouseUp() return false end
    function Veil:onRightMouseDown() return false end
    function Veil:onRightMouseUp() return false end
    function Veil:onMouseMove() return false end
    function Veil:onMouseWheel() return false end

    function V.ensure()
        if V.element then return V.element end
        local ok, err = pcall(function()
            local el = Veil:new()
            el:initialise()
            el:addToUIManager()
            el:backMost()
            V.element = el
        end)
        if not ok then print("[WTAGarou][SmokeVeil] element failed: " .. tostring(err)) end
        return V.element
    end

    if Events and Events.OnGameStart then
        Events.OnGameStart.Add(function() V.ensure() end)
    end
end
