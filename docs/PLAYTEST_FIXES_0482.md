# 0.4.82: Oct 22 hosted 0.4.81 playtest fixes

Source: hosted (host + child server) test of 0.4.81 on 42.21.0, client
`console-4.txt` (551 KB, complete: first patch line to "GameThread
exited") and `coop-console-5.txt` (2.5 MB, the tail after a wrap), three
screenshots.

## What the consoles showed

### `next()` is nil in the game (server, 2238 throws)

`coop-console-5.txt` opens mid-stream with
`Object tried to call nil in lodgedStep (WTAGarouSilver.lua:468)` repeated
2238 times. Line 468 was `if not lodged or not next(lodged) then`.
Project Zomboid's Kahlua does not expose Lua's global `next` (the mod had
already learned this once, in `WTAGarouWitnessScanner.lua`, and then used
it again in three files). The headless lua5.1 tests have `next`, so they
passed. `lodgedStep` is pcall-guarded, so the sweep continued: scatter
burns and lodging worked, but a lodged fragment's burn never grew and
"silver removed" was never detected.

Fixed in `WTAGarouSilver.lua` (two places), `WTAGarouClient.lua`,
`WTAGarouPawGuard.lua` with explicit `pairs` probes, and
`tests/asset_contract_test.py` now fails on any bare `next(` in mod Lua.

### Invisible scatter tiles: the sprite had no id

`IsoObject.save` writes `sprite.id` (an int), and the `AddItemToMap`
packet that `transmitCompleteItemToClients` sends is that same save
stream. `IsoSpriteManager.getSprite(path)` for an unknown texture path
makes a single-texture sprite with the default id (20000000) that is in no
id map, so every client, and every save reload, resolved it to the empty
sprite `""` and drew nothing. The tile existed (it burned feet, lodged
fragments, answered the right-click), it simply had no picture outside the
process that placed it. The vanilla "Pick up" tool never lists it either:
that tool reads tile definitions, and the object has none.

Fix (`shared/WTAGarouScatterSprites.lua`): the four variants are
registered with fixed ids on BOTH sides, `IsoSpriteManager:AddSprite(path,
id)` then `setName(path)`, from `Events.OnLoadedTileDefinitions` (the
engine fires it with the manager right after loading vanilla and mod tile
definitions) and lazily from `ensure()` before any placement.
`IsoWorld.init` disposes the whole sprite manager before that event, so
"registered" is verified by id lookup each time, never by a Lua flag. Ids
follow the engine's own formula with file number 3000 (786956288..291),
far above vanilla sheets and the 100..999 band mod `.tiles` files use.
Tiles placed by 0.4.77..0.4.81 are repaired server-side the first time
`SC.find` touches them (`setSprite` + `transmitUpdatedSpriteToClients`).

Picking up: right-click the square, "Pick up scattered silver" (gloves or
a burned hand, as before). The ground loot window and the furniture
pick-up cursor will never show it; the Guide page says so now.

PNG placement: the engine draws the whole 128x256 canvas anchored like
every other tile; nothing "targets" the art. Matching the vanilla
broken-glass sheet's placement (art centred, which the user's four PNGs
do: bounding boxes at y 98..159) is exactly right. The 0.4.77 placeholder
had its art low; it is gone.

### "Remove Glass" is instant: vanilla, for the host

`ISRemoveGlass:getDuration()` returns 1 (one tick) when `isMultiplayer()`
and the character's role has `Capability.CanMedicalCheat`; the admin role
the host runs under has it, and it also skips the pain. The mod does not
touch that timer. To test the real hand/tweezers durations, drop the host
to a normal role (`/setaccesslevel <name> none`) or test on the second
PC. The label is the mod's: the body-part menu's vanilla "Remove Glass"
now reads "Remove Silver Fragments" when the part's lodged silver kind is a
shard (post-processed after `ISHealthPanel:doBodyPartContextMenu`, the
handler is a local table in vanilla; the submenu and action are
untouched).

### Health panel: the indented "(bandaged)" line

Vanilla hides wound lines under a bandage, so the mod appended its own
silver line, at `healthPanel:getRight() + spacing` (far right, screenshot
20A61C) with a "(bandaged)" suffix. Now: plain "- Silver Burn" at
vanilla's wound-line x (15); the part already says "- Bandaged" above it.

### Glabro foot scratched barefoot: the loop runs on the server

Vanilla `IsoPlayer.updateFootInjuries()` (random barefoot scratches while
walking/running, broken-glass cuts) is guarded by `!GameClient.client`:
it runs on the server and in single player, never on an MP client. The
mod's `FootInjuryPatch` (client Java, rule 0.4.65) therefore held in SP and
did nothing in the hosted game. The silver burn had no part in it.

Fix (`server/WTAGarouPaws.lua`, called from the body sweep every 10
ticks): a toughFeet form (Glabro, Berzerker, Near-Wolf, Wolf) that is
barefoot and shows a fresh foot scratch or cut (timers <= 3.5, the loop's
first `Rand(1,3)` roll) has it cleared with a console line
`[WTAGarou][Paws] <name> shrugged off a barefoot Glabro on Foot_L`.
Older/bigger foot wounds, feet with lodged silver, burns and glass flags
are never touched.

### Dress

Two things in the client console:

