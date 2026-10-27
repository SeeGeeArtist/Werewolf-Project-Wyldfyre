# 0.4.80: climb-arc compression for the scaled bipeds (Java build)

Source: the Oct 21 report ("the fence-climbing animation should be
vertically offset per form scale") and the client console that arrived
with it.

## What the client console said (silver knife / invisible model)

The file holds the last 140 frames before the client died: every frame
throws

    NullPointerException: Cannot invoke "String.indexOf(int)" because "name" is null
      ScriptManager.getItemName  <- ModelManager.addStaticForcedTex <- addStatic
      <- addEquippedModelInstance <- DoCharacterModelEquipped
      <- ResetCharacterEquippedHands <- ModelManager.update

That is the equipped-weapon model path asking the Build 41 Silver Knife /
Silver Machete definition for a hand model it did not have (no
`WeaponSprite`). `ModelManager.update` aborts at that step every frame, so
no character model is rebuilt: that is also the "invisible model after
reload" (the knife was still in hand when the save loaded). The 0.4.79
weapon definitions (full 42.20 clones with `WeaponSprite =
HuntingKnifeForged` / `MacheteForged`) apply to the items already in the
save, so a fresh load should draw the model again; if the hands stay
empty-looking, drop the old knife and spawn a new one. The couch crash is
most likely the same path (sitting re-runs the equipped-hands reset) if the
knife was equipped; unconfirmed until a console covers it.

## Climb-arc compression (`ClimbPatch` / `ClimbRuntime`)

Climb-over-fence, climb-over-wall and climb-through-window animations start
on the ground and lift the whole skeleton (the pelvis rises by the fence
height in the bones; the character's z never changes). `FinalScale` scales
the model about its origin at the feet, so a Crinos (1.65) was drawn
climbing a fence 65% too tall and the hands floated above the top.

The hook runs on `AnimationPlayer.UpdateSkinTransforms` (the one call the
standard and shared-skeleton animation paths both make once the frame's
model-space bone transforms exist). While `getCurrentState()` is one of
`ClimbOverFenceState`, `ClimbOverWallState`, `ClimbThroughWindowState` and
the character is a scaled biped:

- rest = pelvis height (`Bip01_Pelvis`, else `Bip01`; translation m13 =
  model up, as `Model.boneToWorldCoords` reads it) on the first frame of
  the state;
- lift = max(0, pelvis height now - rest);
- every bone's m13 += -lift x (1 - 1/scale).

After `FinalScale`: scale x (rest + lift/scale) = scale x rest + lift, the
vanilla lift on a scaled standing height. Horizontal root motion in climb
states is still vanilla (`StrideRuntime` skips climbs so the hands land on
the geometry). Sub-model players (clothing) take the body player's offset
for the frame. Wolf forms are skipped (own rig). An implausible rest height
(outside 0.2-3.0 model units, i.e. a different matrix layout) disables the
hook once with `[WTAGarou Java] climb compression disabled`. The first
application prints `[WTAGarou Java][Climb] vertical root motion compressed
in <state> (scale, rest pelvis, first offset)`; `WTAGarouJava.status()` and
`climbStatus()` carry frames/applied/last lift.

Limits: the gate is the local state machine, so a remote player's climb is
compressed only if their state replicates as a climb state on this client
(watch for it in MP). The arms are still scaled, so a Crinos's hands reach
past the fence top rather than floating above it.

Tests: `java/test/ClimbTest.java` (17 checks: state set, offset math,
scale-1 untouched, rest capture, all bones shift equally, drawn height =
scaled standing + vanilla lift, no push below rest, sub-model follows,
re-capture on a new climb, fail-closed on a bad layout). Java 27 PASS.

## Waiting on a Java build (for approval / deferral)

1. Climb-arc compression: in this build.
2. Lupus pet flaps (SILVER_TRAPS_0477 roadmap 6): the Lua half (seeded
   pick of some residential exterior doors, flap overlay, Lupus-only
   interaction) can be written any time; the passability of a shut door
   for one form only is a Java collision exception (`IsoDoor` /
   `IsoGridSquare` blocked-movement checks gated on the Lupus form).
3. Nothing else in the docs is parked on Java. The Crinos Q shout gesture
   (`ShoutEmotePatch`, 0.4.63) is already in the JAR and still awaits a
   live check.
