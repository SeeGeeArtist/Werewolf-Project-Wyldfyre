--[[
    WTAGarou - Definitions (v0.4.69)

    Central config: forms, rage, timing, buffs, delirium tuning, silver,
    infamy thresholds, and per-form clothing rules. Loaded on both sides.
]]

WTAGarou = WTAGarou or {}
-- 0.4.44: this file is re-run by "/garou reload" and the Startup panel. A
-- table that another module adds FUNCTIONS to (Howl, Silver, VehicleShift)
-- must be updated in place, not replaced: the Oct 6 console lost every howl
-- sound ("Howl feedback module unavailable") after the Howl table was
-- rebuilt here and WTAGarouHowl.lua's onStarted/onStopped went with it.
local function defineTable(name, values)
    local t = WTAGarou[name] or {}
    for k, v in pairs(values) do t[k] = v end
    WTAGarou[name] = t
    return t
end
WTAGarou.DefineTable = defineTable

-- 0.4.45 rich text (tooltips, Guide). Build 42's ISRichTextPanel splits the
-- text at plain spaces, cuts a token at the first ">", and treats ANY token
-- holding "<" and ">" as a command, so "word<RGB:...>" loses "word" and the
-- spaces either side of a tag are trimmed away ("HomidHuman"). Its own
-- <SPACE> command advances the pen by one space (not at a line start).
-- Rule: every tag stands alone between spaces, and a <SPACE> sits where a
-- visible gap is wanted. Rich.kw() writes a keyword that way; Rich.plain()
-- is what the player reads (tests compare it to the rendered words).
WTAGarou.Rich = WTAGarou.Rich or {}
WTAGarou.Rich.BODY = "<RGB:1,1,1>"
WTAGarou.Rich.COLORS = {
    lore   = "<RGB:1,0.85,0.45>",     -- lore names: Homid, Garou, Ragabash
    rage   = "<RGB:1,0.8,0.35>",      -- Rage and numbers
    war    = "<RGB:1,0.55,0.55>",     -- Berzerker / warnings
    action = "<RGB:0.6,0.9,1>",       -- buttons: Strip, Dress, Howl, Startup
    good   = "<RGB:0.6,1,0.6>",
    wyrm   = "<RGB:0.75,0.35,0.95>",
    silver = "<RGB:0.7,0.8,0.9>",
}
-- " <SPACE> <RGB:..> word <SPACE> <RGB:1,1,1> " - punctuation goes inside.
function WTAGarou.Rich.kw(text, kind)
    local rgb = WTAGarou.Rich.COLORS[kind or "lore"] or WTAGarou.Rich.COLORS.lore
    return " <SPACE> " .. rgb .. " " .. tostring(text) .. " <SPACE> " .. WTAGarou.Rich.BODY .. " "
end
-- Highlighted opener at the start of a line (no leading gap needed).
function WTAGarou.Rich.lead(text, kind)
    local rgb = WTAGarou.Rich.COLORS[kind or "lore"] or WTAGarou.Rich.COLORS.lore
    return rgb .. " " .. tostring(text) .. " <SPACE> " .. WTAGarou.Rich.BODY .. " "
end
function WTAGarou.Rich.line() return " <LINE> " end
-- Two keywords in a row would leave "<SPACE> <RGB:body> <SPACE>" (a double
-- gap); the next keyword sets its own colour, so drop the middle.
function WTAGarou.Rich.tidy(body)
    local out = tostring(body):gsub("<SPACE> +" .. WTAGarou.Rich.BODY:gsub("%p", "%%%0") .. " +<SPACE> ", "<SPACE> ")
    return out
end
function WTAGarou.Rich.plain(body)
    local out = tostring(body):gsub("<LINE>", "\n"):gsub("<[^>]->", " ")
    out = out:gsub(" +", " "):gsub(" \n", "\n"):gsub("\n ", "\n"):gsub("^ ", ""):gsub(" $", "")
    return out
end
WTAGarou.VERSION = "0.4.98"

print("==================================================")
print("[WTAGarou] Definitions loaded - version " .. WTAGarou.VERSION)
print("[WTAGarou] If this version is not what you expect,")
print("[WTAGarou] the game is loading a different folder.")
print("==================================================")

-- ---------------------------------------------------------------------------
-- Action animations  (ONE place to tune both channelled actions)
-- ---------------------------------------------------------------------------
-- See WTAGarouChannel.lua for the client-side timed-action plumbing.
WTAGarou.Anims = {
    -- PERMANENT CONTRACT: no animation, no enum, no fallback. The shift
    -- action ignores animation config and ALWAYS forwards literal nil,nil.
    SHIFT = nil,
    SHIFT_FALLBACK = nil,
    SHIFT_FORCE_SNEAK = true,

    -- Howl: keep the character roughly stationary, no enforced crouch.
    HOWL = "Drink",
    HOWL_FALLBACK = nil,
    HOWL_FORCE_SNEAK = false,
    -- 0.4.71: authored Glabro/Crinos howl. When the human rig has the clip
    -- HOWL_AUTHORED_CLIP loaded (media/anims_X/Bob/Bob_WTAGarouHowl.*), the
    -- howl action sets the action name HOWL_AUTHORED instead of Drink; the
    -- node AnimSets/player/actions/WTAGarouHowl.xml plays it and no arm
    -- mask is needed. Without the file everything stays on Drink + mask.
    HOWL_AUTHORED = "WTAGarouHowl",
    HOWL_AUTHORED_CLIP = "Bob_WTAGarouHowl",
}

-- True when the authored howl should be used for this character: a form
-- whose Drink arm is masked (Glabro/Crinos) and the clip is loaded.
function WTAGarou.UseAuthoredHowl(character)
    local A = WTAGarou.Anims
    if not (A and A.HOWL_AUTHORED and A.HOWL_AUTHORED_CLIP) then return false end
    if not (WTAGarou.HowlMasksArm and WTAGarou.HowlMasksArm(character)) then return false end
    if not (WTAGarouJava and WTAGarouJava.hasHumanClip) then return false end
    local ok, present = pcall(WTAGarouJava.hasHumanClip, A.HOWL_AUTHORED_CLIP)
    return ok and present == true
end

-- ---------------------------------------------------------------------------
-- Forms
-- ---------------------------------------------------------------------------
WTAGarou.Forms = {
    HOMID  = "Homid",
    GLABRO = "Glabro",
    CRINOS = "Crinos",
    HISPO  = "Hispo",
    LUPUS  = "Lupus",
}

WTAGarou.FormOrder = { "Homid", "Glabro", "Crinos", "Hispo", "Lupus" }

WTAGarou.FormData = {
    Homid = {
        name = "Homid",
        displayName = "Human",
        description = "Human form. Firearms, vehicles, all survivor gear.",
        rageCost = 0,
        meleeDamage = 1.00,
        moveSpeed = 1.00,
        damageReduction = 0.00,
        maxCarryMultiplier = 1.00,
        healingMult = 1.00,
        infectionResist = 0.00,
        unarmedDamageBonus = 0.0,
        unarmedPiercing = false,
        shovePowerBonus = 0.0,
        hitboxScale = 1.00,
        modelScript = nil,
        modelScale = 1.00,
        skinTextureName = nil,
        quadruped = false,
        allowPrimaryHand = true,
        allowSecondaryHand = true,
        mouthCarry = false,
        mouthCarryMaxWeight = 0,
        reachBonus = 0.0,
        stealthBonus = 0.00,
        wildernessMult = 1.00,
        toughFeet = false,
        canUseFirearms = true,
        canUseVehicles = true,
        canUseWeapons  = true,
        canUseTools    = true,
        stripsClothing = false,
        drunkDriving   = false,
        allowedClothing = { Shirt=true, Pants=true, Shoes=true, Gloves=true, Hat=true,
                            Belt=true, Backpack=true, Neck=true, Bandana=true, Mask=true, Underwear=true },
        deliriumTier = 0,
        color = { r = 0.85, g = 0.85, b = 0.85 },
    },
    Glabro = {
        name = "Glabro",
        displayName = "Near-Human",
        description = "Near-man. Stronger, still bipedal, still uses gear. Worn clothes stay on.",
        rageCost = 20,
        meleeDamage = 1.50,
        attackSpeedMult = 1.10,
        moveSpeed = 1.05,
        damageReduction = 0.10,
        -- Base 14 -> floor(14 * 1.92) = 26 at Strength 7, before moodles.
        maxCarryMultiplier = 1.75,
        minCarryWeight = 14.0,
        healingMult = 1.75,
        infectionResist = 0.35,
        unarmedDamageBonus = 0.6,
        unarmedPiercing = true,
        shovePowerBonus = 0.4,
        hitboxScale = 1.15,
        modelScript = "WTAGarou_Glabro",
        modelScriptFemale = "WTAGarou_Glabro_Female",
        modelScale = 1.24, -- 0.4.22: 1.08 x 1.15 (all beast forms +15%, September 27)
        skinTextureName = nil,
        quadruped = false,
        allowPrimaryHand = true,
        allowSecondaryHand = true,
        mouthCarry = false,
        mouthCarryMaxWeight = 0,
        reachBonus = 0.15,
        stealthBonus = 0.05,
        wildernessMult = 1.10,
        toughFeet = true,
        canUseFirearms = false,
        canUseVehicles = false,
        canUseWeapons  = true,
        canUseTools    = false,
        stripsClothing = false,
        drunkDriving   = false,
        -- 0.4.77: the Near-Human keeps shoes and gloves (scattered silver
        -- and silvered handles make them worth carrying).
        allowedClothing = { Shirt=true, Pants=true, Shoes=true, Gloves=true, Belt=true, Backpack=true,
                            Neck=true, Bandana=true, Mask=true, Underwear=true },
        deliriumTier = 1,
        color = { r = 0.80, g = 0.55, b = 0.30 },
    },
    Crinos = {
        name = "Crinos",
        displayName = "Berzerker",
        description = "The explosive battle form. Devastating, terrifying, natural armor. Bursts out of worn clothing. A sprint smashes wooden doors (12 Rage, 18 locked) and knocks over the first few zombies in its way.",
        rageCost = 10,
        rageRequired = 55,
        meleeDamage = 2.00, -- 0.4.68: halved from 4.00 (melee only; firearms are never boosted)
        attackSpeedMult = 1.60,
        moveSpeed = 1.45,
        damageReduction = 0.80,
        maxCarryMultiplier = 3.75,
        minCarryWeight = 30.0,
        healingMult = 8.00,
        infectionResist = 0.95,
        unarmedDamageBonus = 6.0,
        unarmedPiercing = true,
        shovePowerBonus = 1.5,
        hitboxScale = 1.55,
        modelScript = "WTAGarou_Crinos",
        modelScriptFemale = "WTAGarou_Crinos_Female",
        modelScale = 1.65, -- 0.4.69: trimmed from 1.73 (0.4.68: +20% on 1.44); too tall for doorways upright
        skinTextureName = nil,
        quadruped = false,
        allowPrimaryHand = true,
        allowSecondaryHand = true,
        mouthCarry = false,
        mouthCarryMaxWeight = 0,
        reachBonus = 0.5,
        stealthBonus = -0.30,
        wildernessMult = 1.20,
        toughFeet = true,
        canUseFirearms = false,
        canUseVehicles = false,
        canUseWeapons  = true,
        canUseTools    = false,
        stripsClothing = true,
        drunkDriving   = false,
        allowedClothing = { Shirt=true, Pants=true, Belt=true, Backpack=true,
                            Neck=true, Bandana=true },
        deliriumTier = 3,
        color = { r = 0.85, g = 0.15, b = 0.15 },
    },
    Hispo = {
        name = "Hispo",
        displayName = "Near-Wolf",
        description = "Dire wolf. Massive four-legged predator. Tears out of worn clothing. Carries in its jaws; worn bags ride as saddlebags; no triggers, no tools.",
        rageCost = 20,
        meleeDamage = 1.75,
        attackSpeedMult = 1.25,
        moveSpeed = 1.45,
        damageReduction = 0.25,
        -- Base 17 -> floor(17 * 1.92) = 32 at Strength 7, before moodles.
        maxCarryMultiplier = 2.125,
        minCarryWeight = 17.0,
        healingMult = 2.25,
        infectionResist = 0.60,
        unarmedDamageBonus = 1.2,
        unarmedPiercing = true,
        shovePowerBonus = 1.0,
        hitboxScale = 1.55,
        modelScript = "WTAGarou_Hispo",
        modelScale = 1.55, -- 0.4.22: 1.35 x 1.15 (was +8% vs 1.25 on September 23)
        skinTextureName = "WTAGarou_Wolf",
        quadruped = true,
        allowPrimaryHand = false,
        allowSecondaryHand = true, -- 0.4.17: off-hand / two-handed items allowed in wolf forms
        mouthCarry = true,
        mouthCarryMaxWeight = 14.0,
        reachBonus = 0.35,
        stealthBonus = 0.25,
        wildernessMult = 1.35,
        toughFeet = true,
        canUseFirearms = false,
        canUseVehicles = true,
        canUseWeapons  = false,
        canUseTools    = false,
        stripsClothing = true,
        drunkDriving   = true,
        allowedClothing = { Belt=true, Backpack=true, Neck=true, Bandana=true },
        deliriumTier = 2,
        color = { r = 0.55, g = 0.30, b = 0.25 },
    },
    Lupus = {
        name = "Lupus",
        displayName = "Wolf",
        description = "Wolf. Fast, quiet, harmless-looking. Slips out of worn clothing. Carries in its jaws; worn bags ride as saddlebags; no triggers, no tools.",
        rageCost = 0,
        meleeDamage = 1.15,
        attackSpeedMult = 1.30,
        moveSpeed = 1.55,
        damageReduction = 0.05,
        maxCarryMultiplier = 0.35,
        minCarryWeight = 8.0,
        healingMult = 1.00,
        infectionResist = 0.75,
        unarmedDamageBonus = 0.8,
        unarmedPiercing = true,
        shovePowerBonus = 0.2,
        hitboxScale = 0.85,
        modelScript = "WTAGarou_Lupus",
        modelScale = 1.15, -- 0.4.22: Lupus 1.00 x 1.15 (user asked for every non-Homid form)
        skinTextureName = "WTAGarou_Wolf",
        quadruped = true,
        allowPrimaryHand = false,
        allowSecondaryHand = true, -- 0.4.17: off-hand / two-handed items allowed in wolf forms
        mouthCarry = true,
        mouthCarryMaxWeight = 8.0,
        reachBonus = 0.0,
        stealthBonus = 0.45,
        wildernessMult = 1.40,
        toughFeet = true,
        canUseFirearms = false,
        canUseVehicles = true,
        canUseWeapons  = false,
        canUseTools    = false,
        stripsClothing = true,
        drunkDriving   = true,
        allowedClothing = { Belt=true, Backpack=true, Neck=true, Bandana=true },
        deliriumTier = 1,
        color = { r = 0.35, g = 0.35, b = 0.55 },
    },
}

