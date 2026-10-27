# Werewolf: Project Wyldfyre

A five-form Garou transformation mod for Project Zomboid Build 42: Homid,
Glabro, Crinos, Hispo and Lupus, with channelled shifts, Rage, per-form
bodies, and a full counter-kit for the humans (silver rounds, forged and
nitrate-coated silver weapons, scattered silver, silver smoke).

This repository is the source of the Workshop mod, published as one
snapshot commit per release (tagged `vX.Y.Z`). Each snapshot message names
the SHA-256 of the shipped Java supplement so you can rebuild and compare.

## Layout

- `42/` - the Build 42 mod tree (`mod.info`, Lua, scripts, UI, the Java jar).
- `common/` - models, animations, sounds, textures.
- `java/` - source of `WTAGarouVisuals.jar` (a ZombieBuddy module:
  per-form models, climb and combat timing). `cd java && bash build.sh`
  rebuilds it; `bash test.sh` runs the Java tests.
- `tests/` - headless Lua tests (`bash tests/run.sh`, needs lua5.1) and the
  asset/package contract (`python3 tests/asset_contract_test.py "$PWD"`).
- `docs/` - design notes, playtest write-ups and `REGRESSION_CONTRACT.md`,
  the rules every change has to keep.
- `workshop/` - Workshop item files and `THIRD_PARTY_ASSETS.md`, the
  permission ledger for every asset that is not ours.
- `tools/` - staging and checking scripts for a Workshop upload.

## Requirements

Project Zomboid 42.20 or newer and [ZombieBuddy](https://steamcommunity.com/sharedfiles/filedetails/?id=3619862853)
2.3.2 or newer. Approve the "Werewolf: Project Wyldfyre" Java module when
ZombieBuddy asks.

## Credits

- Lupus/Hispo wolf body, animations and wolf sounds adapted from
  "[B42] Tame-able Wolves" by Freylith, with permission.
- Form-shift completion whoosh built on "5 Everyday Whooshes" by Tomlija --
  https://freesound.org/s/175183/ -- License: Attribution 3.0 (CC BY 3.0),
  modified.
- Everything else by SeeGeeArtist.

Werewolf: The Apocalypse and the Garou belong to Paradox Interactive /
White Wolf. This is a non-commercial fan work.

## Reporting bugs

Open an issue here with your game build, the mod list, what form you were
in, and `console.txt` (`%USERPROFILE%\Zomboid\console.txt` on Windows,
`~/Zomboid/console.txt` on Linux/Steam Deck). Multiplayer reports also
need the server's console. Build 42 moves quickly; say which version of the
game and of this mod (the console prints `[WTAGarou] Definitions loaded -
version x.y.z`).

## Licence

The code of Werewolf: Project Wyldfyre (everything under `42/media/lua`,
`java/`, `42/media/scripts`, `tests/`, `tools/`, and the documentation)
is free software under the GNU General Public License v3.0 or later; see
`LICENSE`. You may run, study, change and redistribute it, and any version
you distribute must stay under the GPL with its source available.

Copyright (C) 2026 Chris Guerra (SeeGeeArtist).

The licence does not cover:

- Third-party assets listed in `workshop/THIRD_PARTY_ASSETS.md` (the
  wolf body, animations and wolf sounds from Tame-able Wolves). They are included with their authors' permission for this
  mod only and may not be lifted out, re-uploaded or re-licensed.
- The author's own artwork, models, textures and recordings under
  `common/media` and `42/media/ui`, which are (C) Chris Guerra, all rights
  reserved, except that you may redistribute them unmodified as part of a
  GPL build of this mod.

Werewolf: The Apocalypse and the Garou are the property of Paradox
Interactive / White Wolf. This is a non-commercial fan work and nothing
here grants any right to that intellectual property.
