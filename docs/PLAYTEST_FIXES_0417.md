# 0.4.17 - September 26 playtest fixes

Every item below comes from the solo debug-mode playtest of 0.4.16 (screenshots
and `console-4.txt`). Engine behaviour was read from the pinned B42.20.2
reference (`zombie/characters/IsoGameCharacter.java`,
`BodyDamage/BodyDamage.java`, `BodyDamage/BodyPart.java`,
`core/skinnedmodel/advancedanimation/AnimatedModel.java`,
`core/skinnedmodel/model/ModelInstanceRenderData.java`).

## What changed

| Report | Cause | Fix |
| --- | --- | --- |
| Panel buttons crowded | 5 forms + Strip/Dress/Howl in three rows of 300 px | `WTAGarouHUD`: forms in a left column (140 px), Strip / Dress / Howl in a right column, notices below; panel 268 tall. Layout constants in `WTAGarou.HUD.LAYOUT`. |
| "At Breaking Point" never left; Rage climbed to 100 | `IsoGameCharacter.updateStress` adds stress every tick while bitten/scratched parts exist **or `BodyDamage.IsInfected()`**. In B42 `BodyDamage.Update` recomputes `CharacterStat.ZOMBIE_INFECTION` every tick from `(worldAge - infectionTime) / mortalityDuration` while `isInfected`, and re-sets `isInfected` from any part still `IsInfected()`. The 0.4.11-0.4.16 cure only lowered the stat, which the engine put straight back, so the Garou stayed infected and stressed for good. | `cureZombieInfection` counts the burn-off in `d.infectionBurn`; at 100 (Crinos 60 s, Hispo/Glabro 180 s) `WTAGarou.ClearZombieInfection` clears every part's `SetInfected(false)` / fake infection, `setInfected(false)`, `setIsFakeInfected(false)`, `setInfectionTime(-1)`, `setInfectionMortalityDuration(-1)` and both stats. Homid and Lupus never cure. |
| Rage ticking down in Crinos | Intended since 0.4.14: Crinos is the only form with a passive rate (-1/s). | No change. |
| Tear sound kept playing / piled up | `ClothesRipping` is the vanilla crafting loop (the recipe stops it when the craft ends); `player:playSound` was fire-and-forget. | `Clothing.playRip` keeps the emitter handle and stops it (`stopSound(handle)` + `stopSoundByName`) after `ShiftStrip.RIP_SECONDS` (1.2 s) from OnTick. |
| Bark repeated in Hispo/Lupus until the form changed | `OnPlayerGetDamage` fires every tick for BLEEDING, INFECTION, HUNGRY, THIRST, SICK, HEAVYLOAD, POISON, LOWWEIGHT (BodyDamage.java 2331-2403, BodyPart.java 169, Nutrition.java 344). A wounded wolf barked on each one. | Bark only for `WolfSounds.PAIN_TYPES` (WEAPONHIT, FALLDOWN, CARHITDAMAGE, FIRE). Zombie bites/scratches raise **no** damage event in B42.20.2, so a new wound (bitten + scratched + cut count went up) yelps instead. Cooldown 1.5 s. |
| Dress said the stripped clothes were not in the inventory | Two bugs. (1) Strip records items while they are still worn (the vanilla unequip runs later); the HUD tooltip refresh calls `prune`, which treated "found and worn" as "dressed again" and deleted the entries at once - only the two pieces the shift had already dropped survived. (2) `getItemWithIDRecursiv` returned nil for items that were in the inventory (cause unconfirmed). | Entries start `pending` and are kept until seen off the body. `Wardrobe.find` tries the engine lookup, then walks the inventory and nested containers in Lua comparing `getID()` as numbers, then the floor. On a miss it prints `[WTAGarou][Dress] missing ids ...` and `inventory ids ...` so the next console shows the actual ids. Matching stays by exact id, never by type. |
| Dress should also find clothes on the floor | Not implemented before. | `Wardrobe.findOnFloor`: squares within `FLOOR_RADIUS` (2) tiles, `getWorldObjects()` -> `getItem()`; Dress queues `luautils.walkAdj` + `ISGrabItemAction` then `ISWearClothing`. Notice text: "... is not in your inventory or nearby." |
| Silver earrings / necklace: no burn | Only mod silver **weapons** burned (on hit). | `server/WTAGarouSilver.lua` contact scan (1 s): worn silver touches the parts in `Silver.LOCATION_PARTS` (Ears/EarTop/Nose -> Head, Necklace -> Neck, Necklace_Long -> Neck + Torso_Upper, wrists -> forearms, rings -> hands; other clothing uses its covered parts); held silver touches Hand_R (primary) / Hand_L (secondary) unless anything is worn on a Hands location. After `CONTACT_SECONDS` (20) the part gets a vanilla burn (`setBurnTime(15)`, `setNeedBurnWash(true)`) that grows 0.5/s to 100 while contact continues. `d.silverBurns[part] = true`; `Regenerate` skips the part (no health, bleeding or wound-flag help) until `getBurnTime() <= 0`, then drops the flag. Silver detection: mod data `WTAGarou_Silver`, "Silver" in the full type or display name, or the `Silver` tag. |
| Silver earrings dropped on shift | `SAFE_LOCATIONS` already exempts Ears/Necklace etc. The console shows many engine `IsoFallingClothing added` lines: vanilla `helmetFall` drops any worn Clothing with `ChanceToFall > 0` on head hits and falls. | `[WTAGarou][Strip] shift to <form>: <location>:<type>=<result>` now lists every item the shift touched; if the earrings are absent from that line the engine dropped them. |
| Saddlebags float above the back; hammer floats before the face | `ScaleRuntime` multiplied the DrawChar `FinalScale` by `BODY_SCALE` (0.6) only for the wolf body. Sub-models share the wolf rig space, so their bone offsets were drawn 1/0.6 too far from the origin. | Sub-models whose parent chain reaches the wolf also get `BODY_SCALE`; `ModelInstance.scale` is multiplied once by 1/`BODY_SCALE` (applied in `transformToParent` before FinalScale) so the mesh keeps its size; restored on the first human draw. |
| Tool should lie sideways in the mouth | Item drawn in the item's own grip orientation. | Jaw item `attachmentNameParent` -> `GarouJaw` (no human body attachment, so the engine uses `parentBoneName = Bip01_Jaw`); new `MouthCarryPatch` (`AnimatedModel$AnimatedModelInstanceRenderData.transformToParent` OnExit) post-multiplies `WTAGarou.MouthCarry.rotate` (default 0, 90, 0 degrees) and `.offset` in the item's local space. Tune in `WTAGarouDefinitions.lua`; no Java rebuild. |
| Secondary slot in wolf forms | Design rule from 0.3.0. | Hispo/Lupus `allowSecondaryHand = true`; `Slots.enforce` keeps the off-hand and two-handed items; primary/jaws rules unchanged. |
| Forced Crinos 15 s | Was 10 s. | `Rage.FORCE_CRINOS_SECONDS = 15`; client/server fallbacks 15. |
| `[WTAGarou][Howl] sound stop ignored ... reason=character_death` x56 | `OnCharacterDeath` fires for every zombie (owner -1). | Handler ignores non-`IsoPlayer` characters. |

