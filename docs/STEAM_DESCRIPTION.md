# Werewolf: Project Wyldfyre (Workshop description)

The paste-ready Steam page is `workshop/STEAM_PAGE.bbcode.txt` (Steam
BBCode, under the 8,000-character Workshop limit). Keep it in step with
`42/mod.info` `description=` (one-paragraph summary, duplicated in
`workshop/workshop.txt`), the trait text in `Translate/EN/UI.json` and the
in-game Werewolf Guide (`WTAGarouTutorial.lua`). Upload checklist:
[WORKSHOP_RELEASE.md](WORKSHOP_RELEASE.md). Witnesses, Infamy, Hunters and
the NPC-Garou tagging are dormant (0.4.79) and are NOT advertised; the page
says so under "Known limits".

## Short description (mod.info and workshop.txt)

Play a Garou werewolf in Build 42: five forms (Human, Near-Human, the Berzerker war form, Near-Wolf, Wolf) with their own bodies, channelled cancellable shifts, a situational Rage economy, forced war-form at 100 Rage, fast healing that purges the Knox virus, jaw carry and saddlebags for the wolf forms, controller and Steam Deck wheels, solo and multiplayer. Humans get a real counter-kit: silver rounds for every calibre, forged silver weapons, silver nitrate coatings, scattered silver and silver smoke bombs that burn werewolves. Requires ZombieBuddy.

## Long description

Superseded by `workshop/STEAM_PAGE.bbcode.txt` (0.4.97); the prose below is the 0.4.83 draft it grew from and is kept for history.

Become a Garou in Knox Country. Take the Werewolf trait and shift between
five forms, each with its own body, speed, carry rules and risks: Homid
(human), Glabro (near-man), Crinos (the war form: huge, has thumbs, cannot fit
in a vehicle seat), Hispo (dire wolf) and Lupus (wolf). Shifts are channelled
and can be cancelled; Rage builds in a fight and decides which forms you can
leave. Metis cannot leave Crinos above 55 Rage; other breeds above 75.

Quadruped forms carry things in their jaws and on saddlebags, but they have
paws: no firearms (you can carry a gun, you cannot fire, reload, rack or
open its radial), no crafting or building, no vehicle mechanics or siphoning.
Shift back to Homid for thumb work.

Werewolves heal fast, except where silver has touched them. Silver burns
bare skin while it is held or worn, and a silver wound stops healing until
the burn is gone.

### For the hunters

Human players need an edge to counter werewolves with, should they be brave
enough to. Everything below is crafted at a counter or table and needs no
skill unless noted.

- Silver Fragments: four pieces of silver jewellery and pliers, or one piece
  of silverware. A file turns one fragment into Silver Filings (20 uses).
- Silver rounds, one at a time (queue the quantity): a shotgun shell takes
  three filings uses and pliers; a round of any calibre (9mm, .45, .44, .38,
  .357, .30-30, .308, 5.56) two uses, a file and pliers. Six shells or ten
  rounds per fragment. Loading silver is a normal reload (gun in hand, same
  animation) from the gun's context menu or the reload radial menu. A gun
  holds silver or ordinary rounds, never a mix. Each silver round that wounds
  a werewolf burns the wound it made.
- Forged silver weapons: a metal melee weapon, two fragments, charcoal,
  hammer and tongs at a forge. Permanent, and it needs the Blacksmith level
  it takes to forge that weapon in the first place (a machete is a
  master's job, a small knife is not).
- Silver nitrate: a quarter bag of fertilizer (two uses) or one cold pack, a
  car battery (destroyed), fragments and any empty glass vessel (jar, beaker, beer, whiskey
  or wine bottle, drinking glass; nothing plastic), opened with a knife,
  screwdriver or pliers. The vessel comes back full of raw silver nitrate; set
  it inside a lit campfire, barbecue or stove like a pot of tainted water and
  it finishes on its own. Silver nitrate is a fluid: pour it between
  containers, never drink it (poison, like bleach). A litre coats five metal
  melee weapons anywhere, no table needed; the vessel stays and is simply empty
  after the last coat. A coat eats 10% of the weapon's condition and burns
  werewolves for twelve landed hits before it wears off; the weapon's tooltip
  shows the hits left. Cheap, quick, temporary. Wear gloves: a charged coat
  burns a bare Garou hand.

- Scattered silver: throw Silver Fragments or Silver Filings on the floor
  (context menu on the tile) to salt a doorway or a hallway. A barefoot
  Garou (Crinos, Hispo, Lupus always; Homid and Glabro only without shoes)
  walking over it gets fragments lodged in the feet that burn until they
  are pulled out through the health panel, the way glass is. Werewolves
  can smell the silver a few tiles away and get a warning first. Anyone
  can sweep the fragments back up.
- Silver smoke bomb: a smoke bomb and Silver Filings. Any Garou standing
  in the smoke gets a silver burn to the face, can barely see through the
  stinging haze, coughs and builds Rage. A gas mask with a filter keeps the
  dust out; humans breathe it like ordinary smoke.

Silver nitrate in a vessel does not burn a werewolf, so the vessels can be
carried by anyone. Silver rounds inside a gun do not burn either. Bare silver in the
hand or against the skin does.

### Requirements and install

- Project Zomboid Build 42 (42.20 or newer).
- ZombieBuddy 2.3.2 or newer (Workshop 3619862853): subscribe, do its
  one-time install (the installer, or copy `ZombieBuddy.jar` /
  `zbNative.dll` into the game folder and add `-agentlib:zbNative --` to
  the launch options; Linux and macOS use `-javaagent:ZombieBuddy.jar --`).
  This mod ships a small Java supplement (`WTAGarouVisuals.jar`) for the
  form models, climb and combat timing; when ZombieBuddy asks, choose
  Allow for "Werewolf: Project Wyldfyre". The mod lists ZombieBuddy as a
  required mod; if the Java module is not approved the Lua side still
  runs, but the per-form bodies and the Crinos cosmetics do not appear.
- Works solo and in multiplayer (host + server tested). Every player and
  the server need the same version; the Java supplement is client-only,
  the server runs the Lua.
- Controller and Steam Deck supported: native radial menus for shifting,
  social and map wheels. Steam Deck needs the native Linux runtime for
  ZombieBuddy (see its Workshop page).

### Credits and permissions

- Lupus/Hispo wolf body, animations and wolf sounds: adapted from
  "[B42] Tame-able Wolves" by Freylith (Workshop 3581134738), used with
  Freylith's permission (Oct 23 2026). Freylith is listed as a contributor
  on this Workshop item.
- Form-shift completion whoosh (WTAGarou_formshift_02.ogg) is built on
  "5 Everyday Whooshes" by Tomlija -- https://freesound.org/s/175183/ --
  License: Attribution 3.0 (CC BY 3.0), modified (cut, pitched, layered).
- Everything else (code, Java supplement, Crinos head, digitigrade legs, tail, harness, saddlebags,
  UI, poster, Crinos and Hispo voices, silver assets): SeeGeeArtist.
- Werewolf: The Apocalypse and the Garou are the property of Paradox
  Interactive / White Wolf; this is a non-commercial fan work and is not
  affiliated with them.
