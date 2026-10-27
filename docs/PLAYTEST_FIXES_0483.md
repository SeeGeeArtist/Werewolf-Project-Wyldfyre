# 0.4.83: Oct 23 hosted 0.4.82 playtest fixes

Source: hosted (host + child server) test of 0.4.82, client `console-2.txt`,
server `coop-console-3.txt`, screenshot `20A6D3` (scatter tile floating).

Confirmed working in that test and left alone: Dress from the ground with
the loot window open, the silver-burn tag on the health panel, picking up
scattered fragments, tough Glabro feet in multiplayer, scent through an
open door, the shout without the raised hand, the 0.25 Rage hit cost, and
the slower fragment removal once the host's role is `user`.

## Scattered silver floated above the tile

`20A6D3`: the fragments hovered a body height above the floor. The 0.4.82
write-up claimed centred art was correct; it was not. The engine draws a
tile's whole canvas with its top-left at the square's screen point minus
`IsoObject.offsetX/offsetY` = `(32, 96) x tileScale` (`IsoObject.java:207`,
`IsoSprite.prepareToRenderSprite`), and the square's screen point is the
TOP corner of the floor diamond. On a 128x256 canvas the floor diamond is
therefore the bottom 64 rows (192..255, centre at row 224, corners at
(64,192), (0,224), (128,224), (64,256)). Art centred on the canvas (rows
97..159) sits 96 px above the floor.

The four `WTAGarou_SilverScatter_N.png` were shifted down 96 px (bounding
boxes now rows 193..255, horizontally centred). `tests/asset_contract_test.py`
checks every scatter tile's opaque pixels lie within rows 192..255 and are
centred on x = 64 (needs Pillow; skipped without it).

## The server repaired the same tile every 30 frames

`coop-console-3.txt`: `[Scatter] repaired sprite ... at 10636,10272` over
and over. `SC.repairSprite` used `obj:setSprite(path)`; the `String`
overload of `IsoObject.setSprite` builds a NEW sprite with
`IsoSprite.CreateSprite` + `LoadSingleTexture`, which has no id, so the
next `find` saw an id-less sprite and repaired it again. It now uses
`obj:setSpriteFromName(path)`, which resolves through the sprite manager
to our registered id (the constructor `IsoObject(cell, square, path)` also
goes through the manager, which is why fresh tiles were fine).

## Silver smoke: no visual, neck burn, gas mask did nothing

Three findings in one bomb.

1. The gas mask: `SM.masked` called `item:hasTag("GasMask")`. 42.20.2
   exposes `hasTag(ItemTag...)` only, so the call threw "No implementation
   found for function: hasTag(Clothing, String)" inside the pcall, 46
   times a second in the server console, and `masked` was always false.
   The mod learned this in 0.4.19 and violated it again. `SM.itemIsMask`
   now walks `getTags()` and compares names through
   `WTAGarou.Silver.tagKey` (`gasmask`, `improvisedgasmask` protect;
   `gasmasknofilter` does not). `tests/asset_contract_test.py` now fails
   on any `hasTag(` in mod Lua whose argument is not an `ItemTag.`
   constant.
2. The burn: `SM.BREATH_PART` is `Head` (label "face"), not `Neck`. The
   dust is in the eyes and throat.
3. The visual: the engine's smoke-bomb smoke is `IsoFire` objects started
   by `IsoFireManager.StartSmoke`, which `IsoTrap.drawCircleExplosion`
   starts only on a FireStartingChance roll, and which multiplayer clients
   do not own; the short-sight blur is a private field with no setter. So
   the impaired vision is drawn by the mod: `client/WTAGarouSmokeVeil.lua`
   is a mouse-transparent, back-most `ISUIElement` covering the screen
   with a pale silver haze and a six-band dark vignette (alpha 0.82 at
   full), rising in about half a second and clearing over about three
   seconds once the server stops saying the player is in the dust. The
   server now sends the `SilverSmoke` command EVERY body sweep while the
   player stands in a cloud (`{ seconds, cough }`); the client keeps the
   veil up on every message and plays the cough halo/voice/log line only
   when `cough` is true (the previous 6 s cadence). Messages without the
   flag are treated as coughs for older servers.

## Fence climb: hands, not feet

The user: "the foot is probably the wrong bone to measure height for the
fence climb correction. The height should probably be measured by one of
the hand bones since they are supposed to be aligned with the fence. The
foot bone correction on crinos is unreliable ... it bobs up and down while
the legs kick for purchase on the fence."

Both earlier rules measured a LIFT relative to the first climb frame
(0.4.80 pelvis, 0.4.82 lowest foot). That had three faults: the standing
hand height stayed scaled (1.65 x 0.9 = 1.5 above a 1.0 fence, so the
hands could never reach the rail), the rest frame depended on which blend
frame the climb state was entered on (sometimes right, sometimes high),
and the lowest foot changes every time the legs alternate (the bob).

`ClimbRuntime` (Java) now uses the mean height of `Bip01_L_Hand` /
`Bip01_R_Hand` measured from the ground: `dy = -hand x (1 - 1/scale)`,
clamped so the lowest foot never goes below the ground (`dy >=
-lowestFoot`) and never positive. After FinalScale the hands draw at
exactly the vanilla height, i.e. on the fence top, window sill or wall
top. Feet planted: no offset. Feet lifting: the body comes down until the
hands rest on the rail. Legs kicking with the hands planted: constant
offset, no bob. Landing feet bring the offset back to zero through the
clamp. Rigs without hand bones fall back to the 0.4.82 foot lift.
`java/test/ClimbTest.java` covers the straddle, four alternating kicks
with an unchanged pelvis, one hand off the rail, the landing and Glabro
through a window (48 checks).

## Workshop-release audit (same day)

Preparing the Steam Workshop item turned up one more fix and one blocker;
both are written up in `docs/WORKSHOP_RELEASE.md`:

- Fix: the server's `Debug*` commands and GrantItems accepted any role but
  `"None"`. Build 42's default role for every player is `user`, so any
  player could set their Rage or grant items. Now `WTAGarou.Access.privileged`
  (AddItem capability / single player / -debug). `tests/access_test.lua`.
- Blocker: the Lupus/Hispo wolf (Tame-able Wolves), the Crinos legs/tail
  (RabenRabo) and the saddlebags (Horse Mod) ship donor files whose authors
  forbid or have not granted redistribution. `workshop/THIRD_PARTY_ASSETS.md`
  tracks the requests; `tools/check_workshop_staging.py --public` refuses
  until they are recorded.

## Tests

- `bash tests/run.sh` (adds `tests/smoke_veil_test.lua`).
- `python3 tests/asset_contract_test.py "$PWD"` (adds the scatter-tile
  placement checks and the `hasTag` guard).
- `cd java && bash build.sh && bash test.sh`.
