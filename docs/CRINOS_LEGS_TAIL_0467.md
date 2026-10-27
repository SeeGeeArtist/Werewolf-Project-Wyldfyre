# 0.4.67: Crinos digitigrade legs, optional tail, and the Crinos sound pass

Status: implemented and statically verified (Lua 32 PASS, Java all PASS).
Nothing in this release has been seen in the game yet. The live checklist is
at the end.

## What the player sees

- Every Crinos has digitigrade legs and paws. They are part of the body, not
  clothing: nothing to equip, nothing to drop, nothing in the inventory.
- The startup panel (Rage panel > Startup) has a new row under Wolf Gear:
  **Crinos Tail: No tail / Tail**. Default is No tail (the Underworld / Dog
  Soldiers look). It saves immediately, never locks, and can be changed any
  time, like gear. Old saves are tail-less until the player picks Tail.
- Worn shoes/socks keep their stats but their mesh is not drawn while the
  legs are on (Crinos strips footwear on the shift anyway; this covers
  anything put on afterwards). Pants/skirts are not special-cased.
- Crinos footsteps have a bass impact under the normal surface step, on
  every surface, for the local player and for remote Crinos players.
- The Crinos Q roar picks one of seven variants each time.
- Shift channel sound: the quiet form-shift cue repeats sooner (1.8 s) and
  rings over its own tail; every completed channel ends with the new
  `formshift_02` cue at lowered volume; a channel into Crinos opens with
  `Crinos_Shift-Start` (slightly under the completion roar) and finishes
  with the longer `Crinos_Shift` roar as before. Cancelled channels stay
  silent at the end.

## How the legs and tail are attached (Java)

`CrinosCosmetics.addHead` already runs on a fresh model slot before the
vanilla population (`CrinosHeadPatch` on
`PopTemplateManager.populateCharacterModelSlot`). 0.4.67 adds `addParts`
right after the head mounts:

```
ModelManager.instance.newAdditionalModelInstance(mesh, "Body/<tex>", chr, body.animPlayer, null)
inst.depthBias = 0; inst.matrixModel = body; inst.tint = 1,1,1
inst.parent = body; inst.animPlayer = body.animPlayer
body.sub.add(0, inst); slot.sub.add(0, inst); inst.setOwner(slot)
```

That is exactly `PopTemplateManager.addClothingItem` +
`postProcessNewItemInstance` minus the `ItemVisual`. The meshes are skinned to
the vanilla Bip01 rig (the tail rides the DressBack bones, so it sways), so
they animate with the body like any worn FBX and render on remote players
through the same path. Mesh names are the lower-case clothing form
(`media/models_x/skinned/clothes/wtagarou_crinoslegs_m.fbx`); the sex comes
from `chr.isFemale()`.

