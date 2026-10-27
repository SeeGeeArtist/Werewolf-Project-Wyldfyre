local root = assert(arg[1])
package.path = root .. "/42/media/lua/shared/?.lua;" ..
    root .. "/42/media/lua/client/?.lua;" .. package.path
require "WTAGarouDefinitions"
require "WTAGarouState"
require "WTAGarouAccess"   -- 0.4.83: Panel.allowed routes through the shared privilege rule
local n = 0
local function check(ok, why) n=n+1; assert(ok, why) end
local function derive(self, name)
    local cls={Type=name}; cls.__index=cls
    return setmetatable(cls, {__index=self})
end
ISCollapsableWindow={derive=derive}
function ISCollapsableWindow:new(x,y,w,h)
    return setmetatable({x=x,y=y,width=w,height=h,pin=true,children={},texts={}},self)
end
function ISCollapsableWindow:setTitle(t) self.title=t end
function ISCollapsableWindow:titleBarHeight() return 16 end
function ISCollapsableWindow:createChildren() end
function ISCollapsableWindow:initialise() self:createChildren() end
function ISCollapsableWindow:addChild(c) self.children[#self.children+1]=c end
function ISCollapsableWindow:addToUIManager() self.added=true end
function ISCollapsableWindow:removeFromUIManager() self.added=false end
function ISCollapsableWindow:close() end
function ISCollapsableWindow:prerender() end
function ISCollapsableWindow:setHeight(v) self.height=v end
function ISCollapsableWindow:getX() return self.x end
function ISCollapsableWindow:getY() return self.y end
function ISCollapsableWindow:setX(v) self.x=v end
function ISCollapsableWindow:setY(v) self.y=v end
function ISCollapsableWindow:drawText(text) self.texts[#self.texts+1]=text end
function ISCollapsableWindow:drawRect() end
ISButton={}
function ISButton:new(x,y,w,h,title,target,callback)
    return {x=x,y=y,width=w,height=h,title=title,target=target,callback=callback,
        initialise=function() end,setTooltip=function(self,t) self.tooltip=t end}
end
for _,key in ipairs({"ISUI/ISCollapsableWindow","ISUI/ISButton","WTAGarouPanicTrace"}) do
    package.loaded[key]=true
end
Events={}
for _,key in ipairs({"OnAddMessage","OnFillWorldObjectContextMenu","OnPlayerDeath","OnServerCommand","OnGameStart"}) do
    Events[key]={callbacks={}}
    Events[key].Add=function(fn) table.insert(Events[key].callbacks,fn) end
end
local player={data={WTAGarou={isGarou=true,form="Homid",rage=50,infamy=0}},dead=false,level=""}
function player:getModData() return self.data end
function player:isDead() return self.dead end
function player:getAccessLevel() return self.level end
function player:getMaxWeight() return 12 end
local current=player
getPlayer=function() return current end
getSpecificPlayer=function(num) if num==0 then return current end end
local multiplayer=false
isClient=function() return multiplayer end
isServer=function() return false end
UIFont={Small=1}
local sw,sh=1280,720
getCore=function() return {getScreenWidth=function() return sw end,getScreenHeight=function() return sh end} end
getTextManager=function() return {
    MeasureStringX=function(_,font,text) return #text*7 end,
    getFontHeight=function() return 16 end,
} end
local commands={}
require "WTAGarouNet"
WTAGarou.Net.RegisterServerHandler(function(module,command,p,args)
    commands[#commands+1]={command=command,args=args}
end)
sendClientCommand=function(p,module,command,args) commands[#commands+1]={command=command,args=args} end
local busy=false
WTAGarou.IsChannelling=function() return busy end
WTAGarou.RequestTransform=function(form) commands[#commands+1]={command="normal",args={form=form}} end
WTAGarou.PanicTrace={start=function(seconds) return true,"trace "..tostring(seconds) end}
local wolf,reset=false,false
WTAGarouDirectWolf=function(value) wolf=value; WTAGarou.EnableDirectWolf=value end
WTAGarouResetHUDPosition=function() reset=true end
require "WTAGarouTestPanel"
local panel=WTAGarou.TestPanel
local menu={options={}}
function menu:addOption(name,target,fn) self.options[#self.options+1]={name=name,fn=fn} end
local context=Events.OnFillWorldObjectContextMenu.callbacks[1]
context(0,menu,{},true)
check(#menu.options==0,"context test pass does not create UI")
context(1,menu,{},false)
check(#menu.options==0,"split-screen other player cannot control primary")
context(0,menu,{},false)
-- 0.4.45: the context entry is admin-only (multiplayer role); single player
-- and ordinary players open the panel with "/garou cheats".
check(#menu.options==0,"single player: no Werewolf Cheats entry in the world menu")
multiplayer=true; player.level="admin"
isAdmin=function() return false end
context(0,menu,{},false)
check(#menu.options==0,"multiplayer without the admin role: still hidden")
isAdmin=function() return true end
context(0,menu,{},false)
check(#menu.options==1 and menu.options[1].name=="Werewolf Cheats","multiplayer admin sees the Werewolf Cheats entry")
-- 0.4.83: the default B42 role "user" is not privileged even if isAdmin() lied.
menu.options={}; player.level="user"
context(0,menu,{},false)
check(#menu.options==0,"multiplayer 'user' role: no entry (Access.privileged refuses)")
player.level="admin"; menu.options={}
context(0,menu,{},false)
check(#menu.options==1,"admin again")
multiplayer=false; player.level=""
menu.options[1].fn()
local ui=panel.instance
check(ui and ui.added,"context opens UI")
check(panel.open()==ui,"singleton")
check(ui.x>=0 and ui.x+ui.width<=sw and ui.y+ui.height<=sh,"fits 1280x720")
check(ui.x>300,"initial placement separate from left-side HUD")
check(#ui.buttons==30,"all test controls created including Firearm kit, Reset identity and Swap sex")
for _,button in ipairs(ui.buttons) do
    check(button.x>=0 and button.x+button.width<=ui.width,"button inside window")
    check(button.y>ui:titleBarHeight() and button.y+button.height<ui.outputLabelY,"button above diagnostics")
end
local function click(command)
    for _,b in ipairs(ui.buttons) do
        if b.testCommand==command then b.callback(b.target,b); return end
    end
    error("missing "..command)
end
local granted={}
function player:getInventory() return {AddItem=function(_,name) granted[#granted+1]=name; return {} end} end
click("gearkit")
check(#granted==5 and granted[1]=="Base.SleepingBag_Green_Packed" and granted[5]=="Base.MeatCleaver",
    "gear kit bypasses vanilla list and adds bags/tools only to inventory")
granted={}
function player:getInventory()
    return {AddItem=function(_,name) granted[#granted+1]=name; return {} end}
end
-- 0.4.66: the kit reads ammo/magazine types from a loose instanceItem probe
-- (the granted gun is server-made in MP and not in hand yet).
instanceItem=function(name)
    return {getAmmoType=function() return setmetatable(
            {getItemKey=function() return name.."_Ammo" end},
            {__tostring=function() return "base:bullets_test" end}) end,
        getMagazineType=function() return name=="Base.Shotgun" and "" or name.."_Mag" end}
end
click("firearmkit")
local counts={}
for _,name in ipairs(granted) do counts[name]=(counts[name] or 0)+1 end
check(counts["Base.HuntingRifle"]==1 and counts["Base.Shotgun"]==1
    and counts["Base.Pistol"]==1 and counts["Base.Revolver_Short"]==1,"four testing firearms")
check(counts["Base.Pistol_Ammo"]==60 and counts["Base.Pistol_Mag"]==2
    and not counts["Base.Shotgun_Mag"],"ammo and magazines resolved from actual weapons")
check(counts["Base.HolsterAnkle"] and counts["Base.HolsterSimple"] and counts["Base.HolsterDouble"] and counts["Base.HolsterShoulder"]
    and counts["Base.FlashLight_AngleHead"] and counts["Base.Bag_ALICE_BeltSus"],"holsters and webbing accessories")
check(not counts["base:bullets_test"],"registry id never passed to AddItem")
check(WTAGarou.Debug.ammoItemKey("Base.Bullets308")=="Base.Bullets308","legacy item keys retained")
check(WTAGarou.Debug.ammoItemKey("base:bullets_308")==nil,"unresolved resource location rejected")
check(WTAGarou.Debug.ammoItemKey({})==nil,"unknown ammo object rejected without guessing")
function player:getInventory() return {AddItem=function() return nil end} end
check(WTAGarou.Debug.grantFirearmKit(player):find("Missing:",1,true),"missing item IDs reported")
for _,form in ipairs(WTAGarou.FormOrder) do
    click("shift "..form)
    check(commands[#commands].command=="normal" and commands[#commands].args.form==form,"normal channel "..form)
    click("form "..form)
    check(commands[#commands].command=="DebugSetForm" and commands[#commands].args.form==form,"instant "..form)
end
click("rage 100")
check(commands[#commands].args.value==100 and not commands[#commands].args.relative,"absolute Rage")
click("rage -25")
check(commands[#commands].args.value==-25 and commands[#commands].args.relative,"relative Rage")
click("rage +25")
check(commands[#commands].args.value==25 and commands[#commands].args.relative,"add Rage")
busy=true
local count=#commands
click("form Hispo"); click("shift Lupus")
check(#commands==count,"cannot force form or re-enter channel during active channel")
click("wolf off"); check(not wolf,"emergency visual off works during channel")
busy=false
click("wolf on"); check(wolf,"visual on")
click("hudreset"); check(reset,"reset uses existing HUD function")
do
    local count=#commands
    click("identity reset")
    check(#commands==count+1 and commands[#commands].command=="DebugResetIdentity","Reset identity button sends DebugResetIdentity")
    check(type(WTAGarouResetIdentity)=="function" and type(garou)=="function" and type(WTAGarou.cmd)=="function",
        "Lua-console globals exist for identity reset and generic commands")
    garou("identity reset")
    check(#commands==count+2 and commands[#commands].command=="DebugResetIdentity","garou(\"identity reset\") works from the Lua console")
end
-- 0.4.94: Swap sex flips the descriptor and rebuilds the model, single player only
do
    local desc={female=false}
    function desc:isFemale() return self.female end
    function desc:setFemale(v) self.female=v end
    player.getDescriptor=function() return desc end
    player.resets=0
    player.setFemale=function(self,v) self.sex=v end
    player.resetModelNextFrame=function(self) self.resets=self.resets+1 end
    local refreshed=0
    local hadVisual=WTAGarou.Visual~=nil
    WTAGarou.Visual=WTAGarou.Visual or {}
    local oldRefresh=WTAGarou.Visual.refresh
    WTAGarou.Visual.refresh=function(p,force) refreshed=refreshed+1 end
    click("sex")
    check(desc.female==true and player.sex==true and player.resets==1 and refreshed==1,"Swap sex: descriptor flipped, model reset, visuals refreshed")
    click("sex")
    check(desc.female==false and player.resets==2,"second click flips back")
    multiplayer=true
    local f,why=WTAGarou.Debug.swapSex(player)
    check(f==nil and type(why)=="string" and desc.female==false and player.resets==2,"multiplayer: refused, nothing touched")
    multiplayer=false
    WTAGarou.Visual.refresh=oldRefresh
    if not hadVisual then WTAGarou.Visual=nil end
end
-- 0.4.24: Reload defs uses the engine's reloadLuaFile with the path the game
-- loaded Definitions under (Kahlua has no loadstring; the September 27
-- console showed "Object tried to call nil in pcall").
do
    local realReload = WTAGarou.Debug.reloadDefinitions
    local reloadedPath,coatReloaded
    local savedLS, savedReader = loadstring, getModFileReader
    loadstring, getModFileReader = nil, nil
    getLoadedLuaCount = function() return 3 end
    getLoadedLua = function(i) return ({ [0] = "media/lua/shared/Other.lua", [1] = "C:/mods/WTAGarou/42/media/lua/shared/WTAGarouDefinitions.lua", [2] = "media/lua/client/X.lua" })[i] end
    reloadLuaFile = function(path)
        if path:find("WTAGarouWolfCoats",1,true) then coatReloaded=path else reloadedPath=path end
    end
    local savedVisual=WTAGarou.Visual
    local refreshedPlayer
    WTAGarou.Visual={refresh=function(p) refreshedPlayer=p; assert(p==current,"real IsoPlayer required") end}
    -- PZ can expose a global table named player; handle() must not pass it.
    _G.player={}
    WTAGarou.Debug.handle("reload")
    check(refreshedPlayer==current,"reload command uses getPlayer, not unrelated engine global")
    _G.player=nil
    local report = realReload(nil)
    check(reloadedPath == "C:/mods/WTAGarou/42/media/lua/shared/WTAGarouDefinitions.lua", "Reload defs calls reloadLuaFile with the loaded Definitions path: " .. tostring(report))
    check(coatReloaded=="media/lua/shared/WTAGarouWolfCoats.lua","reload also refreshes coat registry")
    check(type(report) == "string" and not report:find("failed", 1, true), "reload reports success without loadstring: " .. tostring(report))
    getLoadedLua = function() return "media/lua/shared/Other.lua" end
    reloadedPath = nil
    report = realReload(nil)
    check(reloadedPath == "media/lua/shared/WTAGarouDefinitions.lua", "without a loaded match the mod path is passed to reloadLuaFile")
    reloadLuaFile, getLoadedLuaCount, getLoadedLua = nil, nil, nil
    report = realReload(nil)
    check(type(report) == "string" and report:find("failed", 1, true), "no reloadLuaFile and no loadstring reports a failure")
    loadstring, getModFileReader = savedLS, savedReader
    WTAGarou.Visual=savedVisual
end
local reloaded = false
WTAGarou.Debug.reloadDefinitions = function() reloaded = true; return "Definitions reloaded" end
click("reload"); check(reloaded,"Reload defs calls Debug.reloadDefinitions")
click("visual-status")
check(table.concat(ui.outputLines," "):find("Java API unavailable",1,true),"missing Java shown, not swallowed")
WTAGarouJava={status=function() return "wolf hook=true " .. string.rep("diagnostics ",90) end}
click("visual-status")
check(#ui.outputLines>ui.outputRows,"long Java diagnostics wrapped")
ui:onMouseWheel(999)
check(ui.outputOffset==#ui.outputLines-ui.outputRows,"scroll output to end")
ui:onMouseWheel(-999)
check(ui.outputOffset==0,"scroll output to start")
for _,line in ipairs(panel.wrap(string.rep("x",300),100)) do
    check(#line*7<=100,"unbroken diagnostics wrap within width")
end
WTAGarouJava.status=function() error("test bridge failure") end
click("visual-status")
check(table.concat(ui.outputLines," "):find("ERROR:",1,true),"bridge errors visible")
local hudMessages=0
WTAGarou.HUD={instance={setDebugLine=function() hudMessages=hudMessages+1 end}}
click("panictrace 60")
check(table.concat(ui.outputLines," ")=="trace 60","debug output reaches panel")
check(hudMessages==0,"panel diagnostics do not spill over main HUD")
click("panictrace 0")
check(table.concat(ui.outputLines," ")=="trace 0","trace stop routed")
player.data.WTAGarou.isGarou=false
count=#commands; click("form Hispo")
check(#commands==count,"non-Garou form changes disabled")
click("trait")
check(commands[#commands].command=="DebugTrait" and not commands[#commands].args.remove,"grant trait")
player.data.WTAGarou.isGarou=true
ui:prerender()
check(table.concat(ui.texts," "):find("Rage: 50.0",1,true),"live Rage visible")
player.data.WTAGarou.form="Hispo"; player.data.WTAGarou.rage=75
ui.texts={}; ui:prerender()
check(table.concat(ui.texts," "):find("Form: Hispo",1,true),"live form visible")
check(table.concat(ui.texts," "):find("Rage: 75.0",1,true),"live Rage refreshed")
ui:setX(240); ui:setY(50); ui:close()
check(not panel.instance and not ui.added,"close removes UI")
WTAGarou.Debug.say("closed-panel fallback")
check(hudMessages==1,"closed panel retains original HUD feedback")
WTAGarou.HUD=nil
ui=panel.open()
check(ui.x==240 and ui.y==50,"placement remembered independently")
check(player.data.WTAGarouHUDLayout==nil,"main HUD placement untouched")
ui:setX(9999); ui:setY(9999); ui:prerender()
check(ui.x+ui.width<=sw and ui.y+ui.height<=sh,"screen changes clamped")
WTAGarou.Debug.handle("panel")
check(panel.instance==nil,"chat panel command closes")
WTAGarou.Debug.handle("panel")
ui=panel.instance
check(ui~=nil,"chat panel command opens")
WTAGarou.Debug.handle("cheats")
check(panel.instance==nil,"0.4.45: /garou cheats toggles the same panel")
WTAGarou.Debug.handle("cheats"); ui=panel.instance
check(ui~=nil and ui.title=="Werewolf Cheats","/garou cheats opens the Werewolf Cheats window")
-- 0.4.45: "/garou ..." typed into multiplayer chat is handled locally and
-- never reaches SendCommandToServer (vanilla ISChat forwards every "/" line).
local sentToServer, logged = {}, {}
SendCommandToServer=function(c) sentToServer[#sentToServer+1]=c end
doKeyPress=function() end
local entryText="/garou cheats"
ISChat={ onCommandEntered=function(self) if entryText:sub(1,1)=="/" then SendCommandToServer(entryText) end end }
ISChat.instance={ textEntry={ getText=function() return entryText end }, unfocus=function(self) self.unfocused=true end,
    logChatCommand=function(self,c) logged[#logged+1]=c end }
ISChat.instance.textEntry.onCommandEntered=ISChat.onCommandEntered
check(WTAGarou.Debug.wrapChat()==true,"chat wrap installs once ISChat exists")
check(ISChat.instance.textEntry.onCommandEntered==ISChat.onCommandEntered and ISChat.WTAGarouOriginalOnCommandEntered,"the live text entry points at the wrapped handler")
ISChat.instance.textEntry.onCommandEntered(ISChat.instance)
check(#sentToServer==0 and panel.instance==nil and ISChat.instance.unfocused and logged[1]=="/garou cheats","/garou in chat runs locally (panel closed) and is swallowed")
entryText="/kick bob"
ISChat.instance.textEntry.onCommandEntered(ISChat.instance)
check(sentToServer[1]=="/kick bob","other slash commands still go to the server")
entryText="hello"
ISChat.instance.textEntry.onCommandEntered(ISChat.instance)
check(#sentToServer==1,"plain chat untouched")
WTAGarou.Debug.wrapChat()
check(ISChat.WTAGarouOriginalOnCommandEntered and ISChat.onCommandEntered~=ISChat.WTAGarouOriginalOnCommandEntered,"wrapping twice does not nest")
check(WTAGarou.Debug.chatLine("  /garou rage 100")=="rage 100" and WTAGarou.Debug.chatLine("/garoux")==nil and WTAGarou.Debug.chatLine("/garou")=="","chat line parser")
WTAGarou.Debug.handle("cheats"); ui=panel.instance
multiplayer=true; player.level=""
check(not panel.allowed(player),"ordinary MP client blocked")
count=#commands; click("rage 100")
check(#commands==count,"permission loss blocks actions")
player.level="None"; check(not panel.allowed(player),"None access blocked")
player.level="admin"; check(panel.allowed(player),"MP admin allowed")
multiplayer=false
player.dead=true
Events.OnPlayerDeath.callbacks[1](player)
check(panel.instance==nil,"death closes panel")
check(panel.open()==nil,"dead character cannot open")
player.dead=false; current=nil
check(panel.open()==nil,"no player cannot open")
current=player

-- Real client messages feed confirmation/denial into the panel without HUD.
WTAGarou.Net._clientHandler=nil
ISTimedActionQueue={getTimedActionQueue=function() return {queue={}} end}
require "WTAGarouClient"
ui=panel.open()
local handle=WTAGarou.Net._clientHandler
handle("WTAGarou","TransformDenied",{reason="not_enough_rage"})
check(table.concat(ui.outputLines," "):find("not_enough_rage",1,true),"server denial shown")
handle("WTAGarou","TransformAccepted",{form="Hispo"})
check(table.concat(ui.outputLines," "):find("Shift accepted: Hispo",1,true),"channel acknowledgement shown")
handle("WTAGarou","TransformCompleted",{form="Hispo"})
check(table.concat(ui.outputLines," ")=="Form confirmed: Hispo","completion shown")
print("PASS: "..n.." testing-panel assertions.")
