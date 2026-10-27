# Publish day runbook (0.4.97, Oct 27 2026)

Everything below is prepared; the author's part is the eight numbered steps.
Text lives in: `42/mod.info` (one-paragraph `description=`, `url=` -> public
repo), `workshop/workshop.txt` (same paragraph + requirement line, tags,
`visibility=private`), `workshop/STEAM_PAGE.bbcode.txt` (full page, 7,766 of
the 8,000 characters Steam allows), `Translate/EN/UI.json` (trait text),
`WTAGarouTutorial.lua` (Werewolf Guide, now 10 pages). Witnesses, Infamy,
Hunters and NPC-Garou tagging are dormant and are listed under "Known
limits", not as features.

1. Windows PC: `git pull`, then `tools\stage_workshop.bat`. It mirrors
   `42/` and `common/` into `%USERPROFILE%\Zomboid\Workshop\WTAGarou\Contents\mods\WTAGarou\`,
   drops `poster - full.png`, `world-on-fire-glyph.png`, `*.base.glb` and
   `*.md`, copies `preview.png`, refreshes `workshop.txt` while its `id=`
   is still empty, prints the JAR SHA-256 and runs
   `tools\check_workshop_staging.py --public` (must end `0 failure(s)`; the
   one warning is the private visibility, intended for the first upload).
2. In game: Workshop -> Create/Update Items -> `WTAGarou` -> Next until
   Upload. First upload goes up PRIVATE. The uploader writes `id=` into the
   staged `workshop.txt`; commit that line back into `workshop/workshop.txt`
   so later staging keeps it.
3. Open the Workshop page in a browser -> Edit description -> paste
   `workshop/STEAM_PAGE.bbcode.txt`. Add Freylith as a contributor (Owner
   controls -> Add/Remove Contributors) before the page goes public; the
   credits say so.
4. Clean-profile check: with the local `mods/WTAGarou` copy disabled or
   renamed, subscribe to the private item, launch, confirm the mod list
   shows the Workshop copy (version 0.4.97 in the console banner), ZombieBuddy
   prompts for the Java module, a new werewolf gets the Startup panel, one
   shift into each form, Strip/Dress, one silver round. Fifteen minutes.
5. Flip visibility to Public on the Workshop page (or set
   `visibility=public` in the staged `workshop.txt` and upload again).
6. GitHub: the public repository is the snapshot repo
   `SeeGeeArtist/Werewolf-Project-Wyldfyre`. Its history was reset to a
   single commit at 0.4.97 (`publish_source_snapshot.sh --reset-history`)
   because the 0.4.83-0.4.89 snapshots still carried the Earthblood and
   Epidemic audio and the RabenRabo/Horse Mod meshes. Verify:
   `git clone` it fresh, `git log --oneline` shows ONE commit, no `.fbx`
   under `common/`, then Settings -> Danger Zone -> Change visibility ->
   Public. Enable Issues; the Workshop page links there.
7. Post the Workshop change note: version, JAR SHA-256 (from the .bat or
   the snapshot commit message), "requires ZombieBuddy 2.3.2+".
8. Development repo `Zomboid-Garou` stays PRIVATE for good (its history
   holds the replaced third-party files).

After release: every fix is bump -> tests -> push -> `tools/publish_source_snapshot.sh`
-> stage -> upload. Player reports go to GitHub Issues or the Workshop
discussion; ask for `console.txt` and the mod list.

---

# Steam Workshop release: checklist and audit (0.4.83, Oct 23 2026)

```text
Repository:            github.com/SeeGeeArtist/Zomboid-Garou, folder WTAGarou/
Branch:                feature/cosmetic-model-swap
Commit:                see `git log -1` at upload time; 0.4.83 = the commit this file lands in
Game build:            42.20.x / 42.21.0 (user's install reports 42.21.0; decompile reviewed is 42.20.2); versionMin=42.20
Release artifact:      %USERPROFILE%\Zomboid\Workshop\WTAGarou\ built by tools\stage_workshop.bat
Executable provenance: 42/media/java/client/WTAGarouVisuals.jar, built from java/src by java/build.sh in the same commit;
                       record its SHA-256 (the .bat prints it) in the Workshop change note
```

## What the Workshop uploader needs

Verified against `zombie.core.znet.SteamWorkshopItem` (42.20.2):

```text
%USERPROFILE%\Zomboid\Workshop\WTAGarou\
    workshop.txt            title=, description= (several lines allowed), tags=a;b;c, visibility=public|friendsOnly|private|unlisted, id= (assigned on first upload: keep the file)
    preview.png             256x256 or 512x512 PNG, <= 1,024,000 bytes (workshop/preview.png is 512, ~420 KB)
    Contents\
        mods\
            WTAGarou\
                42\         mod.info, media\...  (Build 42 tree)
                common\     media\models_X, anims_X, sound, textures
```

- Only `mods/`, `buildings/`, `creative/` may sit under `Contents/`; no loose files.
- Refused anywhere under `Contents/`: `*.exe *.dll *.bat *.app *.dylib *.sh *.so *.zip`.
  Our `.jar` is allowed (ZombieBuddy mods ship JARs this way).
- In game: Main menu > Workshop > Create New Item (later: Update Item),
  pick `WTAGarou`, check the preview/description/tags, Upload. The game
  rewrites `workshop.txt` with the `id=` it was given. Required items
  (ZombieBuddy, Workshop 3619862853) are set on the Workshop page
  afterwards, not in the files.

Commands:

```bat
tools\stage_workshop.bat
python tools\check_workshop_staging.py %USERPROFILE%\Zomboid\Workshop\WTAGarou
python tools\check_workshop_staging.py %USERPROFILE%\Zomboid\Workshop\WTAGarou --public   REM must exit 0 before a public upload
```

The checker fails on anything the engine would refuse, on a version
mismatch between `mod.info` and `WTAGarou.VERSION`, and (with `--public`)
on any third-party asset group whose permission is not recorded as
granted or replaced in `workshop/THIRD_PARTY_ASSETS.md`.

## Audit

### Client trust (cheating / griefing)

- Every Garou power runs through `WTAGarou` server commands; body effects,
  silver burns, scatter tiles and smoke are server-owned (rules 0.4.66,
  0.4.72, 0.4.74, 0.4.75 in REGRESSION_CONTRACT.md). Clients send ids and
  square locators, never items.
- FIXED in 0.4.83: the server's `Debug*` commands (set Rage, clear the
  identity lock, ...) and the GrantItems kit were gated on
  `getAccessLevel() ~= "None"`. In Build 42 that call returns the role
  NAME and every new player's role is `user`, so every ordinary player
  passed. Both now go through `WTAGarou.Access.privileged`: single player,
  a `-debug` server, or a role with the `AddItem` capability (admin,
  moderator, gm by default). The cheat panel hides itself by the same
  rule. `tests/access_test.lua`.
- Not yet bounded: per-command rate limits. All handlers are cheap and
  idempotent, so the exposure is log spam, not state damage. Acceptable for
  a private/unlisted test, worth a ticket before a public release.
- Host-compromise risk: none found. The mod never reads files, opens
  sockets or runs OS commands; the Java supplement only patches
  AnimationPlayer / model code on the client.

### Package

- Development surfaces that ship: the Werewolf Cheats panel and `/garou`
  console commands. They are capability-gated (above) and inert for
  ordinary players, so they are left in for server admins.
- Excluded by the staging script: `poster - full.png` (5.7 MB, unused),
  `world-on-fire-glyph.png`, every `.md/.py/.bat/.sh/.psd/.blend`, repo
  metadata. Removed from the tree in 0.4.83 as unused donor leftovers:
  `Item_WolfSaddlebag.png`, `Item_WolfLure.png`, `Translate/EN/IG_UI_EN.txt`,
  `Wolf_eat.dae`.
- Lua checksums: every player and the server must run the same bytes.
  Workshop subscription gives that for free; the hosted test
  (HOSTING_JUNCTION_CHECKSUM.md) must switch from the junction to the
  Workshop copy once published.

### Third-party assets: THE blocker

Hashing the shipped tree against the donor mods in the repository root
found byte-identical files from three mods, plus derived ones
(`workshop/THIRD_PARTY_ASSETS.md` lists every file):

| Group | What ships | Author's stated terms | Status |
| --- | --- | --- | --- |
| Tame-able Wolves (Freylith, 3581134738) | wolf body, 16 wolf animation clips, 9 `Wolf_Mod_*.ogg`, coat textures | page forbids re-upload; asked by Discord DM | GRANTED 2026-10-23 on condition of a contributor credit on the Workshop page (friend request to `studiofreylith`, then Add Contributors after the first upload) |
| RabenRabo Fantasy Bodyparts / Wolf Ears and Tail (3589269108, 3583888669) | Crinos legs + tail FBX, 14 masks, dye-derived textures | "give credit where credit is due" (no general licence); Wolf Ears and Tail: nothing stated | replaced 0.4.90 by own `tools/build_crinos_parts.py` output; nothing of his ships |
| Horse Mod (Horse Team) | saddlebags FBX + texture | LICENSE.txt: no redistribution "without prior written permission ... granted by at least two owners" | replaced 0.4.89 by own `tools/build_saddlebags.py` output; nothing of theirs ships |

Any Workshop upload, including `private` or `friendsOnly`, copies these
files to Steam's servers, which is the re-upload Freylith forbids. The
Wolf group is the Lupus/Hispo form itself and cannot be swapped out in a
week; the saddlebags can (generate a mesh like `tools/build_harness.py`
does for the harness); the Crinos legs/tail could be remodelled later.

Permission requests to send today (all three channels are public):

1. Freylith, Discord DM (the page names this as the only channel). Ask for:
   redistribution of the wolf body (rebuilt), the animation clips, the nine
   sounds and recoloured coats inside "Werewolf: Project Wyldfyre", with
   credit and a link; offer to make the mod depend on theirs instead if
   they prefer, and to pull the assets if they ever ask.
2. RabenRabo: NO LONGER NEEDED. 0.4.90 ships own legs, tail, textures and
   uses the vanilla masks (`tools/build_crinos_parts.py`).
3. Horse Team: NO LONGER NEEDED. 0.4.89 ships an own saddlebag mesh and
   textures (`tools/build_saddlebags.py`); the Horse Mod files were removed.

### Server exposure (for the hosted test, unchanged by Workshop)

- Hosted game on the gaming PC with the child server; whitelist on, no
  public listing, UPnP off. Not a dedicated host: a tester who crashes the
  server crashes the host's session. Acceptable for friends.

## Decision

```text
Audit scope:               WTAGarou/ at 0.4.83 on feature/cosmetic-model-swap; Lua, Java supplement, shipped assets, Workshop packaging
Host-compromise findings:  none
Game-integrity/DoS findings: Debug*/GrantItems open to every B42 player (FIXED 0.4.83); no per-command rate limit (open, low impact)
Release-package blockers:  third-party assets without recorded permission (Tame-able Wolves GRANTED; RabenRabo and Horse Mod REPLACED 0.4.89/0.4.90)
Server-exposure blockers:  none for the hosted friends test
Required before first invite (hosted, friends, no Workshop): nothing new - 0.4.83 on both machines
Required before ANY Workshop upload (even private): Freylith GRANTED 2026-10-23 (contributor credit owed); nothing else (RabenRabo and Horse Team no longer needed: own legs/tail 0.4.90, own saddlebags 0.4.89)
Required before a PUBLIC Workshop listing: the above, credits on the page, check_workshop_staging.py --public exit 0, a clean-profile install test from the Workshop copy, rate-limit ticket closed or accepted
Residual risk:             Build 42 is still in flux (42.21 moved ZombieBuddy registration for some players); the mod's Java patches target 42.20.2 method shapes
Verdict:                   LIMITED PRIVATE TEST (hosted, friends, whitelist) - Workshop upload unblocked on the asset side as of 0.4.90 (every third-party asset granted or replaced); public listing still needs the page credits, the clean-profile install test and check_workshop_staging.py --public exit 0
```

## Open source (Freylith's question)

Freylith asked whether the repository will be open source, because a
ZombieBuddy mod ships a Java binary and players trust one more when the
source is public. Yes, but NOT this repository: `Zomboid-Garou` is
private and tracks full copies of ten third-party mods (Bandits,
BanditsWeekOne, Horse Mod, PZTheMutants, ZombieBuddy, Tame-able Wolves,
RabenRabo's mods, DynamicModelScale, Skully's) as reference material.
Flipping it public would redistribute all of them, which is worse than
the Workshop question. Plan:

1. New public repository holding only `WTAGarou/` (Lua, Java source,
   scripts, tests, docs, workshop/), e.g. `SeeGeeArtist/WTAGarou`, created
   from a filtered export (`git subtree split -P WTAGarou` keeps the
   history of that folder only; check the result for donor files before
   pushing, `git log --all --stat -- '*.ogg' '*.fbx'`).
2. Add a licence: code under MIT (or GPL-3 if you want derivatives to
   stay open); the `common/media` donor assets excluded from the licence
   and marked "used with permission, do not redistribute separately" in
   the README, using THIRD_PARTY_ASSETS.md as the ledger.
3. The RabenRabo and Horse Mod files are gone from the tree as of 0.4.90;
   the public snapshot carries only granted or own assets.
4. Put the public repo URL in `mod.info` `url=` and on the Workshop page
   next to the JAR SHA-256, so anyone can rebuild `WTAGarouVisuals.jar`
   with `java/build.sh` and compare.

## When the permissions arrive

1. Record each in `workshop/THIRD_PARTY_ASSETS.md` as
   `granted <date> <where>` (keep the message), add the credit lines from
   STEAM_DESCRIPTION.md to the Workshop page.
2. `tools\stage_workshop.bat`, then the checker with `--public`.
3. First upload as `private` (visibility in workshop.txt), subscribe on the
   Steam Deck and the PC, play one hosted session from the Workshop copy
   (not the junction), then flip the page to public.
