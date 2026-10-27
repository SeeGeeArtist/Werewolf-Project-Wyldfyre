# Wolf motion parity, berserk Crinos, regeneration: 0.4.10

Follows the September 23 solo test of 0.4.9. Reported: the wolf still
"walks with the run animation", the rubber band remains, a backwards slide
while turning, Rage not rising while alarmed and exhausted in Hispo, and a
crawler knocking Crinos down. The user confirmed the 0.4.9 death path works
(Wolf_death, then the human corpse pose); it is untouched here.

Everything below is verified by unit tests against the real ZombieBuddy
advice engine, the real shipped GLBs and the real Lua files. **None of it is
verified in game yet.** Animation and gameplay results need a native
playtest.

## Findings (engine 42.20.2 reference)

- **Two roots carried the travel.** Every wolf locomotion GLB baked the same
  forward travel into BOTH the skinned `Bip01` root and the `Translation_Data`
  marker. The engine counter-translates exactly one deferred bone per track
  (`AnimationTrack.getCurrentDeferredCounterPosition`), so whichever bone is
  not deferred keeps moving the visible model: 2x visible speed plus a snap
  back each loop. That is the rubber band.
- **Counter axis sign.** For `BoneAxis.Y` the counter position is
  `(-x, 0, +z)`: it adds z rather than subtracting it. Choosing `Bip01` as
  the deferred bone in 0.4.9 therefore doubled z instead of cancelling it.
  The human rig avoids this because human clips carry travel only on the
  `Translation_Data` marker and the engine's motion nodes are tuned to it.
- **Run key, not run state.** `IsoPlayer.isRunning()` is the run KEY/toggle
  state. It is true while aiming, strafing or standing still with Shift held.
  0.4.9's gait upgrade used it to swap walk clips for the run clip, which is
  the "walking with the run animation" symptom.
- **MoodleType naming.** 42.20 registers moodles as UPPER_SNAKE statics
  (`MoodleType.PANIC`, `MoodleType.HAS_A_COLD`). The old CamelCase lookups
  were nil on every tick, so no moodle has changed Rage since the 42.20
  update. That is why an alarmed, exhausted Hispo did not gain Rage while its
  -0.6/s drain still ran.

## Motion changes

- **Assets:** `tools/bake_wolf_root_inplace.py` holds `Bip01` x/z at the
  frame-0 value (y bob kept) in `Wolf_walk`, `Wolf_run`, `Wolf_run_fourx`,
  `Wolf_run_V2`, `Wolf_run_V3`. `Translation_Data` travel is untouched
  (walk 1.00 u / 1.042 s, run 2.005 u / 0.5 s, fourx 4.008 u / 0.5 s).
  `tests/asset_contract_test.py` now fails if any of those clips regains
  Bip01 x/z travel or loses its marker travel.
- **Derived clips (`WolfPlayerClips.derive`)** copy the HUMAN
  `Translation_Data` keyframes (position and rotation) onto the wolf marker,
  keeping the wolf's rest offset and scaling deltas by duration so ground
  speed is identical to the human clip. The wolf `Bip01` x/z is held. Clip
  duration is stride-matched: `wolfStride * renderScale / humanSpeed`,
  clamped to [0.15, 4] s, so paws do not skate at the body's actual size.
  Non-locomotion clips keep the wolf duration. Cache key includes the scale.
- **Gait is by name only.** `WolfRuntime.gaitFor` maps the requested human
  clip name to a wolf clip; the run key is no longer consulted. Walk clips
  stay walk, run/jog clips use `Wolf_run`, sprint uses `Wolf_run_fourx`.
- **Deferred bone parity.** `beginTrack` no longer overrides deferred bone,
  axis or rotation for derived clips; they inherit the human track's
  settings. Raw-wolf fallback clips only disable deferred rotation.

Contract change: AGENTS.md previously said to compensate the skinned Bip01
root. That advice was written before the counter-axis sign was read; it is
replaced by "travel lives on Translation_Data only, Bip01 holds x/z".

## Rage engine (server, real seconds)

Rates are per wall-clock second (`WTAGarou.NowSeconds`, dt clamped to 2 s),
not per tick, so they do not change with frame rate.

| Form | Base Rage/s | Stamina loss refunded | Knockdown/trip refused |
|------|-------------|-----------------------|------------------------|
| Homid | +0.30 | 0 % | 0 % |
| Glabro | -0.30 | 35 % | 0 % |
| Hispo | -0.60 | 55 % | 95 % |
| Lupus | +0.15 | 70 % | 0 % |
| Crinos | -1.00 | 90 % | 97 % |

