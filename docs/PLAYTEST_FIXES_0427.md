# WTAGarou 0.4.27: coats and playtest follow-up

This patch preserves the author's definitions edits from commits 538f4f9
and 5d480fa. It includes a rebuilt client Java JAR. Fully restart the game
after updating the mod; Reload Defs cannot load new Java classes.

## Wolf coat

- Startup chooser: Original or Blonde, for both Lupus and Hispo.
- Existing and new Garou characters without a choice receive the prompt.
- Reopen using right-click world > Wolf coat.
- Selection lives in character mod data, not an account-wide setting.
- Multiplayer selection is server-validated and replicated to observers.
  A startup request obtains the saved choice before deciding to prompt.
- The renderer changes the individual render record, never the shared model.
  While the blonde texture loads, it falls back to the original.
- Character-creation UI and live wolf preview are not implemented.

## Playtest fixes to verify

- Every configured gear point now has a `pivot = {x,y,z}`: all WolfSlots,
  MouthCarry, Saddlebag and Harness. Existing Back pivot is preserved.
- Wrench attachments `wrench_left` / `wrench_right` use the belt rules.
- Bag offset/pivot tuning cancels the FBX import-unit multiplier. The log
  showed that the bag was loaded and drawing, not a missing-file error.
  This targets excessive displacement; visibility still needs a game test.
  The FBX format itself is not a reason to rename or convert the asset.
- Gait/idle sublayers remain inert after native mask transfers, targeting
  the secondary-hand paw wag that returned after initially looking correct.
  Stationary bite masks still include hips/hind legs; strafing is unchanged.
- Open/close/struggle window clips retain native human duration instead of
  waiting for the substituted wolf cycle. No global timed-action override.
- Stomp recognizes native `Stamp` names as well as `Stomp`.
  `WTAGarou.WolfGait.STOMP_SPEED` is the setting; lower means slower.
  The author's current 2.0 remains untouched. Try 1.0 or 0.75 for comparison.
  Reload Defs refreshes active wolf animation tracks and reports Java values.
- Initial forced-Crinos countdown is 10 seconds, matching the alarm.
  Subsequent Resist countdowns continue shortening under the existing rules.
- `Wolf_Sit_idle.glb` holds the last pose of the author's corrected Sit.
  `Wolf_getup.glb` reverses it. Regenerate with
  `python3 WTAGarou/tools/build_wolf_seated_clips.py` after editing Sit.
  The idle is intentionally a still placeholder, not a breathing animation.

## Verification and limitations

Run `bash WTAGarou/tests/run.sh`, `bash WTAGarou/java/build.sh`, and
`bash WTAGarou/java/test.sh`. The optional `PZ_JAR` environment variable
adds numerical tests using the privately supplied game's JOML classes,
including imported bag offsets and repeated pooled equipment changes.
The game binary is never included in the repository or mod JAR.

Tests cover cosmetic authorization and routing, observer updates, per-player
texture isolation, async fallback, window/stomp timing, masks, attachment
math, Lua syntax, assets and prior gameplay regressions. These are fixture
and numerical tests, not an actual in-game or live multiplayer playtest.

Prioritize a saved Blonde character reload; switching Original/Blonde while
in both wolf forms; two differently colored players together; bag/wrench
visibility through equip changes; window actions; stationary versus strafing
bites; a secondary flashlight walk beyond ten seconds; and sit/get-up.

The proposed human-animation Crinos body with a custom head and matching
fur tint remains a design direction, not an implemented feature.
