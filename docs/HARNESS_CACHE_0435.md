# Harness static-first cache correction, 0.4.35

Live follow-up: user confirms the harness now appears, follows walking/sitting
and switches to Camo immediately. Preserve this loader fix. The remaining
oversize/constant-size issue is addressed by the [0.4.36 shader-scale
correction](HARNESS_SCALE_0436.md), not another import or GLB change.

## Change contract

- Target: `feature/cosmetic-model-swap`, based on b45343a.
- Confirmed working: the .34 initModel hook executes and both Black/Camo
  visual carrier items attach. Preserve previously visible bags and cargo.
- Observed failure: user still sees no harness. Fresh .34 console reports
  `waiting: mesh/skin/texture; WTAGarou_Harness mesh=true skin=false texture=true`
  at frame 2403; no successful skinned-harness preparation follows.
- Must remain untouched: authored GLB/PNGs, model declarations, bag/cargo
  transforms, Lua attachment rules, gear persistence and gameplay.
- Evidence still needed: visible/deforming/fitted harness after this fix,
  form switching, save/reload and multiplayer.

## What the previous fix missed

The .34 hook correction is necessary and the new console proves it runs.
It did not address the earlier import into the shared mesh cache.

Inspection of the previously supplied B42.21 engine shows:

- Native attached items call `ModelManager.addStaticForcedTex`, which requests
  the mesh through a static Model even when the script says `static=false`.
- Model keys distinguish shader, texture and static mode. However, the Model
  constructor asks MeshAssetManager for `AssetPath(meshName)` only.
- AssetManager returns the existing mesh for that path, including while it is
  still loading, rather than replacing its import parameters.
- ModelMesh uses StaticMesh versus Normal import mode from those parameters.
  A later nonstatic Model cannot restore a skin discarded by the first import.

This explains why the authored GLB's weights can pass structural tests while
the game-loaded harness still has a null skin. The console directly establishes
null skin, not the cache's internal history; the cache mechanism is supported
by the actual engine implementation and a reproducing test.

## Implemented

`WolfHarnessLoadPatch` requests `getLoadedModel(scriptName)` on entry to native
`addStaticForcedTex`, for `WTAGarou_Harness` and `WTAGarou_Harness_Camo` only
(also accepting the `Base.` prefix). That requests the nonstatic mesh with the
script's wolf animation mesh before native code can import it as static.

The native carrier loader still runs and retains all instance allocation,
parent/owner and attachment bookkeeping. The existing .34 initModel hook then
selects the nonstatic render Model before the skin palette is built.
Black/Camo share the same skin-preserving mesh and retain separate textures.

No shared mesh is reloaded or mutated, no wolf skin data is substituted, and
no assets/model scripts are edited. Other items, including both saddlebags
and the Crinos head, never enter the new preload path.

## Static verification

- The new 28-assertion fixture first reproduces static-first failure, then
  checks skinned-first loading, asynchronous requests, both variant orders,
  namespaced script IDs, non-harness isolation and exception containment.
- Eight checks execute the supplied engine's actual AssetManager cache
  implementation with a synthetic leaf asset. Both pending and ready cached
  assets retain the first request's parameters. This is not a native GLB import.
- Bytecode checks cover carrier loading, mesh-name keys and render ordering.
  Actual ZombieBuddy advice is woven into both supplied engine target classes.
- Full Lua/asset and Java suites pass, including 404 numerical JOML checks.
  Authored assets/model scripts remain unchanged; rebuilt JAR contains no
  engine or test classes. Rendering itself is still unverified.

```bash
bash WTAGarou/java/build.sh
bash WTAGarou/tests/run.sh
PZ_JAR=/path/to/projectzomboid.jar \
JAVA_GAME=/path/to/jdk25/bin/java JAVAC_GAME=/path/to/jdk25/bin/javac \
JAVAP_GAME=/path/to/jdk25/bin/javap bash WTAGarou/java/test.sh
git diff --check
```

PZ_JAR is private/optional and never bundled. The native cache test compiles
against that JAR, so JAVAC_GAME must support its class version (25 for this
supplied engine). Normal public CI uses fixtures without the private engine.

## Smallest live test

1. Update the mod and rebuilt Java JAR. Fully exit PZ and restart; Lua reload
   cannot clear a mesh previously cached as static. Approve the JAR if asked.
2. Confirm Java and Lua 0.4.35. Enter Lupus wearing the same bag, then switch
   Black/Camo. No belt item is required. Do not re-export or retune the GLB.
3. Expected diagnostics:
   `skinned mesh requested BEFORE static carrier: WTAGarou_Harness...`,
   followed by `skinned WTAGarou_Harness...; own skin data; shared wolf animator`.
4. If still absent, send the new console and screenshot. A successful skin log
   would move the investigation to rendering/fit; another null-skin log would
   keep it at import/cache. Do not conflate either with a confirmed visual pass.
