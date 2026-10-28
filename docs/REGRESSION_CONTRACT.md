# Shifting and HUD regression contract

## Current follow-up: 0.4.83 (Oct 23 hosted playtest)

Write-up: `docs/PLAYTEST_FIXES_0483.md`.

- Crinos legs and tail (0.4.90/0.4.91): see the 0.4.67 section; everything
  about the parts is generated (`tools/build_crinos_parts.py`), nothing
  third-party. 0.4.91: the legs are UV-mapped on the VANILLA body atlas
  (leg islands + foot strips, claws on the author's claw dot at texel
  161.5/72.5 and its mirror), so `crinosLegs` is the coat's CrinosBody
  sheet again and there are no CrinosLegs_<Coat>.png files. The generated
  mesh is a BASE for the author's Blender sculpt: keep its UV islands and
  bone weights when re-exporting.
- Forced 0-Rage revert sound (0.4.92): `onForcedHomid` plays the bed and
  immediately runs the completed-channel end (bed fades 1 s under the
  `CHANNEL_END` whoosh). `FORCED_HOMID_SECONDS` > 0 delays the end instead,
  driven from `SS.update`; default 0.
- Crinos legs mesh (0.4.92): low-poly on purpose, 8 sides, rings only at
  anatomical landmarks (`LEG_RING_TS`), flat-shaded (unwelded, face
  normals), 924 triangles for both legs; knee front about +0.05, hock back
  about -0.10 (the envelope measured off the author's reference export).
  Do not smooth or subdivide it back into a tube. 0.4.93: the paw body is
  part of the leg loft (spline points 10-11, `PAW_T0`); four knuckled,
  asymmetric toes (III/IV long and forward, II/V short and back) rise to a
  knuckle above the paw top and slope to the ground; claws are ~7 mm
  wedges off the toe tips, UV'd on the claw dot, toes UV'd on the fur just
  above it (never on the dot). Hamstring stops above the knee, popliteal
  fossa hollowed, shin front straight under the cap. The author remodels
  the legs from this base in Blender; keep UVs and vertex groups.
- 0.4.94 Crinos parts are UNISEX and the author's own Blender models:
  `WTAGarou_CrinosLegs.glb` / `WTAGarou_CrinosTail.glb` (no `_M`/`_F`).
  Java `LEGS_MESH`/`TAIL_MESH` carry no sex suffix; `preloadParts` keeps
  its female flag for the Lua call signature and ignores it. The tail is
  UV-mapped on the WOLF atlas, so `crinosTail` is the coat's `Wolf_<Coat>`
  PNG (Java `valid(name,"Tail")` accepts `WTAGarou_Wolf_*`); no
  CrinosTail_<Coat> PNGs. `tools/build_crinos_parts.py` refuses to
  overwrite a GLB it did not generate (writes `.base.glb`, git-ignored)
  unless `--force`.
- Silver smoke (0.4.94): the dust burns the Head AND Neck parts
  (`SM.BREATH_PARTS`), announced once as "face and throat".
- Smoke veil (0.4.94): the vignette is `media/ui/WTAGarou/smoke_vignette.png`
  (512 px radial alpha, clear centre, solid by the edges) stretched over
  the screen with `drawTextureScaled`, tinted `V.EDGE`, at `alpha*0.98`;
  `MAX_ALPHA` 0.90. The ring fallback (14 bands over 48% of the short
  side, quadratic falloff) draws only when the texture is missing.
- `/garou sex` / test-panel "Swap sex (SP)" (0.4.94): flips the descriptor,
  `setFemale`, `resetModelNextFrame`, `Visual.refresh(player,true)`.
  Single player only; refused when `isClient()` (server owns the body).
- Server modData guard (0.4.95, `WTAGarouState.GetData`): on the server
  (`isServer()`), the WTAGarou table handed out for a player object is kept
  in a server-side map and re-pointed into `player:getModData()` whenever
  the table there is a different one. Vanilla `ISHotbar:savePosition()`
  calls `player:transmitModData()` on every hotbar refresh (each clothing
  change) and the server-side packet load replaces nested tables, so the
  server's state (crinosCountdownAt, resist timers, pendingForm, witnesses,
  crinosHeldSeconds...) was swapped for the client's RageSync mirror about
  once a second while stripping ("the timer kept resetting", Oct 26).
  Counted in `WTAGarou.ModDataClobbers`, logged for the first three and
  every 100th. Rule: the server never adopts a replaced table for a player
  object it has already served; `WTAGarou.ForgetServerData(player)` drops
  the entry. Clients and single player are unchanged.
- Seat compensation (0.4.95, `ClimbRuntime`): `PlayerOnBedState` and
  `PlayerSitOnFurnitureState` are both SITTING poses (resting on a bed
  sits on the mattress edge, feet on the floor - author's correction).
  The hook uses the PELVIS as the reference: want = -pelvisY (1 - 1/scale)
  would seat the pelvis at vanilla height, floor = -lowestFootY would keep
  the feet on the ground; a scaled body cannot have both, so the offset is
  the midpoint, with the drawn foot sink capped at `MAX_SINK` 0.08 m
  (Glabro: ~5 cm float / ~5 cm sink; Crinos: cap binds, 8 cm sink).
  `PlayerSitOnGroundState` is untouched. The pelvis-height sanity check is
  skipped for seats.
- Patch preload (0.4.98, `Main.main`): every `@Patch` target class is
  loaded before ZombieBuddy installs the advice, so load order (first mod
  pass at startup vs. after the main menu) no longer decides which patches
  apply. `PatchTargetsTest` fails when a new `@Patch` target is not in
  `Main.PATCH_TARGETS`. Expect `patch targets preloaded=N/N` in the console.
  See docs/PATCH_PRELOAD_0498.md.
- ZBS signing (0.4.97, `tools/sign_jar_zbs.py`): keygen/sign/verify for the
  ZombieBuddy sidecar `WTAGarouVisuals.jar.zbs` (Ed25519 over
  `ZBS:<SteamID64>:<sha256>`, three-line file, mirrors `ZBSVerifier`).
  Private key lives outside the repo (`~/.zbs/`); `workshop/ZBS_PUBLIC_KEY.txt`
  and `workshop/ZBS_STEAMID64.txt` are committed once the author signs. The
  staging checker verifies the sidecar against the jar (stale = failure,
  missing = warning). Every jar rebuild needs a re-sign by the author.
- Release copy (0.4.97): `42/mod.info` `description=` and
  `workshop/workshop.txt` carry the same one-paragraph summary;
  `workshop/STEAM_PAGE.bbcode.txt` is the full page (checker fails above
  8,000 characters); the trait text (`UI_trait_GarouDesc`) and the Werewolf
  Guide (10 pages: Startup "Who you are" second, "Paws, jaws and vehicles"
  fourth) describe shipped behaviour only. Dormant systems (witnesses,
  Infamy, Hunters, NPC-Garou tagging) are never advertised. Form
  descriptions stay one or two short sentences. `stage_workshop.bat`
  refreshes the staged `workshop.txt` only while its `id=` is empty.
  `publish_source_snapshot.sh --reset-history` makes the public repo a
  single-commit history (pre-0.4.90 snapshots held replaced donor files).
- Low-fence hop (0.4.96, `ClimbRuntime.hopOffset`): `ClimbOverFenceState`
  is only ever the hoppable fence (tall fences/walls are
  `ClimbOverWallState`, windows `ClimbThroughWindowState`). In the hop the
  hands swing above the rail while the feet pass over it, so the 0.4.83
  hands rule pulled the feet scale x further below the hands and through
  the rail. The hop reference is the LOWEST FOOT, measured from the ground:
  dy = -foot (1 - 1/scale), never positive, no rest frame. Walls and
  windows keep the hands rule (confirmed correct in play). `ClimbTest`.
- Wolf climb arc (0.4.96, `WolfPlayerClips.liftRoot`): a climb/fence/window
  action plays a wolf pose with no vertical arc (Wolf_climb or the idle),
  so Lupus/Hispo glided through the rail. The derived clip adds the human
  clip's rise (summed Y of `Bip01` + `Bip01_Pelvis` above their first key,
  never negative, x `climbArcGain` / renderScale) to the wolf root and
  inserts root keys at the human key times. Rises under 0.02 m are
  ignored; gaits/transitions/attacks never get it; root X/Z stay held.
  Logged `[WTAGarou Java][Gait] wolf climb arc: ...` for the first three.
  `WolfPlayerClipsTest`.
- Saddlebags (0.4.89): `WTAGarou_Saddlebags.glb` + `.png` + `_Camo.png` are
  generated by `tools/build_saddlebags.py` (own work; the Horse Mod FBX and
  textures are gone from the tree and must not come back - their licence
  forbids redistribution and a "modified" copy is still their derivative).
  The generator keeps the donor's measured footprint (x +-0.24, y -0.24..0,
  z +-0.08 before the script's 0.6) so the tuned placement (scale 0.6,
  rotate 90 0 180, WTAGarou.Saddlebag offsets, Bip01_Spine2) is unchanged.
  Edit the generator and re-run it; do not hand-edit the GLB.
