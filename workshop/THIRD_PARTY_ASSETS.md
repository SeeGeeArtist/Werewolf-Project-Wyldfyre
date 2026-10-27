# Third-party assets shipped inside WTAGarou (permission ledger)

`tools/check_workshop_staging.py` reads this file. Every group below must
be `granted` (with who/when/where recorded) or `replaced` before the
checker lets a PUBLIC Workshop upload through; `pending` groups make it
exit non-zero. Byte-identical files were found by hashing the shipped
tree against the donor copies in the repository root (Oct 23, 0.4.83);
derived files are listed from the build notes in `docs/`.

Legend: STATUS is one of `pending`, `requested <date> <where>`,
`granted <date> <where>`, `refused <date>`, `replaced <version>`.

## Group: wolfmod (Lupus / Hispo body, animations, sounds, coats)

- Source: "[B42] Tame-able Wolves ~ (aka, 'the Dog Mod')", Workshop
  3581134738, author Freylith (mod id WolfoMod).
- Stated terms (Workshop page, verbatim): "This mod is a solo-passion
  project ... and under ZERO circumstances should this mod be re-uploaded,
  modified, or used in any public modpack. For any inquiries regarding
  permissions of use -- please DM @Freylith on Discord."
- Shipped files:
  - `common/media/models_X/Skinned/WTAGarou_Wolf.glb` (rebuilt from
    `Wolf_walk.glb`, animation stripped, unused nodes pruned: derived)
  - `common/media/anims_X/WTAGarouWolf/Wolf_*.glb` (16 clips; retargeted /
    renamed copies of the Wolf anims: derived)
  - `common/media/sound/Wolf_Mod_*.ogg` (9 files, byte-identical)
  - `common/media/textures/Body/WTAGarou_Wolf_{Black,Blonde,Brindle,Brown,Timber,White}.png`
    (coat recolours of the wolf body texture: derived)
- Until 0.4.83 `WTAGarou_Hispo_Growl_01.ogg` was `Wolf_Mod_Growl_01.ogg`
  pitched down; since 0.4.84 it is the author's own recording (see group
  `own`). `Wolf_Mod_Bark_01.ogg` is Freylith's bark with the opening growl
  trimmed off by the author (0.4.86; the author's own Lupus bark was
  dropped - "my voice just can't compare to the real thing"); covered by
  the same grant.
- STATUS: granted 2026-10-23 Discord DM from Freylith
- Terms of the grant (verbatim): "it's totally fine if youd like to use
  the assets. tho please credit me as a contributor on the mod page once
  it's made public. to do so, please send me a friend request on steam".
  So: (1) credit line in the description (done, STEAM_DESCRIPTION.md),
  (2) friend request to https://steamcommunity.com/id/studiofreylith,
  (3) after the item exists, Workshop page > Owner Controls > Add/Remove
  Contributors > Freylith (Steam only lets you add friends). Freylith also
  asked whether the repo will be open source (Java mods are trusted more
  with source available); see WORKSHOP_RELEASE.md "Open source".
- Contact used: Discord DM @Freylith. Removed Oct 23 as unused leftovers:
  `Item_WolfSaddlebag.png`, `Item_WolfLure.png`, `Translate/EN/IG_UI_EN.txt`,
  `Wolf_eat.dae`.

## Group: rabenrabo (Crinos digitigrade legs and tail)

- Source: "Fantasy Bodyparts" (Workshop 3589269108, mod
  RabenRabo_FantasyLegs) and "Wolf Ears and Tail" (Workshop 3583888669),
  author RabenRabo.
- Stated terms: Fantasy Bodyparts: "if you publish it give credit where
  credit is due" (said of backports; no general licence). Wolf Ears and
  Tail: no permission statement on the page. RabenRabo's legs are
  themselves built on Tomb's Player Body Overhaul with Tomb's permission.
