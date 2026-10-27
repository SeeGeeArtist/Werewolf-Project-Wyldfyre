# WTAGarou 0.4.26: attachment stability and wolf attacks

This is a targeted response to the September 28 test with the repaired
ZombieBuddy JAR. Headless tests and bytecode checks are not an in-game visual
pass. The wolf body loader, approved sizes, gameplay carry values and shift
behavior are unchanged.

## Attachment fixes

- ModelInstance objects are pooled. Weak maps did not discard their old
  saddlebag, harness, slot or mouth role when the game recycled them. The new
  reset hook forgets all WTAGarou state at the actual lifetime boundary.
  Role assignment is also exclusive on each preparation.
- Human preview models owned by a wolf-form character no longer receive wolf
  bone retargeting or mesh compensation.
- Build 42.21's uploaded Model.DrawSolid bytecode shows that the instanced
  branch does not make the Shader.setScale(finalScale) call used in its
  non-instanced branch. The old gear compensation divided mesh size by 0.60
  while relying on that shader uniform to cancel it. When omitted, that
  produces a 1.667x Lupus mesh. Gear now carries the body-space multiplier
  in its top-level transform matrix; DrawChar does not apply it again.
- The instanced renderer consumes a copied shader-property transform. The
  engine's init/transform order can leave that copy older than attachment
  placement. Publish the completed matrix after placement and scaling so the
  instanced and non-instanced paths use the same placement, including child
  weapon parts.
- Anchor positions follow wolf size. Ordinary belt/back/mouth cargo cancels
  the form multiplier in mesh-local scale and retains its original mesh size.
  Harness and bags deliberately retain Hispo's 1.35 form multiplier. Weapon
  parts inherit the parent transform and do not get another body multiplier.
- `belt_left_screwdriver` now matches `belt_left`, in addition to existing
  `shovel_back` suffix matching. Unknown worn clothing remains hidden on wolves.
- A null-parent transform does not receive extra post-transforms.

The saddlebags remain the HorseMod-derived FBX introduced in 0.4.11, not a new
conversion. The latest console includes their model instance and retarget
records; that is evidence of attachment processing, not proof of visible
triangles. No FBX-to-GLB conversion or asset-placement tuning is included.
The observed disappearance/rotation still requires an in-game retest.

## Animation changes and tuning

In `42/media/lua/shared/WTAGarouDefinitions.lua`, find `WTAGarou.WolfGait`:

```lua
CYCLE_SLOWDOWN = 1.2, -- unchanged locomotion
ATTACK_SPEED = 1.5,   -- unchanged ordinary bite animation
STOMP_SPEED = 1.0,    -- new separate stomp-animation multiplier
```

Lower STOMP_SPEED to 0.8 or 0.75 for a slower stomp. The multiplier is applied
to the derived wolf clip for stomp-named human nodes, which currently map to
Wolf_attack. It is not a new stomp asset or a damage multiplier. Native
animation event timing remains tied to the playing track, so changing clip
duration also changes when that track reaches its events. Reload definitions
and shift off/on to push the setting, or restart the game.

Stationary attacks now get a full-body mask even when the supplied source
list is empty. Build 42.21 also re-applies the human node mask when a live
node transfers layers. A scoped post-hook restores the full-body wolf mask
there for stationary attacks only. Moving attacks, movement locks, priorities
and deferred movement are not changed. The log's stationary melee/turning
nodes motivated this repair, but it does not prove this was the sole cause
of the hip lock.

The user confirmed Wolf_Sit is broken in a separate GLB viewer and plans to
repair it and author Wolf_Sit_idle. Neither asset is altered here.

## Install and short retest

Pull the mod branch with the game closed. Use its rebuilt
`WTAGarou/42/media/java/client/WTAGarouVisuals.jar`; do not replace the repaired
ZombieBuddy JAR with it. Check for WTAGarou Java and Lua version 0.4.26.

1. Equip a belt item and a worn container in Lupus. Add/remove clothing,
   attach/detach a screwdriver, and shift off/on several times.
2. Repeat in Hispo: harness/bags should grow with the body, ordinary cargo
   should not. Check bag visibility, harness rotation and hidden glasses.
3. Bite while stationary, then strafe-bite. Check hips/hind legs in the
   stationary attack and verify strafing still looks as before.
4. Stomp once. Adjust STOMP_SPEED only if needed.

The existing harness/bag placement values were previously tuned amid unstable
scaling. They may still need calibration after this correction. No promise is
made that every visual issue is resolved until this test is run.

## Verification

- Twelve Lua/package suites: 1,988 assertions passed.
- Seven regular Java suites: 860 assertions passed, including translated
  ZombieBuddy advice for pool reset and the stationary layer-transfer repair.
- An additional 400 numerical checks use the uploaded game's actual JOML
  matrix and ShaderPropertyBlock implementations with synthetic bone
  placement. Repeated Lupus/Hispo changes and bag/harness/cargo reuse preserve
  expected mesh size, anchor size, copied shader placement and child scale.
- Offline weaving audit against the uploaded 42.21 JAR: 23 patch classes
  woven, zero unresolved. This is not a native engine boot or visual test.
- No proprietary game JAR or classes are included in the mod.

To run the optional matrix test locally, supply `PZ_JAR` to `java/test.sh`
and `JAVA_GAME` pointing to a Java runtime compatible with that game JAR.
Without PZ_JAR, the normal CI suites run without requiring game binaries.
