# 0.4.24 - September 27 (evening) playtest fixes

Console: the 5:03 PM upload. Every item below names the console evidence,
the change, and what is verified where. Nothing here was seen running in
the game; "verified" means the unit fixtures, "unverified" means it needs
your next wolf-on.

## 1. "Reload defs" always failed

- Console: `[WTAGarou] reload failed: Object tried to call nil in pcall`.
  Kahlua has no `loadstring`; the button never reloaded anything, which is
  why "edit, save, reload defs, wolf off/on" changed nothing until you used
  the debug menu's Lua reload.
- Fix: `WTAGarou.Debug.reloadDefinitions` finds the path the game loaded
  `WTAGarouDefinitions.lua` under (`getLoadedLuaCount`/`getLoadedLua`) and
  calls the engine's `reloadLuaFile(path)` - the debug menu's own call.
  `loadstring` is used only where it exists (the test host).
- Verified: `tests/test_panel_test.lua` (loaded-path match, mod-path
  fallback, honest failure report). Unverified: the button in game.

## 2. Jog-stop coast and the Ctrl-turn swing

- Console: `[Gait] human Bob_RunToStop: duration=1.000 stride=0.811 ...
  derived=4.000 -> Wolf_run`. Transition nodes were stride-matched like
  cycles: a 1.0 s stop became a 4.0 s stop with 4x the travel. Strafing
  during that stretched stop is the swing/clip-through-floor you can
  reproduce on demand.
- Fix: `WolfPlayerClips` recognises transition nodes (`XToY`, `Turn`,
  `180L/R`) and keeps the human duration and marker travel 1:1; the wolf
  cycle is tiled across the clip at its native cadence (x slowdown).
  Toggle: `WTAGarou.WolfGait.TRANSITIONS_KEEP_HUMAN_TIMING` (true).
- Verified: `WolfPlayerClipsTest` (RunToStop stays 1.0 s, travel 0.811,
  tiling, toggle). Unverified: the coast and the swing in game.

## 3. Jumbo items that change size on refresh

- Report: belt/mouth items ~2x, the food being eaten ~3x, sizes changing
  after equip/unequip. `compensateScale` compared the field with "what we
  wrote last"; a pooled `ModelInstance` reused for another model, or reset
  by the engine between our draws, could be compensated on top of an
  already-compensated value.
- Fix: the target is always `modelScript.scale / BODY_SCALE` (the engine
  only ever writes the field from the script or resets it to 1), whatever
  the field holds. Restore writes the script scale back. First 16
  compensations are logged as `[WTAGarou Java][Scale] sub-model ...`; the
  Perf line gains `slot retargets=` and `scale recompensations=`.
- Verified: `WolfCombatTest` (over-compensated value pulled back; a reused
  instance takes the new script's scale; jaw item still once by 1/BODY).
  Unverified: sizes in game. If items are still off by a constant factor,
  that constant is now a Definitions matter (`WTAGarou.Saddlebag.scale`,
  `WTAGarou.Harness.scale`), not drift.

## 4. Items rotating about their handle tips

- New per-slot `pivot = {x, y, z}` in `WTAGarou.WolfSlots` rules (item
  space, metres): the mesh is shifted by `-pivot` after its rotation so
  that point sits on the strap and the item turns about it when the spine
  bobs. Java `setWolfSlotPivot(key, x, y, z)` (separate call after
  `setWolfSlot`, so Kahlua sees one signature per name).
- Verified: matrix call order in `WolfCombatTest`
  (`translateLocal(offset)` then `translate(-pivot)`). Unverified: the
  right pivot values per item (you tune them).

## 5. `shovel_back` hidden

- Console: `[Slot] hidden on the wolf (no WTAGarou.WolfSlots rule):
  attachment="shovel_back"`. The engine names the Back attachment per item
  type. `slotRule` now matches by suffix: a "back" rule covers
  `shovel_back`, `bag_back`, `rifle_back` ... (`secondary` never matches
  by suffix; longest suffix wins).
- Verified in `WolfCombatTest`. Unverified: the shovel drawn in game.

## 6. Slot code exception safety

- The 0.4.23 slot section ran inside the outer `hideSubmodel` try whose
  catch returns "draw". A reflection surprise there would have DRAWN the
  item at the human attachment. It now has its own try/catch that hides
  the item and counts `slotErrors=` in `wolfSlotStatus()` (panel Status).
  Candidate explanation for the sheet-sling bag showing on the first
  wolf-on; unconfirmed - watch the Status line.

## 7. Crouch idle "walks in place"

- `Bob_SneakIdle`/`Bob_IdleCrouch` contain "sneak" and fell into
  `Wolf_walk`. Any idle node (that is not an `IdleTo...` transition) is
  now an idle. The sit loop, climb, fall, drink, strafe, turn and stop
  nodes map to optional clips you can author, each with a packaged
  fallback: see [WOLF_ANIMATION_LIST.md](WOLF_ANIMATION_LIST.md), which
  also answers the layering question.

## Not changed

- Saddlebags not visible although `[Saddlebag] retarget` lines appear:
  unresolved. With the scale fix in, look for the `[Scale] sub-model
  WTAGarou_Saddlebags` line - it prints the script scale and the drawn
  value. If it never prints, the bag is not reaching the draw path; if it
  prints, the placement (`WTAGarou.Saddlebag.offset`) is the suspect.
- Front paws sliding during a standing attack: needs `Wolf_attack_run`
  or a masked attack (list above).
- Item-hold layer driving the foreleg: a runtime change for a later
  version (documented in the animation list).

## Assets you asked to be pointed to

- Harness: `common/media/models_X/WTAGarou/WTAGarou_Harness.glb`, texture
  `common/media/textures/WTAGarou/WTAGarou_Harness.png`, generator
  `tools/build_harness.py`, model script `42/media/scripts/wtagarou_models.txt`
  (`model WTAGarou_Harness`), tuning `WTAGarou.Harness` in Definitions.
- Saddlebags: `common/media/models_X/WTAGarou/WTAGarou_Saddlebags.fbx`,
  texture `common/media/textures/WTAGarou/WTAGarou_Saddlebags.png`, model
  `WTAGarou_Saddlebags` (same script file), tuning `WTAGarou.Saddlebag`.