- Sound levels (0.4.88): the author masters the WTAGarou_*.ogg files, so
  game logic no longer turns them down: `Audio.MAX_VOLUME` (Lua) and
  `StealthRuntime.MAX_VOLUME` (Java) are 1.0 (were 0.75 since 0.4.40),
  `CHANNEL_END_GAIN` is 1.0, every own clip in `wtagarou_sounds.txt` is
  `volume = 1.00`. Exceptions: Crinos footsteps 0.45 (author's call) and the
  wolf channel voice at `WOLF_VOICE_GAIN` 0.4 (0.4.86 request). The Sound
  Effects slider still scales every handle. Wolf_Mod cues are unchanged.
- Shift sounds (0.4.86, third pass): voice size comes from a formant shift
  larger than the pitch shift (`build_set.voice_fx`: Crinos formants -5 st /
  pitch -3 st, Hispo -3/-2) plus a low shelf and a quiet sub-octave layer; NO
  room on any voice (the game adds its own). Wolf channel voice = the current
  form's growl (`SilverCue.BY_FORM`) at `WOLF_VOICE_GAIN` 0.4;
  `WTAGarou_WolfShiftStart` is gone. On completion the bed and the voice ring
  1 s under the whoosh (`CHANNEL_FADE_SECONDS`), cancel = 0.2 s
  (`CANCEL_FADE_SECONDS`). `WTAGarou_HispoBark` has three clips. Lupus bark
  is Freylith's trimmed by the author; the footsteps are the author's edits -
  `build_set.py` does not rebuild either.
- Reset identity (0.4.85): `RageSyncArgs` sends `identityLocked` and
  `auspiceLocked` as explicit booleans. A nil key is absent on the wire, so
  the 0.4.39 `DebugResetIdentity` cleared the server copy but the client's
  startup panel stayed locked until a relog (Oct 24 playtest).
- Shift sounds (0.4.85, second pass after the Oct 24 playtest): no pitch or
  time processing, no saturation or synthetic voice layers; right channel as
  recorded when the left is hot (never scaled past unity - the 0.4.84 set
  scaled it by the L/R ratio and clipped); peaks <= -2 dBTP. Human channel
  voice uses the vanilla discomfort/strain events (`PainMoodle`,
  `CorpseHighEffort`, `Exercise`, `CorpseLowEffort`, `PainFromHitBlunt`), not
  the wound screams. Countdown = breathing only, deep-well reverb, fades to
  silence before the 10 s mark. Footsteps high-passed at 75 Hz.
- Shift sounds (0.4.84, pending playtest): all 20 `WTAGarou_*.ogg` are now
  the author's own recordings (`tools/audio/build_set.py` is the cut list).
  The channel voice follows the form (`WTAGarou.ShiftSounds`,
  `ShiftSoundsRuntime.voiceKind`): target Crinos or currently Crinos ->
  `WTAGarou_CrinosShiftStart`; currently Lupus/Hispo -> (0.4.86) that form's growl;
  currently Homid/Glabro -> the character's vanilla pain voice via
  `IsoPlayer:transmitPlayerVoiceSound(suffix)` (engine-networked, male/female
  by voice prefix; `stopPlayerVoiceSound` on cancel). The voice repeats every
  2.4 s of channel; the rustle bed plays under every channel (Crinos included)
  and fades 200 ms on channel end; the whoosh plays on completion. `WTAGarou_WolfBark`
  played `WTAGarou_Lupus_Bark_01.ogg` (own) until 0.4.86 (back to Freylith's bark, trimmed).
- Shift channel bed (0.4.84, pending playtest): `WTAGarou_FormShift` is an
  8 s sustained rustle (longer than the 6 s BASE channel); the repeat is a
  safety net at 7.5 s. `ShiftSoundsRuntime.onChannelEnd` fades the bed
  (both slots) over `CHANNEL_FADE_SECONDS` = 0.2 via `emitter:setVolume`
  on OnTick, then `stopSound`. Presentation only: setVolume is local,
  stopSound is the engine's networked stop. Every `WTAGarou_*.ogg` is being
  replaced (ledger groups `earthblood`, `epidemic-sound`); file names and
  the sound bank do not change.

- Rule (0.4.83): iso tile art lives on the FLOOR DIAMOND of the canvas.
  The engine draws a tile canvas with its top-left at the square's screen
  point minus `(32, 96) x tileScale`; on 128x256 that is rows 192..255,
  centre (64, 224). Art centred on the canvas floats a body height.
  `tests/asset_contract_test.py` checks the scatter tiles' bounding boxes.
- Rule (0.4.83): change a placed object's sprite with
  `obj:setSpriteFromName(path)` (sprite-manager lookup, keeps the
  registered id), never `obj:setSprite(path)` (the String overload builds
  a new id-less sprite; the server repaired one tile forever).
- Rule (0.4.19, broken again in 0.4.81, now enforced): `InventoryItem.hasTag`
  takes `ItemTag` objects. A String throws "No implementation found".
  Compare `getTags()` names via `WTAGarou.Silver.tagKey`. The asset test
  fails on any `hasTag(` whose argument is not an `ItemTag.` constant.
- Silver smoke (0.4.83): the server sends `SilverSmoke { seconds, cough }`
  every body sweep while a Garou stands in a cloud; the client keeps the
  vision veil (`client/WTAGarouSmokeVeil.lua`, back-most, mouse-transparent)
  up on every message and coughs only when `cough` is true. The burn is on
  the Head ("face"). Masks that protect: `gasmask`, `improvisedgasmask`;
  `gasmasknofilter` does not. The veil is presentation only (0.4.75 still
  holds: the server owns the body).
- Rule (0.4.83): cheat/debug surfaces (server `Debug*` commands, GrantItems,
  the Werewolf Cheats panel) are gated by `WTAGarou.Access.privileged`
  (shared/WTAGarouAccess.lua): single player, a -debug server, or a role
  with the `AddItem` capability. NEVER `getAccessLevel() ~= "None"`: in
  Build 42 that returns the role name and every player is `user`.
  `tests/access_test.lua`; the asset test greps for the old gate.
- Workshop (0.4.83): `tools/stage_workshop.bat` builds the item folder,
  `tools/check_workshop_staging.py` applies the engine's packaging rules and
  the asset-permission ledger `workshop/THIRD_PARTY_ASSETS.md`. No upload
  (even private) until the three donor permissions are recorded there;
  see `docs/WORKSHOP_RELEASE.md`.
- Climb (0.4.83): the vertical root-motion reference is the MEAN HAND
  height measured from the ground, `dy = -hand(1 - 1/scale)`, clamped by
  the lowest foot (`dy >= -lowestFoot`) and `dy <= 0`. No rest frame.
  Kicking legs with planted hands must not change the offset
  (`ClimbTest`). Rigs without hand bones fall back to the 0.4.82 foot lift.

## Previous follow-up: 0.4.82 (Oct 22 hosted playtest)

Write-up: `docs/PLAYTEST_FIXES_0482.md`.

- Rule (0.4.82): mod Lua never calls Lua's global `next()`. Kahlua does not
  expose it; a bare `next(t)` compiles, passes the lua5.1 tests and throws
  "Object tried to call nil" on every run in the game (the 0.4.81 server
  lost lodged-silver burn growth and removal detection to one). Probe with
  `for _ in pairs(t) do ... break end`. `tests/asset_contract_test.py`
  greps every mod Lua file for it.
- Rule (0.4.82): a world object the mod places must use a sprite with a
  FIXED id registered on client and server (`IsoSpriteManager:AddSprite(path,
  id)` + `setName`, from `OnLoadedTileDefinitions` and lazily;
  `shared/WTAGarouScatterSprites.lua`). `IsoObject` is saved and sent in
  AddItemToMap by `sprite.id`; an id-less texture sprite (id 20000000) is
  the empty sprite on every other process. `IsoWorld.init` disposes the
  sprite manager before loading tile definitions, so registration is
  verified by id, never by a Lua flag. Server-side `SC.find` repairs old
  id-less tiles (`setSprite` + `transmitUpdatedSpriteToClients`).
- Rule (0.4.82): tough feet are enforced on the server. Vanilla
  `IsoPlayer.updateFootInjuries` runs only where `!GameClient.client`
  (server, SP), so the client Java `FootInjuryPatch` is SP-only; the server
  body sweep (`WTAGarouPaws.lua`) clears a fresh (<= 3.5 timer) barefoot
  foot scratch/cut for a toughFeet form. Feet with lodged silver, burns and
  glass flags are never touched.
- Rule (0.4.82): in multiplayer Dress grabs floor items ONE at a time.
  Back-to-back `ISGrabItemAction`s merge into a single action with a
  queueList that finishes after its first item in MP; the next grab is
  queued when the previous item arrived or expired. An awaited id is never
  queued twice; a wardrobe id unfound on three Dress presses is forgotten.
- Rule (0.4.82): the climb-compression reference is the LOWEST FOOT
  (`Bip01_L_Foot`/`Bip01_R_Foot`), pelvis only as the matrix-layout sanity
  check and fallback. The lowest point of the body is what rests on the
  fence top.
- Numbers: `Rage.ON_HIT_DEALT = -0.25` (was -0.5); `ShiftStrip.FORMS.Glabro.fraction = 0`
  (no clothing or vehicle-door damage on a Glabro shift).
- Health panel: the silver burn line under a bandaged part is the plain
  "- Silver Burn" at vanilla's wound-line x (15), no "(bandaged)" suffix.
  The body-part menu's vanilla "Remove Glass" reads "Remove Silver
  Fragments" when the part's lodged kind is a shard (post-processed after
  `ISHealthPanel:doBodyPartContextMenu`; the vanilla action is untouched).
- Not bugs: instant glass removal for the host is vanilla
  (`ISRemoveGlass:getDuration` -> 1 for a role with `CanMedicalCheat`,
  i.e. admin); the vanilla "Pick up" furniture tool never lists the scatter
  tile (no tile definition), the mod's right-click does.
- Lua 40 PASS (new scatter_sprites_test 28, paws_server_test 17), asset
  contract 863, Java PASS (ClimbTest 24).

## Previous follow-up: 0.4.81 (silver smoke bomb, scatter art)

Write-up: `docs/SILVER_SMOKE_0481.md`.

- Rule (0.4.81): silver dust is the engine's own smoke footprint: a cloud
  registered from `OnThrowableExplode` for `WTAGarou.SilverSmokeBomb`
  (server / SP), radius = SmokeRange, life = ExplosionDuration game
  minutes, squares gated by `LosUtil.lineClear` not Blocked /
  ClearThroughClosedDoor (IsoTrap's own test). Breathing it is server body
  work (0.4.75): Neck silver burn, Rage, cough cue, scent. `GasMask` tag
  blocks it. Humans unaffected.
- Rule (0.4.81): the silver smoke bomb item is a complete copy of the
  vanilla Smoke Bomb definition (0.4.79 weapon rule); only name, weight,
  tag differ.
- Scatter tiles use the user's four PNG variants by square hash; detection
  stays mod-data based.
- Lua 38 PASS (new silver_smoke_test 46; scatter_test 94), Java 27 PASS.

## Previous follow-up: 0.4.80 (climb-arc compression, Java build)

Write-up: `docs/CLIMB_COMPRESSION_0480.md`.

- Rule (0.4.80): a scaled biped's climb (fence / wall / window states) has
  its vertical root motion compressed by 1/scale in model space
  (`ClimbPatch` on `AnimationPlayer.UpdateSkinTransforms`); horizontal root
  motion in climb states stays vanilla (StrideRuntime skips climbs). The
  reference is the pelvis height on the first frame of the state; the
  offset is never positive (no pushing the model below standing height).
- Client console evidence: the silver weapon equip crash and the invisible
  model were the per-frame `ScriptManager.getItemName` NPE in
  `ModelManager.ResetCharacterEquippedHands` on the B41 weapon definition.
- Java 27 PASS (new ClimbTest 17). Lua 37 PASS.

## Previous follow-up: 0.4.79 (Oct 21 playtest)

Write-up: `docs/PLAYTEST_FIXES_0479.md`.

- Rule (0.4.79): `HaloTextHelper.getColorRGB` and the 3-argument
  `addText(player, text, color)` do not exist in Build 42. Halo text goes
  through `WTAGarou.Halo(player, text, r, g, b)` (real signature
  `addText(player, text, separator, r, g, b)` with 0-255 ints).
- Rule (0.4.79): every mod weapon item must be a complete Build 42
  definition (`WeaponSprite`, sounds, anims), copied from its vanilla
  counterpart. B41-style `StaticModel`-only weapons crash the client on
  equip (Silver Knife / Machete, Oct 21).
- Rule (0.4.79): the toughness refund never refunds a part that dropped in
  the previous sweep too (damage over time is not a hit).
- Rule (0.4.79): "open to air" is `LosUtil.lineClear`, not room equality.
  Clear / ClearThroughOpenDoor pass; a window only when open or smashed.
- Witnesses / Infamy are dormant (`WTAGarou.Delirium.ENABLED = false`),
  players are never witnesses, Infamy is hidden from the panel.
- Panel: resizable, 4 log lines by default, no status line (its texts are
  log entries), scroll-to-bottom icon, layout version 3 carries the size.
- Scatter accepts Silver Fragments (`Base.SilverScrap`, taken by the server
  by id) and filings; options on the world AND inventory menus.

## Previous follow-up: 0.4.78 (Rage panel log)

- The panel's notice area is a LOG (`WTAGarouHUD:pushNotice` appends,
  nothing expires, `LOG_MAX` 200 entries, 10 lines in view, wheel scrolls
  back, a new entry while scrolled up holds the view and shows "new
  below"). Panel height 384. Fresh entries are bright for 6 s, then dim.
- Crinos drain steps ("The beast burns hotter") and the countdown start /
  stop go to the log, not to a halo over the head. "You smell silver" and
  silver-burn halos stay over the head on purpose.
- Pet doors (user, Oct 19): only an occasional residential exterior door,
  never every door. Not built yet; see the roadmap in
  `docs/SILVER_TRAPS_0477.md`.

## Previous follow-up: 0.4.77 ("Home Alone" part 1)

Write-up and roadmap: `docs/SILVER_TRAPS_0477.md`.

- Scattered silver is a plain `IsoObject` (mod sprite
  `media/textures/WTAGarou/WTAGarou_SilverScatter_0.png`, mod data
  `WTAGarou_SilverScatter`), never an `IsoBrokenGlass`: the engine's
  barefoot-glass code must keep ignoring it so humans and zombies walk it
  freely. The hazard runs inside the silver contact scan (server in MP,
  client in SP) through `WTAGarou.Scatter.step`.
- Lodged silver is `d.silverLodged[part] = "bullet" | "shard"` (engine
  `haveBullet` / `haveGlass`); the `SilverLodged` command and
  `RageSync.lodged` carry it. The health panel swaps the matching vanilla
  line only.
- Glabro may wear Shoes and Gloves again (allowedClothing); Crinos, Hispo
  and Lupus never may.
- Worked silver (`Scatter.workedSilver`) = the mod's `WTAGarou.*` items,
  `WTAGarou_Silver`, a live coat, loaded silver rounds, nitrate in a
  vessel. Vanilla silver jewellery is not worked silver and must never
  trigger the sniffer.
- Scatter/pickup: the client drains its own filings (vanilla drainable
  pattern) and the server places/removes the object and hands filings back
  through `WTAGarou.Grant` (never client-made in MP).

## Previous follow-up: 0.4.76

Oct 19 hosted SERVER console (coop-console.txt). Write-up:
`docs/PLAYTEST_FIXES_0476.md`.

- Rule (0.4.76): server Lua may not call client-only globals.
  `getPlayerFromUsername` is client-side and `getPlayerFromRealName` does
  not exist; resolve players through `getOnlinePlayers()` on the server
  (`WTAGarou.WitnessPlayerByName`). The Witness dispatcher threw 1137
  times in one session because of this.
- Lodged silver-tip bullets (`d.silverBullets[part]`, set on the server
  in MP from a ranged silver hit whose part reports `haveBullet()`):
  smoulder at `LODGED_GROWTH_PER_SECOND` up to `LODGED_MAX_BURN` (25,
  never out) until the engine clears `haveBullet` (Pliers, Tweezers,
  Forceps, Suture Needle Holder). The part keeps its silver-burn mark so
  regeneration never pushes the bullet out. Health panel: that part's
  "Lodged Bullet" line reads "Lodged silver-tip bullet" in the silver
  colour (`ISHealthBodyPartListBox.doDrawItem` wrapped, drawText shadowed
  per item). Synced through `RageSync.bullets` and the `SilverBullet`
  command.
- The hosted-server console is `coop-console.txt`; the client console
  never shows server-side Lua errors.

## Previous follow-up: 0.4.75

Oct 19 hosted test, second round. Write-up: `docs/PLAYTEST_FIXES_0475.md`.

Rule (0.4.75): **in Build 42 multiplayer the server owns every player's
BodyDamage.** `BodyDamage.Update()` returns at once on a client for a living
player; the server simulates it, applies PvP and zombie wounds to its copy
(`hitConsequences` -> `DamageFromWeapon`) and pushes the whole BodyDamage
to the owner every 2 s (`NetworkPlayerManager`) and after each wound
(`syncDamage`). Anything a client writes into a body part (burn, heal,
damage scaling) is gone within two seconds. Therefore: silver hit burns,
contact burns, regeneration, acute-damage Rage, the armour refund and the
health-pool refund run in SERVER Lua (`WTAGarou.BodySweep`,
`WTAGarouSilver` server queue) on the server's player object, and the
client only does this work in single player. `sendDamage(player)` pushes
the body immediately. This supersedes the 0.4.72 wording "players own
their own BodyDamage"; the Java `ToughnessPatch` only matters in single
player (no Java on the hosted child server).

Other 0.4.75 rules:
- Never queue `ISWearClothing` directly behind `ISGrabItemAction` on a
  client: the grab only asks the server; wear when `getItemById` finds it
  (`Dress.awaitArrival`).
- `Rage.DEPLETED_HOLD_S` 2 s: the dry revert needs Rage under 1 for two
  continuous seconds and never within two seconds of a shift.
- Paws cannot pull a trigger: `ISReloadWeaponAction.canShoot` wrapped (the
  vanilla attack hook plays the shot sound before Java swallows the press).
- Private cue: the Crinos countdown plays through `playSoundImpl` (owner
  only); every shift sound stays public (`ShiftSoundsRuntime.PRIVATE_CUES`).
- `WTAGarou.VoicePitch` per form on the vanilla voice; default learned in
  a base form only (`d.voicePitch0`).
- Guide pages are capped at 1000 plain characters (tests); silver split
  into "Silver" and "Silver nitrate".

## Previous follow-up: 0.4.74

Oct 19 hosted test: the client logged `watching a stove with raw silver
nitrate` and `vessel warming (temp 1.62)`, but the bottle stayed raw for 35
game minutes. Write-up: `docs/PLAYTEST_FIXES_0474.md`.

Rule (0.4.74): never put an InventoryItem object in a client command.
`TableNetworkUtils` serializes it as a full copy (`saveWithSize` /
`InventoryItem.loadItem`), so the server receives a detached twin and any
change made to it goes nowhere. Send `id = item:getID()` plus the square
locator (`x,y,z,index,containerIndex`, the vanilla `ClientCommands.lua`
shape) and resolve on the server with `getItemWithID`
(`WTAGarou.SilverAmmo.locateVessel` / `findVessel`,
`WTAGarou.NitrateServer.resolve`). Single player may still pass the object
because `Net.ToServer` calls the handler directly.

Kit: the silver kit includes a jar pre-filled with 1 L of finished nitrate
(`Grant.add(..., fluid = {name, litres})`, WTAGarou_* fluids only, 5 L cap).

## Previous follow-up: 0.4.73

Follow-up questions on 0.4.72 (same evening). Write-up: `docs/PLAYTEST_FIXES_0473.md`.

Numbers / rules:
- `WTAGarou.DamageIntake` = Homid 1.0, Glabro 0.65, Hispo 0.65, Lupus 1.0,
  Crinos 0.40 (pools 100 / ~154 / 250). Applied by Java `ToughnessRuntime`
  on `BodyPart.AddDamage` (acute hits only); bleeding / deep wound /
  infection / hunger damage is never scaled. Lua registers it on the local
  client per form change (`WTAGarouVisual`).
- Nitrate scanner: discovery `RADIUS` 15 metre squares every
  `DISCOVER_TICKS`; remembered containers (`NS.watch`) are simulated at any
  distance while loaded and forgotten `FORGET_S` after they empty.

## Previous follow-up: 0.4.72

Target: the October 18 hosted multiplayer test of 0.4.71. Write-up:
`docs/PLAYTEST_FIXES_0472.md`.

Rules that hold from here on:
- Nothing that must work in multiplayer may hang off `InventoryItem.update`
  on a client: the engine never calls it for world-container items there
  (IsoCell.update runs ProcessItems in single player or on the server only).
  Multiplayer nitrate warming is the Lua scanner (`WTAGarouNitrateSync`)
  reporting absolute litres; the server applies AND paces them
  (`nitrateAllowance`). Single player keeps the Java frame simulation.
- Anything that changes another player's body in multiplayer goes through
  the server to THAT player's client (`SilverHit` -> `SilverHitRelay`);
  `OnWeaponHitCharacter` on the attacker's client must not touch a remote
  player's BodyDamage.
- Unarmed contact audio: Crinos `ZombieScratch`, Hispo/Lupus `ZombieBite`,
  stomp untouched; unknown events fail closed. Blood on those hits honours
  BloodLevel.
- Claw swing `m_SpeedScale` 1.25 on both nodes.

## Previous follow-up: 0.4.71

Target: the October 18 playtest of 0.4.70. Write-up: `docs/PLAYTEST_FIXES_0471.md`.
Everything confirmed in 0.4.70 stays locked (arrow placement/no flicker,
cheats-panel pin, footstep/shift volumes, wolf howl anim) unless listed here.

Numbers / switches (Definitions or Java statics):
- `DoorwayRuntime.DUCK_ENABLED = false`: doorway duck / upright refusal
  retired; doorways are vanilla for the Crinos. Door charge unchanged.
- `Anims.HOWL_AUTHORED = "WTAGarouHowl"`, `HOWL_AUTHORED_CLIP =
  "Bob_WTAGarouHowl"`: used for Glabro/Crinos only when the clip is loaded.
- Legwear body locations hidden with the digitigrade legs: Pants,
  Pants_Skinny, PantsExtra, ShortPants, Skirt, LongSkirt, Legs1, Legs5.

Rules that hold from here on:
- `Attack.refresh` (per-frame) never writes `WTAGarouCrinosSwing` for the
  local player while the override is enabled; Java owns it per press. A
  per-frame Lua write to a node-condition variable is a regression.
- Any new player action node is selected by the `PerformingAction` string
  (`setActionAnim(name)`), never by a vanilla node name.
- Human (Bob) clips are checked with `WTAGarouJava.hasHumanClip` before an
  action name that depends on them is set; the fallback path must stay the
  previous behaviour.
- The baseline symbol is top triangle + stem + bottom triangle (7 rects) on
  the baseline column; the cream bracket line stays 4 px inside the bottom edge.

## Previous follow-up: 0.4.70

Target: the October 18 playtest of 0.4.69. Write-up: `docs/PLAYTEST_FIXES_0470.md`.
Everything confirmed in 0.4.69 stays locked unless listed here.

Numbers (Definitions, `/garou reload`):
- `Rage.ON_DAMAGE_DEALT` (-0.15 x damage) -> **`Rage.ON_HIT_DEALT = -0.5`** per landed hit.
- `Rage.CONTENTMENT.PAUSE_ABOVE` removed; `WTAGarou.ContentPullPaused(d)` =
  countdown running, or Rage on MAX outside a Resist rest.
- `HUD.TREND_DEADBAND = 0.05`; `Shift.CHANNEL_END_GAIN` 0.6 -> 0.75.
- Bank: `WTAGarou_CrinosStep` 0.80 -> 0.55, `WTAGarou_CrinosShiftStart` 0.50 -> 0.30,
  `WTAGarou_FormShiftEnd` 0.60 -> 0.70.

Rules that hold from here on:
- The attack-button shove is the `shoveAim` state; any claw/swing node must
  exist under both `player/shove` and `player/shoveAim` (identical).
- `AnimationPlayer.play(params, layer)` honours `subLayerBoneWeights` only on
  sub-layers; a root-layer mask has to be set on the returned track
  (`HowlMaskRuntime.afterPlay`). Masked-out bones hold the previous frame.
- Wolf clips are loaded from `WolfClipLoader.CLIPS` only; a new GLB must be
  added there or it is never available.
- `d.crinosHeldSeconds` (summed dt) is the escalation clock; no wall-clock
  spans in the Rage engine.
- Cheats panel text visibility keys off `isCollapsed`, never `pin`.
- Doorway hook: `hasFlag` uses the `IsoFlagType` overload only; failures are
  logged once, never silently swallowed.

## Previous follow-up: 0.4.69

Target: the 0.4.68 playtest report (legs/tail invisible, feet sliding,
shove/attack buttons, window charge, crowd sprinting, Rage bracket, howl).
Full write-up with engine facts: `docs/CRINOS_0469.md`. Everything
confirmed in 0.4.63-0.4.68 stays locked unless listed here.

Numbers (Definitions, `/garou reload`):
- `modelScale` 1.73 -> **1.65**; `Traits.Crinos` cadence 0.79/0.79/0.73/0.79,
  stride 1.65 (net 1.30 walk/run, 1.20 sprint).
- `DoorCharge.RAGE` 8 -> **12**, `RAGE_LOCKED` 12 -> **18**; stamina unchanged.
  `DoorwayRuntime.WINDOW_CHARGE = false` (window branch returns to vanilla).
- `WTAGarou.CrowdCharge = { Crinos = { limit 3, windowSeconds 3 } }` (new).
- `Rage.BASELINE_BRACKET = { PER_STACK 2, MAX_STACKS 10, SLOW 0.5 }`,
  `Rage.CRINOS_ESCALATION = { EVERY_SECONDS 90, STEP -1 }`, `RESIST.LINEAR_STEP 2`.
- `WTAGarou_CrinosShiftStart` volume 0.80 -> **0.50**, distanceMax 35 -> 25.
- Rage meter markers (bracket line, baseline triangle, fading direction
  arrows, title up/down triangle in the title colour); `RageSync` carries
  `bracket`. No ▲▼ glyphs in UI text (bitmap fonts).

Rules that hold from here on:
- Legs/tail mount through `zombie.core.skinnedmodel.animation.AnimationPlayer`
  (the `advancedanimation` path does not exist in 42.20); the legs sub-model
  takes the coat's `WTAGarou_CrinosBody_<Coat>` texture, there is no
  separate legs texture set.
- `StrideRuntime.LOCOMOTION` must include `PlayerMovementState` (B42.20.2
  walk/run/sprint). `PlayerActionsState` is only the "actions" state.
- Spacebar/LT is the vanilla shove; the attack button unarmed is the swing
  (`WTAGarouCrinosSwing` anim variable gates the claw node and the club cue).
- Crowd charge, climb-lunge poise and the howl arm mask are Java client
  patches registered per form from the visual refresh; forms without an
  entry are vanilla.
- Howl on wolves: `Wolf_howl.glb` is optional; absent, the eat clip plays.
  The human Drink mask is not reused on the wolf rig (absolute neck poses).

## Previous follow-up: 0.4.68

Target: the Crinos balance pass (nerf/buff) and the "too tall for a
doorway" design. Everything confirmed in 0.4.63-0.4.67 stays locked; the
Crinos net movement speed is preserved on purpose.

Numbers (Definitions, `/garou reload`):
- `modelScale` 1.44 -> **1.73** (+20%). `Traits.Crinos.stride` follows
  (1.73) and the cadence dropped to 0.75/0.75/0.70/0.75 so net speed stays
  1.30 walk/run, 1.21 sprint (was 1.30/1.22).
- `meleeDamage` 4.00 -> **2.00**. The surplus is MELEE only: `applyMeleeSurplus`
  returns for `weapon:isRanged()` (firearms were never meant to be boosted;
  Homid can fire them).
- `Rage.ON_DAMAGE_DEALT` +0.15 -> **-0.15**: dealing damage spends Rage
  (OnHitZombie and OnWeaponHitCharacter both use it). Taking damage still
  raises it (+0.75).
- `Endurance` (exhaustion) and `Tired` (drowsiness) left `MOODLE_WEIGHTS` and
  joined `SAD_MOODLES` (1.0 / 0.75 at the 0.03/level/s sad rate): a spent
  body drains Rage like sadness.
- Regeneration: Crinos `HEALTH_PER_SECOND` 1.6 -> **1.2**, `CLEAR_WOUNDS_AFTER`
  75 -> **100 s**. Bite (300 s) and Wyrm purge clocks untouched; Hispo/Glabro
  untouched.
- New `WTAGarou.Poise = { Crinos = 0.85 }`, `WTAGarou.Doorway`,
  `WTAGarou.DoorCharge = { RAGE 8, RAGE_LOCKED 12, STAMINA 0.15, STAMINA_LOCKED 0.225 }`.

Poise (Java, client): every flinch a player plays is a string stored with
`IsoGameCharacter.setHitReaction`. Zombie attacks (standing and crawling)
store it from `BodyDamage.AddRandomDamageFromZombie`, weapon/animal hits
from `IsoPlayer.hitConsequences`; damage is rolled AFTER the string is
stored. `PoiseZombieHitPatch` / `PoiseWeaponHitPatch` bracket those two
calls and `PoisePatch` filters the setter only inside a bracket: with
chance 0.85 the Crinos stores "" instead (no stagger, no shove), damage,
scratches and bites still land, "EndDeath" / "Floor" / "...Defended" are
never filtered and a ranged weapon never opens the bracket. Knockdowns stay
on `WTAGarou.Stability` (0.97). Not uninterruptible: about one melee hit in
seven still staggers.

Doorways (Java, client, local player only): `IsoGridSquare.testCollideAdjacent`
is the movement collision funnel. For a Crinos crossing a doorway edge (a
door object on the edge, open or closed, or the `DoorWallN/W` flag of an
empty frame): sneaking passes as vanilla; running or sprinting passes and
**ducks**: sneak is forced on and the prior state restored once the player
is a tile past the frame (2.5 s safety timeout). Sneak is a toggle in this
engine (`updateSneakKey`: setSneaking(!isSneaking())) and never releases
itself, so the restore is ours; a player who was already crouched stays
crouched, a player who toggles sneak during the duck owns the toggle again.
Walking upright is refused and the HUD red line reads "Too tall for the
doorway. Crouch to pass, or jog through." (once a second). Diagonal and
vertical steps, vanilla blocks and remote players are never touched.

Door charge: `IsoMovingObject.checkHitWall` is where a sprinting player's
collision becomes the collideWithWall stumble. For a sprinting Crinos it is
skipped when the collided object is a closed, unbarricaded IsoDoor whose
`getSoundPrefix()` contains "Wood" and the client-known Rage covers the cost
(8, or 12 when `isLocked()`/`isLockedByKey()`); the door is handed to Lua,
which sends `CrinosDoorCharge {x,y,z,north}` to the SERVER. The server
re-checks everything (Crinos, IsoDoor on that edge, closed, wooden, not
barricaded, within 2.5 tiles, Rage >= cost; it reads the lock itself), then
`door:setHealth(0); door:Thump(player, 1)` (the zombie break path: Break
sound, double doors, planks/hinges drop, removal transmitted), `AddRage(-cost)`
and `WTAGarou.SpendEndurance` (0.15 / 0.225, written through and recorded as
the refund baseline so the 0.90 Crinos refund does not hand it back).
Metal, glass, gates, garage doors, barricades and player-built IsoThumpable
doors keep the vanilla stumble. A sprint into a closed, unbarricaded,
climbable IsoWindow starts `climbThroughWindow` instead of the stumble
(0.4.39 WindowClimbPatch smashes it first; vanilla ClimbThroughWindowState
rolls the 50% glass cut). No Rage cost for windows; cars unchanged.

Not changed: Crinos knockdown filter, Hispo everything, bite/Wyrm clocks,
Glabro 1.5x melee, Crinos armour/carry, roar, cosmetics.

Tests: DoorwayTest 46, PoiseTest 15, door_charge_test 42 (new);
rage_engine_test regen section parametrised on W=100/HP=1.2; visual,
channel_hud, definitions_reload, wyrm_tutorial updated. Lua 33 PASS, Java
all PASS. See CRINOS_BALANCE_0468.md.

Locked in 0.4.68: every 0.4.67, 0.4.66, 0.4.65, 0.4.64 and 0.4.63 item below.

## Previous follow-up: 0.4.67

Target: the Crinos body and the sound pass requested after the Oct 16
hosted playtest. Everything confirmed in 0.4.63-0.4.66 stays locked.

Crinos legs and tail are **intrinsic**: Java mounts the skinned digitigrade
legs (every Crinos) and the tail (only when the character's `crinosTail`
flag is on) as body sub-models on the body's own AnimationPlayer, the same
`newAdditionalModelInstance` + post-process wiring PopTemplateManager uses
for every worn FBX, with no ItemVisual and no inventory item. The human
LeftLeg/LeftFoot/RightLeg/RightFoot mask parts are hidden (0.4.90: with the
vanilla mask set; our leg mesh starts just under the hip joint and overlaps
the stump the vanilla Crotch mask leaves). Worn Shoes/Socks keep their stats but lose
their mesh while the legs are on (`CrinosFootwearPatch`). The tail toggle
lives in the startup panel under Wolf Gear ("No tail" default / "Tail"),
saves on the server (`SelectCrinosTail`, strict boolean, never locks) and
travels in the VisualSnapshot rows so remote clients build the same body.
Meshes (0.4.90): `common/media/models_X/Skinned/Clothes/WTAGarou_Crinos{Legs,Tail}_{M,F}.glb`,
our own, generated by `tools/build_crinos_parts.py` (lofted splines skinned
to the vanilla Bip01 rig whose bind pose is in `tools/data/bip01_bind_pose.json`).
Textures: legs = the coat's `Body/WTAGarou_CrinosBody_<Coat>.png` (vanilla
UV islands, 0.4.91); tail = `Body/WTAGarou_CrinosTail_<Coat>.png`, procedural
fur from the same tool, palette sampled from the author's CrinosBody sheet. The
RabenRabo FBX files, his dye-derived tail PNGs and his mask set are gone
from the tree and must not come back (0.4.67-0.4.89 shipped them; a
re-sculpted copy of his mesh is still his derivative). Edit the generator
and re-run it; do not hand-edit the GLBs. The thigh top follows the stump
the author matched by eye in his 0.4.90 reference edit (centre x 0.059,
z -0.025, half-width 0.043, half-depth 0.053 at y 0.42).

Sound (all cues keep the Sound Effects slider scaling through
`WTAGarou.Audio` / `StealthRuntime.scaleHandle`):
- `WTAGarou_CrinosStep` (two bass clips) is played **locally** under every
  Crinos surface footstep by the Java footstep patch. DoFootstepSound runs
  from the Footstep anim event on every client that animates the character,
  remote copies included, so this is what makes it heard in MP; a networked
  playSound would double it. Gain follows the step volume (quieter sneaking).
- `WTAGarou_CrinosRoar` has three clips since 0.4.87 (Roar_Bark, _02, _03; the
  author dropped _04.._07). Until then seven (Roar_Bark, _02.._07; _07 was the
  previous Crinos shift roar); the engine picks one per play, also on the
  remote copies the PlaySound packet triggers.
- Channel cues: the quiet `WTAGarou_FormShift` repeats at 1.8 s (was 2.9)
  under its own cue slot so the first pass is not cut; `WTAGarou_FormShiftEnd`
  (formshift_02) plays once on perform at 0.6 gain; a channel INTO Crinos
  opens with `WTAGarou_CrinosShiftStart` (bank volume 0.80, under the 0.95
  completion roar) and does not repeat; `WTAGarou_CrinosShift` (the new,
  longer file) still lands it. Cancelled channels play no end cue.
- Reach: FormShift / FormShiftEnd distanceMax 12 (quiet), Crinos start and
  completion 35, roar 60. Shift cues go through `emitter:playSound`, the
  engine's networked path; the `WTAGarou_Crinos_Roar_Bark (n).ogg` files
  were renamed to `_0n` (no parentheses/spaces in clip paths).

Not changed: the Crinos Q shout still plays no gesture animation (0.4.63,
`ShoutEmotePatch`); the user has not yet checked this live.

Tests: CrinosCosmeticsTest 93 (was 60), StealthTest 84 (was 78),
shift_sounds_test 65 (was 32), wolf_coat_test 181 (was 130),
visual_sync_test 56 (was 50), crinos_cosmetics_test 54 (was 44),
crinos_assets_test extended. Lua 32 PASS, Java all PASS. See
CRINOS_LEGS_TAIL_0467.md.

Locked in 0.4.67: every 0.4.66, 0.4.65, 0.4.64 and 0.4.63 item below.

## Previous follow-up: 0.4.66

Target: the first hosted-game playtest (Oct 16, host PC + a Steam Deck
client, game 42.21.0). Everything confirmed in 0.4.63-0.4.65 stays locked.

Root cause behind "can't equip anything" and "the nitrate mix channel
completes and nothing happens": Build 42 multiplayer inventories are
**server-owned**. Every timed action (equip, wear, drop, craft) is rebuilt on
the server from item ids and rejected when the server does not know the
item. The debug kits created hundreds of items client-side with
inventory:AddItem; none existed on the server. The server console shows the
rejections (`ISDropWorldItemAction.new` with a nil item). Vanilla's own item
spawner uses a server command in MP for the same reason.

Rule added to the 0.4.65 one: **no client code may create, remove, drop or
re-stat inventory items in multiplayer.** Items are made on the server
(`WTAGarou.Grant`), stripped on the server (`serverStrip` →
`Clothing.dropForbidden` with the networked drop path), and a remote
client's Java only *reports* nitrate warming (`NitrateCooked`) for the
server to apply with `sendItemStats`. Single player keeps the direct paths.

0.4.66 also silences two console floods seen on the host: `CharacterTrait.get`
needs a ResourceLocation (bare string raised on every witness scan, Kahlua
prints even inside pcall) and `getCraftRecipe(bareName)` returned nil for our
recipes (now module-qualified name first, then a walk of the recipe list).

The "debug menu appearing in Crinos and cycling professions" was the
vanilla Lua Debugger with Break On Error ticked, stopping on the
`CharacterTrait.get` string error above for each BRAVE_TRAITS name; same
fix. The Deck's "connection failed" was `NotInvited` (Steam invite /
whitelist), not the mod.

