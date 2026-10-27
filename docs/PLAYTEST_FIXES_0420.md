# 0.4.20 - third September 26 playtest (6 PM)

Solo debug, console
`uploaded_attachments/7fc7150f8fab4d9a8ddbbc40f43687b3/console-2.txt`
plus one screenshot (belt pocket knife taller than a house in Crinos).
Lua, script AND Java changes; the jar is rebuilt.

## What the console proved

| Report | Root cause found in the log |
|---|---|
| "Wolf Panniers" in the key ring on startup | The mod's own Garou starting saddlebag (`WTAGarou.WolfSaddlebag_Small`, display name Wolf Panniers) - nothing to do with tameable wolves. `WTAGarouStartingItems.findBestBag` picked the roomiest container in the inventory, and the key ring is a container. |
| Stuck for several seconds in Hispo after a bite | `PlayerHitReactionState hitReaction=Bite` with `ignoreMovement=true` for ~5 s. The human bite-reaction clip name has no wolf mapping, so `WolfRuntime.clipFor` fell to the 4 s `Wolf_idle`; the state exits on the clip's animation events, which the substituted clip never fires. |
| Dress after the forced Crinos put on one item | Six items queued three times (frames 52398, 52845, 52979), no exception, nothing pruned: the wear actions ran but did not stick. Shoes/socks are rejected by `ISWearClothing.isValid` in Crinos (correct); why the shirts/pants also stayed off is **not in the log** - see the new Dress outcome report below. `[Strip]` printed nothing at the forced Crinos, so belts and holsters were not stripped there. |
| Wolf legs move faster at a walk than at a run | `WolfPlayerClips.stride` measured first-to-last frame displacement; loops that snap back measure 0 and fell to the wolf's native clip duration, so walk/jog/run got the wrong time scale. Which clip plays for which gait (`Wolf_walk`/`Wolf_run`/`Wolf_run_fourx`) was already right. |
| Rifle in both hands in Lupus was instantly unequipped and detached from the back | `WTAGarouSlots.canEquipPrimary` rejected any `Firearm`/`isRanged` item (`no_trigger_finger`), and `unequip` also calls `setAttachedSlot(-1)`. |
| Tense (Stress 1) climbs Rage fast in Lupus | `MOODLE_WEIGHTS.Stress = 1.0` x `ON_MOODLE_LEVEL_PER_SECOND 0.08` = 4.8 Rage a minute from a level-1 moodle. No form multiplier is involved. |
| Belt knife as big as a building in Crinos, a little bigger in Glabro | No matching line in the console. **Cause not identified**; instrumented (below). |
| Saddlebags yaw 90 degrees after Lupus -> Hispo | No matching line. **Cause not identified**; instrumented (below). |
| Raw chicken: no ill effects | Working as designed (`RawMeatPatch`). |
| Sadness never appears | Working as designed (0.4.14 sad-moodle suppression). |

## Changes

### Starting items (`client/WTAGarouStartingItems.lua`)
`findBestBag` only considers WORN containers (`player:isEquipped(item)`) and never a KeyRing type. The panniers go to the worn bag with the most room, else the main inventory.

### Stuck guard (`client/WTAGarouStuckGuard.lua`)
`S.WOLF_HIT_RELEASE_AFTER = 2.0`. In Hispo/Lupus, when the current state name contains `HitReaction` and no movement has happened for 2 s with input held, the guard releases (clears ignore/block movement and the hit reaction, rebuilds the animator) - before the generic 3 s report. Human forms keep the 6 s rule; other wolf states are still diagnostics-only.

### Wolf clips (`java/.../WolfRuntime.java`, `WolfPlayerClips.java`)
- `clipFor`: bite/bitten/grab/react/defend/stagger/knock/shot/hit names map to `Wolf_hitreaction` (attack checked first). The first 24 distinct non-idle names that still fall to `Wolf_idle` are logged as `wolf clip fallback: ...`.
- `stride` is the maximum root displacement from the first frame, not first-to-last. `[WTAGarou Java][Gait]` logs the first 16 gait derivations (human duration/stride/speed, wolf duration/stride, scale, derived duration).
- `RETARGET_ORIGINAL_BONE` records the original `parentBoneName` of every retargeted sub-model; `restoreAll()` (called from `setWolf(false)` before the rebuild) restores compensated scale, retargeted bones and the mouth attachment.

### Jaws (`java/.../JawsAttackPatch.java`)
New ZombieBuddy patch on `IsoPlayer.pressedAttack`: in a wolf form with a ranged primary item the press is swallowed. Combined with the Slots change, a wolf can hold a rifle in its jaws (weight cap still applies: Lupus 8, Hispo 14) and never fires it.

### Slots (`shared/WTAGarouSlots.lua`)
`canEquipPrimary` no longer rejects firearms (`no_trigger_finger` removed); weight cap unchanged.