- Shipped files (0.4.67 - 0.4.89, NO LONGER SHIPPED):
  - `common/media/models_X/Skinned/Clothes/WTAGarou_CrinosLegs_{M,F}.fbx`
    (from `RabenRabo_DigitigradeLegs_{M,F}.fbx`, later nudged by the author)
  - `common/media/models_X/Skinned/Clothes/WTAGarou_CrinosTail_{M,F}.fbx`
    (from `RabenRabo_WolfTail_{M,F}.fbx`, later re-sculpted and re-weighted
    by the author - still a derivative of his mesh and UV layout)
  - `common/media/textures/WTAGarou/CrinosLegsMasks/*.png` (14 masks,
    byte-identical)
  - `common/media/textures/Body/WTAGarou_CrinosTail_*.png` (painted over
    his `FurDye.png` layout: derived)
- STATUS: replaced
- 0.4.90: all of it replaced by our own `WTAGarou_Crinos{Legs,Tail}_{M,F}.glb`
  and `Body/WTAGarou_Crinos{Legs,Tail}_<Coat>.png`, generated from scratch
  by `tools/build_crinos_parts.py` (spline-lofted geometry, own UV layout,
  procedural fur; skinned to the vanilla Bip01 rig from a measured bind
  pose). No mask set ships any more (the vanilla one is used). The only
  things taken from the previous files were measurements: the rig's bind
  pose (TIS's skeleton, not RabenRabo's work) and the thigh-stump
  cross-section the author matched by eye. The RabenRabo files remain only
  in the private development repository's history.
- 0.4.94: the shipped meshes are now the author's own Blender models,
  unisex `WTAGarou_CrinosLegs.glb` and `WTAGarou_CrinosTail.glb`, built
  from the generated base (the author's export, Khronos glTF Blender I/O).
  The legs use the coat's `CrinosBody_<Coat>` sheet (vanilla body UV) and
  the tail the coat's `Wolf_<Coat>` sheet (wolf UV); no per-part PNGs ship.
- Permission request withdrawn; no credit owed and none given (crediting
  would wrongly imply his work ships). Tomb's Player Body Overhaul is
  likewise no longer involved.

## Group: horsemod (saddlebags)

- Source: "Horse Mod", Horse Team (albion, RedChili, carlesturo, Chuck,
  JBG_84, Paddlefruit, Sewerrabbit, SimKDT); GitHub PZ-HorseTeam/HorseMod.
- Stated terms (LICENSE.txt, verbatim): "You may not: 1. Redistribute this
  mod, in whole or in part, including any of its files, assets, or code,
  on any platform or service without prior written permission from the
  author. ... Permission must be explicitly granted by at least two owners
  of this copyright license."
- Shipped files (0.4.11 - 0.4.88, NO LONGER SHIPPED):
  - `common/media/models_X/WTAGarou/WTAGarou_Saddlebags.fbx`
    (byte-identical to `HorseSaddlebags.fbx`)
  - `common/media/textures/WTAGarou/WTAGarou_Saddlebags.png`
    (byte-identical to `HorseSaddlebags_Black.png`);
    `WTAGarou_Saddlebags_Camo.png` (recolour: derived)
- STATUS: replaced
- 0.4.89: all three files replaced by our own
  `WTAGarou_Saddlebags.glb` / `.png` / `_Camo.png`, generated from scratch
  by `tools/build_saddlebags.py` (numpy-built geometry and procedurally
  painted leather; nothing is derived from the Horse Mod's mesh or
  texture pixels). The only thing taken from the donor was its measured
  bounding box, so the tuned placement did not move; dimensions are facts,
  not protected expression. The Horse Mod files remain only in the private
  development repository's history and must not be published from there.
- Permission request to the Horse Team is withdrawn; no credit is owed and
  none is given (crediting would wrongly imply their work ships).

## Group: epidemic-sound (the howl)

- Source: Epidemic Sound library track "Creatures, Humanoid, Werewolf,
  Wolf, Howling, Distant" (ES id 17140-26533). The raw WAV was committed
  on 2026-09-18 (`4927680`) next to `WTAGarou_Howl.ogg`; both are 9.393 s
  and the ogg is that WAV converted. The WAV was deleted on 2026-09-26 but
  stays in the private repo's history; the ogg still ships.
- Stated terms: an Epidemic Sound subscription licenses the sounds for use
  inside published productions (videos, streams, podcasts). It does not
  grant redistribution of the sound files themselves, and a mod's
  `media/sound/*.ogg` is the file itself, downloadable by every
  subscriber. Check the exact plan terms; the default assumption is that
  this file cannot ship publicly.
- Shipped files: `common/media/sound/WTAGarou_Howl.ogg` (`sound WTAGarou_Howl`
  in `42/media/scripts/wtagarou_sounds.txt`).
- STATUS: replaced 0.4.84
- Replaced 2026-10-24 by the author's own howl (recording session
  `rec20261024`, `howl 01.wav` 597.2-609.7 s, processed by
  `tools/audio/build_set.py`; 14.5 s). The Epidemic Sound ogg is gone from
  the tree; it remains in the private repo's history only, which is why the
  public repo is published from snapshots (`tools/publish_source_snapshot.sh`).

