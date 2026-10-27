# Hosting: "Terminated" during Loading World (junction in the mods folder)

Symptom (Oct 16 host attempt, `coop-console-2.txt`): Host game with only
ZombieBuddy and WTAGarou; the server status goes Initialising → Loading
Assets → Initing Checksum → Loading Sandbox Vars → Loading World →
**Terminated**, three times in a row. Nothing was wrong with the Deck or
the join; the server never got that far.

## Chain of events in the server console

1. `GameServer.doMinimumInit> IllegalStateException: couldn't find
   "c:\users\ludec\zomboid\mods\wtagarou\42\media\animsets\player\shove\wtagaroucrinosclaw.xml"
   at AdvancedAnimator.buildChecksum(AdvancedAnimator.java:909)`
2. That exception is thrown inside the one `try` block that also runs
   `LuaManager.LoadDirBase("shared")`, `("client")` and `("server")`
   (`GameServer.doMinimumInit`, 42.20.2 lines 1450-1458). So no Lua loaded
   at all, vanilla included.
3. Consequences visible further down: `SpawnPoints.initSpawnRegions >
   SpawnRegionMgr is undefined` (vanilla `shared/SpawnRegions.lua` never
   ran), then `WorldGenOverride.lua:4 attempted index: biomes of non-table:
   null` and `WorldGenChunk.<init>: "worldgenTable" is null` (vanilla
   `server/WorldGen/WorldGen.lua` never ran) → `Server Terminated.`
4. Eight earlier, non-fatal `NetChecksum$Checksummer.addFile>
   NullPointerException absPath:null` errors during `ScriptManager.Load`
   are the same problem hitting the mod's eight `media/scripts/*.txt`.

## Why the file "couldn't be found" although it exists

`C:\Users\ludec\Zomboid\mods\WTAGarou` is a directory junction to
`I:\Mod Projects\Zomboid-Garou\WTAGarou` (ZombieBuddy's log shows the jar
resolved to the `I:` path). The multiplayer checksum code builds each
mod's root URI from `modDir.getCanonicalFile()`, which resolves the
junction to `i:\mod projects\zomboid-garou\wtagarou\42\`, but walks the
files through the unresolved `C:\Users\...\mods\WTAGarou\42\media\AnimSets`
path. `ZomboidFileSystem.getRelativeFile` cannot relativize one against
the other, hands back the absolute path, and `getAbsolutePath()` finds no
such key in the mod file map → `IllegalStateException`. Single player never
runs this checksum, which is why the junction has worked for months of
solo playtests.

Nothing in the mod can work around it: the throw is in vanilla code and
it aborts before any mod Lua runs. The mods folder must contain a real
copy for hosting, and the same rule applies to any client that joins
(the client runs `AdvancedAnimator.load()` too).

## Fix on the PC

Run `WTAGarou\tools\sync_mod_folder.bat` from the repository. It removes
the junction (`rmdir` on a junction deletes only the link), then
`robocopy /MIR`s the repository's `WTAGarou` folder into
`%UserProfile%\Zomboid\mods\WTAGarou` (skipping `docs`, `tests`, `tools`,
`.git` and `*.md`). Re-run it after every pull or jar rebuild; it is the
new "install" step, replacing edit-in-place.

Manual equivalent:

```bat
rmdir "%UserProfile%\Zomboid\mods\WTAGarou"
robocopy "I:\Mod Projects\Zomboid-Garou\WTAGarou" "%UserProfile%\Zomboid\mods\WTAGarou" /MIR /XD docs tests tools .git /XF *.md
```

## Check the Steam Deck the same way

Before the Deck joins, make sure `~/Zomboid/mods/WTAGarou` is a real
directory, not a symlink into the repository automount:

```bash
ls -la ~/Zomboid/mods/
```

If the `WTAGarou` entry shows `->`, replace it with a copy:

```bash
rm ~/Zomboid/mods/WTAGarou
rsync -a --delete --exclude docs --exclude tests --exclude tools --exclude .git --exclude '*.md' \
      /path/to/Zomboid-Garou/WTAGarou/ ~/Zomboid/mods/WTAGarou/
```

## Unrelated noise in the same log

- `AdvancedAnimator$1.visitFileFailed NoSuchFileException ...\common\media\AnimSets`
  (and `actiongroups`) for both mods: the checksum walker probes folders
  that do not exist; logged and skipped. Harmless.
- `Failed to load asset: wtagarouwolf/wolf_sit-backup.glb`: a local
  backup copy in `common/media/anims_X/WTAGarouWolf` (the repository only
  has the `.glb.bak`); harmless, can be deleted.
- `Missing translation UI_trait_Garou / UI_trait_GarouDesc`: both keys
  exist in `Translate/EN/UI.json`; the server logs them while loading the
  trait script, before translations are read. Cosmetic.
