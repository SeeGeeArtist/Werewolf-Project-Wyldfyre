local root = assert(arg[1], "supply WTAGarou directory")
local checks, messages, reads = 0, {}, 0
local function check(ok, message) checks=checks+1; assert(ok, message) end
local realPrint = print
print = function(text) messages[#messages+1]=text end
local time, callback = 100, nil
getTimestampMs = function() return time*1000 end
Events = {OnTick={Add=function(fn) callback=fn end}}
CharacterStat = {PANIC="panic", STRESS="stress"}
MoodleType = {PANIC="panic", STRESS="stress"}
local panic, panicLevel, stress = 35, 2, 0.1
local stats = {get=function(self, kind)
    reads=reads+1
    assert(kind)
    return kind=="panic" and panic or stress
end, set=function() error("TRACE MUST NOT WRITE STATS") end}
local moodles = {getMoodleLevel=function(self, kind)
    assert(kind)
    return kind=="panic" and panicLevel or 0
end, setMoodleLevel=function() error("TRACE MUST NOT WRITE MOODLES") end}
local md = {WTAGarou={form="Hispo",rage=25}}
local player = {
    getStats=function() return stats end,
    getMoodles=function() return moodles end,
    getModData=function() return md end,
    getBodyDamage=function() return {getPanicIncreaseValue=function() return 7 end} end,
    isDead=function() return false end
}
local currentPlayer=player
getPlayer=function() return currentPlayer end
dofile(root .. "/42/media/lua/client/WTAGarouPanicTrace.lua")
local trace=WTAGarou.PanicTrace
callback()
check(#messages==0 and reads==0,"disabled by default; no player reads")
local s=trace.snapshot(player)
check(s.panic==35 and s.panicLevel==2 and s.stress==0.1 and s.form=="Hispo","modern accessors")
check(s.panicIncrease==7 and s.rage==25,"context included")
check(trace.start(2),"start")
callback()
check(string.find(messages[#messages],"panicLevel=2",1,true),"initial state logged")
local count=#messages
time=time+0.01; callback()
check(#messages==count,"unchanged state not spammed")
panic=0; panicLevel=0; time=time+0.01; callback()
check(#messages==count+1 and string.find(messages[#messages],"panic=0 ",1,true),"brief level drop logged")
md.WTAGarou.form="Crinos"; callback()
check(string.find(messages[#messages],"form=Crinos",1,true),"form change logged")
count=#messages; time=time+1; callback()
check(#messages==count+1,"heartbeat logged")
time=102; callback(); count=#messages; callback()
check(messages[count]=="[WTAGarou][PanicTrace] finished" and #messages==count,"deadline stops")
for _, value in ipairs({"bad",-1,121,0.5,math.huge,0/0}) do
    check(not trace.start(value),"invalid duration rejected")
end
check(trace.start(),"default duration")
trace.start(0); count=#messages; callback()
check(#messages==count,"manual stop")
CharacterStat=nil
MoodleType={Panic="panic", Stress="stress"}
stats.get=nil
stats.getPanic=function() return 12 end
stats.getStress=function() return 0.2 end
s=trace.snapshot(player)
check(s.panic==12 and s.stress==0.2 and s.panicLevel==0,"legacy fallback")
MoodleType={}
local calls=0
local originalLevel=moodles.getMoodleLevel
moodles.getMoodleLevel=function() calls=calls+1; return 0 end
s=trace.snapshot(player)
check(s.panicLevel==nil and calls==0,"missing enums cannot masquerade as level zero")
moodles.getMoodleLevel=originalLevel
player.getStats=function() error("unavailable") end
player.getMoodles=function() error("unavailable") end
s=trace.snapshot(player)
check(s.panic==nil and s.panicLevel==nil,"unavailable is nil, not fabricated zero")
trace.start(3); currentPlayer=nil; callback()
check(messages[#messages]=="[WTAGarou][PanicTrace] finished","player change stops")
currentPlayer=player; trace.start(3)
player.isDead=function() return true end; callback()
check(messages[#messages]=="[WTAGarou][PanicTrace] finished","death stops")
player.isDead=function() return false end
trace.start(120)
for i=1,601 do md.WTAGarou.form=tostring(i); callback() end
check(messages[#messages]=="[WTAGarou][PanicTrace] finished at 600-line safety limit","log cap")
check(md.WTAGarou.rage==25 and panic==0 and stress==0.1,"stats/rage unchanged")
-- Verify the normal chat and console entry points, not just the module.
package.loaded.WTAGarouPanicTrace=true
package.loaded.WTAGarouNet=true
package.loaded.WTAGarouGrant=true
Events.OnAddMessage={Add=function() end}; Events.OnGameStart={Add=function() end}
isClient=function() return false end
dofile(root .. "/42/media/lua/client/WTAGarouDebug.lua")
check(WTAGarou.Debug.handle("panictrace 5")==true,"chat command handled")
check(WTAGarouPanicTrace(0),"console command wired")
local reset=false
WTAGarouResetHUDPosition=function() reset=true end
WTAGarou.Debug.handle("hudreset")
check(reset,"chat HUD reset wired")
realPrint("PASS: "..checks.." panic-trace regression assertions.")