WTAGarou.SupernaturalForms = { Glabro=true, Crinos=true, Hispo=true, Lupus=true }
-- ---------------------------------------------------------------------------
-- Shift strip (0.4.11, reworked 0.4.15).
-- When a shift completes, worn clothing is handled per destination form:
--   Glabro  keeps everything on, undamaged (0.4.82; was a 0.1-point strain).
--   Lupus   slips out: a little damage, everything tearable drops.
--   Hispo   tears out: moderate damage, drops.
--   Crinos  bursts out: heavy damage (1.5x Hispo), drops.
-- Damage is an AMOUNT of condition points derived from a common T-shirt,
-- not a percentage of the item's own maximum, so a heavy jacket with a high
-- ConditionMax loses the same points a T-shirt does. In B42.20.2 clothing
-- scripts do not set ConditionMax, so the engine default of 10 applies
-- (zombie/scripting/objects/Item.java: conditionMax = 10; T-shirt scripts on
-- pzwiki.net carry no ConditionMax). 10% of a T-shirt = 1 point.
-- Exempt from everything: any worn container (bags, backpacks, sheet slings,
-- fanny packs ...), jewelry and the equipment belts/holsters below, anything
-- held in a hand, and anything merely carried. Headwear and masks are never
-- damaged; head-only locations stay on in Crinos, drop in Lupus/Hispo.
-- Body locations are matched
-- by their bare id ("Torso1"), with the Build 42 "base:" namespace stripped.
-- ---------------------------------------------------------------------------
WTAGarou.ShiftStrip = {
    -- Engine default ConditionMax; the yardstick for every damage amount.
    TSHIRT_CONDITION = 10,
    -- Per destination form: fraction of a T-shirt's condition removed
    -- (rounded to whole points, at least 1), holes torn into covered parts
    -- (capped by covered parts), and whether the item comes off.
    -- Points >= 1 are rounded to whole points; points < 1 accumulate per
    -- item (mod data WTAGarou_Wear) and cost 1 point once they reach 1, so
    -- a 0.01 fraction would be one point every tenth shift. 0.4.82: Glabro
    -- is free (fraction 0): the Oct 22 playtest called the negligible seam
    -- strain pointless, and keeping clothes on IS the Glabro advantage.
    -- forcedMultiplier scales the points (never the holes) when the shift
    -- was forced by the Rage engine (100 Rage Crinos).
    FORMS = {
        Glabro = { fraction = 0,     holes = 0, drop = false },   -- 0.4.82: free (user: "the whole advantage of glabro is keeping clothes on")
        Lupus  = { fraction = 0.10,  holes = 1, drop = true  },
        Hispo  = { fraction = 0.25,  holes = 2, drop = true  },
        Crinos = { fraction = 0.375, holes = 3, drop = true, forcedMultiplier = 2 },
    },
    -- Vanilla clip played once per shift that actually tears (whole points
    -- or holes): the "rip clothing into rags" sound, SoundKey ClothesRipping
    -- in B42.20.2 (zombie/scripting/objects/SoundKey.java).
    RIP_SOUND = "ClothesRipping",
    -- 0.4.17: the vanilla ClothesRipping event is a long/looping crafting
    -- clip; the client stops it by handle this many seconds after starting.
    RIP_SECONDS = 1.2,
    -- Per-item mod-data key for sub-point wear.
    WEAR_KEY = "WTAGarou_Wear",
    -- Headwear and masks: dropped by the dropping forms, never damaged
    -- (some hats double as masks; one simple rule for both).
    NO_DAMAGE_LOCATIONS = {
        Hat = true, FullHat = true, SweaterHat = true, Bandana = true,
        Mask = true, MaskEyes = true, MaskFull = true, Headband = true,
    },
    -- Keep head-only clothing when entering Crinos. Other clothing still
    -- tears/drops normally, and Lupus/Hispo keep their existing drop policy.
    CRINOS_KEEP_LOCATIONS = {
        Hat = true, FullHat = true, Bandana = true, Headband = true,
        Mask = true, MaskEyes = true, MaskFull = true,
    },
    SAFE_LOCATIONS = {
        -- jewelry / accessories (engine ids from ItemBodyLocation)
        Ears = true, EarTop = true, Nose = true, BellyButton = true,
        Eyes = true, LeftEye = true, RightEye = true,
        Necklace = true, Necklace_Long = true,
        LeftWrist = true, RightWrist = true,
        Left_RingFinger = true, Right_RingFinger = true,
        Left_MiddleFinger = true, Right_MiddleFinger = true,
        MakeUp_Eyes = true, MakeUp_EyesShadow = true, MakeUp_FullFace = true, MakeUp_Lips = true,
        -- gear straps and holsters (they hold items; ripping them dumps gear)
        Belt = true, BeltExtra = true, AmmoStrap = true, Webbing = true,
        AnkleHolster = true, ShoulderHolster = true,
        Back = true, Satchel = true, FannyPackFront = true, FannyPackBack = true,
        -- wolf carry gear
        saddlebag = true,
        -- never touch bandages / wounds / zombie damage pseudo-items
        Bandage = true, Wound = true, ZedDmg = true,
    },
}
-- Backwards-compatible aliases still read by older code paths.
WTAGarou.ShiftSafeClothing = { Belt = true, Backpack = true, Neck = true, Bandana = false }
WTAGarou.ClothingShiftDamage = 15

