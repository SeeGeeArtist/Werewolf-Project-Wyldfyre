# 0.4.40 — .39 playtest fix batch: wolf corpse handling, mod audio, picker polish

## Change contract

```text
Target: fix the .39 playtest list — picker "[selected]" clutter, identity-reset
  console failure, "Wolf coat" footer under Wolf gear, wolf bark on corpse
  pickup, Wolf_eat pickup pose, reversed Wolf_walk corpse carry, corpse carried
  ~1 m further forward in wolf forms, Hispo (and Crinos) corpse stowing,
  reference-rotation spin when a wolf drops a corpse into a vehicle, mod sounds
  ignoring the game volume slider (cap at 75%), vehicle impact sound on
  seated-shift damage.
Confirmed working (user, .39 playtest): Berserker/Metis stats and balance,
  vehicle damage values (38 / forced 75 / Hispo 25 — user decided to leave
  as-is), vehicle entry refusal, seated-shift ejection, window smash on climb,
  picker confirm/lock, Q roar knockback, seated head look, harness/gear/coats.
Observed failure or request: the list above (Oct 5 playtest message + console).
Must remain untouched: vehicle damage numbers; harness/gear transforms; coat
  art; form costs; roar knockback; gait tuning (cycleSlowdown, stride match);
  WolfPlayerClips marker logic for gaits; .38 LayDown predicate scope.
Evidence still needed (in game): drag clip names while a wolf drags a corpse,
  the logged grapple forward offset, the vehicle-drop clip name, whether the
  Sound Effects slider now scales mod cues.
```

## Engine findings (private B42.21 jar; nothing from it is shipped)

- **Grapple position.** `AnimLayer` pushes `LiveAnimNode.getGrappleOffsetForward()` into
  `IGrappleable.setGrapplePosOffsetForward(float)` every frame; `BaseGrappleable` keeps the
  value in `grappleOffsetForward` and reads the grappler's value when it is the one being
  dragged. The offset is authored per anim node for the human rig, which is why a dragged
  corpse sits inside the longer wolf body. `GrappleOffsetPatch` (OnEnter on that setter)
  adds `WTAGarou.CorpseCarry.GRAPPLE_FORWARD[form]` only while the flagged character's
  current state is `PlayerDraggingCorpse` or `isGrappling()` is true; it logs
  `[WTAGarou Java][Grapple] node forward offset …` (eight lines max).
- **Corpse ⇄ item.** `IsoDeadBody.getItem()` builds the `Base.Corpse*` item with the
  body's byte data and weight; `becomeCorpseItem(boolean)` = `getItem()` +
  `IsoGridSquare.removeCorpse(body, bool)` (`false` sends the networked removal on
  clients). `IsoGridSquare.tryAddCorpseToWorld(item, x, y, bool)` spawns the body back and
  removes the item from its container; `IsoGameCharacter.pickUpCorpseItem(item)` =
  spawn + grab. `throwGrappledIntoInventory(ItemContainer)` runs the vanilla
  throw-into-container state against any container (the trunk path). `getWeightAsCorpse()`
  is 20.
- **Audio routing.** Mod OGGs are file clips: they play on
  `FMODManager.channelGroupInGameNonBankSounds`, which `SoundManager` only pauses/mutes —
  the Sound Effects slider drives the `vca:/Settings_Sfx` VCA for bank events only. That is
  why lowering the slider never touched the roar. `BaseSoundEmitter.setVolume(long, float)`
  scales a running file clip; `SoundManager.getSoundVolume()` is the slider value.
- **Drag/pickup clips (Oct 5 console).** The bite fired in `SwipeStatePlayer` on the exact
  frame `Bob_PickUp_Person_FromOnBack` started; no grapple flag was set yet. Other corpse
  clips seen: `Bob_PickUp_Person_OnBackLegs`, `Bob_LayDown_Person_OnBack(Legs)`. The drag
  walk clips were never logged because they matched the ordinary walk mapping; .40 logs them.

## Implemented

- **Picker** (`WTAGarouWolfCoat.lua`): selected true form / coat / gear button gets a
  heavier border and tinted background (`markSelected`), no `[selected]` text; the locked
  footer reads `… > Wolf gear`.
