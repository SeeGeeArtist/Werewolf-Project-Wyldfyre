-- Regression contract for the user's repeated nil-animation and HUD reports.
-- The mock base setter intentionally enables the action layer even for nil.
-- Testing only nil arguments would have missed the actual reported behavior.
local root = assert(arg[1], "supply WTAGarou directory")
package.path = root .. "/42/media/lua/shared/?.lua;" .. package.path
require "WTAGarouDefinitions"
require "WTAGarouState"
local checks = 0
local function check(ok, message)
    checks = checks + 1
    assert(ok, message)
end
local function derive(self, name)
    local cls = { Type = name }
    cls.__index = cls
    return setmetatable(cls, { __index = self })
end

ISBaseTimedAction = { derive = derive }
function ISBaseTimedAction:new(player) return setmetatable({character=player}, self) end
function ISBaseTimedAction:setActionAnim(...)
    self.animCalls = (self.animCalls or 0) + 1
    self.animArgCount = select("#", ...)
    self.anim, self.modelArg = ...
    self.character:setVariable("PerformingAction", self.anim)
    self.character:setVariable("IsPerformingAnAction", true)
end
function ISBaseTimedAction:getDuration() return self.maxTime end
function ISBaseTimedAction:stop() self.stopped = true end
function ISBaseTimedAction:perform() self.completed = true end
function ISBaseTimedAction:setAnimVariable(key, value)
    self.character:setVariable(key, value)
end
package.loaded["TimedActions/ISBaseTimedAction"] = true
package.loaded.WTAGarouNet = true
WTAGarou.Net = { ToServer = function(p, command) p.command = command end }
CharacterActionAnims = { None="RAISED_ARMS", Drink="drink", WashFace="WashFace" }
local queued
ISTimedActionQueue = { clear=function() queued=nil end, add=function(action) queued=action end }
local player = { variables={}, data={}, dead=false, sneaking=false }
function player:setVariable(k,v) self.variables[k]=v end
function player:clearVariable(k) self.variables[k]=nil end
function player:isDead() return self.dead end
function player:isSneaking() return self.sneaking end
function player:setSneaking(v) self.sneaking=v end
function player:getModData() return self.data end
player.data.WTAGarou = {isGarou=true, form="Homid", rage=50, infamy=0}
getPlayer=function() return player end
getTimestamp=function() return 100 end
getGameTime=function() return {getMultiplier=function() return 1 end} end
Events={}
for _, name in ipairs({"OnGameBoot","OnKeyPressed","OnGameStart"}) do Events[name]={Add=function() end} end
Events.OnPlayerDeath={handlers={},Add=function(h) table.insert(Events.OnPlayerDeath.handlers,h) end}
Events.OnPlayerUpdate={handlers={},Add=function(h) table.insert(Events.OnPlayerUpdate.handlers,h) end}
dofile(os.getenv("WTAGAROU_CHANNEL_UNDER_TEST") or (root .. "/42/media/lua/client/WTAGarouChannel.lua"))

check(WTAGarou.Anims.SHIFT == nil and WTAGarou.Anims.SHIFT_FALLBACK == nil,
    "definitions must keep SHIFT and SHIFT_FALLBACK nil")
local function noPose(action, label)
    check(action.animArgCount == 2 and action.anim == nil and action.modelArg == nil,
        label .. ": base receives exactly nil,nil")
    check(player.variables.PerformingAction == nil, label .. ": no named animation")
    check(player.variables.IsPerformingAnAction == false, label .. ": action layer disabled")
end
for _, form in ipairs(WTAGarou.FormOrder) do
    -- Deliberately hostile future config: the shift must IGNORE it.
    WTAGarou.Anims.SHIFT = "None"
    WTAGarou.Anims.SHIFT_FALLBACK = "WashFace"
    player.sneaking=false
    WTAGarou.Channel.startChannel(player, form, 5, "Homid")
    local action = queued
    check(action.stopOnWalk == false and action.stopOnRun == false and action.stopOnAim == false,
        "movement stays allowed")
    action:start()
    noPose(action, form .. " start")
    check(player.sneaking, "forced crouch retained")
    -- Even a direct future call cannot insert a string/enum into a shift.
    action:setActionAnim("WashFace", true)
    noPose(action, form .. " override")
    local calls = action.animCalls
    for _=1,30 do
        player.variables.PerformingAction="RAISED_ARMS"
        player.variables.IsPerformingAnAction=true
        action:update()
        noPose(action, form .. " update")
    end
    check(action.animCalls == calls, "update never reactivates setter")
    action:perform()
    check(not player.sneaking and player.command=="TransformConfirm", "complete restores stance and confirms")
    check(player.variables.WTAGarou_Shifting==nil, "complete clears own variables")
end
WTAGarou.Anims.SHIFT=nil
WTAGarou.Anims.SHIFT_FALLBACK=nil
for _, ending in ipairs({"stop","forceCancel"}) do
    player.sneaking=true
    local action=WTAGarouTransformAction:new(player,"Crinos",5,"Homid")
    action:start()
    action[ending](action)
    check(player.sneaking and player.command=="TransformCancel", ending.." restores prior crouch")
    check(player.variables.IsPerformingAnAction==false, ending.." clears pose")
end
local unstarted=WTAGarouTransformAction:new(player,"Hispo",5,"Homid")
player.variables.IsPerformingAnAction=true
player.variables.PerformingAction="drink"
unstarted:forceCancel()
check(player.variables.PerformingAction=="drink" and player.variables.IsPerformingAnAction==true,
    "cancelling an unstarted shift does not clear another action")
check(player.sneaking, "unstarted cancel does not force standing")
local howl=WTAGarouHowlAction:new(player)
howl:start()
check(howl.anim=="drink" and player.variables.IsPerformingAnAction==true,
    "howl retains Drink animation and action layer")
-- 0.4.69: Glabro/Crinos howls ask Java to mask the Drink pose to head+neck.
check(player.variables.WTAGarou_HowlMask==false, "Homid howl keeps the full drink pose (mask variable false): "..tostring(player.variables.WTAGarou_HowlMask))
do
    local saved = player.data.WTAGarou and player.data.WTAGarou.form
    player.data.WTAGarou = player.data.WTAGarou or {}
    for form, masked in pairs({Glabro=true, Crinos=true, Hispo=false, Lupus=false, Homid=false}) do
        player.data.WTAGarou.form = form
        check(WTAGarou.HowlMasksArm(player)==masked, "howl arm mask for "..form.." = "..tostring(masked))
    end
    player.data.WTAGarou.form = "Crinos"
    local masked = WTAGarouHowlAction:new(player); masked:start()
    check(player.variables.WTAGarou_HowlMask==true and player.variables.WTAGarou_Howling=="true", "Crinos howl raises both variables")
    local oldHUDFor = WTAGarou.HUDFor
    WTAGarou.HUDFor = function(_) return { clearChannelling = function() end } end
    masked:stop()
    WTAGarou.HUDFor = oldHUDFor
    check(player.variables.WTAGarou_HowlMask==nil and player.variables.WTAGarou_Howling==nil, "ending the howl clears both variables")
    -- 0.4.71: with an authored Bob_WTAGarouHowl loaded, Glabro/Crinos howls
    -- set the action name WTAGarouHowl (node in player/actions) and no mask.
    local oldJava = WTAGarouJava
    WTAGarouJava = { hasHumanClip = function(name) return name == "Bob_WTAGarouHowl" end }
    check(WTAGarou.UseAuthoredHowl(player) == true, "Crinos + clip loaded -> authored howl")
    local authored = WTAGarouHowlAction:new(player); authored:start()
    check(authored.anim == "WTAGarouHowl" and player.variables.WTAGarou_HowlMask == false and player.variables.WTAGarou_Howling == "true",
        "authored howl: action name WTAGarouHowl, no arm mask: anim=" .. tostring(authored.anim))
    WTAGarou.HUDFor = function(_) return { clearChannelling = function() end } end
    authored:stop(); WTAGarou.HUDFor = oldHUDFor
    WTAGarouJava = { hasHumanClip = function(_) return false end }
    check(WTAGarou.UseAuthoredHowl(player) == false, "clip missing -> Drink + mask as before")
    local fallback = WTAGarouHowlAction:new(player); fallback:start()
    check(fallback.anim == "drink" and player.variables.WTAGarou_HowlMask == true, "fallback howl: Drink with the mask")
    WTAGarou.HUDFor = function(_) return { clearChannelling = function() end } end
    fallback:stop(); WTAGarou.HUDFor = oldHUDFor
    player.data.WTAGarou.form = "Homid"
    WTAGarouJava = { hasHumanClip = function(_) return true end }
    check(WTAGarou.UseAuthoredHowl(player) == false, "Homid keeps the vanilla drink howl even with the clip present")
    WTAGarouJava = oldJava
    player.data.WTAGarou.form = saved