-- ---------------------------------------------------------------------------
-- Noise, visibility and voice per form (0.4.11). Consumed by the Java
-- StealthRuntime through WTAGarouJava.setNoise/setVoice.
--   footstepMul    : multiplier on the engine footstep volume (radius follows)
--   spotMul        : fraction of zombie sight checks that still run while
--                    standing (engine sneaking already ~0.6x; Lupus standing
--                    is meant to read like a sneaking Homid)
--   spotMulSneaking: extra fraction applied while the form is sneaking
--   wolfSteps      : replace the human footstep bank with WTAGarou_WolfStep
--   stepLayer      : 0.4.67, human-step forms only: an extra bank played
--                    under every surface footstep (Crinos bass impact). The
--                    Java footstep patch plays it locally on each client, so
--                    remote Crinos players are heard too.
-- ---------------------------------------------------------------------------
WTAGarou.Stealth = {
    Homid  = { footstepMul = 1.0,  spotMul = 1.0, spotMulSneaking = 1.0, wolfSteps = false },
    Glabro = { footstepMul = 1.0,  spotMul = 1.0, spotMulSneaking = 1.0, wolfSteps = false },
    Hispo  = { footstepMul = 1.0,  spotMul = 1.0, spotMulSneaking = 1.0, wolfSteps = true },
    Lupus  = { footstepMul = 0.5,  spotMul = 0.6, spotMulSneaking = 0.5, wolfSteps = true },
    Crinos = { footstepMul = 1.5,  spotMul = 1.0, spotMulSneaking = 1.0, wolfSteps = false,
               stepLayer = "WTAGarou_CrinosStep" },
    STEP_SOUND = "WTAGarou_WolfStep",
}
-- Q shout replacement. Human: "Hey" 30 tiles, crouched "psst" 6 tiles.
-- Glabro deliberately has no entry: it sounds like Homid.
WTAGarou.Voice = {
    Lupus  = { standing = "WTAGarou_WolfBark",  crouched = "WTAGarou_WolfGrowl",
               radiusStanding = 20, radiusCrouched = 4,
               textStanding = "*bark!*", textCrouched = "*grrr*" },
    -- 0.4.18: Hispo has its own author-supplied bark/growl; the WolfMod
    -- pair stays on Lupus.
    Hispo  = { standing = "WTAGarou_HispoBark", crouched = "WTAGarou_HispoGrowl",
               radiusStanding = 30, radiusCrouched = 6,
               textStanding = "*BARK!*", textCrouched = "*grrrr*" },
    Crinos = { standing = "WTAGarou_CrinosRoar", crouched = "WTAGarou_CrinosGrowl",
               radiusStanding = 45, radiusCrouched = 9,
               textStanding = "*RAAARGH!*", textCrouched = "*growl*",
               -- 0.4.63: Q shout / whisper plays no gesture animation in Crinos
               shoutAnim = false },
}
-- Wolf body sounds (Lupus/Hispo), mirroring WolfMod's animal sound table.
WTAGarou.WolfSounds = {
    FORMS = { Hispo = true, Lupus = true },
    -- 0.4.75: forms with a beast HURT sound (acute hits / new wounds). The
    -- Crinos joins for pain only: its attack, sniff and death cues stay as
    -- they are. Whines etc. slot in here per form once the assets exist.
    PAIN_FORMS = { Hispo = true, Lupus = true, Crinos = true },
    pain  = "WTAGarou_WolfBark",
    attack = "WTAGarou_WolfAttack",
    -- 0.4.19: per-form overrides. Hispo bites and yelps with its own bark;
    -- Lupus keeps the WolfMod pair above. WTAGarou.WolfSounds.forForm(form, key).
    BY_FORM = {
        Hispo  = { attack = "WTAGarou_HispoBark", pain = "WTAGarou_HispoBark" },
        Crinos = { pain = "WTAGarou_CrinosGrowl" },
    },
    fall  = "WTAGarou_WolfFallOver",
    sniff = "WTAGarou_WolfSniff",
    death = "WTAGarou_WolfDeath",
    SNIFF_INTERVAL_MIN = 10,
    SNIFF_INTERVAL_MAX = 20,
    -- Seconds between pain barks. A grab/bite raises OnPlayerGetDamage many
    -- times in a row; 0.4.12 barked on every one and the emitter culled the
    -- pile-up into silence.
    PAIN_COOLDOWN = 1.5,
    -- 0.4.17: OnPlayerGetDamage also fires every tick for BLEEDING,
    -- INFECTION, HUNGRY, THIRST, SICK, HEAVYLOAD, POISON, LOWWEIGHT... A wolf
    -- with a wound barked on every one (a bark every 0.8 s until the form
    -- changed). Only these acute, one-off damage types yelp.
    PAIN_TYPES = { WEAPONHIT = true, FALLDOWN = true, CARHITDAMAGE = true, FIRE = true },
}
-- 0.4.41: reaction to a silver burn application (Oct 6 request: "a sound
-- should play once per silver burn application: the vanilla ouch for Homid
-- and Glabro, the Crinos growl, the Hispo growl, the wolf growl for Lupus").
-- VOICE entries are vanilla player voice events (IsoPlayer.playerVoiceSound,
-- already on the game's own volume); the rest are mod OGG cues.
WTAGarou.SilverCue = {
    BY_FORM = {
        Homid  = "PainFromScratch",
        Glabro = "PainFromScratch",
        Crinos = "WTAGarou_CrinosGrowl",
        Hispo  = "WTAGarou_HispoGrowl",
        Lupus  = "WTAGarou_WolfGrowl",
    },
    VOICE = { PainFromScratch = true },
    -- Seconds between cues; a weapon volley or a multi-part contact burn
    -- (necklace touching Neck and Chest the same scan) reacts once.
    COOLDOWN = 1.0,
    WARNING_SECONDS = 3,
}
function WTAGarou.SilverCue.forForm(form)
    local t = WTAGarou.SilverCue.BY_FORM
    return t[tostring(form)] or t.Homid
end
function WTAGarou.SilverCue.isVoice(name)
    return WTAGarou.SilverCue.VOICE[tostring(name)] == true
end

-- Sound name for `key` ("attack", "pain", ...) in `form`; BY_FORM first.
function WTAGarou.WolfSounds.forForm(form, key)
    local W = WTAGarou.WolfSounds
    local o = form and W.BY_FORM and W.BY_FORM[form] or nil
    if o and o[key] then return o[key] end
    return W[key]
end

-- Body traits handled by the Java runtime (TraitsRuntime), per form.
-- rawMeat: uncooked "dangerous" food adds no poison for a Garou (any form).
-- paws:    the engine's barefoot foot-scratch loop is skipped, and the
--          15% no-shoes speed penalty is compensated in the multipliers.
-- walk/run/sprint/sneak multiply the engine's WalkSpeed/RunSpeed animation
-- variables after the vanilla calculation; turn multiplies getTurnDelta.
-- These are gameplay-speed levers: IsoGameCharacter.setSpeedMod is only read
-- by zombie code in B42.20.2 and never moved a player. Values are first
-- guesses for the 0.4.13 playtest.
-- stride (0.4.60): root-motion multiplier for the scaled bipeds. The model is
-- drawn modelScale times bigger, so each animated step is that much longer
-- on screen, but the engine moved the character by the unscaled amount: the
-- feet slid ("Crinos movement is a tad slidey"). stride = modelScale makes
-- the ground covered match the drawn stride (Java StrideRuntime, locomotion
-- states only). Net speed = cadence (walk/run/...) x stride, so the cadence
-- multipliers below were lowered: a bigger body takes slower, longer steps.
--   Glabro: 0.95 x 1.24 = 1.18 walk/run, 0.92 x 1.24 = 1.14 sprint (was 1.10)
--   Crinos: 0.90 x 1.44 = 1.30 walk/run/sneak, 0.85 x 1.44 = 1.22 sprint (was 1.20 / 1.15)
-- Wolves keep stride 1: their gait tuning is confirmed and locked.
WTAGarou.Traits = {
    RawMeatImmune = true,
    Homid  = { paws = false, walk = 1.00, run = 1.00, sprint = 1.00, sneak = 1.00, turn = 1.00, stride = 1.00 },
    Glabro = { paws = true,  walk = 0.95, run = 0.95, sprint = 0.92, sneak = 0.95, turn = 1.00, stride = 1.24 },
    -- 0.4.68: scaled model, stride follows; cadence dropped so the net speed
    -- stays where it was accepted (1.30 walk/run, 1.21 sprint, 1.30 sneak).
    -- 0.4.69: 1.65x (0.79 x 1.65 = 1.30, 0.73 x 1.65 = 1.20).
    Crinos = { paws = true,  walk = 0.79, run = 0.79, sprint = 0.73, sneak = 0.79, turn = 1.00, stride = 1.65 },
    -- Wolves: faster than the bipeds in every gait. Sneak is scaled so a
    -- crouched Lupus covers ground at about a human jog (human sneak-walk is
    -- roughly 40% of a jog, hence ~2.4). Turn: the wolf gets no animation-
    -- driven rotation, so >1 is needed to feel like the human turn rate.
    Hispo  = { paws = true,  walk = 1.30, run = 1.25, sprint = 1.15, sneak = 2.00, turn = 1.30 },
    Lupus  = { paws = true,  walk = 1.40, run = 1.35, sprint = 1.25, sneak = 2.40, turn = 1.60 },
}
function WTAGarou.TraitsFor(formName)
    local t = WTAGarou.Traits[formName] or WTAGarou.Traits.Homid
    return t
end

-- EXPERIMENTAL (0.4.13): the primary-hand item is drawn at the wolf's jaw
-- (Bip01_Jaw) instead of being hidden, in Lupus and Hispo.
WTAGarou.EnableMouthCarry = true
-- 0.4.17: extra rotation (degrees, x y z) and offset (metres, x y z) applied
-- to the jaw-carried item AFTER the engine's own bone/attachment transform,
-- in the item's local space. The default turns the tool 90 degrees so it
-- lies sideways across the muzzle. Tune here and reload; no Java rebuild.
-- 0.4.19: the jaw bone's local Y runs along the muzzle and Z points up
-- (measured from the wolf GLB). {0,90,0} spun the tool around its own
-- handle, so the blade turned sideways while the handle still pointed
-- forward. Rotating about Z lays the handle across the jaws, perpendicular
-- to the head bone. Flip the sign to swap which side the head hangs on.
WTAGarou.MouthCarry = {
    rotate = { 75.0, 0.0, 90.0 },
    offset = { 0.1, 0.05, 0.0 },
    pivot = { 0.0, 0.0, 0.0 },
}

-- ===========================================================================
-- WOLF ATTACHMENT TUNING (0.4.22 / 0.4.23) - the one place to edit:
--
--   WTAGarou.MouthCarry   the jaw-carried item          (above)
--   WTAGarou.Saddlebag    the saddlebag bag mesh         (below)
--   WTAGarou.WolfSlots    hotbar / secondary items on the wolf (below)
--   WTAGarou.Harness      the harness stand-in           (below)
--   WTAGarou.WolfGait     wolf walk/run animation speed  (below)
--
-- All of them are pushed to the Java side before every wolf request, so an
-- edit here needs NO Java rebuild. In game: Garou testing panel ->
-- "Reload defs" (or /garou reload) re-reads this file and re-applies them;
-- then shift out of and back into a wolf form (or Wolf OFF / Wolf ON).
--
-- Units: rotate = degrees about the item's own X, Y, Z (applied after the
-- engine's bone transform, in the item's local space); offset = metres in
-- that same local space. 0.05 is five centimetres; 5.0 is five METRES.
-- EXCEPTION: WolfSlots.offset is CHARACTER-space (X sideways, Y up,
-- Z forward/back). WolfSlots.pivot is ITEM-local, AFTER its imported/bone
-- orientation. Y/Z can therefore appear exchanged on a rotated tool.
-- They are not interchangeable vectors. Existing tuned values are preserved.
--
-- The saddlebag's BASE placement (bone, base offset/rotation, mesh scale)
-- lives in scripts/wtagarou_models.txt (model WTAGarou_Saddlebags, attachment
-- WTAGarou_Saddlebags: offset x y z, rotate) and the bone in Java
-- (WolfRuntime.SADDLEBAG_BONE = Bip01_Spine2; Spine1 is the next joint back,
-- Spine3 the next forward). Script edits need a game restart; the values
-- below are ADDED on top and only need a reload + reshift.
-- ===========================================================================
WTAGarou.Saddlebag = {
    -- Raised 4 cm on the local up axis (playtest: "too far down"); forward/
    -- back on the spine is offset[2] if the local Y runs along the spine,
    -- otherwise offset[1]. Test one axis at a time with a big value (0.3)
    -- to learn which is which, then dial it in.
    rotate = { 0.0, 0.0, 0.0 },
    offset = { 0.0, 0.1, 0.0 },
    -- 0.4.23: extra uniform size on top of the model script (1.0 = as is,
    -- 1.3 = thirty percent bigger). Reload defs + reshift, no restart.
    scale = 1.0,
    pivot = { 0.0, 0.0, 0.0 },
}

-- ===========================================================================
-- WOLF HOTBAR SLOTS (0.4.23): items on the hotbar (Back, Belt Left/Right,
-- holsters ...) and the secondary-hand item are DRAWN on the wolf instead of
-- hidden, pinned to the spine like the saddlebag.
--
-- Keys: the hotbar LOCATION id as shown in the hotbar tooltip ("Back",
-- "Belt Left", ...) - the client resolves it to the engine attachment name
-- at runtime - or that attachment name directly, or "secondary" for the
-- secondary-hand item. Any attached item WITHOUT a rule stays hidden and the
-- console prints ONE line per name:
--   [WTAGarou Java][Slot] hidden on the wolf (no WTAGarou.WolfSlots rule): attachment="..."
-- Copy that attachment name in as a new key (Reload defs + reshift). The
-- Garou testing panel Status button lists them too (hiddenAttachments).
--
-- Units: offset = metres in CHARACTER space (X sideways, Y UP, Z forward/
-- back; the sign of X and Z is unverified - test one axis at a time with a
-- big value such as 0.3), scaled with the body. rotate = degrees about the
-- item's own axes, applied after the bone. bone defaults to BONE.
-- Placement wishes (September 27 playtest): Back above the saddlebags and to
-- the right; Belt Left/Right either side of the spine just behind the bags;
-- secondary in front of the bags and to the left.
--
-- 0.4.24 - attachment names seen in the September 27 console: belt_left,
-- belt_right (matched by the "Belt Left"/"Belt Right" keys) and shovel_back
-- (hidden: the engine names the Back attachment per item type). Java now
-- also matches a key by SUFFIX, so the "Back" rule covers shovel_back,
-- bag_back, rifle_back ... and no per-type key is needed.
--
-- pivot (0.4.24) = the grip point on the ITEM, metres in the item's own
-- space, the same axes rotate turns about. Most item meshes have their
-- origin at the tip of the handle, so with pivot {0,0,0} a bobbing spine
-- swings the whole item around its handle tip. Set pivot to the point on
-- the item that should sit on the strap (for an axe roughly the middle of
-- the handle, e.g. { 0.0, 0.35, 0.0 } if the handle runs along +Y) and the
-- item turns about THAT point instead. Test one axis at a time.
-- ===========================================================================
WTAGarou.WolfSlots = {
    ENABLED = true,
    BONE = "Bip01_Spine2",
    ["Back"]          = { rotate = { 0.0, 90.0, -8.0 }, offset = {  0.0, 0.07,  0.0 }, pivot = { -0.06, 0.08, -0.06 } },
    ["Belt Left"]     = { rotate = { 0.0, 0.0, 0.0 }, offset = { 0.0, 0.05, 0.0 }, pivot = { 0.12, -0.02, 0.02 } },
    ["Belt Right"]    = { rotate = { 0.0, 180.0, 0.0 }, offset = {  0.0, 0.08, 0.0 }, pivot = { 0.1, 0.07, -0.02 } },
    ["Holster Left"]  = { rotate = { 0.0, 0.0, 0.0 }, offset = { -0.14, 0.06, -0.22 }, pivot = { 0.0, 0.0, 0.0 } },
    ["Holster Right"] = { rotate = { 0.0, 0.0, 0.0 }, offset = {  0.14, 0.06, -0.0 }, pivot = { 0.024, -0.1, -0.05 } },
    ["secondary"]     = { rotate = { 0.0, 0.0, 0.0 }, offset = { -0.08, 0.02,  0.0 }, pivot = { 0.0, -0.1, 0.1 } },
}

-- The harness stand-in (0.4.23) appears in a wolf form while ANY hotbar or
-- secondary-hand item is attached OR a container is worn (the saddlebags
-- then hang from the harness, not a lone strap), and disappears only when
-- there is neither. Bare wolf = nothing attached, no container.
-- Authored skinned GLB follows the wolf bones in bind space. Legacy rigid
-- tunables retained for compatibility only; not sent to the skinned renderer.
WTAGarou.Harness = {
    rotate = { 0.0, 0.0, 0.0 },
    offset = { 0.0, 0.00, 0.00 },
    scale  = 1.0,
    pivot = { 0.0, 0.0, 0.0 },
}
WTAGarou.EnableHarnessVisual = true
WTAGarou.HarnessAttachment = "WTAGarou_Harness"
WTAGarou.HarnessItem = "WTAGarou.WolfHarnessVisual"
WTAGarou.WolfGait = {
    -- Wolf walk/jog/sprint clips play this many times SLOWER than the
    -- stride-matched clock (1.0 = feet never slide, 2.0 = half speed). The
    -- movement speed itself is untouched.
    CYCLE_SLOWDOWN = 1.15,
    -- Attack clip playback only: independent of gait slowdown and damage.
    -- 1.5 = a bite animation takes two thirds of its authored duration.
    ATTACK_SPEED = 1.5,
    -- Visual clip multiplier, independent of bites and movement. Lower is slower.
    STOMP_SPEED = 1.0,
    -- Diagnostic toggle for the "wolf swings around the origin and dips into
    -- the floor when I hold Ctrl to turn while running" report. The wolf's
    -- movement marker keeps its authored rest offset by default; the console
    -- line "[WTAGarou Java][Gait] Wolf_run marker ... rests at (x, y, z)"
    -- shows that offset. If it is not near (0, 0, 0), set this to true
    -- (Reload defs + reshift) and see whether the swing goes away.
    MARKER_AT_ORIGIN = false,
    -- 0.4.24: transition nodes (IdleToRun, RunToStop, WalkToTurn180 ...) are
    -- one-shot root-motion clips, not cycles. Stride-matching stretched
    -- Bob_RunToStop from 1.0 s to the 4 s cap and scaled its travel with it:
    -- the wolf coasted for seconds after the keys were released and a
    -- Ctrl-strafe during that stop swung it around. true = transitions keep
    -- the human clip's timing and travel 1:1 and the wolf cycle is tiled
    -- across them; false = the 0.4.23 behaviour.
    TRANSITIONS_KEEP_HUMAN_TIMING = true,
}
-- Shift cues (0.4.18, author-supplied .ogg in common/media/sound; the
-- sound bank is scripts/wtagarou_sounds.txt). Each plays ONCE per trigger;
-- client/WTAGarouShiftSounds.lua stops the previous instance of the same
-- cue first so they never pile up.
WTAGarou.ShiftSounds = {
    CHANNEL_START   = "WTAGarou_FormShift",        -- any shift channel starts
    CRINOS_COMPLETE = "WTAGarou_CrinosShift",      -- the Crinos shift lands
    COUNTDOWN       = "WTAGarou_CrinosShiftTimer", -- forced-Crinos timer starts
    -- 0.4.19: CHANNEL_START restarts every REPEAT_SECONDS while the channel
    -- is still running. 0.4.67: the second pass comes in sooner than the
    -- 2.95 s clip length and rings over the first one's tail (it uses its
    -- own cue slot, so the first instance is not cut). The last instance is
    -- left to finish when the channel ends.
    -- 0.4.84: the channel bed is one long sustained rustle (8 s clip, longer
    -- than the 6 s BASE channel), so the repeat is only a safety net for a
    -- channel that outlasts it. When the channel ends the bed is faded out
    -- over CHANNEL_FADE_SECONDS and stopped (client presentation), so the
    -- rustle blends into the end cue instead of ringing on.
    REPEAT_SECONDS  = 7.5,
    -- 0.4.86: on completion the bed and the voice keep ringing under the
    -- whoosh and fade over CHANNEL_FADE_SECONDS; a cancel cuts them in
    -- CANCEL_FADE_SECONDS.
    CHANNEL_FADE_SECONDS = 1.0,
    CANCEL_FADE_SECONDS  = 0.2,
    -- 0.4.84: the channel VOICE follows the current form (the bed and the
    -- completion whoosh are the same for every shift):
    --   target Crinos, or currently Crinos  -> CRINOS_START (own Crinos growl)
    --   currently Lupus / Hispo             -> that form's growl
    --      (WTAGarou.SilverCue.BY_FORM) at WOLF_VOICE_GAIN (0.4.86)
    --   currently Homid / Glabro            -> the vanilla pain voice of the
    --      character (IsoPlayer:transmitPlayerVoiceSound(suffix); the voice
    --      prefix picks male/female), cycling HUMAN_PAIN_SUFFIXES.
    -- The voice repeats every VOICE_REPEAT_SECONDS while the channel runs.
    WOLF_VOICE_GAIN = 0.4,
    VOICE_REPEAT_SECONDS = 2.4,
    -- Oct 24 playtest: the wound screams were melodramatic; these are the
    -- vanilla discomfort / strain voices (VoiceMale* / VoiceFemale* events,
    -- scripts/sounds/player/sounds_player_voice_*.txt).
    HUMAN_PAIN_SUFFIXES  = { "PainMoodle", "CorpseHighEffort", "Exercise", "CorpseLowEffort", "PainFromHitBlunt" },
    -- 0.4.19: the 0-Rage forced return to Homid plays CHANNEL_START;
    -- 0.4.92: CHANNEL_END plays at the same moment and the bed rings out
    -- over CHANNEL_FADE_SECONDS. Set FORCED_HOMID_SECONDS > 0 to delay the
    -- whoosh instead.
    FORCED_HOMID    = "WTAGarou_FormShift",
    FORCED_HOMID_SECONDS = 0,
    -- 0.4.67: played once when a channel completes (perform), any form, on
    -- top of the Crinos roar. CHANNEL_END_GAIN multiplies the normal slider
    -- factor so it sits under the other cues.
    CHANNEL_END      = "WTAGarou_FormShiftEnd",
    CHANNEL_END_GAIN = 1.0,    -- 0.4.88: no in-logic attenuation (0.4.70 had 0.75); the file carries its level
    -- 0.4.67: a channel INTO Crinos opens with this instead of CHANNEL_START
    -- (one play, no repeat: the clip is 5.9 s). Its bank volume sits
    -- slightly under CRINOS_COMPLETE, which still plays when the channel
    -- lands. CHANNEL_END_GAIN applies to the quiet end cue as for any form.
    CRINOS_START     = "WTAGarou_CrinosShiftStart",
}
-- Played once when the forced-Crinos countdown starts (was the growl).
WTAGarou.CrinosCountdownSound = WTAGarou.ShiftSounds.COUNTDOWN

