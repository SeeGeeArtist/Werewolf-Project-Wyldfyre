# 0.4.51: player-owned Rage panels and Q voice cooldowns

## Change contract

- Target: stop Rage HUD/shift-channel ownership leaking between local players,
  add a controller-accessible Rage panel toggle, and rate-limit Q voices.
- Priority: online multiplayer correctness first; split-screen fixes are
  targeted to the reported HUD/radial/shift ownership problems.
- Baseline: `4cbf989` (0.4.50); retain the corrected head/coats and the unarmed
  Crinos swing/spiked-club impact integration.
- Confirmed by user: dressing/stripping already worked in the reported
  split-screen test. Preserve their queues, gear rules and inventory behavior.
- Must remain untouched: server shift authority, five-second Crinos knockback,
  full Howl behavior, Rage/balance tuning, corpse handling, controller
  select/cancel lifecycle, native title rendering, models and PNGs.
- Awaiting live verification: current two-client online play; local two-controller
  split-screen; perceived voice cadence and controller UI interaction.

## Evidence from Thursday

The user supplied both `coop-console.txt` and `console.txt` from October 8.
The former is a hosted-server log and contains no WTAGarou entries; it does
not establish which mod code the local client was running.

The client log contains the relevant evidence:

- Line 218: Java **0.4.46** load banner.
- Line 435: Definitions **0.4.48**.
- Lines 439 and 495: network bridge and command handler report
  `singlePlayer=true`.
- Repeated shift/howl action messages show the channels running, but do not
  record enough character identifiers to independently prove every crossed
  action in the user's report.

That version pairing was expected for the HUD-only .48 update. It is older
than the current .49/.50 changes and is not evidence those changes regressed.
The log files themselves are not published in the repository.

Current source exposes two concrete ownership defects consistent with the
report: the local ToClient bridge discarded the recipient character, and the
client handler chose getPlayer() again; the single shared HUD also used
getPlayer() for both displayed data and controls. A controlled two-player
fixture now deliberately points getPlayer() at the wrong actor and verifies
these paths preserve the intended owner.

## Implemented

### Response routing, with online authority preserved

In pure local play, `Net.ToClient` passes the intended player object to the
registered client handler. The handler never re-resolves that direct reply
through ambient getPlayer().

For online play, the server copies the response payload and stamps
`_wtaRecipientID` from the actual recipient's online ID. The client matches it
against local players only. Any recipient tag supplied in a reusable/input
payload is overwritten; the original payload is not mutated.
Requests still use native `sendClientCommand(player, ...)` and the server's
actual sender. No client-selected destination grants gameplay authority.

Unknown, invalid or stale recipient IDs are ignored rather than redirected
to player zero. Untagged legacy replies are accepted only when there is one
local player. Therefore update server and clients together for online
split-screen; mixed versions must not silently corrupt another character.

Howl Started/Stopped remain one broadcast per connection and use the existing
sound owner's ID. Visual snapshots remain on their existing validated path.
Coat confirmation receives the resolved player as well.

### Rage HUD and controller access

Each local character has its own HUD instance, saved layout, Rage/form reads,
buttons, channel display and Crinos countdown. Button callbacks explicitly
pass that HUD's owner. Positioning/clamping uses the player's viewport.
Late local joins/respawns get a panel; manually hiding it is not undone by
ordinary updates, and death removes only that character's panel.

The old `HUD.instance` is retained only as a primary-player compatibility
alias. It never becomes the last-created panel. The Rage title continues
using the .48 native Java text-rendering workaround.

D-pad-down social order is now:

1. Existing vanilla social slices.
2. Howl.
3. **Toggle Rage panel**, using `media/ui/WTAGarou/wta_shift.png`.
4. Strip.
5. Dress.

The toggle callback receives the invoking controller's player. It does not
replace native slice selection or take over radial focus. D-pad-right
Resist countdown feedback uses that same player's HUD, not the primary one.

### Q voice rate limit

For Lupus, Hispo and Crinos:

| Posture | Minimum accepted-call interval |
|---|---:|
| Standing bark/roar | 200 ms |
| Crouched growl | 400 ms |

The gate uses Java's monotonic clock, so it does not depend on in-game
time acceleration. It is independent per character, persists through ordinary
voice-profile refreshes, and switching posture cannot bypass the previous
call's interval. Suppressed Q presses are consumed without human-shout
fallback, extra audio/world sound/text, or a new pending roar effect.

Crinos roar **knockback remains on its existing five-second server cooldown**.
The faster audible roar interval does not shorten that combat cooldown.
Full Howl, pain/attack/death cues, sound radii and audio volume remain unchanged.

## Verification

Passed:

```sh
bash tests/run.sh
bash java/build.sh
bash java/test.sh
git diff --check
```

Coverage includes:

- 696 HUD/channel assertions, including distinct Rage values and form-button
  states, explicit callback owners, independent timed-action feedback,
  viewport/layout ownership, per-player toggle/death, late joins and
  remote-player exclusion.
- 20 direct/local and online reply-routing assertions, including deliberately
  wrong getPlayer(), recipient spoofing, immutable payloads, invalid/stale IDs,
  safe one-local-player compatibility and unchanged native command sending.
- 55 controller-radial assertions, including the new glyph/order, second
  controller callback owner, and no cross-player countdown.
- 71 Java stealth/voice assertions under real ZombieBuddy advice, including
  exact 199/200ms and 399/400ms boundaries, per-character independence,
  spam suppression, posture switching, voice-profile refresh and human
  fallback after the form profile is cleared.
- Existing roar authority/cooldown, vehicle, corpse, Rage/balance, rendering,
  coat, controller, harness, native audio and .50 attack fixture suites.

The shipped JAR was rebuilt and inspected for its .51 banner and 200/400ms
constants. No server gameplay Lua, animation XML, model or PNG changed.
The user-installed game is not available here, so these passes do not certify
the current game's rendered UI, network timing or audio.

## Minimal playtest, online first

1. Fully stop the game and server. Update server and clients from
   `feature/cosmetic-model-swap`; include the rebuilt client
   `42/media/java/client/WTAGarouVisuals.jar`. Verify Definitions and Java
   both report **0.4.51** on clients after restarting.
2. With two online clients, give the characters different Rage/form states.
   Each player's HUD/radials must affect only that player. Test shift,
   cancellation, Resist/countdown and full Howl audio as before.
3. In each of Lupus/Hispo/Crinos, tap Q rapidly while standing and crouched.
   Check the 200/400ms cadence. Spam standing Crinos roar near zombies and
   verify knockback still cannot recur before five seconds.
4. In local split-screen, use D-pad-down > **Toggle Rage panel** on each
   controller. Hide/reopen one panel without changing the other.
5. Give one character Hispo while the other is Homid. The Homid player's
   Hispo choice must remain usable. Shift both independently; each
   channel/progress bar must appear on and complete for its own character.
6. Check separate Rage values, countdowns and cancellation, then dress/strip
   once on both players to confirm their previously working behavior.

If any request still crosses players, capture the fresh **client console.txt**
and the corresponding server log; old .48 logs cannot verify this build.

## Scope limits

This is not a blanket split-screen certification. Legacy cheats/tutorial
windows and some secondary utility notices still use primary-player or
singleton behavior. The existing wardrobe retry/report internals were not
rewritten because dressing/stripping was reported working. Those can be
addressed separately if a fresh test identifies a concrete problem.
