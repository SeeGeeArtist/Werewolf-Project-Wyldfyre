# 0.4.19 - second September 26 playtest

Solo debug, female character, console
`uploaded_attachments/7f272fd6063b43d293736381f3faef86/console.txt`.
Lua and script files only; the Java runtime is unchanged.

## What the console proved

| Report | Root cause found in the log |
|---|---|
| Error screen on start | `server/WTAGarouSilver.lua:62 item:hasTag("Silver")` -> `RuntimeException: No implementation found for function: hasTag(Clothing, String)`. 42.20.2's `InventoryItem.hasTag` takes an `ItemTag`, not a String. Twelve exceptions at frames 1-2 (six worn items x two scans), then the scan was effectively dead. |
| Silver earrings/loop/stud/necklace/ring never burn | Same exception aborted `itemIsSilver` before the type/name checks ran; and the location -> body-part map is keyed `Ears`, `Necklace`, ... while Build 42's `getBodyLocation()` tostrings to `ears`, `necklace`, `left_ringfinger` (visible in the Strip log lines). |
| Earrings/watches dropped on a Crinos shift | Same lower-case ids: `SAFE_LOCATIONS.Ears` never matched `ears`. |
| Strip/Dress error per item, first run only; Long Skirt left off | Kahlua NPE inside vanilla `ISBaseTimedAction:begin` (`ReturnValues.put ... callFrame ... null`) at frames 35210-37837, then never again. Root cause is not in the log; the most likely trigger is Kahlua state fallout from the Java exceptions above. |
| Crinos: "can't move, can't attack", eaten by two zombies | No exception. Hispo -> Crinos landed at frame 237198 (`result=human`, scale 1.25); nothing logged until the howl at 240139, which was force-stopped 82 frames later (a hit reaction), death at 240862. **Cause not identified.** |

## Changes

### Silver and body locations (`shared/WTAGarouClothing.lua`, `server/WTAGarouSilver.lua`)
- `itemIsSilver` iterates `item:getTags()` and compares tag names; `hasTag` is never called with a string.
- New `WTAGarou.Clothing.lookup(tbl, loc)`: case-insensitive lookup with a cached lowered copy per table. Used by `categoryFor`, `isShiftSafe`, `isDamageExempt`, the Silver body-part map and glove check.
- Effect: `ears`, `eartop`, `nose`, `necklace`, `necklace_long`, `left_ringfinger`, `belt`, `leftwrist`, `rightwrist`, `wound`, `bandage` are shift-safe again (never dropped, damaged, stripped or dressed - watches included, as requested); `hat`/`mask` are dropped undamaged; silver on `ears` burns the head, on `necklace` the neck, and `hands` gloves protect from held silver.

### Wyrm line (`client/WTAGarouHealthPanel.lua`)
`- Wyrm Infection` when nothing purges; `- Wyrm Infection (purging 40%, 3:00 left)` while a purge runs. No form name, no advice.

### Garou Guide (`client/WTAGarouTutorial.lua`)
ISRichTextPanel drops the spaces around inline tags, which produced "TheGaroupanel" and "Strip"/"Dress" without spaces. Colour tags now appear only at line starts. Copy: "good food and howling settles it. Sadness drains it to 0."; "Strip before that if you want to keep your clothes."; page 4 adds "Hats and masks are dropped, but never damaged. Bags, jewelry, watches and held items are never dropped or damaged."

### Rage (`shared/WTAGarouDefinitions.lua`, `server/WTAGarouServer.lua`)
- `SAD_MOODLE_LEVEL_PER_SECOND` 0.08 -> 0.03.
- `Rage.DEPLETED_BELOW = 1`: Crinos is forced back to Homid as soon as Rage drops below 1 (the panel floors, so it already read 0). Explains "Rage hit 0 in crinos form, but no forced homid shift": with the well-fed pull toward 60 the value could hover at 0.x for many seconds.