-- Worn containers on a wolf render as a saddlebag attachment (experimental;
-- own generated bag mesh on the wolf spine since 0.4.89; placement tuned in game).
WTAGarou.EnableSaddlebagVisual = true
WTAGarou.SaddlebagAttachment = "WTAGarou_Saddlebags"
WTAGarou.SaddlebagItem = "WTAGarou.WolfSaddlebagVisual"

WTAGarou.Rage = {
    MAX      = 100,
    START    = 50,
    -- Per SECOND, applied with real elapsed time (not per tick).
    -- 0.4.14: Rage is situational. A healthy Garou in Homid, Glabro, Hispo
    -- or Lupus neither gains nor loses Rage by standing there; it moves only
    -- with moodles, damage taken/dealt and howling. Crinos is the one form
    -- that ticks on its own (berserk burns 1 Rage every second).
    REGEN_PER_SECOND = {
        Homid  =  0.00,
        Lupus  =  0.00,
        Glabro =  0.00,
        Hispo  =  0.00,
        Crinos = -1.00,
    },
    ON_DAMAGE_TAKEN = 0.75,
    -- 0.4.44: halved from 0.20 (Oct 6: "I find myself having to change to
    -- crinos pretty often. Maybe turn it down by half.").
    -- 0.4.68: dealing damage now SPENDS Rage (was +0.15 since 0.4.46): the
    -- beast is fed by the violence, not stoked by it.
    -- 0.4.70: a flat cost per LANDED hit (Oct 18: "if an attack hits,
    -- -0.5 rage; so a crinos dealing overkill damage doesn't burn through
    -- rage, but simply hitting enemies does"). Not scaled by damage.
    ON_HIT_DEALT = -0.25,   -- 0.4.82: was -0.5; user: "don't wanna make it too easy to resist crinos in tense combat"
    -- Moodles, per level per second. Fear (Panic) is weighted so a terrified
    -- Garou builds Rage fastest; the rest are ordinary negative pressure.
    ON_MOODLE_LEVEL_PER_SECOND = 0.08,
    -- 0.4.20: Stress 1.0 meant a level-1 Tense moodle alone built 4.8 Rage a
    -- minute (September 26 playtest, Lupus); mild stress is now 0.4 (about
    -- 2 Rage a minute at Tense, 8 at Stressed 4). The server prints the
    -- active moodle pressure every 30 s so the source of a climb is visible.
    MOODLE_WEIGHTS = {
        Panic = 2.0, Stress = 0.4, Pain = 1.0, Injured = 1.0, Bleeding = 1.0,
        Hungry = 1.0, Thirst = 1.0, Sick = 0.75,
        HasACold = 0.5, Wet = 0.5, Hyperthermia = 0.75, Hypothermia = 0.75,
        Windchill = 0.5, HeavyLoad = 0.5, Drunk = 0.5, Uncomfortable = 0.5,
        NoxiousSmell = 0.5, Angry = 1.5,
    },
    -- Sad / depressed moodles drain Rage instead (per level per second).
    -- 0.4.68: exhaustion (Endurance) and drowsiness (Tired) drain Rage too;
    -- a spent body cannot hold the beast up.
    SAD_MOODLES = { Unhappy = 1.0, Bored = 0.5, Endurance = 1.0, Tired = 0.75 },
    -- 0.4.19: 0.08 drained a whole Crinos in under three minutes of reading
    -- with the Sad moodle up; 0.03 is a slow bleed (Unhappy 4 = 0.12/s).
    SAD_MOODLE_LEVEL_PER_SECOND = 0.03,
    -- 0.4.45 contentment. Rage drifts toward the character's BASELINE (see
    -- WTAGarou.Auspices; 50 until the auspice is locked in) when the body is
    -- looked after. CONTENT_PULL_PER_SECOND is now 70% of the old rate; the
    -- weights are fractions of it (Oct 7 design): no Hungry moodle 0.75, no
    -- Thirst moodle 0.75, the Well Fed (FoodEaten) moodle on top 0.5. Fed
    -- and watered drifts at 0.315/s, plus Well Fed makes 0.42/s.
    -- Hungry and thirsty without Well Fed gives no contentment drift.
    CONTENT_PULL_PER_SECOND = 0.21, -- 0.4.46: all three contributions reduced by 30%
    -- SKIP_FORMS: forms whose Rage ignores the drift (empty = every form,
    -- as the old well-fed pull did). Note Crinos burns 1/s while fed and
    -- watered drifts 0.315/s back toward the baseline; set Crinos = true
    -- here if the war form should burn at its full rate regardless.
    -- 0.4.70: the drift no longer pauses for the whole frenzy band (the
    -- old PAUSE_ABOVE = 95); it pauses only while the 100-Rage countdown
    -- is running (WTAGarou.ContentPullPaused), so a fed, watered Garou at
    -- 98 Rage, or one who just Resisted, drifts back toward the baseline.
    CONTENTMENT = { NO_HUNGER = 0.75, NO_THIRST = 0.75, WELL_FED = 0.5, SKIP_FORMS = {} },
    -- 0.4.69 baseline bracket (Oct 18 design). Inside a band around the
    -- baseline the contentment drift is halved (SLOW), so a fed and watered
    -- Garou settles on the baseline more slowly the worse the body feels.
    -- The band's half-width is PER_STACK x the number of negative-moodle
    -- stacks: the sum of the engine moodle LEVELS (0-4) across every
    -- category in MOODLE_WEIGHTS and SAD_MOODLES, whichever way they move
    -- Rage. Capped at MAX_STACKS: 10 stacks = 20 Rage each side (baseline
    -- 70 -> the band is 50..90). Positive moodles (Well Fed) are not stacks.
    BASELINE_BRACKET = { PER_STACK = 2, MAX_STACKS = 10, SLOW = 0.5, BASE_HALF_WIDTH = 0 },
    -- 0.4.69 Crinos escalation: the passive drain grows by STEP for every
    -- full EVERY_SECONDS the war form has been held (-1/s -> -2/s after 90 s
    -- -> -3/s after 180 s; Berserker -0.5/s -> -1.5/s -> -2.5/s). Leaving
    -- Crinos resets it; the clock restarts from zero on the next shift in.
    CRINOS_ESCALATION = { EVERY_SECONDS = 90, STEP = -1.0 },
    BASELINE_DEFAULT = 50,
    HOWL_PULL       = 20,
    HOWL_COST       = 0,
    -- Forced Crinos: 100 Rage held for FORCE_CRINOS_SECONDS shifts you
    -- (channel FORCE_CRINOS_CHANNEL). Dropping below FORCE_CRINOS_CANCEL_BELOW
    -- cancels the countdown.
    FORCE_CRINOS_SECONDS = 10.0, -- matches the ten-second alarm; later Resist warnings still shorten
    FORCE_CRINOS_CANCEL_BELOW = 95,
    FORCE_CRINOS_CHANNEL = 0.25,
    -- 0.4.21 Resist (user design, September 26 evening): the countdown can
    -- be cancelled with the Resist button / keybind / radial slice. Every
    -- successful Resist shortens the NEXT countdown: one second per Resist
    -- while that keeps it at or above LOG_BELOW, then logarithmically toward
    -- MIN_SECONDS (never reached). After a Resist a HIDDEN rest interval,
    -- uniformly random in [REST_MIN_MULT, REST_MAX_MULT] x the countdown just
    -- resisted, runs; when it ends and Rage is still >= FORCE_CRINOS_CANCEL_BELOW
    -- the next, shorter countdown starts. Rage under 95 or entering Crinos
    -- ends the cycle and the countdown length resets to FORCE_CRINOS_SECONDS.
    RESIST = {
        LINEAR_STEP   = 2.0, -- 0.4.69: two seconds shorter per Resist (was 1.0)
        LOG_BELOW     = 2.0,
        MIN_SECONDS   = 0.5,
        REST_MIN_MULT = 3,
        REST_MAX_MULT = 12,
    },
    -- 0.4.39 Berserker breed (lore: Metis; saved trueForm = "Glabro"):
    -- Crinos burns half as fast, needs no Rage floor to enter (cost stays
    -- 10) and cannot be LEFT voluntarily while Rage is above its lock line.
    -- Every other Garou is locked inside Crinos above CRINOS_LOCK_ABOVE, so
    -- a forced 100-Rage Crinos holds you about 25 s before you can shift out.
    CRINOS_DRAIN_BERSERKER = -0.50,
    CRINOS_LOCK_ABOVE = 75,
    -- 0.4.58 (user, Oct 13): 35 made timing a Crinos->Glabro exit fiddly;
    -- Metis may leave Crinos once Rage is at or below 55.
    CRINOS_LOCK_ABOVE_BERSERKER = 55,
    -- Any form other than the chosen true form reverts when Rage reads zero.
    DEPLETED_FORM = "Homid", -- legacy; BaseForm(saved data) selects Homid/Lupus/Glabro
    -- 0.4.19: Crinos counts as dry once Rage shows 0 on the panel (floor),
    -- not only at exactly <= 0. Well-fed pulls toward 60 could hold 0.x Rage
    -- for many seconds while the HUD already read 0 and nothing happened.
    DEPLETED_BELOW = 1,
    -- 0.4.75: seconds Rage must stay under DEPLETED_BELOW (and seconds since
    -- the last shift) before the dry revert fires. Shifting at exactly the
    -- cost no longer bounces straight back while Rage is still climbing.
    DEPLETED_HOLD_S = 2.0,
}

-- 0.4.45 auspices ("Baseline Rage" on the Werewolf Startup panel). The
-- panel shows the number; the moon and the lore name live in the tooltip.
-- Locked in together with true form and coat; until then BASELINE_DEFAULT.
WTAGarou.Auspices = {
    { key = "Ragabash", moon = "New Moon",      baseline = 30 },
    { key = "Theurge",  moon = "Crescent Moon", baseline = 40 },
    { key = "Philodox", moon = "Half Moon",     baseline = 50 },
    { key = "Galliard", moon = "Gibbous Moon",  baseline = 60 },
    { key = "Ahroun",   moon = "Full Moon",     baseline = 70 },
}
function WTAGarou.AuspiceByKey(key)
    for _, a in ipairs(WTAGarou.Auspices) do if a.key == key then return a end end
    return nil
end
function WTAGarou.AuspiceByBaseline(value)
    value = tonumber(value)
    for _, a in ipairs(WTAGarou.Auspices) do if a.baseline == value then return a end end
    return nil
end
function WTAGarou.ValidAuspice(key)
    return WTAGarou.AuspiceByKey(key) ~= nil
end
-- The Rage value this character drifts toward (contentment, howling).
function WTAGarou.BaselineRage(data)
    if data and data.auspiceLocked == true then
        local a = WTAGarou.AuspiceByKey(data.auspice)
        if a then return a.baseline end
    end
    return WTAGarou.Rage.BASELINE_DEFAULT or 50
end
-- Contentment drift per second toward the baseline (pure).
-- 0.4.70: the contentment drift stands still only while the 100-Rage
-- countdown is actually running (d.crinosCountdownAt set) or Rage sits on
-- MAX about to start it (the tick drifts before it checks the countdown,
-- so without this a fed Garou would be pulled to 99.7 and never start
-- one). A Resist clears the countdown and starts the hidden rest, during
-- which the drift works again: fed and watered, Rage leaves the band
-- (< 95) in about 16 s and the Resist cycle ends by itself.
function WTAGarou.ContentPullPaused(data)
    if data == nil then return false end
    if data.crinosCountdownAt ~= nil then return true end
    if data.resistRestUntil ~= nil then return false end   -- hidden rest: no countdown can start yet
    return (data.rage or 0) >= (WTAGarou.Rage.MAX or 100)
end

function WTAGarou.ContentPullPerSecond(hungry, thirsty, wellFed, form)
    local R, C = WTAGarou.Rage, WTAGarou.Rage.CONTENTMENT or {}
    if form and C.SKIP_FORMS and C.SKIP_FORMS[form] then return 0 end
    local mult = 0
    if not hungry then mult = mult + (C.NO_HUNGER or 0) end
    if not thirsty then mult = mult + (C.NO_THIRST or 0) end
    if wellFed then mult = mult + (C.WELL_FED or 0) end
    return (R.CONTENT_PULL_PER_SECOND or 0) * mult
end

-- 0.4.46: natural fur provides a floor at the midpoint of each thermal
-- node's native insulation UI range. Clothing above that floor is kept.
-- Wind, rain, body wetness and body temperature remain vanilla.
WTAGarou.Fur = { INSULATION_UI = 0.5, FORMS = { Crinos=true, Hispo=true, Lupus=true } }
function WTAGarou.FurInsulation(form)
    return WTAGarou.Fur.FORMS[form] and WTAGarou.Fur.INSULATION_UI or 0
end

-- 0.4.21: countdown length after `resists` successful Resists (pure).
-- Linear phase: D - n while that stays >= LOG_BELOW. Logarithmic phase:
-- MIN + (LOG_BELOW - MIN) / (1 + ln(1 + k)), k = Resists past the linear
-- phase; it shrinks forever but never reaches MIN_SECONDS (0.5 s).
function WTAGarou.ResistCountdownSeconds(resists, base)
    local R = WTAGarou.Rage
    local C = R.RESIST or {}
    local D = tonumber(base) or R.FORCE_CRINOS_SECONDS or 10
    local step, low, min = C.LINEAR_STEP or 1, C.LOG_BELOW or 2, C.MIN_SECONDS or 0.5
    local n = math.max(0, math.floor(tonumber(resists) or 0))
    local linearSteps = math.max(0, math.floor((D - low) / step + 1e-9))
    if n <= linearSteps then return D - n * step end
    local startLog = D - linearSteps * step   -- >= low, first value of the log phase
    local k = n - linearSteps
    return min + (startLog - min) / (1 + math.log(1 + k))
end

-- 0.4.21: hidden rest interval after a Resist, uniform in
-- [REST_MIN_MULT, REST_MAX_MULT] x the countdown just resisted.
function WTAGarou.ResistRestSeconds(countdown, roll)
    local C = (WTAGarou.Rage.RESIST) or {}
    local lo, hi = C.REST_MIN_MULT or 3, C.REST_MAX_MULT or 12
    local r = tonumber(roll)
    if r == nil then
        if ZombRandFloat then r = ZombRandFloat(0, 1) else r = math.random() end
    end
    r = math.max(0, math.min(1, r))
    return (tonumber(countdown) or 10) * (lo + (hi - lo) * r)
end

-- Clothing damage profile for a destination form (nil: clothes untouched).
function WTAGarou.ShiftStrip.profileFor(formName)
    return WTAGarou.ShiftStrip.FORMS[tostring(formName)]
end

-- Condition points a shift to `formName` takes from a tearable item.
-- Whole points when >= 1; a fraction (accumulated per item) when below 1.
-- opts.forced applies the profile's forcedMultiplier.
function WTAGarou.ShiftStrip.damageFor(formName, opts)
    local prof = WTAGarou.ShiftStrip.profileFor(formName)
    if not prof then return 0 end
    local pts = (prof.fraction or 0) * WTAGarou.ShiftStrip.TSHIRT_CONDITION
    if opts and opts.forced and prof.forcedMultiplier then pts = pts * prof.forcedMultiplier end
    if pts <= 0 then return 0 end
    if pts >= 1 then return math.floor(pts + 0.5) end
    return math.floor(pts * 1000 + 0.5) / 1000
end

-- Newcomer-friendly name for the panel and radial; lore name stays the key.
function WTAGarou.DisplayName(formName)
    local fd = WTAGarou.FormData and WTAGarou.FormData[tostring(formName)]
    return (fd and fd.displayName) or tostring(formName)
end

-- Endurance loss refunded per form (0 = human stamina, 1 = tireless).
WTAGarou.EnduranceRefund = {
    Homid = 0.00, Glabro = 0.35, Hispo = 0.55, Lupus = 0.70, Crinos = 0.90,
}

-- Knockdown / trip resistance (chance the fall is shrugged off). Crinos and
-- Hispo carry the most mass; both are near-impossible to put on the floor.
WTAGarou.Stability = {
    Homid = 0.00, Glabro = 0.00, Hispo = 0.95, Lupus = 0.00, Crinos = 0.97,
}

-- 0.4.68: poise. Chance that a MELEE hit's flinch (the "HitReaction" stagger
-- and its shove) is shrugged off; damage, scratches and bites still land and
-- ranged hits are never filtered. Crinos is close to, but not, uninterruptible.
WTAGarou.Poise = {
    Homid = 0.00, Glabro = 0.00, Hispo = 0.00, Lupus = 0.00, Crinos = 0.85,
}

