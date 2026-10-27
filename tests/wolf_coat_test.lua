local root=assert(arg[1])
package.path=root.."/42/media/lua/shared/?.lua;"..root.."/42/media/lua/client/?.lua;"..package.path
require "WTAGarouWolfCoats"
require "WTAGarouState"
local checks=0
local function check(ok,why) checks=checks+1; assert(ok,why) end
local client=false
isClient=function() return client end
isServer=function() return false end
local now=100
getTimestamp=function() return now end
Events={}
for _,name in ipairs({"OnPlayerUpdate","OnFillWorldObjectContextMenu","OnPlayerDeath","OnClientCommand"}) do
    Events[name]={Add=function(fn) Events[name].fn=fn end}
end
local function player(id,num)
    local p={id=id,num=num,data={},garou=true}
    function p:isDead() return self.dead end
    function p:isLocalPlayer() return true end
    function p:getPlayerNum() return self.num end
    function p:getOnlineID() return self.id end
    return p
end
local a,b=player(41,0),player(42,1)
WTAGarou.GetData=function(p) return p.data end
WTAGarou.HasGarouTrait=function(p) return p.garou end
getSpecificPlayer=function(n) return ({[0]=a,[1]=b})[n] end
getNumActivePlayers=function() return 2 end
local refreshed={}
WTAGarou.Visual={refresh=function(p) refreshed[p]=true end}
ISCollapsableWindow={}
function ISCollapsableWindow:derive() local c={}; c.__index=c; return setmetatable(c,{__index=self}) end
function ISCollapsableWindow:new(x,y,w,h) return setmetatable({children={},x=x,y=y,width=w,height=h},{__index=self}) end
function ISCollapsableWindow:setTitle(title) self.title=title end
function ISCollapsableWindow:createChildren() end
function ISCollapsableWindow:initialise() self:createChildren() end
function ISCollapsableWindow:addToUIManager() self.visible=true end
function ISCollapsableWindow:addChild(child) self.children[#self.children+1]=child end
function ISCollapsableWindow:close() self.visible=false end
ISButton={}
function ISButton:new(x,y,w,h,label,target,fn)
    return {label=label,target=target,onclick=fn,
        initialise=function() end,setTooltip=function(self,t) self.tooltip=t end,
        setTitle=function(self,t) self.label=t end}
end
getPlayerScreenLeft=function() return 0 end
getPlayerScreenTop=function() return 0 end
getTexture=function() return {} end
package.loaded["ISUI/ISCollapsableWindow"]=true
package.loaded["ISUI/ISButton"]=true
require "WTAGarouNet"
require "WTAGarouWolfCoat"
dofile(root.."/42/media/lua/server/WTAGarouWolfCoatServer.lua")
local replies={}
WTAGarou.Net.RegisterClientHandler(function(_,command,args)
    check(command=="WolfCoatSelected","only coat response")
    replies[#replies+1]=args
    WTAGarou.WolfCoat.receive(args)
end)
local requests={}
sendClientCommand=function(p,_,command,args) requests[#requests+1]={p=p,command=command,args=args} end
local opened={}
WTAGarou.HUD={instance={getX=function() return 80 end,getY=function() return 20 end,getHeight=function() return 268 end}}
local window=WTAGarouCoatWindow:new(a); window:initialise(); window:addToUIManager()
check(window.x==80 and window.y==300,"picker sits 12px beneath HUD")
WTAGarou.HUD.instance.getX=function() return 0 end
getPlayerScreenWidth=function() return 1280 end
getPlayerScreenHeight=function() return 720 end
local inset=WTAGarouCoatWindow:new(a)
check(inset.x==40 and inset.y==math.min(300,720-inset.height),
    "40px left inset preserved; expanded six-coat picker stays inside 720px screen")
WTAGarou.HUD.instance.getX=function() return 80 end
check(window.visible and #window.children==19 and #window.coatButtons==6,
    "chooser includes six coats, three true forms, five baselines, Confirm, gear and the Crinos tail pair")
local coatButtons={}
for _,button in ipairs(window.coatButtons) do coatButtons[button.coat]=button end
for _,key in ipairs({"default","black","blonde","brindle","brown","white"}) do
    check(coatButtons[key] and coatButtons[key].enable~=false,"available coat button "..key)
end
check(window.coatKeys[1]=="default","saved Timber key remains first")
for _,key in ipairs({"black","white"}) do
    window:choose(coatButtons[key])
    check(window.coat==key and coatButtons[key].selected,"stage new coat "..key)
end
window.coat=nil; window:refreshLock()
-- 0.4.45 Baseline Rage row: 30 40 50 60 70, between the coats and Confirm.
for i,a in ipairs(WTAGarou.Auspices) do
    local b=window.auspiceButtons[i]
    check(b.auspice==a.key and b.label==tostring(a.baseline) and b.tooltip:find(a.moon,1,true)
        and b.tooltip:find(a.key,1,true),"baseline button "..a.baseline.." carries the "..a.key.." tooltip")
end
check(window.auspiceY>131+3*38 and window.confirmY>=window.auspiceY+30,"baseline row sits below all three coat rows")
check(window.children[3].trueForm=="Glabro" and window.children[3].label=="Berserker"
    and window.children[3].tooltip:find("Metis"),"third true form is Berserker and its tooltip names the Metis breed")
check(window.children[15]==window.confirmButton and window.confirmButton.enable==false,
    "Confirm sits below the baselines and waits for a staged coat and baseline")
window:chooseTrueForm(window.children[2])
check(window.trueForm=="Lupus" and window.children[2].label=="Wolf" and window.children[2].selected==true
    and window.children[1].selected==false and window.children[2].borderColor==WTAGarou.WolfCoat.SELECTED_BORDER,
    "Wolf true-form selection staged by border/colour, not a text suffix")
window:chooseTrueForm(window.children[3])
check(window.trueForm=="Glabro" and window.children[3].label=="Berserker" and window.children[3].selected==true
    and window.children[2].selected==false,"Berserker true-form selection staged")
for _,c in ipairs(window.children) do check(not (c.label or ""):find("selected",1,true),"no [selected] text on any picker button") end
window:chooseTrueForm(window.children[2])
WTAGarou.WolfCoats.testcoat={label="Test",path="media/textures/Body/WTAGarou_Wolf_Test.png"}
local expanded=WTAGarouCoatWindow:new(a); expanded:initialise()
check(#expanded.children==20 and expanded.height==282+4*38+62+62
    and #expanded.coatButtons==7,"registry entry adds a fourth coat row above baselines, gear and tail")
WTAGarou.WolfCoats.testcoat=nil
getTexture=function() return nil end
local missing=WTAGarouCoatWindow:new(a); missing:initialise()
for _,button in ipairs(missing.coatButtons) do
    check(button.enable==false and button.tooltip,"missing asset disables "..button.coat)
end
getTexture=function() return {} end
WTAGarou.WolfCoat.open=function(p) opened[p]=(opened[p] or 0)+1 end
local tick=Events.OnPlayerUpdate.fn
tick(a); tick(a)
check(opened[a]==1,"unselected solo character prompted once")
WTAGarou.Net.ToServer(a,"SelectWolfCoat",{coat="blonde",rage=100,form="Crinos",playerID=b.id})
check(a.data.wolfCoat=="blonde" and b.data.wolfCoat==nil,"selection changes sender only")
check(a.data.rage==nil and a.data.form==nil,"cosmetic cannot mutate gameplay")
check(refreshed[a],"selection refreshes visuals")
WTAGarou.Net.ToServer(a,"SelectWolfCoat",{coat="../../bad"})
check(a.data.wolfCoat=="blonde" and #replies==1,"arbitrary texture rejected")
a.garou=false
WTAGarou.Net.ToServer(a,"SelectWolfCoat",{coat="default"})
check(a.data.wolfCoat=="blonde","non-Garou rejected")
a.garou=true; a.dead=true
WTAGarou.Net.ToServer(a,"SelectWolfCoat",{coat="default"})
check(a.data.wolfCoat=="blonde","dead character rejected")
a.dead=false
WTAGarou.Net.ToServer(a,"RequestWolfCoat",{})
check(replies[#replies].coat=="blonde","saved selection returned")
WTAGarou.Net.ToServer(a,"SelectWolfCoat",{coat="default"})
check(a.data.wolfCoat=="default","original is a saved choice, not unset")
for _,key in ipairs({"black","white"}) do
    WTAGarou.Net.ToServer(a,"SelectWolfCoat",{coat=key})
    check(a.data.wolfCoat==key,"server accepts new coat "..key)
    WTAGarou.Net.ToServer(a,"RequestWolfCoat",{})
    check(replies[#replies].coat==key,"server restores new coat "..key)
end
WTAGarou.Net.ToServer(a,"SelectWolfCoat",{coat="default"})
b.data.wolfCoat="blonde"; b.data.trueForm="Homid"; tick(b)
check(opened[b]==1,"0.4.45: a save locked before the baseline existed is prompted once to pick it")
Events.OnPlayerDeath.fn(b); opened[b]=nil
b.data.auspice="Philodox"; b.data.auspiceLocked=true; tick(b)
check(not opened[b],"existing fully saved character not prompted")
-- Reconnect: wait for authority, identify local player by online ID.
client=true
local response
sendServerCommand=function(p,module,command,args)
    response={p=p,module=module,command=command,args=args}
end
Events.OnClientCommand.fn("WTAGarou","SelectWolfCoat",b,{coat="blonde"})
check(response and response.p==b and response.args.coat=="blonde"
    and response.args.onlineID==42,"native MP event invokes server handler and addresses reply")
Events.OnPlayerDeath.fn(b)
tick(b); tick(b)
check(#requests==1 and requests[1].command=="RequestWolfCoat","one request before server reply")
now=106; tick(b)
check(#requests==2,"unanswered request retries after five seconds")
WTAGarou.WolfCoat.receive({coat="default",playerNum=0,onlineID=42})
check(b.data.wolfCoat=="default" and a.data.wolfCoat=="default","MP routes by online ID")
tick(b)
check(not opened[b],"server-restored choice suppresses startup prompt")
WTAGarou.WolfCoat.receive({coat="blonde",playerNum=0,onlineID=999})
check(a.data.wolfCoat=="default","foreign ID cannot target player zero")
Events.OnPlayerDeath.fn(b)
WTAGarou.WolfCoat.receive({coat="",playerNum=0,onlineID=42})
tick(b); tick(b)
check(opened[b]==1,"server confirms unset before MP prompt")
Events.OnPlayerDeath.fn(b)
client=false
local applied=0
WTAGarou.ApplyFormBuffs=function(p) applied=applied+1 end
a.data.trueForm=nil; a.data.form="Homid"; a.data.identityLocked=nil
check(not WTAGarou.IdentityLocked(a.data),"coat-only picks before 0.4.39 did not lock identity")
WTAGarou.Net.ToServer(a,"SelectWolfCoat",{coat="brindle",trueForm="Lupus"})
check(a.data.trueForm=="Lupus" and a.data.form=="Lupus" and applied==1,"first Wolf choice starts in Lupus")
check(a.data.wolfCoatTexture==WTAGarou.WolfCoats.brindle.path and a.data.isGarou,"corpse metadata records validated coat")
check(WTAGarou.IdentityLocked(a.data) and replies[#replies].identityLocked==true,"confirmed choice locks true form and coat")
WTAGarou.Net.ToServer(a,"RequestWolfCoat",{})
check(replies[#replies].trueForm=="Lupus" and replies[#replies].form=="Lupus" and replies[#replies].identityLocked==true,
    "saved true form and lock returned on reconnect")
WTAGarou.Net.ToServer(a,"SelectWolfCoat",{coat="default",trueForm="Homid"})
check(a.data.trueForm=="Lupus" and a.data.wolfCoat=="brindle" and replies[#replies].identityLocked==true,
    "locked identity refuses later coat / true-form changes")
a.data.identityLocked=nil
WTAGarou.Net.ToServer(a,"SelectWolfCoat",{coat="default",trueForm="Homid"})
check(a.data.trueForm=="Homid" and a.data.form=="Lupus" and applied==1,"later identity change cannot free-shift")
a.data.identityLocked=nil
WTAGarou.Net.ToServer(a,"SelectWolfCoat",{coat="default",trueForm="Crinos"})
check(a.data.trueForm=="Homid","only Human, Wolf and Berserker accepted")
a.data.identityLocked=nil
WTAGarou.Net.ToServer(a,"SelectWolfCoat",{coat="default",trueForm="Glabro"})
check(a.data.trueForm=="Glabro" and WTAGarou.BaseForm(a.data)=="Glabro" and WTAGarou.IsBerserkerBreed(a.data)
    and a.data.form=="Lupus","Berserker accepted as a true form; no free shift on a later change")
a.data.identityLocked=nil
WTAGarou.Net.ToServer(a,"SelectWolfCoat",{coat="default",trueForm="Homid"})
a.data.identityLocked=nil
a.data.pendingForm="Hispo"
WTAGarou.Net.ToServer(a,"SelectWolfCoat",{coat="blonde",trueForm="Lupus"})
check(a.data.trueForm=="Homid" and a.data.wolfCoat=="default","identity edits blocked during shift")
a.data.pendingForm=nil
-- 0.4.39: a Berserker's first confirmed choice starts the character in Glabro.
local c=player(43,2); getSpecificPlayer=function(n) return ({[0]=a,[1]=b,[2]=c})[n] end
WTAGarou.Net.ToServer(c,"SelectWolfCoat",{coat="default",trueForm="Glabro"})
check(c.data.form=="Glabro" and c.data.trueForm=="Glabro" and applied==2 and WTAGarou.IdentityLocked(c.data),
    "first Berserker choice starts in Near-Human and locks")
-- 0.4.39: picker confirm flow. Coat clicks stage; Confirm asks; YES sends once.
local e=player(44,3); getSpecificPlayer=function(n) return ({[0]=a,[1]=b,[2]=c,[3]=e})[n] end
local modal
ISModalDialog={new=function(_,x,y,w,h,text,yesno,target,fn)
    modal={text=text,yesno=yesno,target=target,fn=fn,initialise=function() end,addToUIManager=function() end}
    return modal end}
local picker=WTAGarouCoatWindow:new(e); picker:initialise(); picker:addToUIManager()
check(picker.locked==false and picker.coat==nil and picker.auspice==nil and picker.confirmButton.enable==false,"fresh picker is unlocked with nothing staged")
picker:chooseTrueForm(picker.children[3])
local brindleButton
for _,button in ipairs(picker.coatButtons) do if button.coat=="brindle" then brindleButton=button end end
picker:choose(brindleButton)
check(e.data.wolfCoat==nil and picker.coat=="brindle" and brindleButton.label=="Brindle" and brindleButton.selected==true
    and picker.confirmButton.enable==false,"coat click only stages; Confirm still waits for a baseline")
picker:confirm()
check(modal==nil,"Confirm without a baseline does nothing")
picker:chooseAuspice(picker.auspiceButtons[1])
check(picker.auspice=="Ragabash" and picker.auspiceButtons[1].selected==true and picker.auspiceButtons[5].selected==false
    and picker.confirmButton.enable==true,"baseline click stages the auspice; Confirm becomes available")
check(WTAGarou.WolfCoat.footerText(false)=="Reopen later: Rage panel > Startup." and WTAGarou.WolfCoat.footerText(true)==WTAGarou.WolfCoat.footerText(false)
    and picker.title=="Werewolf Startup" and WTAGarou.WolfCoat.REOPEN_BUTTON=="Startup",
    "0.4.45: window is \"Werewolf Startup\" and the footer points at the Rage panel's Startup button")
local before=#replies
picker:confirm()
check(modal and modal.yesno==true and modal.text:find("Are you sure") and modal.text:find("Berserker")
    and modal.text:find("Brindle") and modal.text:find("Baseline Rage: 30 (New Moon)",1,true) and #replies==before,
    "Confirm opens an Are-you-sure dialog naming the baseline and sends nothing yet")
picker:onConfirmDialog({internal="NO"})
check(e.data.wolfCoat==nil and not picker.locked,"declining the dialog changes nothing")
picker:confirm(); picker:onConfirmDialog({internal="YES"})
check(e.data.wolfCoat=="brindle" and e.data.trueForm=="Glabro" and e.data.form=="Glabro"
    and WTAGarou.IdentityLocked(e.data) and e.data.auspice=="Ragabash" and WTAGarou.AuspiceLocked(e.data)
    and WTAGarou.BaselineRage(e.data)==30 and replies[#replies].auspice=="Ragabash" and replies[#replies].auspiceLocked==true,
    "YES sends the staged choice once; the server locks true form, coat and baseline Rage (30)")
check(picker.locked==true and picker.auspiceLocked==true and picker.confirmButton.enable==false and picker.children[1].enable==false
    and brindleButton.enable==false and picker.auspiceButtons[1].enable==false and picker.gearButtons[1].enable~=false
    and picker.title=="Werewolf Startup",
    "picker locks true form, coat and baseline but leaves wolf gear changeable")
picker:choose(picker.coatButtons[1]); picker:chooseTrueForm(picker.children[1]); picker:chooseAuspice(picker.auspiceButtons[5])
check(picker.coat=="brindle" and picker.trueForm=="Glabro" and picker.auspice=="Ragabash","locked picker ignores further clicks")
picker:chooseGear(picker.gearButtons[2])
check(e.data.wolfGearVariant=="Camo" and e.data.wolfCoat=="brindle","gear still changes after the lock")
local relock=WTAGarouCoatWindow:new(e); relock:initialise()
check(relock.locked==true and relock.auspiceLocked==true and relock.title=="Werewolf Startup" and relock.children[1].enable==false
    and relock.auspiceButtons[1].enable==false and relock.auspiceButtons[1].selected==true,"reopened picker remembers both locks")
-- 0.4.45: a save confirmed before 0.4.45 (true form + coat locked, no auspice)
-- may still pick its baseline once; nothing else reopens.
local f=player(45,4); getSpecificPlayer=function(n) return ({[0]=a,[1]=b,[2]=c,[3]=e,[4]=f})[n] end
f.data.wolfCoat="blonde"; f.data.trueForm="Homid"; f.data.form="Homid"; f.data.identityLocked=true
check(WTAGarou.BaselineRage(f.data)==50,"pre-0.4.45 locked save drifts to 50 until it picks")
local old=WTAGarouCoatWindow:new(f); old:initialise(); old:addToUIManager()
check(old.locked==true and old.auspiceLocked==false and old.children[1].enable==false and old.auspiceButtons[1].enable~=false
    and old.confirmButton.enable==false and old.confirmButton.label=="Confirm baseline Rage","old save: only the baseline row is open")
old:chooseAuspice(old.auspiceButtons[5]); old:confirm(); old:onConfirmDialog({internal="YES"})
check(f.data.auspice=="Ahroun" and WTAGarou.AuspiceLocked(f.data) and WTAGarou.BaselineRage(f.data)==70
    and f.data.wolfCoat=="blonde" and f.data.trueForm=="Homid" and old.auspiceLocked==true and old.confirmButton.label=="Confirmed",
    "old save confirms its baseline (70) without touching coat or true form")
WTAGarou.Net.ToServer(f,"SelectWolfCoat",{coat="blonde",trueForm="Homid",auspice="Ragabash",confirm=true})
check(f.data.auspice=="Ahroun","locked baseline refuses a second pick")
WTAGarou.Net.ToServer(f,"SelectWolfCoat",{coat="blonde",trueForm="Homid",auspice="Bogus",confirm=true})
check(f.data.auspice=="Ahroun","unknown auspice ignored")
getSpecificPlayer=function(n) return ({[0]=a,[1]=b,[2]=c,[3]=e})[n] end
getSpecificPlayer=function(n) return ({[0]=a,[1]=b})[n] end
check(window.gearButtons[1].gear=="Black" and window.gearButtons[2].gear=="Camo",
    "Wolf Gear row contains Black/Camo below coats")
check(window.gearY>131+38 and window.gearY+30<window.footerY,"gear row fits above footer")
window:chooseGear(window.gearButtons[2])
check(a.data.wolfGearVariant=="Camo" and a.data.form=="Lupus" and a.data.trueForm=="Homid",
    "gear selection cannot shift or change identity")
check(window.visible,"gear selection leaves picker open")
WTAGarou.Net.ToServer(a,"RequestWolfCoat",{})
check(replies[#replies].wolfGearVariant=="Camo","gear restored with coat reply")
WTAGarou.Net.ToServer(a,"SelectWolfGear",{variant="../../arbitrary",rage=100})
check(a.data.wolfGearVariant=="Camo" and a.data.rage==nil,"gear is allowlisted and cosmetic only")
WTAGarou.Net.ToServer(a,"SelectWolfGear",{variant="Black",playerID=b.id})
check(a.data.wolfGearVariant=="Black" and b.data.wolfGearVariant~="Camo","gear changes sender only")
a.dead=true
WTAGarou.Net.ToServer(a,"SelectWolfGear",{variant="Camo"})
check(a.data.wolfGearVariant=="Black","dead gear selection rejected")
a.dead=false; a.garou=false
WTAGarou.Net.ToServer(a,"SelectWolfGear",{variant="Camo"})
check(a.data.wolfGearVariant=="Black","non-Garou gear selection rejected")
a.garou=true
window:choose(window.children[3])
check(window.visible,"choosing a coat keeps gear row reachable")
check(WTAGarou.WolfGearKey(nil)=="Black" and WTAGarou.WolfGearKey("bad")=="Black","old saves default Black")
-- 0.4.67: Crinos tail toggle mirrors the gear row: cosmetic, never locks, sender only.
check(window.tailButtons[1].tail==false and window.tailButtons[2].tail==true and window.tailButtons[1].selected
    and window.tailY>window.gearY and window.tailY+30<window.footerY,"Crinos Tail row defaults to No tail, sits between gear and footer")
window:chooseTail(window.tailButtons[2])
check(a.data.crinosTail==true and a.data.form=="Lupus" and a.data.trueForm=="Homid" and window.visible,
    "tail on: saved server-side, no form/identity change, picker stays open")
check(replies[#replies].crinosTail==true,"coat reply carries the tail flag")
window:updateTail(replies[#replies].crinosTail)
check(window.tailButtons[2].selected and not window.tailButtons[1].selected,"picker marks the tail from the reply")
window:chooseTail(window.tailButtons[1])
check(a.data.crinosTail==nil and replies[#replies].crinosTail==false,"tail off stores nil (old saves stay tail-less)")
window:updateTail(replies[#replies].crinosTail)
check(window.tailButtons[1].selected and not window.tailButtons[2].selected,"picker marks No tail again")
WTAGarou.Net.ToServer(a,"SelectCrinosTail",{tail="yes"})
check(a.data.crinosTail==nil,"non-boolean tail rejected")
WTAGarou.Net.ToServer(a,"SelectCrinosTail",{tail=true,playerID=b.id})
check(a.data.crinosTail==true and b.data.crinosTail==nil,"tail changes sender only")
a.dead=true
WTAGarou.Net.ToServer(a,"SelectCrinosTail",{tail=false})
check(a.data.crinosTail==true,"dead tail selection rejected")
a.dead=false
check(WTAGarou.CrinosTailOn(nil)==false and WTAGarou.CrinosTailOn(true)==true and WTAGarou.CrinosTailOn("true")==false,"tail flag is a strict boolean")
for _,coat in ipairs(WTAGarou.WolfCoatKeys()) do
    local entry=WTAGarou.WolfCoats[coat]
    check(entry.crinosLegs and entry.crinosLegs==entry.crinosBody
        and entry.crinosTail and entry.crinosTail==entry.crinosHead,"coat "..coat.." legs use the body atlas texture (vanilla UV), tail the wolf atlas like the head (0.4.94)")
    for _,tex in ipairs({entry.crinosLegs,entry.crinosTail}) do
        local f=io.open(root.."/common/media/textures/Body/"..tex..".png","rb")
        check(f~=nil,"shipped part texture "..tex); if f then f:close() end
    end
end
for _,mesh in ipairs({"WTAGarou_CrinosLegs","WTAGarou_CrinosTail"}) do
    local f=io.open(root.."/common/media/models_X/Skinned/Clothes/"..mesh..".glb","rb")
    check(f~=nil,"shipped skinned mesh "..mesh.." (0.4.94: unisex own GLB)"); if f then f:close() end
    for _,sexed in ipairs({"_M","_F"}) do
        local old=io.open(root.."/common/media/models_X/Skinned/Clothes/"..mesh..sexed..".glb","rb")
        check(old==nil,"0.4.94: no sexed variant "..mesh..sexed); if old then old:close() end
    end
    local old=io.open(root.."/common/media/models_X/Skinned/Clothes/"..mesh..".fbx","rb")
    check(old==nil,"0.4.90: no third-party FBX for "..mesh); if old then old:close() end
end
check(io.open(root.."/common/media/textures/WTAGarou/CrinosLegsMasks/Crotch.png","rb")==nil,"0.4.90: no third-party mask set ships")
check(WTAGarou.ValidWolfCoat("default") and WTAGarou.ValidWolfCoat("blonde")
    and not WTAGarou.ValidWolfCoat({}) and not WTAGarou.ValidWolfCoat("invalid"),"allowlist")
print("PASS: "..checks.." wolf coat persistence/routing/authorization assertions.")