Tests: multiplayer_items_test 56 (new), NitrateHeatTest 44 (was 29),
test_panel_test adjusted (firearm kit probes ammo via instanceItem). Lua 32
PASS, Java all PASS. See MULTIPLAYER_ITEM_OWNERSHIP_0466.md.

Locked in 0.4.66: every 0.4.65, 0.4.64 and 0.4.63 item below.

## Previous follow-up: 0.4.65

Target: the hosted co-op server. Everything confirmed in 0.4.63/0.4.64 stays
locked.

Hosting terminated twice on Oct 16. First because `mods\WTAGarou` was a
junction (vanilla MP anim-set checksum cannot relativize a junction; see
HOSTING_JUNCTION_CHECKSUM.md; fixed by a real copy, `tools/sync_mod_folder.bat`).
Second because the co-op server is a child JVM without ZombieBuddy: no
WTAGarou Java runs there, so `tags[wtagarou:coatable]` /
`tags[wtagarou:forgeable]` were empty and `InputScript.OnPostWorldDictionaryInit`
aborted world load ("Tag has no items"). Recipes are performed on the server
in MP (`ISHandcraftAction`), so the server must know the weapon set itself.

Rule for the whole mod from now on: **no script may depend on anything the
Java side adds at load time.** Java is client-side only (visuals, patches,
tagging for reports); scripts and shared/server Lua must be complete on
their own.