end
check(ISBaseTimedAction.setActionAnim ~= WTAGarouTransformAction.setActionAnim,
    "base timed-action class not monkeypatched")
-- 0.4.69: cancelling a howl (Escape / moving) indexed `self` inside a plain
-- local function: "attempted index: character of non-table: null" on every
-- cancel, and the HUD "Howl" channelling line never cleared.
do
    local cleared = 0
    local oldHUDFor = WTAGarou.HUDFor
    WTAGarou.HUDFor = function(_) return { clearChannelling = function() cleared = cleared + 1 end, setChannelling = function() end } end
    local okStop, err = pcall(function() howl:stop() end)
    check(okStop, "cancelling a howl raises no error: " .. tostring(err))
    check(cleared == 1 and player.command == "HowlStop" and player.variables.WTAGarou_Howling == nil,
        "cancelled howl clears the HUD channelling line, tells the server and drops the howling variable")
    local okAgain = pcall(function() howl:forceCancel() end)
    check(okAgain and cleared == 2 and howl.sentStop == true, "a second end path only clears the HUD again (HowlStop sent once)")
    WTAGarou.HUDFor = oldHUDFor
end

local oldJava=WTAGarouJava
local scopeDepth=0
WTAGarouJava={
    beginShiftAnimation=function(owner)
        check(owner==player,"Java null guard scoped to this shift owner")
        scopeDepth=scopeDepth+1
    end,
    endShiftAnimation=function() scopeDepth=scopeDepth-1 end,
}
local guardedAction=WTAGarouTransformAction:new(player,"Lupus",5,"Homid")
guardedAction:setActionAnim("None",true)
noPose(guardedAction,"Java guarded shift")
check(scopeDepth==0,"Java guard released on normal return")
local oldSetter=ISBaseTimedAction.setActionAnim
ISBaseTimedAction.setActionAnim=function() error("injected base setter failure") end
local ok=pcall(function() guardedAction:setActionAnim(nil,nil) end)
check(not ok and scopeDepth==0,"Java guard released on setter exception")
check(player.variables.IsPerformingAnAction==false,"setter exception still suppresses raised arms")
ISBaseTimedAction.setActionAnim=oldSetter
WTAGarouJava=oldJava

-- HUD mocks. Draw all forms with every color removed to reproduce Hispo.
ISCollapsableWindow={derive=derive}
function ISCollapsableWindow:new(x,y,w,h)
    local o=setmetatable({x=x,y=y,width=w,height=h,pin=true,texts={},rects={}},self)
    -- Model only existing native UIElement methods, not invented Lua aliases.
    o.javaObject={
        getXScroll=function() return o.scrollX or 0 end,
        getYScroll=function() return o.scrollY or 0 end,
        DrawTextCentre=function(_,font,s,tx,ty,r,g,b,a)
            o.titleDraws=o.titleDraws or {}
            table.insert(o.titleDraws,{text=s,x=tx,y=ty,r=r,g=g,b=b,font=font})
        end,
        -- native rect draw (ISUIElement.drawRect wraps this; the title bypasses the wrapper)
        DrawTextureScaledColor=function(_,tex,tx,ty,w,h,r,g,b,a)
            o.titleRects=o.titleRects or {}
            table.insert(o.titleRects,{x=tx,y=ty,w=w,h=h,r=r,g=g,b=b,a=a})
        end,
    }
    return o
end
function ISCollapsableWindow:setTitle(s) self.title=s end
function ISCollapsableWindow:titleBarHeight() return 16 end
function ISCollapsableWindow:createChildren() end
function ISCollapsableWindow:initialise() self:createChildren() end
function ISCollapsableWindow:addChild(c) end
function ISCollapsableWindow:addToUIManager() end
function ISCollapsableWindow:removeFromUIManager() end
function ISCollapsableWindow:prerender() end
function ISCollapsableWindow:close() self.visible=false end
function ISCollapsableWindow:isVisible() return self.visible~=false end
function ISCollapsableWindow:setVisible(v) self.visible=v end
function ISCollapsableWindow:collapse() self.pin=false end
function ISCollapsableWindow:getX() return self.x end
function ISCollapsableWindow:getY() return self.y end
function ISCollapsableWindow:setX(x) self.x=x end
function ISCollapsableWindow:setY(y) self.y=y end
function ISCollapsableWindow:drawText(s) table.insert(self.texts,s) end
function ISCollapsableWindow:drawTextCentre(s,x,y,r,g,b,a,font)
    -- Native ISUIElement suppresses this helper while collapsed. The old
    -- mock omitted that guard and falsely passed the 0.4.46 title test.
    if self.isCollapsed then return end
    self.javaObject:DrawTextCentre(font,s,x,y,r,g,b,a)
end
function ISCollapsableWindow:drawTextCentreStatic(s,x,y,r,g,b,a,font)
    -- Reproduce the broken vanilla helper; do NOT manufacture these aliases.
    self.javaObject:DrawTextCentre(font,s,x-self:getScrollX(),y-self:getScrollY(),r,g,b,a)
end
function ISCollapsableWindow:drawRect(...) table.insert(self.rects,{...}) end
ISButton={new=function(_,x,y,w,h,title,target,callback) return {x=x,y=y,width=w,height=h,title=title,target=target,callback=callback,initialise=function() end,setTooltip=function() end,
    setTitle=function(self,t) self.title=t end, setBackgroundRGBA=function(self,r,g,b,a) self.bg={r,g,b,a} end} end}
package.loaded["ISUI/ISCollapsableWindow"]=true
package.loaded.keyBinding=true
keyBinding={}
Keyboard={KEY_G=34,KEY_NONE=0}
UIFont={Small=1}
local screenW, screenH=1920,1080
local boundKeys={WTAGarou_ToggleHUD=34}
getCore=function() return {
    getScreenWidth=function() return screenW end,
    getScreenHeight=function() return screenH end,
    isKey=function(_,name,key) return boundKeys[name]~=nil and boundKeys[name]==key end,
} end
local bootHandlers={}
Events.OnGameBoot={Add=function(fn) table.insert(bootHandlers,fn) end}
dofile(os.getenv("WTAGAROU_HUD_UNDER_TEST") or (root .. "/42/media/lua/client/WTAGarouHUD.lua"))
local hud=WTAGarou.HUD.open()
-- Optional integration check using a supplied vanilla Lua reference, not a
-- second mock of the rendering helper. Native Java calls are recorded only.
if os.getenv("WTAGAROU_VANILLA_LUA") then
    ISBaseObject={derive=derive}
    package.loaded.ISBaseObject=true
    for _,name in ipairs({"ISUI/ISUITextureGetter","ISUI/Style/ISStyle",
        "ISUI/Style/UIHorizontalAlignment","ISUI/Layout/ISDock","ISUI/Layout/ISBounds","luautils"}) do
        package.loaded[name]=true
    end
    dofile(os.getenv("WTAGAROU_VANILLA_LUA").."/ISUIElement.lua")
    ISCollapsableWindow.drawTextCentre=ISUIElement.drawTextCentre
    ISCollapsableWindow.drawTextCentreStatic=ISUIElement.drawTextCentreStatic
