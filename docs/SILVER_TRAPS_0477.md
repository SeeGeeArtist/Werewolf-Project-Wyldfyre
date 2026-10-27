# 0.4.77: scattered silver, the silver scent ("Home Alone", part 1)

## Scattered silver (silver caltrops)

Right-click any floor square while carrying Silver Filings: **Scatter
silver filings here** (5 of the 20 uses in a unit of filings). Right-click
a scattered tile: **Pick up scattered silver** (0.4.79 label; the 5 uses
or the fragment come back; a Garou
without gloves burns a hand doing it).

What the tile does, per walker:

| Walker | Effect |
|---|---|
| Human, zombie | Nothing. Silver has no edge; the tile is not glass to the engine. |
| Garou in Homid / Glabro, intact shoes | Nothing. |
| Garou in Homid / Glabro, barefoot or shoes at 0 condition | A foot burns at the contact rate; 35 % per step that fragments work in. |
| Crinos, Hispo, Lupus | Paws, always. Same burn, same lodge chance. |

Lodged fragments are the engine's lodged-glass state (pull them by hand or
with tweezers, the vanilla action) marked silver, so the foot keeps burning
and never regenerates until they are out. Health panel: "Lodged silver
fragments" in the silver colour; a bullet still reads "Lodged silver-tip
bullet". Yes, one foot can hold both a silver bullet and silver fragments,
and a foot can hold vanilla glass and silver fragments at once; the mark
only says which foreign body is silver. Yes, a glass tile and a silver tile
can share a square (the engine's glass is its own object type).

Glabro can wear shoes and gloves again; Crinos, Hispo and Lupus cannot
equip shoes (the re-equip guard refuses, the shift strips them).

Placeholder tile art: `common/media/textures/WTAGarou/WTAGarou_SilverScatter_0.png`
(128 x 256, shards drawn inside the bottom floor diamond). Paint over it;
keep the name. If the engine renders it at the wrong scale (B42 tiles are
2x), say so and I will add a 64 x 128 variant.

## The sniffer

Every 2 s a Garou sniffs the squares open to the same air (same room, or
both outdoors, same floor) within a nose radius per form: Homid 3, Glabro
4, Crinos 5, Hispo 7, Lupus 8. Anything *worked* silver raises **"You
smell silver"** over the head and a panel notice: scattered tiles, the
mod's own silver items on the floor or in containers (two bag levels
deep), a nitrate vessel, a loaded silver gun, a live coat, and whatever
another character nearby carries or holds. Vanilla silver jewellery never
triggers it. It says near, not where. It warns on first contact, repeats
every 60 s while the smell lingers, and resets in clean air so walking back
into it warns again. Your own kit does not set off your own nose.

## Answers

- Broken glass does not craft weapons in vanilla B42 (it is a Moveable
  junk item with a BrokenGlass tag used by the glass-shard wound code); a
  silver-fragment weapon would be a new recipe, see roadmap.
- Lodged metal: bullets are the only lodged metal in the engine; glass is
  the only other foreign body.

## Roadmap (next versions, in order)

1. (done in 0.4.78) Rage panel notices as a scrollable log; the Crinos
   drain / countdown notices moved there from the head.
2. Silvered windowsills and door handles: filings on a window frame or
   door object (mod data); climbing through / opening without gloves burns
   the hands (hooks: `ISClimbThroughWindow`-style vanilla actions and the
   door toggle).
3. (done in 0.4.81, `docs/SILVER_SMOKE_0481.md`) Silver smoke bomb: a
   vanilla-style throwable with `SmokeRange`; Garou inside the smoke
   breathe dust (throat burn, cough, Rage, scent).
4. (shelved, user Oct 21) Silver snares/traps for humans and zombies.
5. Silver-fragment improvised weapons (recipe parity with glass shards is
   not possible, there is none; a shard knife recipe instead).
6. (shelved, user Oct 21) Pet doors (user, Oct 19): an occasional residential exterior door with
   a flap that Lupus (and only Lupus) can pass. Vanilla has no flap door
   tiles, so this is either (a) a deterministic pick of some residential
   exterior doors by seed (door object mod data + a small flap overlay
   sprite) that the Lupus movement code treats as passable while the door
   stays shut for everyone else, or (b) a craftable flap the player fits to
   a door. (a) is the looting exploit asked for; passability for a single
   form needs a Java-side collision exception, so it rides with the next
   Java build.
