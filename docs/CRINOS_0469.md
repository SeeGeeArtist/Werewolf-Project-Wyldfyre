# 0.4.69: Crinos playtest follow-up (legs/tail, swing, scale, crowd charge, Rage bracket)

Requested Oct 18 from the 0.4.68 playtest (console-3.txt, two screenshots).
Single-player only: the multiplayer item/strip changes were not exercised.
Everything below has static tests (Java 30 invocations, Lua 33 suites);
nothing is accepted until the next live run.

## What changed (player-facing)

| Area | 0.4.68 | 0.4.69 |
|---|---|---|
| Crinos legs and tail | invisible (mount failed) | mounted; legs use the coat's `WTAGarou_CrinosBody_<Coat>` texture |
| Footwear, eyewear, masks in Crinos | shoes/socks still drawn | shoes/socks hidden while the legs are on; eyewear and masks hidden; hats and neck jewelry kept |
| Spacebar / LT | one-handed swing | vanilla shove again, no club sound |
| Ctrl+click / RS+RT unarmed | shove | one-handed swing with the spiked-club impact on hits |
| Size | 1.73x | 1.65x; cadence 0.79/0.79/0.73/0.79 keeps net 1.30 walk, 1.20 sprint |
| Feet sliding when walking | yes | root motion now scaled in the real walk/run/sprint state (see below) |
| Door charge | 8 Rage, 12 locked | 12 Rage, 18 locked (stamina unchanged) |
| Window charge | smashed, did not pass | off (vanilla stumble) |
| Sprinting into zombies | stumble, zombie flinches | first 3 in 3 s are knocked down and the sprint continues; the 4th is a vanilla bump |
| Fence/window climb lunge | staggered the Crinos | 85% poise applies |
| Shift-start cue | 0.80 | 0.50, shorter range |
| Baseline pull | full rate everywhere | halved inside a band of 2 Rage per negative-moodle level (cap 10 levels = 20 each side) |
| Crinos drain | -1/s (Metis -1.5/s) | +1/s more every 90 s held; resets on exit |
| Forced shift at 100 Rage | resist takes 1 s off | 2 s off |
| Howl cancel | Lua error | fixed |
| Howl arm (Glabro/Crinos) | left arm raises (Drink clip) | arm keeps its gait layer; head and neck still incline |
| Howl (Lupus/Hispo) | eat clip | plays `Wolf_howl.glb` when the author drops it in `anims_X/WTAGarouWolf/` (falls back to eat) |

## Engine facts behind the fixes

**Legs/tail.** The 0.4.67 mount looked up
`zombie.core.skinnedmodel.advancedanimation.AnimationPlayer`; in B42.20.2 it
is `zombie.core.skinnedmodel.animation.AnimationPlayer` (console 1182-1183
`ClassNotFoundException`). `CrinosCosmetics.ANIM_PLAYER_CLASS` corrected, test
stub moved. The six `WTAGarou_CrinosLegs_*.png` were on the vanilla body
layout, so they were obsolete: the legs sub-model takes the coat's Crinos
body texture (`WolfCoats.crinosLegs`).

**Shove vs. attack.** `CombatManager.calculateAttackVars` forces
`doShove = true` for bare hands on both buttons; the only difference is
`IsoPlayer.isMeleePressed()` (spacebar true, attack button false), set
before `pressedAttack`. `CrinosSwingPatch` (IsoPlayer.pressedAttack enter)
publishes the anim variable `WTAGarouCrinosSwing = unarmed && !isMeleePressed`;
the `WTAGarouCrinosClaw` node requires it, so spacebar falls through to the
vanilla shove node. The club impact plays only when the swing variable is on.

**Stride (the sliding feet).** `StrideRuntime` scaled
`IsoPlayer.getDeferredMovement` only in a locomotion whitelist that named
the B41 `PlayerActionsState`. B42.20.2 registers the player's "movement",
"run" and "sprint" states as `zombie.ai.states.player.PlayerMovementState`
(`IsoPlayer` 1153/1159/1187), so an ordinary walk was never scaled; the
console only ever showed `[Stride] root motion x1.73 in PlayerStrafeState`.
`PlayerMovementState` is in the set now and each state logs once. Expect the
Berzerker to be visibly faster than in 0.4.68 (it was running at cadence
0.75 with unscaled ground motion, i.e. slower than a human); 1.30/1.20 is
the designed net speed, tune `Traits.Crinos` if it feels wrong. The
cadence multiplier scales the `WalkSpeed`/`RunSpeed` anim variables and
only changes speed, not foot tracking: tracking is the root-motion scale.

