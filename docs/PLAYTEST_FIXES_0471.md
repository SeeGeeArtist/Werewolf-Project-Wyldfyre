# 0.4.71: October 18 playtest fixes (0.4.70 report)

Target: the playtest of 0.4.70 (`console-3.txt` with the animation recorder
on the attack button, `console-5.txt` howl, two screenshots, the baseline
symbol drawing). Confirmed in that report and therefore locked: arrows no
longer flicker, the arrow sits on the side Rage moves toward, cheats panel
text survives pinning, footstep volumes, the Crinos shift/step weight, the
Lupus/Hispo howl animation. Multiplayer and silver are untouched.

## Why ctrl+click still shoved (and what changed)

The recorder in `console-3.txt` shows the fix from 0.4.70 did work for one
frame: on the press frame the node under `player/shoveAim` is
`WTAGarouCrinosClaw`. On the very next frame the state re-selects
`ShoveAim` (vanilla, priority 4, no conditions). The reason is Lua, not the
anim set: `Attack.refresh` in `WTAGarouCrinosAttack.lua` runs every
`OnPlayerUpdate` (through `Visual.refresh`) and, for the local player, wrote
`WTAGarouCrinosSwing = false` each time. Java sets the variable true on the
press; Lua reset it a frame later; the claw node's condition failed and the
best remaining node took over.

`Attack.refresh` now writes the swing flag only for REMOTE players (observer
path, every unarmed attack swings) or to clear it when the override itself is
disabled (form change, vehicle, override off). Local players keep whatever
Java decided per press. `tests/crinos_attack_test.lua` pins this.

## Howl: diagnostics and the authored clip

`console-5.txt` shows the Crinos howl running on the `actions` sub-layer with
the root-layer mask log firing only late, and the arm still rising. The
0.4.70 masks are left in place; 0.4.71 adds two things.

1. A one-shot `[WTAGarou][HowlDiag]` dump (`WTAGarouJava.debugHowl`,
   `HowlDiagnostics.java`) printed on the first howl tick: every layer,
   its current node, every track, whether it carries a bone mask, and the
   weights for R/L UpperArm, Neck, Head, Spine1. The next console tells
   exactly which track moves the arm.
2. The authored-howl path the author asked for ("make a simple crinos howl
   from the human armature and use it instead of drink"):
   - node `42/media/AnimSets/player/actions/WTAGarouHowl.xml`: clip
     `Bob_WTAGarouHowl`, looped, selected only by the string condition
     `PerformingAction == WTAGarouHowl` (this is the variable
     `BaseAction.setActionAnim` writes, decompile `BaseAction.java:273`),
     upper-body `m_SubStateBoneWeights` copied from the claw node so the legs
     keep the gait layer;
   - `WTAGarou.Anims.HOWL_AUTHORED = "WTAGarouHowl"`,
     `HOWL_AUTHORED_CLIP = "Bob_WTAGarouHowl"`,
     `WTAGarou.UseAuthoredHowl(character)` = Glabro/Crinos AND
     `WTAGarouJava.hasHumanClip(clip)` (`HumanClips.java`: looks the name up
     in `ModelManager.instance.maleModel.tag.animationClips`);
   - `WTAGarouHowlAction:start()` calls `setActionAnim("WTAGarouHowl")` when
     the clip is loaded and sets `WTAGarou_HowlMask = false` (no mask needed);
     without the clip everything is exactly the 0.4.70 Drink + mask path.

   Dropping the clip in is all that is needed to switch over:
   - author it on the vanilla Bob skeleton (the `MaleBody` rig; the Crinos
     head is a rigid attachment on `Bip01_Head`, so key Neck/Head/Spine and
     the arms as wanted, legs are masked out anyway);
   - export `Bob_WTAGarouHowl.glb` (or `.fbx`/`.X`) into
     `WTAGarou/42/media/anims_X/Bob/`; the clip name IS the file name and
     the `Bob_` prefix is required for the Bob mesh (`ModelManager`
     `loadAnimsFromDir` prefix check; `.glb/.fbx/.X` all go through
     `FileTask_AbstractLoadModel`);
   - make the action loop cleanly (the node is `m_Looped`), "Reset pose
     bones" on, sampled LINEAR keys, no root motion;
   - a mod folder is scanned at load, so a restart (not `/garou reload`)
     picks the new file up; the `[HowlDiag]` dump shows the node name
     `WTAGarouHowl` once it is in use.

## Legwear hidden on the digitigrade legs

Trousers, shorts and skirts are texture layers painted onto the human body
texture in `ModelInstanceTextureCreator.init`; with the human legs masked
away they only show on the hips, and the digitigrade thighs cut through
them (screenshot). While the legs are mounted the following body locations
are now skipped in the compositor: `Pants`, `Pants_Skinny`, `PantsExtra`,
`ShortPants`, `Skirt`, `LongSkirt`, `Legs1`, `Legs5`. Underwear, socks and
tops are untouched; the items stay equipped (insulation, pockets, protection
unchanged). `CrinosCosmetics.isLegwearLocation`, `CrinosFaceVisuals.hidden`
(legs scope now also set for the texture pass and restored by `leave()`),
`CrinosFaceVisualsTest`. Logged once: `[CrinosFit] worn legwear hidden`.

"Hide just below the thighs" is not possible with texture-only clothing: the
clothing is pixels on the body's UV map, not a mesh with a cut line.

The "cloaked" human legs seen under shorts were the transparent tights:
texture-only clothing paints on the body mesh wherever its UV covers, and
the hidden legs are hidden by mask, so a nearly transparent layer reveals
the body shape. Legs1 (tights/long johns bottom) is now in the hidden set.

## Doorway duck retired

`DoorwayRuntime.DUCK_ENABLED = false`: `collide()` returns the vanilla
answer before doing anything else, so the Crinos walks through doorways as
every other character. No hint, no forced sneak. The mechanism's code and
`DoorwayTest` stay (the harness turns the flag on) in case it is picked up
again; the Garou Guide sentence about doorways is gone. The sprint door
charge (closed wooden door, 12/18 Rage) is unchanged.

## Baseline symbol

Per the drawing: a 3-row triangle pointing down from the meter's top edge,
a 3-row triangle pointing up from the bottom edge, and a 1 px yellow stem
joining them, all on the baseline column. The 4 px cream bracket line
(stack width) stays inside the bottom edge beneath the symbol.
`WTAGarou.HUD.bracketGeometry` returns `topY/stemY/stemH/apexY`;
`WTAGarouHUD:drawBaselineSymbol` draws it in 7 rects; `channel_hud_test`
pins rows, stem and the arrow counting around it.

## Not changed (answers)

- Open window, no fall: vanilla. `IsoMovingObject.checkHitWall` skips the
  stumble when `checkVaultOver()` is true for a hoppable edge; walking into
  an open window simply stops.
- Flat/faceted look of the wolf and Crinos head versus the smooth vanilla
  body: this is in the mesh data (per-vertex normals the GLB exporter
  writes), not Blender's viewport shading or the game. In Blender, Object
  Mode, select the mesh, right-click, Shade Smooth (or Shade Auto Smooth with
  a 30-60 degree angle to keep intended hard creases). If the mesh was
  imported with flat custom normals: Object Data Properties, Geometry Data,
  Clear Custom Split Normals Data. If edges look smooth-shaded but still
  show seams, Mesh, Clean Up, Merge by Distance to weld split vertices.
  Re-export the GLB. The vanilla Bob mesh ships smooth normals, which is why
  the body does not show the facets.