-- 0.4.75: the Garou's own voice (the vanilla FMOD voice: pain grunts,
-- exertion, shouts) per form, as an offset on the character's recorded
-- Voice Pitch (creation slider -100..100; FMOD parameter
-- CharacterVoicePitch). Homid and Lupus restore the default, Glabro and
-- Hispo drop, Crinos bottoms out. The default is learned once, in a base
-- form, and kept in mod data so a shifted voice is never mistaken for it.
WTAGarou.VoicePitch = { Homid = 0, Glabro = -45, Hispo = -45, Lupus = 0, Crinos = -100 }
function WTAGarou.VoicePitchFor(base, form)
    local v = (tonumber(base) or 0) + (WTAGarou.VoicePitch[form] or 0)
    return math.max(-100, math.min(100, v))
end
-- Applies to one player (local or a remote copy: each client pitches the
-- copies it hears). Returns the pitch set, or nil when nothing was done.
function WTAGarou.ApplyVoicePitch(player, form, d)
    if not (player and player.getVoicePitch and player.setVoicePitch) then return nil end
    if not d then
        if WTAGarou.GetData then d = WTAGarou.GetData(player)
        else
            local md = player.getModData and player:getModData()
            if not md then return nil end
            md.WTAGarou = md.WTAGarou or {}; d = md.WTAGarou
        end
    end
    local offset = WTAGarou.VoicePitch[form] or 0
    if d.voicePitch0 == nil then
        if offset ~= 0 then return nil end          -- never learn a default from a shifted voice
        local ok, cur = pcall(function() return player:getVoicePitch() end)
        if not ok or type(cur) ~= "number" then return nil end
        d.voicePitch0 = cur
    end
    local target = WTAGarou.VoicePitchFor(d.voicePitch0, form)
    local ok, cur = pcall(function() return player:getVoicePitch() end)
    if ok and type(cur) == "number" and math.abs(cur - target) < 0.5 then return target end
    pcall(function() player:setVoicePitch(target) end)
    return target
