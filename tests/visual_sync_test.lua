local root=assert(arg[1])
package.path=root.."/42/media/lua/shared/?.lua;"..root.."/42/media/lua/client/?.lua;"..package.path
require "WTAGarouDefinitions"
require "WTAGarouState"
local n=0
local function check(ok,why) n=n+1; assert(ok,why) end
local server,client,now=true,false,100
isServer=function() return server end
isClient=function() return client end
getTimestamp=function() return now end
Events={}
for _,name in ipairs({"OnTick","OnServerCommand","OnGameStart","OnCreatePlayer","OnPlayerUpdate","OnPlayerDeath"}) do
    Events[name]={Add=function() end}
end
local function person(id,name,localPlayer)
    local p={id=id,name=name,localPlayer=localPlayer,data={WTAGarou={isGarou=true,form="Lupus"}}}
    function p:getOnlineID() return self.id end
    function p:getUsername() return self.name end
    function p:getModData() return self.data end
    function p:isLocalPlayer() return self.localPlayer end
    function p:isDead() return self.dead==true end
    function p:getVehicle() return self.vehicle end
    function p:isFemale() return false end
    function p:getPrimaryHandItem() return self.primary end
    function p:getSecondaryHandItem() return self.secondary end
    function p:setVariable(key,value)
        self.variables=self.variables or {}; self.variables[key]=value
    end
    return p