1. Floor items, one per press. Six items were queued from the floor, one
   arrived, the next press queued five, one arrived... `ISGrabItemAction`
   merges back-to-back grabs into one action with a `queueList`
   (`checkQueueList`), and in multiplayer that merged action finishes
   after its first item (`transferItem` -> `ISBaseTimedAction.perform`),
   which is also the "incomplete progress bar on everything" look. Now
   Dress queues ONE floor grab, and queues the next when the previous item
   has landed (or expired after 10 s). An awaited id is never queued twice
   (the doubled "arrived" lines).
2. `missing ids: 1095603344=Base.HoodieDOWN_WhiteTINT` on every press: a
   hoodie toggled hood-down becomes a new item with a new id, so the old
   wardrobe entry can never be found. Three unfound Dress presses now
   forget the entry (notice: "<name> is gone; forgetting it.").

Shoes and socks: both were in the inventory (ids 1516984081 Shoes,
2053263414 Socks_Long) but never in the wardrobe. Dress restores what
Strip or a shift took off; footwear removed by hand (to walk the silver
barefoot) is not remembered. Not a bug, but worth knowing.

### Berzerker still floats on the fence (Java)

0.4.80 compressed the climb arc using the PELVIS lift. The feet rise MORE
than the pelvis while the legs tuck over the fence (feet 0 -> fence top,
pelvis only part of that), so the feet were still drawn scale x too high:
about 0.26 at 1.65 and 0.10 at 1.24, which is "Glabro near perfect,
Crinos still floats a bit". The reference is now the LOWEST FOOT
(`Bip01_L_Foot` / `Bip01_R_Foot`); the pelvis remains the matrix-layout
sanity check and the fallback. The lowest point of the body is what rests
on the fence top (and on the ground before/after), so that is what sits
at vanilla height; the taller body's torso rightly sits higher. The jar
is rebuilt (`ClimbTest` 24 checks).

### Tuning and text

- `Rage.ON_HIT_DEALT` -0.5 -> -0.25 ("don't make Crinos too easy to resist
  in tense combat").
- Glabro shift clothing damage off (`ShiftStrip.FORMS.Glabro.fraction = 0`);
  Strip tooltip, Near-Human tooltip and the vehicle-door share follow.
- Berzerker tooltip: the stale "Too tall for doorways: crouch..." sentence
  is gone; it now ends "...smashes wooden doors (12 Rage, 18 locked) and
  knocks over the first few zombies in its way."

### Not changed, explained

- Scent notices outside the open door: the sniffer's "open to air" test is
  a straight `LosUtil.lineClear` from the player to the source; standing
  off the doorway's axis puts a wall on that line. Through the door it
  fires at once, which matches the report. A path-through-doors variant is
  a later improvement.
- The watch telling time every ten minutes is vanilla.
- The Angus bull appearing on a zombie corpse: nothing from the mod in
  either console; the mod never spawns animals. Likely a 42.21 engine
  issue; worth a vanilla repro.
- Gift of the Wolf Spirit: reading it bumps Gnosis and stores a pending
  gift (`WTAGarouUmbra.lua` stub). Placeholder for the Gnosis roadmap.

## Testing checklist (hosted, both consoles)

Console cap: the Steam launch option `-console_dot_txt_size_kb=102400`
covers the CLIENT only. The hosted child server is a separate JVM whose
command line `CoopMaster.launchServer` builds itself (no pass-through of
the host's options); `GameServer.main` defaults it to 20 MB and reads only
the system property `-Dzomboid.ConsoleDotTxtSizeKB`, which the child never
gets. `LimitSizeFileOutputStream` truncates and restarts at the cap, which
is why `coop-console-5.txt` began mid-stream: the 0.4.81 `lodgedStep`
spam blew past 20 MB. The route that reaches both JVMs is the environment:
Windows user variable `JAVA_TOOL_OPTIONS` =
`-Dzomboid.ConsoleDotTxtSizeKB=102400`, then fully restart Steam. With the
`next()` fix the server log should stay small regardless.

1. Scatter: scatter filings on a square; the tile must be visible to the
   host AND to the second PC; right-click the square -> "Pick up scattered
   silver". Expect `[WTAGarou][Scatter] 4 tile sprites registered, ids
   786956288..786956291` in BOTH consoles at world load. Walk the old
   invisible squares once: `repaired an id-less tile sprite at x,y,z`.
2. Lodged fragments: the server console must have NO `lodgedStep` errors;
   with a fragment lodged, the foot's burn keeps growing; pulling it logs
   the removal. Body-part menu reads "Remove Silver Fragments". Duration:
   test as a non-admin or on PC two.
3. Health panel: bandage a silver-burned part; "- Silver Burn" sits under
   "- Bandaged" at the same indent as other wound lines.
4. Barefoot Glabro outside for a few minutes: no foot scratch survives a
   second; `[WTAGarou][Paws] ... shrugged off` in the server console.
5. Dress from the floor with the loot window open: items go on one after
   another; one "arrived" line per item; no half bars left behind.
6. Fence climb as Berzerker: feet on the fence top at the straddle (the
   client console prints `reference lowest foot`).
7. Rage: a landed hit now costs 0.25; Glabro shift leaves clothes
   untouched; Berzerker tooltip text.
8. Silver smoke bomb (untested so far): pack (1 Smoke Bomb + 10 filings),
   throw; a Garou in the cloud coughs, neck burns, Rage climbs; a gas mask
   blocks it.
