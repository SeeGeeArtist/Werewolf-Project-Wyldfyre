# 0.4.66: multiplayer item ownership (first hosted playtest)

First hosted game, Oct 16: host PC (debug, 0.4.65) plus a Steam Deck
client, game 42.21.0. Report: the raw-nitrate mix channel completes and
nothing happens; nothing can be equipped; the vanilla debug menu pops up
on its own in Crinos and cycles professions.

## What the logs show

Host client:

- `[WTAGarou][Debug] silver kit`, `Firearm kit: 253 items added` and the
  wearable kit, all through `inventory:AddItem` on the client.
- `[WTAGarou][Dress] 3 queued item(s) still not worn after 8s in Glabro
  ... queue idle=false`: the action queue never drained.
- Flood: `expected argument of type ResourceLocation, got String` from
  `WTAGarouAdapters.lua:169` (`CharacterTrait.get(name)`) on every witness
  scan while in Crinos. The call was inside a pcall; Kahlua prints the
  trace anyway.
- Eight `attempted index: getInputs of non-table: null` from
  `reportRecipeDrift`: `getCraftRecipe("WTAGarou_CoatSilverNitrate")`
  returned nil on 42.21.

Server (coop-console):

- Three `ISDropWorldItemAction.getDuration ... getActualWeight of nil`
  inside `NetTimedAction.parse`: the server rebuilt a client's drop action
  and could not find the item.
- No mod errors; `[WTAGarou] Net loaded. singlePlayer=false`, handler
  registered. The server also runs the shared Rage engine for each
  connected player, which is expected.

## Why

Build 42 multiplayer inventories are **server-owned**. A timed action is a
transaction: the client sends the action type and its arguments, the
server looks every item up by container and id in *its* copy
(`PZNetKahluaTableImpl.loadInventoryItem`), calls `Type.new(...)` with what
it found, and answers Accept or Reject (`NetTimedActionPacket`). The
action's `complete()` runs on the server in MP (vanilla
`ISDropWorldItemAction`, `ISUnequipAction` branch on `isServer()`).

An item created on the client with `AddItem` is not in the server's copy.
Equip, wear, drop and craft on it are all rejected; the recipe channel
plays on the client and the server has nothing to perform. Vanilla's item
spawner does `SendCommandToServer("/additem ...")` in MP for exactly this
reason (`ISItemsListTable.lua`).

The same ownership breaks two other client paths:

- Shift strip (`Clothing.dropForbidden`) did `removeWornItem`, `Remove`,
  `AddWorldInventoryItem` on the client. The server kept believing the
  shirt was worn; the floor item did not exist for it; picking it up was
  rejected.
- Nitrate warming is client Java (`NitrateHeatRuntime`). A hosted or
  dedicated server has no Java (0.4.65), yet it owns the jar and performs
  the coat recipe, so for the server the mix never finished.

## Changes

### `WTAGarou.Grant` (shared `WTAGarouGrant.lua`, server `WTAGarouGrantServer.lua`)

The one way the mod creates items:

```lua
local batch = WTAGarou.Grant.begin(player, "silver kit")
WTAGarou.Grant.add(batch, "Base.Fertilizer", 1)   -- SP: created now, returned
WTAGarou.Grant.commit(batch)                        -- MP client: one GrantItems command
```

Single player and the server create on the spot (plus
`sendAddItemToContainer` on a server). A remote client only queues and
`commit` sends `GrantItems {reason, items={ {type,count} }}`; the server
creates, syncs, and answers `GrantItemsDone {added, missing}` which the
client prints, notes in the test panel and pushes to the Garou panel.
Policy on the server: a debug server (a hosted game inherits the host's
`-debug`) grants to everyone; otherwise any access level above None. Caps:
200 entries / 600 items per request.

All five debug kits use it (silver wearables, silver crafting kit, firearm
kit, gear kit). The firearm kit reads ammo and magazine types from a loose
`instanceItem` probe because the granted gun is not in hand yet on a
remote client.

### Server strip