- **Console** (`WTAGarouDebug.lua`, `WTAGarouTestPanel.lua`): the in-game console evaluates
  Lua, so `/garou …` is `unexpected symbol near '/'`. New globals `WTAGarouResetIdentity()`,
  `garou("identity reset")`, `WTAGarou.cmd("…")`, plus a Testing-panel "Reset identity"
  button.
- **Audio** (`shared/WTAGarouAudio.lua`, `StealthRuntime.java`): every mod cue
  (roar, countdown, howl, barks, rips, falls, footsteps) is started through
  `WTAGarou.Audio.play` / `scaleHandle`, volume = Sound Effects slider × 0.75 cap.
  Remote clients' copies of networked `playSound` are not scaled (MP caveat).
- **Vehicle impact** (`WTAGarouClient.lua`): `VehicleEjected` with damage plays
  `WTAGarou.VehicleShift.IMPACT_SOUND` (`VehicleCrash1`) on the vehicle.
- **Wolf corpse pose** (`WolfPlayerClips.java`, `WolfRuntime.java`): pickup / lay-down clips
  → `Wolf_eat` retimed to the human action length (`derivePoseOnly`: wolf marker kept, no
  human root keys); throw / container clips → `Wolf_idle`. Corpse clips and any
  non-locomotion clip while dragging or throwing switch `useDeferredRotation` off (the
  vehicle-drop spin). Gait clips while dragging derive with `reversePose`: wolf pose key
  times mirrored, human marker (direction/speed) untouched. Drag clips are logged once each:
  `[WTAGarou Java][Drag] clip '…' while dragging -> … (pose reversed)`.
- **Bite filter** (`WTAGarouWolfVoice.lua`): adds `isGrappling()` and
  `WTAGarouJava.isCorpseHandling(player)` (true for 1.5 s after a corpse clip starts, and
  while dragging) at swing time and before the deferred bite.
- **Grapple offset** (`WolfGrappleRuntime.java`, `GrappleOffsetPatch.java`,
  `WTAGarouVisual.lua`): Visual pushes `CorpseCarry.grappleForward(form)` (Hispo 1.0 m,
  Lupus 0.7 m, bipeds 0) with the bulk flag.
- **Corpse stowing** (`client/WTAGarouCorpseCarry.lua`): Crinos/Hispo get "Stow corpse"
  (ground corpse: walk adjacent + timed action → `becomeCorpseItem(false)` + `AddItem`),
  "Stow carried corpse" while dragging (`throwGrappledIntoInventory(own inventory)`), and
  "Put down corpse" on the inventory item in any form (`pickUpCorpseItem`). Animals excluded;
  weight left to vanilla encumbrance. MP sync of the stow is unverified.

## Static verification

- Lua suite (`tests/run.sh`) green, incl. new `tests/corpse_carry_test.lua` (37) and the
  extended voice/coat/panel/vehicle tests.
- Java tests green; `WolfPlayerClipsTest` covers Wolf_eat retime, marker preservation,
  reversed drag gait, dragging idle rotation guard and the grapple offset gate;
  `EnginePlaytestAdviceTest` weaves `GrappleOffsetPatch` into the real
  `BaseGrappleable.setGrapplePosOffsetForward(float)`; `engine_playtest_contract.py` pins
  the corpse-item, grapple and audio surfaces. Jar contains no `zombie/` classes.
- None of this is in-game evidence.

## Smallest in-game test (full restart, Lupus first, then Hispo)

1. Both banners: `[WTAGarou] Definitions loaded - version 0.4.40` and
   `[WTAGarou Java] 0.4.40 loaded; wolf corpse handling …`.
2. Picker: selected button shows a thicker border, no text suffix; lock it, reopen → footer
   says Wolf gear.
3. Console: `WTAGarouResetIdentity()` → picker unlocks (no slash).
4. Lupus: Grab a corpse. Expect no bark, a head-down (eat) pose during the lift, then the
   wolf walks backwards while the corpse trails ~0.7 m ahead of the old spot. Report the
   `[Drag] clip` and `[Grapple] node forward offset` lines.
5. Hispo: same, offset ~1 m; right-click the corpse → Stow corpse; inventory → Put down
   corpse. Drop a dragged corpse into a car trunk: no spin.
6. Set Sound Effects to 20%, roar in Crinos: quieter than before. Shift in a seat:
   crash sound with the rip.