end
local owner=person(0,"owner",true)
local a,b=person(1,"alice",false),person(2,"bob",false)
owner.data.WTAGarou.form="Homid"
b.data.WTAGarou.isGarou=false; b.data.WTAGarou.form="Homid"
local online={owner,a,b}
getPlayer=function() return owner end
getOnlinePlayers=function() return {
    size=function() return #online end,
    get=function(_,i) return online[i+1] end
} end
require "WTAGarouNet"
local packets={}
sendServerCommand=function(module,command,args)
    check(module=="WTAGarou" and command=="VisualSnapshot","dedicated visual packet")
    packets[#packets+1]=args
end
dofile(root.."/42/media/lua/server/WTAGarouVisualSyncServer.lua")
local publish=WTAGarou.VisualSyncServer.tick
publish()
check(#packets==1 and packets[1].players[2].form=="Lupus","snapshot reads server form")
check(packets[1].players[2].rage==nil and packets[1].players[2].model==nil,"only minimal visual state replicated")
for i=1,20 do publish() end
check(#packets==1,"server poll throttled")
now=now+1; publish()
check(#packets==1,"unchanged state not spammed")
now=now+10; publish()
check(#packets==2,"heartbeat serves late joiners")
local first=packets[#packets]

local registered,scaled={},{}
WTAGarouJava={
    setScale=function(p,v) scaled[p]=v; return true end,
    setWolf=function(p,on) registered[p]=on; return on and "wolf" or "human" end,
    clear=function(p) registered[p]=nil; scaled[p]=nil end,
    status=function() return "test" end,
}
require "WTAGarouVisual"
require "WTAGarouVisualSync"
local sync=WTAGarou.VisualSync
server,client=false,true
-- Remote mod data is intentionally stale and trait-less. The observer must
-- use the validated server snapshot WITHOUT editing that gameplay data.
a.data.WTAGarou.isGarou=false; a.data.WTAGarou.form="Homid"
sync.receive("WTAGarou","VisualSnapshot",first); sync.tick()
check(registered[a] and scaled[a]==1.15,"remote Lupus uses same Java path (1.15 since 0.4.22)")
check(a.data.WTAGarou.form=="Homid" and not a.data.WTAGarou.isGarou,"observer never rewrites remote gameplay state")
check(registered[owner]==nil and owner.data.WTAGarou.form=="Homid","local player excluded from observer override")
check(not registered[b],"ordinary observer stays human")
WTAGarou.Visual.refresh(a,false)
check(registered[a],"normal refresh retains authoritative remote visuals despite missing local trait")

local function packet(seq,form,garou,alive,name)
    return {sequence=seq,players={{id=1,username=name or "alice",form=form,garou=garou,alive=alive}}}
end
sync.receive("WTAGarou","VisualSnapshot",packet(3,"Hispo",true,true)); sync.tick()
check(registered[a] and scaled[a]==1.55,"remote Hispo preserves the 0.4.22 size")
sync.receive("WTAGarou","VisualSnapshot",packet(2,"Homid",true,true)); now=now+1; sync.tick()
check(registered[a] and scaled[a]==1.55,"old packets cannot revert newer forms")
sync.receive("WTAGarou","VisualSnapshot",packet(100,"INVALID",true,true)); sync.tick()
check(registered[a],"malformed snapshot ignored atomically")
sync.receive("WTAGarou","VisualSnapshot",packet(4,"Homid",true,true)); sync.tick()
check(not registered[a] and scaled[a]==1,"return to human replicated")
sync.receive("WTAGarou","VisualSnapshot",packet(5,"Lupus",true,true)); sync.tick()
check(registered[a],"wolf reentry")
a.vehicle={}; now=now+1; sync.tick()
check(not registered[a],"remote vehicle suspends wolf")
a.vehicle=nil; now=now+1; sync.tick()
check(registered[a],"remote vehicle exit resumes wolf")
sync.receive("WTAGarou","VisualSnapshot",packet(6,"Lupus",true,false)); sync.tick()
check(not registered[a] and scaled[a]==nil,"death snapshot clears remote registry")
sync.receive("WTAGarou","VisualSnapshot",packet(7,"Lupus",true,true)); sync.tick()
sync.receive("WTAGarou","VisualSnapshot",packet(8,"Homid",false,true)); sync.tick()
check(not registered[a],"trait loss restores remote human")
sync.receive("WTAGarou","VisualSnapshot",packet(9,"Lupus",true,true)); sync.tick()
online={owner,b}; now=now+1; sync.tick()
check(registered[a]==nil,"stream-out/disconnect clears old object")
local replacement=person(1,"alice",false)
replacement.data.WTAGarou.isGarou=false
online={owner,replacement,b}; now=now+1; sync.tick()
check(registered[replacement],"stream-in resolves cached snapshot onto new object")
replacement.name="another-user"; now=now+1; sync.tick()
check(registered[replacement]==nil,"online ID reuse never applies old owner's wolf")
replacement.name="alice"; now=now+1; sync.tick()
sync.receive("WTAGarou","VisualSnapshot",{sequence=10,players={}}); sync.tick()
check(registered[replacement]==nil,"full snapshot removes vanished peers")
sync.receive("WTAGarou","VisualSnapshot",packet(11,"Lupus",true,true)); sync.tick()
sync.reset()
check(registered[replacement]==nil,"session reset clears old registrations")
-- Remote Crinos animation eligibility follows server snapshot, not stale
-- modData, and gets cleared on trait/death/stream-out via Visual.clear.
sync.receive("WTAGarou","VisualSnapshot",packet(1,"Crinos",true,true)); sync.tick()
check(replacement.variables.WTAGarouCrinosUnarmed==true,
    "observer enables Crinos swing from validated snapshot")
check(replacement.data.WTAGarou.form=="Lupus",
    "snapshot animation eligibility never rewrites remote gameplay form")
replacement.primary={}; now=now+1; sync.tick()
check(replacement.variables.WTAGarouCrinosUnarmed==false,"observer equipment disables override")
replacement.primary=nil; now=now+1; sync.tick()
check(replacement.variables.WTAGarouCrinosUnarmed==true,"observer unequip re-enables override")
sync.receive("WTAGarou","VisualSnapshot",packet(2,"Crinos",true,false)); sync.tick()
check(replacement.variables.WTAGarouCrinosUnarmed==false,"remote death clears override")
sync.reset()

-- Client and solo cannot originate server snapshots.
local count=#packets
publish(); check(#packets==count,"client cannot publish")
client=false; publish(); check(#packets==count,"solo skips replication")
sync.receive("WTAGarou","VisualSnapshot",packet(12,"Lupus",true,true)); sync.tick()
check(registered[replacement]==nil,"solo ignores network visual messages")
owner.data.WTAGarou.form="Lupus"; WTAGarou.Visual.refresh(owner,true)
check(registered[owner],"solo still uses original local path")

-- State changes and removals trigger a fresh server snapshot immediately
-- at the next one-second poll, not only the heartbeat.
server=true
now=now+1; publish(); count=#packets
replacement.data.WTAGarou.isGarou=true; replacement.data.WTAGarou.form="Hispo"
now=now+1; publish()
check(#packets==count+1 and packets[#packets].players[2].form=="Hispo","server publishes authoritative form change")
replacement.data.WTAGarou.wolfCoat="blonde"
now=now+1; publish()
check(#packets==count+2 and packets[#packets].players[2].wolfCoat=="blonde","coat-only server change published")
local coats={}
WTAGarouJava.setWolfCoat=function(p,key) coats[p]=key end
server,client=false,true
sync.receive("WTAGarou","VisualSnapshot",packets[#packets]); sync.tick()
check(coats[replacement]=="blonde","observer applies peer's selected coat")
local invalid=packet(999,"Hispo",true,true); invalid.players[1].wolfCoat="bad/path"
sync.receive("WTAGarou","VisualSnapshot",invalid); sync.tick()
check(coats[replacement]=="blonde","invalid cosmetic rejected without consuming sequence")
server,client=true,false
local beforeGear=#packets
replacement.data.WTAGarou.wolfGearVariant="Camo"
now=now+1; publish()
check(#packets==beforeGear+1 and packets[#packets].players[2].wolfGearVariant=="Camo",
    "gear-only server change published before heartbeat")
local observedGear
local setRemote=WTAGarou.Visual.setRemoteState
WTAGarou.Visual.setRemoteState=function(p,state,changed)
    if p==replacement and state then observedGear={key=state.wolfGearVariant,changed=changed} end
    setRemote(p,state,changed)
end
server,client=false,true
-- Stale peer mod data must not replace the authoritative cosmetic snapshot.
replacement.data.WTAGarou.wolfGearVariant="Black"
sync.receive("WTAGarou","VisualSnapshot",packets[#packets]); sync.tick()
check(observedGear.key=="Camo" and observedGear.changed,"observer gear-only update forces visual refresh")
check(replacement.data.WTAGarou.wolfGearVariant=="Black","observer never edits peer saved mod data")
local badGear=packet(1000,"Hispo",true,true); badGear.players[1].wolfGearVariant="../../bad"
sync.receive("WTAGarou","VisualSnapshot",badGear); now=now+1; sync.tick()
check(observedGear.key=="Camo","malformed gear rejected without replacing valid snapshot")
local oldPeer=packet(packets[#packets].sequence+1,"Hispo",true,true)
sync.receive("WTAGarou","VisualSnapshot",oldPeer); sync.tick()
check(observedGear.key=="Black","absent gear field defaults Black for old snapshots")
-- 0.4.67: Crinos tail flag rides the same rows (server-owned, strict boolean, default off).
server,client=true,false
local beforeTail=#packets
replacement.data.WTAGarou.crinosTail=true
now=now+1; publish()
-- (the fabricated oldPeer packet above consumed this sequence number on the
-- client; a heartbeat republish carries the next one)
now=now+11; publish()
check(#packets==beforeTail+2 and packets[#packets].players[2].crinosTail==true
    and packets[#packets].players[1].crinosTail==false,"tail-only server change published; others report false")
local observedTail
WTAGarou.Visual.setRemoteState=function(p,state,changed)
    if p==replacement and state then observedTail={on=state.crinosTail,changed=changed} end
    setRemote(p,state,changed)
end
server,client=false,true
sync.receive("WTAGarou","VisualSnapshot",packets[#packets]); sync.tick()
check(observedTail.on==true and observedTail.changed,"observer tail-only update forces visual refresh")
local badTail=packet(packets[#packets].sequence+1,"Hispo",true,true); badTail.players[1].crinosTail="yes"
sync.receive("WTAGarou","VisualSnapshot",badTail); now=now+1; sync.tick()
check(observedTail.on==true,"non-boolean tail rejected without replacing valid snapshot")
local noTail=packet(packets[#packets].sequence+2,"Hispo",true,true)
sync.receive("WTAGarou","VisualSnapshot",noTail); now=now+1; sync.tick()
check(observedTail.on==false,"absent tail field defaults off for old snapshots")
server,client=true,false
online={owner}; now=now+1; publish()
check(#packets[#packets].players==1,"server removal appears in complete snapshot")
print("PASS: "..n.." solo/multiplayer visual synchronization assertions.")
