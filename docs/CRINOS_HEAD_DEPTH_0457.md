# Crinos hidden-head depth follow-up: 0.4.57

## Baseline and evidence

This follows commit `9400a34` / .56 on `feature/cosmetic-model-swap`.
The user's October 13 playtest confirms makeup hides in Crinos and returns
in human forms, and hats/accessories fit well enough with head-relative scaling.
Those behaviors are now locked alongside the approved visible head scale 0.6
and orientation.

The new report describes patches at the hidden human head surface that erase
parts of the replacement head and even vehicles behind the character, exposing
floor texture. Three supplied screenshots show the head area at different
facing angles. The supplied console
loads Lua/Java .56 and logs both the .6 head mount and the successful accessory
scaling hook. It does not contain a GPU/shader trace proving the cause.

Current source masks the original human head in the composed body texture;
that does not remove the head's skinned geometry. A depth-writing interaction
is consistent with the symptoms but remains a hypothesis. This change avoids
relying solely on transparency for that hidden surface rather than guessing
at the current game shader or changing global depth/blending settings.

## Narrow rendering change

After native `initMatrixPalette` copies the body's skinning transforms, the
new hook contracts only the hidden human head's matrix around its current
animated pivot:

```text
hidden-head vertex = animated pivot
                   + 0.001 * (original skinned vertex - animated pivot)
```

The tiny nonzero scale avoids a singular normal transform. It pulls the
hidden head's geometry inside the visible replacement instead of leaving
full-size invisible surfaces where they can interfere with other rendering.
Vertices with mixed neck/head weights can still be affected near the join;
neck appearance must therefore be checked in game.

- **Body-only scope:** only a body with a current, successfully mounted Crinos
  profile qualifies. Other characters and unregistered clothing render data do not.
- **Separate indices:** the mesh's `SkinningData.boneIndices` selects the
  palette entry; the animator's bone index selects the current head pivot.
- **Render-copy only:** shared animation matrices, the original mesh, and
  accessories using the head bone are never edited.
- **Publication order:** the correction occurs before native shader-property
  publication, covering the ordinary palette and its later instanced copy.
- **Rebuild/restoration:** native palette generation starts from the unchanged
  pose each time. There is no cumulative shrinking, and the next normal-form
  rebuild is untouched.
- **Fail closed:** missing ownership, skin data, bone indices, an unready
  palette, invalid/nonfinite matrices, or incompatible buffer layouts leave
  the native palette unchanged.

The successful application logs:

```text
[WTAGarou Java][CrinosHeadCull] hidden human head contracted in body render palette only; scale=0.001; shared pose, replacement head and accessories unchanged
```

**0.001 refers exclusively to the invisible human head. The visible Crinos
head remains at its approved 0.6 scale.**

## Preserved

No GLB, coat PNG, model script, visible head scale/orientation, headwear matrix,
makeup filter, texture-refresh, clothing policy, healing, voice, multiplayer,
or split-screen behavior was changed. The shove-animation work remains deferred.
No graphics-option changes or new Blender export are required.

The console also includes an AtomUI joypad string-formatting error while
opening reading UI in Glabro. That separate path is outside this visual patch
and was not changed or treated as the source of the head artifact.

## Verification

- Full Lua syntax/gameplay/assets/package suite passes.
- Java supplement rebuilt and full Java suite passes.
- 1,487 new checks exercise actual woven advice with synthetic native-shaped
  palettes: changing pivots, mismatched mesh/pose indices, repeated rebuilds,
  byte-identical unrelated bones, shared-pose preservation, shader publication,
  accessory exclusion, same-body normal-form restoration, per-character
  isolation, and invalid-input behavior.
- All 2,128 existing real-JOML accessory matrix/advice checks still pass.
- Existing makeup snapshot/restoration and cosmetic ownership checks pass.

These tests do not render the user's scene or prove the visual artifact is
gone. Engine layout evidence is from the pinned B42.20.2 reference; live
compatibility with the user's B42.21.0 runtime remains part of the test.

## Focused live test

1. Update the branch and fully exit/restart the game for the new JAR.
   Confirm Definitions and Java both load **0.4.57**.
2. Shift to Crinos at the same camera zoom, first without a hat, then wearing
   the same hat/glasses/earrings that fit in .56.
3. Face several directions in front of a parked vehicle or opaque furniture.
   Look for floor-colored cutouts through the head or background object.
4. Turn, aim, and crouch. Check the head/neck join for a new gap or stretched
   seam, while confirming the visible head and accessories retain their fit.
5. Return to Glabro/Homid and verify makeup and ordinary head/accessory
   appearance still restore. If available, repeat with a remote online player.

If patches remain, send the console and a screenshot at the same angle.
The presence or absence of `[CrinosHeadCull]` distinguishes an inactive or
incompatible hook from a successful contraction that did not solve the cause.
