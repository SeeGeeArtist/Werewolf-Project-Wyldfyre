# Rigged harness and Wolf Gear picker

**Superseded renderer assumption:** the .33 playtest showed no harness.
The older `init` reference below does not match B42.21. Version .34 instead
hooks `initModel(ModelInstance, parentData)` before palette construction.
See [the correction and current verification](HARNESS_FIX_0434.md).

## Change contract

- Target: `feature/cosmetic-model-swap`, based on author commit
  [c860187](https://github.com/SeeGeeArtist/Zomboid-Garou/commit/c8601874811f927d3f4d6738860b8b73f447906d).
- Confirmed working to preserve: wolf body/coat swaps, worn-container bag
  visibility, harness visibility rules, cargo size/placement, true-form
  restrictions, Crinos cosmetics, shift/Rage/voice/animation behavior.
- Request: Black/Camo Wolf Gear row below Coat, saved selection for both
  harness and bags, and runtime support for the new skinned harness.
- Must remain untouched: authored GLB/PNG/animation contents, bag/cargo
  transforms, gameplay balance, shout behavior and private-alpha security gates.
- Evidence still needed: current installed B42 renderer compatibility,
  visual fit, spine deformation, form scaling and two-client observation.

## Implemented

- Wolf Gear offers Black and Camo below the Coat buttons. Selecting gear
  saves immediately; selecting a coat still saves coat/true form. The window
  stays open so selecting a coat does not make the gear row inaccessible.
  Gear selected-state labels update on the authoritative response.
- Server validates the variant and sender. Selection stores only
  `wolfGearVariant = "Black"` or `"Camo"` and cannot change gameplay state.
  Existing saves and older snapshots without this field default to Black.
- Model variants map through hidden zero-weight visual carrier items.
  Changing variant replaces the actual attachment only when its full item
  type differs. Re-entrant clothing events remain guarded; missing-item
  construction retries rather than recording a false successful attachment.
- Saved gear returns with the coat response; visual snapshots include gear
  and detect gear-only changes. Observer state does not modify peer mod data.
- Both harness scripts are non-static, use `WTAGarou_Wolf`, and share the
  authored GLB. Black still uses `WTAGarou_Harness.png`; Camo uses
  `WTAGarou_Harness_Camo.png`. Saddlebags remain static with original tuning.
- Rigged harness no longer receives Spine2 retargeting, rigid self-attachment
  rotation, offsets/pivots, or inverse-body scale compensation.
- Java selects the skinned script model explicitly on the carrier before
  render-data `init` builds the skin palette. It preserves the harness's
  skinning data, shares the wolf body's animation player, and clears both
  bone-mount fields and the self attachment. Body normalization and current
  form multiplier are baked once using the existing matrix publication path.
- Instance bookkeeping restores native fields on deactivation and discards
  stale references on pool reset. Shared models and animation players are
  not modified. The placeholder generator refuses to overwrite authored art.

## Why the loader handling matters

The item's property is still named `StaticModel`: that is the native attached
item's lookup property, not a declaration that our final render mesh is static.
The [older native loader reference](https://github.com/piromasta/PZDecompiled/blob/main/zombie/core/skinnedmodel/ModelManager.java)
shows `addStaticForcedTex` loading a static model independently of the model
script's flag, whereas `getLoadedModel(scriptName)` honors the script's
animation mesh and static flag. This is supporting reference, not proof of the
user's current B42 implementation. The new path uses the same script-loading
API already used by WTAGarou's wolf body and Crinos runtime.

The [older render-data reference](https://github.com/piromasta/PZDecompiled/blob/main/zombie/core/skinnedmodel/advancedanimation/AnimatedModel.java)
builds the skin palette in `init`, before `transformToParent`. Therefore changing
only the existing transform hook would be too late. The new init advice uses
the project's B42-style fields (`animPlayer`, `modelScript`, `tag`, `mesh`);
the exact running game's behavior must still be checked in the playtest.

The shipped harness has 1,888 weighted vertices, one UV channel, four-or-fewer
influences per vertex and all 44 wolf joint names. Joint order differs from the
wolf mesh. Never assign the wolf's skinning data directly to the harness;
native skin-transform mapping must receive the harness's own data/bind poses.

## Static verification

Run from the repository root:

```bash
bash WTAGarou/tests/run.sh
bash WTAGarou/java/build.sh
bash WTAGarou/java/test.sh
git diff --check
```

New coverage includes gear allowlisting/defaults, UI layout and persistence,
gear-only observer updates, attachment replacement and re-entry, failed
construction retry, GLB weights/UVs/joints, loader-before-palette ordering,
own skin-data retention, animator replacement, pool cleanup and missing assets.
The old three-attachment bag assertion was stale after the author's Camo
declaration; it now includes the fourth block without moving any bag.

Local result: the complete Lua 5.1 syntax/regression suite, asset tests, Java
build and Java integration suite pass, as does `git diff --check`. The rebuilt
0.4.33 JAR is included and contains no `zombie/` engine or test classes. No
files in the authored `common/media` asset tree were modified.

The first Actions run reached the existing Crinos asset test, then failed
because the runner lacked NumPy. The workflow now explicitly sets up Python
and installs NumPy/Pillow, which that pre-existing test imports. This is
test-environment setup, not a Crinos asset or gameplay change.

The optional real-game JOML test requires `PZ_JAR` and was not available here.
Mocks and structural checks do not prove rendered appearance or multiplayer
operation. Check the GitHub Actions run for the final commit separately.

## Smallest useful playtest

1. Pull this branch and copy the updated mod, including
   `42/media/java/client/WTAGarouVisuals.jar`, into the active installation.
   Completely restart PZ; Lua reload alone cannot replace the Java hooks.
   Approve the changed Java JAR through ZombieBuddy if prompted.
2. Look for `[WTAGarou Java] 0.4.33 loaded`. Enter Lupus wearing a container.
   The harness and bags should appear; bare wolf should still show neither.
3. Open the existing world menu's **Wolf coat...** picker. Switch Wolf Gear
   Black/Camo while transformed: both gear textures should change without
   changing the wolf coat, true form, Rage or inventory contents.
4. Walk, run, attack and sit/get up. Watch the harness follow multiple spine
   segments rather than rotate rigidly around Spine2. Check the underside,
   handle and ring for stretching or separation.
5. Switch Lupus → Hispo → Homid → Lupus. Harness should stay fitted, bags and
   carried tools should keep their established sizes, and gear choice should
   persist. Unequip the container and attachments to check disappearance.
6. Save/load and reconnect. Repeat with two players choosing opposite gear
   variants; each observer should see the correct gear, including late join.

If the harness is absent, rigid, rotated or oversized, send a screenshot and
`console.txt` lines containing `[WTAGarou Java][Harness]`, `skinned harness`,
`harness init`, and the Status output's `harness skin-init hook`. Do not adjust
the old Harness offsets to compensate before identifying which path failed.

This is a local-playtest candidate, not a cleared private-alpha release.
No Crinos shout burst or unrelated security/gameplay change is included.
