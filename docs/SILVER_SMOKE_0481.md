# 0.4.81: silver smoke bomb, scatter tile variants ("Home Alone", part 2)

Halloween focus (user, Oct 21): multiplayer + silver traps, then the
Workshop. Snares and pet flaps are shelved; scatter and the smoke bomb are
the two traps that ship.

## Scattered silver: the user's tile art

`common/media/textures/WTAGarou/WTAGarou_SilverScatter_0..3.png` (128x256
iso tiles, committed by the user as "silver scatter texture and variants").
`WTAGarou.Scatter.SPRITES` lists them; `spriteFor(x, y)` hashes the square
so every client and every reload draw the same variant on a given square,
and neighbouring squares differ. `find()` still goes by mod data, so the
sprite is purely cosmetic. The engine makes a single-texture sprite from a
texture path (`IsoSpriteManager.getSprite -> AddSprite -> LoadSingleTexture`;
`getTextureForFrame` falls back to that texture when a sprite has no
frames), which is how the 0.4.77 tile rendered.

## Silver smoke bomb

- Item `WTAGarou.SilverSmokeBomb`: a line-for-line copy of the 42.20
  `Base.SmokeBomb` (PhysicsObject ExplosiveTrap, SmokeRange 5,
  ExplosionDuration 10, Throw anim, SmokeBomb sprite/model), tag
  `WTAGarouSilverSmoke`. Thrown, landed, timed and smoked by the engine like
  the vanilla bomb; zombies in it lose their target as usual.
- Recipe `WTAGarou_PackSilverSmokeBomb` ("Pack Silver Filings into Smoke
  Bomb"): one vanilla Smoke Bomb + 10 uses of Silver Filings (half a
  fragment), 40 ticks, any surface, no skill or magazine (the vanilla bomb
  itself still needs its magazine).
- Dust (`server/WTAGarouSilverSmoke.lua`): the engine explodes traps on
  the server (SP: locally) and fires `OnThrowableExplode(trap, square)`;
  for our item a cloud is kept: centre, floor, radius = SmokeRange, expiry
  = ExplosionDuration game minutes (the window during which IsoTrap keeps
  refreshing its smoke squares). A square is in the dust when it is on the
  cloud's floor, within the radius and `LosUtil.lineClear` from the centre
  is not Blocked / ClearThroughClosedDoor: the test IsoTrap itself uses to
  decide which squares get smoke, so dust = visible smoke.
- Breathing it (every server body sweep via `Silver.scan`, 0.4.75 rules):
  a silver burn on the Neck (the throat; blocks regeneration and shows in
  the health panel like every silver burn), `RAGE_PER_SECOND` 0.4 Rage,
  a cough cue every `COUGH_GAP` 6 s (server command `SilverSmoke` ->
  `WTAGarou.SilverSmokeReact`: vanilla "Cough" voice, silver halo, log
  line), and the sniffer smells the dust to `SCENT_EXTRA` 2 squares past
  the smoke edge. A worn item with the vanilla `GasMask` tag keeps it out.
  Humans are not Garou and breathe ordinary smoke. Every form breathes.
- Tooltip line on the bomb: "Silver dust: werewolves breathing the smoke
  burn and rage." Test kit (`/garou silver`): 2 Smoke Bombs, 2 Silver Smoke
  Bombs, 2 Silver Filings.

Not done on purpose: no custom smoke colour (the engine's smoke is a shared
IsoFire object), no effect on zombies beyond vanilla, no breath-holding.

## console.txt: why the file was only the tail

42.20.2 writes `console.txt` through `LimitSizeFileOutputStream` with
`Core.consoleDotTxtSizeKb` = 5120 (5 MB) by default: when the cap is hit the
file is truncated and restarted, so a session that spams an exception every
frame leaves only what came after the last restart. The cap is settable
between 512 and 102400 KB:

- Steam launch options: `-console_dot_txt_size_kb=102400`
- or the JVM property `-Dzomboid.ConsoleDotTxtSizeKB=102400` (in the
  `ProjectZomboid64.json` / `.bat` vmArgs).

With 100 MB the whole session fits. The `logs/` zip the game makes at the
next start (`logs_<date>.zip`) holds the same capped file.

## Tests

- `tests/silver_smoke_test.lua` (46): item/recipe/translation shape, only
  our item makes a cloud, radius/floor/LOS/closed door/open door, scent
  reach, throat burn + flag + single announcement, Rage per second, cough
  cadence, human untouched, outside untouched, gas mask vs bandana,
  Silver.scan hook, expiry.
- `tests/scatter_test.lua` (94, +10): four variants used, deterministic per
  square, each PNG present and 128x256.
- Lua 38 PASS, Java 27 PASS (unchanged jar logic; banner 0.4.81).
