# 0.5.0 - The Resolve update: Crinos Rage buffer, shift-channel formula, Resolve skill

Lua-only candidate stacked on `fbcb8a0` (feature/cosmetic-model-swap). The Java JAR
and its signature are unchanged (the banner still reads 0.4.98 Java / 0.5.0 Lua).
Nothing in this document is live-verified until the playtest at the end.

## Resolve countdown and baseline-pull perks

Implemented at the user's request; not yet confirmed in game.

- Each Resolve level reduces the timer penalty per resist by 0.1 seconds.
  Level 0 still loses 2 seconds per resist; level 5 loses 1.5; level 10
  loses 1. The initial countdown stays 10 seconds. Near the existing
  half-second floor, the timer still shrinks gradually by smaller amounts.
  Higher Resolve slows progress along that same curve; it never gives a
  shorter countdown at the same resist count.
- Each level makes passive baseline pull 1% stronger, up to 10%. This is
  a percentage of the existing nourishment-based pull, not +0.1 Rage/s.
  Fed and watered: 0.315/s at level 0, 0.3465/s at level 10.
  With Well Fed too: 0.42/s becomes 0.462/s.
- The total boosted pull is capped at 95% of the character's initial
  Crinos drain, including the Berserker's slower 0.5/s drain. Escalation
  does not raise this cap. Baseline pull alone cannot sustain Crinos.
- The pull still moves toward the same baseline in either direction.
  Hunger/thirst requirements, moodle-bracket slowdown and countdown pauses
  remain active. Howling receives no bonus.

Change contract:

- Target: shared countdown math and server-owned passive baseline pull.
- Confirmed baseline to preserve: shifting, moon exposure, opt-in, roar
  gating and door charge as reported in the previous playtest.
- Untouched: XP awards/cooldown/thresholds, initial countdown, reset rules,
  rest multipliers, Crinos drain/escalation, ability unlocks, Java and Steam files.
- Verification: offline tests cover every level, shrinking countdowns,
  level-to-level timer ordering, the drain cap for all origins, and the
  server countdown and Rage-tick paths. Hosted and dedicated runtime
  behavior still require playtesting.

Small live test: compare `/garou resolve 0` and `/garou resolve 10`.
At 100 Rage, resist the initial countdown once: the next countdown should
be 8 seconds at level 0 and 9 at level 10. With the same nourishment and
no other Rage pressure, passive baseline pull should be slightly faster
at level 10; Crinos should still lose Rage below the baseline, including
for a Berserker. Restart fully after installing this Lua update.

## Hosted playtest follow-up (November 7, evening)

What the user saw in a hosted game (not a dedicated server):

- Confirmed: the existing-character opt-in worked, and the log shows all four
  traits granted. Moon exposure behaved as expected with fog, roofs, windows
  and doorways. At Resolve 0 the roar no longer staggers. At Resolve 3 (set
  with `/garou resolve 3`) the door charge broke a door.
- The errors in both logs are all the old `openingExposed` line-171 call
  (`getDoorFrameTo`). That test ran the copy from before `f040398`, which
  already replaces that call. Nothing else from WTAGarou errored.
- XP mismatch: the HUD said +3 but the skills panel showed 2.75. Cause: the
  engine's normal `addXp`/`AddXP` uses the trait XP-boost table, and a skill
  with no starting boost learns at 25%. Three awards (3 + 5 + 3 = 11) times
  0.25 = 2.75. Fix: Resolve now uses `addXpNoMultiplier` (B42.21 global),
  then `AddXP(perk, amount, true, false, false)`. The boosted call is only a
  last resort and logs a warning. Resolve XP is now exact and also ignores
  sandbox XP multipliers. The award amounts are unchanged.
- Engine note, not changed: `PerkFactory.AddPerk` multiplies every `xpN`
  value in `perks.txt` by 1.5. Our `xp1 = 50` is really 75 XP, so level 1
  took three resists (75 XP) at 25 each, not two. Follow-up (user request):
  only every third resist in a streak now gives 8 (lowered from 25 the
  same day); the others give 3 on the shift cooldown. A full streak is
  usually 3 + 0 + 8 = 11 XP.
