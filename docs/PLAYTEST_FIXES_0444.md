# 0.4.44 - October 6 late playtest fixes

Report: "Everything seems to work fine" for 0.4.43 (Lupus drunk driving
confirmed), then four items.

## Silent howl

Console: every `HowlStarted` ended in `[WTAGarou][Howl] client error: Howl
feedback module unavailable`. Cause: `WTAGarouDefinitions.lua` is re-run by
`/garou reload` and by the Startup panel (15 "Definitions loaded" banners in
one session). It did `WTAGarou.Howl = { ... }`, replacing the table that
`WTAGarouHowl.lua` had attached `onStarted` / `onStopped` / `startSound` to.
`WTAGarou.Silver` and `WTAGarou.VehicleShift` had the same shape. All three
now go through `defineTable(name, values)`, which updates the existing table
in place. Test: `tests/definitions_reload_test.lua`.

## Rage from damage dealt

`Rage.ON_DAMAGE_DEALT` 0.20 -> 0.10. Damage taken (0.75) and moodle
pressure untouched.

## Shoulders grab from the ground

Console offsets while dragging: carry -0.3, legs pickup -0.7, shoulders
pickup -0.9 (FromOnFront) and -1.2 (FromOnBack), trunk drag-out +0.3. With
the 0.4.42 carry extra added, the shoulders lift sat 1.6 / 1.9 m ahead of a
Lupus whose carry is at 1.0. `CorpseCarry.SHOULDER_PICKUP_DISTANCE`
(Hispo 1.3, Lupus 1.0 = 0.3 + GRAPPLE_FORWARD) now holds those two pickup
clips at the carry distance; nothing else changed. Tune in Definitions; 0
restores the 0.4.42 rule.

## Body dropped into a trunk / seat / trailer

The deposit clip has no corpse noun we can rely on (the window throw is
`Bob_ThrowBody_OutOFWindow`), so it took the motion derive and then had its
deferred bone swapped, which is the spin. `CorpseThrowPatch` (OnEnter of
`IsoGameCharacter.throwGrappledIntoInventory`) marks the thrower unless the
container is the character's own inventory (the stow); for 3 s the next
stationary clip is built pose-only as `Wolf_idle` with deferred rotation
off, exactly like a ground lay-down. "body" joined the corpse nouns.
Log caps raised (drag clips 24, guarded poses 16) so the deposit clip name
appears in the next console.

## Not changed

Drunk screen distortion while a Lupus drives (vanilla moodle effect, the
user is fine with it); vehicle damage; harness / gear / coats.
