# Direct wolf body and melee timing: 0.4.4

Branch: `feature/cosmetic-model-swap`. Lua version:
**0.4.4-direct-wolf**. Java module: **0.4.4**. This release contains a
compiled JAR and an enabled development-branch wolf prototype. It has not
been run in Project Zomboid by the assistant and is not claimed visually
correct, complete, or multiplayer-validated.

## What changed

- **Swing timing:** Garou-only `OnWeaponSwing` handling uses the categories
  found in [Skully's swing module](https://github.com/SeeGeeArtist/Zomboid-Garou/blob/41191c9/SkullysFasterSwing/42/media/lua/shared/swing_time_skully.lua).
  Heavy: multiply current CombatSpeed by 1.50, capped at 1.51.
  Stab: 1.22, capped at 1.23. Other melee: 1.10, capped at 1.11.
  WTAGarou never reduces a speed already above a cap. Firearms, dead
  characters and non-Garou are excluded.
- **Recovery timing:** The Java hook intercepts the actual
  `SwipeStatePlayer.OnAnimEvent_SetMeleeDelay` event. Its maximum delay
  values come from [Skully's attack XML](https://github.com/SeeGeeArtist/Zomboid-Garou/tree/41191c9/SkullysFasterAttackSpeed/42/media/AnimSets/player/melee):
  one-/two-handed 12, knife 1, spear 8, heavy 4. These are engine delay
  units, not seconds. Already-shorter delays stay shorter. Unmapped
  categories, including unarmed, are unchanged.
- **Scope:** Both timing features apply to Garou characters including
  Homid. Existing per-form `attackSpeedMult` values are not additionally
  stacked onto Skully's capped values in this release. WTAGarou does not
  replace the global player XML graph or change every survivor's weapons.
- **Standalone mods:** Neither Skully module is required. When
  `SkullysFasterSwingSpeed` is active, WTAGarou skips its own swing boost.
  Recovery uses a minimum, so already-shortened XML values are not multiplied
  again. For an isolated playtest, disable both standalone Skully mods.
- **Direct wolf visuals:** Hispo and Lupus request the actual wolf body
  through `ModelManager.getBodyModel`. The existing player remains the
  player; no IsoAnimal is spawned, no mount is spoofed, and no invisible
  duplicate is created.
- **Wolf animation adapter:** Player track requests are translated to
  existing wolf idle, walk, run, attack, hit-reaction, sit, eat and death
  clips. The player's gameplay/action graph and its event definitions remain
  in place. Human limb reparenting/twist overrides are cleared only on the
  wolf animation player, and human upper-body masks become full-body wolf
  tracks. This is a clip adapter, not a complete independent wolf AnimSet.
- **Appearance restoration:** No HumanVisual model/skin field is changed.
  The body override is a weak per-character Java registry. Returning to a
  biped form, dying, losing the trait, entering a vehicle, or disabling the
  prototype removes it and requests a normal model/animation rebuild.
  Equipment meshes are hidden while wolf-rendered, not removed from inventory
  by this adapter. Existing gameplay clothing rules remain separate.
- **Assets:** Four existing GLBs had duplicate or case-mismatched embedded
  clip names. They now match their filenames. Their binary motion data is
  byte-for-byte unchanged, and reference mod directories remain untouched.

## Why this is different from the old mesh probe

The inspected
[B42.20.2 ModelManager](https://github.com/Ketum-Git/PZ-Javacode/blob/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/core/skinnedmodel/ModelManager.java)
selects the default male/female body for a non-animal player in
`getBodyModel`, rather than using `HumanVisual.getModel`. Therefore simply
setting `forceModelScript` is not enough in that path.
The new hook changes that body selection, which also feeds
[IsoGameCharacter.getAnimationPlayer](https://github.com/Ketum-Git/PZ-Javacode/blob/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/characters/IsoGameCharacter.java).
Changing bodies makes the engine allocate the matching animation player.

The clip adapter works at
[AnimationPlayer.play](https://github.com/Ketum-Git/PZ-Javacode/blob/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/core/skinnedmodel/animation/AnimationPlayer.java),
where the requested clip and bone mask can be replaced without replacing
the actor's gameplay state machine. Pooled track parameters are restored on
both normal and exceptional returns. The asset importer uses
[embedded animation names](https://github.com/Ketum-Git/PZ-Javacode/blob/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/core/skinnedmodel/model/jassimp/ImportedSkeleton.java),
which is why the variant names needed normalization.

The wolf texture is applied only to the render-data record, not the player's
saved appearance or shared model instance. It is retained for deferred
consumption because [RenderList.DrawQueued](https://github.com/Ketum-Git/PZ-Javacode/blob/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/core/rendering/RenderList.java)
holds a reference to that record. The engine overwrites the texture when
the record is initialized/reused. The existing scale save/restore contract
is retained.

These sources are **B42.20.2**, not a verified dump of the user's
**B42.20.4** installation. Passing annotation-transformer tests does not
prove the signatures, loader behavior, or visuals in the user's game.

## Install and test

1. Fully quit the game, then pull:

   ```bash
   git pull origin feature/cosmetic-model-swap
   ```

2. Use a disposable test save with ZombieBuddy and WTAGarou. No
   DynamicModelScale, WolfMod or Skully dependency is needed for this patch.
   Approve the updated `WTAGarouVisuals.jar` if ZombieBuddy requests it;
   do not disable its security policy globally. This is executable Java code.
3. Check for `Definitions loaded - version 0.4.4-direct-wolf` and
   `[WTAGarou Java] 0.4.4 loaded`.
4. Test Homid -> Hispo -> Homid, then Lupus -> Crinos -> Homid. Check
   idle, walking, running, turning and crouching before fighting.
   The wolf prototype is enabled automatically for Hispo/Lupus on this
   development branch. Transformation channeling remains literal `nil,nil`.
5. Check one melee weapon, knife, spear and heavy weapon. Compare swing
   speed and pause after the hit separately. Check firearms remain normal.
6. Use `/garou wolf status` and send `console.txt` plus a screenshot or
   short clip of any visual failure.

### Immediate escape

```text
/garou wolf off
```

Or in the Lua debug console:

```lua
WTAGarouDirectWolf(false)
```

This restores the normal body without changing the gameplay form or the
approved scale values. `/garou wolf on` retries the direct prototype;
`/garou form Homid` changes the actual form as well. The toggle is not saved.

### Useful log distinctions

- `result=pending`: asset readiness checks have not passed; human body stays.
  Retries are limited to once per second and 60 attempts.
- `result=wolf`: Java registered the requested body. This alone is NOT a
  screenshot-level confirmation.
- `wolf body hook=true`: the patched body-selection method has run.
- `track hook=true`: the adapter has handled a wolf track request.
- `wolf draw=true`: the draw path has received the registered wolf model.
  This still does not establish correct appearance or animation.
- `recovery hook=true`: the patched melee-delay event has run.

## Known limits and acceptance criteria

The desired basic result is a visible wolf that can idle, walk, run and
return to the original human appearance on the same player. That result
still requires the user's playtest. There is no blended mesh-morph effect;
the cosmetic body changes when the existing transformation channel completes.
Crinos remains a scaled human placeholder, not a newly modeled war-form mesh.

Unknown human clips fall back to wolf idle. Climbing/vaulting, grappling,
ragdolls, item-use gestures, attacks with multiple blend tracks, and the
timing of human gameplay events on shorter wolf clips are unverified.
Root-motion distance and orientation may require calibration. Weapons and
bags do not yet render in the jaws/on the wolf. No new hitbox, species, AI,
networking, corpse or zombification behavior is implemented.

If the next log shows a signature/asset mismatch, fix that measured failure
rather than reintroducing Lua-only model scaling, raised-arms shifting, a
mount proxy, or another player's global animation overrides.

## Verification

Local checks cover 625 Lua assertions, 54 asset/reference/package
assertions, and 306 Java assertions. Java tests use the bundled real
ZombieBuddy annotation transformer and fake game objects, including
exception cleanup, ordinary-player isolation, recovery limits, pending
assets, body restoration, clip substitution and queued-texture lifetime.
They are not a substitute for running the game.

Run:

```bash
bash WTAGarou/tests/run.sh
bash WTAGarou/java/build.sh
bash WTAGarou/java/test.sh
```

GitHub Actions now also builds and tests Java. The distributed JAR contains
only `wtagarou` classes; the compile-only Model signature and test engine
fixtures are explicitly excluded. All reference mods, nil-only shift code,
HUD layout and approved scale values are preserved.
