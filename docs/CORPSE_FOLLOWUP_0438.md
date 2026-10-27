# WTAGarou 0.4.38: corpse put-down and pickup audio

The .37 playtest confirms Q roar knockback, seated wolf head turning and corpse
pickup orientation. This patch preserves them and the previously confirmed
harness, attachments and coats.

## Change contract

```text
Target: corpse put-down rotation, pickup bark, radial title capitalization.
Confirmed working: Q burst, seated head look, pickup orientation, gear/coats.
Observed failure: put-down rolls the wolf; pickup still barks.
Must remain untouched: roar/knockback tuning, head look, pickup root guard,
  gear/assets, real bite/damage behavior and the player's own death path.
Evidence still needed: live .38 put-down orientation and pickup audio.
```

## Evidence and changes

- **Put-down:** the new console logs `Bob_LayDown_Person_OnBack`, whereas the
  previous predicate covered pickup and putdown spellings. Video frames show
  the roll during release while pickup keeps the wolf upright. The existing
  working root-pose guard now includes LayDown when paired with person, corpse
  or deadbody. Generic laying down, sleep and death remain excluded.
- **Pickup bark:** the video audio closely matches the authored Hispo bark,
  but the old console did not identify which sound callback emitted it.
  The .37 isDoGrapple-only filter was insufficient in the live interaction.
  This revision also checks native PlayerDraggingCorpse and performing-grab
  state, then rechecks on the next local update before playing a queued bite
  sound. Only audio waits that update; attack, hit, damage and action timing
  do not change. This is an implementation awaiting live confirmation, not
  a proven diagnosis of the remaining sound.
- **Diagnostics:** `[WTAGarou][WolfVoice]` prints bounded reason/state messages
  for suppressed utility grabs, attack sounds and pain sounds. Genuine pain
  remains audible during corpse handling, and deliberate Q is not modified.
- **Radial title:** idle `Resist\nthe change` becomes `Resist\nThe Change`.
  The two-line layout, callback and active `RESIST` countdown remain unchanged.

## Verification

Lua syntax and regression suites cover the exact radial title, unchanged
countdown/action, early and settled grab states, delayed playback exactly once,
death/form-change cancellation, normal bite audio after release and real pain.
Java tests exercise native LayDown names through the existing track adapter,
including marker selection, disabled deferred rotation and parameter restoration.
Existing roar, head-look, harness, asset, engine-advice and matrix tests are
also retained. Passing these tests is not an in-game visual/audio pass.

No authored GLB, texture, animation, sound asset, attachment transform, roar
logic or seated-look implementation was edited.

## Smallest next test

1. Fully exit the game, update the branch including the rebuilt
   `42/media/java/client/WTAGarouVisuals.jar`, and restart. Both Java and Lua
   banners must show **0.4.38**.
2. In Hispo, pick up and put down a face-up corpse, then a face-down corpse.
   Repeat in Lupus. Expect the existing upright pickup and now upright release.
3. Listen for the unwanted pickup bark, then perform a normal bite to verify
   its sound still works. If the pickup bark remains, send the new console.
4. Open Q's radial without an active countdown and check **Resist The Change**.
   The active warning countdown is intentionally unchanged.

The console should now report `corpse handling pose guarded` for the
`Bob_LayDown_Person_...` clip as well as pickup clips. New WolfVoice diagnostics
will help isolate any surviving bark without broadly disabling wolf sounds.

```text
Implemented: LayDown guard, stronger utility-grab audio filter, radial title.
Preserved: live-confirmed .37 behavior and .36 gear/coats/assets.
Static verification: Lua/Java/asset tests plus supplied-engine checks.
Awaiting live verification: .38 corpse release and pickup sound.
```
