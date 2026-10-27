# WTAGarou 0.4.31: true form and playtest follow-up

This patch incorporates the two latest logs/screenshots, the Human/Wolf true-form
request, and the author's newer Timber/Brown/Brindle commits through `9b4178e`.
Automated fixture and compatibility checks are not an in-game playtest.

## Pull and restart

Pull `feature/cosmetic-model-swap`, fully exit Project Zomboid, and restart it.
Both Lua and the bundled `WTAGarou/42/media/java/client/WTAGarouVisuals.jar`
change. **Reload defs cannot install Java hooks or the new corpse AnimSet.**
The load banner and Java status should both report `0.4.31`.

## Timber startup failure confirmed

The newest 01:42 test log is still running 0.4.30. It explicitly reports
`model ready; texture=null (Body/WTAGarou_Wolf)` and
`media/textures/Body/WTAGarou_Wolf.png=MISSING`, then `Direct wolf ... failed`.
The mesh, animation rig and animation files are present. Adding a coat is not
the failure: renaming the original PNG to Brown left both native model scripts
pointing at a missing base texture, so Java preflight correctly refused the
wolf before applying a selectable coat. The script references now use Timber;
the Crinos default references and missing Timber swatches are updated as well.
Pull and restart, rather than using Reload defs for this repair.

## True form and coat picker

- **Human or Wolf:** select the true-form button, then click a coat to save both.
  Human means Homid; Wolf means Lupus. Both use the same stats, costs and
  transformations as before, with the requested base-form exception.
- **Starting form:** first-time Wolf selection from Homid switches to Lupus
  without spending Rage. This is the startup dialogue, not a pre-spawn character
  creation integration. Existing characters without an identity are prompted
  once, even when they already have a coat.
- **Zero Rage:** every form other than the selected base reverts immediately on
  the next Rage tick. Wolf-born Homid also reverts to Lupus. The base itself
  remains stable at zero; no repeated shift loop.
- **Persistence:** plain per-character saved values; server validates owner,
  identity and coat. Reconnect returns the saved choice. Later changes through
  the picker update the fallback but do not grant a free immediate transformation.
  Pending shifts block edits.
- **Corpse:** Wolf-born characters use a Lupus-sized, coat-matched `Wolf_dead`
  render snapshot, regardless of the form in which they died. Human-born
  characters retain the existing human corpse path. Real corpse loot and
  inventory are unchanged; human clothing/held models are hidden on the wolf
  snapshot. No fake animal corpse or death-animation reset.
- **Corpse limits:** new render path needs live testing, including save/reload,
  turning corpses, and multiplayer observers. Missing/unready assets and later
  decomposed skeletons fall back to native visuals. Reanimated zombies and carried
  corpse inventory icons are not new wolf-model systems in this patch.

The picker retains its left inset and position beneath the Garou panel.

## Gameplay and silver

- **Crinos completion burst:** radius increased from 1.5 to 3 tiles. It remains a
  non-damaging native stagger, blocked by walls/closed barriers and other floors.
  The supplied first log recorded one shift with two local targets, so the
  earlier burst did execute at least once; this does not prove every combat case.
- **Silver contact:** burn begins around one second, mildly. A smooth S-curve
  rises from severity 2 to 75 by 60 seconds, then plateaus. Native burn damage
  scales from 4% to 85% with severity; the actual health/pain outcome still needs
  balancing in game, especially comparing rings and multi-part necklaces.
- **Nonlethal burn:** only the identified silver burn tick is capped, stopping
  at 20 overall health or 5 health on the affected part. No health is refunded.
  Bites, bleeding, fire, starvation, silver weapon hits and other damage can
  still kill. This requires the new Java JAR.
- **Treatment:** washing/bandaging still matter. Removing the item stops contact
  escalation, but the wound remains and that part's super-regeneration remains
  blocked until the burn heals. It does not instantly reset after removal.
- **Food:** immunity applies only to fresh, untainted, unpoisoned dangerous raw
  food. Rotten meat keeps vanilla harm. No changes to frozen food, unhappiness,
  boredom, nutrition, or normal freshness penalties.

## Wolf equipment and animation

- **Attachment refresh:** clothing/equipment refresh now republishes actual item
  aliases to Java, addressing items such as the snow shovel appearing only after
  Reload defs. The supplied author pivot/offset/scale values are preserved.