0.4.65: both weapon slots are explicit generated lists
(`tools/gen_coatable_lists.py`, same rule as `CoatableTagRuntime.decide`).
Coat slot additionally unions the vanilla metal tags (`OnTestCoatInput`
trims the junk on both sides); forge slot is list-only so hammers stay out
of the weapon slot (0.4.63 lock). `WTAGarouSilverAmmo.reportRecipeDrift`
logs at OnGameStart which rule-coatable items the lists miss; the
reference scripts used for the baseline predate 42.20.2, so expect a
non-empty first report and regenerate with `--extra`.
silver_ammo_test 205. See HOSTING_SERVER_WITHOUT_JAVA_0465.md.

Locked in 0.4.65: every 0.4.64 and 0.4.63 item below.

## Previous follow-up: 0.4.64

Target: the two requests that followed the 0.4.63 report. Everything the
Oct 16 console confirmed stays locked; 0.4.63 fixes are untouched.

Backward strafe in Hispo/Lupus played the forward walk cycle while the
body slid backwards (`Bob_WalkBwdAim` etc. resolved to `Wolf_walk`).
`WolfRuntime.preferredClipFor` now resolves "walk"+"bwd"/"back" human
nodes to `Wolf_walk_back`; until that clip is authored the optional
fallback is `Wolf_walk` and `reverseForBackwardWalk` flips the pose keys
(the same `reversePose` path corpse dragging already used), so the paws
move with the direction of travel. An authored `Wolf_walk_back` plays
forward. Dragging precedence is unchanged. WolfPlayerClipsTest 410 PASS.

Movement stopped after every shift into or out of a wolf form until the
key was released and pressed again. Cause (static, from the 42.20.2
decompile): `WolfRuntime.rebuild` and `refreshWolfAnimations` call
`AdvancedAnimator.OnAnimDataChanged(false)`, which nulls the root
`AnimLayer` state; the next `AdvancedAnimator.update` then forces the
`Idle` anim state while the player's `ActionContext` is still in
walk/run/sneak, so no state-change callback fires and the root-motion
locomotion never restarts. Vanilla only calls `OnAnimDataChanged(false)`
next to `ActionContext.setGroup` (`IsoPlayer.checkActionGroup`) or re-syncs
through the private `restoreAnimatorStateToActionContext`. The mod now
does the same: `WolfRuntime.resetAnimData` resets and then calls
`animator.setState(actionContext.getCurrentStateName(), childStateNames)`
(all three call sites: rebuild, deferred death reset, timing refresh).
`WolfRuntime.status()` reports `animator state restored after reset=true`
once it has run. AnimatorRestoreTest (9) covers order, child states, a
context without a root state and a character without an ActionContext.
Awaiting live verification; if a Homid<->Glabro shift (no wolf rebuild)
also stops movement, the cause there is different and still open.

Locked in 0.4.64: every 0.4.63 item below.

## Previous follow-up: 0.4.63

Target: the 42.21 playtest of 0.4.62 (console of October 16, Java banner
0.4.62, no Lua errors). Live evidence from that console: the fluid pipeline
works end to end (`coatable tag: ItemTags.Init seen, 232 of 5110 item
scripts tagged`, two `silver nitrate coat on 1 weapon(s)` lines, pouring
between containers, the tooltip meter counting down and the coat wearing
off, re-coating, every firearm in the kit fired on silver and a half-empty
magazine topped up), and `rage = 100` four times in Hispo followed by
`[Resist] nothing to resist` with no `Crinos countdown ... started` line.
Everything confirmed there stays locked; the items below are the fixes.

Rage sat on 99 (even in Crinos, even after cheating to 100): `rageTick`
applied the passive rate, the negative-moodle pressure and the sad drain as
three separate `AddRage` calls, so the positive part clamped at 100 and the
sad drain (one Unhappy level, 0.03/s) then pulled it to 99.985 every tick;
the HUD showed 99 and `d.rage >= R.MAX` was never true, so the 100-Rage
Crinos countdown never armed. The three are now summed into one signed
`net` and applied once (the contentment pull still runs after, and only
below 95). rage_engine_test adds the exact Oct 16 moodle set at 100
(holds), at 99.9 (climbs onto 100) and in Crinos (holds); below the cap the
sum equals the old separate adds. 660 PASS.

Nitrate cooked instantly in a microwave: `NitrateHeatRuntime` converted
from the first hot tick at 0.01 L per client update (a litre in ~2 s at 60
fps). It now mirrors vanilla `InventoryItem.update` heat: a per-vessel
warmth (weak map, 1.0 cold) climbs `temp/1000 * timeMultiplier` per client
update (`/16` on the server) up to `min(3, temp)`, cools 0.001 per update
out of the heat, and only converts above 1.6 (vanilla boil), at a quarter
of the tainted-water rate (0.0025 / 0.15). A lit fire: ~330 updates of
warm-up, then ~400 to finish a litre. NitrateHeatTest 35 (ramp, cap, cool,
residual heat, server ramp).

Carving fork / smithing hammer / claw hammer not coatable:
`CoatableTagRuntime.decide` counted only `metalValue > 0` or HasMetal and
excluded Tongs/File/Hammer/ClubHammer. Metal now also means any
`Smeltable*` tag (fireplace poker, hand fork, trowel, pipe wrench, ratchet,
tire iron carry those and no MetalValue in the 42 scripts), Sharpenable
(hatchet, machete, ice pick) or the script name CarvingFork2 / IceAxe (no
tags at all). Forge tools are coatable like everything else; a SECOND tag
`wtagarou:forgeable` (coatable minus the four tool tags) is registered in
`registries.lua`, applied in the same `ItemTags.Init` pass, and is the
FORGE recipe's weapon slot, so the forge's hammer/tongs slots still never
compete with its weapon. `S.isMetalItem` (Lua) mirrors the Java rule;
SharpKnife/ChopTree alone no longer count (stone knives and axes). The
status line reads `n of m item scripts tagged coatable, k forgeable`.
CoatableTagTest 44.

Coating needed a surface: `WTAGarou_CoatSilverNitrate` is `Tags =
InHandCraft` (HandcraftLogic only gates `isAnySurfaceCraft`); mixing the
raw nitrate keeps AnySurfaceCraft.

Shells six at a time: every round recipe is ONE round per craft, queued in
bulk, Time 180/6 = 30 (shells) and 240/10 = 24 (bullets). A recipe cannot
take a sixth of a fragment, so `WTAGarou_FileSilverFragments` (fragment +
file, 60) makes `WTAGarou.SilverFilings`, a 20-use drainable
(`ItemType = base:drainable`, `UseDelta = 0.05`); shells take `item 3`
(six a fragment, as before), bullets `item 2` (ten a fragment, as before).
Recipe names are singular. Debug kit: 20 Silver Fragments.

Racking un-silvered the chambered shell: vanilla `ISRackFirearm:removeBullet`
instances the gun's ORDINARY ammo type. `S.ejectedRoundType(gun)` (chamber
guns: chamber flag; others: silver count > 0) and an eighth wrapper on
`removeBullet` add the silver type instead (SP and server; MP clients do not
run rackBullet). Unloading already handed silver back and is unchanged.

Loading silver rounds: the 0.4.58 instant action (no animation, no sound,
gun not required in hand) is replaced by two derivatives of the VANILLA
actions in `shared/WTAGarouSilverLoadActions.lua` (shared so a server can
instance them by Type): `WTAGarouLoadSilverAction` (ISReloadWeaponAction:
same AnimSet events, reload speed, rack-after, `getPrimaryHandItem() ==
gun` rule; `initVars` stages the silver type, `loadAmmo` adds one to the
silver count per round) and `WTAGarouLoadSilverMagazineAction`
(ISLoadBulletsInMagazine: InsertBullets anim with the magazine in hand,
per-round InsertBullet sound/removal/count). The context menu equips the
gun first like vanilla "Load bullets" and stages rounds out of bags
(`transferBullets`). The firearm radial menu (hold R / controller) gets a
`Load silver rounds (+n)` slice (vanilla icons and ammo-count text) that
targets the gun or the fullest silver-compatible magazine; it is hidden
when ordinary rounds are inside, when there is nothing to load, or for
paws. Both actions are in the paw-guard list. silver_load_actions_test 46
(new), silver_ammo_test 174, paw_guard_test 54.

Crinos Q shout / whisper: `ShoutEmotePatch` (Java, `IsoGameCharacter.
playEmote` entry, skipOn) drops the "shout" emote for characters whose
voice profile asks (`WTAGarouJava.setShoutAnim(player, false)`, set from
`WTAGarou.Voice.Crinos.shoutAnim = false` in applyStealth; every other form
passes true). The roar/growl sound and text still come from CalloutPatch;
no other emote is touched. StealthTest 79, stealth_voice_test 284.

Known / deferred: 7.62 rounds are vanilla's `.308` calibre (the display
name is vanilla's); mixed silver/ordinary magazines are still refused by
design (a full per-round ammo model would be a rewrite); the coated-weapon
burn on a werewolf needs a second player to verify live; MP clients see
the silver count through mod data, which lags vanilla's field sync.

Lua suite: 31 PASS. Java suite: 23 PASS (CoatableTagTest 44, NitrateHeatTest
35, StealthTest 79).

## Current follow-up: 0.4.62

Target: the 42.21 playtest of 0.4.61 (console of October 14, Java banner
0.4.60, Lua 0.4.61). Live evidence from that console: the coat recipe ran
(`silver nitrate coat on 1 weapon(s)`), the coated saucepan burned a bare
hand (`Hand_R burned by silver`) and stopped once the coat wore off, and
1092 lines of `Translator.reportMissingArgumentsFromPastAbuse ... Missing
arguments for "Tooltip_WTAGarou_SilverNitrate"` (the `%` in the tooltip text
is a format specifier to the translator). Shifting near 0/100 Rage confirmed.
The silver nitrate feature is redesigned as a fluid; the rest is locked.

Silver nitrate is a FLUID now (`scripts/silver_fluids.txt`:
`WTAGarou_SilverNitrateRaw`, `WTAGarou_SilverNitrate`; Hazardous, poison
like Bleach: Deadly past 0.2 L, 10% dilution; the two blend only with each
other). The two jar items and `Translate/EN/Tooltip.json` are gone
(`Fluids.json` names the fluids). `WTAGarou_PrepareSilverNitrate` keeps the
empty glass vessel (`tags[Glass;GlassBottle] mode:keep
flags[ItemIsFluid;IsEmpty]`, OnTestNitrateInput unchanged) and pours
`+fluid 1.0 WTAGarou_SilverNitrateRaw` into it: the jar is no longer left
empty, it comes back full. Fertilizer stays `item 2 [Base.Fertilizer]`:
CraftRecipeManager takes USES from a drainable input (eight per bag), so
this is a quarter of ONE bag; the debug kit gave two bags because of a wrong
comment, now one bag plus leather gloves. The battery is still destroyed.

Cooking stage: `NitrateHeatPatch` (Java, `InventoryItem.update` exit) turns
raw into finished at vanilla's tainted-water rate ((server ? 0.6 : 0.01) *
timeMultiplier per update) whenever the vessel's OUTERMOST container reports
a temperature above 1.5 (lit campfire/barbecue/fireplace 1.8, running stove
(T+100)/100). Vanilla only boils Cookable items (itemHeat never rises for a
jar), hence the patch reads the container, not the item. Hot items stay in
the process list (`finishupdate`), so no extra ticking is needed. NitrateHeatTest
20 (fixture advice: client 100 ticks per litre, server 2, cold/floor/water
untouched, inert without the fluids).

Coat recipe: `item 1 tags[wtagarou:coatable] mode:keep` plus `item 1 [*]
mode:keep flags[ItemIsFluid]` / `-fluid 0.2 [WTAGarou_SilverNitrate]`: five
coats per litre, the vessel stays. OnTestCoatInput: a NON-EMPTY fluid
container passes as the vessel, a HandWeapon must pass canCoatWeapon,
anything else (foil, cans, bulbs) is refused; OnCoatWeapon never coats the
kept vessel. The weapon tag is added at item-load time by `CoatableTagPatch`
(`ItemTags.Init` exit): every item script of type Weapon, not ranged, with
`metalValue > 0` or HasMetal, minus Tongs/File/Hammer/ClubHammer, Materials
and anything named silver, gets `wtagarou:coatable` and is indexed in
`ItemTags.tagItemMap`, which is what `tags[]` inputs resolve through at
`OnPostWorldDictionaryInit`. So the crafting window's "possible items" lists
real weapons instead of foil and light bulbs, and the forge recipe uses the
same slot. `flags[IsNotWorn]` is gone from both weapon slots: InputScript
rejects EQUIPPED items under that flag too (`!isWorn() && !isEquipped()`),
which is why the cleaver in hand "acted like it was not in the inventory".
CoatableTagTest 27.

