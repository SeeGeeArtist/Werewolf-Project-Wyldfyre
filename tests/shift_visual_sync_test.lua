-- Real sender, server filter, snapshot serializer, receiver and renderer path.
-- These are Lua mocks; two real clients must still verify rendered timing.
local root=assert(arg[1])
package.path=root.."/42/media/lua/shared/?.lua;"..root.."/42/media/lua/client/?.lua;"
    ..root.."/42/media/lua/server/?.lua;"..package.path
local checks, clock, server, client = 0, 100, true, false
local function check(ok,msg) checks=checks+1; assert(ok,msg) end
local function near(a,b,msg) check(math.abs(a-b)<0.000001,msg.." ("..tostring(a)..")") end
getTimestamp=function() return math.floor(clock) end
getTimestampMs=function() return clock*1000 end
isServer=function() return server end
isClient=function() return client end
Events={}
for _,name in ipairs({"OnTick","OnClientCommand","OnServerCommand","OnGameStart","OnCreatePlayer",
        "OnPlayerUpdate","OnPlayerDeath"}) do
    Events[name]={handlers={}}
    Events[name].Add=function(fn) table.insert(Events[name].handlers,fn) end
end
require "WTAGarouDefinitions"
require "WTAGarouState"
local function actor(id,name,localPlayer)
    local p={id=id,name=name,localPlayer=localPlayer,data={WTAGarou={isGarou=true,form="Homid",rage=60}}}
    function p:getOnlineID() return self.id end
    function p:getUsername() return self.name end
    function p:getModData() return self.data end
    function p:isLocalPlayer() return self.localPlayer end
    function p:isDead() return self.dead==true end
    function p:isFemale() return false end
    function p:setVariable() end
    return p
