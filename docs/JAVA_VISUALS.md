# Java visuals and recovery test guide

## Status

Lua/mod version: **0.4.4-direct-wolf**, on `feature/cosmetic-model-swap`.
Java module version: **0.4.4**. Start with
[the current wolf/combat playtest guide](WOLF_COMBAT_044.md).
The scale multipliers remain unchanged. See [the regression contract](REGRESSION_CONTRACT.md) for the
nil-only shifting fix, HUD fixes, and permanent safeguards added in 0.4.2.
Version 0.4.3 nudges the HUD left by 16px and adds an opt-in,
read-only [panic trace](PANIC_TRACE.md). Version 0.4.4 adds the direct-body
wolf prototype and Garou-only Skully-style melee timing, including a new JAR.
This patch includes a compiled `WTAGarouVisuals.jar`, its Java source, and
tests. It has been compiled and tested outside Project Zomboid; the game
itself has not been launched by the assistant.

The prior 0.4.0 playtest failed during world loading, before it could prove
anything about model replacement or scaling. Its console ended with
`WorldDictionaryException: World loading could not proceed, there are script
load errors`, preceded by the missing `TimedActionScript 'Sewing'` recipe.
The speculative registry calls and starting-item construction also produced
errors. A successful Lua `pcall` would not have proved a working wolf render.

## What changed

- Replaced guessed registry APIs with `ItemBodyLocation.register` and a
  namespaced saddlebag ID, then passed the returned object to the body group.
- Updated saddlebag definitions to `ItemType = base:container`.
- Registered the bag tag, updated the shared slot identifier, and checked
  the item type before constructing starting gear.
- Temporarily disabled `CraftWolfSaddlebag`. The bags still exist; crafting
  is deferred rather than assigning another guessed timed action.
- Added independent Java render scaling for Garou characters only.
- Kept vanilla human meshes for the default test, including Glabro and
  Crinos. This preserves their existing skeleton and attachment definitions.
- Normalized experimental model-script scales to 1, so Java owns the size
  multiplier. No dependence on DynamicModelScale, no replacement game files,
  and no changes to the read-only reference mod folders.
- Changed neither shift/howl channeling nor combat, collision, Rage,
  movement, or healing mechanics in this patch.

## How the Java part works

The included DynamicModelScale JAR was inspected with `javap`, not assumed
to be a Lua-only implementation. Its `Patch_Model_DrawChar` targets
`zombie.core.skinnedmodel.model.Model.DrawChar`, uses the render instance's
character to choose the target, and modifies
`ModelSlotRenderData.finalScale`. Its head/neck handling uses separate
bone-transform hooks. Those extra hooks are not copied into this module.

WTAGarou has an independently written hook at that draw entry/exit point.
Lua reads the existing form data and supplies a per-character multiplier to
`WTAGarouJava.setScale`. Java keeps a synchronized weak-key map, avoiding
live Lua table access from the render thread. Each draw saves the original
scale, multiplies it, and restores the exact original value on normal or
exceptional exit. No global player-size setting and no repeated growth.
Unknown render layouts disable the hook with one diagnostic.

The reflection field names are based on the included DMS binary; the
actual PZ render layout still needs runtime confirmation. The module
does not contain DMS implementation classes or proprietary game classes.