end

-- 0.4.72: health pool per form, as the fraction of every ACUTE hit (weapon,
-- bullet, bite, scratch, fall, car) that lands on a body part
-- (Java ToughnessRuntime on BodyPart.AddDamage). Vanilla derives overall
-- health from the parts each tick, so the pool cannot be a bigger number;
-- scaling the intake is the same thing. 0.40 = a 250-point pool: a healthy
-- Crinos survives an average point-blank shotgun blast (about 235 raw) with
-- little left, two head pellets still kill. Bleeding, deep wounds, infection
-- and hunger are NOT scaled: a mauled Crinos still bleeds out at human
-- speed and still needs bandages. Homid and Lupus are human-fragile.
WTAGarou.DamageIntake = {
    Homid = 1.00, Glabro = 0.65, Hispo = 0.65, Lupus = 1.00, Crinos = 0.40,
}
function WTAGarou.DamageIntakeFor(form)
    local v = WTAGarou.DamageIntake[form]
    return (type(v) == "number" and v > 0 and v <= 1) and v or 1.0
end
function WTAGarou.EffectiveHealthFor(form)
    return 100 / WTAGarou.DamageIntakeFor(form)
end

-- 0.4.68: at 1.73x (1.65x since 0.4.69) the Berzerker is too tall for a doorway. Walking upright
-- into one is refused (crouch to pass); a jog or sprint ducks through on its
-- own and the duck is released a tile past the frame unless the player was
-- already crouched. Sprinting into a closed WOODEN door charges through it.
-- 0.4.71: the doorway duck / upright refusal is retired (Java
-- DoorwayRuntime.DUCK_ENABLED=false): the Crinos walks through doorways as
-- vanilla. TALL_FORMS still gates the sprint door charge (WTAGarou.DoorCharge).
WTAGarou.Doorway = {
    TALL_FORMS   = { Crinos = true },
    HINT         = "Too tall for the doorway. Crouch to pass, or jog through.",
    DUCK_RELEASE_TILES = 1.0,   -- distance past the frame before the duck lets go
    DUCK_TIMEOUT_MS    = 2500,  -- safety release if the crossing stalls
}
WTAGarou.DoorCharge = {
    RAGE           = 12,    -- spent on a closed wooden door (0.4.69: +50%, was 8)
    RAGE_LOCKED    = 18,    -- spent on a LOCKED wooden door (0.4.69: +50%, was 12)
    STAMINA        = 0.15,  -- endurance (0..1) spent; not refunded by EnduranceRefund
    STAMINA_LOCKED = 0.225, -- relative: 1.5x
    MAX_TILES      = 2.5,   -- server sanity: door must be within reach of the charger
}
-- 0.4.69: crowd charge. A sprinting Crinos that runs into zombies knocks
-- down the first LIMIT of them inside WINDOW_SECONDS without stumbling
-- (the sprint continues); the next collision inside the window is a
-- vanilla bump, the crowd having stopped it. Java (CrowdChargeRuntime)
-- hooks the engine's bump sequence; forms absent here get vanilla bumps.
WTAGarou.CrowdCharge = {
    Crinos = { limit = 3, windowSeconds = 3.0 },
}
function WTAGarou.CrowdChargeFor(form)
    local rule = (WTAGarou.CrowdCharge or {})[form]
    if not rule then return 0, 0 end
    return rule.limit or 0, rule.windowSeconds or 0
