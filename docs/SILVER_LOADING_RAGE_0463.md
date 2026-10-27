# 0.4.63: Rage cap, nitrate cook time, coat list, per-round silvering, animated silver reload, Crinos shout

Answers the October 16 playtest of 0.4.62. Everything you confirmed there
(fluid pipeline, pouring, coating from the weapon's context menu, the hit
meter, coat depletion and re-coating, firing every kit weapon on silver,
topping up a half-empty magazine, unloading) is untouched.

## What you reported, what it was

| Report | Cause | Fix |
| --- | --- | --- |
| "Rage would go up to 99 and just sit there, even in Crinos ... cheated to 100 and it dropped back to 99" | The Rage tick applied regen, the negative-moodle pressure and the sad drain as three separate adds. The positive part clamped at 100, then one Unhappy level (0.03/s) pulled it to 99.985. The HUD showed 99 and the 100-Rage Crinos countdown never armed (`rage = 100` x4 in your console, then `nothing to resist`). | The three are summed and applied once. Rage rests on 100 whenever the net is positive; the countdown arms. |
| "it cooked instantly in this microwave" | The converter ran from the first hot tick at vanilla's tainted-water rate, which is fast; vanilla pots feel slow because the **item heat** has to climb first, and that ramp was missing. | The vessel warms like a vanilla pot (same ramp constants, same 1.6 boil point) before any raw mix finishes, and the finish rate is a quarter of vanilla's. A litre over a lit fire is a visible wait now. |
| Carving fork, smithing hammer, claw hammer not in the coat list | The tag rule counted only `MetalValue`/`HasMetal` and excluded all forge tools. The 42 scripts give the carving fork no tags at all, and pokers, wrenches, trowels etc. only `Smeltable*` tags. | Metal = MetalValue, HasMetal, any `Smeltable*`, Sharpenable, or carving fork / ice axe by name. Hammers, tongs and files coat like anything else. The forge recipe now uses a second tag (`wtagarou:forgeable`, coatable minus tools) so a hammer can never be picked as the forge's *weapon*. |
| "coating the weapon requires a surface. Let's remove that requirement" | Recipe tag `AnySurfaceCraft`. | Coat is `InHandCraft`. Mixing the raw nitrate still wants a counter or table. |
| "shells can only be silvered six-at-a-time ... divide the silvering time by six" | Batch recipes (6 shells / 10 bullets per fragment). | One round per craft (queue the quantity), Time 30 for a shell (180/6) and 24 for a bullet (240/10). A recipe cannot take a sixth of a fragment, so **File Silver Fragments** (fragment + file) makes **Silver Filings**, a 20-use drainable: a shell takes 3 uses, a bullet 2, which is the same six shells / ten bullets per fragment as before. |
| "Put more silver fragments in the silver kit. 20" | — | `/garou silver` gives 20. |
| "chambered a silver round in the shotgun and racked it, and it un-silvered the shell" | Vanilla `ISRackFirearm:removeBullet` instances the gun's ordinary ammo type. Unloading went through our hand-back, racking did not. | Racking a silver round out of the chamber (or a chamberless gun with silver inside) hands back the silver round. |
| "no reloading animation or audio plays for loading silver ammo" / "loading silver rounds does not require that the firearms be equipped" | The 0.4.58 action was an instant custom action. | Loading silver **is** the vanilla reload now: `WTAGarouLoadSilverAction` derives from `ISReloadWeaponAction` and `WTAGarouLoadSilverMagazineAction` from `ISLoadBulletsInMagazine`, with the silver type swapped in. Same animation, sounds, reload speed, racking afterwards, and the gun must be in your hand (the menu equips it first, like vanilla "Load bullets"). |
| "I do wish that loading silver rounds was a part of the reload radial menu" | — | The firearm radial (hold the reload key / controller) has a **Load silver rounds (+n)** slice with the vanilla icon and ammo count. It targets the gun, or the fullest magazine of the gun's type that has no ordinary rounds in it. Hidden when there is nothing to load, when ordinary rounds are inside, or on paws. |
| "disable the shout and whisper animations while in crinos form" | `Callout(true)` plays the "shout" emote after the sound. | `ShoutEmotePatch` drops the "shout" emote for Crinos only (roar/growl sound and text unchanged; every other form and every other emote untouched). |
| "Silver-tipping 7.62 rounds ... says they're now .308" | Not a bug: Project Zomboid's rifle calibre item is `.308` (the 7.62x51 round) and the silver variant takes vanilla's name. | Left as is. |
| "mixed mags" | A gun or magazine holds one count of silver rounds, not a per-slot list. Mixing would mean tracking order of rounds through every vanilla action. | Deferred, by design: silver or ordinary, never both. |

## How silver rounds play now

1. **Strip** jewellery or silverware into Silver Fragments (unchanged).
2. **File Silver Fragments** (counter or table): 1 fragment + file -> Silver Filings (20 uses).
3. **Silver Shotgun Shell**: 1 shell, 3 filings uses, pliers. **Silver-Tip <calibre> Round**: 1 round, 2 filings uses, file, pliers. Set the quantity in the crafting window; each round is its own short craft.
4. Right-click the gun or magazine -> **Load silver rounds (n)**, or open the firearm radial and pick the silver slice. The gun comes to hand and the normal reload plays. Mixed loads are refused with the usual HUD line.
5. Rack, fire, unload: silver stays silver all the way through.

## Static verification

- Lua: `bash WTAGarou/tests/run.sh` -> 31 PASS (new `silver_load_actions_test` 46; `silver_ammo_test` 174; `rage_engine_test` 660; `stealth_voice_test` 284; `paw_guard_test` 54).
- Java: `bash WTAGarou/java/build.sh && JOML_JAR=... bash WTAGarou/java/test.sh` -> 23 PASS (`CoatableTagTest` 44, `NitrateHeatTest` 35, `StealthTest` 79).
- Banner: `[WTAGarou Java] 0.4.63 loaded; ...`; `/garou silver` prints `coatable tag: ItemTags.Init seen, n of m item scripts tagged coatable, k forgeable`.

## Awaiting live verification

- Rage holds 100 with negative moodles and one Unhappy level; the Crinos countdown arms.
- A jar over a campfire takes a visible while; the microwave too.
- Carving fork, smithing hammer, claw hammer, poker, pipe wrench appear in the coat list; coating works away from any table.
- Filing, per-round silvering with a queued quantity, filings uses going down 3/2 per round.
- Load silver from the context menu: gun equips, reload animation and audio play; from the radial slice on controller.
- Rack a chambered silver shell: the ejected shell is silver.
- Crinos Q / crouched Q: roar/growl without the gesture; Homid/Glabro/wolf forms unchanged.
- Coated-weapon burn on a werewolf still needs a second player.
