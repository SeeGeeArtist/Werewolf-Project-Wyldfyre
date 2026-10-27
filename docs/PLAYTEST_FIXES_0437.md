# WTAGarou 0.4.37: roar and wolf action follow-up

This patch follows the user's .36 playtest, which confirms that the harness,
attachments and coats now look right. Those visuals and all authored assets
remain unchanged; this is a runtime/Lua follow-up, not another GLB revision.

## Change contract

```text
Target:
  Standing Crinos Q knockback; wolf corpse handling, bite-sound filtering,
  eating masks and furniture Ctrl-look.
Confirmed working:
  .36 harness fit, gear attachments and coats; earlier harness skinning,
  walking/sitting deformation and immediate Black/Camo switching.
Observed failure or request:
  Q should push like a completed Crinos shift while attracting zombies.
  Corpse lifting/lowering rolls the wolf; pickup makes an unwanted bark.
  Eating raises the front without corresponding hindquarter animation.
  Furniture Ctrl-look should turn the wolf head.
Must remain untouched:
  Authored GLBs/PNGs/animation files; harness/bag/cargo placement and scale;
  coat state; shift channel timing; existing bite damage; Rage balance;
  true-form death/corpse handoff; human and Crinos head rendering.
Evidence still needed:
  .37 live visual/audio behavior and a two-client roar ownership test.
```

## Implemented

- **Standing Crinos Q:** the patched native Callout creates a one-shot edge.
  The local player's Lua update consumes it and requests the existing burst.
  The server checks the actual sender's Garou trait, living Crinos form and
  non-crouched state, then selects targets using the same path as completed
  Crinos entry. Default radius remains 3 tiles and force remains 1.
- **Noise downside:** standing voice/radius remains the existing Crinos roar,
  45 tiles. Accepted multiplayer requests also generate world noise on the
  server, so a burst request cannot silently bypass the downside. No extra
  Rage charge or long ability cooldown was added. A 250ms request flood guard
  rejects immediate duplicate/spam requests. Crouched Q remains only a growl.
- **Authority and filters:** request payload geometry is ignored. The server
  determines position, range, force and zombie IDs. Existing walls/closed
  barriers, other floors, dead-zombie and NPC exclusions remain. Only the
  owning zombie simulation applies native non-damaging stagger; existing
  packet serial deduplication is reused. No damage or teleport was introduced.
- **Corpse lifting/lowering:** person/corpse pickup and putdown clips keep
  the authored wolf idle pose instead of deriving one from a human root.
  Deferred movement uses the wolf's unskinned Translation_Data and deferred
  turning is disabled for those fallback poses. Native interaction timing,
  corpse/grapple behavior and the wolf player's own death handoff are unchanged.
- **Pickup bark:** the weapon-swing sound callback now excludes grapple grabs.
  In the supplied B42 engine, SwipeStatePlayer raises OnWeaponSwing for those
  grabs before setting the performing-grapple-animation flag. The earlier
  isDoGrapple flag is therefore the guard; actual bites, pain and Q stay audible.
- **Eating:** whole-body masks now survive layer transfers for eating/drinking,
  including empty initial masks. Gait/idle sublayers remain inert and moving
  attack behavior is preserved. HeavyBreathing no longer matches the substring
  "eat" and accidentally selects Wolf_eat.
- **Seated look:** on furniture, the wolf head uses native smoothed Ctrl-look
  input and the engine's head-angle limit. A model-space yaw is applied at
  the head's own pivot after pose sampling and before skin-palette calculation.
  Authored pitch, head position, body and paws are preserved by construction.
  No human spine twist, reparenting or root counter-rotation is re-enabled.
  Releasing Ctrl returns through native smoothing; getting up, death and
  leaving wolf form bypass the override.

## Evidence and limits

The .36 console identifies the pickup clips as
`Bob_PickUp_Person_FromOnBack`, `Bob_PickUp_Person_FromOnFront` and
`Bob_PickUp_Person_OnBackLegs`. It also shows HeavyBreathing mapping to eating.
The corpse-roll explanation remains a runtime hypothesis because that console
did not print the original deferred bone. The new bounded
`corpse handling pose guarded` message reports it for the next test.

The supplied private B42.21 engine was inspected locally. It establishes the
grapple/weapon-swing ordering, normalized head-look input, head-pivot helper
and pose-sampling/skin-palette order. No engine binaries or decompiled files
are included in this repository.

Static verification includes Lua syntax and regression suites, Java fixture
tests using real ZombieBuddy advice, private engine signature/order checks,
advice weaving into the supplied class bytes, and existing harness, asset and
attachment-matrix checks. These checks do not establish in-game appearance,
audio timing, knockback distance or multiplayer behavior.

## Focused playtest

Fully exit Project Zomboid, update this branch including
`WTAGarou/42/media/java/client/WTAGarouVisuals.jar`, and relaunch. Both the
Lua Definitions banner and Java load banner must say **0.4.37**.
Reload defs alone cannot load the rebuilt Java code.

1. In Crinos, complete a shift near a few unobstructed zombies as the control.
   Then, while standing, tap Q near them: expect the same non-damaging stagger
   and the existing loud roar. Nearby zombies beyond the burst may hear it.
   Crouched Q must growl without a burst. Walls and other floors still block.
2. In Hispo, lift and lower a corpse lying face-up, then face-down. Repeat in
   Lupus. Check for sideways rolling and the unwanted pickup bark; confirm a
   normal bite still makes its sound.
3. Eat while standing still in both wolf forms. Watch the front and hind legs
   together, cancel once, then walk and bite to check mask reset.
4. Sit on furniture in each wolf form. Hold Ctrl and move the cursor left and
   right: only the head should turn, not the harness, torso or paws. Release
   Ctrl, then stand up. Confirm head pose returns normally.
5. Briefly switch Black/Camo, walk and sit in each wolf form to catch any
   regression in the now-confirmed harness/attachments/coats.

For multiplayer, repeat the standing roar with a second client owning the
nearby zombies. Verify one reaction per target, noise attraction, no replayed
push, and no effect on players/NPCs. This remains a live release gate.

If anything persists, send the fresh console plus which form/action failed.
A short clip is particularly useful for a remaining corpse roll or head-look
direction issue. The new Java diagnostics and
`[WTAGarou][CrinosBurst] standing Crinos Q roar` distinguish an unloaded build,
an input/authority failure and a visual failure.

## Status

```text
Implemented: requested Q burst and scoped wolf action/look changes.
Preserved: confirmed harness, attachments, coats and authored assets.
Static verification: covered by repository tests and private engine checks.
Awaiting live verification: all new .37 visual/audio behavior and MP roar.
```
