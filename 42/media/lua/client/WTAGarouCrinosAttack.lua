-- 0.4.50: presentation only. Keep native shove collision/damage/knockback,
-- but let the Crinos-only shove node play the human one-handed swing.
-- 0.4.69: only for the attack button. Vanilla turns a bare-hands attack into
-- a shove (doShove forced true), so isDoShove() cannot tell the spacebar
-- shove from ctrl+click; Java CrinosSwingRuntime decides per press from
-- IsoPlayer.meleePressed and writes SWING_VARIABLE. Spacebar: vanilla shove
-- node and vanilla audio. Attack button: one-handed swing + club hit sound.
WTAGarou = WTAGarou or {}
WTAGarou.CrinosAttack = WTAGarou.CrinosAttack or {}
local Attack = WTAGarou.CrinosAttack
Attack.VARIABLE = "WTAGarouCrinosUnarmed"
Attack.SWING_VARIABLE = "WTAGarouCrinosSwing"
-- 0.4.72: unarmed contact audio per beast form (Oct 18 request): the Crinos
-- claws sound like a zombie scratch, the wolf jaws like a zombie bite; every
-- unarmed hit except the stomp (isAimAtFloor), spacebar shove included.
-- Verified B42 SoundKey.ZOMBIE_SCRATCH / ZOMBIE_BITE event names (the ones
-- BodyDamage plays when a zombie lands them), not file paths. Never ask
-- getSound() to auto-create a missing sound: isKnownSound first, fail closed.
Attack.HIT_SOUNDS = { Crinos = "ZombieScratch", Hispo = "ZombieBite", Lupus = "ZombieBite" }
Attack.HIT_SOUND = Attack.HIT_SOUNDS.Crinos   -- kept for older callers/tests
-- 0.4.72: those hits also fling blood (vanilla bare hands never do: the
-- BareHands script has no SplatBloodOnNoDeath, so IsoGameCharacter.Hit
-- skips splatBlood(2, 0.2) for them). Presentation only on the attacker's
-- client, exactly like vanilla's no-death splat; honours the BloodLevel
-- sandbox option (off at 1 = None). `scratch` adds a torn-clothing blood
-- decal on the zombie (IsoGameCharacter.addBlood scratched=true).
Attack.BLOOD = {
    Crinos = { splats = 3, dist = 2, alpha = 0.30, scratch = true },
    Hispo  = { splats = 2, dist = 2, alpha = 0.30, scratch = false },
    Lupus  = { splats = 1, dist = 2, alpha = 0.25, scratch = false },
}

local function bloodLevel()
    local ok, v = pcall(function()
        local o = getSandboxOptions and getSandboxOptions():getOptionByName("BloodLevel")
        return o and o:getValue()
    end)
    if ok and tonumber(v) then return tonumber(v) end
    return 3
end

-- Splatter for one unarmed hit. Returns the number of floor splats made.
function Attack.flingBlood(zombie, form)
    local cfg = zombie and Attack.BLOOD[form]
    if not cfg then return 0 end
    local level = bloodLevel()
    if level <= 1 then return 0 end
    local splats = cfg.splats
    if level == 2 then splats = math.max(1, math.floor(splats / 2))
    elseif level == 4 then splats = splats * 2
    elseif level >= 5 then splats = splats * 3 end
    local made = 0
    for _ = 1, splats do
        local ok = pcall(function() zombie:splatBlood(cfg.dist, cfg.alpha) end)
        if ok then made = made + 1 end
    end
    pcall(function() zombie:addBlood(nil, cfg.scratch == true, false, false) end)
    return made
end
local forms = setmetatable({}, {__mode="k"})
local warnedSound = {}
local diagnosticCounts=setmetatable({}, {__mode="k"})
local diagnosticPending=setmetatable({}, {__mode="k"})

local function emptyHands(player)
    return player and player.getPrimaryHandItem and player.getSecondaryHandItem
        and player:getPrimaryHandItem() == nil and player:getSecondaryHandItem() == nil
end