Tags: `ItemTag.get(ResourceLocation.of(x))` is a plain registry lookup, so a
script tag that was never registered (`WTAGarouSilverAmmo`,
`WTAGarouSealedSilver`) resolved to null in-game, and `ItemTag:toString()`
is the namespaced lower-case id (`base:hasmetal`), so every `tostring(tag)
== "HasMetal"` comparison in our Lua never matched outside the test stubs.
`registries.lua` now registers `wtagarou:silverammo` and `wtagarou:coatable`
(get-before-register; duplicate registration throws), silver rounds carry
`Tags = Ammo;wtagarou:silverammo`, and both Lua tag comparisons
(`SilverAmmo.hasAnyTag`, `Silver.itemIsSilver`) go through `tagKey`
(namespace stripped, lower case). Contact scan: the sealed-type/tag list is
replaced by "any fluid container that is not itself coated/forged is
exempt", so a jar or bottle of nitrate never burns while a Silvered
Saucepan still does.

UI: the rename `Silvered <name> (n)` is invisible on fluid-container weapons
(InventoryItem.getName returns the FluidContainer UI name) and was never
saved (customName flag). `S.rename` sets `setCustomName(true)` on coat and
forge renames and clears it when a coat wears off. New
`client/WTAGarouSilverTooltip.lua` wraps `ISToolTipInv:render` and draws one
strip under the vanilla tooltip: `Silver coat: n of 12 hits left`
or `Forged silver: ...` (`S.tooltipLine`); any error disables
the strip, never the tooltip. Guide page 6, STEAM_DESCRIPTION, test panel
label and `/garou silver` (prints `coatableStatus`/`nitrateStatus`) updated.
Known open: a Garou drinking the fluid only gets vanilla poison, not a
silver burn. silver_ammo_test 153, rage_engine_test 655; Lua 30 PASS, Java
23 PASS; banner 0.4.62.

## Current follow-up: 0.4.61

Non-Crinos channel time now depends on how far Rage sits from the middle
of the bar, falling off toward BOTH ends (requested after 0.4.60).
`WTAGarou.ComputeTransformSeconds`: within `TransformTime.PLATEAU` (5) of 50
the channel is `BASE` (6.0 s, what the old 10 -> 2 ramp gave at 50, so the
middle feels unchanged); from there it shrinks linearly and reaches `FAST`
(1.0 s) once Rage is within `FULL_AT` (20) of 0 or 100, i.e. at <= 20 or
>= 80, staying there. Halfway points: 32.5 and 67.5 Rage give 3.5 s. Crinos
keeps its fixed 1.0 s snap. The old `MIN`/`MAX` constants are gone; nothing
else read them (the server only reads `COOLDOWN`). Guide page 3 (Rage)
states the rule. rage_engine_test 650, wyrm_tutorial_test 90; Lua 30 PASS.
No Java change (jar banner still says 0.4.60).

## Current follow-up: 0.4.60

Target: the 42.21 playtest of 0.4.59 (console of October 14). Live evidence
from that console: the 0.4.59 preload works (`[WTAGarou][Preload] wolf +
Crinos assets ready (5.1 s)` at spawn, `0.1 s` after a coat change) and the
Java 0.4.59 banner printed. Three defects were found, two of them mine.

Item scripts (the "silver shells give an error" report):
`Lua(Vanilla).performRecipe> NullPointerException ... setAlcoholPower ... at
Item.InstanceItem`. B42.2x item scripts set the kind of item with
`ItemType = base:<kind>`; the legacy `Type = Normal` keyword is silently
ignored (B42.20.2 `Item.DoParam` only knows `ItemType`), so every silver item
and the three spirit-gift books had no item type and could not be
instantiated. Our 0.4.11 saddlebag items already used `ItemType =
base:container`. Fixed in `silver_items.txt` (12 blocks) and
`spirit_gifts.txt` (3). silver_ammo_test asserts no `Type =` keyword remains.

Ammunition catalogue (the recipe-hover errors): `InputScript ... Invalid
input. line: item 10 [Base.223Bullets]`. B42.14 removed .223 ammunition
(MSR700 uses 5.56) and added .357 Magnum; the 42.20.2 Lua tree lists the
vanilla set as ShotgunShells, Bullets357, Bullets38, Bullets9mm, Bullets45,
Bullets44, 3030Bullets, 308Bullets, 556Bullets. `.223` removed everywhere;
`.357 Magnum` (`Base.Bullets357`) and `.30-30` (`Base.3030Bullets`) added,
10 rounds in, 10 silver rounds out like every other bullet calibre. The
4,500 `ISWidgetInput.lua:336/337` hover errors came from the empty .223 input
list. Note for later work: `PZ-reference/pzmcp-b42/media/scripts` predates
42.14 and is stale for ammunition; `PZ-reference/vanilla-lua` is 42.20.2.

Nitrate vessel ("any glass container, nothing plastic"): the vessel slot is
`item 1 tags[Glass;GlassBottle] flags[IsEmpty]` plus
`OnTest = WTAGarou.SilverAmmo.OnTestNitrateInput`, which refuses Glass-tagged
items that are not fluid containers (windshields, shards) and any vessel with
fluid in it. Plastic never carries the Glass tag. The vessel is used up with
the mix: `ReplaceOnDeplete = Base.EmptyJar` was removed, because a beer
bottle must not come back as a jar. Guide page 6, tooltips, Steam notes
updated.

Crinos "slidey feet": root motion. Player locomotion is animation root
motion handed over by `IsoPlayer.getDeferredMovement(Vector2, boolean)`
(vanilla scales the same vector for its invisible-sprint cheat). The Crinos
model is drawn at 1.44x, Glabro at 1.24x, so the visible stride was that much
longer than the ground covered. `StridePatch`/`StrideRuntime` scale the vector
by `WTAGarou.Traits.<form>.stride` (= modelScale) in locomotion states only
(PlayerActions/Strafe/Aim/PathFind/WalkToward/DraggingCorpse); climbs,
falls, get-ups, hit reactions, attacks and seated poses keep vanilla root
motion. Net speed is cadence x stride, so the cadence multipliers dropped:
Glabro 0.95/0.95/0.92/0.95 x 1.24 (net 1.18 walk, was 1.10); Crinos
0.90/0.90/0.85/0.90 x 1.44 (net 1.30 walk, 1.22 sprint; was 1.20/1.15).
Wolves have no stride entry: their gait tuning is locked. Numbers are
tunable in Definitions (`/garou reload`).

Right-stick look while seated: NOT the mod. B42.20.2
`IsoPlayer.update` computes the seated head-look (`isHeadLookAround`) from the
`AimingReticle` screen position, not from the stick vector; with a gamepad
the reticle sits where precision aim parks it (ahead of / above the player on
screen), which is north-ish in iso space: facing west the head turns right,
facing east it turns left, exactly the report. Nothing in WTAGarou touches
AimingReticle, head look or forward direction for a Homid (`WolfSeatedLook`
is wolf-forms-only and sitting-on-furniture-only). Reproduce with the mod
disabled to confirm; mouse look works because the reticle follows the mouse.

Testing kit: `/garou silver` (Test Panel "Silver kit") now also adds 2
Fertilizer, a CarBattery1, Pliers, File, Screwdriver, an Empty Jar, 2 Silver
Fragments and a box of shotgun shells (`WTAGarou.Debug.SILVER_CRAFT_KIT`), so
the chain can be tested outside debug mode.

Static suites pass (Lua 30 PASS, silver_ammo_test 130, stealth_voice 281,
rage_engine 633; Java 21 PASS incl. the new StrideTest 21). Live
confirmation pending; see [SILVER_FIXES_STRIDE_0460.md](SILVER_FIXES_STRIDE_0460.md).

## Current follow-up: 0.4.59

Target: the second, cheaper silver route (silver nitrate coatings), the
forge-skill rule, logical exceptions to the "silver in the name burns" rule,
the Werewolf Guide / Steam description notes, and the first-shift model pop
("big guy in underwear" between the end of the first Crinos/Hispo/Lupus channel
and the model appearing). 0.4.58 is still awaiting its live test; nothing from
.56/.57/.58 was changed except the retry cadence noted below.

Silver nitrate: `WTAGarou_PrepareSilverNitrate` (2 fertilizer uses + car
battery destroyed + Silver Fragments + empty jar, opened with knife /
screwdriver / pliers, kept, no skill) -> "Jar of Raw Silver Nitrate", a
CantEat cookable that the vanilla cooking system turns into "Silver Nitrate"
(4 applications) on any heat source. `WTAGarou_CoatSilverNitrate` (metal
melee weapon kept + 1 application, no skill) -> "Silvered <name> (12)": 10% of
max condition eaten (floor 1), 12 landed hits (zombie or Garou) each spend a
charge, then the name reverts and the wielder gets `silver_worn_off`. Forged
"Silver" weapons cannot be coated; coated weapons can be re-coated (reset to
12, condition paid again). Numbers are the user's choices.

Forge skill: `WTAGarou_SilverWeapon` keeps `Blacksmith:1` as a floor; OnTest
also requires the Blacksmith level vanilla asks for to forge that weapon's
blade/head (`WTAGarou.SilverAmmo.FORGE_LEVELS`, derived from B42.20.2 scripts;
loot-only twins inherit; unforgeable weapons use the floor).

Contact exception: `WTAGarou.Silver.contactSilver` = itemIsSilver AND NOT
sealed (tag `WTAGarouSealedSilver` or type in `SEALED_TYPES`). Both jars are
sealed; held/worn bare silver still burns; weapon hits still use itemIsSilver.

First-shift pop: Java `WTAGarouJava.preloadForms(body, head, wolfTexturePath)`
warms the wolf model + clips, the Crinos head model and the coat's body/head
textures; Lua `Visual.preload` calls it from every refresh (so from
OnCreatePlayer) and polls until "ready". "pending" answers from
setCrinosCosmetics/setWolf are now re-asked every 0.1 s (was 1 s), giving up
after 60 s (was 60 attempts). Expected live effect: the first shift shows the
model on the same frame the channel ends, or within a tenth of a second.

Translations: new `Translate/EN/Recipes.json` (both `<name>` and
`Recipe_<name>` keys, since Translator.getRecipeName looks the raw name up in
the Recipes map) and `Tooltip.json`. Observation, unchanged: the IGUI_ keys in
`UI.json` are read from the IG_UI map by Translator, so they do not resolve;
the HUD uses its own DENIAL_TEXT table and is unaffected.

Static suites pass (Lua 30 PASS, silver_ammo_test 119, rage_engine 633,
crinos_cosmetics 45; Java 20 PASS). Live confirmation pending; see
[SILVER_NITRATE_PRELOAD_0459.md](SILVER_NITRATE_PRELOAD_0459.md).

## Current follow-up: 0.4.58

Target: the Hispo "machine-gun bite" that appeared only while holding an
electric guitar, quadruped lockouts for firearm handling / crafting /
mechanics, the Metis Crinos exit line at 55 Rage, and the first Wits slice:
craftable silver ammunition, silvered melee weapons and a located Silver Burn.
User-confirmed after .57: makeup hide/restore, headwear fit and the hidden
head depth patches are all fixed ("everything seems to work just fine").
Those join the locked .56/.57 behaviours. Do not change the .56 accessory,
makeup, ownership, clothing-policy, texture-refresh or .57 head-cull code.

Guitar: the item script's BaseSpeed 1.1 x two-handed heavy 1.2 inflates the
engine's CombatSpeed; the Skully "Heavy" table and the Java heavy recovery cap
(4) then stacked on the fixed-length derived Wolf_attack clip. .58 makes jaw
attacks weapon-neutral on both sides (Lua `biteSpeed` divides the weapon class
factor back out and caps at 1.11; Java `CombatRuntime` uses one JAWS_CAP=12
whenever the wolf body is active). Human forms keep the Skully caps 12/12/1/8/4.
Hypothesis, not yet shown live: any "Heavy" two-hander (sledgehammer)
reproduced the same bug.

Paws: `WTAGarouPawGuard.lua` refuses the whole reload family, firearm radial,
crafting/build/dismantle/fix, vehicle mechanics and fuel transfer for Hispo and
Lupus with HUD denials (paws_firearm / paws_craft / paws_mechanic). Firing is
already swallowed by the existing JawsAttackPatch. `RECIPE_WHITELIST` ships
empty by design; Crinos keeps thumbs (only vehicle seats remain blocked).
Metis: CRINOS_LOCK_ABOVE_BERSERKER 35 -> 55, tooltip updated.

Silver: eight silver round variants (one per vanilla calibre), B42 craftRecipe
scripts (shells: 6 + fragments + pliers; tips: 10 + fragments + file + pliers;
forge: metal melee weapon + 2 fragments + charcoal + hammer + tongs at a forge),
homogeneous loads only (mixed refused), per-shot silver flag, located burn via
the Java BodyDamage hit recorder (no record = clothing absorbed = no burn).
Multiplayer sync of silver counts is NOT in this slice.

Full static suites pass (Lua 30 suites incl. new silver_ammo_test 78 and
paw_guard_test 52; Java incl. new SilverHitTest). Live confirmation pending;
see [Wits first slice and paws](WITS_SILVER_0458.md).

## Current follow-up: 0.4.57

Target: Crinos head-area patches that expose the floor through the replacement
head and, per the user's report, vehicles behind it.
User-confirmed after .56: makeup now hides AND restores; scaled hats/accessories
fit well enough. These join the locked .6 head size/orientation and confirmed
split-screen behavior. Do not change the .56 accessory, makeup, ownership,
clothing-policy, or texture-refresh implementations.

Source evidence: masking the human head only changes its composed texture;
the original skinned head geometry still participates in body rendering.
Depth involvement is a hypothesis consistent with the screenshots/report,
not a captured GPU diagnosis. .57 contracts only Bip01_Head's matrix in the
registered Crinos body's copied render palette, around its current animated
pivot. The shared pose, model/mesh/PNG assets, head attachment, accessory
matrices, and other body bones are untouched. Contraction is 0.001 for the
hidden human head only, NOT a change to the visible head's 0.6 scale.
Apply after native palette generation, before shader-property publication.
Use the mesh's bone index for the palette and the animator's index for the
pose; never assume those indices match.

Full static suites pass, including 1,487 new palette/advice checks and the
existing 2,128 headwear matrix checks. Live elimination of the patches and
neck appearance still need confirmation; see
[Crinos hidden-head depth follow-up](CRINOS_HEAD_DEPTH_0457.md).

## Current follow-up: 0.4.56

Target: Crinos makeup restoration and smaller head-worn accessories.
User-confirmed: .55 head orientation and **scale 0.6** are correct; makeup
hides in Crinos but fails to return in human forms. .51 split-screen repair
remains confirmed. Do not change head/body assets, form scale, healing,
Q timing, harness/carry, multiplayer ownership, or deferred shove animation.

Invalidate every body registration for the exiting character immediately,
without waiting for native pooled-instance reset. Gate compositor/face scope
on the live owner profile, and request model plus texture refresh on changes.
Keep saved makeup untouched; emit read-only saved-makeup counts on transitions.
Glasses are visible again. Contract static head-mounted clothing by 0.6
around the animated Bip01_Head pivot, including placement offsets, and
publish the corrected matrix to the instanced shader. Do not scale the
replacement head twice or alter shared animation bones/model scripts.
Skinned hoods and clothing involving other bones remain native.
Retain head-only hat/mask locations when entering Crinos; other clothing
damage, Lupus/Hispo drops, and manual Strip/Dress remain unchanged.

