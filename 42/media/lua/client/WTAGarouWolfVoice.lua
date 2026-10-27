--[[
    WTAGarou - Wolf body sounds (v0.4.19)

    Lupus and Hispo carry WolfMod's animal sound table:
      attack    -> WTAGarou_WolfAttack     on every weapon swing (the bite)
      pain      -> WTAGarou_WolfBark       on acute damage or a new wound (rate-limited;
                                           0.4.17: never on bleeding/infection ticks)
      sniff     -> WTAGarou_WolfSniff      idle, every 10-20 s while standing still
      death     -> WTAGarou_WolfDeath      on death in wolf form
      fall over -> WTAGarou_WolfFallOver   from Java StabilityRuntime.onFall
      footsteps -> WTAGarou_WolfStep       from Java FootstepPatch
      Q shout   -> bark / growl            from Java CalloutPatch

    Everything here is the LOCAL player's voice; character:playSound goes
    through the character emitter, which the engine already syncs in MP.
    Q-shout and footsteps are handled in Java so their zombie-facing world
    sound radius matches the form (see WTAGarou.Voice / WTAGarou.Stealth).
]]

WTAGarou = WTAGarou or {}
require "WTAGarouAudio"
WTAGarou.WolfVoice = WTAGarou.WolfVoice or {}
local Voice = WTAGarou.WolfVoice

local nextSniff = {}
local pendingSwing = setmetatable({}, { __mode = "k" })
local voiceLogs = {}
local voiceLogCount = 0
local function stateName(player)
    local ok, name = pcall(function()
        local state = player:getCurrentState()
        return state and state:getName() or ""
    end)
    return ok and tostring(name) or ""
end
local function utilityGrab(player)
    -- isDoGrapple is a request flag, not a lifetime test for the whole
    -- interaction. The .37 one-flag filter did not silence the live pickup.
    if stateName(player) == "PlayerDraggingCorpse" then return true end
    if player.isDoGrapple and player:isDoGrapple() then return true end
    if player.isGrappling and player:isGrappling() then return true end
    -- 0.4.40: at swing time (and on the next update) the state is still
    -- SwipeStatePlayer and no grapple flag is set (Oct 5 console:
    -- "attack bite sound; state=SwipeStatePlayer" on the exact frame the
    -- Bob_PickUp_Person clip started). The Java track adapter saw that clip;
    -- ask it.
    if WTAGarouJava and WTAGarouJava.isCorpseHandling then
        local ok, handling = pcall(WTAGarouJava.isCorpseHandling, player)
        if ok and handling then return true end
    end
    return player.isPerformingGrappleGrabAnimation and player:isPerformingGrappleGrabAnimation() or false
end
local function trace(player, reason)
    local state = stateName(player)
    local key = reason..":"..state
    local count = voiceLogs[key] or 0
    if count >= 2 or voiceLogCount >= 32 then return end
    voiceLogs[key] = count + 1
    voiceLogCount = voiceLogCount + 1
    print("[WTAGarou][WolfVoice] "..reason.."; state="..state)
end

local function wolfForm(player)
    if not player then return nil end
    local md = player:getModData()
    local form = md and md.WTAGarou and md.WTAGarou.form or nil
    local forms = WTAGarou.WolfSounds and WTAGarou.WolfSounds.FORMS or {}
    if form and forms[form] then return form end
    return nil
end
Voice.wolfForm = wolfForm

-- 0.4.75: forms that voice pain as a beast (adds the Crinos growl).
local function painForm(player)
    if not player then return nil end
    local md = player:getModData()
    local form = md and md.WTAGarou and md.WTAGarou.form or nil
    local forms = WTAGarou.WolfSounds and WTAGarou.WolfSounds.PAIN_FORMS
        or (WTAGarou.WolfSounds and WTAGarou.WolfSounds.FORMS) or {}
    if form and forms[form] then return form end
    return nil
end
Voice.painForm = painForm

local function play(player, name)
    if not (player and name) then return false end
    -- 0.4.40: scaled by the Sound Effects slider and capped (WTAGarou.Audio).
    local handle = WTAGarou.Audio.play(player, name)
    return handle ~= nil
end
Voice.play = play

local function isLocal(player)
    return player and (not player.isLocalPlayer or player:isLocalPlayer())
end

-- Bite / attack sound on every swing while a wolf.
local function onWeaponSwing(player, weapon)
    if not isLocal(player) then return end
    local form = wolfForm(player)
    if not form then return end
    -- B42 SwipeStatePlayer raises OnWeaponSwing for grapple grabs too,
    -- before isPerformingGrappleGrabAnimation is set. A corpse pickup is
    -- not a bite. Keep actual attacks, pain, and deliberate Q calls audible.
    if utilityGrab(player) then
        trace(player, "utility grab: bite sound suppressed")
        return
    end
    -- Defer only the sound by one local update so a context pickup can
    -- settle into PlayerDraggingCorpse. Never defer damage or the attack.
    pendingSwing[player] = form
end
local function flushSwing(player)
    local form = pendingSwing[player]
    pendingSwing[player] = nil
    if not form or not isLocal(player) or player:isDead() or wolfForm(player) ~= form then return end
    if utilityGrab(player) then
        trace(player, "settled utility grab: bite sound suppressed")
        return
    end
    trace(player, "attack bite sound")
    -- 0.4.19: Hispo bites with its own bark (WolfSounds.BY_FORM).
    play(player, WTAGarou.WolfSounds.forForm and WTAGarou.WolfSounds.forForm(form, "attack")
        or WTAGarou.WolfSounds.attack)
end

