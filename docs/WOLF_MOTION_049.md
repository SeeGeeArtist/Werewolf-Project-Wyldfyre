# Wolf movement, rig consistency, and death: 0.4.9

This follows the September 23 solo test of 0.4.8: rubber-banding while
running, unavailable strafing, inability to escape/fight during a zombie
encounter, and a human idle model on death. It preserves the working direct
IsoPlayer transformation and adds targeted changes, not a horse/mount proxy.
Native playtesting is still required before these symptoms are called fixed.

## Findings

- **Gait selection:** 0.4.8 already mapped run-named clips to `Wolf_run`, but
  sprint used that same clip. The user's asset review identifies `Wolf_walk`
  as walking, `Wolf_run` as jogging, and `Wolf_run_fourx` as sprinting.
  `Wolf_run_V2` and `Wolf_run_V3` are walking variants, not faster tiers.
- **Root mismatch:** The mesh's skinned root was named `Bip01`, while walking,
  sprinting, idle and some other exports used `Bip01_Root`. Some assets also
  reused `Bip01` for a non-joint wrapper. The mesh had two nodes named
  `Translation_Data`, only one of them a skin joint. This makes name-based
  animation import ambiguous and is a concrete candidate for the viewer/game
  difference. It is not an in-game visual proof of the whole cause.
