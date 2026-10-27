# 0.4.74: the nitrate that never cooked (October 19 hosted test)

## What the console showed

Host client, 0.4.73, glass bottle of raw nitrate in a stove:

```
[WTAGarou][Silver] watching a stove with raw silver nitrate (simulated at any distance while loaded)
[WTAGarou][Silver] nitrate vessel warming in a stove (temp 1.62): 1.00 L raw
```

So discovery, the watch list and the warming simulation all ran, the stove
was above the 1.6 boil threshold, and reports were being sent. The bottle
still read raw after 35 game minutes.

## Root cause

The report carried the bottle itself (`args.item = item`). A client command
table is serialized by `zombie/network/TableNetworkUtils.java`; an
`InventoryItem` value is written as a full copy (`saveWithSize`) and read
back on the server with `InventoryItem.loadItem`. The server therefore got a
brand-new, detached bottle, converted ITS fluid, and pushed `sendItemStats`
for an item that is in no container. The real bottle in the stove was never
touched. Single player hid this: there `Net.ToServer` calls the handler
directly with the live object.

Vanilla never sends items; `server/ClientCommands.lua` sends `itemID` and,
for world containers, `x, y, z, index, containerIndex`, then resolves with
`getCell():getGridSquare` -> `sq:getObjects():get(index)` ->
`getContainer()/getContainerByIndex(ci)` -> `cont:getItemWithID(id)`.

## Fix

- Client (`WTAGarouNitrateSync.lua`): every report now carries
  `S.locateVessel(item, cont)` = `{ id, x, y, z, index, containerIndex }`
  and, in multiplayer, no item object at all.
- Server (`WTAGarouNitrateServer.lua`): `NSrv.resolve` ignores `args.item`
  on a server and uses `S.findVessel` (named object, then every container on
  the square, then the player's own bags). Not found is logged as
  `nitrate report: vessel id N not found at x,y,z`.
- `tests/multiplayer_items_test.lua`: locator shape, multiplayer report has
  no object, server resolves the live bottle and ignores a detached copy,
  wrong object index still found by square search, unknown id -> nil.

What you should see now: the client lines as before, then on the SERVER
console `nitrate warmed on the server ...` and the bottle's tooltip turning
to silver nitrate over about ten game minutes at a boil.

## Kit: a jar of finished nitrate

`/garou silver` (and the test panel's Silver kit) now adds a SECOND jar
that already holds a litre of finished silver nitrate (five coats), next to
the empty one for the mix/cook chain, so coating and silver-strike tests
never wait on the cooking step. `WTAGarou.Grant.add` takes an optional
`fluid = { name, litres }`; only this mod's fluids, clamped to 5 L and the
vessel's capacity, filled where the item is made (single player or the
server, before `sendAddItemToContainer`), so a hosted game's client receives
it already full.

## Other notes from the same session

- Stove temp 1.62 just above 1.6: `IsoStove` ramps its temperature up after
  it is switched on; it keeps climbing, so warming is not borderline.
- "My PC wasn't up to date": right, the earlier 0.4.71/0.4.72 fixes never
  ran on the host. Sync the repo folder to `mods/` on BOTH machines before
  the next test.
- The Lua console that opens when the dress key is pressed is the vanilla
  debug-mode Lua console keybind, not this mod; the console errors in the
  log (`roomtones.lua:1 Object tried to call nil`) are text typed into it.
- The server shutdown is not visible from the client console; it needs the
  server's own console (`server-console.txt` / the Logs zip).
