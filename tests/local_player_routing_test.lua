local root=assert(arg[1])
package.path=root.."/42/media/lua/shared/?.lua;"..root.."/42/media/lua/client/?.lua;"..package.path
local checks=0
local function check(ok,why) checks=checks+1; assert(ok,why) end
local client,server=false,false
isClient=function() return client end
isServer=function() return server end
Events={OnServerCommand={Add=function(fn) Events.handler=fn end}}
getTimestamp=function() return 10 end
local players={}
local function actor(n,id)
    local p={num=n,id=id,data={WTAGarou={isGarou=true,form="Homid",rage=50,infamy=0}}}
    function p:getModData() return self.data end
    function p:getPlayerNum() return self.num end
    function p:getOnlineID() return self.id end
    function p:isDead() return false end
    function p:isLocalPlayer() return true end
    players[n]=p; return p
end
local a,b=actor(0,31),actor(1,84)
local ambient=b
getPlayer=function() return ambient end
getSpecificPlayer=function(n) return players[n] end
getNumActivePlayers=function() return 2 end
require "WTAGarouDefinitions"
require "WTAGarouState"
require "WTAGarouNet"
WTAGarou.HasGarouTrait=function() return true end
local N=WTAGarou.Net
local panels={}
for _,p in ipairs({a,b}) do
    local h={refreshes=0}
    function h:refresh() self.refreshes=self.refreshes+1 end
    function h:flashDenial(why) self.denied=why end
    function h:clearCrinosCountdown() self.countdown=nil end
    function h:startCrinosCountdown(s) self.countdown=s end
    function h:clearChannelling() self.cleared=true end
    panels[p]=h
end
WTAGarou.HUD={forPlayer=function(p) return panels[p] end,instance=panels[a]}
WTAGarou.Channel={
    startChannel=function(p,form) p.channel=form end,
    startHowl=function(p) p.howl=true end,
    abort=function(p) p.aborted=true end,
}
local broadcasts=0
WTAGarou.Howl={}
WTAGarou.Howl.onStarted=function(args) broadcasts=broadcasts+1 end
WTAGarou.Howl.onStopped=function(args) broadcasts=broadcasts+1 end
package.loaded.WTAGarouHowl=true
package.loaded.WTAGarouTrueForms=true
require "WTAGarouClient"
N.ToClient(a,"RageSync",{rage=21,form="Glabro"})
N.ToClient(b,"RageSync",{rage=73,form="Hispo"})
check(a.data.WTAGarou.rage==21 and a.data.WTAGarou.form=="Glabro","direct reply for first player despite ambient second")
check(b.data.WTAGarou.rage==73 and b.data.WTAGarou.form=="Hispo","direct reply for second player")
check(panels[a].refreshes==1 and panels[b].refreshes==1,"each response refreshes its own panel")
local coatRecipient
WTAGarou.WolfCoat={receive=function(args,p) coatRecipient=p end}
N.ToClient(a,"WolfCoatSelected",{coat="black"})
check(coatRecipient==a,"coat confirmation receives direct local owner")
N.ToClient(b,"WolfCoatSelected",{coat="white"})
check(coatRecipient==b,"second coat confirmation does not resolve through getPlayer")
N.ToClient(a,"TransformAccepted",{form="Lupus",seconds=4})
N.ToClient(b,"TransformAccepted",{form="Homid",seconds=5})
check(a.channel=="Lupus" and b.channel=="Homid","two channel acknowledgements remain distinct")
N.ToClient(b,"CrinosCountdown",{seconds=3})
check(panels[b].countdown==3 and panels[a].countdown==nil,"countdown recipient independent")
N.ToClient(a,"TransformDenied",{reason="cooldown"})
check(panels[a].denied=="cooldown" and panels[b].denied==nil,"denial stays with requester")
N.ToClient(b,"TransformForced",{form="Homid"})
check(b.aborted and not a.aborted and b.data.WTAGarou.form=="Homid","forced shift touches only target queue/state")
local requestOwner
N.RegisterServerHandler(function(module,command,p,args)
    requestOwner=p
    if command=="TransformRequest" then N.ToClient(p,"TransformAccepted",{form=args.form}) end
end)
WTAGarou.RequestTransform("Crinos",a)
check(requestOwner==a and a.channel=="Crinos" and b.channel=="Homid","local request/reply round trip keeps owner")
ambient=a
WTAGarou.RequestTransform("Lupus",b)
check(requestOwner==b and b.channel=="Lupus","second request/reply ignores global primary")
N.Broadcast("HowlStarted",{ownerID=84}); N.Broadcast("HowlStopped",{ownerID=84})
check(broadcasts==2,"one broadcast processing per connection, not per local HUD")

-- Online MP: server stamps its actual player, never trusting a destination
-- in args; receiving connection resolves against its LOCAL online IDs.
local packet
sendServerCommand=function(p,module,command,args) packet={p=p,module=module,command=command,args=args} end
client=false; server=true
local original={rage=67,form="Crinos",_wtaRecipientID=31}
N.ToClient(b,"RageSync",original)
check(packet.p==b and packet.args._wtaRecipientID==84,"server-owned destination overwrites forged ID")
check(original._wtaRecipientID==31 and packet.args~=original,"routing never mutates reusable input")
server=false; client=true
Events.handler(packet.module,packet.command,packet.args)
check(b.data.WTAGarou.rage==67 and a.data.WTAGarou.rage==21,"online reply updates only second local recipient")
for _,bad in ipairs({-1,777,"bad"}) do
    Events.handler("WTAGarou","RageSync",{rage=99,_wtaRecipientID=bad})
end
check(a.data.WTAGarou.rage==21 and b.data.WTAGarou.rage==67,"invalid/remote/stale IDs cannot fall back to player zero")
Events.handler("WTAGarou","RageSync",{rage=88})
check(a.data.WTAGarou.rage==21 and b.data.WTAGarou.rage==67,"untagged split-screen reply rejected as ambiguous")
players[1]=nil
Events.handler("WTAGarou","RageSync",{rage=44})
check(a.data.WTAGarou.rage==44,"legacy single-local-client replies remain compatible")
players[1]=b
local sent
sendClientCommand=function(p,module,command,args) sent={p=p,module=module,command=command,args=args} end
WTAGarou.RequestTransform("Hispo",b)
check(sent.p==b and sent.command=="TransformRequest" and sent.args.form=="Hispo",
    "online input still goes through native sendClientCommand(player), no local state mutation")
Events.handler("WTAGarou","HowlStarted",{ownerID=999})
check(broadcasts==3,"remote howl broadcast unaffected by recipient routing")
print("PASS: "..checks.." local/online multi-player recipient-routing assertions.")
