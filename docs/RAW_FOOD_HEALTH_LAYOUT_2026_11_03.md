# Raw food and health-panel follow-up - November 3, 2026

Candidate Lua-only patch, not live-game verified. Keep the existing Java JAR and signature unchanged; no rebuild is needed for these Lua files.

## Changes

- Shared WTAGarouRawFood wraps full-meal complete and interrupted-meal eat on the authoritative side. Eligible Garou meals are dangerous uncooked food that is not rotten, tainted or explicitly poisoned. Preserve pre-existing POISON and legitimate reductions; normal consumption and nutrition still run once. Multiplayer clients do not restore stats. 0.5.1: during an eligible meal the food is marked safe-raw and then restored, so vanilla no longer zeroes the Full timer.
- Client WTAGarouHealthPanelLayout replaces only the existing mod's drawing helpers. Reserve the full status width in listbox.textRight; recalculate absolute list/content/window heights instead of subtracting from the injury viewport. Keep scrolling for screen-limited content and leave per-part silver labels and menus unchanged.
- Added raw_food_health_layout_test.lua to tests/run.sh. Fixtures cover meal eligibility, partial meals, pre-existing poison, client exclusion, repeated layout, text width, font height and screen limits.

## Verification boundary

No Lua tests, CI result or live game success is claimed at authoring time: the authoring environment had no Lua runtime. Run bash tests/run.sh from WTAGarou where Lua 5.1 is installed. Fixture assertions do not establish actual rendering or network behavior.

The inspected vanilla references were shared/TimedActions/ISEatFoodAction.lua (aecfa2fe214c56837054aad9e72bd45b121f9a94) and client/XpSystem/ISUI/ISHealthPanel.lua (3e2030eb07502dc88d40fa39735699eec864885c) in Project-Zomboid-Community-Modding/ProjectZomboid-Vanilla-Lua. Installed-build differences require verification.

## Local hosted playtest

1. Back up saves; use a disposable hosted world. Restart host and clients with matching Lua files.
2. From a healthy Garou, eat fresh raw meat in Homid and another form; repeat with a partly eaten interrupted portion. Compare POISON/Queasy before and after normal server updates.
3. Confirm human behavior and rotten/tainted/poisoned food consequences on separate disposable characters. Fresh raw meat must not cure existing poisoning. This patch does not remove Queasy from earlier meals or other causes, and does not cover arbitrary direct Eat calls from other mods on a server without Java.
4. While purging infection, inspect the complete percentage/time text and multiple injury rows. Check bandaged Silver Burn and lodged-silver labels, larger fonts, small screens, another patient's panel, reopen, shifts and purge completion.
5. Short lists must not gain a scrollbar merely from adding the line; long screen-limited lists still scroll. Watch for progressive resizing or errors.

Retain host coop-console.txt and client console.txt on failure. No art, audio, Rage balance, release version or roadmap changes are included.
