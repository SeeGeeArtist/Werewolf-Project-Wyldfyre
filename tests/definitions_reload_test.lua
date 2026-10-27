-- 0.4.44: "/garou reload" re-runs WTAGarouDefinitions.lua. Tables other
-- modules add functions to must survive (Oct 6 console: every howl was
-- silent, "Howl feedback module unavailable", after reloads rebuilt
-- WTAGarou.Howl). Also the halved rage from damage dealt.
local root=assert(arg[1])
package.path=root.."/42/media/lua/shared/?.lua;"..package.path
local n=0
local function check(ok,why) n=n+1; assert(ok,why) end
isServer=function() return false end
isClient=function() return false end
WTAGarou={}
local function loadDefinitions()
    package.loaded["WTAGarouDefinitions"]=nil
    require "WTAGarouDefinitions"
end
loadDefinitions()
-- Modules attach functions after the first load (as WTAGarouHowl.lua does).
local howl=WTAGarou.Howl; howl.onStarted=function() return "sound" end
WTAGarou.Silver.announce=function() return "announce" end
WTAGarou.VehicleShift.forceExit=function() return "exit" end
WTAGarou.Howl.RAGE_PER_TICK=12 -- a stale tuning value the reload must refresh
loadDefinitions()
check(WTAGarou.Howl==howl,"Howl table is updated in place, not replaced")
check(WTAGarou.Howl.onStarted and WTAGarou.Howl.onStarted()=="sound","Howl feedback functions survive a reload")
check(WTAGarou.Howl.RAGE_PER_TICK==1.0,"reload still refreshes tuning values")
-- 0.4.45: a reload must not forget the Rich helper or the auspice table.
check(WTAGarou.Rich and WTAGarou.Rich.kw and #WTAGarou.Auspices==5 and WTAGarou.Rage.BASELINE_DEFAULT==50,"0.4.45 tables present after reload")
check(WTAGarou.Silver.announce and WTAGarou.Silver.announce()=="announce","Silver server functions survive a reload")
check(WTAGarou.VehicleShift.forceExit and WTAGarou.VehicleShift.forceExit()=="exit","VehicleShift functions survive a reload")
check(WTAGarou.VehicleShift.damageFor and WTAGarou.VehicleShift.damageFor("Crinos")==38,"VehicleShift keeps its own helpers and tuning (damage 38 untouched)")
check(WTAGarou.Rage.ON_DAMAGE_DEALT==nil and WTAGarou.Rage.ON_HIT_DEALT==-0.25,"0.4.82: a landed hit spends a flat 0.25 Rage (0.4.70 flat rule; halved from 0.5 so Crinos is not too easy to resist in combat)")
check(WTAGarou.ShiftStrip.FORMS.Glabro.fraction == 0 and WTAGarou.ShiftStrip.damageFor("Glabro") == 0, "0.4.82: a Glabro shift costs clothing nothing")
check(not WTAGarou.FormData.Crinos.description:find("doorway", 1, true) and not WTAGarou.FormData.Crinos.description:find("crouch", 1, true)
      and WTAGarou.FormData.Crinos.description:find("knocks over the first few zombies in its way", 1, true), "0.4.82: Berzerker tooltip lost the stale crouch-under-doorways text and says 'knocks over the first few zombies in its way'")
check(not WTAGarou.FormData.Glabro.description:find("strain", 1, true), "0.4.82: Near-Human tooltip no longer mentions seam strain")
check(WTAGarou.Rage.MOODLE_WEIGHTS.Endurance==nil and WTAGarou.Rage.MOODLE_WEIGHTS.Tired==nil
    and WTAGarou.Rage.SAD_MOODLES.Endurance==1.0 and WTAGarou.Rage.SAD_MOODLES.Tired==0.75,
    "0.4.68: exhaustion and drowsiness drain Rage like sadness")
check(WTAGarou.FormData.Crinos.meleeDamage==2.0 and WTAGarou.Poise.Crinos==0.85
    and WTAGarou.Regeneration.HEALTH_PER_SECOND.Crinos==1.2 and WTAGarou.Regeneration.CLEAR_WOUNDS_AFTER.Crinos==100
    and WTAGarou.Regeneration.CLEAR_BITES_AFTER.Crinos==300,
    "0.4.68: Crinos melee 2x, poise 0.85, healing eased (bite/Wyrm clocks untouched)")
check(WTAGarou.DamageIntake.Crinos==0.40 and WTAGarou.DamageIntake.Glabro==0.65 and WTAGarou.DamageIntake.Hispo==0.65
    and WTAGarou.DamageIntake.Homid==1.0 and WTAGarou.DamageIntake.Lupus==1.0
    and WTAGarou.EffectiveHealthFor("Crinos")==250 and math.abs(WTAGarou.EffectiveHealthFor("Glabro")-153.846)<0.01
    and WTAGarou.EffectiveHealthFor("Homid")==100 and WTAGarou.DamageIntakeFor("Nope")==1.0,
    "0.4.72: health pools: Crinos 250, Glabro/Hispo ~154, Homid/Lupus 100; unknown form = human")
-- 0.4.75: voice pitch per form
check(WTAGarou.VoicePitchFor(0, "Crinos") == -100 and WTAGarou.VoicePitchFor(20, "Glabro") == -25 and WTAGarou.VoicePitchFor(-80, "Hispo") == -100
    and WTAGarou.VoicePitchFor(15, "Homid") == 15 and WTAGarou.VoicePitchFor(15, "Lupus") == 15,
    "Glabro/Hispo drop 45, Crinos bottoms out, Homid/Lupus restore; clamped to the slider range")
do
    local vp = { pitch = 12, md = { WTAGarou = {} } }
    function vp:getVoicePitch() return self.pitch end
    function vp:setVoicePitch(v) self.pitch = v end
    function vp:getModData() return self.md end
    check(WTAGarou.ApplyVoicePitch(vp, "Crinos") == nil and vp.pitch == 12, "a shifted voice is never learned as the default (nothing applied yet)")
    check(WTAGarou.ApplyVoicePitch(vp, "Homid") == 12 and vp.md.WTAGarou.voicePitch0 == 12, "the default is learned in a base form")
    check(WTAGarou.ApplyVoicePitch(vp, "Crinos") == -88 and vp.pitch == -88, "Crinos: default minus 100 (clamped)")
    check(WTAGarou.ApplyVoicePitch(vp, "Glabro") == -33 and vp.pitch == -33, "Glabro: default minus 45")
    check(WTAGarou.ApplyVoicePitch(vp, "Lupus") == 12 and vp.pitch == 12, "Lupus restores the recorded default")
end
local r, st = WTAGarou.DoorChargeCost(false); local rl, stl = WTAGarou.DoorChargeCost(true)
check(r==12 and rl==18 and math.abs(stl/st-1.5)<1e-9 and WTAGarou.Doorway.TALL_FORMS.Crinos==true,
    "0.4.69: door charge 12/18 Rage (+50%) with the 0.4.68 relative stamina cost; Crinos is the tall form")
local cl, cw = WTAGarou.CrowdChargeFor("Crinos"); local hl, hw = WTAGarou.CrowdChargeFor("Homid")
check(cl==3 and cw==3.0 and hl==0 and hw==0, "0.4.69: Crinos crowd charge 3 knockdowns per 3 s; other forms none")
check(WTAGarou.FormData.Crinos.modelScale==1.65 and WTAGarou.Traits.Crinos.stride==1.65
    and WTAGarou.Rage.BASELINE_BRACKET.PER_STACK==2 and WTAGarou.Rage.BASELINE_BRACKET.MAX_STACKS==10
    and WTAGarou.Rage.CRINOS_ESCALATION.EVERY_SECONDS==90 and WTAGarou.Rage.CRINOS_ESCALATION.STEP==-1
    and WTAGarou.Rage.RESIST.LINEAR_STEP==2,
    "0.4.69: 1.65x Crinos, baseline bracket, 90 s drain escalation, 2 s Resist step")
check(WTAGarou.Rage.ON_DAMAGE_TAKEN==0.75,"rage from damage taken untouched")
for _,form in ipairs({"Homid","Glabro","Crinos","Hispo","Lupus"}) do
    check(WTAGarou.FurInsulation(form)==((form=="Homid" or form=="Glabro") and 0 or 0.5),
        "medium natural insulation only for furry forms: "..form)
end
check(math.abs(WTAGarou.ContentPullPerSecond(false,true,false)-0.1575)<1e-9,"no hunger contribution reduced 30%")
check(math.abs(WTAGarou.ContentPullPerSecond(true,false,false)-0.1575)<1e-9,"no thirst contribution reduced 30%")
check(math.abs(WTAGarou.ContentPullPerSecond(true,true,true)-0.105)<1e-9,"Well Fed bonus reduced 30%")
-- 0.4.44 shoulders-grab offset.
check(WTAGarou.CorpseCarry.grappleForward("Lupus")==0.7 and WTAGarou.CorpseCarry.grappleForward("Hispo")==1.0,"carry extras untouched")
check(WTAGarou.CorpseCarry.shoulderPickupDistance("Lupus")==1.0 and WTAGarou.CorpseCarry.shoulderPickupDistance("Hispo")==1.3,"shoulders ground grab held at the carry distance (0.3 + extra)")
check(WTAGarou.CorpseCarry.shoulderPickupDistance("Crinos")==0,"non-wolf forms: no override")
print("PASS: "..n.." Definitions reload assertions.")