- Level costs (engine fact): each `xpN` is the cost of that level alone,
  times 1.5, and the costs add up. Per level: 75, 150, 300, 525, 825,
  1200, 1650, 2250, 3000, 3900. Running total: 75, 225, 525, 1050, 1875,
  3075, 4725, 6975, 9975, 13875.
- Health panel: the Wyrm Infection line used to widen the whole health
  window to fit. It now wraps inside the existing width. The name goes on
  line one, and "(purging NN%, M:SS left)" starts its own indented line,
  which can wrap again on a narrow panel. Only the height grows. The silver
  line uses the same helper.

Still to check in game: the panel shows exactly +3 / +5 / +8 per award,
the wrapped Wyrm lines on the Steam Deck, and the doorway fix without errors.

## Solo playtest follow-up (November 7)

The user reports shifting and moonlight working, with Resolve present in the
skills panel but displaying its translation key. The solo console records
moon-adjusted shift timings, the six-second Crinos entry at 50 Rage, and
Resolve XP award messages. This does not establish every test below passed.

Two narrow repairs follow that log:

- Resolve/category names and the skill description belong in `IG_UI.json`,
  not `UI.json`. The B42.21 Translator routes `IGUI_` keys to that category
  ([Translator.java](https://raw.githubusercontent.com/rbm4/apocalipsebr-zomboid-patches/4379818fb75b7c2395fb6a4edb0b93bc05d9b8a1/42.21.0/decompiled/zombie/core/Translator.java)).
- The empty-doorway lookup repeatedly called nonexistent `getDoorFrameTo`.
  It now reads the owning tile's `DoorWallN` or `DoorWallW` flag, retaining
  the same unroofed-neighbour and two-way collision rules. This follows
  `isDoorSquare`'s north/west tile ownership in the current engine
  ([IsoGridSquare.java](https://raw.githubusercontent.com/rbm4/apocalipsebr-zomboid-patches/4379818fb75b7c2395fb6a4edb0b93bc05d9b8a1/42.21.0/decompiled/zombie/iso/IsoGridSquare.java)).
  This supersedes older `getDoorFrameTo` references below.

All 46 local suites pass after the repairs. No tuning, shifting behavior,
HUD geometry, Java or enrollment code changed. A full restart must still
verify the readable skill label, bare/removed-door frames in both
orientations, blocked/replaced doors, and absence of new doorway errors.
Hosted opt-in remains unverified.

## Follow-up: moon baseline and HUD (November 7)

The first two Resolve commits only used moon exposure for channel time.
They did not yet change the Rage baseline or move its bracket. This follow-up
connects the mechanics and display. The maximum bonus is now +15 Rage,
increased from the initial +10 at the user's request.

Change contract:

- Target: the server-owned Rage target, its HUD markers, and local moon access.
- Confirmed working: no new in-game confirmation; the user has not tested these commits.
- Request: move the bracket upward with moon exposure, retain the yellow
  Startup marker, and show an identical white effective-baseline marker below it.
- Preserve: Startup selection, bracket width and slowdown, rates, costs,
  Crinos thresholds/buffers, countdowns, depletion hold, Java and art.
- Evidence needed: actual HUD rendering and hosted-MP door/window state.

The empty-doorway follow-up extends only local moon access: bare exterior
door frames and remaining frames after exterior door removal/destruction.
The existing baseline/HUD, door/window rules, weather and daytime scaling
stay unchanged. Nothing in this follow-up is yet confirmed in game.

Covered-porch correction: `isOutside()` alone was insufficient to establish
open sky. Both direct outdoor exposure and the outdoor tile across an
opening now require `haveRoofFull() == false`. This changes only roof
qualification; all tuning and the indoor adjacent-opening exception remain.

```
B_selected  = BaselineRage(data)                    -- Startup auspice; never overwritten
E           = server-sampled moon exposure (0..1)
B_effective = clamp(B_selected + 15 * E, 0, Rage.MAX)
```

`MoonLight.BASELINE_BONUS = 15` is the maximum bonus. Contentment and Howl
now target `EffectiveBaselineRage(data)`. This does not instantly grant or
remove Rage. The server resamples on the Rage update (normally every 0.5 s),
and before Howl ticks and accepted shift timing; it sends `moonExposure`
in `RageSync`, including an explicit zero when exposure disappears.
The HUD uses that received value, not a separate client lighting estimate.

The cream-yellow bracket is centred on the effective baseline; its
moodle-based width is unchanged. The yellow symbol stays at the Startup
baseline. The white symbol uses the exact same two triangles and stem, but
at the effective baseline, and is drawn first. At zero exposure the opaque
yellow symbol covers it exactly. Small fractional changes can share a pixel
until the marker moves far enough to reach the next pixel column.

At a selected baseline of 50, clear full moon:

| Location / time | Exposure | Yellow marker | White marker / bracket centre |
|---|---:|---:|---:|
| Outdoors, full night | 1 | 50 | 65 |
| Outdoors, full daylight | 0.5 | 50 | 57.5 |
| Unexposed indoors | 0 | 50 | 50 (white covered) |

At full exposure, Ahroun targets 85 and Theurge targets 55. Once a
Theurge's actual Rage reaches 55, an ordinary-Origin Crinos entry has no
buffer penalty; its normal one-second channel still applies, reduced to
0.75 seconds by full exposure.

Ragabash targets 45, ten short of the 55 entry requirement. Since the
admission window is `6 + Resolve`, this needs Resolve 4, not 2. Resolve 4
admits that ten-point shortfall while the added time remains capped at
six seconds: 6.75 seconds total at full exposure. The target is not an
instant Rage grant; admission always checks current Rage. Entry/exit
thresholds, Resolve scaling and the 25% maximum channel reduction are unchanged.

### Door and window access

`MoonLight.OPENINGS = true` enables a simple tile rule. An unroofed outdoor tile
counts, as does the indoor tile immediately across an opening from an
unroofed outdoor cardinal neighbour on the same floor. An exterior door must be
open and unbarricaded. A window may be shut or open, but needs no curtain
or an open curtain and no barricade. Any barricade currently blocks exposure,
even a sparse one; that is a conservative gameplay choice, not ray tracing.
Bare exterior door frames also count, including the remaining frame after
an exterior door is removed or destroyed. This fallback only runs when
there is no door object on that edge, and the edge must be unblocked in
both directions. A closed or barricaded replacement door takes precedence.
No deleted-door history is retained: every sample reads the current edge.
Interior-to-interior openings, diagonals, deeper room tiles and
missing/unloaded tiles do not qualify. Removing both the door and its frame
does not qualify through this rule; arbitrary wall gaps are not inferred.
Set `OPENINGS = false` to restore outside-only access.

A covered porch does not qualify even if `isOutside()` is true. Standing
on it gives no exposure, and an open door, bare frame, removed-door frame
or uncovered window leading onto that roofed tile gives no exposure through
that edge. The indoor character's own roof is not the issue for the opening
exception: the outdoor tile across the opening must have open sky.
Missing tiles, unavailable roof APIs, and unknown roof results all read as
no exposure, rather than falling back to the player's exterior flag.
The public API documents `haveRoofFull()` separately from `isOutside()`,
without promising that the latter excludes roofs
([IsoGridSquare API](https://projectzomboid.com/modding/zombie/iso/IsoGridSquare.html)).
Actual porch/sloped-roof classification in the installed build still needs
the live test below.

The tile lookup uses the documented `getWindowTo`, `getDoorTo` and
`getDoorFrameTo` methods, with `isBlockedTo` guarding empty doorways,
not a rendered-light value that might include lamps
([IsoGridSquare API](https://projectzomboid.com/modding/zombie/iso/IsoGridSquare.html)).
The state checks use `HasCurtains`, `isBarricaded`, `IsOpen` and
`isCurtainOpen` on their respective objects
([IsoWindow API](https://projectzomboid.com/modding/zombie/iso/objects/IsoWindow.html),
[IsoDoor API](https://projectzomboid.com/modding/zombie/iso/objects/IsoDoor.html),
[IsoCurtain API](https://projectzomboid.com/modding/zombie/iso/objects/IsoCurtain.html)).
Those documented interfaces and Lua mock tests do not establish correct
open-door edge resolution or MP synchronization in the user's installed build.
Both door orientations, bare versus removed-door frames, and curtains
installed on either side need a live test. The API documentation lists
these methods but does not specify all removal/collision edge cases.

No moon-angle or physical light-path calculation is being introduced.
The earlier claim that the entire game has no moon-position calculation
was too broad: the checked public ClimateMoon API exposes phase and
brightness, not position; the rendering internals were not inspected
([ClimateMoon API](https://projectzomboid.com/modding/zombie/iso/weather/ClimateMoon.html)).

### Verification status

- Implemented: effective-baseline drift/Howl, server exposure sync, two-marker
  HUD and local exterior door/window access.
- Preserved: Startup identity, moodle bracket width/slowdown, Rage costs and
  rates, Crinos entry/exit thresholds, buffers, Resolve progression, Java/art.
- Static verification: `bash WTAGarou/tests/run.sh` exited 0 with 45 PASS
  suites after this follow-up; `git diff --check` passed. The new exposure
  suite covers empty-doorway access, explicit roof checks and the +15
  Ahroun/Theurge/Ragabash baseline and Crinos-admission examples;
  existing HUD, server, routing and guide tests
  were extended. No Java changes or Java rebuild.
- Awaiting live verification: rendering, both door orientations, curtain
  sides, server/client opening-state updates and the existing Resolve
  registration/XP gates. Local tests are not a game playtest or a CI result.

## What changed, in one breath

1. **Crinos Rage buffer.** You may start a shift into Crinos up to six Rage short
   of the 55 it needs, and start a shift out of Crinos up to six Rage above the
   75 lock (55 for a Berzerker Origin). Every point of distance adds one second
   to the channel. Beyond the window the old refusals stand ("Not enough Rage.",
   "The Rage will not let you go yet."). The Crinos cost is still 10.
2. **Glabro and Hispo have no buffer.** Their floor is their cost (20). A buffer
   that spent 14..20 was judged pointless: wait for 20. Unchanged.
3. **Berzerker Origin** has no Crinos entry floor, so no entry buffer; its exit
   lock (55) does get the buffer.
4. **Moonlight** on the skin trims the body part of a shift: outdoors or at a qualifying opening, by moon
   brightness, clouds and fog. Up to a quarter off under a clear full moon at
   night; the moon still pulls by day at half strength (an eighth off at noon).
5. **Resolve** is a new skill (`media/perks.txt`, category Garou). Trained by
   resisting the forced change (every third resist in a row: 8 XP; the
   other resists: 3 XP on the shift cooldown) and a little by completing shifts (3 XP;
   5 into Crinos; one reward per minute; nothing for forced or cancelled shifts).
   Each level widens the Crinos buffer window by one Rage without raising the
   six-second cap. Levels 1 / 2 / 3 unlock the zombie charge, the roar stagger
   and the door charge; later levels sharpen them.
6. **Wording:** "True form" is now "Origin" everywhere a player reads it. The
   saved field is still `trueForm`.
7. The two-second 0-Rage hold before the forced return (0.4.75,
   `Rage.DEPLETED_HOLD_S`) is untouched and still applies.

## The full channel formula

Symbols:

| symbol | meaning |
|---|---|
| `f`, `g` | current form, target form |
| `r` | current Rage, not rounded |
| `b` | Berzerker Origin (true/false) |
| `v` | voluntary shift (true) or forced (false) |
| `B` | the selected baseline Rage (auspice, 30..70); distinct from the moon-adjusted drift target |
| `L` | Resolve level, 0..10 |
| `E` | moonlight exposure, 0..1 |
| `q` | the Crinos entry floor: 55 (ordinary Origin); none for `b` |
| `h(b)` | the Crinos exit lock: 75, or 55 when `b` |
| `c_g` | the target form's Rage cost (Crinos 10, Glabro 20, Hispo 20, Homid/Lupus 0) |

### 1. Distances from the Crinos thresholds

```
d_in  = max(0, q - r)      if g = Crinos and not b      else 0
d_out = max(0, r - h(b))   if f = Crinos                else 0
d     = d_in + d_out       (only one of them can be non-zero)
```

### 2. Admission (may the shift START?)

```
W(L) = 6 + 1 * L                       -- ShiftBuffer.WIDTH + PER_RESOLVE_LEVEL * L

allowed  iff   r >= c_g                 -- the cost is never buffered
          and  d_in  <= W(L)            -- Crinos entry window
          and  d_out <= W(L)            -- Crinos exit window
          and  (g in {Glabro, Hispo} implies r >= 20)   -- plain floor, no buffer
```

Refusals: `not_enough_rage` for the cost / entry side, `crinos_locked` for the
exit side. The 3 s post-shift cooldown and the trait check are unchanged and
come first.

### 3. Buffer seconds

```
T_buffer = min(6, d)                    -- one second per Rage, capped at ShiftBuffer.MAX_SECONDS
```

Resolve widens `W(L)`; it never raises the cap. At Resolve 10 you may begin a
Crinos shift at 39 Rage (16 short) and it still costs six extra seconds.

### 4. Body time (pair base + centre curve, or the Crinos snap)

```
z        = 50                           -- or B when TransformTime.CENTER_ON_BASELINE
dist     = |r - z|
clip(x)  = max(0, min(1, x))

T_curve  = 6 - 5 * clip((dist - 5) / 25)          -- 6 s on the plateau (45..55), 1 s by 20 or 80
T_snap   = 1                                      -- any shift INTO Crinos

T_pair(f, g, b) = TransformTime.PAIR_BERZERKER["f>g"] if b and present
                  else TransformTime.PAIR["f>g"] if present
                  else 0                          -- both tables are empty by default

T_body   = T_pair + (T_snap if g = Crinos else T_curve)
```

### 5. Moonlight

```
O = 1 unroofed outside or beside an opening to unroofed outside, otherwise 0
M = moon brightness 0..1  (ClimateMoon.getMoonFloat() / 0.7; phase table fallback)
N = night strength 0..1   (ClimateManager.getNightStrength)
s = MoonLight.DAY_SHARE   (0.25 since 0.5.1, was 0.5: the moon's daytime pull as a share of its night pull)
S = s + (1 - s) * N       -- sky weight: 0.5 at noon, 1 at full night
C = cloud intensity 0..1  (getCloudIntensity)
F = fog intensity 0..1    (getFogIntensity)

E   = O * M * S * (1 - C) * (1 - F)
m_L = 1 - 0.25 * E                      -- MoonLight.MAX_REDUCTION
```

A missing API reads `E = 0` (no change). This is a gameplay exposure scale,
not a physical luminance model. We use only phase and brightness, with no
moonrise, moonset or elevation term. The daytime share is the werewolf's
cycle, not visible light: a full moon still pulls at noon.

### 6. The whole thing

```
T_vol = max(0.25, T_body * m_L) + T_buffer           -- TransformTime.MIN_SECONDS = 0.25

T = T_vol        if v and allowed
  = 0.25         if not v and the frenzy forces Crinos (unchanged)
  = 0            if not v and depletion returns the Origin form (after the 2 s hold)
  = refused      otherwise
```

The buffer is added **after** the moon's cut, so missing Rage always costs its
full seconds. Everything is read once, when the server accepts the request;
the channel is not re-timed while it runs. Completion still requires `r >= c_g`.

### Worked examples (no moonlight, Resolve 0)

| shift | body | buffer | total |
|---|---:|---:|---:|
| Homid -> Crinos at 55 | 1 s | 0 | **1 s** |
| Homid -> Crinos at 50 (Philodox baseline) | 1 s | 5 s | **6 s** |
| Homid -> Crinos at 49 | 1 s | 6 s | **7 s** |
| Homid -> Crinos at 48 | refused (7 short) | | |
| Homid -> Crinos at 48, Resolve 1 | 1 s | 6 s | **7 s** |
| Crinos -> Homid at 81 | 1 s | 6 s | **7 s** |
| Crinos -> Homid at 82 | held | | |
| Berzerker Crinos -> Glabro at 61 | 4.8 s | 6 s | **10.8 s** |
| Homid -> Glabro at 14 | refused (floor 20, no buffer) | | |
| Homid -> Glabro at 50 under a clear full moon, outside | 6 x 0.75 = 4.5 s | 0 | **4.5 s** |
| Homid -> Crinos at 50 under a clear full moon, outside | 0.75 s | 5 s | **5.75 s** |
| Homid -> Glabro at 50, full moon, clear noon, outside | 6 x 0.875 = 5.25 s | 0 | **5.25 s** |

## Resolve

| | |
|---|---|
| perk id | `WTAGarou_Resolve`, parent `WTAGarou_Garou` (new category "Garou") |
| XP to level | 50, 100, 200, 350, 550, 800, 1100, 1500, 2000, 2600 |
| training | Resists that stop a running countdown: the 3rd, 6th, 9th... in one streak earn 8 XP; the others earn 3 XP, but only if the shift-XP cooldown (60 s) is over, and they restart it. The streak resets when Rage drops below 95 or the character reaches Crinos. Completed voluntary shift: 3 XP (5 into Crinos), one reward per 60 s. Forced shifts, cancels: 0. |
| every level | Crinos buffer window +1 Rage; resist timer penalty reduced by 0.1 s (2 to 1 s); passive baseline pull +1% (max +10%, capped below Crinos drain) |
| level 0 (since 0.5.2) | zombie charge: a Crinos sprint knocks down the first 3 zombies (4 at level 5, 5 at level 8) |
| level 1 (since 0.5.2) | roar stagger: the Q roar pushes the pack (force 1.0; 1.5 at level 6; 2.0 at level 10) |
| level 2 (since 0.5.2) | door charge: a sprint smashes closed wooden doors (12 Rage, 18 locked, plus stamina) |
| level 3 | passives only (was the door charge before 0.5.2) |

Existing characters start at Resolve 0 and have to earn the three abilities
back. `/garou resolve <n>` sets the level for testing. The completed-shift
Crinos burst (0.4.29) is not gated; only the Q roar is.

Where the XP lands: the server validates every award and grants it with the
Build 42 `addXp` global (then `XP:AddXP`). If a hosted playtest shows the
client never receiving it, flip `WTAGarou.Resolve.CLIENT_APPLIES_XP = true`:
the server then only notifies and the owning client applies the amount.

Deferred from the roadmap (not in this build): Resolve modifiers to Crinos
drain or shift costs; tougher-door charging;
roar knockdown probability as a separate stat; auspice starting levels.
The starting-level allocation is now specified in
[the three-skill roadmap](ROADMAP_SPIRIT_GIFTS_2026_11_03.md#auspice-starting-garou-skills).
It is deferred until Resolve, Wits and Gnosis are all implemented; this
Resolve-only candidate still does not grant auspice starting levels.

## Files

- `42/media/perks.txt` (new), `Translate/EN/UI.json` (perk names)
- `shared/WTAGarouDefinitions.lua`: `ShiftBuffer`, `MoonLight`, `Resolve`,
  `TransformTime.PAIR/PAIR_BERZERKER/CENTER_ON_BASELINE/MIN_SECONDS`;
  `CenterRage`, `PairBaseSeconds`, `ComputeTransformSeconds(r, g, data)`,
  `CrinosEntryShortfall`, `CrinosExitExcess`, `ShiftBufferWidth`,
  `ShiftBufferSeconds`, `ShiftAdmission`, `MoonLightMultiplier`, `ShiftSeconds`,
  `ResolveStep`, `ResolveUnlocked`, `ResolveCrowdChargeLimit`, `ResolveRoarForce`,
  `CrowdChargeFor(form, level)`
- `shared/WTAGarouResolve.lua` (new): perk lookup, `levelOf`, `grant`,
  `applyOnClient`, `setLevel`, `MoonBrightness`, `MoonLightExposure`
- `server/WTAGarouServer.lua`: TransformRequest admits through `ShiftAdmission`
  and times through `ShiftSeconds`; `AwardResolve` on resist and completed
  voluntary shifts; door charge gated; `DebugSetResolve`
- `server/WTAGarouCrinosBurstServer.lua`: roar gated and scaled
- `client/WTAGarouClient.lua`: buffer notice, `ResolveXP`, `ResolveSetLevel`,
  `CrinosRoarResult`; `WTAGarouVisual.lua`: crowd charge by level;
  `WTAGarouDoorway.lua`: `no_resolve` text; `WTAGarouHUD.lua`: Crinos tooltip;
  `WTAGarouTutorial.lua`: "Shifting time" and "Resolve" pages; `WTAGarouDebug.lua`:
  `/garou resolve`; Origin wording in WolfCoat/HUD/Debug
- tests: `resolve_test.lua` (new, in run.sh); rage_engine, crinos_burst,
  door_charge, visual and wyrm_tutorial updated for the gates and the pages

## Local playtest (smallest tests that settle each hypothesis)

Full game restart with the new Lua; check the banner says 0.5.0.

1. **Perk registers.** Open the skills panel: a "Garou" category with "Resolve"
   at 0. If missing, `perks.txt` did not load (console: look for a perks
   parse error) and every Resolve ability stays locked.
2. **Entry buffer.** `/garou rage 50`, shift to Crinos from Homid: accepted,
   notice "You reach for Rage you do not quite have. +5 s.", channel about 6 s,
   Rage 40 afterwards. `/garou rage 48`: "Not enough Rage."
3. **Exit buffer.** In Crinos `/garou rage 81`, shift to Homid: accepted, "The
   Rage clings to you. +6 s.", about 7 s. `/garou rage 82`: "The Rage will not
   let you go yet."
4. **Glabro unchanged.** Homid at 19 Rage -> Glabro refused; at 20 accepted.
5. **Moon.** Outside, night, clear sky, full moon (sandbox or wait): Homid ->
   Glabro at 50 Rage channels about 4.5 s instead of 6. Step deeper indoors,
   away from exterior openings: 6 s again.
   Same moon at noon, clear sky, outside: about 5.25 s. New moon by day: 6 s.
   The server log line `[WTAGarou][Shift]` prints exposure and the multiplier.
6. **Resolve XP.** At 100 Rage, Resist once: "You held the Rage down. Resolve
   +3." Resist twice more without letting Rage drop below 95: the second
   gives nothing (shift cooldown), the third gives "Resolve +8." The skills
   panel moves by the same amounts. On a hosted game, check the XP lands on
   the client; if not, flip `CLIENT_APPLIES_XP` and retest.
7. **Gates.** At Resolve 0 in Crinos: sprinting into zombies does not knock them
   down; Q roar is noise with "Your roar is only noise. Resolve 2 needed to
   stagger."; a door charge gives "You slam into the door. Resolve 3 is needed
   to break it." `/garou resolve 3`: all three work. `/garou resolve 5`: four
   zombies go down per sprint.
8. **Save/load.** Reload the save: the level persists (vanilla perk storage).
9. **HUD baseline.** With Startup baseline 50, clear full moon at night,
   outside: yellow marker at 50, white at 65. If negative moodles produce
   a bracket, it centres on 65 without changing width. At noon, white/bracket
   centre at 57.5. Deeper indoors, white disappears beneath yellow at 50.
   Howl and fed/watered drift should head to the same displayed target.
10. **Openings.** On the indoor tile beside an exterior window: exposed with
   no curtain or an open curtain; unexposed after closing it or barricading
   the window. Repeat with an exterior door closed/open, in both north/south
   and east/west orientations. Move one tile deeper: no exposure.
   Test a second player operating the curtain/door on a hosted server.
   Interior room-to-room openings must not expose either room.
11. **Empty doorways.** Repeat the same exposure test at a bare exterior door
   frame, then remove/destroy an exterior door while leaving its frame.
   Both should expose the adjacent indoor tile just like an open door.
   Test both orientations; move a tile deeper to lose exposure. Reinstall
   and close a door: exposure must stop again. Block the empty doorway
   and check that it no longer counts. Repeat after save/reload and with
   another player removing/replacing the door on the hosted server.
12. **Covered porch.** Repeat open-door, empty-frame, removed-door and window
   tests with the outdoor neighbour under a porch roof. That edge should
   give no bonus; yellow and white should overlap unless a different edge
   qualifies. Stand on the roofed porch itself: still no bonus. Step beyond
   the roof into unroofed outdoors: exposure should return. At night under
   a clear full moon and selected baseline 50, expect 50 on the porch and
   65 beyond the roof. Check both existing roofs and player-built cover.

Keep the host `coop-console.txt` and the client `console.txt` on any failure.