end

function WTAGarou.DoorChargeCost(locked)
    local C = WTAGarou.DoorCharge
    if locked then return C.RAGE_LOCKED, C.STAMINA_LOCKED end
    return C.RAGE, C.STAMINA
end

-- Regeneration ("healing factor"). Crinos closes ordinary wounds and clears
-- bleeding in about 100 seconds even unbandaged. Hispo and Glabro run at roughly
-- a third of that; Lupus keeps the vanilla clock.
--
-- Lore (0.4.18): the Knox virus is a bioweapon engineered by Wyrm-corrupted
-- humans. In the Garou's health panel it reads "Wyrm Infection", and only
-- time spent in Berzerker (Crinos) purges it quickly: five minutes for the
-- whole infection (fifteen in Near-Human/Near-Wolf). Zombie BITES close on
-- the same clock, so a badly bitten Garou has to keep returning to Crinos.
WTAGarou.WyrmInfection = {
    NAME          = "Wyrm Infection",
    PURGE_SECONDS = { Crinos = 300, Hispo = 900, Glabro = 900 },
}
WTAGarou.Regeneration = {
    -- Body-part health restored per second (100 = full part).
    -- .54: 20% lower ordinary healing throughput; bite/Wyrm clocks unchanged.
    -- .68: Crinos 1.6 -> 1.2 and wounds 75 s -> 100 s (healing factor eased).
    HEALTH_PER_SECOND   = { Crinos = 1.2, Hispo = 0.56, Glabro = 0.56 },
    -- Seconds until a scratch/cut/laceration/deep-wound/fracture flag is
    -- cleared once THAT wound has aged in the form.
    CLEAR_WOUNDS_AFTER  = { Crinos = 100, Hispo = 225, Glabro = 225 },
    -- Seconds until a zombie BITE flag is cleared: the Wyrm Infection clock.
    CLEAR_BITES_AFTER   = { Crinos = 300, Hispo = 900, Glabro = 900 },
    -- Wyrm Infection purged per second (100 = the whole infection).
    INFECTION_PER_SECOND = { Crinos = 100 / 300, Hispo = 100 / 900, Glabro = 100 / 900 },
}

-- 0.4.61: non-Crinos channel time is a plateau around the middle of the Rage
-- bar that falls off toward BOTH ends. Within PLATEAU points of the middle
-- (45..55) a shift channels for BASE seconds; from there the time shrinks
-- linearly, reaching FAST once Rage is within FULL_AT points of 0 or 100
-- (<= 20 or >= 80) and staying there. BASE is what the old 10 -> 2 ramp gave
-- at 50 Rage, so the middle of the bar feels as before. Crinos keeps its own
-- fixed snap (CRINOS).
WTAGarou.TransformTime = { BASE = 6.0, FAST = 1.0, PLATEAU = 5, FULL_AT = 20, COOLDOWN = 3.0, CRINOS = 1.0 }
defineTable("Howl", {
    -- 0.4.45: a howl pulls toward the character's baseline (WTAGarou.BaselineRage).
    RAGE_PER_TICK = 1.0,
    TICK_SECONDS = 0.5,
    SERVER_TICK_COOLDOWN = 0.40,
    RADIUS_TILES = HOWL_RADIUS_TILES,
})
WTAGarou.TICKS_PER_SECOND = 30

function WTAGarou.SecondsToTicks(seconds)
    return math.max(1, math.floor((tonumber(seconds) or 1) * WTAGarou.TICKS_PER_SECOND))
end

function WTAGarou.ComputeTransformSeconds(currentRage, targetForm)
    -- Crinos is a snap into berserk: a fixed short channel regardless of Rage.
    if targetForm == "Crinos" and WTAGarou.TransformTime.CRINOS then
        return WTAGarou.TransformTime.CRINOS
    end
    local T = WTAGarou.TransformTime
    local max = tonumber(WTAGarou.Rage.MAX) or 100
    local r = math.max(0, math.min(max, tonumber(currentRage) or 0))
    local mid = max / 2
    local dist = math.abs(r - mid)                       -- 0 at the middle, 50 at either end
    local plateau = tonumber(T.PLATEAU) or 5
    local edge = mid - (tonumber(T.FULL_AT) or 20)       -- distance from the middle where FAST is reached
    local base, fast = tonumber(T.BASE) or 6.0, tonumber(T.FAST) or 1.0
    if dist <= plateau then return base end
    if dist >= edge or edge <= plateau then return fast end
    local t = (dist - plateau) / (edge - plateau)        -- 0 at the plateau edge, 1 at FULL_AT
    return base - (base - fast) * t
end

-- Rage needed to START a shift (Crinos needs 55 but only spends 10).
-- 0.4.39: pass the saved data to honour the Berserker breed, for whom
-- Crinos has no floor beyond its cost.
function WTAGarou.RageRequired(formName, data)
    local fd = WTAGarou.GetForm(formName) or {}
    local cost = tonumber(fd.rageCost) or 0
    if formName == "Crinos" and WTAGarou.IsBerserkerBreed and WTAGarou.IsBerserkerBreed(data) then
        return cost
    end
    return math.max(tonumber(fd.rageRequired) or 0, cost)
end

-- Passive Crinos drain per second for this character (negative).
-- 0.4.69: `heldSeconds` (how long Crinos has been held, server-side) adds
-- CRINOS_ESCALATION.STEP for every full EVERY_SECONDS; nil/0 = base rate.
function WTAGarou.CrinosEscalationSteps(heldSeconds)
    local E = WTAGarou.Rage.CRINOS_ESCALATION or {}
    local every = tonumber(E.EVERY_SECONDS) or 90
    local held = tonumber(heldSeconds) or 0
    if every <= 0 or held <= 0 then return 0 end
    return math.floor(held / every + 1e-9)
end
function WTAGarou.CrinosDrainPerSecond(data, heldSeconds)
    local R = WTAGarou.Rage
    local base
    if WTAGarou.IsBerserkerBreed and WTAGarou.IsBerserkerBreed(data) then
        base = tonumber(R.CRINOS_DRAIN_BERSERKER) or -0.5
    else
        base = tonumber((R.REGEN_PER_SECOND or {}).Crinos) or -1
    end
    local steps = WTAGarou.CrinosEscalationSteps(heldSeconds)
    if steps > 0 then base = base + steps * (tonumber((R.CRINOS_ESCALATION or {}).STEP) or -1) end
    return base
end

-- 0.4.69 baseline bracket (pure). Half-width in Rage points for `stacks`
-- negative-moodle levels, and the multiplier the contentment drift gets at
-- `rage` (SLOW inside the band, inclusive; 1 outside).
function WTAGarou.BaselineBracketHalfWidth(stacks)
    local B = WTAGarou.Rage.BASELINE_BRACKET or {}
    local n = math.max(0, math.floor(tonumber(stacks) or 0))
    n = math.min(n, tonumber(B.MAX_STACKS) or 10)
    return (tonumber(B.BASE_HALF_WIDTH) or 0) + n * (tonumber(B.PER_STACK) or 2)
end
function WTAGarou.BaselinePullMultiplier(rage, baseline, stacks)
    local B = WTAGarou.Rage.BASELINE_BRACKET or {}
    local half = WTAGarou.BaselineBracketHalfWidth(stacks)
    if half <= 0 then return 1 end
    local dist = math.abs((tonumber(rage) or 0) - (tonumber(baseline) or 0))
    if dist <= half + 1e-9 then return tonumber(B.SLOW) or 0.5 end
    return 1
end

-- Rage line above which a Garou cannot shift OUT of Crinos.
function WTAGarou.CrinosLockAbove(data)
    local R = WTAGarou.Rage
    if WTAGarou.IsBerserkerBreed and WTAGarou.IsBerserkerBreed(data) then
        return tonumber(R.CRINOS_LOCK_ABOVE_BERSERKER) or 55
    end
    return tonumber(R.CRINOS_LOCK_ABOVE) or 75
end

-- True while this character is in Crinos with Rage above the lock line.
function WTAGarou.CrinosLocked(data)
    if not data or data.form ~= "Crinos" then return false end
    return (tonumber(data.rage) or 0) > WTAGarou.CrinosLockAbove(data)
end

-- 0.4.39: the two bulk forms do not fit through doors made for people.
-- They cannot enter vehicles; a shift INTO one of them while seated forces
-- the exit, damages that seat's door and window by the form's clothing
-- fraction (of a part's 100 condition; forced shifts double it exactly as
-- for clothes) and has a small chance to smash the window outright with
-- the engine's own bare-handed smash: glass noise, car alarm, hand cut.
-- Climbing through an OPEN, unbroken window smashes it first the same way.
WTAGarou.BulkForms = { Crinos = true, Hispo = true }
function WTAGarou.IsBulkForm(formName)
    return WTAGarou.BulkForms[tostring(formName)] == true