-- Pain bark when hurt.
-- Pain bark, rate-limited. A zombie grab/bite reports damage many times in
-- quick succession; barking on each one stacked dozens of instances that the
-- emitter then culled, leaving several seconds of silence (0.4.12 playtest).
local lastPain = setmetatable({}, { __mode = "k" })
local function nowSeconds()
    return getTimestampMs and (getTimestampMs() / 1000) or os.time()
end
local function onPlayerGetDamage(player, damageType, damage)
    if not isLocal(player) then return end
    local form = painForm(player)
    if not form then return end
    if damage and damage <= 0 then return end
    -- 0.4.17: the engine raises this event every tick for ongoing damage
    -- (BLEEDING, INFECTION, HUNGRY, THIRST, SICK, HEAVYLOAD, POISON,
    -- LOWWEIGHT). A wounded wolf barked on each one until the form changed.
    -- Only acute hits yelp (WolfSounds.PAIN_TYPES).
    local types = WTAGarou.WolfSounds and WTAGarou.WolfSounds.PAIN_TYPES
    if types and damageType ~= nil and not types[tostring(damageType)] then return end
    local now = nowSeconds()
    local cooldown = (WTAGarou.WolfSounds and WTAGarou.WolfSounds.PAIN_COOLDOWN) or 0.8
    local last = lastPain[player]
    if last and now - last < cooldown then return end
    lastPain[player] = now
    trace(player, "pain sound: "..tostring(damageType))
    play(player, WTAGarou.WolfSounds.forForm and WTAGarou.WolfSounds.forForm(form, "pain")
        or WTAGarou.WolfSounds.pain)
end

-- Zombie bites, scratches and lacerations raise NO OnPlayerGetDamage in
-- B42.20.2 (IsoGameCharacter.Hit(IsoZombie...) has no Lua event), so a wolf
-- yelps when the count of wounded parts goes up (checked from OnPlayerUpdate).
local lastWounds = setmetatable({}, { __mode = "k" })
local function woundCount(player)
    local n = 0
    pcall(function()
        local bd = player:getBodyDamage()
        n = (bd:getNumPartsBitten() or 0) + (bd:getNumPartsScratched() or 0)
        if bd.getNumPartsCut then n = n + (bd:getNumPartsCut() or 0) end
    end)
    return n
end
local function onWoundCheck(player, form)
    local n = woundCount(player)
    local prev = lastWounds[player]
    lastWounds[player] = n
    if form and prev ~= nil and n > prev then onPlayerGetDamage(player, "WEAPONHIT", 1) end
end
Voice.onWoundCheck = onWoundCheck

-- Death whimper. The corpse handoff itself is owned by the Java wolf
-- runtime (Wolf_death then human corpse) and is not touched here.
local function onPlayerDeath(player)
    if not isLocal(player) then return end
    if not wolfForm(player) then return end
    play(player, WTAGarou.WolfSounds.death)
    nextSniff[player] = nil
end

-- Idle sniffing while standing still.
local function scheduleSniff(player, now)
    local s = WTAGarou.WolfSounds
    local lo, hi = s.SNIFF_INTERVAL_MIN or 10, s.SNIFF_INTERVAL_MAX or 20
    local span = math.max(0, hi - lo)
    local wait = lo + (ZombRand and ZombRand(span * 10 + 1) / 10 or span / 2)
    nextSniff[player] = now + wait
end

local function onPlayerUpdate(player)
    if not isLocal(player) then return end
    flushSwing(player)
    local form = wolfForm(player)
    onWoundCheck(player, painForm(player))
    if not form then
        nextSniff[player] = nil
        return
    end
    local now = getTimestampMs and (getTimestampMs() / 1000) or os.time()
    if not nextSniff[player] then
        scheduleSniff(player, now)
        return
    end
    if now < nextSniff[player] then return end
    local moving = false
    pcall(function()
        moving = player:isMoving() or (player.isPlayerMoving and player:isPlayerMoving())
    end)
    if moving or player:isDead() then
        -- Try again shortly; wolves only sniff while standing still.
        nextSniff[player] = now + 2
        return
    end
    play(player, WTAGarou.WolfSounds.sniff)
    scheduleSniff(player, now)
end

-- Worn gear changes re-evaluate the saddlebag (and, 0.4.23, the harness)
-- visual on wolves. Hotbar changes fire OnClothingUpdated too; the secondary
-- hand fires OnEquipSecondary.
local function onClothingUpdated(player)
    if not isLocal(player) then return end
    if WTAGarou.Visual and WTAGarou.Visual.refreshSaddlebag then
        WTAGarou.Visual.refreshSaddlebag(player)
    end
end

Voice.onWeaponSwing = onWeaponSwing
Voice.flushSwing = flushSwing
Voice.onPlayerGetDamage = onPlayerGetDamage
Voice.onPlayerDeath = onPlayerDeath
Voice.onPlayerUpdate = onPlayerUpdate
Voice.onClothingUpdated = onClothingUpdated

if Events then
    if Events.OnWeaponSwing then Events.OnWeaponSwing.Add(onWeaponSwing) end
    if Events.OnPlayerGetDamage then Events.OnPlayerGetDamage.Add(onPlayerGetDamage) end
    if Events.OnPlayerDeath then Events.OnPlayerDeath.Add(onPlayerDeath) end
    if Events.OnPlayerUpdate then Events.OnPlayerUpdate.Add(onPlayerUpdate) end
    if Events.OnClothingUpdated then Events.OnClothingUpdated.Add(onClothingUpdated) end
    if Events.OnEquipSecondary then Events.OnEquipSecondary.Add(function(player) onClothingUpdated(player) end) end
    if Events.OnEquipPrimary then Events.OnEquipPrimary.Add(function(player) onClothingUpdated(player) end) end
end
