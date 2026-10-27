# 0.4.52: Crinos head orientation and size calibration

The .52 live retest confirmed upright orientation, but facing remained
backward. The attachment rotation values below are historical and superseded
by [the .53 facing-only correction](CRINOS_HEAD_FACING_0453.md); scale 0.5 remains unchanged.

## Evidence and scope

The user confirmed the .51 split-screen ownership problems are gone. That
is live user confirmation, and those HUD, networking and controller paths
remain unchanged in this update.

The October 12 screenshot and `console-2.txt` show .51 running, with the
Crinos head backward/rolled sideways and too large. The user's estimate was
roughly 2–3x oversized. The screenshot shows game 42.21.0; the console confirms
Lua and Java .51. There is no head-load exception explaining the visible pose.
The log and screenshot are not published in this repository.

The earlier zero-rotation advice was incorrect: matching the mesh to body
space in Blender does not match it to the head bone's local basis.
The fix is confined to the head model script and head attachment selection.
The user's GLB, UVs, normals, embedded material, all PNGs, zero mount offset,
human body models and global form scaling are preserved.

## Orientation calculation

In the earlier Blender fitting thread, the user measured the new-head-to-old-
placeholder orientation as quaternion:

```text
W = 0.5
X = -0.5
Y = 0.5
Z = -0.5
```

Converting that rotation from Blender Z-up to glTF Y-up gives this mapping:

```text
new head X -> placeholder Z
new head Y -> placeholder X
new head Z -> placeholder Y
```

The old placeholder used a 90-degree X self-mount correction. This update
composes that old mount with the measured head conversion, rather than
guessing world-space Euler angles from one isometric screenshot.

Self attachments are NOT unconditionally inverted: the reference renderer
inverts them only if `ModelInstanceRenderData.invertAttachmentSelfTransform`
is true, then applies the model-instance scale
([AnimatedModel.java](https://raw.githubusercontent.com/Ketum-Git/PZ-Javacode/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/core/skinnedmodel/advancedanimation/AnimatedModel.java)).
The available 42.20.2 reference declares that flag with default false and
constructs attachment rotation through rotateXYZ in radians
([ModelInstanceRenderData.java](https://raw.githubusercontent.com/Ketum-Git/PZ-Javacode/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/core/skinnedmodel/model/ModelInstanceRenderData.java)).
That reference is not claimed to be the user's installed 42.21.0 binary.

Java therefore reads the ACTUAL installed engine's flag when attaching the
head and chooses between two head-only script mounts:

| Native self-attachment mode | Attachment | Script rotation XYZ |
|---|---|---|
| Inverted | `mount` | `180 0 -90` |
| Applied directly | `mount_direct` | `0 0 -90` |

Each produces the same old-placeholder-relative correction for that engine
mode. Tests compare the resulting matrices, not merely string values, and
require determinant +1 to rule out mirroring. Java never changes the engine
flag or another model's attachments. If that reflective field is unavailable,
the code logs a warning and falls back to `mount`; that case needs review
rather than being silently claimed correct.

## Head-only size adjustment

`WTAGarou_CrinosHead` now has model-script scale **0.5**, down from 1.0.
This halves the head's linear dimensions around its existing origin.
There is no additional Java scale multiplication. Male/female body model
scripts remain 1.0 and Crinos form scale remains unchanged.

This is a conservative first retest at the upper end of the user's 2–3x
oversize estimate, not proof of a perfect final fit. Correct orientation
should be established before adding a neck offset or fine-tuning size.

The first head injection reports:

```text
[WTAGarou Java][CrinosFit] head mounted; attachment=mount_direct;
instance.scale=0.5; expected head-only scale=0.5; body/form scale unchanged
```

`attachment=mount` is also valid when the native inversion flag is true.
The reported scale is read from the actual instance, not printed as a
hard-coded assertion that the installed script loaded.

## Shove issue: unresolved, with read-only diagnostics

The user explicitly confirmed testing with empty hands. Although one
screenshot contains a toolbox, that does not invalidate the empty-handed
test or explain the reported failure.

No attack animation behavior, collision timing, damage or audio rules are
changed here. The first two local empty-handed Crinos swings per session
queue a diagnostic after two player updates, allowing node selection to
settle. The Java reader reports:

- Actual animation-set name and loaded shove nodes.
- Whether `WTAGarouCrinosClaw` is present and its condition priority.
- `WTAGarouCrinosUnarmed` and `AimFloorAnim` values.
- Live states, nodes and animation-track names from the native debugger.

Look for `[WTAGarou][CrinosAttackDiag]`. This is observational only: it does
not set variables, load nodes, force clips, modify inventory or play sound.
Remote players are excluded and logging is limited to two samples per
local character per session. Missing diagnostic APIs fail safely.

## Verification and retest

The full Lua/asset and Java suites passed. Checks include both native
attachment modes, exact matrix composition, one head-only scale, unchanged
body scales, retained six-coat assets, read-only diagnostic output and the
existing .51 ownership/voice regression suites. The shipped JAR was rebuilt.
No live renderer test is possible here, so the final head fit and the
shove-animation cause are still unverified.

1. Fully quit the game, pull this branch and update the installed mod,
   including **both** `wtagarou_models.txt` and the rebuilt client
   `WTAGarouVisuals.jar`. Do not re-export the head GLB.
2. Restart and verify **Lua 0.4.52 / Java 0.4.52**.
3. Shift into Crinos, inspect the head from front and side, then turn/look
   around. Capture head-to-neck alignment and proportions.
4. Make two empty-handed standing attacks. If they still shove, send the
   fresh client `console.txt` containing the attack and fit diagnostics.
5. Only then tune any remaining neck offset/size. Do not change global form
   scale or the now-confirmed split-screen systems to compensate.
