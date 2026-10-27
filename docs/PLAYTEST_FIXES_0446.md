# 0.4.46: Rage title, balance, fur and console repair

## Change contract

- Target: the October 7 evening playtest requests.
- Confirmed working: spacing, auspices, howl audio, corpse rotation.
- Observed failure/request: slash console syntax error, insufficient Rage
  movement during combat, Hispo chilly; collapsed title needs a counter.
- Must remain untouched: user-edited copy, existing coats/art, corpse
  offsets (including occasional trunk deposit alignment), vehicle rules,
  harness/gear, howl audio and rates, identity locks.
- Evidence still needed: live collapsed rendering, console dispatch,
  weather balance and multiplayer.

## Implemented

The title reads `Rage N`, drawn twice one pixel apart for bold-style weight
without increasing the font or title-bar height. White at 25 through 75;
red for actual Rage <25 or >75. Integer display uses the same floor as the
existing Rage meter. It updates even when collapsed.

Contentment contributions are exactly 70% of their 0.4.45 values:

| Condition | Old Rage/s | New Rage/s |
| --- | ---: | ---: |
| No Hungry moodle | 0.225 | 0.1575 |
| No Thirst moodle | 0.225 | 0.1575 |
| Well Fed bonus | 0.15 | 0.105 |
| Neither hunger nor thirst | 0.45 | 0.315 |
| Neither, plus Well Fed | 0.60 | 0.42 |

Damage-dealt multiplier is 0.15: halfway from 0.10 back to 0.20. Damage
taken, negative moodle weights, howl rate and the existing >=95 drift
pause are untouched. The pause means the reduction does NOT change
contentment drift at or above 95. Ordinary Crinos below baseline nets
-0.685 Rage/s when fed/watered, or -0.58 with Well Fed; Berserker breed
nets -0.185 or -0.08 respectively before other moodles/events.

Fur applies only to Crinos, Hispo and Lupus: after each native thermal-node
clothing calculation, insulation is raised to at least the midpoint
(0.5) of that node's own UI scale. Warmer clothing is preserved; no new
clothing item, invulnerability, temperature clamp or cold-moodle removal
is used. Wind resistance, wetness and weather stay vanilla. This is not a
promise of snowstorm immunity. Native recalculation clears the floor on
the next thermal update after returning to a human form, death or trait loss.
Tune `WTAGarou.Fur.INSULATION_UI` in Definitions.

## Console root cause and evidence

The uploaded console shows both 0.4.45 banners and successful transformation
of UIDebugConsole.ProcessCommand. The new regression executes the real
ZombieBuddy-translated advice on a fixture in another package. It failed
before the fix: advice called package-private `rewrite` from outside the
mod package and swallowed the failure. Making `rewrite` public fixes the
execution test; errors now log rather than disappearing.

Use `/garou reload` in the debug Lua console after a FULL RESTART with the
new JAR. `garou("reload")` remains the plain-Lua fallback. A Lua reload
cannot replace an already loaded Java class.

## Verification

Lua flow/asset suites and Java unit/real-engine advice tests cover the
implementation. Added cases cover strict title thresholds, collapsed
updates, all three reduced pull contributions, per-form Lua routing,
17 synthetic thermal nodes, non-accumulation, better clothing, unrelated
characters, death/clear and actual woven console execution. Native game
class bytecode confirms insulation is calculated before the heat equation.
These are static/fixture checks, not an in-game rendering or climate test.

## Smallest playtest

Full restart and verify BOTH:
`[WTAGarou] Definitions loaded - version 0.4.46` and
`[WTAGarou Java] 0.4.46 loaded`.

1. Type `/garou info`, then `/garou reload`. The fallback is `garou("info")`.
2. Collapse Rage and set values 24, 25, 75, 76 using `/garou rage N`.
   Red at 24 and 76; white at 25 and 75; title keeps updating.
3. In the same weather, compare Human versus Hispo/Lupus/Crinos on the
   temperature panel. Furred forms should have medium-or-better insulation
   on every part; Human must not keep the fur floor. Body temperature takes
   time to respond, and wind/wetness still matter.
4. With no hunger/thirst, check drift below 95: 0.315/s, or 0.42/s with
   Well Fed, before other modifiers. Then check combat builds Rage more
   readily. No need to retest or retune trunk alignment for this change.