Lua/mod/Java .56 with rebuilt JAR. Static tests are not in-game acceptance.
Makeup return and actual accessory fit still need the focused live retest in
[Crinos headwear and makeup](CRINOS_HEADWEAR_0456.md).

## Current follow-up: 0.4.55

User explicitly requests Crinos head scale **0.6**, not the previous .675.
Keep the user-confirmed rotations/offsets. Hide makeup and glasses/eye-slot
accessories only in ready Crinos rendering, without unequipping, deleting
saved makeup, changing protection or mutating remote appearance snapshots.
Filter native temporary worn visuals and COPY saved body-visual lists.
Scope both population and texture composition; restore scope even on errors
and across nested non-Crinos renders. Human appearance returns through normal
model reset. Head-not-ready fallback stays vanilla.
Lua/mod/Java .55; rebuilt client JAR required. Keep .54 healing, .51 ownership
and voice fixes, GLB/PNGs, wolf rendering and deferred shove code untouched.
See [implementation and retest](CRINOS_FACE_VISUALS_0455.md).

## Current follow-up: 0.4.54

User report: glass/deep wounds close in Crinos, but a fully healed-looking
character continues limping through sleep, vehicle use and form changes.
Ordinary regeneration must finish the injury state, not merely visible flags.
Detect retained glass/bullets/stitches and nonzero wound timers; expel ordinary
foreign bodies and remove mature stitches BEFORE clearing removal-generated
wounds/timers. Existing hidden states age through the normal regeneration
window, so no fresh save or blanket body restore is required. Never force
WalkInjury/WalkSpeed or suppress unrelated injuries/equipment penalties.
Failed cleanup retains mature progress and logs once for safe retry.

Requested modest survival rebalance: ordinary HP/bleeding taper throughput
reduced 20%; wound completion 75s Crinos / 225s Hispo-Glabro. Preserve bite and
Wyrm 300/900s clocks, including hidden bite timers, and all silver blocking.
Healing clocks are keyed by character rather than shared offline online IDs.
Lua/mod .54; Java remains .52 unchanged. Head orientation is user-confirmed;
current requested head scale is .675, awaiting size confirmation. Do not touch
head assets, .51 split-screen/voice fixes or explicitly deferred shove work.
See [healing repair and playtest](HEALING_REPAIR_0454.md).

## Current follow-up: 0.4.53

The user's .52 retest confirms the head is upright but still backward.
Preserve that confirmed up axis, scale 0.5 and zero offset; apply a 180-degree
facing correction about fitted head-local X. Direct mount becomes 180 0 -90;
inverted self mount becomes 0 0 90. Assert both preserve up and negate forward.
Definitions/mod .53; Java remains byte-identical .52. GLB, PNGs, body scale,
split-screen, voice and attack code untouched.
Shove still shoves per user retest. Await fresh .52/.53 CrinosAttackDiag log;
do not call the attack fixed or blame held equipment. See
[facing-only retest](CRINOS_HEAD_FACING_0453.md).

## Current follow-up: 0.4.52

The user confirmed .51 fixed the reported split-screen problems. Lock those
HUD/network/controller changes and the 200/400ms Q voice gates.
Current playtest exposes the authored Crinos head facing backward/rolled onto
its right side and about 2–3x too large. Body-space fitting did NOT justify
the previous zero-rotation mount. Restore the earlier placeholder orientation
using the user's recorded Blender quaternion, converted to glTF space, while
querying the engine's actual self-attachment inversion flag. Apply model-script
scale 0.5 to the HEAD ONLY; zero offset, body/form scales, GLB and PNGs unchanged.
Log chosen mount and actual instance scale. Fit remains pending live retest.

The user explicitly confirmed testing the shove with empty hands. The toolbox
in one screenshot does NOT explain away that test. Keep the animation issue
unresolved/lower priority; add two read-only local swing diagnostic samples
for loaded nodes, eligibility and current clips, without changing attack rules.
Definitions/mod/Java .52; rebuilt JAR required. See [fit and retest](CRINOS_HEAD_FIT_0452.md).

## Current follow-up: 0.4.51

Online multiplayer takes precedence over split-screen. Keep native
sendClientCommand(player,...) and server authority. Replies now carry the
server-selected recipient online ID; in pure local play the bridge passes the
exact recipient object. Never apply a tagged reply to a different local actor,
or guess a recipient for untagged replies with multiple local players.
Howl/visual broadcasts retain their existing owner-based paths.

Rage HUDs, HUD controls, shift/howl channel displays and Crinos countdowns are
per-character; global getPlayer must not select their owner. Preserve the
working .48 native title-drawing fix and the native controller radial lifecycle.
D-pad-down gets a Rage panel toggle immediately after Howl, using wta_shift.png.
Keep the primary HUD.instance compatibility alias strictly tied to slot zero.

Java Q voices use a per-character monotonic real-time gate: 200ms standing,
400ms crouched. Suppressed presses do not emit audio, world noise, text or
pending Crinos roar effects. Do not reset the gate during voice-profile refresh.
Crinos knockback stays server-gated at five seconds; full Howl stays unchanged.
Definitions/mod/Java .51. No model/PNG, balance, corpse, server gameplay,
unarmed swing or native weapon changes. See [evidence and tests](LOCAL_PLAYERS_VOICE_0451.md).

## Current follow-up: 0.4.50

Empty-handed, standing Crinos uses Bob_Attack1Hand01_Hit in place of the shove
pose, via one additive, condition-gated player/shove node. Keep native ShoveAnim
flags and exactly one collision event: this is NOT a damage/knockback rewrite
or a hidden equipped weapon. Only empty primary AND secondary hands qualify.
Ground stomps, armed shoves/attacks, other forms and corpse/grapple states stay
on their existing nodes. Play verified LongSpikedClubHit on local zombie-contact
callbacks, never a miss; refuse missing sound events instead of guessing.
Observer animation eligibility uses existing validated visual snapshots, not
remote modData. Definitions/mod .50, Java remains byte-identical .49.
No GLB, PNG, Java, balance, corpse, controller/HUD or wolf runtime edits.
See [implementation and focused test](CRINOS_ATTACK_0450.md). Native animation,
contact feel and two-client audio remain unverified until playtested.

## Current follow-up: 0.4.49

Replacement static Crinos head uses the wolf UV atlas for every shipped coat.
White/Black join Timber/Brown/Blonde/Brindle through the existing shared registry
and startup grid. Keep saved Timber key `default`, identity locks, per-instance
textures, pending/retry behavior and human head/hair/dress masking.
The user dropped the proposed female F_ texture set: both sexes use the authored
CrinosBody atlas; female UV/neck fit still needs a live check. Preserve every PNG,
including the transparent human-head area. No head scaling or vertex/UV edits.
Keep zero mount rotation/offset and scale 1 as the new export's fitting baseline.
The old exported head used BLEND despite an opaque wolf texture; the user
confirmed disconnecting shader Alpha in Blender fixes the viewer rendering and
pushed the corrected export as 1c834fd. Preserve that exact GLB without edits.
Definitions/mod/Java .49; ship the rebuilt JAR, not only Lua. All prior gameplay,
HUD/controller, harness/gear and corpse behavior stay frozen.
See [implementation and retest](CRINOS_COATS_0449.md). Viewer appearance is
user-confirmed; head-bone alignment and body fit in game are NOT yet confirmed.

## Current follow-up: 0.4.48

Oct 8 Deck console confirms .47's drawTextCentreStatic crashes on undefined
getScrollX/getScrollY and aborts the entire HUD prerender before body content.
This supersedes the .47 Static-helper recommendation below. Draw the title
through native UIElement.DrawTextCentre with actual getXScroll/getYScroll
offsets; do not alter collapse state or patch vanilla globally. Tests must
not invent scroll aliases, must reproduce the old failure, and must verify
the expanded meter after the title draw as well as collapsed updates.
Only HUD drawing and version metadata change; all .47 controller work stays.
Definitions/mod .48, unchanged Java .46. Live Deck rendering remains pending.

## Current follow-up: 0.4.47

Deck: real copied mod folder fixes missing trait; official ZombieBuddy
2.3.4 loads the existing Java 0.4.46 module. No additional loader jar.
The title fix must use drawTextCentreStatic because the normal helper
suppresses all text when collapsed. Keep strict red thresholds and live
updates. Native social wheel gets Howl/Strip/Dress, native map wheel gets
five forms/Resist, no nested Garou menu or standalone forms key handler.
Preserve native entries, pause gates, focus and release/cancel behavior.
Rage toggle stays optional but is unbound under a new binding id to retire
saved G/alternate shortcuts. AtomUI diagnostic-label fallback prevents the
observed getSimpleName exception from aborting printed-media focus transfer.
No balance, Java, art, or transformation-rule changes. See
[Deck follow-up](PLAYTEST_FIXES_0447.md); live Deck verification pending.

## Current follow-up: 0.4.46

Oct 7 evening: user confirms formatted spacing, auspices, howl audio and
corpse pickup/deposit rotation. Occasional trunk alignment is explicitly
deferred. Changes: collapsed live bold-style Rage title (red <25 or >75);
contentment pull 0.30 -> 0.21, damage-dealt Rage 0.10 -> 0.15; native
medium fur-insulation floor on Crinos/Hispo/Lupus; public console rewrite
helper with a cross-package woven execution regression. The >=95 pause,
howl rate and all confirmed mechanics remain unchanged. See
[playtest notes](PLAYTEST_FIXES_0446.md) and
[copy and coat guide](COPY_AND_COATS_0446.md). Awaiting live verification.

## Current follow-up: 0.4.45