[ZombieBuddy](https://github.com/zed-0xff/ZombieBuddy) supplies the Java
loader, Lua exposure, and annotation-based runtime patching. Configuration
follows its [modding guide](https://github.com/zed-0xff/ZombieBuddy/blob/main/doc/ModdingGuide.md):
`require=\ZombieBuddy`, `javaJarFile`, `javaPkgName`, and `ZBVersionMin`.

## Pull and test

1. Fully exit Project Zomboid.
2. In GitHub Desktop stay on `feature/cosmetic-model-swap`, fetch, then pull.
3. Keep ZombieBuddy and WTAGarou enabled. Leave DynamicModelScale disabled.
4. If ZombieBuddy asks about the new **WTAGarouVisuals.jar**, review and
   approve this module. It is unsigned local-development code. Do not turn
   off ZombieBuddy's security policy globally. Java code has unrestricted
   process access. This module now handles scaling, the wolf prototype and
   melee recovery timing.
5. Use a disposable test save first. Do not delete an existing save to
   resolve the previous script-load failure.
6. Confirm `Definitions loaded - version 0.4.4-direct-wolf` and
   `[WTAGarou Java] 0.4.4 loaded` in the console.
7. Test Homid -> Glabro -> Crinos -> Homid, then Hispo and Lupus.

| Form | Requested render multiplier | Default mesh |
|---|---:|---|
| Homid | 1.00 | Vanilla human |
| Glabro | 1.08 | Vanilla human |
| Crinos | 1.25 | Vanilla human placeholder |
| Hispo | 1.25 | Direct wolf prototype |
| Lupus | 1.00 | Direct wolf prototype |

These are render multipliers, not collision sizes. Hispo and Lupus request
the wolf body by default in this development build, but successful in-game
appearance is not yet verified. Use `/garou wolf off` to disable the prototype.

When a non-unit form is actually drawn, expect
`[WTAGarou Java] first scaled DrawChar; factor=...`.
`Java scale requested=...` by itself only proves state reached the Java API.
The startup "loaded" message alone does not prove the draw hook ran.

In the Lua debug console:

```lua
WTAGarouVisualStatus()
```

Look for `DrawChar observed=true`, `scaled draw observed=true` after
Glabro/Crinos, and `render hook disabled=false`.
If the Java API is missing, the mod logs once and leaves normal size.
Check approval/loading rather than reinstalling DynamicModelScale.

Verify that returning to Homid restores size; another character is not
scaled; reloading in Crinos reapplies scale; and changing forms does not
cause cumulative growth. Clothing/held gear and split-screen still need
visual testing. Multiplayer, corpses, muzzle offsets, and mounted behavior
are not validated or expanded by this prototype.

## Historical mesh probe: superseded in 0.4.4

The following describes the old experiment, not the current test procedure.
The new path hooks actual body selection and translates animation clips;
use [WOLF_COMBAT_044.md](WOLF_COMBAT_044.md), not this legacy probe.

DynamicModelScale is a scaling reference, not a wolf model/animation
replacement framework. Merely calling `setForceModelScript` from Java
would invoke the same engine operation as Lua and would not solve the
player-versus-wolf skeleton and animation-controller mismatch.

The old mesh probe remains opt-in, not enabled on normal startup:

```lua
WTAGarouTestWolfMesh(true)  -- experimental; test only after normal load/scale
WTAGarouTestWolfMesh(false) -- restore our previous model/skin override
```

Only Lupus/Hispo request a wolf mesh. This toggle is not saved.
Do not interpret a successful setter as a rendered or animated wolf.
If a mesh appears distorted, static, checkerboarded, or incompatible with
equipment, disable the probe and provide the console plus a screenshot.

The 0.4.4 implementation is based on nearby B42.20.2 source. Exact B42.20.4
runtime compatibility and visual output still require the user's playtest.

## Rebuild and local checks

The committed JAR is ready to pull; the user does not need a JDK to test it.
For developers with a JDK (17 or later) and the reference ZombieBuddy JAR:

```bash
bash WTAGarou/java/build.sh
bash WTAGarou/java/test.sh
bash WTAGarou/tests/run.sh
```

Set `ZB_JAR` to override the default framework path. Java dependencies are
compile-only; neither ZombieBuddy nor game classes are bundled into our JAR.

Local verification of the Java implementation in 0.4.1:

- 222 Java assertions, including repeated draws, per-character isolation,
  existing base-scale preservation, gear-slot fallback, missing data,
  clear/reset, and fail-closed handling.
- A real ZombieBuddy annotation transformation and ByteBuddy-instrumented
  fake renderer verify the shared local state and exceptional-exit cleanup.
- 26 original Lua mock assertions covered registry argument types, each form scale,
  same-online-ID players, death and trait loss, missing Java recovery,
  experimental mesh restoration and invalid starting-item guards.
- Lua 5.1 syntax checks and Git whitespace checks.

In 0.4.2 the Lua checks expanded to 28 visual assertions plus 539
channel/HUD assertions. GitHub Actions runs the Lua tests on matching
pushes and pull requests. The user has now confirmed Java scale changes
work in game; the new shifting/HUD corrections still need an in-game test.

Mocks do not validate the game's script parser, asset loader, Lua-Java
binding, or in-game visuals. Those remain explicitly part of the playtest.