`CrinosCosmetics.set(chr, enabled, body, head, legs, tail)` stays "pending"
until the head, the coat textures and the two skinned models are resident
(`tryGetLoadedModel` / `loadAdditionalModel`, the engine's own key). Lua
polls as before. `WTAGarouJava.preloadCrinosParts(legs, tail, female)` warms
both meshes at player creation, tail included, so toggling it later is
instant.

Body masking (`CrinosCosmetics.texture`, after
`ModelInstanceTextureCreator.init`): with legs on, the LeftLeg, LeftFoot,
RightLeg and RightFoot parts are hidden (the same four parts the clothing
version of these legs masks) and `chrData.maskFolder` switches to
`media/textures/WTAGarou/CrinosLegsMasks`, whose Crotch/Waist/Chest masks are
extended so the thigh cut meets the mesh. The mask PNGs are queued in
`texturesNotReady` exactly as the native code does.

Footwear: `CrinosFootwearPatch` skips `PopTemplateManager.addClothingItem`
(returns null, as for items with no model) when the character's profile has
legs and the item's body location is `*:Shoes` or `*:Socks`. The item stays
worn.

## Lua, sync and the panel

- `WTAGarouWolfCoats.lua`: each coat names `crinosLegs` and `crinosTail`
  textures. Coats without them fall back to Timber's.
- `WTAGarouVisual.refreshCrinos` passes legs for every Crinos and the tail
  when `Visual.tailWanted(player)` is true: the synced snapshot row for remote
  players, `modData.WTAGarou.crinosTail` for the local one. Older Java
  without `setCrinosCosmeticsParts` gets the old four-argument call.
- Server: `SelectCrinosTail {tail=boolean}` in `WTAGarouWolfCoatServer.lua`
  stores `data.crinosTail` (true or nil), answers with the usual
  `WolfCoatSelected` payload (now carrying `crinosTail`), and
  `WTAGarouVisualSyncServer` puts `crinosTail` in every snapshot row;
  changes publish immediately like gear. The client validates it as a strict
  boolean and defaults to off for old snapshots.
- Panel: `WTAGarouWolfCoat.lua` adds the row (+62 px window height),
  `chooseTail` / `updateTail`, and `Coat.receive` applies the flag.

## Sound details

Bank (`42/media/scripts/wtagarou_sounds.txt`):

| cue | file(s) | volume | range | plays |
|---|---|---|---|---|
| `WTAGarou_CrinosStep` | Crinos_Fstep_01/02 | 0.80 | 3-20 | locally under each Crinos surface step |
| `WTAGarou_CrinosRoar` | Roar_Bark, _02.._07 | 1.00 | 10-60 | Q in Crinos, random clip |
| `WTAGarou_FormShift` | formshift | 0.85 | 2-12 | channel start (non-Crinos), repeat every 1.8 s |
| `WTAGarou_FormShiftEnd` | formshift_02 | 0.60 (x0.6 gain) | 2-12 | every completed channel |
| `WTAGarou_CrinosShiftStart` | Crinos_Shift-Start | 0.80 | 5-35 | channel into Crinos starts |
| `WTAGarou_CrinosShift` | Crinos_Shift (new, longer) | 0.95 | 5-35 | channel into Crinos completes |

`Roar_Bark_07.ogg` is byte-identical to the previous `Crinos_Shift.ogg`
(the old shift roar, now a Q variant). The `(n)` filenames were renamed to
`_0n` with `git mv`.

Why the footstep layer is local and not networked: vanilla footsteps are
driven by the `Footstep` animation event, which fires on every client that
animates a character, remote players included (`IsoPlayer.DoFootstepSound`
→ `CharacterSoundEmitter.playFootsteps`, a `playSoundImpl`, never a packet).
The `FootstepPatch` therefore already runs for remote Crinos players on each
observer's machine, and `playSoundLocal` there is what every client hears.
`character:playSound` would add a PlaySound packet on top and double it.

Why shift cues are networked by the engine: `IsoGameCharacter.playSound`
(what `WTAGarou.Audio.play` calls) is the engine's networked emitter path;
`playSoundLocal` is the `playSoundImpl` one. Remote clients receive
`PlaySoundPacket` and play the same bank entry on their copy of the
character, so the cue's own `distanceMax` is the reach: 12 tiles for the
quiet form-shift cues, 35 for the Crinos start/completion roars.

Volume: every handle is still scaled by `WTAGarou.Audio.factor()` (the
Sound Effects slider), with an extra per-cue gain for the end cue and the
footstep layer. Nothing bypasses the slider.

## Asset credit / permission (please read)

The leg and tail meshes, the mask set and the grey dye textures the coat
textures were baked from come from two Steam Workshop mods by RabenRabo:
Fantasy Legs (3589269108, `RabenRabo_DigitigradeLegsClawsSR_{M,F}.fbx`,
`FantasyLegs/Masks`, `DigitigradeLegsDye.png`) and Wolf Ears and Tail
(3583888669, `RabenRabo_WolfTail_{M,F}.fbx`, `WolfEarsTail/FurDye.png`). The
repo copies of those mods are reference material. Before this branch is
shared outside the private alpha (and certainly before any Workshop upload),
RabenRabo's permission for redistributing the meshes should be on record and
the mod description should credit them. If permission is refused, the Java
path is mesh-agnostic: drop replacement FBX files under the same names.

The baked `WTAGarou_Crinos{Legs,Tail}_<Coat>.png` textures are a first pass
(median coat colour multiplied into the dye textures; the legs dye texture is
smooth skin, not fur). Repaint freely; the names are what the registry
expects, M and F share one texture as in the source mod.

## Live checklist (not yet done)

1. Shift to Crinos (male and female characters): legs and paws present,
   human legs/feet gone, no seam at the thigh, no human feet poking through
   the paws. Console shows `[CrinosFit] legs mounted as skinned body
   sub-model`.
2. Walk, run, sneak, crouch-attack, climb, fall: the legs follow the thigh/
   calf/foot bones (no stretching or stuck mesh). If the mesh lags the body
   or stays in bind pose, the AnimationPlayer wiring is wrong, not the mesh.
3. Startup panel: Tail toggles on/off on the next refresh (no reshift
   needed); the tail sways; second client sees the change.
4. Put on shoes in Crinos: no shoe mesh; take them off, back to Homid: shoes
   draw again.
5. Footsteps: bass under every Crinos step on wood, grass, road, indoors; the
   other player hears the host's Crinos steps and vice versa; sneaking is
   quieter; Sound Effects slider scales it.
6. Q in Crinos several times: different roars, still no gesture animation
   (0.4.63 check the user has not done yet).
7. Channel to Glabro: form-shift cue repeats at 1.8 s with overlap, quiet end
   cue on completion, nothing extra on cancel. Channel to Crinos: Shift-Start
   on start (slightly under the completion roar), the long roar on
   completion. Second client hears the Crinos cues at a distance and the
   quiet ones only when close.
