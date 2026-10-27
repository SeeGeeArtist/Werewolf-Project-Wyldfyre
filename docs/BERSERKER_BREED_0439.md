# 0.4.39: Berserker breed, Crinos exit lock, bulk-form vehicle and window rules, confirm-and-lock picker

## Change contract

```text
Target:            third true form "Berserker" (Metis), Crinos exit lock for all Garou,
                   Crinos/Hispo vehicle + window rules, Confirm/lock in the identity picker
Confirmed working: .37 Q roar knockback, seated head look, upright corpse pickup,
                   .36 harness fit / attachments / coats (all untouched)
Observed request:  user design message + Berserker naming, "Build it now";
                   picker confirm with "Are you sure?", wolf gear exempt
Must remain untouched: form costs (Homid 0, Glabro 20, Crinos 10/55, Hispo 20, Lupus 0),
                   Rage MAX/START/FORCE_CRINOS rules, .38 LayDown guard and bark filter,
                   art, scales, gear transforms
Evidence still needed: everything below is static (Lua + Java fixtures + engine
                   signature contract); nothing in .39 is confirmed in game
```

## What changed

### Berserker breed (saved as `trueForm = "Glabro"`)

| Rule | Human / Wolf breeds | Berserker |
| --- | --- | --- |
| Starting form on first confirmed choice | Human / Wolf | Near-Human (Glabro) |
| Form forced at 0 Rage | Human / Wolf | Near-Human |
| Rage needed to START Crinos | 55 (spends 10) | 10 (spends 10) |
| Passive Crinos drain | 1 Rage/s | 0.5 Rage/s (1 Rage per 2 s) |
| May shift OUT of Crinos while Rage is | 75 or lower | 35 or lower |
| 100-Rage forced Crinos | unchanged | unchanged (from Glabro) |

The 0-Rage return (`forceDepletedShift`) is the only thing that bypasses the exit lock; it
is free and goes to the breed's base form. The picker button is "Berserker" (your naming;
the panel's Crinos display name stays "Berzerker"), and its tooltip names the Metis breed.

Constants: `WTAGarou.Rage.CRINOS_DRAIN_BERSERKER = -0.5`, `CRINOS_LOCK_ABOVE = 75`,
`CRINOS_LOCK_ABOVE_BERSERKER = 35`. Helpers: `WTAGarou.RageRequired(form, data)`,
`CrinosDrainPerSecond(data)`, `CrinosLockAbove(data)`, `CrinosLocked(data)`,
`IsBerserkerBreed(data)`, `TrueFormLabel(form)`.

Denial text for a locked request: "The Rage will not let you go yet."

### Bulk forms: Crinos and Hispo versus vehicles

- Cannot enter a vehicle. Java `VehicleEntryPatch` answers true from
  `BaseVehicle.isEnterBlocked(IsoGameCharacter, int)` for a flagged character; the Lua
  `WTAGarouVehicleGuard` also wraps `ISEnterVehicle:isValid` and `ISVehicleMenu.onEnter`
  so the refusal shows "You do not fit in there." even on an old jar.
- A shift INTO Crinos or Hispo that completes while seated (voluntary, forced, or debug) is
  resolved on the server (`WTAGarouVehicleShiftServer.lua`):
  - the seat's door part takes `VehicleShift.damageFor(form)` points: the form's clothing
    fraction of a 100-condition part. Crinos 38 (forced 100-Rage Crinos 75, same x2 as
    clothes), Hispo 25;
  - the window in that door takes the same points through `VehiclePart.damage` (which the
    engine routes to `VehicleWindow.damage`: condition, transmit, alarm), or with a 2% roll is
    smashed outright through `VehicleWindow.hit(player)`: the engine's own bare-handed smash
    (VehicleWindowSmash world sound, broken glass, zombie-audible noise, car alarm);
  - the owning client receives `VehicleEjected`, runs `vehicle:exit(player)` (the vanilla
    exit path) and, when the glass went, `BodyDamage.setScratchedWindow()` plus the
    "PainFromGlassCut" voice line, exactly what `SmashWindowState` does with empty hands.

Tuning lives in `WTAGarou.VehicleShift` (`SMASH_CHANCE = 0.02`, `PART_CONDITION = 100`,
`ENABLED`). If 38 points on a door feels like too much or too little, that is the knob.

### Bulk forms versus windows

`WindowClimbPatch` runs before `IsoGameCharacter.climbThroughWindow(IsoWindow)`: for a
flagged character and an open, unbroken, unbarricaded window it calls
`IsoWindow.WeaponHit(character, null)` (bare-handed smash, same call the engine's smash state
makes), then `setScratchedWindow()` and "PainFromGlassCut". The climb itself always
proceeds. Already smashed or destroyed windows pass untouched, so the usual
smashed-window climb cut still applies as in vanilla.

