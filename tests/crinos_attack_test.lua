local root=assert(arg[1])
package.path=root.."/42/media/lua/client/?.lua;"..package.path
local n=0
local function check(ok,why) n=n+1; assert(ok,why) end
local hooks={}
Events={}
for _,name in ipairs({"OnEquipPrimary","OnEquipSecondary","OnHitZombie","OnWeaponSwing","OnPlayerUpdate"}) do
    Events[name]={Add=function(fn) hooks[name]=fn end}
end
WTAGarou={HasGarouTrait=function(p) return p.garou end}
local known=true
GameSounds={isKnownSound=function(name)
    check(name=="ZombieScratch" or name=="ZombieBite","only verified B42 event lookups: "..tostring(name))
    return known
end}
local function player()
    local p={data={WTAGarou={form="Crinos"}},garou=true,vars={},sounds={}}
    function p:getModData() return self.data end
    function p:getPrimaryHandItem() return self.primary end
    function p:getSecondaryHandItem() return self.secondary end
    function p:setVariable(k,v) self.vars[k]=v end
    function p:getVariableBoolean(k) return self.vars[k]==true end
    function p:isLocalPlayer() return not self.remote end
    function p:isDead() return self.dead end
    function p:isAimAtFloor() return self.floor end
    function p:isDoShove() return not self.notShove end
    function p:isDoGrapple() return self.grapple end
    function p:isPerformingGrappleGrabAnimation() return self.grab end
    function p:getVehicle() return self.vehicle end
    function p:playSound(name) self.sounds[#self.sounds+1]=name end
    return p
end
local A=require "WTAGarouCrinosAttack"
local p,q=player(),player()
local bare={getType=function() return "BareHands" end}
local club={getType=function() return "LongSpikedClub" end}
local Z={splats=0,decals={}}
function Z:splatBlood(dist,alpha) check(dist==2 and alpha>0 and alpha<=0.3,"vanilla-sized floor splat"); self.splats=self.splats+1 end
function Z:addBlood(part,scratched,bitten,all) self.decals[#self.decals+1]={part,scratched,bitten,all} end
local bloodLevel=3
getSandboxOptions=function() return {getOptionByName=function(_,name) check(name=="BloodLevel","sandbox option name"); return {getValue=function() return bloodLevel end} end} end
local function hit(who,weapon) hooks.OnHitZombie(Z,who,nil,weapon or bare) end
check(hooks.OnHitZombie and hooks.OnEquipPrimary and hooks.OnEquipSecondary,"real client events wired")
for _,form in ipairs({"Homid","Glabro","Crinos","Hispo","Lupus"}) do
    A.refresh(p,form)
    check(p.vars[A.VARIABLE]==(form=="Crinos"),"form scoping "..form)
end
A.refresh(p,"Crinos")
for _,slot in ipairs({"primary","secondary"}) do
    p[slot]=club; A.onEquip(p)
    check(p.vars[A.VARIABLE]==false,"equipped "..slot.." stays vanilla")
    hit(p); check(#p.sounds==0,"no claw sound while holding "..slot)
    p[slot]=nil; A.onEquip(p)
    check(p.vars[A.VARIABLE]==true,"unequip restores swing "..slot)
end
for _,flag in ipairs({"dead","vehicle"}) do
    p[flag]=true; A.refresh(p,"Crinos")
    check(p.vars[A.VARIABLE]==false,"no animation override when "..flag)
    p[flag]=nil
end
A.refresh(p,"Crinos")
-- 0.4.69: the per-press decision belongs to Java. 0.4.70: a local refresh
-- (every OnPlayerUpdate) must not touch it while the override is live.
check(p.vars[A.SWING_VARIABLE]==nil or p.vars[A.SWING_VARIABLE]==false,"local refresh does not switch the swing flag on by itself")
p.vars[A.SWING_VARIABLE]=true                      -- Java decided: attack button
A.refresh(p,"Crinos")
check(p.vars[A.SWING_VARIABLE]==true,"0.4.70: a per-frame local refresh leaves Java's press decision alone (was cleared each frame)")
A.refresh(p,"Homid")
check(p.vars[A.SWING_VARIABLE]==false,"leaving Crinos clears the stale decision")
A.refresh(p,"Crinos")
p.vars[A.SWING_VARIABLE]=false
hit(p)
check(#p.sounds==1 and p.sounds[1]=="ZombieScratch","0.4.72: the spacebar shove also scratches (every unarmed Crinos hit)")
p.vars[A.SWING_VARIABLE]=true
hit(p)
check(#p.sounds==2 and p.sounds[2]=="ZombieScratch" and A.HIT_SOUND=="ZombieScratch","attack-button unarmed contact plays the zombie scratch")
-- 0.4.72: blood. Two Crinos hits so far at BloodLevel 3 = 3 splats each + a scratched decal each.
check(Z.splats==6 and #Z.decals==2 and Z.decals[1][2]==true and Z.decals[1][3]==false,"Crinos claws fling 3 floor splats and tear a bloody scratch per hit: "..Z.splats)
Z.splats=0; Z.decals={}
bloodLevel=1; hit(p); check(Z.splats==0 and #Z.decals==0,"BloodLevel None: no blood at all")
bloodLevel=5; hit(p); check(Z.splats==9,"BloodLevel Ultra Gore: triple splats")
bloodLevel=3; Z.splats=0; Z.decals={}
check(A.flingBlood(nil,"Crinos")==0 and A.flingBlood(Z,"Homid")==0 and Z.splats==0,"no zombie / human form: nothing flung")
local lastSounds=#p.sounds
local before=#p.sounds
for _,flag in ipairs({"remote","dead","floor","notShove","grapple","grab","vehicle"}) do
    p[flag]=true; hit(p); p[flag]=nil
    check(#p.sounds==before,"no sound for "..flag)
end
hit(p,club); check(#p.sounds==before,"weapon attack keeps its own hit sound")
p.garou=false; hit(p); p.garou=true
check(#p.sounds==before,"non-Garou fails closed")
for _,form in ipairs({"Homid","Glabro"}) do
    p.data.WTAGarou.form=form; hit(p)
    check(#p.sounds==before,"human form's sound untouched: "..form)
end
for _,form in ipairs({"Hispo","Lupus"}) do
    p.data.WTAGarou.form=form; Z.splats=0; Z.decals={}; hit(p)
    check(#p.sounds==before+1 and p.sounds[#p.sounds]=="ZombieBite","0.4.72: wolf jaws bite: "..form)
    check(Z.splats==A.BLOOD[form].splats and #Z.decals==1 and Z.decals[1][2]==false,"wolf bite flings blood without tearing clothes: "..form)
    before=#p.sounds
    Z.splats=0; p.floor=true; hit(p); p.floor=nil
    check(#p.sounds==before and Z.splats==0,"wolf stomp keeps vanilla audio and blood: "..form)
end
p.data.WTAGarou.form="Crinos"
known=false; hit(p)
check(#p.sounds==before,"unregistered event never played or auto-created")
GameSounds=nil; hit(p)
check(#p.sounds==before,"missing sound API fails closed")
GameSounds={isKnownSound=function() error("unavailable") end}; hit(p)
check(#p.sounds==before,"broken sound API fails closed")
q.remote=true; q.data.WTAGarou.form="Homid"
A.refresh(q,"Crinos")
check(q.vars[A.VARIABLE]==true and q.data.WTAGarou.form=="Homid","remote snapshot presentation only")
check(q.vars[A.SWING_VARIABLE]==true,"remote Crinos shows the swing for every unarmed attack (no input to read)")
A.refresh(q,"Homid"); check(q.vars[A.SWING_VARIABLE]==false,"remote swing flag follows the form")
A.refresh(q,"Crinos")
hit(q); check(#q.sounds==0,"observer never starts duplicate hit audio")
q.primary=club; hooks.OnEquipPrimary(q)
check(q.vars[A.VARIABLE]==false,"remote equipment event updates eligibility")
q.primary=nil; hooks.OnEquipPrimary(q)
check(q.vars[A.VARIABLE]==true,"remote unequip preserves snapshot form")
A.clear(q)
check(q.vars[A.VARIABLE]==false and p.vars[A.VARIABLE]==true,"per-character clear on death/shift")
hooks.OnEquipPrimary(q)
check(q.vars[A.VARIABLE]==false,"equipment event cannot resurrect cleared form")
A.refresh({}, "Crinos"); A.onEquip(nil); hit(nil)
check(true,"missing player/methods are safe")
local diag=0
WTAGarouJava={debugCrinosAttack=function(who) check(who==p,"diagnostic owner"); diag=diag+1; return "read-only fixture" end}
A.refresh(p,"Crinos")
hooks.OnWeaponSwing(p)
hooks.OnPlayerUpdate(p); check(diag==0,"defer diagnostic until animation selection")
hooks.OnPlayerUpdate(p); check(diag==1,"second update reads current animation")
for i=1,6 do hooks.OnWeaponSwing(p); hooks.OnPlayerUpdate(p); hooks.OnPlayerUpdate(p) end
check(diag==2,"maximum two reports per local character per session")
local untouched=p.vars[A.VARIABLE]
check(untouched==true and #p.sounds==before,"diagnostics don't change eligibility or play audio")
hooks.OnWeaponSwing(q); hooks.OnPlayerUpdate(q); hooks.OnPlayerUpdate(q)
check(diag==2,"no remote-player diagnostics")
print("PASS: "..n.." Crinos unarmed animation eligibility/contact-sound assertions.")
