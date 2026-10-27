# Werewolf: Outbreak 0.4.28

## Confirmed in the September 29 playtest

The author selected Blonde, quit, continued, and remained Blonde.
The saddlebag is visible and disappears when the worn bag is unequipped.
These behaviors and the attachment tuning in 9039285 are preserved.
Held sling orientation remains unchanged, as requested.

## Silver: earlier warning, less damage

- Contact onset: approximately the next one-second scan, previously 20s.
- Initial burn: 2 instead of 15; continued exposure adds 0.05/s instead of
  0.5/s; new severity cap 30 instead of 100. Existing larger burns are never
  reduced merely by equipping silver again.
- Real ongoing damage: 4% of vanilla's unbandaged burn tick for a fresh
  silver burn, rising gradually to 20% at the severity cap.
- Washing, bandaging, ordinary burn healing and the per-body-part block on
  Garou regeneration remain intact. Removing silver stops exposure growth,
  not the wound itself. Bandaging retains vanilla's burn-damage protection.
- Long necklaces still touch Neck and Torso_Upper, so both may burn.
- Any item's full type or display name containing Silver qualifies,
  now case-insensitively even for SILVER or sIlVeR. The mod-data marker and
  Silver tag still work. This is not limited to the debug kit's three items.
- Gloves protect held silver, not a worn silver ring.

The supplied 42.21 BodyPart bytecode applies the same 3.75 damage constant
for any positive burn time. Lowering INITIAL_BURN alone would therefore
not fix the rapid health loss. Two scoped Java hooks reduce only that
native damage call inside DamageUpdate. No HP refunds or general wound
immunity are introduced. Weapon-hit damage amplification remains unchanged.
The factors are repopulated from saved silver-wound flags during scanning.

All values above are tunable in WTAGarou.Silver in Definitions.
Fully restart with the new JAR: an old JAR cannot apply reduced tick damage.
This does not heal the critical character or erase existing burns.
Test on a healthy character so prior injuries do not obscure the change.

## Coat picker and new PNGs

The picker starts 12px below the main Garou panel, aligned to its left edge
and clamped to the viewport. If the HUD is too near the screen bottom,
clamping takes precedence over placing the chooser off-screen.

New PNGs are NOT automatically discovered. Add the PNG alongside the existing
textures, then add one entry in
`42/media/lua/shared/WTAGarouWolfCoats.lua`, for example inside the table:

```lua
brown = {
    label = "Brown",
    path = "media/textures/Body/WTAGarou_Wolf_Brown.png",
},
```

The selector adds a button automatically and Java loads the listed texture.
No Java rebuild is needed for subsequent coats. Use filename suffixes made
of letters, numbers, underscores or hyphens; case must match the actual PNG.
Ship the same registry and PNGs to server/clients, then restart the game.
Keep existing keys stable to preserve saved choices. Missing PNG buttons
are disabled. There is no live model preview.

## Attachments and testing

- The log explicitly hid `meatcleaver_left` and `meatcleaver_right` because
  no slot rule matched. Both now map to their corresponding belt rules.
- Actual equipped items also contribute aliases through their registered
  attached location and hotbar slot type, reducing type-by-type exceptions.
  Unknown clothing stays hidden; this is not a blanket "show all" switch.
- Belt/back/holster offsets are CHARACTER-space: X sideways, Y up,
  Z forward/back. Pivots are ITEM-local after imported/bone orientation.
  A rotated item's axes may look exchanged relative to offset controls.
  No axis swap or placement changes are made to the author's tuning.
- The Gear kit testing-panel button (`/garou gearkit`) attempts to add
  Schoolbag, Duffel Bag, Hiking Bag, Wrench and Meat Cleaver to inventory;
  missing item definitions are skipped and the result reports a count.
  Nothing auto-equips.
- The saddlebag condition uses worn containers, not a sling-name allowlist.
  Held-only bags do not trigger it.

The vanilla debug list failed in `ISItemsListTable.initList` with a null
`toString` access. The Gear kit bypasses that screen; it does not repair
the vanilla debug window or claim to identify the offending item definition.

## Get-up transition

Sit/get-up use one authored pose pass stretched over the native action
duration, not tiled locomotion cycles. A native reversed sit node selects
the already-reversed get-up asset and disables a second reversal/loop.
The sit-on-ground name is excluded from the generic on-ground corpse match.
All pooled animation parameters are restored afterwards. The held seated
idle is still intentionally frozen; no new idle animation was authored.

## Verification and next playtest

Lua suites, Java advice fixtures, asset/package checks and the optional
404-case JOML attachment test pass. The supplied 42.21 game JAR accepts
all 25 patch targets in the offline weaving audit. The 27 silver damage
tests cover ordinary burns, other wounds, bandages, external hits,
time multipliers, healed parts, nested calls and exception restoration.
Game binaries are not shipped.

These checks are not an in-game health/animation/multiplayer test. Retest:
healthy Garou + long necklace for a few seconds then remove, wash/bandage;
cleaver on both belts; Gear kit's different worn bags; one sit/get-up;
picker position beneath a moved HUD. Preserve the confirmed Blonde save.
