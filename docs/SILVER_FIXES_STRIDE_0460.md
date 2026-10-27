# 0.4.60: silver item fixes, 42.21 ammunition, glass vessels, Crinos stride

Branch `feature/cosmetic-model-swap`. Follows 0.4.59 and the October 14
Steam Deck playtest console (Build 42.21.0, non-debug).

## What the console proved

- The 0.4.59 preload is live: `[WTAGarou][Preload] wolf + Crinos assets
  ready (5.1 s)` at spawn, `ready (0.1 s)` after each coat change, and the
  `[WTAGarou Java] 0.4.59` banner.
- `InputScript.OnPostWorldDictionaryInit> Invalid input. line: item 10
  [Base.223Bullets]`: the .223 recipe had no valid input item.
- 4,500 `ISWidgetInput.lua:336/337` errors while hovering recipes: the
  recipe UI iterating that empty input list.
- Crafting silver shells: `performRecipe> NullPointerException: Cannot invoke
  InventoryItem.setAlcoholPower because "item" is null at Item.InstanceItem`.

## Fix 1: `ItemType = base:<kind>` (shells error)

Build 42.2x item scripts declare the kind of item with `ItemType =
base:normal` / `base:weapon` / `base:food` / `base:drainable` /
`base:literature`. The Build 41 keyword `Type = Normal` is not parsed at all
in 42.20.2 (`Item.DoParam` only knows `ItemType`), so the item loads, shows
in the recipe, but has no type; `Item.InstanceItem` then has nothing to
construct and the crafting code crashes on the null. Our 0.4.11 saddlebag
items already used the new keyword; the 0.4.58/0.4.59 silver items and the
0.4.x spirit-gift books did not. All 15 blocks converted. The test suite now
fails if a `Type =` line reappears in `silver_items.txt`.

Expected live: silver shells and every bullet calibre craft, forged silver
weapons and both nitrate vessels appear in the inventory.

## Fix 2: 42.21 ammunition catalogue (hover errors)

Build 42.14 removed .223 ammunition (the MSR700/Varmint Rifle now uses
5.56), added .357 Magnum items and moved the Revolver to .357 ([SteamDB
patch notes](https://steamdb.info/patchnotes/21952923/)). The 42.20.2 Lua
tree (`shared/Foraging/Categories/Ammo.lua`) lists the vanilla loose rounds
as ShotgunShells, Bullets357, Bullets38, Bullets9mm, Bullets45, Bullets44,
3030Bullets, 308Bullets, 556Bullets.

- Removed: `WTAGarou.Silver223Bullets`, `WTAGarou_SilverTip223`.
- Added: `WTAGarou.SilverBullets357` (`WTAGarou_SilverTip357`, from
  `Base.Bullets357`) and `WTAGarou.Silver3030Bullets`
  (`WTAGarou_SilverTip3030`, from `Base.3030Bullets`). Ten rounds, fragments,
  file and pliers, same as the other calibres. Icons borrow the .38 and .308
  loose-round icons until 42.21's own icon names are known.
- Catalogue is now nine calibres; Guide, Steam notes and tests updated.

Reference note: `PZ-reference/pzmcp-b42/media/scripts` predates 42.14 and is
stale for ammunition; `PZ-reference/vanilla-lua` (42.20.2) is the one to
trust for item names.

## Fix 3: any empty glass vessel for the nitrate

`WTAGarou_PrepareSilverNitrate` vessel slot: `item 1 tags[Glass;GlassBottle]
flags[IsEmpty]`, with `OnTest = WTAGarou.SilverAmmo.OnTestNitrateInput`:

- accepted: any EMPTY glass fluid container: jar, beaker, beer, whiskey,
  wine or other glass bottle, drinking glass;
- refused: anything with fluid in it; Glass-tagged items that are not
  fluid containers (windshields, shards); anything without the Glass tag,
  which is every plastic bottle.

The vessel is used up with the last application. 0.4.59 handed an Empty Jar
back when the four applications were spent; with bottles going in, a fixed
jar coming out was wrong, so `ReplaceOnDeplete` is gone. If a jar-for-jar
return is wanted later, it needs a per-vessel output item.

## Fix 4: Crinos (and Glabro) stride

Player movement is animation root motion: the engine reads the animated
root translation and `IsoPlayer.getDeferredMovement(Vector2, boolean)` hands
it to the mover each frame; vanilla's invisible-sprint cheat scales the same
vector. Crinos is drawn at 1.44x and Glabro at 1.24x, so each visible step
was that much longer than the ground covered: the feet slid.

`StridePatch` + `StrideRuntime` (Java) scale that vector by
`WTAGarou.Traits.<form>.stride`, set to the form's `modelScale`, and only in
locomotion states (PlayerActions, Strafe, Aim, PathFind, WalkToward,
DraggingCorpse). Climbs, falls, get-ups, hit reactions, attacks, emotes and
seated poses keep vanilla root motion because their translation has to land
on world geometry.

Net speed = cadence x stride, so the cadence multipliers were lowered. A
bigger body takes slower, longer steps:

| Form   | stride | walk/run cadence | sprint cadence | net walk | net sprint | 0.4.59 net |
|--------|--------|------------------|----------------|----------|------------|------------|
| Glabro | 1.24   | 0.95             | 0.92           | 1.18     | 1.14       | 1.10       |
| Crinos | 1.44   | 0.90             | 0.85           | 1.30     | 1.22       | 1.20/1.15  |

Wolves have no stride entry; their gait tuning is unchanged. Everything is
in `WTAGarouDefinitions.lua` and reloads with `/garou reload`.

Expected live: Crinos feet plant and push without sliding; Crinos and
Glabro are a little faster than before. Console prints
`[WTAGarou Java][Stride] root motion x1.44 in PlayerActionsState` once.

## Not a mod bug: right-stick look while seated

42.20.2 `IsoPlayer.update` derives the seated head-look from the
`AimingReticle` screen position, not from the stick vector. With a gamepad
the reticle sits where precision aim parks it (ahead of the player on
screen), which is north-ish in iso space: facing west the head turns right,
facing east it turns left. Mouse look works because the reticle follows the
mouse. WTAGarou does not touch AimingReticle, head look or facing for a
Homid (`WolfSeatedLook` is wolf-forms + furniture only). Reproduce with the
mod disabled to be sure.

## Testing kit

`/garou silver` (Test Panel: "Silver kit") now also adds 2 Fertilizer, a Car
Battery, Pliers, File, Screwdriver, an Empty Jar, 2 Silver Fragments and a
box of shotgun shells, so the nitrate and shell recipes can be tested
outside debug mode.

## Static evidence

Lua `tests/run.sh`: 30 PASS (silver_ammo_test 130, stealth_voice 281,
rage_engine 633). Java `build.sh` + `test.sh`: 21 PASS, including the new
`StrideTest` (21 assertions: scaling in locomotion states, vanilla root
motion in climb/attack states, clamps, clearAll). No live run yet.

## Still open

- AtomUI `getSimpleName` toString error when ISReadABook shows print media
  (JoyPadSetup.lua:151 path); harmless, still logged.
- Live acceptance of 0.4.58/0.4.59/0.4.60 silver chain and stride.