end
local a,b=actor(1,"alice"),actor(2,"bob")
local owner,remote=actor(2,"bob",true),actor(1,"alice",false)
remote.data.WTAGarou.isGarou=false
local sPlayers,cPlayers={a,b},{owner,remote}
getOnlinePlayers=function()
    local list=server and sPlayers or cPlayers
    return {size=function() return #list end,get=function(_,i) return list[i+1] end}
end
getPlayer=function() return owner end
local packets,clientPackets={},{}
sendServerCommand=function(module,command,args)
    check(command=="VisualSnapshot","only existing server snapshot channel used")
    packets[#packets+1]=args
end
sendClientCommand=function(p,module,command,args)
    clientPackets[#clientPackets+1]={player=p,module=module,command=command,args=args}
end
require "WTAGarouVisualSyncServer"
require "WTAGarouVisual"
require "WTAGarouVisualSync"
local SS,VS,CS,S=WTAGarou.ShiftVisualServer,WTAGarou.VisualSyncServer,WTAGarou.VisualSync,WTAGarou.ShiftScale
local scaled={}
WTAGarouJava={setScale=function(p,v) scaled[p]=v; return true end,
    clear=function(p) scaled[p]=nil end}
local function onServer() server,client=true,false end
local function onClient() server,client=false,true end
local function begin(p,target)
    onServer()
    local d=p.data.WTAGarou
    d.pendingForm=target; d.pendingExpiresAt=math.floor(clock)+60
    local args={form=target,previousForm=d.form,seconds=6}
    SS.reply(p,"TransformAccepted",args)
    check(type(args.shiftVisualToken)=="number","accepted server reservation receives a token")
    return args.shiftVisualToken
end
local function progress(p,token,n,extra)
    onServer()
    local args=extra or {}
    args.token, args.progress=token,n
    SS.receive("WTAGarou","ShiftVisualProgress",p,args)
end
local function publish()
    onServer(); VS.tick(); return packets[#packets]
end
local function deliver(packet)
    onClient(); CS.receive("WTAGarou","VisualSnapshot",packet); CS.tick()
end
local token=begin(a,"Crinos")
deliver(publish())
near(scaled[remote],1,"observer begins at current form")
check(scaled[owner]==nil,"own player never receives observer scale")
clock=clock+0.21
progress(a,token,0.5,{form="Hispo",scale=99,id=2,ownerID=2})
local half=publish()
deliver(half)
near(scaled[remote],1,"incoming sample starts smoothing rather than snapping")
clock=clock+0.1; CS.tick()
near(scaled[remote],1.121875,"sub-second tick interpolates without OnPlayerUpdate")
clock=clock+0.11; CS.tick()
near(scaled[remote],1.24375,"half channel sample rendered")
check(a.data.WTAGarou.form=="Homid" and a.data.WTAGarou.rage==60
    and remote.data.WTAGarou.form=="Homid" and not remote.data.WTAGarou.isGarou,
    "progress never edits authoritative or remote gameplay state")
check(scaled[owner]==nil,"forged owner ID ignored")

onServer()
local revision=SS.sample(a).revision
progress(a,token,0.4)
progress(a,token,0/0)
progress(a,token,math.huge)
progress(a,token,2)
progress(a,token,"1")
progress(b,token,1)
progress(a,token+999,1)
check(SS.sample(a).revision==revision,"invalid, backwards, wrong-owner and stale-token packets rejected")
progress(a,token,0.7)
revision=SS.sample(a).revision
progress(a,token,0.8)
check(SS.sample(a).revision==revision,"progress floods rate limited")
clock=clock+0.21
progress(a,token,1)
deliver(publish()); clock=clock+0.21; CS.tick()
near(scaled[remote],1.4875,"75% endpoint shown to observer")
-- Older snapshots and malformed scale metadata must not consume sequence.
deliver(half); clock=clock+0.21; CS.tick()
near(scaled[remote],1.4875,"out-of-order snapshot cannot rewind shift")
local bad={sequence=packets[#packets].sequence+1000,players={{id=1,username="alice",garou=true,
    alive=true,form="Homid",shift={token=token,revision=999,mode="channel",value=999,remaining=0}}}}
deliver(bad)
near(scaled[remote],1.4875,"malformed shift metadata rejected atomically")
-- Explicit cancel follows the same one-second recovery on observers.
onServer()
SS.receive("WTAGarou","ShiftVisualProgress",a,{token=token,cancel=true})
local cancelled=publish()
deliver(cancelled)
near(scaled[remote],1.4875,"cancel does not snap")
clock=clock+0.5; CS.tick()
near(scaled[remote],1.24375,"cancel half-second return")
deliver(cancelled) -- stale sequence ignored
clock=clock+0.51; CS.tick()
near(scaled[remote],1,"cancel returns to base in one second")
CS.tick(); near(scaled[remote],1,"cached descriptor cannot replay cancellation")

-- Restart during return, stale token, completion and forced replacement.
token=begin(a,"Crinos"); clock=clock+0.21; progress(a,token,0.5)
deliver(publish()); clock=clock+0.21; CS.tick()
onServer(); SS.receive("WTAGarou","ShiftVisualProgress",a,{token=token,cancel=true})
deliver(publish()); clock=clock+0.25; CS.tick()
local replacementToken=begin(a,"Hispo")
local before=SS.sample(a).value
progress(a,token,1); SS.receive("WTAGarou","ShiftVisualProgress",a,{token=token,cancel=true})
near(SS.sample(a).value,before,"old token cannot change same-player replacement")
clock=clock+0.21; progress(a,replacementToken,1)
deliver(publish()); clock=clock+0.21; CS.tick()
near(scaled[remote],1.4125,"replacement reaches its own endpoint")
onServer(); a.data.WTAGarou.form="Hispo"; a.data.WTAGarou.pendingForm=nil
SS.reply(a,"TransformCompleted",{form="Hispo"})
deliver(publish())
near(scaled[remote],1.55,"completion goes directly to authoritative full scale")
token=begin(a,"Homid"); clock=clock+0.21; progress(a,token,1)
deliver(publish()); clock=clock+0.21; CS.tick()
near(scaled[remote],1.1375,"shrinking channel uses same server-derived fraction")
onServer(); a.data.WTAGarou.form="Homid"; a.data.WTAGarou.pendingForm=nil
SS.reply(a,"TransformForced",{form="Homid"})
deliver(publish()); near(scaled[remote],1,"forced form clears interpolation")

-- Legacy clients can cancel by the normal server reply, without progress.
token=begin(a,"Crinos"); clock=clock+0.21; progress(a,token,0.5)
deliver(publish()); clock=clock+0.21; CS.tick()
onServer(); a.data.WTAGarou.pendingForm=nil
SS.reply(a,"RageSync",{})
check(SS.sample(a).mode=="return","normal server cancel reconciles without cosmetic message")
deliver(publish()); clock=clock+1.01; CS.tick(); near(scaled[remote],1,"legacy cancel recovers")
token=begin(a,"Crinos"); clock=clock+0.21; progress(a,token,0.5)
onServer(); a.data.WTAGarou.pendingExpiresAt=math.floor(clock)-1
check(SS.sample(a).mode=="return","reservation timeout recovers")
token=begin(a,"Crinos"); clock=clock+0.21; progress(a,token,0.5)
a.data.WTAGarou.pendingForm=nil
SS.reply(a,"TransformDenied",{})
check(SS.sample(a).mode=="return","denied completion recovers")

-- Mid-channel stream-in, subsequent stream-out and reused online IDs.
token=begin(a,"Crinos"); clock=clock+0.21; progress(a,token,0.5)
local current=publish()
onClient(); CS.reset(); deliver(current)
near(scaled[remote],current.players[1].shift.value,"late observer starts from current sample, not channel start")
cPlayers={owner}; clock=clock+1.01; CS.tick()
check(scaled[remote]==nil,"stream-out clears registry")
cPlayers={owner,remote}; remote.name="different"; clock=clock+1.01; CS.tick()
check(scaled[remote]==nil,"ID reused by another user cannot inherit effect")
remote.name="alice"; clock=clock+1.01; CS.tick()
near(scaled[remote],1,"stale cached channel cannot revive on re-entry")
onServer(); a.dead=true; clock=clock+0.21
deliver(publish()); check(scaled[remote]==nil,"death clears remote registry")
a.dead=false
token=begin(a,"Crinos")
onServer(); sPlayers={b}; clock=clock+0.21; publish()
check(SS.sample(a)==nil,"server removes disconnected actor")
sPlayers={a,b}
token=begin(a,"Crinos"); clock=clock+0.21; progress(a,token,0.5)
deliver(publish()); clock=clock+0.21; CS.tick()
clock=clock+3.1; CS.tick(); clock=clock+1.01; CS.tick()
near(scaled[remote],1,"lost updates cannot leave remote size stuck")
onServer(); check(SS.sample(a).mode=="return","server also retires an abandoned action")
clock=clock+1.01; check(SS.sample(a)==nil,"server stale effect expires")

-- Two active shifters keep independent tokens and a shared publication cap.
local ta=begin(a,"Crinos")
local tb=begin(b,"Glabro")
check(ta~=tb,"simultaneous reservations have distinct tokens")
progress(a,ta,0.5); progress(b,tb,0.5)
local both=publish()
near(both.players[1].shift.value,1.24375,"first actor has Crinos preview")
near(both.players[2].shift.value,1.09,"second actor has Glabro preview")
local numPackets=#packets
clock=clock+0.16
progress(a,ta,0.6); progress(b,tb,0.7); publish()
check(#packets==numPackets,"multiple senders cannot bypass global snapshot rate limit")
clock=clock+0.05; publish()
check(#packets==numPackets+1,"dirty samples coalesce into one snapshot")
SS.receive("WTAGarou","ShiftVisualProgress",a,{token=tb,cancel=true})
check(SS.sample(a).mode=="channel" and SS.sample(b).mode=="channel","another actor's token cannot cancel either shift")
SS.receive("WTAGarou","ShiftVisualProgress",a,{token=ta,cancel=true})
check(SS.sample(a).mode=="return" and SS.sample(b).mode=="channel","cancelling one actor leaves other channel running")
b.data.WTAGarou.isGarou=false
check(SS.sample(b)==nil,"trait removal clears server effect")
b.data.WTAGarou.isGarou=true
-- A very short forced reservation uses the same safe cosmetic path.
clock=clock+1.01
local forced=begin(a,"Crinos")
a.data.WTAGarou.pendingForced=true
SS.receive("WTAGarou","ShiftVisualProgress",a,{token=forced,cancel=true})
check(SS.sample(a).mode=="return" and a.data.WTAGarou.pendingForced
    and a.data.WTAGarou.pendingForm=="Crinos","forced-action visual cancellation never changes its gameplay reservation")

-- Local effect remains direct; only a bounded, normalized progress hint goes out.
onClient()
local localActor=actor(3,"local",true)
local action={shiftVisualToken=999}
S.start(localActor,action,"Homid","Crinos")
local count=#clientPackets
for i=1,20 do S.progress(localActor,action,i/20) end
check(#clientPackets==count,"same-frame progress sends only one sample")
clock=clock+0.21; S.progress(localActor,action,0.5)
check(#clientPackets==count+1 and clientPackets[#clientPackets].args.progress==0.5
    and clientPackets[#clientPackets].args.scale==nil,"sender transmits normalized progress, not model/scale")
near(S.value(localActor,"Homid",1),1.24375,"local confirmed scale path unchanged")
S.cancel(localActor,action); S.cancel(localActor,action)
check(#clientPackets==count+2 and clientPackets[#clientPackets].args.cancel==true,"one terminal cancel packet")
S.start(localActor,{},"Homid","Crinos"); S.progress(localActor,{},1)
check(#clientPackets==count+2,"older server without token creates no new traffic")
server,client=false,false
S.start(localActor,action,"Homid","Crinos"); S.progress(localActor,action,0.5)
check(#clientPackets==count+2,"single player creates no cosmetic network traffic")

-- Exact integration hooks are also guarded, so a refactor cannot silently
-- leave the tested helper disconnected from the actual action/reply paths.
local function read(path) local f=assert(io.open(root..path)); local text=f:read("*a"); f:close(); return text end
check(read("/42/media/lua/server/WTAGarouServer.lua"):find(
    "WTAGarou.ShiftVisualServer.reply(player, cmd, args)",1,true),"real server reply calls lifecycle helper")
check(read("/42/media/lua/client/WTAGarouClient.lua"):find("args.shiftVisualToken",1,true)
    and read("/42/media/lua/client/WTAGarouChannel.lua"):find("o.shiftVisualToken = shiftVisualToken",1,true),
    "server token reaches real timed action")
print("PASS: "..checks.." multiplayer shift-scale synchronization assertions.")