-- Visual.refresh supplies local form or the validated remote snapshot form.
function Attack.refresh(player, form)
    if not player then return end
    forms[player] = form
    if player.setVariable then
        local enabled = form == "Crinos" and emptyHands(player)
            and not (player.isDead and player:isDead())
            and not (player.getVehicle and player:getVehicle())
        player:setVariable(Attack.VARIABLE, enabled == true)
        -- Remote Crinos: no input to read, so observers see the swing for
        -- every unarmed attack. Local: Java decides per press and this
        -- function runs every OnPlayerUpdate (Visual.refresh), so it must
        -- NOT touch the flag while the override is live -- 0.4.69 cleared
        -- it here each frame, the claw node started on the press frame and
        -- lost to ShoveAim one frame later (Oct 18 recorder). Only a form
        -- change / disabled override clears a stale decision.
        local remote = player.isLocalPlayer and not player:isLocalPlayer()
        if remote then
            player:setVariable(Attack.SWING_VARIABLE, enabled == true)
        elseif not enabled then
            player:setVariable(Attack.SWING_VARIABLE, false)
        end
    end
end

function Attack.swinging(player)
    if not (player and player.getVariableBoolean) then return false end
    local ok, v = pcall(player.getVariableBoolean, player, Attack.SWING_VARIABLE)
    return ok and v == true
end

function Attack.clear(player)
    Attack.refresh(player, nil)
    if player then diagnosticPending[player]=nil end
end

-- Only collect evidence; don't force a clip or change the existing gate.
-- Wait two local updates after the swing event so selection can settle.
function Attack.onSwing(player)
    if not (player and player.isLocalPlayer and player:isLocalPlayer()
            and forms[player]=="Crinos" and emptyHands(player)
            and not (player.isAimAtFloor and player:isAimAtFloor())) then return end
    if (diagnosticCounts[player] or 0)>=2 or diagnosticPending[player] then return end
    diagnosticCounts[player]=(diagnosticCounts[player] or 0)+1
    diagnosticPending[player]=2
end
function Attack.updateDiagnostic(player)
    local ticks=diagnosticPending[player]
    if not ticks then return end
    if ticks>1 then diagnosticPending[player]=ticks-1; return end
    diagnosticPending[player]=nil
    if forms[player]~="Crinos" or not emptyHands(player) then return end
    local ok,status=pcall(function()
        if WTAGarouJava and WTAGarouJava.debugCrinosAttack then
            return WTAGarouJava.debugCrinosAttack(player)
        end
        return "diagnostic bridge unavailable; expected Java 0.4.52"
    end)
    print("[WTAGarou][CrinosAttackDiag] "..(ok and tostring(status) or "diagnostic call failed"))
end

function Attack.onEquip(player)
    -- Also covers remote equipment changes between snapshot polls.
    Attack.refresh(player, forms[player])
end

function Attack.onHitZombie(zombie, player, bodyPart, weapon)
    if not (player and player.isLocalPlayer and player:isLocalPlayer()
            and player.getModData and emptyHands(player)
            and player.isDead and not player:isDead()
            and player.isAimAtFloor and not player:isAimAtFloor()   -- stomp keeps vanilla audio
            and player.isDoShove and player:isDoShove()
            and weapon and weapon.getType and weapon:getType() == "BareHands") then return end
    local md = player:getModData()
    local data = md and md.WTAGarou
    local sound = data and Attack.HIT_SOUNDS[data.form]
    if not (sound and WTAGarou.HasGarouTrait and WTAGarou.HasGarouTrait(player)) then return end
    if (player.getVehicle and player:getVehicle())
            or (player.isDoGrapple and player:isDoGrapple())
            or (player.isPerformingGrappleGrabAnimation and player:isPerformingGrappleGrabAnimation()) then return end
    Attack.flingBlood(zombie, data.form)
    local ok, known = pcall(function()
        return GameSounds and GameSounds.isKnownSound and GameSounds.isKnownSound(sound)
    end)
    if not ok or not known then
        if not warnedSound[sound] then
            warnedSound[sound] = true
            print("[WTAGarou][CrinosAttack] hit event " .. tostring(sound) .. " unavailable in this installation; leaving audio unchanged.")
        end
        return
    end
    -- Native bank event uses normal SFX volume, not the custom OGG correction.
    -- Only the local attacker starts it; native emitter handles MP replication.
    if player.playSound then player:playSound(sound) end
end

if Events then
    if Events.OnEquipPrimary then Events.OnEquipPrimary.Add(Attack.onEquip) end
    if Events.OnEquipSecondary then Events.OnEquipSecondary.Add(Attack.onEquip) end
    if Events.OnHitZombie then Events.OnHitZombie.Add(Attack.onHitZombie) end
    if Events.OnWeaponSwing then Events.OnWeaponSwing.Add(Attack.onSwing) end
    if Events.OnPlayerUpdate then Events.OnPlayerUpdate.Add(Attack.updateDiagnostic) end
end
return Attack
