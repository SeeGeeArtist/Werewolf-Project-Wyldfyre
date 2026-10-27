# 0.4.64: wolf backward strafe and movement through a shift

Two follow-ups to the 0.4.63 report. Every behaviour the October 16 console
confirmed stays locked; both changes are Java-only (`WTAGarouVisuals.jar`)
plus the version bump.

## Hispo / Lupus backward strafe

Problem: while Ctrl-aiming and backing up, the human node is a backward
walk (`Bob_WalkBwdAim` and friends). The wolf clip table resolved it to
`Wolf_walk`, so the wolf played its forward walk cycle while its body slid
backwards: paws moving one way, body the other.

Change (`WolfRuntime.java`):

- `preferredClipFor` recognises backward-walk nodes (`walk` plus `bwd` or
  `back` in the name) and asks for `Wolf_walk_back`.
- `Wolf_walk_back` is optional; until it is authored the fallback is
  `Wolf_walk`, and `reverseForBackwardWalk` marks the pose as reversed, so
  `WolfPlayerClips.adapt` plays the walk keys back to front (the same
  `reversePose` path corpse dragging has used since 0.4.40). Paws now track
  the direction of travel.
- An authored `Wolf_walk_back.glb` plays forward and is not reversed.
- Dragging precedence is unchanged (dragging decides first).

Tests: `WolfPlayerClipsTest` (410 PASS) covers backward-walk resolution,
the reverse flag, the authored-clip exception and the dragging precedence.

## Movement stops at the end of a shift

Problem: however you were moving when a shift finished, the character
stopped and you had to release and press the movement key or stick again.

Cause (static reading of the 42.20.2 decompile, not yet confirmed live):

1. On a wolf form change `WolfRuntime.rebuild` (and the gait-timing refresh
   `WTAGarouJava.refreshWolfAnimations`) call
   `AdvancedAnimator.OnAnimDataChanged(false)` so the wolf rig and clips
   are picked up.
2. `OnAnimDataChanged` resets the animation player and every `AnimLayer`;
   `AnimLayer.reset()` sets its state to null.
3. On the next `AdvancedAnimator.update`, `if (!rootLayer.hasState())
   rootLayer.transitionTo(animSet.GetState("Idle"), true)` forces the Idle
   anim state.
4. The player's `ActionContext` is still in walk / run / sneak, so its
   conditions do not change, no `IActionStateChanged` callback fires, and
   the animator stays on Idle. Player locomotion is root-motion driven, so
   the character stands still. Releasing the key moves the action context
   to idle; pressing it again moves it to walk, which finally re-syncs the
   animator.

Vanilla never leaves the animator in that state: `IsoPlayer.checkActionGroup`
calls `OnAnimDataChanged(false)` immediately followed by
`ActionContext.setGroup`, and `IsoGameCharacter` has a private
`restoreAnimatorStateToActionContext()` that calls
`getAdvancedAnimator().setState(getActionContext().getCurrentStateName(),
childStateNames)` after model-manager re-adds and anim-set swaps.

Change (`WolfRuntime.resetAnimData`): every mod call site (`rebuild`, the
deferred death reset in `beforeModelReset`, and `refreshWolfAnimations`)
now resets and then re-applies the action context's current state and
child states to the animator through the public
`AdvancedAnimator.setState(String, List<String>)`. If the action context
has no root state the animator is left alone, exactly like vanilla.
`WolfRuntime.status()` (debug console) gains
`animator state restored after reset=true/false`.

Tests: `AnimatorRestoreTest` (9 PASS): reset still happens exactly once
with `reload=false`; `setState` runs after the reset with the root state
and the child-state names (nulls skipped); no `setState` without a root
state; a character without `getActionContext` still resets.

## What to check live

- Hispo/Lupus: Ctrl-aim and back up. Paws should step with the direction
  of travel; forward walk, run, strafe and corpse dragging unchanged.
- Hold a direction (keyboard or stick) through a Homid -> Hispo, Hispo ->
  Homid, Lupus -> Crinos shift. Movement should continue without
  re-pressing. Running and sneaking too.
- Also try Homid -> Glabro while moving. That path does no wolf rebuild;
  if movement still stops there, the cause is elsewhere and should be
  reported with the console.
- Console: `[WTAGarou Java] 0.4.64 loaded; ...` and no
  `wolf animator state restore:` warning.

## Versions

`mod.info` 0.4.64, `WTAGarou.VERSION` 0.4.64, Java banner 0.4.64. Lua
suite 31 PASS, Java suite all PASS (AnimatorRestoreTest added to
`java/test.sh`).
