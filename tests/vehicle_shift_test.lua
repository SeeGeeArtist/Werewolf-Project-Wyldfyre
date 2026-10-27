-- 0.4.39: bulk-form shifts inside a vehicle (server authority) and the
-- client ejection handler. Fixtures shaped like B42.21 BaseVehicle /
-- VehiclePart / VehicleWindow (getSeat, getPassengerDoor, getChildWindow,
-- VehiclePart.damage routing to VehicleWindow.damage, VehicleWindow.hit).
local root=assert(arg[1])
package.path=root.."/42/media/lua/shared/?.lua;"..root.."/42/media/lua/server/?.lua;"..package.path
local n=0
local function check(ok,why) n=n+1; assert(ok,why) end
isServer=function() return false end
isClient=function() return false end
getTimestamp=function() return 1000 end
Events=setmetatable({},{__index=function(t,k) t[k]={Add=function() end}; return t[k] end})
local sent={}
WTAGarou=WTAGarou or {}
WTAGarou.Net={ToClient=function(p,cmd,args) sent[#sent+1]={p=p,cmd=cmd,args=args} end,
    ToServer=function() end,RegisterServerHandler=function() end,RegisterClientHandler=function() end,
    IsSinglePlayer=function() return true end}
require "WTAGarouDefinitions"
require "WTAGarouState"
require "WTAGarouVehicleShiftServer"
-- The real Net module replaced the stub on require; re-stub for capture.
WTAGarou.Net.ToClient=function(p,cmd,args) sent[#sent+1]={p=p,cmd=cmd,args=args} end
WTAGarou.Net.IsSinglePlayer=function() return true end
WTAGarou.HasGarouTrait=function(p) return p.garou~=false end
local V=WTAGarou.VehicleShift
check(V.onCompleted~=nil and V.ENABLED==true,"vehicle shift module loaded")

local function window(part)
    local w={condition=100,hits=0,part=part}
    function w:isDestroyed() return self.condition<=0 end
    function w:damage(n) self.condition=math.max(0,self.condition-n) end
    function w:hit(chr) self.hits=self.hits+1; self.hitBy=chr; self.condition=0 end
    function w:getPart() return self.part end
    return w
end
local function part(withWindow)
    local p={condition=100,transmits=0}
    function p:getCondition() return self.condition end
    function p:damage(n)
        if self.window then self.window:damage(n) end
        self.condition=math.max(0,self.condition-n); self.transmits=self.transmits+1
    end
    function p:getWindow() return self.window end
    function p:getChildWindow() return self.childWindow end
    function p:findWindow() return self.childWindow and self.childWindow.window end
    if withWindow then p.window=window(p) end
    return p
end
local function vehicle(id)
    local v={id=id,seats={},doors={},stats=0}
    function v:getId() return self.id end
    function v:getSeat(chr) for seat,c in pairs(self.seats) do if c==chr then return seat end end return -1 end
    function v:getPassengerDoor(seat) return self.doors[seat] end
    function v:updatePartStats() self.stats=self.stats+1 end
    return v
end
local function player(form,trueForm)
    local p={data={isGarou=true,form=form,trueForm=trueForm},garou=true}
    function p:isDead() return false end
    function p:getVehicle() return self.vehicle end
    function p:getModData() return {WTAGarou=self.data} end
    return p
end
WTAGarou.GetData=function(p) return p.data end

-- Door with a child window: both take the Crinos fraction; no smash on a high roll.
local car=vehicle(7); local driver=player("Crinos")
local door=part(false); local glass=part(true); door.childWindow=glass
car.doors[0]=door; car.seats[0]=driver; driver.vehicle=car
ZombRandFloat=function() return 0.5 end
check(V.onCompleted(driver,"Homid","Crinos",false)==true,"seated Crinos shift resolves")
check(door.condition==62 and door.transmits==1,"door takes 38 points (Crinos 0.375 of 100) and transmits")
check(glass.window.condition==62 and glass.window.hits==0,"window takes the same 38 points via VehiclePart.damage; not smashed at a 50% roll")
check(car.stats==1,"part stats refreshed")
local msg=sent[#sent]
check(msg and msg.cmd=="VehicleEjected" and msg.p==driver and msg.args.form=="Crinos" and msg.args.seat==0
    and msg.args.points==38 and msg.args.smashed==false and msg.args.vehicleId==7 and msg.args.forced==false,
    "owner told to leave seat 0 with the damage summary")

-- Forced (100-Rage) Crinos doubles the points like clothing.
sent={}; car=vehicle(8); local forced=player("Glabro"); door=part(false); glass=part(true); door.childWindow=glass
car.doors[2]=door; car.seats[2]=forced; forced.vehicle=car
check(V.onCompleted(forced,"Glabro","Crinos",true)==true and door.condition==25 and glass.window.condition==25
    and sent[#sent].args.points==75 and sent[#sent].args.forced==true,"forced Crinos deals 75 to door and window")

-- Hispo uses its own fraction; a low roll smashes the window outright (full engine smash, 1 hit).
sent={}; car=vehicle(9); local wolf=player("Hispo"); door=part(false); glass=part(true); door.childWindow=glass
car.doors[1]=door; car.seats[1]=wolf; wolf.vehicle=car
ZombRandFloat=function() return 0.019 end
check(V.onCompleted(wolf,"Homid","Hispo",false)==true,"seated Hispo shift resolves")
check(door.condition==75,"Hispo door damage is 25")
check(glass.window.hits==1 and glass.window.hitBy==wolf and glass.window.condition==0,"1.9% roll smashes the window through VehicleWindow.hit(player)")
check(sent[#sent].args.smashed==true and sent[#sent].args.seat==1,"ejection reports the smash")
ZombRandFloat=function() return 0.02 end
sent={}; car=vehicle(10); local edge=player("Hispo"); door=part(false); glass=part(true); door.childWindow=glass
car.doors[0]=door; car.seats[0]=edge; edge.vehicle=car
V.onCompleted(edge,"Homid","Hispo",false)
check(glass.window.hits==0 and glass.window.condition==75,"a 2.0% roll is not under the 2% line")

-- Already destroyed window: no further damage, no smash, still ejected.
sent={}; car=vehicle(11); local gone=player("Crinos"); door=part(false); glass=part(true); glass.window.condition=0; door.childWindow=glass
car.doors[0]=door; car.seats[0]=gone; gone.vehicle=car
ZombRandFloat=function() return 0.0 end
V.onCompleted(gone,"Homid","Crinos",false)
check(glass.window.hits==0 and sent[#sent].args.smashed==false and door.condition==62,"destroyed glass is left alone; door still damaged; still ejected")

-- Door without any window (findWindow nil): door damage only.
sent={}; car=vehicle(12); local bare=player("Crinos"); door=part(false); car.doors[0]=door; car.seats[0]=bare; bare.vehicle=car
V.onCompleted(bare,"Homid","Crinos",false)
check(door.condition==62 and sent[#sent].cmd=="VehicleEjected","no window: door damage and ejection only")

-- Non-bulk forms, unseated players, non-Garou and clients never act.
sent={}
check(V.onCompleted(player("Glabro"),"Homid","Glabro",false)==nil and #sent==0,"Glabro is not a bulk form")
check(V.onCompleted(player("Lupus"),"Hispo","Lupus",false)==nil and #sent==0,"Lupus is not a bulk form")
local walker=player("Crinos")
check(V.onCompleted(walker,"Homid","Crinos",false)==nil and #sent==0,"not seated: nothing happens")
car=vehicle(13); local mortal=player("Crinos"); mortal.garou=false; car.seats[0]=mortal; car.doors[0]=part(false); mortal.vehicle=car
check(V.onCompleted(mortal,"Homid","Crinos",false)==nil and #sent==0,"non-Garou ignored")
isClient=function() return true end
car=vehicle(14); local remote=player("Crinos"); car.seats[0]=remote; car.doors[0]=part(false); remote.vehicle=car
check(V.onCompleted(remote,"Homid","Crinos",false)==nil and #sent==0,"MP client never resolves vehicle damage")
isClient=function() return false end
V.ENABLED=false
check(V.onCompleted(remote,"Homid","Crinos",false)==nil,"kill switch respected")
V.ENABLED=true

-- Client side: VehicleEjected exits through BaseVehicle.exit and applies the bare-handed cut only when smashed.
package.path=root.."/42/media/lua/client/?.lua;"..package.path
local clientHandler
WTAGarou.Net.RegisterClientHandler=function(fn) clientHandler=fn end
WTAGarou.Visual={refresh=function() end}
WTAGarou.HUD={instance={pushNotice=function(self,t) self.notice=t end,flashDenial=function(self,r) self.denial=r end,refresh=function() end}}
local me={data={isGarou=true,form="Crinos"},cuts=0,voices={}}
function me:isDead() return false end
function me:getVehicle() return self.vehicle end
function me:getModData() return {WTAGarou=self.data} end
function me:getBodyDamage() return {setScratchedWindow=function() me.cuts=me.cuts+1 end} end
function me:playerVoiceSound(s) self.voices[#self.voices+1]=s end
getPlayer=function() return me end
getSpecificPlayer=function(n) if n==0 then return me end end
require "WTAGarouClient"
check(clientHandler~=nil,"client handler registered")
local exits=0
local carSounds={}
me.vehicle={exit=function(_,p) exits=exits+1; check(p==me,"exit called with the owner") end,
    playSound=function(_,name) carSounds[#carSounds+1]=name end}
clientHandler("WTAGarou","VehicleEjected",{form="Crinos",seat=0,points=38,smashed=false})
check(exits==1 and me.cuts==0 and #me.voices==0 and WTAGarou.HUD.instance.notice=="You burst out of the vehicle.","unsmashed ejection: exit only")
check(#carSounds==1 and carSounds[1]==WTAGarou.VehicleShift.IMPACT_SOUND and carSounds[1]=="VehicleCrash1",
    "0.4.40: damaged vehicle plays the impact cue from the vehicle")
me.vehicle={exit=function(_,p) exits=exits+1 end,playSound=function(_,name) carSounds[#carSounds+1]=name end}
clientHandler("WTAGarou","VehicleEjected",{form="Hispo",seat=1,points=25,smashed=true})
check(exits==2 and me.cuts==1 and me.voices[1]=="PainFromGlassCut" and WTAGarou.HUD.instance.notice=="You burst out through the glass.",
    "smashed ejection: exit, bare-handed glass cut and PainFromGlassCut")
check(#carSounds==2,"impact cue also plays on a smashed ejection")
me.vehicle={exit=function(_,p) exits=exits+1 end,playSound=function(_,name) carSounds[#carSounds+1]=name end}
clientHandler("WTAGarou","VehicleEjected",{form="Crinos",seat=0,points=0,smashed=false})
check(#carSounds==2 and exits==3,"no damage points: ejection without an impact cue")
me.vehicle=nil
clientHandler("WTAGarou","VehicleEjected",{form="Crinos",seat=0,points=38,smashed=false})
check(exits==3,"already outside: nothing to exit")

-- 0.4.41: silver burn reaction on the owner's client (notice, red warning,
-- halo, per-form cue; one cue per COOLDOWN).
local halos={}
-- the B42 helper: addText(player, text, separator, r, g, b) with 0-255 ints; NO getColorRGB
local haloArgs={}
HaloTextHelper={addText=function(p,text,sep,r,g,b)
    assert(type(sep)=="string" and type(r)=="number" and r==math.floor(r) and r>=0 and r<=255,"addText called with the B42 signature")
    halos[#halos+1]=text; haloArgs[#haloArgs+1]={sep,r,g,b} end,
    addBadText=function(p,text) halos[#halos+1]="BAD:"..text end}
local played={}
WTAGarou.Audio.play=function(src,name) played[#played+1]=name; return 1 end
WTAGarou.HUD.instance.flashSilverBurn=function(self,part) self.silverWarning=part end
me.voices={}
me.data.form="Crinos"
local ok,cue=WTAGarou.SilverReact(me,"Hand_R",100)
check(ok and cue=="WTAGarou_CrinosGrowl" and played[1]=="WTAGarou_CrinosGrowl" and #me.voices==0,"Crinos silver burn growls (mod cue, scaled)")
check(WTAGarou.HUD.instance.notice=="Silver burns your Hand R." and WTAGarou.HUD.instance.silverWarning=="Hand R"
    and halos[#halos]=="Silver Burn: Hand R","notice, red warning line and halo")
check(haloArgs[#haloArgs][2]==179 and haloArgs[#haloArgs][3]==204 and haloArgs[#haloArgs][4]==230,"0.4.79: halo colour passed as 0-255 ints (silver 0.7,0.8,0.9)")
check(WTAGarou.Halo(me,"You smell silver",0.7,0.8,0.9)==true and halos[#halos]=="You smell silver","the scent halo goes through the same helper")
local oldAdd=HaloTextHelper.addText; HaloTextHelper.addText=nil
check(WTAGarou.Halo(me,"x",1,1,1)==true and halos[#halos]=="BAD:x","without addText the helper falls back to addBadText")
HaloTextHelper.addText=oldAdd
ok,cue=WTAGarou.SilverReact(me,"Neck",100.5)
check(ok and cue==nil and #played==1 and WTAGarou.HUD.instance.silverWarning=="Neck","second part inside the cooldown: warning updates, no second cue")
me.data.form="Hispo"; WTAGarou.SilverReact(me,"Neck",102)
check(played[2]=="WTAGarou_HispoGrowl","Hispo growls")
me.data.form="Lupus"; WTAGarou.SilverReact(me,"Neck",104)
check(played[3]=="WTAGarou_WolfGrowl","Lupus wolf growl")
me.data.form="Homid"; WTAGarou.SilverReact(me,"Neck",106)
check(#played==3 and me.voices[1]=="PainFromScratch","Homid uses the vanilla ouch voice, not a mod cue")
me.data.form="Glabro"; WTAGarou.SilverReact(me,"Neck",108)
check(me.voices[2]=="PainFromScratch","Glabro too")
me.data.form="Crinos"
clientHandler("WTAGarou","SilverBurn",{part="Head"})
check(played[4]=="WTAGarou_CrinosGrowl" and WTAGarou.HUD.instance.silverWarning=="Head","dedicated-server SilverBurn command runs the same reaction")

-- Lua entry guard wraps the vanilla enter paths.
ISEnterVehicle={isValid=function(self) return "vanilla" end}
ISVehicleMenu={onEnter=function(playerObj,vehicle,seat) return "entered" end}
require "WTAGarouVehicleGuard"
check(WTAGarou.VehicleGuard.install()==true,"guard wrapped both vanilla paths")
check(WTAGarou.VehicleGuard.install()==false,"guard installs once")
me.data.form="Crinos"
check(ISEnterVehicle.isValid({character=me})==false and WTAGarou.HUD.instance.denial=="vehicle_blocked","Crinos enter action is invalid with a HUD denial")
check(ISVehicleMenu.onEnter(me,{},0)==nil,"Crinos menu entry refused")
me.data.form="Glabro"; WTAGarou.HUD.instance.denial=nil
check(ISEnterVehicle.isValid({character=me})=="vanilla" and ISVehicleMenu.onEnter(me,{},0)=="entered" and WTAGarou.HUD.instance.denial==nil,
    "Glabro passes straight through to vanilla")
me.data.form="Hispo"
check(ISVehicleMenu.onEnter(me,{},0)==nil,"Hispo menu entry refused")
print("PASS: "..n.." vehicle-shift authority / ejection / entry-guard assertions.")
