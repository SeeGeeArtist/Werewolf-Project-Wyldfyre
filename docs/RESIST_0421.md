# 0.4.21 - Resist the change

User design, September 26 evening. Lua and one icon only; the Java jar is the
0.4.20 build and still reports 0.4.20 (nothing in it changed).

## The cycle

1. Rage reaches 100 outside Crinos: the displayed countdown starts
   (`FORCE_CRINOS_SECONDS`, 15 s). It ends in a forced Crinos as before.
2. **Resist** (panel button under Howl, radial slice next to Howl on the root
   communication radial, or the `WTAGarou_Resist` key) while the countdown
   runs cancels it. The panel says `Resisted the change (xN). Next warning
   lasts S.Ss.` The server then starts a HIDDEN rest interval, uniformly
   random in `[3, 12] x the countdown just resisted` (45-180 s after a 15 s
   countdown; 6-24 s after a 2 s one). It is never displayed.
3. When the rest ends and Rage is still `>= FORCE_CRINOS_CANCEL_BELOW` (95),
   the next countdown starts - shorter. Rage does not have to touch 100
   again inside a cycle.
4. Countdown length after `n` Resists (`WTAGarou.ResistCountdownSeconds`):
   `15 - n` while that stays `>= LOG_BELOW` (2 s; so 15, 14, ..., 2 over the
   first 13 Resists), then `0.5 + 1.5 / (1 + ln(1 + k))` with `k` counting
   Resists past the linear phase: 1.39, 1.22, 1.13, 1.07, ... It shrinks by
   ever smaller steps and never reaches 0.5 s (a million Resists: 0.60 s).
5. The cycle ends - `n` back to 0, rest cleared, full 15 s next time - when
   Rage falls under 95 or the character enters Crinos (forced or chosen).
   The panel says `The urge to change fades.` on a reset that followed at
   least one Resist.

A Resist with no countdown running answers `Nothing to resist.` and does not
count.

Constants: `WTAGarou.Rage.RESIST = { LINEAR_STEP 1.0, LOG_BELOW 2.0,
MIN_SECONDS 0.5, REST_MIN_MULT 3, REST_MAX_MULT 12 }` in
`shared/WTAGarouDefinitions.lua`.

## Wiring

- Server (`server/WTAGarouServer.lua`): `d.resists`, `d.resistRestUntil`,
  `d.crinosCountdownSeconds`; `startCrinosCountdown`, `resistCountdown`
  (`WTAGarou.ResistCountdown`), `resetResistCycle`; command `ResistRequest`
  (trait-gated); replies `CrinosCountdown {seconds, resists}`,
  `CrinosCountdownCancelled {reason = "resisted"}`, `ResistResult {ok,
  resists, resisted, nextSeconds | reason}`, `ResistReset {reason, resists}`.
- Client (`client/WTAGarouClient.lua`): `WTAGarou.RequestResist()`; notices
  for `ResistResult` / `ResistReset`.
- Panel (`client/WTAGarouHUD.lua`): right column is now Strip, Dress, Howl,
  **Resist**, Guide (Guide moved down one row). The Resist label reads
  `RESIST 1.4` on a red background while a countdown runs.
- Radial (`client/WTAGarouEmote.lua`): `Resist / the change` slice next to
  Howl; label `RESIST / 1.4s` while a countdown runs. Icon
  `media/ui/WTAGarou/wta_resist.png` (48 px raised hand, same red as the
  other slices).
- Key bindings (Options > Key Bindings > [WTAGarou]): `WTAGarou_Resist`,
  `WTAGarou_Strip`, `WTAGarou_Dress`, all unbound by default
  (`Keyboard.KEY_NONE`). `WTAGarou.HUD.keyAction(key)` is the pure dispatch.
- Guide: the Rage page explains Resist in two sentences.

## Tests
`tests/rage_engine_test.lua`: curve values (15, 14, 2, first log step,
monotone, shrinking steps, asymptote), rest bounds at roll 0/1/0.5 and a
random roll, the full cycle (Resist succeeds, cancel reason, hidden rest in
range, failed Resist does not count, next countdown 14 s after the rest at 97
Rage, forced Crinos after exactly 14 s, reset on Crinos and on Rage < 95,
full 15 s again). `tests/channel_hud_test.lua`: Resist/Guide rows, label and
colour during a countdown, keybinds registered unbound, dispatch.

## Not verified in game
Every part of it. In particular whether `ISButton:setBackgroundRGBA` and
`setTitle` behave as expected on 42.20.2, whether a `Keyboard.KEY_NONE`
entry shows up as an empty binding in the options screen, and whether a
half-second countdown is humanly resistable through the radial (the panel
button and a bound key are the intended way at that point).