**Crowd charge.** `IsoMovingObject.separate()` is the whole collision
mechanic: for a running player (WalkSpeed > 0.2, runningTime > 0.5, not
the character bumped last) it sets `BumpFall(true)` when sprinting, then
`setLastBump`, `setBumpedChr(zombie)`, `setBumpType(left/right)`,
`zombie.setBumpType(...)`, `setHitFromBehind` and reports `wasBumped`,
which enters `BumpedState` (the stumble that ends the sprint).
`CrowdChargeRuntime` opens a thread-local scope in `setBumpedChr` when a
registered form is sprinting into a standing zombie and fewer than `limit`
charges happened inside `windowSeconds`: it calls the public
`IsoZombie.knockDown(isBehind)` (the same call a shove ends in), undoes the
trip, empties both bump types and swallows the `wasBumped` event in
`ActionContextEvents.add`. The next collision inside the window is a vanilla
bump (crowd stop). `WTAGarou.CrowdCharge = { Crinos = { limit 3, window 3 s } }`.
MP caveat: the knockdown is issued on the charging client; a zombie owned by
another client may not replicate it (not tested).

**Climb lunge.** Zombies flopping over a fence or through a window
(`ClimbOverFenceState`/`ClimbThroughWindowState` "CheckAttack") call
`IsoGameCharacter.attackFromWindowsLunge`, which sets the "stagger" bump
itself (no hit-reaction string), so the poise filter never saw it.
`PoiseLungePatch` skips the method on the poise roll.

**Howl.** `endHowlAction` was a plain function using `self.character`
(error on cancel); it uses `action.character`. The arm: `AnimationTrack.initBoneWeights`
zeroes every bone, then takes the max weight per `subLayerBoneWeights`
binding (descendants included). `HowlMaskPatch` (AnimationPlayer.play enter)
swaps the Drink/Eat track's sub-layer weights for `[Bip01 0, Bip01_Neck 1]`
while the Lua anim variable `WTAGarou_HowlMask` is set (Glabro/Crinos only).
The same mask cannot be reused on the wolves: the wolf GLB has the
Bip01_Neck/Bip01_Head names, but the human clip's neck rotations are
absolute poses for a vertical spine, so on the horizontal wolf spine the
head would twist into the ground. Hence the optional `Wolf_howl` clip hook.

**Rage.** `WTAGarou.Rage.BASELINE_BRACKET = { PER_STACK 2, MAX_STACKS 10, SLOW 0.5 }`:
the contentment pull toward baseline is multiplied by 0.5 while
`|rage - baseline| <= 2 x stacks`; stacks = the sum of `getMoodleLevel`
over every negative moodle category (both the Rage-raising set and the
sad/draining set; levels, not names, so Agony counts as Pain 4). Example
from the request: baseline 70, Fear 3, Pain 3, Drowsy 3, Bored 3, Hunger 1
= 13 -> capped 10 -> band 50..90. `CRINOS_ESCALATION = { EVERY_SECONDS 90,
STEP -1 }` (server tracks `crinosHeldSince`, sends `CrinosDrain` for the
HUD). `RESIST.LINEAR_STEP = 2`.

## Rage meter markers (same day, follow-up request)

Plain `drawRect`/`DrawTextCentre` on the existing panel, no UI framework:

- a 4 px cream-yellow (1, 0.95, 0.75) line inside the bottom edge of the
  meter, centred on the baseline, half width = the server's current bracket
  (`RageSync.bracket`, from `d.bracketStacks` read every tick); no stacks =
  no line;
- a 9 x 5 px yellow (1, 0.85, 0.2) up-triangle on that line at the baseline;
- two sideways triangles flanking the current-value edge, both pointing the
  way Rage last moved, fading over `WTAGarou.HUD.TREND_HOLD_MS` (1000 ms)
  after the last change; any change counts. A run of changes shares one
  pulse clock (`TREND_PULSE_MS` 1000), so a constant drift pulses full ->
  clear once a second rather than sitting solid; a direction flip restarts
  the pulse, and the last pulse is capped by the hold fade so it ends at zero;
- the title reads `Rage: 45` with a 7 x 4 px up/down triangle to the right of
  the text in the title colour (white, or the red of the danger thresholds),
  fading with the arrows. Drawn with the native `DrawTextureScaledColor`
  rather than the ▲▼ code points: the UI fonts are AngelCode bitmap fonts;
  `AngelCodeFont` skips glyphs the font lacks and its draw loop indexes the
  glyph table without a bounds check, so the symbols are not safe. The
  collapsed title tracks the value itself since the body is not drawn.

Pure helpers for tests: `WTAGarou.HUD.trackTrend/trendState/bracketGeometry/titleState`.

## Awaiting live verification

1. Legs/tail visible in Crinos; footwear/eyewear/masks gone; hats and neck
   jewelry still drawn.
2. Feet track the ground at a walk, jog and sprint; console shows
   `[Stride] root motion x1.65 in PlayerMovementState`. Speed feel.
3. Spacebar shoves silently; Ctrl+click swings with the club impact.
4. Sprinting into a group: three go down, the fourth stops the charge;
   `[CrowdCharge]` console line.
5. Fence-climb zombies no longer stagger the Crinos most of the time.
6. Howl: no error on cancel; Glabro/Crinos left arm stays down; head
   inclines.
7. Meter: cream bracket line and baseline triangle visible; arrows and
   title `<`/`>` appear while Rage moves and fade within a second.
8. Baseline bracket log every 30 s (`[Rage] bracket ...`), Crinos drain
   stepping up in the HUD tooltip after 90 s, resist taking 2 s off.