- **Root compensation:** The previous adapter selected the `Translation_Data`
  marker, not the root carrying the visible body. In the available native
  [AnimationPlayer reference](https://github.com/Ketum-Git/PZ-Javacode/blob/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/core/skinnedmodel/animation/AnimationPlayer.java),
  deferred movement is countertranslated at the selected bone. Cancelling a
  separate marker does not cancel travel of the skinned root.
- **Player timing and layers:** Directly substituting a wolf clip also
  substituted its duration and track identity. Clearing every sublayer mask
  allowed upper-body/action layers to influence the whole wolf, including
  movement. These are compatibility problems beyond simply choosing a gait.
- **Death during a shift:** The log shows a shift starting at frame 17685 and
  player death at 17732, with no intervening completed-form log. It supports
  death during channeling but does not independently establish the target
  as Crinos. The previous cleanup immediately requested a human model and
  reset the animator.
- **Nil overload:** Each recorded shift also logged an engine exception from
  the enum overload of `BaseAction.setActionAnim`, which dereferenced null.
  The later Lua `pcall` log still said success. That success line is not
  proof that the Java call completed without an error.

## Implemented changes

### Movement and pose adaptation

`WolfPlayerClips` creates cached, namespaced derived clips. It keeps the
wolf's bone poses but retimes them to the original human clip's duration and
retains the original player track name. It maps the original human deferred
bone's signed planar displacement to the wolf's skinned `Bip01` root.

This means left/right/backward movement no longer depends on the wolf walk
asset having the right directional travel. The native player graph still
owns input, collision, movement restrictions, event timing, and recovery.
No coordinates are teleported, no movement-ignore flag is forcibly cleared,
and no attack or damage authority is moved to a cosmetic proxy.

The root's authored vertical pose and the other wolf bones are retained.
Native countertranslation at the skinned root is intended to prevent the
body travelling away from the player origin and snapping back each cycle.
The derived clip is private to WTAGarou: neither the human source clip nor
the imported wolf source clip is overwritten.

Action-layer bone masks retain entries that exist in the wolf skeleton,
rather than being replaced with full-body influence. Missing mask bones
are filtered, not redirected to arbitrary limbs.

Walking uses `Wolf_walk`, running/jogging uses `Wolf_run`, and sprinting uses
`Wolf_run_fourx`. Running/sprinting state also handles walk-named blend
tracks; these state checks do not replace an attack or hit-reaction pose.
Sprint and death clips now join the required readiness checks.
V2/V3 remain available assets but are not randomly mixed into locomotion.

### Rig names

The WTAGarou copies of all 14 GLBs now have unique node names and one
canonical skinned `Bip01` root. Non-joint wrappers use `WTAGarou_RigRoot`.
The normalization tool is idempotent. Binary mesh, skin weights, animation
samples and buffer data are byte-identical to their pre-patch versions;
only JSON node names changed. Reference mods were not edited.

This addresses an import mismatch, but the native game still blends tracks,
applies root compensation and uses different playback timing than a viewer.
A single raw GLB preview and the in-game blended result will not necessarily
look identical.

### Hispo size

Hispo's multiplier changes from **1.25 to 1.35**, exactly **8% larger**.
The wolf-body base stays 0.60, giving effective factors of 0.81 for Hispo
and 0.60 for Lupus. Lupus, Homid, Glabro, Crinos, collision and gameplay
stats are unchanged.

### Wolf death to human corpse

Normal death cleanup now retains a registered wolf and its scale instead of
immediately swapping to a fresh human animator. New track requests for a
dead registered wolf select `Wolf_death`, not `Wolf_idle` or `Wolf_dead`.

At native corpse creation, the registration is removed so the human model
and normal human corpse pose take over. The handoff prevents capturing an
old wolf skeleton or a newly initialized human idle pose into the corpse.
The explicit emergency wolf-off path still exists.

This is the requested wolf-collapse → human-dead handoff, not a timed
resurrection or gameplay death delay. The native death graph still decides
when corpse creation occurs, so a complete, uninterrupted `Wolf_death`
playback is **not yet verified**, especially for death mid-shift, falling,
ragdolls, or multiplayer. Breed-dependent natural-form selection is not
implemented by this temporary human-corpse rule.

### Literal nil shifting remains locked

The setter still receives exactly `nil, nil`. A synchronous Java scope
around that transformation setter skips the null-dereferencing overload
only for the matching shift owner. The scope is released on both normal
and exceptional paths. It does not change the Lua base action class,
substitute `"None"`, alter ordinary actions, or suppress the non-null Drink
animation used for howling.

## Verification and limits

Local checks pass:

- **Java 17:** Build plus 627 assertions, including real ZombieBuddy advice
  translation: 222 scale, 139 wolf/combat/death, 23 clip loading, and 243
  motion/timing/shift-scope assertions.
- **Lua:** 791 assertions, including 552 channel/HUD checks and the existing
  visual, panic, combat, testing-panel and multiplayer-state checks.
- **Assets/package:** 82 assertions, plus a separate byte comparison showing
  all 14 modified GLBs retain their binary chunks exactly. Running the
  normalization tool again changes zero files.
- **Safety:** No game stubs are packaged. Git whitespace checks pass.
  Human source clips, reference mods, inventory and health are not modified
  by the derived-clip adapter.

The engine reference is Build 42.20.2; the playtest is 42.20.4. Tests use
fixtures, not the proprietary native game runtime. Running, strafing,
zombie-contact recovery, doors, click-to-walk, the final rendered pose and
the death sequence still need an in-game check. Live multiplayer is not
verified.

The test sandbox has `AttackBlockMovements=true`. This patch does not
disable legitimate native attack/grapple restrictions to conceal an
animation problem. If immobilization persists after recovery should have
finished, capture that exact interaction for further diagnosis.

## Missing animations and next test

No fence-climbing, wall-climbing, window-climbing or dedicated sideways/
backward wolf clips were fabricated. Directional movement can be preserved
without those poses, but it will not make a forward walk cycle a natural
sidestep. Author those assets against the normalized wolf rig; keep its
joint names unique and consistent. Dedicated climb clips need their own
mapping and event review when supplied.

Update the **whole WTAGarou folder**, not just the JAR: both Java and GLB
names changed. Fully restart and approve the updated module if prompted.
Confirm Lua `0.4.9-wolf-motion` and Java `0.4.9`.

In a disposable solo save:

1. Compare walking, running and sprinting in Lupus on open ground. Then aim
   and try left/right/backward movement.
2. Test a shove and recovery against one zombie, followed by movement and
   another attack. Do not start with a crowd.
3. Check the slightly larger Hispo, then restore Homid.
4. Test death once while stationary and once during a shift. The target is
   wolf collapse followed by a human body on the ground, never human idle.

The first adapted player clip prints `player-motion clip ready` and the
Java status includes a `player-motion clips` count. If the adapter reports
unavailable or that count remains zero after moving, include that log:
the fallback is not evidence that the new player-motion path worked.