## Group: earthblood (Crinos voice) - REPLACED

- Source: Werewolf: The Apocalypse - Earthblood (Cyanide Studio / Nacon,
  2021). Author's statement 2026-10-23: "The crinos sounds are actually
  ripped from Earthblood." Commercial game assets, all rights reserved;
  these could never ship on the Workshop or in the public repo.
- Affected files (every `WTAGarou_*.ogg` except the howl and the Hispo
  growl): `WTAGarou_Crinos_Growl.ogg`, `WTAGarou_Crinos_Roar_Bark.ogg`,
  `WTAGarou_Crinos_Roar_Bark_02..07.ogg` (04..07 deleted in 0.4.87), `WTAGarou_Crinos_Shift.ogg`,
  `WTAGarou_Crinos_Shift-Start.ogg`, `WTAGarou_Crinos_Shift-Timer.ogg`,
  `WTAGarou_Crinos_Fstep_01/02.ogg`, `WTAGarou_Hispo_Bark_01.ogg`,
  `WTAGarou_formshift.ogg`, `WTAGarou_formshift_02.ogg`.
- STATUS: replaced 0.4.84
- All of them were replaced on 2026-10-24 with the author's own voice and
  foley (recording session `rec20261024`, 24 WAVs, Rode VideoMic into a
  Pixel; cut list and processing in `tools/audio/build_set.py`, presets in
  `tools/audio/process_voice.py`). None of the Earthblood audio remains in
  the tree; it stays in the private repo's history only.

## Group: freesound-tomlija (CC BY 3.0, attribution in place)

- Source: "5 Everyday Whooshes" by Tomlija, https://freesound.org/s/175183/
- Licence: Creative Commons Attribution 3.0 Unported (CC BY 3.0). Allows
  redistribution and modification, including commercial use, as long as
  the attribution names the work, the author, the source and the licence,
  and says the work was modified.
- Affected file: `WTAGarou_formshift_02.ogg` (the form-shift completion
  whoosh) - built on this sample from 0.4.87 on (cut, pitched, layered with
  the author's own rock-on-towel impact).
- STATUS: granted 2026-10-25 (licence grant; no permission request needed)
- Attribution line (keep verbatim on the Workshop page, in
  `docs/STEAM_DESCRIPTION.md` "Credits and permissions", and in
  `README_PUBLIC.md` "Credits"):
  5 Everyday Whooshes by Tomlija -- https://freesound.org/s/175183/ --
  License: Attribution 3.0

## Group: own (no action)

Everything else: all Lua, Java (`WTAGarouVisuals.jar` built from
`java/src`), scripts, UI icons, poster, `WTAGarou_CrinosHead.glb`,
`WTAGarou_Harness.glb` and textures (generated), `WTAGarou_SilverScatter_*.png`,
the Crinos body textures' torso/arms (vanilla body repaints), and since
0.4.84 every `WTAGarou_*.ogg` in `common/media/sound/` (the author's own
voice and foley recorded 2026-10-24, processed with `tools/audio/build_set.py`
and the author's own Audacity passes; the raw session is kept off-repo,
600 MB) - except `WTAGarou_formshift_02.ogg`, see group `freesound-tomlija`.

- STATUS: granted 2026-10-23 (author's own work; vanilla-derived textures
  are ordinary PZ mod content)
