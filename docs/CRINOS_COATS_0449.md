# 0.4.49: authored Crinos head and six shared coats

Historical implementation record. The zero-rotation/scale-1 head fitting
baseline below failed the later live test and is superseded by
[0.4.52 head fitting](CRINOS_HEAD_FIT_0452.md); the coat mapping remains valid.

## Change contract

- Target: integrate the replacement static, wolf-UV Crinos head and the author's
  six repainted human-UV body coats on `feature/cosmetic-model-swap`.
- Baseline: `1c834fd` ("disconnected alpha from shader"), including the author's
  corrected GLB, White/Black wolf coats, and final body-texture edits.
- Confirmed working: existing coat selection/persistence and earlier protected
  systems; the user now confirms normal GLB viewer rendering after disconnecting
  the texture Alpha output in Blender.
- Observed request: no dependencies on deleted CrinosHead PNGs, White/Black in
  Werewolf Startup, and new head mounting. The user's later deletion of female
  F_ textures supersedes the earlier request to implement that split.
- Must remain untouched: body/wolf PNG bytes, geometry/UVs/normals, form scales,
  balance, corpse handling, audio, HUD/controller changes, harness and gear,
  identity locks, native head/hair hiding and skin restoration.
- Evidence still needed: actual in-game alignment, neck overlap under rotation,
  body appearance on male/female models, multiplayer appearance.

## Implemented

- Shared registry contains Timber (`default`), Black, Blonde, Brindle, Brown and
  White. The existing startup grid and server allowlist consume that registry;
  no duplicated list, per-button special cases or identity-lock bypass is added.
- Every `crinosHead` is `WTAGarou_Wolf_<color>`. Every `crinosBody` is
  `WTAGarou_CrinosBody_<color>` with no F_ variant or deleted-head dependency.
- Java accepts safe wolf head names while retaining legacy custom
  `WTAGarou_CrinosHead_...` names. This compatibility does not request deleted
  files: shipped registry entries exclusively use wolf names.
- Per-instance head textures, readiness checks, retries, human-head and dress
  masks, hair hiding, ownership and restoration are preserved.
- The author already set the mount to `rotate = 0 0 0`, zero offset and scale
  1.0. Preserve those settings and remove obsolete placeholder-axis comments.
  No speculative 2x correction or global Crinos scale change.
- The author's corrected GLB has one static mesh/node, identity node transforms,
  one UV channel and 492 triangles. It uses opaque material semantics and is
  preserved byte-for-byte. No GLB or PNG changes are part of this code update.
- Lua/mod and Java load banners are 0.4.49. Rebuilt client JAR is included.

## Viewer diagnosis and future exports

The pre-fix head's material declared `alphaMode: "BLEND"` and `doubleSided: true`,
despite the embedded Brown PNG and every shipped wolf PNG being fully opaque.
No triangulation or normal edit was needed for the user's successful viewer test.
An equivalent material-only correction was tested locally, then discarded when
the user's fixed Blender export arrived. This update retains that exact export,
not a rewritten or regenerated copy.

Blender's current glTF exporter derives alpha mode from the Principled BSDF
Alpha socket, and its manual warns of viewer artifacts in blend mode
([Blender glTF manual](https://docs.blender.org/manual/en/latest/addons/scene_gltf2.html)).
In the head's Blender material, leave Image Texture **Color** connected to
Principled **Base Color**, disconnect the connection to **Alpha**, and leave
Alpha at 1.0. Preserve the body atlas transparency; the head and body use
different textures and do not share this material requirement.

The obsolete placeholder generator is not used to rebuild the authored head.
Keep the opaque material setup in the Blender source for subsequent exports.

## Verification

Run from `WTAGarou/`:

```sh
bash tests/run.sh
bash java/build.sh
bash java/test.sh
```

The asset test now reads indexed Blender GLBs and checks the real six coat
pairs, rather than assuming the old unindexed placeholder and eight opaque
512px swatches. Body atlases remain authored 256px RGBA; wolf atlases are 1024px.
Lua tests cover menu growth/screen clamping, staged White/Black choices, server
acceptance/restoration, identity locks, both-sex routing and Timber fallback.
Java fixtures cover wolf-family validation, unsafe-path rejection, asynchronous
readiness, instance-specific wolf textures, masking and restoration.

These are syntax/structural/fixture checks, not game rendering. This session
does not have the installed game JAR for the optional PZ_JAR native-byte checks.
Do not promote static checks to a live multiplayer or visual result.
All three commands above passed against the author's `1c834fd` GLB. Git also
confirms no changes to `common/media`, including the head GLB and every PNG.

## Smallest useful playtest

1. Fully quit Project Zomboid; pull this branch and update the actual installed
   WTAGarou copy. Include `42/media/java/client/WTAGarouVisuals.jar`, both media
   trees, scripts and Lua. Approve the changed module if ZombieBuddy asks.
2. Restart and verify both Definitions and Java banners say 0.4.49. Lua reload
   is not a replacement for clearing model/JAR caches with a full restart.
3. Use a fresh test character. Verify all six choices in Rage panel > Startup,
   select Black or White, choose true form/baseline and confirm once. Existing
   locked characters are deliberately not silently unlocked.
4. Shift through Crinos, Hispo and Lupus. Check matching coat selection and
   save/reload persistence. Repeat with the other new coat on a test character.
5. In Crinos, inspect front and side while still, turning the head, crouching,
   running and attacking. Check forward direction, pivot, neck overlap and size.
   If alignment is wrong, send front/side screenshots before changing scale.
6. Repeat on male and female characters. Sharing the body texture is the user's
   current choice, not proof that both meshes have identical UVs or neck fit.
7. Return to Homid: original skin/hair must return. Keep the existing transparent
   body-head area and Java head mask; do not rely on PNG transparency alone.

For single-player throwaway tests only, `garou("identity reset")` unlocks true
form, coat and baseline together. Reselect all three in Startup; this is not
required for existing saved coats and should not be used on a keeper save
without intending that reset.