end
-- 0.4.40 corpse carrying. GRAPPLE_FORWARD: extra metres a dragged corpse sits
-- ahead of a wolf-form grappler (the human anim-node offset puts it inside
-- the longer quadruped body; "a whole meter forward for the Hispo", Oct 5).
-- STOW_FORMS: forms that can put a human corpse in their inventory.
WTAGarou.CorpseCarry = {
    GRAPPLE_FORWARD = { Hispo = 1.0, Lupus = 0.7 },
    -- 0.4.44: total distance (metres ahead of the wolf) at which a body is
    -- held while lifted FROM THE GROUND BY THE SHOULDERS (the vanilla
    -- Bob_PickUp_Person_FromOnFront / FromOnBack nodes are 0.9 / 1.2 against
    -- 0.3 for the carry, so with GRAPPLE_FORWARD added it was "too far from
    -- the wolf's head", Oct 6). Default = the carry distance, 0.3 +
    -- GRAPPLE_FORWARD. The legs grab and the trunk drag-out are unchanged.
    SHOULDER_PICKUP_DISTANCE = { Hispo = 1.3, Lupus = 1.0 },
    STOW_FORMS = { Crinos = true, Hispo = true },
    STOW_TIME = 40,
}
-- 0.4.42: wolf-form melee reach (Oct 6: "Hispo and lupus should have more
-- melee attack range. 30% increased"). Java scales HandWeapon.getRangeMod
-- for melee weapons (incl. bare-handed bites) of a flagged character.
WTAGarou.WolfMelee = { RANGE_MULT = { Hispo = 1.3, Lupus = 1.3 } }
function WTAGarou.WolfMelee.rangeFor(formName)
    return tonumber(WTAGarou.WolfMelee.RANGE_MULT[tostring(formName)]) or 1
end
function WTAGarou.CorpseCarry.grappleForward(formName)
    return tonumber(WTAGarou.CorpseCarry.GRAPPLE_FORWARD[tostring(formName)]) or 0
end
function WTAGarou.CorpseCarry.shoulderPickupDistance(formName)
    return tonumber(WTAGarou.CorpseCarry.SHOULDER_PICKUP_DISTANCE[tostring(formName)]) or 0
end
function WTAGarou.CorpseCarry.canStow(formName)
    return WTAGarou.CorpseCarry.STOW_FORMS[tostring(formName)] == true
end
defineTable("VehicleShift", {
    ENABLED = true,
    SMASH_CHANCE = 0.02,
    PART_CONDITION = 100,
    -- 0.4.40: the vanilla light-crash bank event plays from the vehicle when
    -- a shift damages it (the window smash still plays its own glass cue).
    IMPACT_SOUND = "VehicleCrash1",
})
function WTAGarou.VehicleShift.damageFor(formName, forced)
    local prof = WTAGarou.ShiftStrip and WTAGarou.ShiftStrip.profileFor(formName)
    if not prof then return 0 end
    local pts = (tonumber(prof.fraction) or 0) * (WTAGarou.VehicleShift.PART_CONDITION or 100)
    if forced and prof.forcedMultiplier then pts = pts * prof.forcedMultiplier end
    return math.max(0, math.min(100, math.floor(pts + 0.5)))
end

-- Wall-clock seconds with sub-second precision when the build offers it.
function WTAGarou.NowSeconds()
    if getTimestampMs then
        local ok, ms = pcall(getTimestampMs)
        if ok and ms then return ms / 1000 end
    end
    return getTimestamp()
end

-- Build 42.20 registers moodles as UPPER_SNAKE statics (MoodleType.PANIC,
-- MoodleType.HAS_A_COLD); Build 41 used CamelCase (MoodleType.Panic). The
-- 0.4.x rage code looked up CamelCase only, so on 42.20 every moodle lookup
-- returned nil and moodles never moved Rage at all.
function WTAGarou.MoodleTypeFor(name)
    if not MoodleType or not name then return nil end
    local direct = MoodleType[name]
    if direct ~= nil then return direct end
    local snake = tostring(name):gsub("(%l)(%u)", "%1_%2"):upper()
    if MoodleType[snake] ~= nil then return MoodleType[snake] end
    -- "HasACold" -> "HAS_A_COLD" needs the single-letter split too.
    local snake2 = tostring(name):gsub("(%u)(%u%l)", "%1_%2"):gsub("(%l)(%u)", "%1_%2"):upper()
    return MoodleType[snake2]
end

WTAGarou.Delirium = {
    -- 0.4.79 (user, Oct 21): witnesses and Infamy are DORMANT. Infamy has no
    -- effect yet (hunter spawning is not built) and two friends shifting
    -- with PvP on were raising each other's Infamy. While dormant the client
    -- scanner sends nothing, the server's WitnessTick/DeliriumReport are
    -- ignored and the panel hides the figure. Players are never witnesses
    -- even when this is switched back on.
    ENABLED = false,
    PLAYERS_WITNESS = false,
    LOOK_TIME_TRIGGER = { Glabro = 3.0, Hispo = 3.0, Lupus = 5.0, Crinos = 0.0 },
    SIGHT_TILES = 20,
    ESCAPE_HIDE_SECONDS = 600,
    BRAVE_TRAITS = { "Brave", "Fearless", "Cop", "Veteran", "SecurityGuard" },
    FORGET_SECONDS = 90,
}

-- ---------------------------------------------------------------------------
-- MODEL SWAP  (cosmetic forms)
-- ---------------------------------------------------------------------------
-- Scaling is now handled by WTAGarou's own ZombieBuddy Java DrawChar hook.
-- DynamicModelScale is NOT required. Model-script scale is NOT relied upon.
-- Mesh replacement is a SEPARATE experiment. A wolf mesh does not select an
-- animal animation controller, and Java scaling does not solve that mismatch.
WTAGarou.EnableJavaScale = true
WTAGarou.EnableModelSwap = false
-- Direct Java body/clip prototype. No HumanVisual getter, mount, or IsoAnimal.
-- Enabled for this development-branch playtest; /garou wolf off is the escape.
WTAGarou.EnableDirectWolf = true
-- Crinos-only render experiment: static head/neck cuff + coat-matched fur.
-- Human rig, animation graph, saved skin/hair and inventory remain unchanged.
WTAGarou.EnableCrinosCosmetics = true

-- Legacy HumanVisual-probe gate, independent of the new direct-body path.
-- Keep vanilla human meshes and
-- attachment definitions for Glabro/Crinos; Java scales their render output.
-- Only the legacy probe requires EnableModelSwap=true.
-- Existing gear can still misrender on the wolf skeleton.
WTAGarou.ModelSwapForms = {
    Homid  = false,  -- always vanilla
    Glabro = false,  -- vanilla mesh, Java scale=1.08
    Crinos = false,  -- vanilla mesh, Java scale=1.25
    Hispo  = true,
    Lupus  = true,
}

--- True when this form is allowed to replace the player mesh.
function WTAGarou.ModelSwapAllowed(formName)
    if not WTAGarou.EnableModelSwap then return false end
    if not formName then return false end
    return WTAGarou.ModelSwapForms[formName] == true
end

WTAGarou.Infamy = {
    MAX = 100,
    HUMAN_ESCAPE_GAIN  = 1,
    HUNTER_ESCAPE_GAIN = 3,
    RECOGNITION_BASE_TILES = 2,
    RECOGNITION_MAX_TILES  = 10,
    HUNTER_HOURLY_CHANCE_PER_POINT = 0.005,
    BSD_TURN_CHANCE = 0.10,
}

defineTable("Silver", {
    DAMAGE_MULT = 2.0,
    BURN_DURATION_MIN = 120, -- legacy (0.2.0) expiry entries are still honoured
    -- 0.4.17 contact burns. Silver worn against the skin, or held in a bare
    -- hand, burns the body part it touches once it has been in contact for
    -- CONTACT_SECONDS. The burn is a real vanilla burn wound (BodyPart burn
    -- time; wash + bandage, heals at the vanilla pace) that starts at
    -- INITIAL_BURN and follows an S-curve to MAX_BURN by RAMP_SECONDS.
    -- Regeneration skips a silver-burned part until its burn
    -- time reaches 0, then super healing resumes there.
    CONTACT_SECONDS    = 1,
    INITIAL_BURN       = 2,
    GROWTH_PER_SECOND  = 0.05, -- legacy weapon-call fallback
    RAMP_SECONDS       = 60,
    MAX_BURN           = 75,
    -- Vanilla unbandaged burn DAMAGE is constant, independent of burn time.
    -- The Java hook reduces only that damage call, never other wounds or
    -- healing. It rises gradually with burn severity between these factors.
    TICK_DAMAGE_MIN    = 0.04,
    TICK_DAMAGE_MAX    = 0.85,
    -- Held silver only burns a bare hand: any worn item on the Hands
    -- location (gloves) protects the hands from HELD silver, never from a
    -- worn silver ring.
    GLOVE_LOCATIONS    = { Hands = true, Hands_Left = true, Hands_Right = true },
    -- Which body parts a piece of worn jewellery touches, by bare body
    -- location id. Clothing with covered parts uses those instead.
    LOCATION_PARTS = {
        Ears = { "Head" }, EarTop = { "Head" }, Nose = { "Head" },
        Eyes = { "Head" }, LeftEye = { "Head" }, RightEye = { "Head" },
        Necklace = { "Neck" }, Necklace_Long = { "Neck", "Torso_Upper" },
        BellyButton = { "Torso_Lower" },
        LeftWrist = { "ForeArm_L" }, RightWrist = { "ForeArm_R" },
        Left_RingFinger = { "Hand_L" }, Right_RingFinger = { "Hand_R" },
        Left_MiddleFinger = { "Hand_L" }, Right_MiddleFinger = { "Hand_R" },
    },
    -- Items count as silver when their mod data has WTAGarou_Silver, their
    -- full type or display name contains "Silver", or they carry the tag.
    NAME_PATTERN = "[Ss][Ii][Ll][Vv][Ee][Rr]",
    TAG = "Silver",
})

-- Non-damaging radial stagger on real Crinos entry and standing Crinos Q.
-- This is a close-range radius, independent of a held weapon's reach.
WTAGarou.CrinosShiftBurst = {
    ENABLED = true,
    RADIUS = 3.0, -- tiles; doubled for the next playtest, bounded to 0.25..3
    HIT_FORCE = 1.0, -- native stagger strength, bounded to 0.1..2
    -- 0.4.42: standing Q roar knockback cooldown (Oct 6: "too powerful.
    -- Let's say 5 second cooldown"). The roar voice and its zombie-attracting
    -- noise still happen every press; only the stagger waits. The completed
    -- Crinos shift burst is not affected and does not start the timer.
    ROAR_COOLDOWN = 5.0,
}

WTAGarou.Tags = {
    GAROU     = "WTAGarou_IsGarou",
    BSD       = "WTAGarou_IsBSD",
    HUNTER    = "WTAGarou_IsHunter",
    WITNESSES = "WTAGarou_Witnesses",
}

WTAGarou.TraitId = "wtagarou:garou"
WTAGarou.IGNORE_TRAIT_GATE = false

WTAGarou.Carry = {
    -- 0.4.22: the Wolf Panniers / Wolf Saddlebag CONTAINER items are retired
    -- (Obsolete in wtagarou_items.txt, no longer a starting item, recipe
    -- gone). The saddlebag on a wolf is purely visual: any worn container in
    -- Hispo or Lupus shows the bag mesh (client/WTAGarouVisual.lua
    -- applySaddlebag). The ids stay listed so old saves still load them.
    SADDLEBAGS = {
        "WTAGarou.WolfSaddlebag_Small",
        "WTAGarou.WolfSaddlebag",
    },
    BODY_LOCATION = "wtagarou:saddlebag",
    MOUTH_KEY = "WTAGarou_MouthItem",
}

function WTAGarou.HasGarouTrait(player)
    if WTAGarou.IGNORE_TRAIT_GATE then return true end
    if not player then return false end
    local trait = _G.WTAGarouTraits and _G.WTAGarouTraits.Garou or nil
    if trait and player.hasTrait then
        local ok, res = pcall(function() return player:hasTrait(trait) end)
        if ok then return res == true end
    end
    local md = player:getModData()
    return md and md.WTAGarou and md.WTAGarou.isGarou == true
end

function WTAGarou.CanHoldInHands(formName)
    local fd = WTAGarou.GetForm(formName)
    return fd.allowPrimaryHand == true, fd.allowSecondaryHand == true
end

function WTAGarou.IsValidForm(name)
    return type(name) == "string" and WTAGarou.FormData[name] ~= nil
end

function WTAGarou.IsSupernatural(name)
    return WTAGarou.SupernaturalForms[name] == true
end

function WTAGarou.GetForm(name)
    return WTAGarou.FormData[name] or WTAGarou.FormData.Homid
end