end
check(hud.getScrollX==nil and hud.getScrollY==nil,"no fabricated scroll aliases")
local staticOK, staticErr=pcall(hud.drawTextCentreStatic,hud,"Rage 50",150,1,1,1,1,1,UIFont.Small)
check(not staticOK and tostring(staticErr):find("getScrollX",1,true),
    "reproduce Deck Static helper nil call before the meter draws")
check(hud.x==144 and hud.y==0,"1920-wide default nudged 16px left")
for _, form in ipairs(WTAGarou.FormOrder) do
    WTAGarou.FormData[form].color=nil
    player.data.WTAGarou.form=form
    for _, rage in ipairs({0,50,100}) do
        player.data.WTAGarou.rage=rage
        hud.texts={}
        hud:prerender()
        local found=false
        for _, text in ipairs(hud.texts) do
            if text=="Rage "..rage.." / 100" then found=true end
        end
        check(found,form.." rage label survives missing color at "..rage)
    end
end
local r,g,b=WTAGarou.HUD.rageColor(0)
check(r==g and g==b,"zero rage gray")
r,g,b=WTAGarou.HUD.rageColor(1)
check(r==1 and g==0 and b==0,"full rage red")
hud:setX(250); hud:setY(30); hud.pin=false
hud:prerender()
hud:close()
hud=WTAGarou.HUD.open()
check(hud.x==250 and hud.y==30 and hud.pin==false,"manual position and auto-hide persist")
WTAGarouResetHUDPosition()
check(hud.x==144 and hud.y==0,"reset to requested default")
hud:close()
player.data.WTAGarouHUDLayout={x=160,y=0,pin=false}
hud=WTAGarou.HUD.open()
check(hud.x==144 and hud.y==0 and hud.pin==false,"old default migrates, pin preserved")
hud:close()
check(player.data.WTAGarouHUDLayout.version==3 and player.data.WTAGarouHUDLayout.w==300 and player.data.WTAGarouHUDLayout.h==WTAGarou.HUD.DEFAULT_HEIGHT,"migrated layout version persisted with the size (0.4.79)")
hud=WTAGarou.HUD.open()
check(hud.x==144,"migration does not nudge again")
hud:setX(160); hud:close()
hud=WTAGarou.HUD.open()
check(hud.x==160,"versioned manual placement at old default is preserved")
hud:close()
player.data.WTAGarouHUDLayout={x=250,y=30,pin=false}
hud=WTAGarou.HUD.open()
check(hud.x==250 and hud.y==30 and hud.pin==false,"legacy custom position preserved")
hud:close()
player.data.WTAGarouHUDLayout=nil
screenW=1280; screenH=800
hud=WTAGarou.HUD.open()
check(hud.x==90 and hud.y==0,"Steam Deck-sized default")
hud:close()
player.data.WTAGarouHUDLayout={x=9000,y=9000}
hud=WTAGarou.HUD.open()
check(hud.x==980 and hud.y==800-WTAGarou.HUD.DEFAULT_HEIGHT,"off-screen saved coordinates clamped to the default size (0.4.79: "..WTAGarou.HUD.DEFAULT_HEIGHT.." tall)")
check(WTAGarou.FormData.Glabro.modelScale==1.24,"Glabro 1.24 (0.4.22 +15%)")
check(WTAGarou.FormData.Crinos.modelScale==1.65,"Crinos 1.65 (0.4.69, trimmed from 1.73)")
check(WTAGarou.FormData.Hispo.modelScale==1.55,"Hispo 1.55 (0.4.22 +15%)")
check(WTAGarou.FormData.Lupus.modelScale==1.15,"Lupus 1.15 (0.4.22 +15%)")

-- ---------------------------------------------------------------------------
-- 0.4.10 berserk Crinos: countdown text, Rage-cost tooltips, forced shifts.
-- ---------------------------------------------------------------------------
hud:close()
player.data.WTAGarouHUDLayout=nil
hud=WTAGarou.HUD.open()
check(hud:crinosCountdownText()==nil,"no countdown text by default")
local nowS=1000
WTAGarou.NowSeconds=function() return nowS end
hud:startCrinosCountdown(10)
check(hud:crinosCountdownText()=="Shifting to Berzerker in 10.0","countdown text with one decimal")
nowS=1003.25
check(hud:crinosCountdownText()=="Shifting to Berzerker in 6.8","countdown counts down with the wall clock")
hud.texts={}
hud:prerender()
local drewCountdown=false
for _,t in ipairs(hud.texts) do if t:find("Shifting to Berzerker in 6.8",1,true) then drewCountdown=true end end
check(not drewCountdown,"0.4.79: no status line; the countdown is on the Resist button and in the log")
check(hud.resistBtn.title=="RESIST 6.8","Resist button carries the countdown")
nowS=1011
check(hud:crinosCountdownText()=="Shifting to Berzerker...","expired countdown shows the shifting line until the server acts")
hud:clearCrinosCountdown()
check(hud:crinosCountdownText()==nil,"cancel clears the countdown")
local beforeForm=player.data.WTAGarou.form
hud:startCrinosCountdown(0)
player.data.WTAGarou.form="Crinos"
check(hud:crinosCountdownText()==nil and hud.crinosCountdownEnd==nil,"confirmed Crinos clears stale shifting text")
player.data.WTAGarou.form=beforeForm

