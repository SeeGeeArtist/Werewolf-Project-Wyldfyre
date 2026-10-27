# Wolf size and control follow-up: 0.4.8

The September 22 playtest is the first user-confirmed visible Lupus and Hispo
transformation. Attacks worked and the player could equip a frying pan, but
wolves were oversized and turning, interactions and pathing were problematic.
This patch preserves the successful 0.4.7 loader/body path rather than
replacing it with a mount or spawned animal.

## What the playtest established

- **Visible forms:** The user confirmed Lupus and Hispo. This was a solo test;
  live multiplayer remains unverified.
- **Human return:** The supplied log records a wolf request at frame 831,
  then `Direct wolf request=false result=human` with scale 1 at frame 3025.
  Later wolf activations follow. The final recording ends in death, not a
  final intentional return-to-Homid check.
- **Furniture error:** At frame 15743, the contextual Rest/Sleep path enters
  `SeatingManager.getTotalDeferredMovement` and dereferences a missing clip.
  This is evidence for a furniture-motion query failure, not proof of the
  cause of every failed door or plain "Walk to" interaction.
- **Death errors:** The log reports a null current animation clip followed by
  an empty-track-list removal error during death. The prior cleanup reset the
  animator immediately, including from `OnPlayerDeath`.

## Changes

- **Wolf base size:** A render-only factor of **0.60** is applied only to the
  registered wolf body. This is a first visual calibration, not a measured
  final natural-wolf size. The approved form multipliers stay unchanged:
  Lupus 1.00 and Hispo 1.25, producing effective wolf factors 0.60 and 0.75.
  Human fallback and all other forms retain their previous scale.
- **Turning:** The track adapter sets `useDeferredRotation=false` for wolf
  tracks and restores the original pooled parameter afterward, including
  exceptional exits. The bundled walk/run `Translation_Data` rotation is
  constant. Feeding that into a human node requesting animation-driven
  turning can suppress normal input/path-facing rotation. Native player
  turning rates are retained; no extra Lupus agility bonus or special Hispo
  turn radius is added in this patch.
- **Furniture query compatibility:** A narrowly scoped Java hook detects
  queries against the active wolf skinning data. If the requested human
  clip is absent there but present in the vanilla human data along with its
  deferred bone, the query uses the human data. It does not copy human
  animations into the wolf skeleton or replace the visible wolf.
- **Death cleanup:** Removal of a dying player's wolf registration still
  happens immediately, but the animator reset waits for the queued
  `ModelManager.Reset` call instead of releasing tracks from inside the
  death callback. This addresses a concrete reentrancy risk; the full native
  death/ragdoll/corpse sequence still requires an in-game test.

## What this does not claim

The adapter continues to use wolf movement clips. It does **not** yet separate
all gameplay displacement and action timing from cosmetic animation. Door
opening, click-to-walk, attack reach feel, collision perception, backward
movement and corpse appearance are not declared fixed by these tests.
Allowing a wolf to equip a frying pan is also not resolved here.

The implementation keeps the original IsoPlayer. It does not install horse
movement, mount controls or animal collision, and the new size correction
does not change collision or movement speeds. The nearby engine reference
applies animal size only to an actual IsoAnimal in
[ModelSlotRenderData](https://github.com/Ketum-Git/PZ-Javacode/blob/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/core/skinnedmodel/model/ModelSlotRenderData.java).
That supports separating visible size from the reported horse-like feel;
it does not prove the user's interaction problems are solved.

The relevant reference paths are
[AnimationPlayer](https://github.com/Ketum-Git/PZ-Javacode/blob/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/core/skinnedmodel/animation/AnimationPlayer.java),
[SeatingManager](https://github.com/Ketum-Git/PZ-Javacode/blob/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/seating/SeatingManager.java),
and [AdvancedAnimator](https://github.com/Ketum-Git/PZ-Javacode/blob/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/core/skinnedmodel/advancedanimation/AdvancedAnimator.java).
They are Build 42.20.2 reference code, not a verified dump of the tested
42.20.4 game.

## Verification

Local Java 17 build passes. Real ZombieBuddy advice translation against
test fixtures passes 370 assertions: 222 scale, 127 wolf/combat/control and
21 explicit clip-loader checks. Lua checks pass 783 assertions, plus 54
asset/reference/package assertions. Syntax and Git whitespace checks pass.

Coverage includes base-size restoration on exceptional draws, no wolf
normalization on human fallback, restored pooled turning parameters, scoped
seating-data substitution, no human clips inserted into wolf data, and
exactly-once deferred death cleanup. Test-only engine signature stubs are
not included in the distributed JAR.

These tests are not native in-game verification. Literal `nil, nil` shifting,
suppressed raised-arms action layer, approved HUD layout, Rage text, combat
recovery and multiplayer visual snapshot rules are unchanged.

## Next short test

Fully restart the game after updating the mod and Java JAR; approve the
updated module if ZombieBuddy prompts. Confirm `0.4.8-wolf-control` in Lua
and Java `0.4.8`. Use a disposable solo save with only the intended test mods.

1. Shift Homid → Lupus. Check size against a doorway and turn in place.
2. Try keyboard movement, "Walk to" on empty open ground, then opening an
   unlocked door by both context menu and the interaction key.
3. Compare Hispo size and turning, then explicitly return to Homid and repeat
   the same door/path actions. This separates wolf-only failures from others.
4. Test Rest on furniture and, separately, death only in the disposable save.

If interactions still fail, send the log with the exact action and active
form. The next engineering step is deeper separation of player gameplay
motion/action timing from wolf pose playback, not replacing IsoPlayer with
a horse.