### Shift cues (`client/WTAGarouShiftSounds.lua`, `WTAGarouChannel.lua`, `WTAGarouClient.lua`)
- `onChannelTick` restarts `WTAGarou_FormShift` every `ShiftSounds.REPEAT_SECONDS` (2.9 s = clip length) while the channel runs; `onChannelEnd` (perform/stop/forceCancel) stops the repeat and lets the last instance finish. A 6 s shift plays it twice.
- The 0-Rage forced Homid plays `ShiftSounds.FORCED_HOMID` (`WTAGarou_FormShift`) once.

### Hispo voice (`client/WTAGarouWolfVoice.lua`)
`WolfSounds.BY_FORM.Hispo = { attack = WTAGarou_HispoBark, pain = WTAGarou_HispoBark }`; Lupus keeps WolfAttack/WolfBark.

### Trait (`42/media/scripts/characters/wtagarou_traits.txt`)
`XPBoosts = Fitness=2;Strength=2;Sneak=2;Nimble=2;Lightfoot=2;Sprinting=3;Tracking=3`. Vanilla already starts every character at Fitness 5 / Strength 5; the boosts add on top (7/7). Syntax verified against `CharacterTraitDefinitionScript` (splits on the first `=`).

### Saddlebag and jaw item (`42/media/scripts/wtagarou_models.txt`, Definitions)
- `Bip01_Spine1` axes measured from `WTAGarou_Wolf.glb`: local X sideways, Y forward along the spine, Z up. Offset z raised from -0.05 to +0.02 on all three attachments.
- `Bip01_Jaw` axes: Y along the muzzle, Z up. `MouthCarry.rotate` {0,90,0} spun the tool about its own handle (blade sideways, handle still forward). Now {0,0,90}: the handle lies across the jaws. Flip to {0,0,-90} to swap the side the head hangs on. Lua-only, no Java rebuild.

### Stuck guard (`client/WTAGarouStuckGuard.lua`, new)
Mitigation for the unexplained Crinos freeze. While the local Garou holds a movement input and has not moved for 3 s it prints one `[WTAGarou][StuckGuard]` line with the engine state (current AI state, hit reaction, knocked down / bump fall / bump staggered, sit-on-ground / on-floor, ignoreMovement / ignoreForDirection / blockMovement, grapple flags, action count, our animation variables), repeating every 5 s. After 6 s in Homid/Glabro/Crinos, outside climb/vehicle/grapple/sleep states, it clears `setIgnoreMovement(false)`, `setBlockMovement(false)`, `setHitReaction("")`, bump/knockdown flags, the timed-action queue, and calls `getAdvancedAnimator():OnAnimDataChanged(false)` (the rebuild every form change already does), then shows "You shake yourself loose." Wolf forms are only diagnosed, never released. **If it happens again, the StuckGuard lines in the console are what will identify the cause.**

### Dress (`client/WTAGarouDress.lua`)
A wear action that fails to queue keeps its wardrobe entry and arms one automatic retry 4 s later once the action queue is idle (the Long Skirt case).

## Sound files
All `common/media/sound/WTAGarou_*.ogg` are RIFF/WAV PCM inside a `.ogg` name (FMOD plays them). Durations: formshift 2.95 s, Crinos_Shift 4.51 s, Crinos_Shift-Timer 11.32 s, Hispo_Bark_01 0.76 s, Hispo_Growl_01 2.66 s, Howl 9.39 s. Not modified.

## Tests
`bash WTAGarou/tests/run.sh`: 28 / 611 / 28 / 25 / 123 / 35 / 437 / 197 / 66 / 38 / 18 (new `stuck_guard_test.lua`) / 222. New assertions: lower-case location lookups, watches shift-safe, `getTags` silver path with a throwing `hasTag`, Wyrm line wording, guide copy without mid-sentence tags, cue repeat/end/forced-Homid, `forForm`, trait boosts, saddlebag offsets, mouth rotate, depletion threshold, stuck-guard report/release/exclusions.

## Unverified in game
- Silver burn actually appearing on the earring/necklace/ring parts.
- Watches/earrings staying on through a Crinos shift; Strip/Dress skipping them.
- Whether the first-run Strip/Dress NPE disappears with the Java exception gone.
- Saddlebag height and jaw-item orientation (both are tuning numbers).
- The Crinos freeze: the guard only logs and releases; the cause is unknown.
- Cue repeat timing against the real channel length; trait boosts on a new character.
