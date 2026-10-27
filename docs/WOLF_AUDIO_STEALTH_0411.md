# 0.4.11 - Shift strip, wolf voice, form noise and stealth, saddlebag visual

Everything below was verified only by the offline suites listed at the end.
Nothing in this document claims an in-game result.

## Shift strip (clothing rips off on Crinos / Hispo / Lupus)

`shared/WTAGarouClothing.lua` was rewritten. The 0.2.1 code indexed a string
table with the Build 42 `ItemBodyLocation` object returned by
`InventoryItem:getBodyLocation()`, so every worn item read as "unknown =
safe" and nothing was ever dropped. `WTAGarou.Clothing.locationId(item)` now
turns that object (`tostring` = `base:Torso1`) into the bare `Torso1`.

When a shift to a `stripsClothing` form completes (client, on
`TransformCompleted`), every WORN item is damaged and dropped at the feet,
except:

- any worn container (`getCategory() == "Container"` / `InventoryContainer`):
  backpacks, duffel bags, sheet slings, satchels, fanny packs, saddlebags;
- jewelry, glasses, make-up and gear straps listed in
  `WTAGarou.ShiftStrip.SAFE_LOCATIONS` (belts, ammo straps, webbing, holsters);
- anything held in the primary/secondary hand;
- anything only carried in the inventory.

Damage is `DAMAGE_FRACTION` (25 %) of max condition, floored at 1, plus up to
`HOLES` (2) holes on the parts the item covers (`Clothing.getCoveredParts` ->
`ItemVisual.setHole`). The drop path is `removeWornItem` ->
`getInventory():Remove` -> `square:AddWorldInventoryItem`, then one
`resetModelNextFrame()`.

