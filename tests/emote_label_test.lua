local root=assert(arg[1])
local checks=0
local function check(b,why) checks=checks+1; assert(b,why) end
function require() end
local player={num=0,garou=true}
local second={num=1,garou=true}
local players={player,second}
getPlayer=function() return player end
getSpecificPlayer=function(n) return players[n+1] end
getTexture=function(p) return p end
local paused=false
UIManager={getSpeedControls=function() return {getCurrentGameSpeed=function() return paused and 0 or 1 end} end}
Joypad={DPadDown=10,DPadRight=11,BButton=1,XButton=2}
local focus, opens, vanillaSocial, vanillaMap = nil,0,0,0
local radial={slices={}}
function radial:clear() self.slices={} end
function radial:addSlice(text,icon,callback,...)
    self.slices[#self.slices+1]={text=text,icon=icon,callback=callback,args={...}}
end
function radial:isVisible() return self.visible end
function radial:undisplay() self.visible=false; focus=nil end
function radial:display(button)
    opens=opens+1; self.visible=true; self.release=button; focus=self
end
-- Native ISRadialMenu lifecycle: close before command; commands must not
-- reopen a shared wheel that the SAME D-pad release can immediately select.
function radial:releaseSlice(button,index)
    if button~=self.release or focus~=self or not self.visible then return end
    self:undisplay()
    local s=self.slices[index]
    if s and s.callback then s.callback(unpack(s.args)) end
end
function radial:cancel() self:undisplay() end
getPlayerRadialMenu=function() return radial end
ISEmoteRadialMenu={}
function ISEmoteRadialMenu:fillMenu(submenu)
    vanillaSocial=vanillaSocial+1
    radial:clear()
    radial:addSlice(submenu and "Vanilla emote" or "Vanilla social",nil,function() end)
    self:display()
end
function ISEmoteRadialMenu:display() radial:display(Joypad.DPadDown) end
ISDPadWheels={onDisplayRight=function()
    vanillaMap=vanillaMap+1
    if paused then return end
    radial:clear()
    for _,name in ipairs({"Map","Minimap","Animal zones","Survival guide"}) do
        radial:addSlice(name,nil,function() end)
    end
    radial:display(Joypad.DPadRight)
end}
local requests={}
local function request(action,p)
    requests[#requests+1]={action=action,player=p}
end
WTAGarou={
    HasGarouTrait=function(p) return p.garou end,
    NowSeconds=function() return 100 end,
    GetData=function() return {form="Homid",rage=50} end,
    BaselineRage=function() return 40 end,
    FormOrder={"Homid","Glabro","Crinos","Hispo","Lupus"},
    GetForm=function(name) return {rageCost=name=="Homid" and 0 or 10} end,
    RageRequired=function(name) return name=="Crinos" and 55 or 10 end,
    DisplayName=function(name) return name end,
    RequestTransform=function(form,p) request(form,p) end,
    RequestResist=function(p) request("Resist",p) end,
    RequestHowl=function(p) request("Howl",p) end,
    RequestStrip=function(p) request("Strip",p) end,
    RequestDress=function(p) request("Dress",p) end,
    Clothing={stripCandidates=function() return {} end},
    Wardrobe={count=function() return 0 end},
    HUD={instance={},toggle=function(p) request("Toggle Rage",p) end},
}
WTAGarou.HUDFor=function(p) return p==player and WTAGarou.HUD.instance or nil end
local handlers=0
Events={OnGameBoot={Add=function() handlers=handlers+1 end},
    OnKeyPressed={Add=function() handlers=handlers+1 end}}
keyBinding={}
dofile(root.."/42/media/lua/client/WTAGarouEmote.lua")
dofile(root.."/42/media/lua/client/WTAGarouRadial.lua")
check(handlers==0 and #keyBinding==0 and WTAGarou.Radial.open==nil,
    "no standalone forms keybind, listener or opener")
local social=setmetatable({playerNum=0,character=player},{__index=ISEmoteRadialMenu})
social:fillMenu()
check(vanillaSocial==1 and opens==1,"native social display called exactly once")
check(#radial.slices==5 and radial.slices[1].text=="Vanilla social","vanilla retained plus four Garou social actions")
check(radial.slices[2].text=="Howl\nRage 40","Howl retains auspice baseline")
check(radial.slices[3].text=="Toggle\nRage panel" and radial.slices[3].icon=="media/ui/WTAGarou/wta_shift.png",
    "Rage toggle immediately next to Howl uses supplied glyph")
check(radial.slices[4].text=="Strip\n0 item(s)" and radial.slices[5].text=="Dress\n0 item(s)","stable wardrobe positions when empty")
for i,action in ipairs({"Howl","Toggle Rage","Strip","Dress"}) do
    social:fillMenu()
    local before=#requests
    radial:releaseSlice(Joypad.DPadDown,i+1)
    check(#requests==before+1 and requests[#requests].action==action and requests[#requests].player==player,
        action.." dispatched once to correct actor")
    check(not radial.visible and focus==nil,"social selection closes and releases focus")
    radial:releaseSlice(Joypad.DPadDown,i+1)
    check(#requests==before+1,"same release cannot select another action")
end
local secondSocial=setmetatable({playerNum=1,character=second},{__index=ISEmoteRadialMenu})
secondSocial:fillMenu()
radial:releaseSlice(Joypad.DPadDown,3)
check(requests[#requests].action=="Toggle Rage" and requests[#requests].player==second,
    "second controller toggles its own HUD after native radial closes")
social:fillMenu("shouts")
check(#radial.slices==1,"vanilla emote submenus untouched")
for i,form in ipairs(WTAGarou.FormOrder) do
    ISDPadWheels.onDisplayRight({player=0})
    check(#radial.slices==10 and radial.slices[1].text=="Map","all native slices plus five forms and Resist")
    check(radial.release==Joypad.DPadRight,"native right release binding retained")
    local before=#requests
    radial:releaseSlice(Joypad.DPadDown,4+i)
    check(#requests==before and radial.visible,"stale down release cannot select a form")
    radial:releaseSlice(Joypad.DPadRight,4+i)
    check(#requests==before+1 and requests[#requests].action==form,"chosen form only, not accidental Lupus")
    check(not radial.visible and focus==nil,"form selection closes without nested reopen")
end
ISDPadWheels.onDisplayRight({player=0})
check(radial.slices[7].text=="Crinos\nRage 10 (need 55)","entry requirement label preserved")
check(radial.slices[10].text=="Resist\nThe Change","idle Resist capitalization preserved")
WTAGarou.HUD.instance.crinosCountdownEnd=105
ISDPadWheels.onDisplayRight({player=0})
check(radial.slices[10].text=="RESIST\n5.0s","active countdown preserved")
radial:releaseSlice(Joypad.DPadRight,10)
check(requests[#requests].action=="Resist","same Resist action now on map")
ISDPadWheels.onDisplayRight({player=1})
check(radial.slices[10].text=="Resist\nThe Change","first player's countdown not shown on second wheel")
radial:releaseSlice(Joypad.DPadRight,9)
check(requests[#requests].player==second,"controller actor forwarded, not global first player")
local before=#requests
for _=1,20 do
    social:fillMenu(); radial:cancel()
    ISDPadWheels.onDisplayRight({player=0}); radial:cancel()
end
check(#requests==before and focus==nil,"repeated open/cancel never dispatches or traps focus")
player.garou=false
social:fillMenu(); check(#radial.slices==1,"non-Garou social unchanged")
ISDPadWheels.onDisplayRight({player=0}); check(#radial.slices==4,"non-Garou map unchanged")
player.garou=true; radial:cancel(); paused=true
ISDPadWheels.onDisplayRight({player=0})
check(not radial.visible and #radial.slices==4,"paused right-wheel gate preserved")
print("PASS: "..checks.." direct controller radial assertions.")
