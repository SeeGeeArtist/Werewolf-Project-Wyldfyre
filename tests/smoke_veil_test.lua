-- 0.4.83: the silver smoke vision veil (client presentation only).
local root = arg[1] or "."
package.path = root .. "/42/media/lua/client/?.lua;" .. package.path
local n = 0
local function check(ok, why) n = n + 1; assert(ok, why) end

-- No ISUIElement here: the pure part (touch/step/paint) must work without it.
WTAGarou = WTAGarou or {}
require "WTAGarouSmokeVeil"
local V = WTAGarou.SmokeVeil
check(V and V.touch and V.step and V.paint and V.active, "module loaded without the UI")
check(V.alpha == 0 and not V.active(), "clear at start")

-- Untouched: stays clear.
check(V.step(0.5, 100) == 0, "no dust, no veil")

-- First cue: the sting rises fast.
V.touch(100)
local a1 = V.step(0.1, 100.1)
check(a1 > 0 and a1 <= V.MAX_ALPHA and V.active(), "rises after the server's cue: " .. tostring(a1))
V.step(0.5, 100.6)
local a2 = V.step(0.5, 101.1)
check(math.abs(a2 - V.MAX_ALPHA) < 1e-6, "reaches MAX_ALPHA within about half a second")

-- Cues once a second keep it up (HOLD covers a server sweep gap).
V.touch(101)
V.step(1.0, 102.0)
V.touch(102)
V.step(1.0, 103.0)
check(math.abs(V.alpha - V.MAX_ALPHA) < 1e-6, "steady cues keep the veil at full")

-- Silence: fades over a few seconds, never below zero.
local last = V.alpha
local t = 103.0
local cleared
for i = 1, 40 do
    t = t + 0.25
    local a = V.step(0.25, t)
    check(a <= last + 1e-9, "fades monotonically")
    last = a
    if a == 0 and not cleared then cleared = t end
end
check(cleared and (cleared - 103.0 - V.HOLD) >= 2.5 and (cleared - 103.0 - V.HOLD) <= 4.0,
      "clears about three seconds after the hold ends: " .. tostring(cleared and cleared - 103.0 - V.HOLD))
check(not V.active(), "inactive once clear")

-- Huge frame gaps are clamped so a hitch cannot pop the veil to full.
V.alpha = 0
V.touch(200)
V.step(5.0, 200.1)
check(V.alpha <= V.RISE_PER_S * 0.5 + 1e-6, "dt is clamped to half a second: " .. tostring(V.alpha))

-- Paint: a haze plus a vignette of rings, all inside the screen.
local rects = {}
local ui = { drawRect = function(_, x, y, w, h, a, r, g, b) rects[#rects + 1] = { x = x, y = y, w = w, h = h, a = a, r = r, g = g, b = b } end }
check(V.paint(ui, 1920, 1080, 0) == 0 and #rects == 0, "nothing drawn when clear")
local drawn = V.paint(ui, 1920, 1080, V.MAX_ALPHA)
check(drawn == 1 + 4 * V.BANDS and #rects == drawn, "no texture: haze plus four strips per vignette band (fallback)")
check(rects[1].w == 1920 and rects[1].h == 1080 and rects[1].a < V.MAX_ALPHA and rects[1].r > 0.7, "the haze covers the screen and is pale silver, not opaque")
for _, r in ipairs(rects) do
    check(r.x >= 0 and r.y >= 0 and r.x + r.w <= 1920 and r.y + r.h <= 1080, "every rect stays on screen")
    check(r.a > 0 and r.a <= 1, "alpha in range")
end
check(rects[2].a > rects[#rects].a, "outer vignette bands are darker than inner ones")
check(rects[2].a > 0.85 and rects[2].a / V.MAX_ALPHA > 0.95, "0.4.94: the outermost band is nearly solid")
local span = 0
for i = 2, #rects do span = math.max(span, rects[i].y + rects[i].h) end
check(span >= 1080 * 0.9 and #rects >= 1 + 4 * 12, "0.4.94: finer rings reach well toward the centre")

-- 0.4.94: with the gradient texture present, one stretched draw replaces the rings
V.texture = { name = "smoke_vignette" }
local draws = {}
local ui2 = {
    drawRect = function(_, x, y, w, h, a, r, g, b) draws[#draws + 1] = { kind = "rect", a = a } end,
    drawTextureScaled = function(_, tex, x, y, w, h, a, r, g, b) draws[#draws + 1] = { kind = "tex", tex = tex, x = x, y = y, w = w, h = h, a = a, r = r, g = g, b = b } end,
}
check(V.paint(ui2, 1920, 1080, V.MAX_ALPHA) == 2 and #draws == 2 and draws[2].kind == "tex", "haze plus the radial-gradient texture")
check(draws[2].x == 0 and draws[2].y == 0 and draws[2].w == 1920 and draws[2].h == 1080 and draws[2].tex == V.texture, "texture stretched over the whole screen")
check(draws[2].a > 0.85 and draws[2].r < 0.2 and draws[2].g < 0.2 and draws[2].b < 0.2, "tinted dark, nearly solid at full alpha")
check(V.TEXTURE == "media/ui/WTAGarou/smoke_vignette.png", "texture path")
local f = io.open(root .. "/42/" .. V.TEXTURE, "rb"); check(f ~= nil, "the vignette PNG ships"); if f then f:close() end
V.texture = nil

print(string.format("PASS: %d smoke veil assertions.", n))