- Negative moodles add `0.08 x level x weight` Rage/s. Panic weighs 2.0,
  Angry 1.5, Stress/Pain/Injured/Bleeding/Endurance/Hungry/Thirst 1.0,
  Tired/Sick/Hyper-/Hypothermia 0.75, the rest 0.5
  (see `WTAGarou.Rage.MOODLE_WEIGHTS`). Fear at level 4 alone
  is +0.64 Rage/s, which beats the Hispo drain.
- Sad moodles (Unhappy 1.0, Bored 0.5) subtract `0.08 x level x weight`.
- Positive moodles (Well Fed) pull Rage toward 60 at `0.30 x level` per
  second, in either direction, like a slow howl. Howl target is now 60.
- The random frenzy roll and the Pain ache are gone.

## Berserk Crinos

- Shifting into Crinos requires 60 Rage but spends 10. Channel is 1.0 s
  regardless of Rage. Other forms keep the Rage-scaled channel.
- Crinos burns 1 Rage/s. At 0 the server sets Homid directly (no channel,
  no cost), sends `TransformForced {form, previousForm, reason=rage_depleted}`
  and the client aborts any channel in flight WITHOUT sending
  `TransformCancel` (the server already changed the form).
- At 100 Rage outside Crinos the server starts a 10 s countdown and sends
  `CrinosCountdown {seconds}`; the client plays `WTAGarou_Growl`
  (`Wolf_Mod_Growl_01.ogg`, non-looping) once and the HUD draws
  `Shifting to Crinos in 6.8`. Dropping below 95 sends
  `CrinosCountdownCancelled`. When the countdown expires the server reserves
  a forced Crinos shift (`TransformAccepted {forced=true, seconds=0.25}`),
  the client channels 250 ms, and the confirm applies Crinos with
  `isFrenzied=true`. A stale `TransformCancel` for a different form, or any
  client cancel of a forced reservation, is ignored.
- Tooltips show `Rage cost: 10  (requires 60)` in the `<H1>` rich-text face
  (vanilla has no bold tag) colored gold; radial labels show `Rage 10 (need 60)`.

## Stability (Java)

`StabilityRuntime` holds a per-character refuse chance registered from the
local client in `WTAGarouVisual.refresh` (`WTAGarouJava.setStability`).
`StabilityKnockdownPatch` and `StabilityBumpFallPatch` rewrite the boolean
argument of `IsoGameCharacter.setKnockedDown` / `setBumpFall` to `false`
when the roll refuses. Only `true` (a fall being set) is filtered; clearing a
fall always passes. Verified with real ZombieBuddy advice in
`StabilityTest`; the earlier failure was the test installing two patches on
one class with separate redefinitions, which wiped the first.

## Regeneration (server, `WTAGarou.Regenerate`)

| Form | Body-part HP/s | Wound flags cleared after | Zombie infection burn |
|------|----------------|---------------------------|-----------------------|
| Crinos | 2.0 | 60 s in form | 100 points / 60 s |
| Hispo | 0.7 | 180 s | 100 / 180 s |
| Glabro | 0.7 | 180 s | 100 / 180 s |
| Lupus, Homid | vanilla | never | none |

Bleeding time tapers continuously at the HP rate. On clearing: bleeding,
scratch, cut, deep wound, bite, wound infection level, per-part infected
flag, burn, fracture and additional pain are reset (all pcall-guarded per
setter). Zombie infection uses `CharacterStat.ZOMBIE_INFECTION` /
`ZOMBIE_FEVER` on 42 (falls back to `get/setInfectionLevel` on 41) and clears
`BodyDamage.setInfected(false)` when it reaches 0. Silver-burned parts are
skipped by the Garou boost: they still heal, at the regular vanilla pace, for
the burn duration (correction from the 0.4.10 wording "never regenerate").
The clock resets on every form change.

## Tests

- Java: ScaleTest 222, WolfCombatTest 139, WolfClipLoaderTest 23,
  WolfPlayerClipsTest 198, StabilityTest 12. All PASS.
- Lua/asset: visual 28, channel/HUD 567, panic-trace 28, combat 25,
  test-panel 123, visual-sync 35, rage-engine 66, asset contract 102. All PASS.

## Unverified in game

Wolf ground speed and foot planting, the turning slide, the stability
patches actually intercepting crawler knockdowns, the 250 ms forced channel,
the growl sound routing, `CharacterStat.ENDURANCE` exposure to Lua on 42.20,
and whether 2 HP/s feels like the requested minute-scale healing.