### Dress (`client/WTAGarouDress.lua`)
- Items that `WTAGarou.CanWear(form, item)` rejects are skipped with one notice: `N item(s) will not fit a <display form>; shift to a human form first.` They stay remembered.
- 8 s after a Dress with at least one queued item, the console gets `[WTAGarou][Dress] N queued item(s) still not worn after 8s in <form>: <names> (queue idle=...)` or `every queued item is worn`. This is what will name the shirts/pants that stayed off in the next forced Crinos.

### Shift strip (`shared/WTAGarouClothing.lua`)
`WTAGarou.Clothing.providesAttachments(item)` (`item:getAttachmentsProvided()`, InventoryItem.java:4307): any worn item that provides attachment points (belts, holsters, webbing, vests with hotbar slots) is shift-safe - never stripped, dropped, damaged or re-dressed. Belts/holsters were already safe by location; this covers vests and modded gear.

### Howl slice (`client/WTAGarouEmote.lua`, `client/WTAGarouRadial.lua`)
Howl moved out of the Shift Form submenu to the top level of the vanilla communication radial (next to "Shift Form", label `Howl / Rage N`).

### Rage (`shared/WTAGarouDefinitions.lua`, `server/WTAGarouServer.lua`)
- `MOODLE_WEIGHTS.Stress = 0.4`: Tense alone is about 2 Rage a minute (was 4.8); Stressed 4 about 8.
- Every 30 s while negative moodles push Rage, the server prints `[WTAGarou][Rage] moodle pressure +X/s in <form>: Stress1 x0.4, Endurance2 x1 ...` so the source of a climb is visible in the console.

### Silver (`server/WTAGarouSilver.lua`, `client/WTAGarouDebug.lua`, `client/WTAGarouTestPanel.lua`)
- `S.firesSilver(weapon)`: a ranged weapon fires silver when its mod data has `WTAGarou_SilverAmmo`, or its ammo/magazine type name matches `NAME_PATTERN`. `OnWeaponHitCharacter` burns a random body part of the target for silver blades AND silver rounds (Garou also take `DAMAGE_MULT`).
- No silver ammunition item ships with the mod or vanilla; the flag is the hook for one.
- Test Panel, utility section: **Silver kit** (`/wta silver`) adds one of every wearable item whose type contains `Silver` (found by scanning `getScriptManager():getAllItems()`, capped at 12, with a vanilla-name fallback) to the main inventory. **Silver rounds** (`/wta silverrounds`) flags the firearm in the primary hand.

### Diagnostics for the two unsolved visuals
- `SubmodelDiag.java` (in `ScaleRuntime.begin`): logs, at most 8 times and once per instance, any sub-model whose render transform first-axis length is outside 0.5-2.5, with model/parent names, `instance.scale`, `parent.scale`, `parentBoneName`, attachment names, wolf/mouth flags, factor and slot final scale. This is aimed at the giant belt knife.
- `WolfRuntime.saddlebagLog`: the first 12 saddlebag retargets print `bone <before> -> Bip01_Spine2`, self/parent attachment names, parent model/script names, `parentIsWolf`, both scales. This is aimed at the 90 degree yaw after Lupus -> Hispo.
- Corrected the models-script comment: the bag hangs from **Bip01_Spine2** (`WolfRuntime.SADDLEBAG_BONE`, since 0.4.13), not Spine1.

## Tuning without a Java rebuild
- Saddlebag height/rotation: `42/media/scripts/wtagarou_models.txt`, `model WTAGarou_Saddlebags` -> `attachment WTAGarou_Saddlebags` `offset = x y z` (x sideways, y forward along the spine, z up; raise = larger z, try 0.06) and `rotate = 90.0 0.0 180.0` (degrees XYZ; the 180 about Z flips the bag front/back, the 90 about X stands it up).
- Jaw-carried item: `WTAGarou.MouthCarry = { rotate = {0, 0, 90}, offset = {0, 0, 0} }` in `shared/WTAGarouDefinitions.lua` (jaw bone: Y along the muzzle, Z up), read by `MouthCarryPatch`.

## Tests
Lua (`tests/run.sh`): 28 / 611 / 28 / 25 / 127 / 35 / 444 / 207 / 66 / 38 / 21 / 222.
Java (`java/test.sh`): 222 / 202 / 23 / 216 / 12 / 29 / 38.
New assertions cover: Dress form filter and outcome report, attachment-provider exemption, silver rounds detection, stuck-guard wolf bite release ordering, stride/snap-back gait derivation, hit-reaction clip names, SubmodelDiag thresholds, jaws gate, test panel button count (25).

## Not verified in game
Everything above is unit-tested only. Specifically unverified: the bite-lock release timing, the gait fix, holding a rifle in the jaws, the Dress outcome report, silver rounds, the two diagnostics producing useful lines, and whether the giant belt knife or the saddlebag yaw is fixed at all (they are only instrumented).
