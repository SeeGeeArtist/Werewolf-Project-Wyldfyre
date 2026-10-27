-- Optional execution against supplied vanilla files; no copyrighted engine
-- source is bundled. Usage: lua5.1 this.lua WTAGarou /path/to/reference-files
local root, vanilla=assert(arg[1]),assert(arg[2])
function require() end
local function derive(self,name)
    local c={Type=name}; c.__index=c; return setmetatable(c,{__index=self})
end
ISBaseObject={derive=derive}
ISPanelJoypad={derive=derive}
local event={Add=function() end}
Events={OnGameStart=event,OnGameBoot=event,OnKeyPressed=event}
getTexture=function(x) return x end
getText=function(x) return x end
UIManager={getSpeedControls=function() return {getCurrentGameSpeed=function() return 1 end} end}
ISWorldMap={IsAllowed=function() return true end,ToggleWorldMap=function() end}
getPlayerMiniMap=function() return nil end
getPlayerScreenLeft=function() return 0 end
getPlayerScreenTop=function() return 0 end
getPlayerScreenWidth=function() return 1280 end
getPlayerScreenHeight=function() return 800 end
Joypad={DPadDown=1,DPadRight=2,BButton=3,XButton=4}
local joy={id=0,player=0}
JoypadState={players={joy}}
local actor={getPlayerNum=function() return 0 end,setJoypadIgnoreAimUntilCentered=function() end}
getPlayer=function() return actor end
getSpecificPlayer=function() return actor end
dofile(vanilla.."/ISRadialMenu.lua")
dofile(vanilla.."/ISEmoteRadialMenu.lua")
dofile(vanilla.."/ISDPadWheels.lua")
local selected=0
local menu=setmetatable({slices={},sounds={},playerNum=0},{
    __index=ISRadialMenu})
menu.javaObject={clear=function() end,addSlice=function() end,
    getSliceIndexFromJoypad=function() return selected end,
    getSliceIndexFromMouse=function() return selected end}
function menu:setX(x) self.x=x end
function menu:setY(y) self.y=y end
function menu:getWidth() return 400 end
function menu:getHeight() return 400 end
function menu:addToUIManager() self.visible=true end
function menu:removeFromUIManager() self.visible=false end
function menu:isVisible() return self.visible end
getPlayerRadialMenu=function() return menu end
setJoypadFocus=function(_,m) joy.focus=m; m.joyfocus=joy end
local calls={}
local function request(name,p) assert(p==actor); calls[#calls+1]=name end
WTAGarou={
    FormOrder={"Homid","Glabro","Crinos","Hispo","Lupus"},
    HasGarouTrait=function() return true end,
    GetData=function() return {form="Homid"} end,
    GetForm=function() return {rageCost=0} end,
    DisplayName=function(n) return n end,
    BaselineRage=function() return 50 end,
    RequestTransform=request,
    RequestHowl=function(p) request("Howl",p) end,
    RequestResist=function(p) request("Resist",p) end,
    RequestStrip=function(p) request("Strip",p) end,
    RequestDress=function(p) request("Dress",p) end,
}
ISEmoteRadialMenu.menu={shout={name="Shout"}}
ISEmoteRadialMenu.icons={}
dofile(root.."/42/media/lua/client/WTAGarouEmote.lua")
dofile(root.."/42/media/lua/client/WTAGarouRadial.lua")
local emote=setmetatable({playerNum=0,character=actor},{__index=ISEmoteRadialMenu})
local checks=0
local function check(x,s) checks=checks+1; assert(x,s) end
local function release(button,index)
    selected=index-1
    if joy.focus==menu and menu:isVisible() then
        menu:onJoypadButtonReleased(button,joy)
    end
end
for _=1,10 do
    emote:fillMenu()
    check(#menu.slices==4 and menu.hideWhenButtonReleased==Joypad.DPadDown,"native social layout and release")
    release(Joypad.DPadDown,2)
    check(calls[#calls]=="Howl" and not menu.visible and joy.focus==nil,"native social closes without reopening")
    ISDPadWheels.onDisplayRight(joy)
    check(#menu.slices==9 and menu.hideWhenButtonReleased==Joypad.DPadRight,"native map preserves 3 slices plus 6")
    local before=#calls
    release(Joypad.DPadDown,8)
    check(#calls==before and menu.visible,"old button cannot release map wheel")
    release(Joypad.DPadRight,4)
    check(calls[#calls]=="Homid" and #calls==before+1,"native form selection executes exactly once")
    check(not menu.visible and joy.focus==nil,"no invisible focus trap")
    ISDPadWheels.onDisplayRight(joy)
    menu:onJoypadDown(Joypad.BButton,joy)
    check(not menu.visible and joy.focus==nil and #calls==before+1,"native B cancels without dispatch")
end
-- Mouse selection also executes through the original ISRadialMenu callback.
emote:fillMenu(); menu.joyfocus=nil; joy.focus=nil; selected=2
menu:onMouseDown(0,0)
check(calls[#calls]=="Strip" and not menu.visible,"mouse social path retained")
print("PASS: "..checks.." supplied-vanilla radial lifecycle assertions.")
