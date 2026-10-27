# 0.4.16 - Dress, Glabro wear, forced-Crinos damage, rip sound

Not verified in game; the Lua suite and the asset contract cover the logic
and the files.

## Wardrobe and Dress

- `shared/WTAGarouWardrobe.lua`: per-player list in mod data
  `WTAGarou_Wardrobe` of `{ id, name, type, source }`, keyed by
  `InventoryItem:getID()`. The engine writes the id with the item and reads
  it back on load (`InventoryItem.load`: `this.id = input.getInt()`), so
  the list survives save/load. Capped at 32; re-recording an id moves it
  to the end.
- Strip records every item it queues an unequip for (`source = "strip"`);
  shift drops record every item they drop (`source = "shift"`), so clothes
  picked back up after a wolf run can be re-worn with one click.
- `client/WTAGarouDress.lua`: prunes entries that are worn again, then for
  each remaining entry, innermost first (Strip records outer layers first),
  looks the item up with `ItemContainer:getItemWithIDRecursiv(id)` (main
  inventory and every nested container). Found in a bag: queue
  `ISInventoryTransferAction` to the main inventory, then `ISWearClothing`
  (the pair the vanilla inventory context menu uses). Missing, broken or in
  a hand: one line in the Garou panel ("Dress: Cap is not in your
  inventory." / "is ruined." / "is in your hands."), and the entry stays for
  the next Dress. Entries are only removed once the item is confirmed worn
  (a wear action that gets interrupted leaves the entry in place).
- Panel: "Dress" button in the second row's third slot, enabled only while
  the wardrobe remembers something; tooltip lists the remembered items one
  per line (innermost first), refreshed once a second. Notice lines (up to
  three, six seconds each) sit under the buttons; the panel grew from 168
  to 204 px. Both radials offer "Dress / N item(s)" while the wardrobe is
  non-empty, with the `wta_dress.png` icon (T-shirt + green check).

## Clothing changes

- Glabro: 0.1 point per shift (`fraction = 0.01`). Condition is an integer
  in the engine, so sub-point wear accumulates in the item's mod data
  (`WTAGarou_Wear`) and costs one real point when it reaches 1: one point
  every tenth Glabro shift. Nothing comes off, no holes, no model reset.
  Set the fraction to 0 to make Glabro free.
- Forced Crinos (100 Rage): `forcedMultiplier = 2` on the Crinos profile,
  applied to points only (8 on a T-shirt), holes stay 3. The server now
  sends `forced` in `TransformCompleted`; the client passes it through to
  `Clothing.dropForbidden(player, form, { forced })`.
- Sound: `ClothesRipping` (registered SoundKey in B42.20.2,
  `zombie/scripting/objects/SoundKey.java`; the B41 rip-clothing recipes
  used the same name, see https://pzwiki.net/wiki/Denim_Strips) plays once
  per shift that actually removes a whole point or tears a hole. A Glabro
  shift that only accumulates wear is silent. Whether the clip is present
  in the B42 sound bank under that name is unverified in game; if it is
  silent, the name to try next is what the debug crafting UI shows for the
  rip-sheets recipe.

## Tests

Lua: stealth/voice/strip 167 (profiles, wear accumulator, forced Crinos,
Wardrobe record/prune/cap, Dress queue order, bag transfer, failure
notices), channel/HUD 593 (Dress button, red Berzerker border, notice
lines, dynamic tooltip, 204 px clamp), rage engine 88 (`forced` flag on
completion); asset contract 195 (dress icon, both radials, new modules).