`WTAGarou.CanWear(form, item)` always allows containers ("any container a
human can wear, a wolf can wear") and unknown locations.

## Form voice (Q shout)

`java/.../CalloutPatch` (`IsoGameCharacter.Callout()`, `strictMatch`) skips
the human "Hey"/"psst" for registered forms and plays the form sound through
`character.playSound(name)` (emitter path, MP-synced), says the text, and
registers a world sound of the form radius through
`WorldSoundManager.instance.addSound(src, x, y, z, radius, volume)`.

| Form   | standing (radius)              | crouched (radius)              |
|--------|--------------------------------|--------------------------------|
| Homid  | vanilla Hey (30)               | vanilla psst (6)               |
| Glabro | vanilla (sounds like Homid)    | vanilla                        |
| Lupus  | WTAGarou_WolfBark (20)         | WTAGarou_WolfGrowl (4)         |
| Hispo  | WTAGarou_WolfBark (30)         | WTAGarou_WolfGrowl (6)         |
| Crinos | WTAGarou_CrinosRoar (45)       | WTAGarou_CrinosGrowl (9)       |

Table lives in `WTAGarou.Voice`. The Crinos entries reference
`media/sound/WTAGarou_Crinos_Roar_Bark.ogg` and
`media/sound/WTAGarou_Crinos_Growl.ogg`, which the mod author keeps locally in
`WTAGarou/common/media/sound/`; the repo does not carry them and
`tests/asset_contract_test.py` lists them as author-supplied. The forced-Crinos
countdown growl now uses `WTAGarou_CrinosGrowl` (the old `WTAGarou_Growl`
entry is retired).

## Footsteps and noise

`FootstepPatch` (`IsoGameCharacter.DoFootstepSound(float)`, signature-matched
so the `String` overload is untouched) multiplies the volume by
`WTAGarou.Stealth[form].footstepMul` (Lupus 0.5, Crinos 1.5, others 1.0) and
lets the engine continue, so the radius, indoor halving and random gate stay
vanilla. For Lupus/Hispo (`wolfSteps`) it skips the human bank and plays
`WTAGarou_WolfStep` (three WolfMod paw clips) locally, then adds a world sound
mirroring the human math (x1.4, paws count as no shoes x0.5, sneaking applies
`getSneakSpotMod()`, indoors halves, 1-in-2 gate / 1-in-4 while sneaking).

## Sight

`SpottedPatch` (`IsoZombie.spotted(IsoMovingObject, boolean)`) drops a
share of non-forced sight checks against a registered target:
keep = `spotMul` (Lupus 0.6, everything else 1.0) times `spotMulSneaking`
when the target is sneaking (Lupus 0.5, so a sneaking Lupus keeps 30 % of
checks on top of the engine's own sneaking reductions). Crinos visibility is
unchanged; its extra conspicuousness is noise (footsteps x1.5, roar 45).

## Wolf body sounds (Lua, `client/WTAGarouWolfVoice.lua`)

Local player in Lupus/Hispo only: `OnWeaponSwing` -> `WTAGarou_WolfAttack`;
`OnPlayerGetDamage` (>0) -> `WTAGarou_WolfBark`; idle sniff every 10-20 s
while not moving -> `WTAGarou_WolfSniff`; `OnPlayerDeath` ->
`WTAGarou_WolfDeath`. Falls that stability allows play `WTAGarou_WolfFallOver`
from `StabilityRuntime.filter` -> `StealthRuntime.onFall`. The death visual
path (Wolf_death then human corpse) is untouched.

## Registration

`client/WTAGarouVisual.lua` `refresh` pushes the profile once per form change
for the local player and every synced remote (`WTAGarouJava.setNoise`,
`setVoice`, `setVoiceText`, `setFallSound`); `WTAGarouJava.clear` removes it
on death/trait loss. `WTAGarouJava.status()` now includes stealth counters.

## Saddlebag visual (EXPERIMENTAL)

`WTAGarou.EnableSaddlebagVisual` (default true). While a wolf wears any
container, a hidden zero-weight `WTAGarou.WolfSaddlebagVisual` item is
attached at the new `WTAGarou_Saddlebags` attached-location, and both wolf
body models carry an `attachment WTAGarou_Saddlebags` on `Bip01_Spine1`
(offset `0 0.08 -0.05`, rotate `90 0 180`; Hispo scale 1.1). The mesh and
texture are HorseMod's `HorseSaddlebags.fbx` / `HorseSaddlebags_Black.png`
copied to `common/media/models_X/WTAGarou/WTAGarou_Saddlebags.fbx` and
`common/media/textures/WTAGarou/WTAGarou_Saddlebags.png`. The offsets are a
first guess against the wolf rig and are NOT verified in game; if the bag
floats or clips, tune the attachment block in `wtagarou_models.txt` or set the
toggle false. Worn bag meshes themselves still render as the engine renders
them on the wolf skeleton; hiding them was not attempted.

## Silver burns (wording fix)

Silver-burned parts are skipped by the Garou regeneration boost and heal at
the vanilla pace. The mod grants no Fast Healer trait and the engine trait
only shortens wound timers when the wound is created, so no counter-tuning
is needed. 0.4.10 docs said "never regenerate"; that was wrong wording, not
behaviour.

## Verified offline

- `bash WTAGarou/java/build.sh` and `bash WTAGarou/java/test.sh`: ScaleTest 222,
  WolfCombatTest 139, WolfClipLoaderTest 23, WolfPlayerClipsTest 198,
  StabilityTest 12, new StealthTest 29 (real ZombieBuddy advice on fixtures:
  footstep scaling / wolf skip, Callout replacement standing/crouched,
  deterministic sight skips, forced/unregistered pass-through, fall sound,
  clear).
- `bash WTAGarou/tests/run.sh`: all Lua suites plus new
  `stealth_voice_test.lua` (80: location parsing with `base:` objects, safe
  rules, CanWear, strip damage/holes/drop with held and carried exemptions,
  per-form Java registration, saddlebag attach/detach and toggle, wolf sound
  events, sniff timer) and the asset test (150; sound clips shipped, Crinos
  files allow-listed, saddlebag assets, attachment bones exist in the rig).

## Not verified in game

Sound playback and FMOD ranges, zombie reaction to the new world sounds,
the sight-check reduction as felt in play, holes/condition on dropped
clothing, saddlebag placement and orientation, and whether the hidden
attached item is ever visible in the hotbar UI.