### Identity picker: confirm and lock

- Three true-form buttons (Human / Wolf / Berserker), coat buttons that only STAGE a choice,
  a "Confirm true form and coat" button, then the Wolf Gear row.
- Confirm opens an "Are you sure?" dialog listing the staged true form and coat. YES sends
  one `SelectWolfCoat`; the server locks `data.identityLocked` and refuses later coat or
  true-form changes. Wolf gear (`SelectWolfGear`) never locks.
- Once locked the window reopens as "Wolf gear" with the true-form and coat buttons disabled;
  the world context option reads "Wolf gear..." instead of "Wolf coat...".
- Saves from before 0.4.39 are not locked yet: open "Wolf coat...", pick, Confirm once. For
  testing, `/garou identity reset` (or `WTAGarou.Debug.resetIdentity()`) clears the lock.

## Static verification

- Lua: `tests/run.sh` green. New/updated: `rage_engine_test` (breed floor, drain, 35/75
  locks, Glabro revert from every form, lock denial carries `lockAbove`),
  `vehicle_shift_test` (door/window points, forced x2, 2% edge at 0.019 vs 0.020, destroyed
  glass, no-window door, non-bulk/unseated/non-Garou/client no-ops, client exit + cut,
  Lua entry guard), `wolf_coat_test` (three true forms, Metis tooltip, staged coat, dialog
  text, NO vs YES, server lock, gear exempt, reopened lock), `channel_hud_test` (breed-aware
  tooltips, denial texts).
- Java: `BulkFormTest` weaves `VehicleEntryPatch` and `WindowClimbPatch` with real
  ZombieBuddy translation onto fixtures (vanilla block preserved, smash once, cut once,
  smashed/destroyed/barricaded untouched, flag clear restores vanilla).
  `EnginePlaytestAdviceTest` weaves both patches into the real B42.21 `BaseVehicle` and
  `IsoGameCharacter` bytes. `engine_playtest_contract.py` pins `isEnterBlocked`, `exit`,
  `getSeat`, `getPassengerDoor`, `transmitPartCondition`, `VehiclePart.damage/getWindow/
  getChildWindow/findWindow`, `VehicleWindow.hit/damage/isDestroyed` + VehicleWindowSmash
  world sound, `climbThroughWindow(IsoWindow)` calling `canClimbThrough`, `IsoWindow.WeaponHit/
  isSmashed/isDestroyed/isBarricaded/smashWindow`, `BodyDamage.setScratchedWindow`, and the
  `SmashWindowState` order (cut before the PainFromGlassCut line).
- A static pass is implementation evidence only. None of this is confirmed in game.

## Smallest in-game test

Fully restart the game (not just reload the save). Both banners must read 0.4.39:
`[WTAGarou] Definitions loaded - version 0.4.39` and
`[WTAGarou Java] 0.4.39 loaded; bulk-form vehicle entry block and window-climb smash; ...`.

1. Picker: on an existing save, right-click world > "Wolf coat...". Expect three true-form
   buttons, Confirm greyed until a coat is clicked, the Are-you-sure dialog, and after YES the
   title "Wolf gear" with true form and coat greyed. Black/Camo must still switch.
   Then `/garou identity reset` and confirm Berserker + a coat.
2. Berserker: `/garou rage 12`, shift to Berzerker (Crinos) from Near-Human. Expect accept
   at 12 Rage, Rage 2 after. `/garou rage 50`, try Near-Human: expect "The Rage will not let
   you go yet." `/garou rage 35`: expect the shift to go through. `/garou rage 30` in
   Crinos: Rage should read about 28 after 4 s (0.5/s). Let it hit 0: expect Near-Human, not
   Human.
3. Default lock (Human/Wolf breed): in Crinos at 80 Rage try any form: denied; at 75 it
   works.
4. Vehicle: in Human/Glabro sit in a driver seat with an intact window, `/garou rage 60`,
   shift to Crinos. Expect: you are standing outside, the mechanics panel shows that door
   and window at about 62/100 (door) and 62 (window), and the HUD notice "You burst out of
   the vehicle." Then in Crinos right-click the car: enter options should refuse with "You
   do not fit in there." Repeat a few times for the 2% glass smash (alarm + hand cut).
5. Window: in Crinos or Hispo, open (do not smash) a window and climb through. Expect the
   glass to smash as you go, the PainFromGlassCut line, and a window cut in the health
   panel. Climb through an already smashed window: no extra smash.

Report what you observed; only your result promotes any of this to confirmed.
