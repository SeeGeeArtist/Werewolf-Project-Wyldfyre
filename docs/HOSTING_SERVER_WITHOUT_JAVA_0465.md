# 0.4.65: the hosted server runs without Java (second "Terminated")

Second host attempt on Oct 16, after the junction was replaced by a real
folder (see HOSTING_JUNCTION_CHECKSUM.md). The server got further: all
Lua loaded (`[WTAGarou] Definitions loaded - version 0.4.64`, `Net loaded.
singlePlayer=false`, `Server command handler registered`), then still
terminated during Loading World.

## What the log says

```
GameServer.main> Exception thrown
java.lang.Exception: Tag has no items: wtagarou:coatable.
    line: item 1 tags[wtagarou:coatable] mode:keep
    at InputScript.OnPostWorldDictionaryInit(InputScript.java:956)
...
World loading could not proceed, there are script load errors.
Server Terminated.
```

## Why

The co-op server is a separate Java process that the host client starts
(`CoopMaster.launchServer` builds the command line itself: `java -Xmx...
-Djava.class.path=... zombie.network.GameServer`). ZombieBuddy is injected
into the client by a JVM agent flag; that flag is not on the child's
command line, so **the server has no ZombieBuddy and no WTAGarou Java at
all**. The server console confirms it: not a single `[ZB]` or
`[WTAGarou Java]` line. (Even a dedicated server with ZombieBuddy installed
would skip our jar, because `mod.info` declares it under
`media/java/client/`.)

`CoatableTagRuntime` is the only part of the mod that scripts depended on:
it tags every metal melee weapon `wtagarou:coatable` / `wtagarou:forgeable`
when the item scripts load, and the coat and forge recipes used those tags
for their weapon slot. With no Java the tags are empty, and
`InputScript.OnPostWorldDictionaryInit` treats an empty tag as a fatal
script error. In single player the client's Java always ran first, which
is why this never showed up in solo playtests.

The server cannot be left out either: `ISHandcraftAction` performs the
recipe **on the server** in multiplayer (`if not isClient() then
self:performRecipe()`), with the server's own script data, so the server
must know exactly which weapons the slot accepts.

## Change

Both weapon slots in `silver_recipes.txt` are now explicit, generated item
lists (no Java anywhere in the chain):

- Coat (`WTAGarou_CoatSilverNitrate`): `item 1 [192 weapons]
  tags[HasMetal;Sharpenable;SmeltableIron*;SmeltableSteel*] mode:keep`.
  `InputScript` unions the `[items]` list with the tag items, so metal
  weapons newer than the list still qualify; `OnTestCoatInput` already
  refuses every non-weapon the metal tags drag in (foil, cans, bulbs), and
  it runs on the client and on the server.
- Forge (`WTAGarou_SilverWeapon`): `item 1 [184 weapons] mode:keep`, list
  only. A tag union would put hammers back into the weapon slot, which
  0.4.63 removed on purpose so a forge tool can never be picked as the
  weapon.

`tools/gen_coatable_lists.py <media/scripts> [--extra A;B] --write`
produces the lists with the same rule as `CoatableTagRuntime.decide`
(melee weapon, not ranged, MetalValue > 0 or HasMetal/Sharpenable/
Smeltable* tag or carving fork / ice axe by name, not DisplayCategory
Material, nothing silver) and writes them under the two `GENERATED`
markers.

The reference scripts available here predate 42.20.2 (they have the
smithing hammer *head* but not the hammer), so the lists are a baseline.
The client still tags items with the Java rule, and new
`WTAGarouSilverAmmo.reportRecipeDrift` compares that against what the
recipes accept, once per session at OnGameStart and with the silver debug
kit:

```
[WTAGarou][Silver] coat recipe drift: N rule-coatable item(s) missing from the coat list [Base.X;...]; M missing from the forge list [...] -> tools/gen_coatable_lists.py --extra
```

Paste that line and the lists get regenerated with `--extra`. The coat
recipe is already covered for most of those through the tag union; the
forge list is the one that benefits.

`CoatableTagRuntime` itself is unchanged (tags still applied on clients,
`coatableStatus` still reports), it just no longer gates a recipe.

## Also in 0.4.65: cold packs as a nitrate source

`WTAGarou_PrepareSilverNitrate` now takes `item 2 [Base.Fertilizer;1:Base.Coldpack]`:
two uses of a fertilizer bag **or one instant cold pack** (its filling is
ammonium nitrate; with battery acid that is the classic nitric-acid
route, same as the NPK path). `1:` is the engine's per-item amount
prefix. Tutorial page, Steam description and the debug kit (two cold
packs) updated.

## Tests

- Lua `silver_ammo_test` 205 (was 174): no recipe input depends on a
  Java-added tag; coat line = list ∪ metal tags, forge line = list only;
  hammers/file coatable but not forge weapons; machete, hunting knife,
  crowbar, carving fork, ice axe, katana in both; fragments, fertilizer,
  pistol, shotgun, stone axe, plank, foil, can, bulb in neither; drift
  report names a missing sword, says "none" once the lists include it,
  degrades to "not measurable" without a registry or script manager.
- Lua suite 31 PASS, Java suite all PASS. Version 0.4.65 everywhere.

## What to check live

1. Host again: the server should pass Loading World and reach
   `UI_ServerStatus_Started`. If it terminates, send `coop-console.txt`.
2. Console on the host client: `[WTAGarou][Silver] coat recipe drift: ...`.
   Send that line; it tells which weapons the baseline lists miss.
3. In the hosted game, coat a weapon and forge one (the forge needs
   Blacksmith); both are server-performed in MP now, which is the first
   time that path runs.
4. Still open for MP, not fatal: the raw nitrate warming
   (`NitrateHeatRuntime`) is client Java; in a hosted game the server owns
   container items, so the jar may cook instantly or not at all. Report
   what you see.
