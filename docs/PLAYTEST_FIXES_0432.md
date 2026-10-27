# WTAGarou 0.4.32: Resolve maintenance and art handoff

This is a narrow follow-up to the September 30 playtest. The user's new back
pivot and right-holster values from `efb4a07` are preserved, as are all GLBs,
wolf textures, Crinos head placement and body masks.

## Fixed for the next test

- **Firearm-kit ammunition:** the log reports failed spawns for
  `base:bullets_308`, `base:shotgun_shells`, `base:bullets_9mm` and
  `base:bullets_38`. Those are AmmoType registry identifiers, not inventory
  item keys. The kit now calls `AmmoType.getItemKey()`, verified on the supplied
  42.21 class, then adds 60 loose rounds per gun. Removable magazines remain
  separate; guns are still unloaded. Unknown types are reported, not guessed.
- **Ground get-up:** native references name the exit clips
  `Bob_SitGround_Out` and `Bob_SitGround_OutQuick`, which the prior mapper treated
  as sit-down. Both now select the same `Wolf_getup` asset used for chair get-up.
  It is already a reversed sit asset, so playback stays forward and one-shot.
  No GLB needs to be reversed again. This is a tested mapping correction,
  not yet a confirmed in-game animation result.
- **Seated death:** `Bob_SitGround_EndDeath` has priority over the generic sit-end
  match, preventing a death clip from selecting get-up.
- **Left holster testing:** firearm kit now also grants `Base.HolsterDouble`.
  Equip the double holster for both left and right pistol attachment slots,
  rather than trying to stack two single holsters. No equipment-slot restrictions
  are altered.

The normal and quick exit names are documented in the
[ground get-up node](https://github.com/Niteghxst/Project-Zomboid-Media-Files/blob/main/media/AnimSets/player/getup/fromSitOnGround.xml)
and [quick get-up node](https://github.com/Niteghxst/Project-Zomboid-Media-Files/blob/main/media/AnimSets/player/getup/fromSitOnGroundQuick.xml).
That public media snapshot is reference evidence, not a certified copy of the
user's current game files. The [PZwiki item table](https://pzwiki.net/wiki/Items)
lists the double holster's left and right attachment slots.

## Human skin texture templates

Use copies from your own installed game to match its version. On the installation
path shown in your console, check:

```text
I:\SteamLibrary\steamapps\common\ProjectZomboid\media\textures\Body\
    MaleBody01.png
    FemaleBody01.png
```

Other numbered skin tones and male `a` variants may also be present.
The [PZwiki texture reference](https://pzwiki.net/wiki/Texture) lists these
male/female texture names and the `media/textures/body` directory.

Copy the PNGs into your art workspace; do not paint over the installed originals.
Keep the original pixel dimensions and UV placement. Paint the underwear pixels
as fur too, but preserve unrelated transparent regions. Use separate male/female
templates rather than stretching the wolf UV sheet onto either human mesh.

The supplied ProjectZomboid.zip contains Java JARs and launcher files only, so
it does not contain these skin images. If the PNGs are absent in your installed
Body folder, inspect your build's `media/texturepacks` assets instead; the
[file-format guide](https://pzwiki.net/wiki/File_formats) describes packed texture
atlases and Pack Viewer. Do not assume a public older skin download matches
your current UV layout.

The current Crinos registry uses one body swatch per coat for both sexes.
Once male/female human-UV paintings are ready, the next integration should add
separate body-texture fields rather than silently applying the male skin to both.
That routing change is not made in this maintenance patch.

## Confirmed and deferred

- **Confirmed by the user:** wolf swapping with Timber, Crinos head orientation,
  no fur skirt, Crinos coat changes and initial wolf corpse appearance.
- **Traversal:** the user did not test fences/windows in this run; still pending.
- **Reanimated wolves:** the initial corpse renderer works, but reanimation
  creates a separate IsoZombie with human visuals. A zombie-wolf feature needs
  its own model/rig/animation and persistence/network handling. No reanimation
  behavior is changed here.
- **Seated head look:** remains deferred and low priority. Do not restore human
  twist bones to get it, given earlier body-rotation failures.
- **Different weapon origins:** a future per-item/full-type transform override,
  falling back to the existing slot settings, is a better fit than endlessly
  retuning the shared Back pivot. Not implemented here.
- **Author art:** the user will edit wolf animations, including lowering the
  head approximately 15 degrees, and remodel/paint Crinos. No automatic asset
  regeneration is part of this patch.

## Roadmap boundary

**Resolve** focuses on transformation and Rage. The planned **2.0 Wits** update
is the place for the Hunter trait, its skill buffs, and crafting silver variants
of ordinary ammunition.

Silver variants are a reasonable design direction, but must preserve which
rounds are silver across loading, magazine transfer, unloading and firing.
A cosmetic ammo name or the current testing gun flag alone is not a complete
silver-ammunition system. No Hunter or ammunition-crafting implementation is
included in 0.4.32.

## Installation and verification

Pull `feature/cosmetic-model-swap` and fully restart the game to load the rebuilt
Java JAR. Both version banners should read `0.4.32`.

```bash
git pull origin feature/cosmetic-model-swap
```

Full Lua/asset and Java fixture suites pass, including object-shaped AmmoType
tests that reproduce the registry-ID mistake, both native ground-exit names,
one-shot/reverse restoration, and seated-death precedence. The optional supplied
game-JAR numerical attachment suite also passes. These do not replace a game
playtest; no claim is made that ground get-up is visually verified yet.
