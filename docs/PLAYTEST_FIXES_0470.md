# 0.4.70: October 18 playtest fixes (0.4.69 report)

Target: the first playtest of 0.4.69 (`console.txt`, `console-2.txt` with the
animation recorder on). Everything confirmed in 0.4.69 stays locked; only the
items below change. Multiplayer and silver are untouched.

## Why the ctrl+click swing never played

The anim recorder shows the attack-button shove running in state
`player/shoveAim` (node `ShoveAim`, clip `Bob_AimShove`), not `player/shove`.
`IsoPlayer` registers both: `shove` for the spacebar shove and `shoveAim`
when `isShovingWhileAiming()` (aiming and shoving) is true, which the attack
button always is. The 0.4.69 claw node existed only under `player/shove`, so
the `WTAGarouCrinosSwing` variable was set (the `[CrinosSwing]` log fired)
and nothing matched it. `42/media/AnimSets/player/shoveAim/WTAGarouCrinosClaw.xml`
is an exact copy of the shove node (same conditions, events and sub-state
bone weights); `tests/crinos_attack_assets_test.py` pins the two as identical.

## Why the Crinos arm still rose during a howl

`AnimationPlayer.play(StartAnimTrackParameters, AnimLayer)` applies
`params.subLayerBoneWeights` **only when `animLayer.isSubLayer()`**; on the
root layer it calls `track.setBoneWeights(null)` (full body). A standing howl
runs the Drink node on the root layer (the sub-layer copy only exists while
moving), so the 0.4.69 mask was set on the params, logged as "drink track
masked", and discarded. `HowlMaskPatch.exit` (OnExit of the same `play`) now
checks the returned track: if the params carried our mask and the track has
no bone mask, it sets the neck+head weights on the track and calls
`initBoneWeights(skinningData)` itself. Bones at zero weight take the previous
frame's pose (`AnimationPlayer.updateBoneAnimationTransform_Internal` blends
the remaining weight from `boneTransforms[]`), so the arms hold their last
idle pose instead of rising. The same exit advice covers the wolf's
`Wolf_howl` mask (same cached list).

## Why wolves still howled with the eat clip

`WolfClipLoader.CLIPS` is the explicit list that populates the wolf rig's
clip map (the console printed `available=[Wolf_Sit, Wolf_attack, ...]`
without `Wolf_howl`). `Wolf_howl` is in the list now; `Wolf_howl.glb` ships in
`common/media/anims_X/WTAGarouWolf/`.

## Rage engine

- **Baseline pull at high Rage.** 0.4.45-0.4.69 paused the contentment drift
  for the whole frenzy band (`CONTENTMENT.PAUSE_ABOVE = 95`), which is why a
  fed, watered character cheated to 98 or 100 never pulled back, and why the
  pull "commenced" only once a jumpscare or a -25 cheat took Rage under 95.
  `PAUSE_ABOVE` is gone. `WTAGarou.ContentPullPaused(d)` pauses the drift only
  while the 100-Rage countdown is running (`d.crinosCountdownAt`), or while
  Rage sits on MAX outside a Resist rest (the tick drifts before it checks the
  countdown, so this lets the countdown start). Consequence to be aware of:
  after a Resist the hidden rest runs with the pull active, so a fed, watered
  Garou leaves the band (< 95) in about 16 s and the Resist cycle ends by
  itself. Hungry and thirsty, nothing changes (no pull).
- **Crinos escalation clock.** `d.crinosHeldSeconds` sums the tick deltas
  (each capped at 2 s, and `rageTick` only runs while the game updates)
  instead of `now - crinosHeldSince` on the wall clock. A paused game adds at
  most 2 s. `rage_engine_test.lua` pins a 10-minute gap as +2 s.
- **Damage dealt.** `Rage.ON_DAMAGE_DEALT = -0.15 x damage` is replaced by
  `Rage.ON_HIT_DEALT = -0.5` per landed hit (OnHitZombie and
  OnWeaponHitCharacter), so overkill damage no longer burns Rage.

## HUD

- Direction markers no longer flicker at the baseline: `TREND_DEADBAND = 0.05`.
  Rage parked on the baseline is pushed off and pulled back every tick and
  the float sums do not cancel exactly, which the 0.4.69 tracker read as a
  real down/up flip every half second. Movement accumulates from the last
  counted value so a slow drift still registers.
- Bracket line and triangle snap to whole pixels around one centre column
  (`bracketGeometry`): the apex sits in the first pixel column at or right of
  the fractional baseline x; the line extends the same whole number of pixels
  either side. A fractional rect edge rasterised a pixel short on one side.
- One arrow, on the moving side only, clipped to the bar
  (`WTAGarou.HUD.arrowPlacement`): rising = right-pointing arrow 2 px right of
  the fill edge; falling = left-pointing arrow 2 px left of it. Columns outside
  the bar are not drawn, so near 0/100 the arrow is partly or wholly masked;
  the title triangle still shows the direction.

## Cheats panel

The body text was hidden while `not self.pin`; `ISCollapsableWindow` clears
`pin` the moment the collapse (pin) button is pressed, so an un-pinned window
open under the mouse drew buttons and no text. It now keys off
`self.isCollapsed`.

## Sounds

`WTAGarou_CrinosStep` 0.80 -> 0.55 (the authored footstep files are played
unprocessed; there is no EQ, pitch or gain stage in code),
`WTAGarou_CrinosShiftStart` 0.50 -> 0.30, `WTAGarou_FormShiftEnd` 0.60 -> 0.70
and `Shift.CHANNEL_END_GAIN` 0.6 -> 0.75.

## Doorway duck / refusal: diagnostics

No `[Doorway] ducked/refused` line appeared although the sprint door charge
(same `State`, same tall flag) did, and `collide()` swallowed every exception.
Two changes: `hasFlag` calls the `has(IsoFlagType)` overload explicitly
(`IsoGridSquare` also has `has(IsoPropertyType)`, `has(IsoObjectType)` and
`has(String)`; `getMethods()` order is unspecified and `Enum.valueOf` on the
wrong enum throws), and the hook now prints its first failure plus the first
six doorway-edge decisions (`[Doorway] edge d=(dx,dy) sneaking= running=
sprinting= -> fits|duck|refuse`). `status()` reports `hook calls=` and
`edges=`. If the next console shows no `edge` lines at all, the hook is not
reached for player movement in 42.20 and the duck needs another entry point.

## Not a bug

Sprinting into an open window gives no stumble in vanilla either:
`IsoMovingObject.checkHitWall` sets `valid = false` when `checkVaultOver()` is
true (open windows are `HoppableN/W`), so the `collideWithWall` event is never
reported there. The mod does not suppress it; with `WINDOW_CHARGE = false` the
window branch returns to vanilla.