- **Held containers:** cosmetic workaround hides containers held in either hand
  while a wolf, instead of drawing their skewed/skinned bag model on paws.
  Inventory, hand equipment and worn saddlebags are not removed.
- **Traversal recovery:** fence/vault/window clips, including named end/recovery
  phases, keep native human event timing rather than a longer wolf idle clock.
  This needs a repeat of the reported fence/window test; missing marker data
  still uses the existing safe fallback.
- **Ground get-up:** recognizes ground-sit exit names and `forceGetUp`, selects
  the authored `Wolf_getup`, and clears reverse/loop only during playback. Chair
  behavior and pooled parameters are preserved.
- **Seated looking:** Ctrl head/neck tracking is not implemented here. Re-enabling
  human twist/reparenting is unsafe given prior whole-body rotation regressions;
  this needs a scoped wolf neck/head solution.

## Crinos and authored coats

- **Head orientation:** quarter-turn correction lives in the Crinos head model's
  self `mount` rotation, now `90 0 0`. Sign/fit still needs a front/side playtest.
  The placeholder GLB itself was not regenerated or remodeled.
- **Skirt/tube:** mask the native optional `Dress` body region, which the opaque
  fur swatch exposed, while preserving the normal clothing compositor.
- **Timber default:** native wolf model scripts and Crinos head script now point
  to Timber assets. The author's rename removed the old default texture files;
  leaving those script references unchanged would break asset preflight.
- **Brindle and Timber:** generated corresponding body/head swatches from the
  latest coat images. Brown's existing swatches and all authored wolf images are
  preserved. These are color-matched fur swatches, not a full human-UV pattern
  transfer. Dark sampling can still make Brindle look dark.
- **Reload defs:** also reloads `WTAGarouWolfCoats.lua`; close/reopen the picker.
  New files may still require restart. In multiplayer the server must have the
  same registry/assets and be restarted/reloaded separately.

For future swatches without overwriting a head model:

```bash
python WTAGarou/tools/build_crinos_placeholder.py \
  --coat WTAGarou/common/media/textures/Body/WTAGarou_Wolf_Timber.png Timber
```

Do not run the generator without `--coat` over an authored replacement head.

## Testing kits

- **Gear kit:** packed green sleeping bag replaces the school backpack. Duffel,
  hiking bag, wrench and meat cleaver remain.
- **Firearm kit:** hunting rifle, shotgun, M9 (`Base.Pistol`), M36 small revolver
  (`Base.Revolver_Short`) for ankle-holster testing, ankle/regular/shoulder
  holsters, angle-headed flashlight, ALICE belt-and-suspenders and battery.
  The M36 is the small handgun choice, not a new custom pistol.
- **Ammo:** 60 rounds per weapon and two removable magazines where supported,
  resolved from each actual weapon's ammo/magazine getters. Guns remain unloaded;
  equip and load manually. Missing item IDs are reported rather than silently
  pretending the entire firearm kit spawned.

Accessory identifiers were checked against the
[angle-headed flashlight entry](https://pzwiki.net/wiki/Flashlight_-_Angle_Headed),
[ALICE webbing entry](https://zomboiddb.wiki/db/item/alice-belt-and-suspenders~c54858ce-cb6f-5ad1-b389-ad5e51201046),
and [shoulder holster entry](https://pzfans.com/en/wiki/items/Base/HolsterShoulder/).
Actual compatibility still follows installed game/mod item scripts; the kit does
not change which guns a holster accepts.

## Verification and next test

Verification commands:

```bash
bash WTAGarou/tests/run.sh
bash WTAGarou/java/build.sh
PZ_JAR=/path/to/private/projectzomboid.jar bash WTAGarou/java/test.sh
```

Lua/assets regressions, Java fixtures, and numerical attachment checks pass.
The private 42.21 hook audit resolves and weaves all 30 patches. These checks do
not boot the game, prove rendering, or certify multiplayer.

Suggested next test: choose Wolf + Timber, save/continue, set Rage to zero from
Homid and Hispo, then test death on a disposable character. Also check the Crinos
head from the front, traverse a fence/window, move the shovel between hand/back,
and get up from ground sitting. Test prolonged silver contact in a safe area,
without unrelated damage, to isolate the ramp and floor.
