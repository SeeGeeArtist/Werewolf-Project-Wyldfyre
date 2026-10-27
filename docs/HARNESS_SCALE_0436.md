# Harness body-scale correction, 0.4.36

## Change contract

- Target: `feature/cosmetic-model-swap`, based on abff8ca.
- Confirmed by user in .35: harness visible, follows walking/sitting,
  switches to Camo immediately.
- Observed failure: harness appears constant-sized between Lupus/Hispo,
  slightly too large in Hispo and floating well above Lupus.
- Must remain untouched: authored GLB/textures, working import/skin mapping,
  .34/.35 loader hooks, picker/persistence, bag/cargo tuning, form scales,
  gameplay, and Crinos head.
- Evidence still needed: corrected live fit through both forms, motion and
  reload. Static tests are not a rendered-fit confirmation.

## Implemented

The uploaded B42.21 Shader.startCharacter implementation chooses either:

- Static mesh: `setTransformMatrix(renderData.xfrm, true)`.
- Skinned mesh: `setMatrixPalette(renderData.matrixPalette)`.

The .35 harness was correctly skinned, but it still received the static gear
scale treatment: its xfrm was scaled while ScaleRuntime suppressed its
FinalScale factor. The skinned shader did not consume that xfrm, so the
harness missed the scale that the wolf body received.

Version .36 treats a classified harness attached to the active wolf like the
wolf body in ScaleRuntime. It multiplies the existing slot finalScale by
`BODY_SCALE * current form scale`, restoring the exact original slot value
after normal or exceptional draw exit. The harness no longer gets static
matrix-scale baking. Instance scale stays 1; no offsets, rigid bone mount,
inverse compensation, or copied wolf skin data are introduced.

The current log requests Lupus 1.15 and Hispo 1.55. With BODY_SCALE 0.60,
their body factors are 0.69 and 0.93, respectively; the harness now follows
those same factors rather than remaining at 1. These are derived from the
existing settings, not new tuning. The fault predicts a much larger mismatch
on Lupus than Hispo, consistent with the playtest.

Static bags, belt items, mouth cargo and weapon children keep their previous
matrix scaling. Body rendering itself is unchanged. The fix uses the existing
working body draw path, not a new shader, global renderer override, or palette
mutation. It does not establish support for every possible engine debug
rendering mode; the live rendering check remains required.

## Static verification

- Complete Lua/asset suite and Java integration suite pass.
- 123 new shader-scale parity/variant/repeated-shift/exception assertions pass.
  The fixture deliberately ignores xfrm for skinned models, matching the
  inspected shader branch rather than assuming all attachments use it.
- 900 numerical JOML checks cover unchanged static gear transforms and the
  harness's separate scale path, including actual log scales 1.15 and 1.55.
- Supplied-engine bytecode checks verify static transform versus skinned
  palette selection and the DrawSolid finalScale handoff.
- Existing actual-engine cache checks and advice weaving still pass.
- GLB/PNGs, animation assets, model scripts and combat files are unchanged.
  Rebuilt .36 JAR contains no engine or test classes.

## Smallest live test

1. Update mod files and Java JAR, fully restart PZ, and confirm both .36
   banners. Approve the changed JAR through ZombieBuddy if prompted.
2. With the same worn bag, compare Lupus -> Hispo -> Lupus from the same
   camera angle. Harness should remain fitted and grow/shrink with the body.
   Do not alter the GLB or legacy Harness offsets during this comparison.
3. Walk and sit, then switch Black/Camo. Preserve the confirmed deformation
   and immediate texture response. Bags/tools should look as before.
4. Console now logs bounded `skinned draw scale=0.69` / `0.93` lines for the
   current settings. If it still floats with those values, send matching
   screenshots in both forms and the console; investigate residual authored
   fit/import transforms rather than blindly adding another scale multiplier.

## Crinos Q versus shift burst

The console at frame 80946 says:

```text
form voice replaced Callout: sound=WTAGarou_CrinosRoar radius=45 sneaking=false
```

That confirms the Q voice handler selected the standing roar. It is not
proof of audible playback or knockback. The 45 value is the shout's
zombie-attraction radius, not a knockback radius.

Current code invokes the non-damaging radial stagger only when a shift into
Crinos completes, with radius 3 and the existing eligibility/collision rules.
Both recorded completions (frames 59171 and 78686) reported
`local pushes=0; network targets=0`. These counts do not establish why targets
were excluded or prove a successful nearby-zombie push.

Q currently plays the form voice and creates world sound; it does not call
the burst. Adding a Q-triggered knockback would be a new gameplay action,
requiring an explicit decision about repeated use/cooldown rather than
silently changing the existing shift-only behavior. No combat code changed.
To test the existing burst, complete a Crinos shift on a test save with a
living zombie within three tiles on the same floor and no wall/closed opening.

## Separate console issue

Later, after the logged death, the console repeats an IsoTree room-null
exception in FBORenderCell rendering. That stack is a separate diagnostic
from the harness scale mismatch and does not prove its cause. This patch
does not change tree/FBO rendering or attempt to suppress those errors.
