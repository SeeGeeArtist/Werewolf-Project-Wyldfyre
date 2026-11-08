local root = assert(arg[1])
package.path = root .. "/42/media/lua/shared/?.lua;" .. root .. "/42/media/lua/client/?.lua;"
    .. root .. "/42/media/lua/server/?.lua;" .. package.path
local checks = 0
local function check(ok, why) checks = checks + 1; assert(ok, why) end
local mode, clock = "sp", 100
isClient = function() return mode == "client" end
isServer = function() return mode == "server" end
getDebug = function() return false end
getTimestamp = function() return clock end
Events = setmetatable({}, {__index = function(t, key)
    local event = {handlers = {}}
    event.Add = function(fn) event.handlers[#event.handlers + 1] = fn end
    t[key] = event; return event
end})
CharacterTrait = {FAST_HEALER="fast", HEARTY_APPETITE="hungry", NIGHT_VISION="eyes",
    SLOW_HEALER="slow", LIGHT_EATER="light"}
WTAGarouTraits = {Garou="garou"}
local players = {}
local function actor(n, id, data)
    local p = {num=n, id=id, md=data or {}, traits={}, boosts={}, dead=false, role="user"}
    function p:getModData() return self.md end
    function p:getOnlineID() return self.id end
    function p:getPlayerNum() return self.num end
    function p:isDead() return self.dead end
    function p:isLocalPlayer() return not self.remote end
    function p:getAccessLevel() return self.role end
    function p:hasTrait(t) return self.traits[t] == true end
    function p:getCharacterTraits()
        return {
            get=function(_, t) return self.traits[t] == true end,
            set=function(_, t, value)
                if self.refuse == t and value then return false end
                self.traits[t] = value; return value
            end,
        }
    end
    function p:modifyTraitXPBoost(t, removing)
        if self.throwBoost == t then error("fixture: XP API failure") end
        self.boosts[t] = (self.boosts[t] or 0) + (removing and -1 or 1)
        self.boostCalls = (self.boostCalls or 0) + 1
    end
    function p:Say(text) self.said=text end
    function p:getJoypadBind() return self.joypad and self.num or -1 end
    return p
end
getSpecificPlayer = function(n) return players[n] end
getNumActivePlayers = function() return 2 end
getPlayer = function() return players[0] end
require "WTAGarouDefinitions"
require "WTAGarouState"
require "WTAGarouNet"
require "WTAGarouAccess"
local B = require "WTAGarouTraitBundle"
local S = require "WTAGarouEnrollmentServer"
local N = WTAGarou.Net
local function bundle(p)
    return p:hasTrait("garou") and p:hasTrait("fast") and p:hasTrait("hungry") and p:hasTrait("eyes")
        and not p:hasTrait("slow") and not p:hasTrait("light")
end
local p = actor(0, 11)
p.traits = {slow=true, light=true, weak=true}
check(B.apply(p, false) and bundle(p), "full grant replaces only direct conflicts")
check(p.traits.weak, "unrelated creation exclusions are preserved on a played character")
check(p.boostCalls == 6, "only six membership deltas update XP modifiers")
local ok, changed = B.apply(p, false)
check(ok and not changed and p.boostCalls == 6, "duplicate grants cannot stack modifiers")
check(B.apply(p, true) and not p:hasTrait("garou") and p:hasTrait("eyes"), "remove keeps companions")
local calls = p.boostCalls
B.apply(p, true)
check(p.boostCalls == calls, "repeated remove does not subtract XP twice")
local broken = actor(0, 12)
broken.traits.slow = true
broken.refuse = "eyes"
check(not B.apply(broken, false), "native refusal is not success")
check(broken:hasTrait("slow") and not broken:hasTrait("fast") and not broken:hasTrait("garou"),
    "failed transaction restores membership")
check(broken.boosts.slow == 0 and broken.boosts.fast == 0, "completed boost changes rolled back")
broken.refuse, broken.throwBoost = nil, "hungry"
check(not B.apply(broken, false) and not broken:hasTrait("fast"), "XP failure does not produce Garou")
local eyes = CharacterTrait.NIGHT_VISION
CharacterTrait.NIGHT_VISION = nil
check(not B.apply(p, false) and not p:hasTrait("garou"), "missing registry preflight changes nothing")
CharacterTrait.NIGHT_VISION = eyes

local replies = {}
N.RegisterClientHandler(function(_, cmd, args, owner)
    replies[#replies+1] = {owner=owner, cmd=cmd, args=args}
end)
local function last() return replies[#replies].args end
local human = actor(0, 20)
N.ToServer(human, "RequestWerewolfOffer", {})
check(last().status == "offer" and not human.md.WTAGarou.werewolfOfferDecision,
    "query offers without recording a decision")
N.ToServer(human, "AnswerWerewolfOffer", {accept=false})
check(last().status == "declined" and human.md.WTAGarou.werewolfOfferDecision == "declined",
    "No is persisted per character")
local reloaded = actor(0, 20, human.md)
N.ToServer(reloaded, "RequestWerewolfOffer", {})
check(last().status == "declined", "No survives a fresh character object")
local other = actor(1, 21)
N.ToServer(other, "RequestWerewolfOffer", {})
check(last().status == "offer", "another character gets an independent choice")
N.ToServer(reloaded, "AnswerWerewolfOffer", {accept=true, player=other, trait="strong", xp=999})
check(bundle(reloaded) and not bundle(other), "manual opt-in after No is self-only")
check(last().decision == "accepted" and reloaded.md.WTAGarou.isGarou, "success saved after native grant")
calls = reloaded.boostCalls
N.ToServer(reloaded, "AnswerWerewolfOffer", {accept=true})
N.ToServer(reloaded, "RequestWerewolfOffer", {})
check(reloaded.boostCalls == calls, "answer retry and reconnect query are idempotent")
N.ToServer(reloaded, "AnswerWerewolfOffer", {accept=false})
check(bundle(reloaded) and last().status == "existing", "stale No cannot reverse acceptance")
local existing = actor(0, 22)
existing.traits.garou = true
N.ToServer(existing, "RequestWerewolfOffer", {})
check(last().status == "existing" and existing.boostCalls == nil, "creation Garou gets no prompt or edits")
local malformed = actor(0, 23)
N.ToServer(malformed, "AnswerWerewolfOffer", {accept="yes"})
check(last().status == "error" and not bundle(malformed), "strict boolean answer")
broken.throwBoost = nil; broken.refuse = "eyes"
N.ToServer(broken, "AnswerWerewolfOffer", {accept=true})
check(last().status == "error" and not broken.md.WTAGarou.werewolfOfferDecision
    and not broken.md.WTAGarou.isGarou, "failed native grant never saves fake success")
local count = #replies
malformed.dead = true
N.ToServer(malformed, "AnswerWerewolfOffer", {accept=true})
check(#replies == count and not bundle(malformed), "dead character cannot opt in")

mode = "server"
local packets = {}
sendServerCommand = function(owner, module, command, args)
    packets[#packets+1] = {owner=owner, module=module, command=command, args=args}
end
local syncs = 0
SyncXp = function(owner) syncs=syncs+1 end
SandboxVars = {WTAGarou={AllowWerewolfOptIn=false}}
S.handle("WTAGarou", "RequestWerewolfOffer", other, {})
check(packets[#packets].args.status == "disabled", "host option suppresses automatic prompt")
S.handle("WTAGarou", "AnswerWerewolfOffer", other, {accept=true})
check(not bundle(other) and packets[#packets].args.status == "disabled", "host option rejects direct request")
check(S.grant(other, false) and bundle(other) and syncs == 0,
    "privileged helper grants with opt-in disabled, without relying on client-only SyncXp")
check(packets[#packets].args._wtaRecipientID == 21, "network reply stamped for actual owner")

-- Load actual DebugTrait owning handler without initializing unrelated imports.
local realRequire = require
require = function() end
dofile(root .. "/42/media/lua/server/WTAGarouServer.lua")
require = realRequire
local user = actor(0, 25)
WTAGarou.HandleClientCommand("WTAGarou", "DebugTrait", user, {})
check(not bundle(user), "ordinary MP role still denied DebugTrait")
user.role = "admin"
WTAGarou.HandleClientCommand("WTAGarou", "DebugTrait", user, {})
check(bundle(user), "actual admin DebugTrait uses full bundle")
SandboxVars.WTAGarou.AllowWerewolfOptIn = true
local ordinary = actor(0, 26)
S.handle("WTAGarou", "AnswerWerewolfOffer", ordinary, {accept=true})
check(bundle(ordinary), "ordinary MP user may self-opt-in without admin privileges")

-- Client UI and real recipient router. Modal fixture matches vanilla callback
-- order and its numeric player index (not an ambient getPlayer()).
local modals = {}
ISModalDialog = {}
function ISModalDialog.CalcSize(w, h) return w, h end
function ISModalDialog:new(x,y,w,h,text,yesno,target,onclick,index)
    local m = {x=x,y=y,width=w,height=h,text=text,target=target,onclick=onclick,player=index}
    function m:initialise() end
    function m:addToUIManager() self.visible=true end
    function m:setAlwaysOnTop(v) self.top=v end
    function m:destroy() self.visible=false end
    function m:click(answer) self:destroy(); self.onclick(self.target, {internal=answer}) end
    modals[#modals+1]=m; return m
end
package.loaded["ISUI/ISModalDialog"] = true
getPlayerScreenLeft = function(n) return n*640 end
getPlayerScreenTop = function() return 0 end
getPlayerScreenWidth = function() return 640 end
getPlayerScreenHeight = function() return 720 end
JoypadState = {players={{focus="old0"},{focus="old1"}}}
local focused
setJoypadFocus = function(n, modal) focused={n=n, modal=modal} end
local info = {charScreen={}}
getPlayerInfoPanel = function() return info end
package.loaded.WTAGarouHowl = true
package.loaded.WTAGarouTrueForms = true
require "WTAGarouClient"
WTAGarou.Halo = function(owner, text) owner.notice=text; return true end
local C = WTAGarou.Enrollment
local a, b = actor(0, 31), actor(1, 84)
players[0], players[1] = a, b
b.joypad = true
mode = "sp"
C.update(b)
check(#modals == 1 and modals[1].target == b and modals[1].x >= 640, "SP offer placed in owner's viewport")
check(focused.n == 1 and focused.modal.prevFocus == "old1", "controller focus uses owner's prior focus")
C.update(b)
check(#modals == 1, "open dialog cannot duplicate")
modals[1]:click("YES")
check(bundle(b) and not bundle(a) and not modals[1].visible, "SP Yes grants only chosen local actor")
check(info.charScreen.refreshNeeded and b.notice:find("Cat's Eyes",1,true), "trait screen refresh and confirmed feedback")
C.receive(b, {status="offer"})
check(#modals == 1, "late offer reply cannot reopen an answered dialog")
C.update(a)
check(#modals == 2, "second human gets its own offer")
modals[2]:click("NO")
check(a.md.WTAGarou.werewolfOfferDecision == "declined" and not bundle(a), "UI No grants nothing")
clock=clock+10
C.update(a)
check(#modals == 2, "answered prompt not repeated this session")

mode = "client"
local requests = {}
sendClientCommand = function(owner, module, command, args)
    requests[#requests+1]={owner=owner, command=command, args=args}
end
C.answer(a, true)
check(not bundle(a) and requests[#requests].command == "AnswerWerewolfOffer", "MP client request cannot grant locally")
clock=clock+6; C.update(a)
check(#requests == 2 and requests[2].args.accept == true, "lost answer retried")
local route = Events.OnServerCommand.handlers[#Events.OnServerCommand.handlers]
local accepted = {status="accepted", decision="accepted", _wtaRecipientID=31}
route("WTAGarou", "WerewolfEnrollment", accepted)
check(bundle(a) and a.md.WTAGarou.werewolfOfferDecision == "accepted", "server acknowledgment mirrors owner traits")
calls = a.boostCalls
route("WTAGarou", "WerewolfEnrollment", accepted)
check(a.boostCalls == calls, "duplicate server receipt does not stack XP modifiers")
local c = actor(0, 32)
players[0]=c
route("WTAGarou", "WerewolfEnrollment", accepted)
check(not bundle(c), "stale recipient ID cannot affect replacement character")
C.update(c)
check(requests[#requests].command == "RequestWerewolfOffer", "new session waits for server status")
local remote = actor(2, 99); remote.remote=true
count=#requests
C.update(remote)
check(#requests == count, "remote actor never receives local prompt")
route("WTAGarou", "WerewolfEnrollment", {status="offer", _wtaRecipientID=32})
local modal=modals[#modals]
c.dead=true; C.update(c)
check(not modal.visible and not bundle(c), "death dismisses prompt without granting")
require "WTAGarouDebug"
c.dead=false
WTAGarou.Debug.handle("trait")
check(requests[#requests].command == "AnswerWerewolfOffer" and not bundle(c),
    "/garou trait ordinary-user route requests, never claims local success")
c.role="admin"
WTAGarou.Debug.handle("trait")
check(requests[#requests].command == "DebugTrait", "admin command retains privileged override")
WTAGarou.Debug.handle("untrait")
check(requests[#requests].command == "DebugTrait" and requests[#requests].args.remove == true,
    "untrait stays on privileged route")
mode="sp"
local fresh=actor(0, 40)
count=#modals
for _,handler in ipairs(Events.OnNewGame.handlers) do handler(fresh) end
check(not fresh.md.WTAGarou, "new-character event queues, does not transmit during creation")
C.update(fresh)
check(#modals == count and fresh.md.WTAGarou.werewolfOfferDecision == "declined" and not bundle(fresh),
    "fresh human keeps creation choice, with no retrofit prompt")
print(string.format("PASS: %d enrollment/bundle/server/UI assertions.", checks))