Oct 7: Werewolf Startup gains a Baseline Rage row (30-70, one per auspice,
lore in the tooltips) locked with true form and coat; Rage drifts toward
that baseline when the character is fed and watered (no Hungry / Thirst
moodle, Well Fed on top), paused in the 95+ frenzy band; howls settle on
the baseline too. Lore names moved to tooltips: Werewolf trait, Rage panel,
Werewolf Startup (opened from the panel's Startup button, no world entry),
Werewolf Guide, Werewolf Cheats (admin-only world entry; "/garou cheats").
"/garou" commands now work in the Lua console (Java rewrite) and in
multiplayer chat (ISChat wrap). Rich text gaps fixed everywhere via
WTAGarou.Rich. See [note](STARTUP_AUSPICE_0445.md). Unverified in game.

## Current follow-up: 0.4.44

Oct 6 late playtest: Definitions reload no longer wipes the Howl / Silver /
VehicleShift module functions (silent howls); rage from damage dealt
halved; shoulders ground grab held at the carry distance; a body dropped
into a trunk / seat / trailer plays as a pose-only idle without the deferred
rotation. Lupus drunk driving (0.4.43) confirmed in game. Unverified: the
four 0.4.44 changes.

## Current follow-up: 0.4.43

Lupus drives like a drunk: B42 intoxication held at 65 (DRUNK moodle 3)
while Lupus is the driver, real value restored afterwards; the vanilla car
controller supplies the input delay and swerve. The old module had been a
silent no-op on Build 42. Unverified in game.

## Current follow-up: 0.4.42

User confirmed the .41 silver cue, wolf true form clothing, reversed drag
walk, trunk drag-out offset, stowing, vehicle impact sound and scaled audio.
Fixes: grip-aware corpse offset (extra follows the node offset's sign), still
tail during corpse pickup/put-down, 5 s knockback cooldown on standing Q roar
(noise every press), Hispo/Lupus melee reach x1.3, picker named Garou Startup
everywhere. See [note](PLAYTEST_FIXES_0442.md).

## Current follow-up: 0.4.41

Silver burn reaction only; .40 stays frozen and unverified. Each burn
application (fresh contact burn per part, every silver weapon hit) reaches
the owner through one path (`Silver.announce` -> `SilverReact`): notice,
red `SILVER BURN: part` warning for 3 s, halo, and a per-form cue at most
once a second — vanilla "PainFromScratch" voice for Homid/Glabro, the
Crinos/Hispo/wolf growls for the other forms. Burn mechanics untouched.
See [note](SILVER_REACTION_0441.md).

## Current follow-up: 0.4.40

Playtest fix batch; the user confirmed the .39 Berserker balance, vehicle
damage/restrictions, window smash and picker lock, so those are frozen with
every earlier lock. Picker: selected true form/coat/gear shows a heavier
border and tinted background, no extra text; locked footer names Wolf gear.
Console: `WTAGarouResetIdentity()` / `garou("identity reset")` and a Testing
panel button; slash commands cannot work in the Lua console. Wolf corpse
handling (Java): pickup/lay-down clips play Wolf_eat retimed to the human
action (wolf marker, deferred rotation off), container throws stay idle,
gait clips while dragging play the wolf pose backwards, stationary clips
while dragging/throwing switch deferred rotation off (vehicle-drop spin).
Bite filter adds isGrappling and the Java corpse-clip flag. Wolf grapple
offset: Hispo +1.0 m, Lupus +0.7 m, only while dragging. Crinos/Hispo stow
and put down corpses through vanilla becomeCorpseItem / pickUpCorpseItem.
Mod audio: every cue scaled by the Sound Effects slider and capped at 75%.
Seated shift damage plays VehicleCrash1. Nothing in .40 is confirmed in game.
See [engine findings, change contract and playtest](CORPSE_AUDIO_0440.md).

## Current follow-up: 0.4.39

Feature push on top of an unverified .38; every .38 and earlier lock stands.
Berserker breed: trueForm "Glabro", label "Berserker", BaseForm Glabro, Crinos
RageRequired equals its cost (10), drain CRINOS_DRAIN_BERSERKER (-0.5/s), exit
lock CRINOS_LOCK_ABOVE_BERSERKER (35). Everyone else: Crinos entry 55, drain
-1/s, exit lock CRINOS_LOCK_ABOVE (75). TransformRequest denies with
`crinos_locked` (carries lockAbove); forceDepletedShift ignores the lock.
Bulk forms Crinos/Hispo: vehicle entry blocked in Java and Lua; completed
seated shifts damage the seat door and window by VehicleShift.damageFor
(Crinos 38 / forced 75, Hispo 25), 2% full smash, VehicleEjected to the owner
who exits and, when smashed, takes setScratchedWindow + PainFromGlassCut.
Window climb: open unbroken IsoWindow is smashed bare-handed first; the climb
itself is never skipped. Identity picker: three true forms, staged coat,
Confirm with an Are-you-sure dialog, server lock on data.identityLocked;
wolf gear stays changeable. Nothing in .39 is confirmed in game.
See [design, change contract and playtest](BERSERKER_BREED_0439.md).

## Current follow-up: 0.4.38

User confirms .37 standing Q knockback, seated wolf head look and corpse
pickup orientation. Preserve those paths and all confirmed harness/gear/coats.
The remaining release clip is Bob_LayDown_Person_OnBack, missed by the original
pickup/putdown predicate. Include LayDown only with person/corpse/deadbody.
Do not alter the player's own death or ordinary lay-down/sleep behavior.

The pickup bark persists in .37. The strengthened filter checks native
PlayerDraggingCorpse and performing-grab state, both at the swing event and
before a deferred bite sound on the next local update. Attack/damage timing
is untouched, genuine damage still yelps and deliberate Q is unchanged.
Bounded reason/state diagnostics support the next playtest; do not declare
the bark fixed from fixture tests. Radial idle title is Resist The Change,
preserving its line break and the existing active countdown.
See [follow-up and test](CORPSE_FOLLOWUP_0438.md).

## Current follow-up: 0.4.37

User confirms .36 harness fit, attachments and coats. Freeze those systems
and authored assets. No female Crinos or Crinos head changes were requested.
Standing Q roar now explicitly shares completed-entry knockback, server target
selection and owner/replay rules. Keep the existing 45-tile roar noise, including
server-side noise for accepted MP requests; crouched growl has no burst.
No extra Rage cost or long ability cooldown; a 250ms request flood guard applies.

Corpse pickup/putdown uses the authored wolf idle pose and Translation_Data,
never donated human root rotation. Keep native corpse interaction and the
player's own death path intact. Suppress bite audio on grapple grabs only.
Eating/drinking takes a full-body mask at creation and after layer transfer.
HeavyBreathing must map to idle, not eat.

Furniture Ctrl-look uses the engine's smoothed normalized head input and native
head-angle limit, applies model-space yaw at the head pivot after pose sampling
and before model/skin transforms, and never restores humanoid spine twists.
Standing/get-up/dead/human/Crinos paths remain untouched.
See [implementation and focused playtest](PLAYTEST_FIXES_0437.md).

## Current follow-up: 0.4.36

User confirms .35 harness is visible, follows walking/sitting and changes
to Camo immediately. Keep all of that. Its oversize/constant-size fault is a
shader-path mismatch: B42 Shader.startCharacter uses xfrm for static meshes
but the palette for skinned meshes. Harness must share the body's FinalScale
factor, BODY_SCALE times the CURRENT form scale, with exact slot restoration.
Do not also bake that multiplier into its xfrm. This supersedes the earlier
harness matrix-scale rule, not the unchanged static bag/cargo rules.
Do not retune authored art or the existing form scales to compensate.
Crinos Q roar is logged; the existing AoE runs on completed Crinos entry,
not Q. No combat behavior change or Crinos head work in this patch.
See [scale correction and playtest](HARNESS_SCALE_0436.md).

## Current follow-up: 0.4.35

The .34 playtest confirms the corrected hook runs and both carrier variants
attach, but the harness model has no skin data. Native attached-item loading
imports static first; the mesh asset cache uses mesh name without static mode.
Prime ONLY the two allowlisted harness skinned scripts on entry to
`ModelManager.addStaticForcedTex`. Native carrier construction then continues
unchanged, using the already-requested skinned mesh. Keep .34's initModel hook.
Never repair this by copying wolf skin data, mutating/reloading shared meshes,
or changing bag/cargo transforms. A full restart is required to clear the
old mesh cache. See [cache diagnosis and test](HARNESS_CACHE_0435.md).

## Current follow-up: 0.4.34

B42.21 builds the harness skin palette in base render-data
`initModel(ModelInstance, parentData)`, not `init()` (which takes no arguments).
Prepare before that base method; the world subclass caches model and texture
after its super call. Fixture tests must preserve this split and inheritance.
Optional PZ_JAR checks inspect the user's real class bytes and weave the actual
ZombieBuddy advice without loading the game. Do not distribute engine binaries.
The .33 playtest confirms bags visible but no harness in either variant.
Preserve the bags and assets; .34 rendering still awaits a full-restart test.
See [harness follow-up](HARNESS_FIX_0434.md).

## Current follow-up: 0.4.33

The authored harness is skinned to the wolf, not rigid cargo. It retains its own
skin data and shares the wolf animator before palette initialization, with no
Spine2 mount, self transform or inverse-scale compensation. Keep all saddlebag,
mouth and hotbar transforms unchanged. Preserve the authored assets and all
gameplay contracts below. Black/Camo is owner-validated saved cosmetic state,
replicated to observers without changing peer mod data. Full implementation
and the required in-game checks are in [Wolf Gear notes](WOLF_GEAR_0433.md).

## Current follow-up: 0.4.32

Latest user playtest confirms the Timber load, Crinos head yaw, hidden Dress
region, coat changes, and initial wolf corpse. Lock those behaviors and preserve
the user's efb4a07 attachment tuning. Reanimation is a separate human zombie
and is deliberately not changed in this maintenance patch.

Ground get-up must recognize Bob_SitGround_Out and Bob_SitGround_OutQuick even
when forceGetUp is false. Reuse Wolf_getup forward once, restoring pooled flags;
do not regenerate the user's animation assets. Bob_SitGround_EndDeath is death.

Firearm kit uses AmmoType.getItemKey() for B42 ammo objects. The registry
representation base:bullets_308 is not an AddItem key. Legacy full-type strings
remain supported; report unknown types rather than guessing. Include the native
double holster for two pistol slots, without changing clothing-slot exclusivity.

This build is Resolve (transformation/Rage). Hunter trait, craftable silver
ammo variants and future skill buffs belong to 2.0 Wits and are deferred.

## Current follow-up: 0.4.31

The latest true-form request overrides the earlier universal-Homid rule.
Human-born defaults to Homid; Wolf-born defaults to Lupus. Every other form
reverts at displayed zero Rage, before moodle gains rescue it; the chosen base
form does not repeatedly transform at zero. Startup selection applies the base
once when initially Homid. Save/load retains the current form and identity.
Changing identity later is not a free-shift command. Only allowlisted identities
and coats are accepted from the owner, and not during a pending shift.

Wolf-born corpse visuals use a temporary HumanVisual copy and a separate native
atlas AnimSet with Wolf_dead. Do not change the corpse object type, inventory,
loot, saved human appearance, resurrection rules, or reset dying animation tracks.
Missing assets and decomposed skeletons keep native fallback. Actual corpse
appearance, persistence and multiplayer remain pending visual testing.

Silver contact keeps one-second mild onset and wash/bandage/regeneration rules.
Severity follows a 60-second S-curve, 2 to 75; damage factor .04 to .85. Guard only
the matching native silver burn tick: stop at 20 overall or 5 part health. No
health refund, global invulnerability or reduction to external damage.
Fresh safe raw food is protected; rotten, tainted and explicitly poisoned food
retains vanilla effects. Frozen-food unhappiness remains completely unchanged.

Burst radius is now 3 tiles, otherwise preserve .29 completion/LOS/authority rules.
Preserve user-tuned attachment transforms. Republish actual item aliases on
equipment events. Hide held containers only, without unequipping them or altering
worn saddlebags. Traversal phases keep native durations. Ground forceGetUp and
sit-exit names select the authored forward-once reversed asset.

Crinos hides Dress in addition to the replaced Head, not chest/legs/clothing.
Head mount has a quarter-turn correction pending playtest. Timber is the author's
new default; Brown is the renamed original. Do not restore obsolete filename
references or regenerate authored meshes. Brindle/Timber swatches only were built.

## Current follow-up: 0.4.30

Crinos cosmetics keep the native human skeleton, scale, graph and clothing.
The prototype head and rigid neck cuff are render-only additions, not worn items.
Head masking and hair suppression require a successfully attached replacement.
Coat-selected base fur enters the normal compositor, not a DrawChar texture
override; body masks, clothing, blood/dirt and saved human identity must survive.
No tail or digitigrade changes. Pool reuse must clear body-role bookkeeping.
Missing assets wait with bounded retries and missing bones leave native visuals.
The GLB is author-replaceable; NEVER rerun its generator over an authored edit.
See CRINOS_COSMETICS_0430.md for static vs skinned limits and test status.

## Current follow-up: 0.4.29

Crinos burst lives in the authoritative completed-shift path, never visual
refresh or a new client-requestable power. One reservation produces one
burst. The shared filter checks zombie type, NPC adapters, life, same floor,
radius and collision LOS (doors included). Native stagger only: no weapon
Hit call, damage/XP/Rage awards, forced floor flags or coordinate movement.
Server-owned zombies are mutated on server; selected client-owned IDs are
broadcast and only their current owning client mutates them, once per serial.
Range is rechecked at receipt. Network transfer/drop/latency remains an
in-game test concern; do not advertise this as verified multiplayer.

Coat picker stays at least 40px from the viewport's left edge, not x=0.
It still follows the HUD's x when farther right and starts 12px below it.

## Current follow-up: 0.4.28

The user confirmed Blonde survives save/continue and the saddlebag appears
and disappears with the worn bag. Preserve those behaviors and the latest
author positions from 9039285. Slot offsets and pivots intentionally use
different coordinate spaces; document this rather than swapping axes.

Silver: one-second onset, INITIAL_BURN 2, growth 0.05/s capped at 30 (never
lower an existing larger burn). Tick damage scales from 4% to 20% of vanilla
with severity. Only the native burn damage expression inside DamageUpdate
is reduced; ordinary wounds, weapon-hit multipliers, washing, bandaging and
healing remain unchanged. Never refund health as a substitute. A healed
or unmarked part has no damage override, including after trait removal.

Coats: shared allowlist entries drive buttons and texture paths. Java paths
are restricted to media/textures/Body/WTAGarou_Wolf_SUFFIX.png. No directory
scan, client-supplied arbitrary path, or shared model mutation.
The picker starts 12px below the existing main HUD, screen-clamped.

Sit/get-up: match sit-on-ground before generic on-ground death handling;
authored reversed get-up plays forward once. Native reverse/loop parameters
must be restored after success or exception. No transition tiling for the
one-shot sit/get-up poses. Visual results remain pending the next playtest.

## Current follow-up: 0.4.27

Preserve the confirmed 0.4.26 harness/cargo matrix-scale path. Bag import
unit compensation affects tuning offsets/pivots only. Do not resize meshes
or shared models to fix displacement. Each wolf coat is stored per character
and selected from a server allowlist; only render-data texture changes.
Do not infer the client's split-screen index from server playerNum.
Keep original versus unset distinct, so saved Original suppresses the prompt.
Stomp matches both Stomp and Stamp names; movement slowdown stays separate.
Window action duration remains human-native, with wolf pose substituted.
Full-body stationary attacks and inert gait sublayers survive native mask
transfers; moving attack behavior stays unchanged.
The new sit idle holds the authored final pose; get-up reverses the authored
sit. These are generated assets, not newly animated breathing.
The initial forced-Crinos warning is 10 seconds. Resist still shortens later
warnings and retains the established hidden-rest formula.
See [patch and test notes](PLAYTEST_FIXES_0427.md). In-game results pending.

## Current follow-up: 0.4.26

Wolf gear must use matrix-based body-space scaling on both instanced and
non-instanced rendering paths. Do not also apply wolf FinalScale to it.
Top-level harness/bags retain the form multiplier; ordinary cargo cancels it.
Descendant weapon parts inherit their parent matrix without a second scale.
Publish the completed xfrm to ShaderPropertyBlock after placement; its matrix
is a copy, not a live reference to xfrm.
ModelInstance.reset forgets all role/scale/bone/attachment bookkeeping, without
writing old values into a recycled instance. Human preview gear remains vanilla.
Stationary attacks use the full wolf body on sublayers, including after native
layer transfer; moving attacks, root layers, movement locks and strafe behavior
remain unchanged. Stomp playback uses WolfGait.STOMP_SPEED, separate from bites
and gait. The authored sit clip is still pending the user's replacement.

## Current follow-up: 0.4.25

Attachment bone/scale preparation occurs before the transform matrix is
built, not only at DrawChar. Action override props are hidden on wolves;
ordinary held items keep mouth/secondary semantics. Chair root protection
is scoped to furniture nodes, not death. Gait slowdown never changes the
derived bite clock (`WolfGait.ATTACK_SPEED`). Glabro costs 20 Rage; Glabro
and Hispo carry bases are 14 and 17 (26/32 at Strength 7 before penalties).
Confirmed transforms clear HUD countdown/channel display. Preserve literal
nil/nil shift arguments and the existing death handoff. Visual outcomes
remain unverified; see [0.4.25 notes](PLAYTEST_FIXES_0425.md).

## Permanent user requirements

These requirements take precedence over cosmetic experiments and convenience
refactors. They were repeated after failed playtests and are not optional
tuning defaults. Changing them requires the user's explicit new instruction.

### Shifting: no action animation

- Every transformation uses **literal `nil, nil`**.
- Never substitute `"None"`, `CharacterActionAnims.None`, `""`, `WashFace`,
  `BuildLow`, or any fallback animation.
- `WTAGarouTransformAction:setActionAnim` deliberately ignores arguments
  and forwards only `ISBaseTimedAction.setActionAnim(self, nil, nil)`.
- Suppress `PerformingAction` and set `IsPerformingAnAction=false` after
  the setter and during the active shift. Do not repeatedly call the
  setter in `update`, since the setter can reactivate the action layer.
- Preserve forced crouch and free movement during shifting. Restore the
  prior crouch state on completion/cancellation.
- Preserve the timed-action duration, progress bar and server confirmation.
- Do not globally monkeypatch ISBaseTimedAction. Howl keeps Drink.
- Do not clear another action's variables when cancelling an unstarted shift.

The September 20 playtest log explicitly records
`shift action anim: nil, nil ok=true err=nil`, yet the user saw the
raised-arms pose. Therefore testing the arguments alone is not enough.
The [available BaseAction implementation](https://github.com/piromasta/PZDecompiled/blob/main/zombie/characters/CharacterTimedActions/BaseAction.java)
sets `IsPerformingAnAction=true` in `setActionAnim(String)`, regardless
of the argument. This is older reference source, not a verified dump of
the user's B42.20.4 engine. The corrective patch clears that known
animation-state flag as well as keeping the arguments nil. Its visual
outcome still needs the user's in-game test.

### HUD

- First position: `x=floor(screenWidth/12)-16, y=0`, constrained to the screen.
  The 16px left nudge was requested after the successful 0.4.2 playtest.
- Preserve user-chosen placement and pin/auto-hide state in player mod data.
- Migrate only unversioned saved coordinates exactly matching the previous
  default at the current resolution. Versioned and custom positions stay put.
- Clamp restored coordinates after a resolution change.
- `WTAGarouResetHUDPosition()` restores the requested top-of-screen default.
- Draw Rage numbers in **every** form, even with missing form color data.
- Rage bar color depends on Rage: gray at 0, saturated red at 100.

The supplied log showed repeated `WTAGarouHUD.lua:132` errors indexing
`form.color.r` when Hispo lacked a color. The new HUD does not read a form
color to draw the meter. A Hispo color is also supplied for other consumers.

### Visual scale and mesh safety

- Homid: 1.00; Glabro: 1.08; Crinos: 1.25; Hispo: **1.35**; Lupus: 1.00.
  Hispo changed from 1.25 in 0.4.9 under the September 23 request for
  another 5–10% size increase: 1.35 is exactly 8% larger. Lupus is unchanged.
- As of the successful 0.4.7 wolf playtest, these remain **form multipliers**.
  The user reported horse-sized wolves. Version 0.4.8 adds a separate 0.60
  wolf-body render normalization, pending in-game calibration. It applies
  only when the draw instance is the registered wolf mesh. Hispo is now
  1.35 times Lupus; human fallback, speed, reach and collision are untouched.
- Change visual multipliers only, not damage, speed, collision or carry stats.
- Retain WTAGarou-owned ZombieBuddy scaling without DynamicModelScale.
- The user confirmed this independent Java scaling works in game.
- With mesh swapping off, never call unexposed HumanVisual getters to clear
  an override the mod did not set. The playtest exposed
  `getForceModelScript` as unavailable on that Lua object.
- Keep wolf model/animation development separate from these regression fixes.

### Bag-slot observation

No bag exclusivity change is part of this patch. The
[official B42.13 notes](https://theindiestone.com/forums/topic/88501-build-42130-unstable-multiplayer-released/)
document moving satchels from `back` to a separate `satchel` body location.
Wearing a satchel alongside a back-slot bag is consistent with that change;
it is not evidence that Java scaling modified clothing slots.

## Required verification before committing

```bash
bash WTAGarou/tests/run.sh
```

This checks syntax, the existing visual tests, and channel/HUD regression
tests. The shift mock intentionally models the engine setter turning the
action layer on for a nil argument, then verifies our code turns it off.
It also injects hostile future config values and direct animation calls.
The HUD test removes **all** form colors before rendering all five forms.

For Java changes, additionally run:

```bash
bash WTAGarou/java/build.sh
bash WTAGarou/java/test.sh
```

GitHub Actions runs the Lua regression suite on matching pushes and pull
requests. A failing check flags the regression; this workflow does not
change branch-protection settings or guarantee every possible engine
behavior has been tested.

Local verification for 0.4.2:

- 28 visual/registry/starting-item mock assertions.
- 539 channel/HUD regression assertions.
- Negative controls: the previous channel fails because the action layer
  stays enabled; the previous HUD fails the startup-position test.
- Lua 5.1 syntax and Git whitespace checks pass.

Local verification for 0.4.3:

- 28 visual assertions, 544 channel/HUD assertions, 28 panic-trace assertions.
- Layout migration preserves custom coordinates and pin state, and cannot
  repeatedly shift a versioned layout left.
- Panic tracing is disabled by default and read-only. Missing APIs return
  unavailable values, never a fabricated zero; logging has time/line limits.
- The latest user playtest confirmed Hispo Rage text and believable scale.
  The reported frightened-moodle flicker is **not yet diagnosed or fixed**.
  See [the panic trace guide](PANIC_TRACE.md) for the next test.

In 0.4.3, the Java JAR remained at 0.4.1. The current **0.4.4-direct-wolf**
release includes a new **0.4.4 Java JAR** and may require fresh ZombieBuddy
approval. The user explicitly requested Skully-style timing and work on a
real player-to-wolf cosmetic transformation. See
[the current implementation and playtest limits](WOLF_COMBAT_044.md).

Current additional contracts:

- Do not change global player AnimSet XML to speed up everyone.
- Shorten recovery only at the actual SetMeleeDelay event; never repeatedly
  divide the per-tick countdown.
- Do not double the standalone Skully swing handler.
- Direct wolf rendering keeps the same IsoPlayer, inventory and gameplay
  state machine. No animal/mount spoofing is part of this implementation.
- The direct-wolf escape command and return-to-human path are required.
- Validate embedded animation names, not just filenames. Preserve motion
  binary data when normalizing names.
- Treat the direct-wolf path as a prototype until its appearance, movement
  and combat have actually been tested in game.

Tests are not an in-game visual verification. Report that distinction
explicitly; do not promise that mock checks make regressions impossible.

## Confirmed wolf milestone and next control pass

The user confirmed that 0.4.7 renders both Lupus and Hispo and allows attacks.
Preserve the scoped native clip loader and direct IsoPlayer body substitution.
That playtest also reported oversized wolves, poor movement/turning, doors
not opening and "Walk to" not working. Solo rendering success is not
multiplayer verification or proof of complete player-action compatibility.

Version 0.4.8 disables animation-driven wolf root rotation while preserving
native player turn rates. It does not yet provide human-equivalent movement
displacement or a distinct heavier Hispo turn radius. Keep those limitations
explicit. See [the focused patch and next test](WOLF_CONTROL_048.md).

Version 0.4.9 addresses the next playtest with a namespaced derived-clip
adapter that retains player timing/identity and directional root movement.
It does not copy human skeleton poses into wolf bones. Action bone masks
are retained where the named bones exist, rather than giving every upper
layer full-body/root influence. See [motion and death follow-up](WOLF_MOTION_049.md).

The new log also showed the engine selecting the null enum overload of
`BaseAction.setActionAnim`. A short Java scope around the unchanged literal
`nil,nil` setter skips null dereferencing for that transformation owner only.
The Lua base class is not monkeypatched, and other actions retain normal
behavior. Both successful and exceptional paths must release that scope.

Version 0.4.10 moves all wolf travel to the `Translation_Data` marker
(Bip01 held flat in the GLBs), selects gait by clip name only, and adds the
berserk-Crinos Rage engine, per-form stamina refund, Java knockdown
stability and per-form regeneration. Moodle-to-Rage had been silently dead
on 42.20 because of the UPPER_SNAKE `MoodleType` rename. See
[berserk, motion and regeneration notes](BERSERK_MOTION_0410.md). The
0.4.9 death path (Wolf_death, then human corpse pose) was confirmed by the
user and is unchanged.

Version 0.4.11 fixes the shift strip (Build 42 `ItemBodyLocation` objects
were never matched, so nothing dropped), adds per-form voice, footsteps and
sight (Java `StealthRuntime`: Callout, DoFootstepSound(float), IsoZombie.spotted),
WolfMod body sounds for Lupus/Hispo, and an EXPERIMENTAL worn-container
saddlebag attachment on the wolf spine. Silver-burned parts heal at the
vanilla pace (never "not at all"). See
[audio, stealth and strip notes](WOLF_AUDIO_STEALTH_0411.md).

Version 0.4.12 answers the 0.4.11 playtest: the saddlebag attach no longer
re-enters itself from `OnClothingUpdated` (Kahlua stack overflow on wearing
a bag or hat) and is drawn on the wolf (sub-models attached at `WTAGarou_`
attachments are exempt from the human-gear hide); wounds age individually
and close only after their own per-form window (never "instantly" once the
form has been held); the Rage engine runs from `OnPlayerUpdate` in single
player and from the `OnTick` sweep on a dedicated server, throttled per
player; the wolf rig (human twist bones, limb reparenting, `Bip01`
counter-rotation) is re-stripped on every wolf track start; masked
sub-layers are inert for gait/idle clips and whole-body (`Bip01`,
descendants) for actions; `[Perf]` counters print every ~5 s while a wolf
is active. A `Strip` action queues vanilla `ISUnequipAction`s for the
items a shift would tear, damaging nothing. See
[playtest fixes](PLAYTEST_FIXES_0412.md). The 0.4.7 loader/body path, the
0.4.9 death handoff, literal `nil,nil` shift arguments and the Homid
"Rage rises" design are unchanged.

Version 0.4.13 answers the 0.4.12 playtest: the `WTAGarou_Saddlebags`
attached location is registered at load (the `no such location` stack on
load and on every clothing change is gone) and the saddlebag is pinned to
the wolf spine bone by `parentBoneName` with its offset on the bag's own
attachment (it drew at the character origin before: the black slab under
the wolf); Crinos requires 55 Rage; the Garou panel hides on death; wolf
pain barks are rate-limited (0.8 s) so a grab no longer floods and mutes
the emitter; a Java `TraitsRuntime` gives every Garou form raw-meat immunity
(no POISON from dangerous uncooked food), gives Glabro/Crinos/Hispo/Lupus
paws (the barefoot scratch loop is skipped) and scales the player's
`WalkSpeed`/`RunSpeed` variables per gait and `getTurnDelta` per form
(wolves faster in every gait, crouched Lupus at about a jog, Lupus turning
faster than Hispo); the primary-hand item is drawn from the wolf jaw
(experimental mouth carry, `WTAGarou.EnableMouthCarry`). See
[playtest fixes](PLAYTEST_FIXES_0413.md). Everything else listed above is
unchanged, including the 0.4.7 loader/body path, the 0.4.9 death handoff,
literal `nil,nil` shift arguments and the Homid "Rage rises" design.

Version 0.4.14 makes Rage situational: `REGEN_PER_SECOND` is 0 for Homid,
Glabro, Hispo and Lupus and -1/s for Crinos only. A healthy Garou holds its
Rage indefinitely; it climbs with negative moodles (Panic weighted x2),
damage taken and dealt, drops with Unhappy/Bored, is pulled toward 60 by
Well Fed and by howling. The 100-Rage Crinos countdown, the 55-Rage Crinos
gate and the 0.4.13 changes are unchanged. (The 0.4.12/0.4.13 paragraphs
above describing "Homid Rage rises by design" are superseded here.)

Version 0.4.15 reworks what a shift does to clothing: per-form profiles in
`ShiftStrip.FORMS`, damage as whole points off a T-shirt yardstick (engine
default ConditionMax 10; Glabro 1 and keeps everything on, Lupus 1 + 1 hole,
Hispo 3 + 2 holes, Crinos 4 + 3 holes, the last three dropping), headwear
and masks dropped but never damaged, the safe list unchanged. The panel and
both radials show Human / Near-Human / Berzerker / Near-Wolf / Wolf; tooltips
open with the lore name in colour and use the default tooltip size only
(the oversized Rage line overflowed). Moon-phase radial icons plus a
crossed-out T-shirt strip icon replace the fox heads. See
[clothing, icons and names](CLOTHING_UI_0415.md).

Version 0.4.16 adds Dress, the counter-command to Strip: both Strip and
shift drops record exact item ids in the player's Wardrobe; Dress finds
them in the inventory or any bag and queues vanilla wear actions innermost
first, reporting every miss on its own Garou-panel line and keeping the
entry for next time. Glabro now wears only 0.1 condition per shift
(accumulated per item), a Rage-forced Crinos deals double points with the
same three holes, and the vanilla `ClothesRipping` clip plays once per
tearing shift. The Berzerker button has a red border. See
[Dress and wardrobe](DRESS_0416.md).

Version 0.4.17 answers the September 26 playtest: the Garou panel is two
columns (forms left, Strip / Dress / Howl right); the forced-Crinos countdown
is 15 s; the Knox infection is really cleared (flag, parts, timers and stats
together) so "At Breaking Point" stress and 100 Rage no longer stick to an
infected Garou; wolves bark only on acute damage types or a new wound, never
on bleeding/infection ticks; `ClothesRipping` is stopped by handle after
`RIP_SECONDS`; Strip entries stay pending until seen off the body and Dress
finds items by a Lua inventory walk and on the floor within two tiles
(grabbing them first); silver worn or held bare-handed inflicts a growing
vanilla burn that blocks regeneration on that part until it heals; wolf
forms keep off-hand and two-handed items; wolf sub-models (saddlebags, jaw
item) are scaled with the body and the jaw item is turned 90 degrees via
`WTAGarou.MouthCarry`. See [playtest fixes](PLAYTEST_FIXES_0417.md).

Version 0.4.18 makes the Knox virus a Wyrm bioweapon: an infected Garou sees
"- Wyrm Infection" with the purge progress in the health panel, Berzerker
purges it in five minutes (Near-Human/Near-Wolf in fifteen) and zombie bites
close on that same clock while other wounds keep the 60 s / 180 s windows.
The Berzerker tooltip says "Reduces wyrm infection." A paged Garou Guide
window with a persisted "Don't show again" tick box opens for new Garou and
from the panel's Guide button (draft copy). The wolf body mesh is rebuilt
from the animation GLBs' properly weighted mesh (the WolfMod body's weak
head weights were the head/neck squish) and the locomotion clips carry the
tail down-and-back instead of tucked. See [Wyrm, guide and wolf
mesh](WYRM_0418.md).

Version 0.4.19 answers the second September 26 playtest: `hasTag("Silver")`
(a Java exception per worn item, the start-of-game error screen) is replaced
by a `getTags()` name compare; every body-location table is read
case-insensitively because Build 42 hands back lower-case ids ("ears",
"rightwrist"), so jewelry and watches are exempt again and silver finds its
body parts; watches are never stripped or dressed; the Wyrm line is plain
"- Wyrm Infection" or "(purging NN%, M:SS left)"; the guide copy has no
mid-sentence colour tags; sadness drains 0.03/level/s; Crinos is depleted
when the panel reads 0; the form-shift cue repeats for the whole channel and
plays once on the forced Homid; Hispo bites and yelps with its own bark; the
trait adds skill boosts; the saddlebag sits higher and the jaw item is turned
across the jaws; a Lua stuck guard logs and releases movement locks in
human-bodied forms; Dress retries once when a wear action fails to queue.
See [playtest fixes](PLAYTEST_FIXES_0419.md).

Version 0.4.20 answers the third September 26 playtest: the Wolf Panniers
land in a worn bag instead of the key ring; a Hispo/Lupus locked in the
bite reaction is released after 2 s; bite/react/stagger clip names map to
`Wolf_hitreaction`; gait time-scaling measures stride as maximum
displacement so walk/jog/run no longer swap speeds; wolves may hold a
firearm in the jaws but never fire it; Dress skips what the form cannot
wear and reports what stayed off; attachment-point providers (belts,
holsters, vests) are never stripped; Howl sits on the main communication
radial; Stress weighs 0.4 and the server names the moodles behind a Rage
climb; silver rounds burn on hit and the Test Panel hands out a silver kit;
the giant belt knife and the saddlebag yaw are instrumented, not fixed.
See [playtest fixes](PLAYTEST_FIXES_0420.md).

Version 0.4.21 adds Resist: the forced-Crinos countdown can be cancelled
from the panel, the communication radial or a bound key; every Resist
shortens the next countdown (one second at a time, then logarithmically
toward half a second) and a hidden 3x-12x rest brings the urge back while
Rage stays at 95 or more; Rage under 95 or Crinos resets the cycle. Strip,
Dress and Resist have unbound key bindings. See [Resist](RESIST_0421.md).

Version 0.4.22 answers the September 27 playtest: the wear blacklist is off
(every form dresses; shift damage is the deterrent), the beast forms are 15%
bigger, panel notices last at least four seconds and wrap, the health panel
names Silver Burn parts in blue-grey, the Guide keeps its coloured keywords
with real spaces, the trait grants Cat's Eyes, wolf gait clips run at half
speed with the movement speed untouched, saddlebags are re-compensated when
the engine resets a pooled instance and take a Definitions-side transform,
the panniers container is obsolete, and "Reload defs" re-reads Definitions
in game. See [0.4.22 fixes](PLAYTEST_FIXES_0422.md).

Version 0.4.23 draws hotbar and secondary-hand items on the wolf through
`WTAGarou.WolfSlots` rules and shows a harness stand-in while any such item
is attached or a container is worn (bare wolf otherwise). Locked: items WITHOUT a rule stay hidden
(never drawn floating at the human attachment); a rule never touches the
primary-hand jaw item or the saddlebag; weapon parts follow their visible
parent; `restoreScale`/`restoreAll` undo every slot retarget and rename;
the harness never appears for our own stand-ins or for a two-handed
primary item. Attachment names, axis signs and the harness mesh are
unverified in game. See [0.4.23 wolf attachments](WOLF_ATTACHMENTS_0423.md).

Version 0.4.24 answers the September 27 evening playtest: "Reload defs"
uses the engine's `reloadLuaFile` (Kahlua has no `loadstring`); transition
nodes (`RunToStop`, `IdleToRun`, the 180 turns) keep the human clip's
timing and travel 1:1 instead of being stride-stretched to 4 s; sub-model
scale compensation targets `modelScript.scale / BODY_SCALE` and never
compounds; slot rules match attachment names by suffix (`shovel_back` ->
Back) and take a `pivot`; the slot section hides on any exception; idle
nodes are idles (crouch idle no longer walks in place); optional wolf
clips resolve through `WolfRuntime.OPTIONAL_FALLBACK`. Locked: the
death hand-off, the jaw item, the saddlebag, the `nil, nil` shift
arguments and the 0.4.23 hide-without-rule behaviour are untouched.
Unverified in game: all of it. See [0.4.24 fixes](PLAYTEST_FIXES_0424.md)
and [wolf animation list](WOLF_ANIMATION_LIST.md).