`WTAGarouServer.lua` `serverStrip(player, target, forced)`: on a real
server, when a shift lands (channel or DebugSetForm), the server runs
`Clothing.dropForbidden` itself and attaches the result to
`TransformCompleted.strip = {dropped, damaged, tore, forced, modelChanged,
wardrobe}`. `Clothing.dropItem` on a server follows vanilla
`ISDropWorldItemAction.complete`: `removeWornItem`, hands cleared +
`sendEquip`, `AddWorldInventoryItem(..., false)` +
`transmitCompleteItemToClients`, `Remove` + `sendRemoveItemFromContainer`.
Condition damage pushes `sendItemStats`; torn models push `syncVisuals`
once. The remote client no longer strips; it calls
`Clothing.presentStrip(player, args.strip)` for the rip sound, model reset,
test-panel line, and merges `strip.wardrobe` into its Wardrobe
(`Wardrobe.recordEntries`) so Dress still finds the dropped items. Single
player is unchanged (client strips and presents in one go).

### Nitrate warming report

`NitrateHeatRuntime`: a remote client (`GameClient.client` and not server)
is the authority for its vessels: it warms and converts at the server
rates and queues each converted vessel once (`pollNitrateCooked`). Client
Lua `WTAGarouNitrateSync.lua` polls every 20 ticks and sends
`NitrateCooked {item, raw, done}` (absolute litres; the item travels as a
container+id reference). Server `WTAGarouNitrateServer.lua` applies it
through `SilverAmmo.applyNitrateReport`, which refuses a report that adds
raw mix, changes the vessel's total, or targets a vessel without nitrate,
then `sendItemStats(item)`. A repeated report is a no-op, so two clients
near the same campfire cannot double anything.

### Console floods

- `Adapters.traitByName(name)`: `CharacterTrait.BRAVE`-style static field
  first, then `CharacterTrait.get(ResourceLocation.of(name))`, cached,
  never a bare string.
- `SilverAmmo.findCraftRecipe(sm, name)`: `"WTAGarou."..name`, then the
  bare name, then a walk of `getAllCraftRecipes()` by script object name;
  `recipeItemSet` nil-checks before `getInputs`.

## Not changed, known

- Corpse carry (`CorpseCarry.stow`) still does a client `AddItem`; MP
  behaviour unknown, low priority.
- Silver bookkeeping on items is client mod data; the server does not see
  coat charges (0.4.62 note stands).
- Dress / Strip buttons already use vanilla actions and are fine in MP.
- The "debug menu" in Crinos (resolved by the screenshots): it was the
  vanilla **Lua Debugger** (F11 in debug mode) with **Break On Error**
  ticked. It stops the game on every Lua error, and the error was the
  `CharacterTrait.get("Brave")` string call from `isBrave` on each witness
  scan; the "professions" scrolling past were the `BRAVE_TRAITS` names
  (Brave, Fearless, Cop, Veteran, SecurityGuard) in the debugger's object
  stack. Fixed by `traitByName` above. For playtests, untick Break On
  Error in that window; any remaining vanilla or mod error still goes to
  the console.
- Deck "connection failed" (resolved by the Deck's console history):
  `Failed,NotInvited` five times, then `Connected`. The hosted game only
  admits Steam friends the host invited (or players on the whitelist);
  not a mod issue. Once connected, the Deck loaded 0.4.65 with Java and
  saw the host's Crinos cosmetics (head mount, body texture) correctly.

## Tests

- `tests/multiplayer_items_test.lua` (56): SP creates directly; remote
  client sends one command and creates nothing; server denies None on a
  non-debug server, grants admins, grants everyone in debug, caps; server
  strip uses the networked drop path, ships Wardrobe entries, never calls
  the client model reset; client presents the summary; nitrate reports are
  bounded and idempotent; `flush` skips non-containers; trait lookups never
  pass a string; recipe found under the module name or by walking.
- `NitrateHeatTest` 44: remote client converts at the server pace, queues
  each vessel once, poll drains, single player never queues.
- Lua suite 32 PASS, Java all PASS. Version 0.4.66.

## What to check live

1. Pull, run `tools\sync_mod_folder.bat`, update the Deck's copy (real
   directory, not a symlink), host again.
2. Silver kit from the test panel: console should print
   `[WTAGarou][Grant] silver kit: N item(s) placed in your inventory by the
   server`; then equip a kit weapon.
3. Mix raw nitrate (fertilizer or cold pack): the vessel should fill on
   both screens. Warm it in a campfire; the server console should print
   `nitrate warmed on the server`. Then coat.
4. Shift to Crinos while dressed: clothes drop for everyone, Dress picks
   them back up in Homid.
5. Send both consoles (PC and Deck) and a screenshot of the panel that
   appears in Crinos.
