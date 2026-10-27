local root=assert(arg[1])
package.path=root.."/42/media/lua/shared/?.lua;"..root.."/42/media/lua/client/?.lua;"..package.path
Events={}
for _,name in ipairs({"OnCreatePlayer","OnPlayerUpdate","OnPlayerDeath"}) do Events[name]={Add=function() end} end
local now=100
getTimestamp=function() return now end
require "WTAGarouVisual"
local calls={}
local result="crinos"
WTAGarouJava={setCrinosCosmetics=function(p,on,body,head)
    calls[#calls+1]={p,on,body,head}; return result
end}
local V=WTAGarou.Visual
local p={}
local checks=0
local function check(b,msg) checks=checks+1; assert(b,msg) end
V.refreshCrinos(p,"Crinos","blonde",false)
check(calls[1][2] and calls[1][3]=="WTAGarou_CrinosBody_Blonde","blonde skin selected")
check(calls[1][4]=="WTAGarou_Wolf_Blonde","head uses wolf UV atlas")
V.refreshCrinos(p,"Crinos","blonde",false)
check(#calls==1,"no per-frame rebuild")
V.refreshCrinos(p,"Lupus","blonde",false)
check(#calls==2 and not calls[2][2],"wolf disables Crinos cosmetics")
WTAGarou.WolfCoats.new={path="media/textures/Body/WTAGarou_Wolf_New.png"}
V.refreshCrinos(p,"Crinos","new",false)
check(calls[3][3]=="WTAGarou_CrinosBody_Timber","new coat without fur mapping falls back explicitly")
check(calls[3][4]=="WTAGarou_Wolf_Timber","head fallback uses shipped wolf Timber, never deleted head PNG")
WTAGarou.EnableCrinosCosmetics=false
V.refreshCrinos(p,"Crinos","new",false)
check(not calls[4][2],"kill switch")
WTAGarou.EnableCrinosCosmetics=true
result="pending"
V.refreshCrinos(p,"Crinos","blonde",false)
V.refreshCrinos(p,"Crinos","blonde",false)
check(#calls==5,"pending throttled")
-- 0.4.59: pending is re-asked every PENDING_RETRY_S (0.1 s), not every second
now=now+0.05; V.refreshCrinos(p,"Crinos","blonde",false)
check(#calls==5,"50 ms later still throttled")
now=now+0.06; V.refreshCrinos(p,"Crinos","blonde",false)
check(#calls==6,"pending retries after a tenth of a second")
local start=now
while now-start<70 do now=now+0.1; V.refreshCrinos(p,"Crinos","blonde",false) end
local asked=#calls
check(asked>=590 and asked<=606,"pending asked about ten times a second, then gave up after 60 s ("..asked..")")
now=now+5; V.refreshCrinos(p,"Crinos","blonde",false)
check(#calls==asked,"no more asks after the give-up window")
calls={}; for i=1,64 do calls[i]={} end -- the forced-reload check below counts from 64
result="crinos"; V.refreshCrinos(p,"Crinos","blonde",true)
check(#calls==65,"forced reload can retry")
-- 0.4.59: asset preload at player creation, polled until ready
local pre={} ; local preResult="pending"
WTAGarouJava.preloadForms=function(body,head,path) pre[#pre+1]={body,head,path}; return preResult end
check(V.preload(p,"blonde")=="pending" and #pre==1,"preload asks Java once")
check(pre[1][1]=="WTAGarou_CrinosBody_Blonde" and pre[1][2]=="WTAGarou_Wolf_Blonde" and pre[1][3]=="media/textures/Body/WTAGarou_Wolf_Blonde.png","preload names the coat's body, head and wolf texture")
V.preload(p,"blonde"); check(#pre==1,"preload throttled inside the retry window")
now=now+0.11; preResult="ready"; check(V.preload(p,"blonde")=="ready" and #pre==2,"preload polls again and sees ready")
now=now+5; check(V.preload(p,"blonde")=="ready" and #pre==2,"ready is never re-asked")
check(V.preload(p,"brown")=="ready" and #pre==3 and pre[3][1]=="WTAGarou_CrinosBody_Brown","a coat change warms the new textures")
WTAGarouJava.preloadForms=nil
check(V.preload(p,"brown")==nil,"older Java without preloadForms: no-op")
for _,female in ipairs({false,true}) do
    local character={isFemale=function() return female end}
    for _,key in ipairs(WTAGarou.WolfCoatKeys()) do
        if key~="new" then
            V.refreshCrinos(character,"Crinos",key,true)
            local c=calls[#calls]
            local entry=WTAGarou.WolfCoats[key]
            check(c[3]==entry.crinosBody and c[4]==entry.crinosHead,
                "shared body / wolf head mapping for "..key.." female="..tostring(female))
            check(not c[3]:find("_F_",1,true),"no removed female texture dependency")
        end
    end
end
-- 0.4.67: Java with setCrinosCosmeticsParts gets legs for every Crinos and
-- the tail only when the character's flag is on; older Java keeps the
-- four-argument call.
local partCalls={}
WTAGarouJava.setCrinosCosmeticsParts=function(pl,on,body,head,legs,tail)
    partCalls[#partCalls+1]={pl,on,body,head,legs,tail}; return "crinos"
end
local md={WTAGarou={}}
local q={getModData=function() return md end,isFemale=function() return false end}
local beforeParts=#calls
V.refreshCrinos(q,"Crinos","brown",true)
check(#calls==beforeParts and #partCalls==1,"parts entry point preferred when present")
check(partCalls[1][5]=="WTAGarou_CrinosBody_Brown" and partCalls[1][6]=="","legs always (body atlas texture), tail off by default")
md.WTAGarou.crinosTail=true
V.refreshCrinos(q,"Crinos","brown",false)
check(#partCalls==2 and partCalls[2][6]=="WTAGarou_Wolf_Brown","tail flag flips the key and resends with the tail")
V.refreshCrinos(q,"Crinos","brown",false)
check(#partCalls==2,"no per-frame rebuild with parts either")
V.refreshCrinos(q,"Crinos","new",false)
check(partCalls[3][5]=="WTAGarou_CrinosBody_Timber" and partCalls[3][6]=="WTAGarou_Wolf_Timber","coats without part mappings fall back to Timber parts")
local legs,tail=V.coatParts("black",false)
check(legs=="WTAGarou_CrinosBody_Black" and tail=="","coatParts: tail off is an empty string, never nil")
-- remote players take the tail from the synced snapshot row, not their mod data
local src=io.open(root.."/42/media/lua/client/WTAGarouVisual.lua"):read("*a")
check(src:find("if remote then return WTAGarou.CrinosTailOn(remote.crinosTail) end",1,true),"remote tail is read from the snapshot state first")
-- preload warms both parts (tail too, so a later toggle is instant)
local prePart={}
WTAGarouJava.preloadForms=function() return "ready" end
WTAGarouJava.preloadCrinosParts=function(l,t,f) prePart[#prePart+1]={l,t,f}; return "ready" end
local fem={getModData=function() return {} end,isFemale=function() return true end}
check(V.preload(fem,"black")=="ready" and #prePart==1 and prePart[1][1]=="WTAGarou_CrinosBody_Black"
    and prePart[1][2]=="WTAGarou_Wolf_Black" and prePart[1][3]==true,"preload warms legs and tail for the character's sex")
WTAGarouJava.preloadCrinosParts=function() return "pending" end
check(V.preload(fem,"white")=="pending","parts still loading keep the preload pending")
WTAGarouJava.setCrinosCosmeticsParts=nil
WTAGarouJava.preloadCrinosParts=nil
WTAGarouJava.preloadForms=nil
local beforeMissingJava=#calls
WTAGarouJava=nil
V.refreshCrinos(p,"Crinos","blonde",true)
check(#calls==beforeMissingJava,"old/missing Java graceful")
print("PASS: "..checks.." Crinos cosmetics Lua routing/retry assertions.")