-- 0.4.13: the panel leaves with the character, like every vanilla panel.
hud.visible=true
function hud:setVisible(v) self.visible=v end
player.dead=true
hud.texts={}
hud:prerender()
check(hud.visible==false and #hud.texts==0,"dead player hides the Garou panel and draws nothing")
player.dead=false
hud:prerender()
check(#hud.texts>0,"alive player draws again (visibility restored by open/toggle, not prerender)")
local deathHandlers=Events.OnPlayerDeath and Events.OnPlayerDeath.handlers or {}
check(#deathHandlers>=1,"HUD registers an OnPlayerDeath handler")
hud.visible=true
for _,h in ipairs(deathHandlers) do h(player) end
check(hud.visible==false,"OnPlayerDeath hides the panel")

local tip=WTAGarou.HUD.formTooltip("Crinos")
check(not tip:find("<SIZE",1,true) and not tip:find("<H1>",1,true) and not tip:find("<H2>",1,true),
    "0.4.15: tooltips never change font size (ISToolTip measures lines with its default font; bigger faces overflow)")
check(tip:find("Rage cost: 10 (requires 55)",1,true),"Crinos tooltip shows cost 10 / requires 55")
check(tip:find("^<RGB:[%d%.,]+> Crinos <SPACE> <RGB:1,1,1> ") ~= nil,"Crinos tooltip opens with the highlighted lore name and a <SPACE> gap (0.4.45)")
check(tip:find("forced back to Human",1,true),"Crinos drain line uses the display name")
check(tip:find("Burns 1 Rage/s",1,true) and tip:find("Cannot shift out above 75 Rage",1,true),"0.4.39: default Crinos tooltip shows 1/s drain and the 75 exit lock")
check(tip:find("Too big for vehicles",1,true) and WTAGarou.HUD.formTooltip("Hispo"):find("Too big for vehicles",1,true)
    and not WTAGarou.HUD.formTooltip("Glabro"):find("Too big for vehicles",1,true),"bulk-form tooltips mention vehicles and windows")
local berserkerTip=WTAGarou.HUD.formTooltip("Crinos",{trueForm="Glabro"})
check(berserkerTip:find("Rage cost: 10",1,true) and not berserkerTip:find("requires",1,true),"Berserker Crinos tooltip has no Rage floor")
check(berserkerTip:find("Burns 0.5 Rage/s",1,true) and berserkerTip:find("forced back to Near-Human at 0",1,true)
    and berserkerTip:find("Cannot shift out above 55 Rage",1,true),"Berserker Crinos tooltip: half drain, Near-Human return, 55 lock (0.4.58)")
check(WTAGarou.HUD.DENIAL_TEXT.crinos_locked and WTAGarou.HUD.DENIAL_TEXT.vehicle_blocked,"0.4.39 denial texts present")
hud:clearLog()
hud:flashDenial("crinos_locked")
check(hud.denialMsg=="The Rage will not let you go yet.","crinos_locked denial text")
check(hud.notices[#hud.notices].text=="The Rage will not let you go yet.","0.4.79: a denial is a log entry")
hud:flashDenial("crinos_locked")
check(#hud.notices==1,"the same denial again at once is not logged twice")
hud.texts={}
hud:prerender()
local drewStatus=false
for _,t in ipairs(hud.texts) do if t=="The Rage will not let you go yet." then drewStatus=true end end
check(drewStatus,"the denial shows in the log, not on a status line (drawn once)")
-- 0.4.41 put the silver warning on the status line; 0.4.79: the log carries it.
hud:flashSilverBurn("Left Hand")
check(hud.lastSilverBurnPart=="Left Hand" and hud.denialMsg=="The Rage will not let you go yet.","silver warning no longer takes the (removed) red line")
-- 0.4.79: channelling is a log line with the Esc hint
hud:setChannelling("Homid", 60)
check(hud.notices[#hud.notices].text=="Changing to Human... press Esc to stop.","channelling logs the Changing line")
hud:setChannelling("Howl", 0)
check(hud.notices[#hud.notices].text=="Howling... run or press Esc to stop.","howl channelling logs its line")
hud:clearChannelling()
hud:clearLog()
for _,f in ipairs(WTAGarou.FormOrder) do
    local t=WTAGarou.HUD.formTooltip(f)
    check(t:find(" "..f.." ",1,true)==t:find(" ",1,true) and t:sub(1,5)=="<RGB:", f.." tooltip leads with its lore name")
    check(not t:find("[^%s>]<") and not t:find(">[^%s<]"), f.." tooltip: every tag separated from text by spaces")
end
check(WTAGarou.DisplayName("Homid")=="Human" and WTAGarou.DisplayName("Glabro")=="Near-Human"
    and WTAGarou.DisplayName("Crinos")=="Berzerker" and WTAGarou.DisplayName("Hispo")=="Near-Wolf"
    and WTAGarou.DisplayName("Lupus")=="Wolf","display names: Human / Near-Human / Berzerker / Near-Wolf / Wolf")
check(WTAGarou.DisplayName("Nope")=="Nope","unknown form falls back to its key")
check(hud.transformButtons["Crinos"].title=="Berzerker" and hud.transformButtons["Homid"].title=="Human","panel buttons use display names")
check(hud:crinosCountdownText()==nil,"no countdown text without a countdown")
hud:startCrinosCountdown(10)
check(hud:crinosCountdownText():find("Shifting to Berzerker in",1,true),"countdown text uses Berzerker")
hud:clearCrinosCountdown()
-- 0.4.16: Dress button, red Berzerker border, notice lines, dynamic tooltip
check(hud.dressBtn~=nil and hud.dressBtn.title=="Dress","Dress button exists")
check(hud.transformButtons["Crinos"].borderColor and hud.transformButtons["Crinos"].borderColor.r>0.8
    and hud.transformButtons["Crinos"].borderColor.g<0.2,"Berzerker button has a red border")
check(hud.transformButtons["Homid"].borderColor==nil,"other buttons keep the default border")
-- 0.4.78 (user request October 19): the notices are a scrollable LOG. Nothing
-- expires; fresh entries are highlighted for 6 s; newest at the bottom; the
-- wheel scrolls back; a new entry while scrolled up holds the view.
-- 0.4.79 (October 21): four lines by default, the panel is resizable in
-- both axes (buttons share the width, the log takes the height), a
-- scroll-to-bottom icon replaces the "new below" text.
do
    local H=WTAGarou.HUD
    check(H.NOTICE_MIN_SECONDS>=4 and H.NOTICE_SECONDS>=H.NOTICE_MIN_SECONDS,"fresh entries highlighted at least 4 s (6 s configured)")
    check(H.NOTICE_LINES==4 and H.LOG_MAX>=100,"four lines in view by default, at least 100 entries kept")
    check(H.LAYOUT.ROW_Y_OFFSET==42,"buttons start straight under the meter (status line removed)")
    check(H.heightFor(4)==16+42+H.buttonsHeight()+4+4*14+18 and H.DEFAULT_HEIGHT==H.heightFor(4),"default height = title + meter + 6 button rows + 4 log lines + bottom strip ("..H.DEFAULT_HEIGHT..")")
    check(H.linesFor(H.DEFAULT_HEIGHT)==4 and H.linesFor(H.DEFAULT_HEIGHT+27)==5 and H.linesFor(H.heightFor(0))==0,"lines in view follow the height")
    check(H.minHeight()==H.heightFor(H.MIN_LOG_LINES) and H.MIN_WIDTH==300,"minimum size: two log lines, 300 wide")
    local lx,cw,rx=H.columns(300); check(lx==8 and cw==138 and rx==154 and rx+cw==292,"columns at 300: 8..146 and 154..292")
    lx,cw,rx=H.columns(400); check(cw==188 and rx+cw==392,"columns at 400 share the width")
    local measure=function(str) return #str*10 end
    local w=H.wrapText("one two three four five",100,measure)
    check(#w==3 and w[1]=="one two" and w[2]=="three four" and w[3]=="five","word wrap at the pixel width")
    check(#H.wrapText("supercalifragilistic",50,measure)==1,"an over-long word gets its own line, not cut")
    check(H.wrapText("",100,measure)[1]=="","empty text wraps to one empty line")
    local f,l=H.logWindow(4,10,0); check(f==1 and l==4,"window: fewer lines than the view shows all")
    f,l=H.logWindow(25,10,0); check(f==16 and l==25,"window: pinned to the newest ten")
    f,l=H.logWindow(25,10,5); check(f==11 and l==20,"window: scrolled back five")
    f,l=H.logWindow(25,10,99); check(f==1 and l==10,"window: cannot scroll past the oldest")
    check(hud.width==300 and hud.height==H.DEFAULT_HEIGHT and hud.resizable==true and hud.minimumWidth==300 and hud.minimumHeight==H.minHeight(),"panel opens at the default size, resizable, with the minimums set")
    check(hud:viewLines()==4,"four lines in view at the default height")
    hud:clearLog()
    local now=100
    getTimestamp=function() return now end
    hud:pushNotice("a"); hud:pushNotice("b"); hud:pushNotice("c"); hud:pushNotice("d")
    local live=hud:liveNotices()
    check(#live==4 and live[1]=="a" and live[4]=="d","four short notices all show at once")
    now=200
    live=hud:liveNotices()
    check(#live==4 and live[4]=="d","nothing expires: it is a log")
    local lines=hud:logLines()
    check(lines[1].fresh==false,"old entries are no longer highlighted")
    hud:pushNotice("e")
    lines=hud:logLines()
    check(lines[#lines].fresh==true and lines[#lines].text=="e","a fresh entry is highlighted")
    live=hud:liveNotices()
    check(#live==4 and live[1]=="b" and live[4]=="e","a fifth entry scrolls the oldest out of the four-line view")
    for i=1,20 do hud:pushNotice("n"..i) end
    live=hud:liveNotices()
    check(#live==4 and live[#live]=="n20" and live[1]=="n17","pinned to the newest four of twenty-five")
    -- wheel: up = older
    hud.getMouseY=function() return hud.noticeY+5 end
    check(hud:onMouseWheel(-1)==true and hud.logScroll==H.LOG_WHEEL_LINES,"wheel up over the log scrolls back three lines")
    live=hud:liveNotices()
    check(live[#live]=="n17" and live[1]=="n14","the view moved back three")
    hud.rects={}
    hud:drawLog()
    local icon=0
    for _,r in ipairs(hud.rects) do if r[3]==H.JUMP_ICON.w and r[4]==H.JUMP_ICON.h then icon=icon+1 end end
    check(icon==1,"scrolled back: the scroll-to-bottom icon is drawn (backing rect)")
    hud:pushNotice("new1")
    live=hud:liveNotices()
    check(live[#live]=="n17" and hud.logUnread==1,"a new entry while scrolled up holds the view and counts as unread")
    local ix,iy,iw,ih=hud:jumpIconRect()
    check(ix+iw<=300-10 and iy+ih<=select(2,hud:logArea()),"icon sits inside the log area, left of the scroll bar")
    check(hud:jumpIconHit(ix+2,iy+2)==true and hud:jumpIconHit(ix-1,iy)==false,"icon hit test")
    check(hud:onMouseDown(ix+2,iy+2)==true and hud.logScroll==0 and hud.logUnread==nil,"clicking the icon jumps to the newest line and clears unread")
    live=hud:liveNotices()
    check(live[#live]=="new1","the view is at the bottom again")
    hud.rects={}; hud:drawLog()
    icon=0
    for _,r in ipairs(hud.rects) do if r[3]==H.JUMP_ICON.w and r[4]==H.JUMP_ICON.h then icon=icon+1 end end
    check(icon==0,"at the bottom no icon is drawn")
    hud.texts={}; hud:drawLog()
    for _,t in ipairs(hud.texts) do check(t~="new below","no 'new below' text any more") end
    hud.getMouseY=function() return 5 end
    check(hud:onMouseWheel(-1)==false and hud.logScroll==0,"the wheel over the buttons is not the log's")
    hud.getMouseY=nil
    -- resize: taller shows more lines, wider re-wraps and widens the buttons
    hud.height=H.heightFor(8); hud:onResize()
    check(hud:viewLines()==8 and #hud:liveNotices()==8,"taller panel: eight lines in view")
    check(hud.startupBtn.y+H.LAYOUT.BTN_H+H.LAYOUT.LOG_PAD==hud.noticeY,"log still starts right under the buttons")
    hud:clearLog()
    local long=string.rep("word ",30)
    hud:pushNotice(long)
    local narrowLines=#hud.notices[1].lines
    hud.width=600; hud:onResize()
    check(#hud.notices[1].lines<narrowLines,"wider panel re-wraps the log onto fewer lines")
    check(hud.transformButtons.Homid.width==288 and hud.stripBtn.x==8+288+8 and hud.stripBtn.width==288,"buttons share the new width")
    check(player.data.WTAGarouHUDLayout.w==600 and player.data.WTAGarouHUDLayout.h==H.heightFor(8),"the size is saved with the layout")
    hud.width=300; hud.height=H.DEFAULT_HEIGHT; hud:onResize()
    check(hud.transformButtons.Homid.width==138 and hud:viewLines()==4,"back to the default size")
    -- wrapping and the cap
    hud:clearLog()
    hud:pushNotice("word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word")
    lines=hud:logLines()
    check(#lines>=2 and lines[#lines].text~="","a long notice is wrapped onto several lines")
    for _,line in ipairs(lines) do
        check(#line.text*6<=H.NOTICE_WIDTH,"wrapped line fits the panel width (fallback measure)")
    end
    for i=1,H.LOG_MAX+10 do hud:pushNotice("x"..i) end
    check(#hud.notices==H.LOG_MAX and hud.notices[#hud.notices].text=="x"..(H.LOG_MAX+10),"the log keeps the newest LOG_MAX entries")
    hud:clearLog()
    hud.texts={}; hud.rects={}
    for i=1,12 do hud:pushNotice("l"..i) end
    hud:drawLog()
    check(#hud.rects==2,"an overflowing log draws a scroll bar (track + thumb)")
    hud:clearLog()
    getTimestamp=function() return 100 end
    check(hud.noticeY~=nil and hud.noticeY+4*H.LINE_H<=hud.height-18,"four log lines fit above the bottom strip")
    -- the saved size comes back, clamped to the minimums
    hud:close()
    player.data.WTAGarouHUDLayout={x=10,y=10,w=500,h=H.heightFor(6),pin=true,version=3}
    hud=WTAGarou.HUD.open()
    check(hud.width==500 and hud.height==H.heightFor(6) and hud:viewLines()==6,"a saved size is restored")
    hud:close()
    player.data.WTAGarouHUDLayout={x=10,y=10,w=100,h=10,pin=true,version=3}
    hud=WTAGarou.HUD.open()
    check(hud.width==300 and hud.height==H.minHeight(),"a too-small saved size is clamped to the minimums")
    hud:close()
    player.data.WTAGarouHUDLayout=nil
    hud=WTAGarou.HUD.open()
end
-- 0.4.17: two columns. Forms stack on the left, Strip/Dress/Howl on the right,
-- no button overlaps another and every button sits above the notice lines.
do
    local L=WTAGarou.HUD.LAYOUT
    local prevY=nil
    for _,f in ipairs(WTAGarou.FormOrder) do
        local b=hud.transformButtons[f]
        check(b.x==L.PAD and b.width==138,"form button "..f.." in the left column (half the width at 300: 138)")
        check(prevY==nil or b.y>=prevY+L.BTN_H+L.GAP,"form button "..f.." below the previous one")
        prevY=b.y
    end
    for _,b in ipairs({hud.stripBtn,hud.dressBtn,hud.howlBtn}) do
        check(b.x==L.PAD+138+L.COL_GAP and b.width==138,"utility button in the right column, clear of the forms")
        check(b.x+b.width<=300-8,"utility button inside the panel")
    end
    check(hud.stripBtn.y==hud.transformButtons.Homid.y and hud.dressBtn.y==hud.transformButtons.Glabro.y
        and hud.howlBtn.y==hud.transformButtons.Crinos.y,"right column rows line up with the left")
    check(hud.noticeY>=hud.transformButtons.Lupus.y+L.BTN_H,"notices start below the last form button")
    -- 0.4.21: Resist under Howl, Guide under Resist, both still in the right column.
    check(hud.resistBtn and hud.resistBtn.y==hud.transformButtons.Hispo.y and hud.resistBtn.x==hud.stripBtn.x,"Resist sits under Howl (Hispo row)")
    check(hud.guideBtn.y==hud.transformButtons.Lupus.y,"Guide moved down to the Lupus row")
    -- 0.4.45: Startup under Guide (sixth right-column row), notices below it.
    check(hud.startupBtn and hud.startupBtn.x==hud.stripBtn.x and hud.startupBtn.title=="Startup"
        and hud.startupBtn.y==hud.guideBtn.y+L.BTN_H+L.GAP,"Startup sits under Guide")
    check(hud.noticeY>=hud.startupBtn.y+L.BTN_H,"notices start below the Startup button")
    check(hud.title=="Rage","0.4.45: the panel is titled Rage")
    check(hud.resistBtn.title=="Resist","Resist idle label")
    hud:startCrinosCountdown(1.4)
    check(hud.resistBtn.title:find("RESIST 1.",1,true)~=nil and hud.resistBtn.bg and hud.resistBtn.bg[1]>0.5,"countdown: RESIST + seconds, red background")
    hud:clearCrinosCountdown()
    check(hud.resistBtn.title=="Resist","cancelled: idle label back")
end
-- 0.4.21 keybinds: Resist / Strip / Dress registered unbound; dispatch is pure.
for _,fn in ipairs(bootHandlers) do fn() end
local names={}
for _,entry in ipairs(keyBinding) do names[entry.value]=entry end
check(names.WTAGarou_Resist and names.WTAGarou_Resist.key==0,"Resist keybind registered, unbound")
check(names.WTAGarou_Strip and names.WTAGarou_Strip.key==0 and names.WTAGarou_Dress and names.WTAGarou_Dress.key==0,"Strip and Dress keybinds registered, unbound")
check(names.WTAGarou_ToggleRagePanel.key==0,"Rage toggle starts unbound")
check(names.WTAGarou_ToggleHUD==nil,"old saved HUD binding not registered")
check(WTAGarou.HUD.keyAction(0)==nil,"KEY_NONE never dispatches")
check(WTAGarou.HUD.keyAction(34)==nil,"old saved G cannot toggle the panel")
boundKeys.WTAGarou_ToggleRagePanel=22
check(WTAGarou.HUD.keyAction(22)=="toggle","new optional binding works when explicitly assigned")
boundKeys.WTAGarou_ToggleRagePanel=nil
boundKeys.WTAGarou_Resist=19
check(WTAGarou.HUD.keyAction(19)=="resist","a bound Resist key dispatches resist")
boundKeys.WTAGarou_Resist=nil
local emptyTip=WTAGarou.HUD.dressTooltip(nil)
check(emptyTip:find("Nothing remembered yet",1,true)~=nil and not emptyTip:find("<SIZE",1,true),"empty wardrobe tooltip")
WTAGarou.Wardrobe={names=function() return {"Cap","Jeans","Blue T-shirt"} end,count=function() return 3 end,prune=function() return 0 end}
local fullTip=WTAGarou.HUD.dressTooltip(player)
check(fullTip:find("Remembered (3):",1,true)~=nil,"tooltip counts the wardrobe")
check(fullTip:find("<LINE> <RGB:1,1,1> - Blue T-shirt <LINE> <RGB:1,1,1> - Jeans <LINE> <RGB:1,1,1> - Cap",1,true)~=nil,
    "one line per item, innermost first")
WTAGarou.Wardrobe=nil
local st=WTAGarou.HUD.stripTooltip()
check(st:find("Near-Human keeps everything on, undamaged",1,true) and st:find("Wolf -1, Near-Wolf -3, Berzerker -4, all dropped",1,true)
    and st:find("Dress puts the same pieces back on",1,true)
    and not st:find("<SIZE",1,true),"strip tooltip lists the per-form damage")
check(tip:find("Burns 1 Rage/s",1,true),"Crinos tooltip explains the drain")
check(WTAGarou.HUD.formTooltip("Hispo"):find("Rage cost: 20",1,true),"Hispo tooltip shows its cost")
check(WTAGarou.HUD.formTooltip("Homid"):find("Rage cost: none",1,true),"Homid tooltip is free")

-- Forced shift: an in-flight channel is dropped WITHOUT a TransformCancel.
player.command=nil
WTAGarou.Channel.startChannel(player,"Hispo",4,"Homid")
check(queued~=nil and queued.Type=="WTAGarouTransformAction","channel queued")
local act=queued
ISTimedActionQueue.getTimedActionQueue=function() return {queue={queued}} end
WTAGarou.Channel.abort(player)
check(queued==nil,"abort clears the queue")
check(player.command~="TransformCancel","abort never tells the server to cancel (server already changed the form)")
check(act.suppressServerCancel==true,"aborted action is flagged so a late stop() stays quiet")
act:stop()
check(player.command~="TransformCancel","late stop() after abort stays quiet")
ISTimedActionQueue.getTimedActionQueue=nil

-- 0.4.46: collapsed title stays live, uses strict thresholds and bold-style
-- dual drawing; no expanded body content leaks into the collapsed frame.
for _,case in ipairs({{24.9,true},{25,false},{50,false},{75,false},{75.1,true},{100,true}}) do
    local text, danger = WTAGarou.HUD.titleState({rage=case[1]})
    check(danger==case[2] and text=="Rage: "..math.floor(case[1]),"title value/threshold "..case[1])
end
hud.isCollapsed=true
player.data.WTAGarou.rage=80
hud.trendRage=nil; hud.trendDir=nil; hud.trendAt=nil   -- 0.4.69: no movement observed yet
hud.texts={}; hud.titleDraws={}
hud:prerender()
check(#hud.texts==0 and #hud.titleDraws==2,"collapsed frame draws only the bold-style title")
check(hud.titleDraws[1].text=="Rage: 80" and hud.titleDraws[1].g==0.2
    and hud.titleDraws[2].x==hud.titleDraws[1].x+1,"danger title red, second draw offset one pixel")
player.data.WTAGarou.rage=50; hud.titleDraws={}; hud.titleRects={}
hud:prerender()
check(hud.titleDraws[1].text=="Rage: 50" and hud.titleDraws[1].g==1,"collapsed title updates without reopening")
-- 0.4.69: 80 -> 50 is a drop: a down-triangle (wide row on top) in the title colour
check(#hud.titleRects==4 and hud.titleRects[1].w==7 and hud.titleRects[4].w==1
    and hud.titleRects[1].y<hud.titleRects[4].y,"collapsed title draws a 4-row down marker: "..#hud.titleRects)
check(hud.titleRects[1].r==1 and hud.titleRects[1].g==1 and hud.titleRects[1].b==1 and hud.titleRects[1].a>0.9,
    "marker uses the title colour (white at 50) and starts opaque")
check(hud.titleRects[1].x>hud.titleDraws[1].x+#"Rage: 50"*3,"marker sits to the right of the centred text")
hud.titleRects={}; hud.trendDir=nil; hud.trendAt=nil
hud:prerender()
check(#hud.titleRects==0,"no movement: no marker")

-- 0.4.69 Rage meter markers: baseline bracket line, baseline triangle,
-- fading direction arrows, title triangle rows.
local up,down=WTAGarou.HUD.titleMarkerRows(1),WTAGarou.HUD.titleMarkerRows(-1)
check(up[1].w==7 and up[1].dy==3 and up[4].w==1 and up[4].dy==0,"up marker: wide row at the bottom, apex on top")
check(down[1].w==7 and down[1].dy==0 and down[4].w==1 and down[4].dy==3,"down marker: wide row on top, apex at the bottom")
local st={}
local dir,alpha=WTAGarou.HUD.trackTrend(st,40,1000)
check(dir==0 and alpha==0,"first observation sets no direction")
dir,alpha=WTAGarou.HUD.trackTrend(st,40.02,1200)
check(dir==0 and alpha==0,"a 0.02 wobble (float noise at the baseline) is below the deadband: no direction")
dir,alpha=WTAGarou.HUD.trackTrend(st,39.98,1300)
check(dir==0 and alpha==0,"...and the wobble back is ignored too (no half-second flip)")
dir,alpha=WTAGarou.HUD.trackTrend(st,40.03,1400)
check(dir==0 and alpha==0,"movement is measured from the last counted value (40), not the last sample")
dir,alpha=WTAGarou.HUD.trackTrend(st,40.05,1500)
check(dir==1 and alpha==1,"a rise of TREND_DEADBAND (0.05) from the counted value points right at full alpha")
dir,alpha=WTAGarou.HUD.trendState(st,2000)
check(dir==1 and math.abs(alpha-0.5)<1e-6,"arrow half faded 500 ms later")
dir,alpha=WTAGarou.HUD.trendState(st,2500)
check(dir==0 and alpha==0,"gone after TREND_HOLD_MS (1 s)")
dir,alpha=WTAGarou.HUD.trackTrend(st,39,2600)
check(dir==-1 and alpha==1,"a drop points left")
dir,alpha=WTAGarou.HUD.trackTrend(st,39,2700)
check(dir==-1 and alpha<1 and alpha>0.8,"unchanged value keeps the last direction fading")
-- constant drift (a change every 500 ms sync): pulse full -> clear every second, not solid
st={}
WTAGarou.HUD.trackTrend(st,30,10000)
dir,alpha=WTAGarou.HUD.trackTrend(st,30.1,10000)
check(dir==1 and alpha==1,"drift starts: full pulse")
dir,alpha=WTAGarou.HUD.trackTrend(st,30.2,10500)
check(dir==1 and math.abs(alpha-0.5)<1e-6,"next sync keeps the running pulse (half faded), does not reset it")
dir,alpha=WTAGarou.HUD.trendState(st,10900)
check(math.abs(alpha-0.1)<1e-6,"nearly clear at the end of the period")
dir,alpha=WTAGarou.HUD.trackTrend(st,30.3,11000)
check(dir==1 and alpha==1,"period wraps: full again (the pulse)")
dir,alpha=WTAGarou.HUD.trackTrend(st,30.4,11500)
check(math.abs(alpha-0.5)<1e-6,"second pulse half faded")
dir,alpha=WTAGarou.HUD.trackTrend(st,30.2,11700)
check(dir==-1 and alpha==1,"direction flip restarts the pulse at full")
dir,alpha=WTAGarou.HUD.trendState(st,12500)
check(dir==-1 and math.abs(alpha-0.2)<1e-6,"after the last change the hold fade caps the pulse (ends at zero, no cut-off)")
dir,alpha=WTAGarou.HUD.trendState(st,12700)
check(dir==0 and alpha==0,"gone one second after the last change")
local bar={x=8,w=284,y=40,h=14}
local g=WTAGarou.HUD.bracketGeometry(bar,70,20,100)
check(g.centreX==math.floor(8+284*0.7),"baseline centre column = first whole pixel at/right of the 70% edge ("..g.centreX..")")
check(g.lineW==2*57+1 and g.lineX==g.centreX-57,"bracket +/-20 = 57 px either side of the centre column, symmetric: x="..g.lineX.." w="..g.lineW)
check(g.lineY==52 and g.lineH==2,"0.4.79: 2 px cream line inside the bottom edge (half the old 4)")
check(g.tickW==3 and g.tickH==6 and g.tickY==48,"bracket ends: 3 px wide ticks rising 4 px above the line (rows 48..53)")
check(g.topY==40 and g.apexY==51 and g.stemY==43 and g.stemH==8,"0.4.71 symbol: top triangle rows 40..42, stem 43..50, bottom triangle rows 51..53 (meter 40..53)")
g=WTAGarou.HUD.bracketGeometry(bar,50,5,100)
check(g.centreX==150 and g.lineX==136 and g.lineW==29,"baseline 50 +/-5: centre column 150, line 136..164 inclusive (whole pixels, no half-pixel edge)")
g=WTAGarou.HUD.bracketGeometry(bar,95,20,100)
check(g.lineX+g.lineW==292 and g.lineW<2*57+1,"bracket clipped at the right end of the bar")
g=WTAGarou.HUD.bracketGeometry(bar,70,0,100)
check(g.lineW==0,"no stacks: no cream line, only the centre symbol")
-- the ticks are drawn only when the line is wide enough to hold both
hud.rects={}
hud:drawRageMarkers({rage=50,bracketHalfWidth=20,baselineRage=50},bar,50,100)
local ticks=0
for _,r in ipairs(hud.rects) do if r[3]==3 and r[4]==6 then ticks=ticks+1 end end
check(ticks==2,"down-bracket: two 3x6 ticks drawn at the ends of the line")
g=WTAGarou.HUD.bracketGeometry(bar,100,0,100)
check(g.centreX==291,"baseline 100: centre column is the last pixel of the bar, not one past it")
-- single arrow on the moving side, clipped to the meter
local a=WTAGarou.HUD.arrowPlacement(bar,50,100,1)
check(a and a.x==152 and a.dir==1,"rising at 50: right arrow base 2 px right of the fill edge (150), pointing right")
a=WTAGarou.HUD.arrowPlacement(bar,50,100,-1)
check(a and a.x==147 and a.dir==-1,"falling at 50: left arrow base 2 px left of the fill edge, pointing left")
check(WTAGarou.HUD.arrowPlacement(bar,100,100,1)==nil,"rising at 100: the right arrow lies wholly outside the bar -> not drawn")
check(WTAGarou.HUD.arrowPlacement(bar,0,100,-1)==nil,"falling at 0: the left arrow lies wholly outside the bar -> not drawn")
a=WTAGarou.HUD.arrowPlacement(bar,99,100,1)
check(a and a.x==291,"rising at 99: arrow base is the last bar column; the rest is masked")
check(WTAGarou.HUD.arrowPlacement(bar,50,100,0)==nil,"no direction: no arrow")
-- expanded body draws: cream line, 7-draw baseline symbol, arrows while moving
hud.isCollapsed=false
player.data.WTAGarou.rage=60; player.data.WTAGarou.bracketHalfWidth=10
hud.rects={}; hud.trendDir=nil; hud.trendAt=nil; hud.trendRage=nil
hud:prerender()
local cream,yellow=0,0
for _,r in ipairs(hud.rects) do
    if r[6]==1 and r[7]==0.95 and r[8]==0.75 then cream=cream+1 end
    if r[6]==1 and r[7]==0.85 and r[8]==0.2 then yellow=yellow+1 end
end
check(cream==3,"cream bracket: the line and its two end ticks (0.4.79): "..cream)
check(yellow==7,"baseline symbol = 3+1+3 yellow draws, no arrows on the first frame: "..yellow)
local symCol=math.floor(8+284*WTAGarou.BaselineRage(player.data.WTAGarou)/100)   -- the baseline column, not the fill edge
local meterY
for _,r in ipairs(hud.rects) do if r[1]==8 and r[3]==284 and r[4]==14 then meterY=r[2] end end   -- the meter background
local topRow,stem,bottomRow=0,nil,0
for _,r in ipairs(hud.rects) do
    if r[6]==1 and r[7]==0.85 and r[8]==0.2 then
        if r[2]==meterY and r[3]==5 and r[1]==symCol-2 then topRow=topRow+1 end
        if r[1]==symCol and r[3]==1 and r[4]==8 then stem=r end
        if r[2]==meterY+13 and r[3]==5 and r[1]==symCol-2 then bottomRow=bottomRow+1 end
    end
end
check(meterY and topRow==1 and bottomRow==1 and stem~=nil and stem[2]==meterY+3,"symbol: 5-wide rows on the top and bottom edge of the meter, 1x8 stem between, all centred on the baseline column "..symCol)
player.data.WTAGarou.rage=62; hud.rects={}
hud:prerender()
yellow=0
for _,r in ipairs(hud.rects) do if r[6]==1 and r[7]==0.85 and r[8]==0.2 then yellow=yellow+1 end end
check(yellow==7+5,"rising: baseline symbol + ONE 5-column arrow (right side only): "..yellow)
local rightmost,leftmost=0,1e9
for _,r in ipairs(hud.rects) do if r[6]==1 and r[7]==0.85 and r[8]==0.2 and r[3]==1 and r[4]>1 and r[1]~=symCol then rightmost=math.max(rightmost,r[1]); leftmost=math.min(leftmost,r[1]) end end
check(leftmost>=math.floor(8+284*0.62)+2,"the rising arrow starts right of the fill edge, nothing on the left: "..leftmost)
-- arrow masked at the right end of the meter
hud.trendDir=nil; hud.trendAt=nil; hud.trendRage=nil
player.data.WTAGarou.rage=97; hud:prerender()
player.data.WTAGarou.rage=98.5; hud.rects={}; hud:prerender()
local cols=0
for _,r in ipairs(hud.rects) do if r[6]==1 and r[7]==0.85 and r[8]==0.2 and r[3]==1 and r[4]>1 and r[4]~=8 then cols=cols+1; check(r[1]<8+284,"arrow column inside the bar: "..r[1]) end end
check(cols==3,"98.5 rising: arrow columns 289..293, only the 3 inside the meter are drawn: "..cols)
player.data.WTAGarou.rage=60; hud.trendDir=nil; hud.trendAt=nil; hud.trendRage=nil; hud:prerender()
player.data.WTAGarou.rage=62; hud.rects={}; hud:prerender()
hud.rects={}; hud.titleDraws={}; hud.titleRects={}
hud:prerender()
check(hud.titleDraws[1].text=="Rage: 62" and #hud.titleRects==4 and hud.titleRects[1].y>hud.titleRects[4].y,
    "expanded title shows the up marker while the arrows fade")
hud.isCollapsed=true; player.data.WTAGarou.rage=50; hud.titleDraws={}
hud:prerender()
check(hud.isCollapsed==true,"title never unsets the collapse flag")
hud.scrollX=7; hud.scrollY=3; hud.titleDraws={}
hud:prerender()
check(hud.titleDraws[1].x==143 and hud.titleDraws[1].y==-2,
    "native scroll offsets canceled using verified getXScroll/getYScroll")
hud.scrollX=0; hud.scrollY=0
hud.isCollapsed=false
hud.texts={}; hud.rects={}; hud.titleDraws={}
hud:prerender()
local meter=false
for _,text in ipairs(hud.texts) do if text=="Rage 50 / 100" then meter=true end end
check(meter and #hud.rects>=2 and #hud.titleDraws==2,
    "reopened window draws BOTH title and body meter after title call")

-- Real HUD + timed actions with two local owners; getPlayer is deliberately
-- switched to the OTHER actor to reproduce the October 8 report.
local second={variables={},data={WTAGarou={isGarou=true,form="Hispo",rage=70,infamy=0}},dead=false,sneaking=false}
setmetatable(second,{__index=player})
function second:getModData() return self.data end
function player:getPlayerNum() return 0 end
function second:getPlayerNum() return 1 end
getSpecificPlayer=function(i) if i==0 then return player elseif i==1 then return second end end
getNumActivePlayers=function() return 2 end
getPlayerScreenLeft=function(i) return i*960 end
getPlayerScreenTop=function() return 0 end
getPlayerScreenWidth=function() return 960 end
getPlayerScreenHeight=function() return 720 end
player.dead=false; player.data.WTAGarou.form="Homid"; player.data.WTAGarou.rage=20
getPlayer=function() return second end
local h1=WTAGarou.HUD.open(player)
local h2=WTAGarou.HUD.open(second)
check(h1~=h2 and h1.player==player and h2.player==second,"independent HUD owners")
check(WTAGarou.HUD.instance==h1,"legacy alias always slot zero, not last created")
check(h2.x>=960 and h2.y==0,"second panel starts inside its viewport")
h1:refresh(); h2:refresh()
check(h1.transformButtons.Hispo.enable and not h2.transformButtons.Hispo.enable,
    "nephew's current Hispo does not grey out first player's Hispo")
h1.titleDraws={}; h2.titleDraws={}; h1:prerender(); h2:prerender()
check(h1.titleDraws[1].text=="Rage: 20" and h2.titleDraws[1].text=="Rage: 70","each title reads its owner")
local invoked
WTAGarou.RequestTransform=function(form,p) invoked={form=form,player=p} end
h1.transformButtons.Hispo.callback()
check(invoked.player==player and invoked.form=="Hispo","first panel's shift ignores ambient player two")
h2.transformButtons.Homid.callback()
check(invoked.player==second,"second panel's shift owns second player")
for key,field in pairs({RequestStrip="stripBtn",RequestDress="dressBtn",RequestHowl="howlBtn",RequestResist="resistBtn"}) do
    WTAGarou[key]=function(p) invoked=p end
    h1[field].callback(); check(invoked==player,key.." first owner")
    h2[field].callback(); check(invoked==second,key.." second owner")
end
WTAGarou.WolfCoat={toggle=function(p) invoked=p end}
h2.startupBtn.callback(); check(invoked==second,"startup belongs to second player")
local a2=WTAGarouTransformAction:new(second,"Lupus",3,"Hispo")
a2:start()
check(h2.channelForm=="Lupus" and h1.channelForm==nil,"channel display attached to action's owner")
a2:perform()
check(second.command=="TransformConfirm" and h2.channelForm==nil,"second character confirms its own channel")
WTAGarou.HUD.toggle(second)
check(WTAGarou.HUD.forPlayer(second)==nil and WTAGarou.HUD.forPlayer(player)==h1,"toggle closes only owner's panel")
for _,fn in ipairs(Events.OnPlayerUpdate.handlers) do fn(second) end
check(WTAGarou.HUD.forPlayer(second)==nil,"ordinary updates do not reopen a deliberately hidden HUD")
h2=WTAGarou.HUD.open(second)
h2:setX(1200); h2:setY(50); h2:saveLayout()
check(second.data.WTAGarouHUDLayout.x==1200 and player.data.WTAGarouHUDLayout.x~=1200,
    "layout saved on the correct character")
for _,fn in ipairs(Events.OnPlayerDeath.handlers) do fn(second) end
check(WTAGarou.HUD.forPlayer(second)==nil and WTAGarou.HUD.forPlayer(player)==h1,"death removes only that character's HUD")
local joined=setmetatable({data={WTAGarou={isGarou=true,form="Homid",rage=50}},variables={}}, {__index=second})
function joined:isLocalPlayer() return true end
for _,fn in ipairs(Events.OnPlayerUpdate.handlers) do fn(joined) end
check(WTAGarou.HUD.forPlayer(joined)~=nil,"late join/respawn gets its own HUD without another OnGameStart")
local remote=setmetatable({}, {__index=joined})
function remote:isLocalPlayer() return false end
for _,fn in ipairs(Events.OnPlayerUpdate.handlers) do fn(remote) end
check(WTAGarou.HUD.forPlayer(remote)==nil,"online observer never opens a remote player's HUD")
print("PASS: "..checks.." channel/HUD regression assertions.")
