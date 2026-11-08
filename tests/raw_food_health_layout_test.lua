-- Fixtures only: not proof of live rendering or hosted multiplayer behavior.
local root = assert(arg[1], "supply WTAGarou directory")
local count = 0
local function check(ok, msg) count = count + 1; assert(ok, msg) end
package.loaded["WTAGarouDefinitions"] = true
package.loaded["WTAGarouState"] = true
package.loaded["TimedActions/ISEatFoodAction"] = true
WTAGarou = { HasGarouTrait = function(p) return p.garou end }
CharacterStat = { POISON = "poison" }
local client = false
isClient = function() return client end
local stats = { poison = 7, nutrition = 0 }
function stats:get(k) return self[k] end
function stats:set(k, v) self[k] = v end
local food = { dangerous = true, cooked = false, rotten = false, tainted = false, power = 0 }
function food:isbDangerousUncooked() return self.dangerous end
function food:isCooked() return self.cooked end
function food:isRotten() return self.rotten end
function food:isTainted() return self.tainted end
function food:getPoisonPower() return self.power end
local player = { garou = true, getStats = function() return stats end }
local action = { character = player, item = food, percentage = 0.5 }
local calls = 0
local function consume(self, _, fraction)
    calls = calls + 1
    stats.poison = stats.poison + 12
    stats.nutrition = stats.nutrition + (fraction or self.percentage)
    return true
end
ISEatFoodAction = { complete = consume, eat = consume }
dofile(root .. "/42/media/lua/shared/WTAGarouRawFood.lua")
local R = WTAGarou.RawFood
check(R.install() == false, "install once")
check(ISEatFoodAction.complete(action) == true and stats.poison == 7, "preserve existing poison")
check(calls == 1 and stats.nutrition == 0.5, "one native full meal")
ISEatFoodAction.eat(action, food, 0.25)
check(calls == 2 and stats.poison == 7 and stats.nutrition == 0.75, "one native partial meal")
for _, key in ipairs({ "cooked", "rotten", "tainted" }) do
    food[key] = true; stats.poison = 7
    ISEatFoodAction.complete(action)
    check(stats.poison == 19, key .. " unchanged")
    food[key] = false
end
food.power = 5; stats.poison = 7
ISEatFoodAction.complete(action)
check(stats.poison == 19, "explicit poison retained")
food.power = 0; food.dangerous = false; stats.poison = 7
ISEatFoodAction.complete(action)
check(stats.poison == 19, "non-dangerous food untouched")
food.dangerous = true; player.garou = false; stats.poison = 7
ISEatFoodAction.complete(action)
check(stats.poison == 19, "human unaffected")
player.garou = true; client = true; stats.poison = 7
ISEatFoodAction.complete(action)
check(stats.poison == 19, "client cannot restore body stats")
client = false; stats.poison = 7
local saved = R.before(action); stats.poison = 3; R.after(saved)
check(stats.poison == 3, "legitimate reduction retained")
check(R.before({ character = player, item = {} }) == nil, "missing API fails closed")

package.loaded["WTAGarouHealthPanel"] = true
WTAGarou.HealthPanel = {}
UIFont = { Small = 1 }
local font = 14
getTextManager = function() return {
    getFontHeight = function() return font end,
    MeasureStringX = function(_, _, s) return #s * 8 end,
} end
getCore = function() return { getScreenHeight = function() return 720 end } end
dofile(root .. "/42/media/lua/client/WTAGarouHealthPanelLayout.lua")
local HP = WTAGarou.HealthPanel
local box = { x = 150, y = 100, height = 40, scroll = 40 }
function box:getX() return self.x end
function box:getY() return self.y end
function box:setY(v) self.y = v end
function box:getScrollHeight() return self.scroll end
function box:setHeight(v) self.height = v end
function box:setWidth(v) self.width = v end
box.vscroll = { setHeight = function(_, v) box.scrollbarHeight = v end }
local panel = { listbox = box, width = 320, y = 20,
    healthPanel = { getRight = function() return 140 end, getBottom = function() return 313 end } }
function panel:getWidth() return self.width end
function panel:getY() return self.y end
function panel:setWidthAndParentWidth(v) self.width = v end
function panel:setHeightAndParentHeight(v) self.height = v end
function panel:drawText(s, x, y) self.drawn[#self.drawn + 1] = { text = s, x = x, y = y } end
local text = "- Wyrm Infection (purging 40%, 3:00)"
local color = { r = 1, g = 1, b = 1 }
-- Wrap width = 320 - 150 - 10 = 160 px = 20 chars; indent "- " = 16 px.
for i = 1, 50 do
    box.y = 100; box.height = 40; panel.drawn = {}
    HP.drawSizedLine(panel, text, color)
    check(#panel.drawn == 3 and box.y == 100 + 14 * 3 and box.height == 40, "wrapped lines push the list, frame " .. i)
end
check(panel.width == 320, "panel width is never widened")
check(box.width == nil and box.textRight == nil, "list width bookkeeping left to vanilla")
check(panel.drawn[1].text == "- Wyrm Infection" and panel.drawn[1].x == 150 and panel.drawn[1].y == 100, "name on the first line")
check(panel.drawn[2].text == "(purging 40%," and panel.drawn[2].x == 166 and panel.drawn[2].y == 114, "purge note starts its own indented line")
check(panel.drawn[3].text == "3:00)" and panel.drawn[3].y == 128, "long note wraps again")
for _, l in ipairs(panel.drawn) do check(#l.text * 8 + (l.x - 150) <= 160 or not l.text:find(" "), "line fits the wrap width: " .. l.text) end
check(box.scrollbarHeight == box.height and panel.allTextHeight == 182 and panel.height == 347, "no compounded growth")
panel.width = 600; box.y = 100; panel.drawn = {}
HP.drawSizedLine(panel, text, color)
check(#panel.drawn == 2 and panel.drawn[2].text == "(purging 40%, 3:00)", "wide panel: name and note on two lines")
panel.drawn = {}; box.y = 100
HP.drawSizedLine(panel, "- Wyrm Infection", color)
check(#panel.drawn == 1 and box.y == 114, "plain line stays one line")
panel.width = 320
panel.drawn = {}; box.y = 100; box.scroll = 900
HP.drawSizedLine(panel, text, color)
check(box.height == 524 and panel.height == 700, "long list screen clamp")
font = 24; box.y = 100; box.scroll = 40; panel.drawn = {}
HP.drawSizedLine(panel, text, color)
check(box.y == 100 + 24 * 3 and box.height == 40, "larger font retains list")
font = 14
panel.parent = { getY = function() return 40 end, parent = {} }
box.y = 100; box.scroll = 900; panel.drawn = {}
HP.drawSizedLine(panel, text, color)
check(panel.height == 660 and box.height == 484, "nested origin respected")
print("PASS: " .. count .. " raw-food / health-layout fixture assertions.")