## Not changed (by request or pending)

- Howl animation for Hispo/Lupus: the user will author one; `Drink` stays.
- Wolf head deforming while eating / neck while moving: the animation-track
  dump for a diagnosis is not in this version.
- Witness/Bandits infamy: parked.

## Verification

- `bash WTAGarou/tests/run.sh`: 28 Lua / 611 channel-HUD / 28 panic / 25
  combat / 123 test-panel / 35 visual-sync / 166 rage-engine (includes the
  pinned-infection cure and silver contact burns) / 182 stealth-voice-strip
  (pain types, new-wound yelp, pending Wardrobe entries, Lua inventory walk,
  floor grab, diagnostic dump) / 199 asset assertions.
- `bash WTAGarou/java/build.sh && bash WTAGarou/java/test.sh`: 222 / 202 /
  23 / 198 / 12 / 29 / 38 assertions, including the sub-model scale
  compensation, the `GarouJaw` attachment, the restore on the first human
  draw and the `MouthCarryPatch` advice on a stub `transformToParent`.
- Unverified in game (mock tests cannot prove them): the saddlebag/hammer
  position, the 90 degree jaw rotation direction, the rip clip actually
  stopping, whether `getItemWithIDRecursiv` still misses (read the
  `[WTAGarou][Dress]` dump), the burn moodle/wash flow on silver burns, and
  the infection stat/moodle disappearing after a minute in Crinos.
