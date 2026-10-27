# Umbral Update - glyph library (design draft, September 26, 2026)

Design notes only. Nothing here is implemented. Order of work agreed with the
author: finish shapeshifting, then the Infamy Update (NPC mod integrations),
then this Umbral Update (Garou magic, glyphs, spirit tracking).

## Pillars

- Survival game, not a quest game: powers are **crafted**, not awarded.
  A Garou tracks a spirit, learns its glyph, and converts Rage into that
  glyph at a crafting bench (Rage is the ingredient).
- Three Garou stats, one per auspice: **Resolve** (Ahroun - Rage control),
  **Wits** (Ragabash - trickery, stealth, mobility), **Gnosis** (Theurge -
  spirits, tracking, glyphs). Infamy from the Infamy Update is the social
  axis. Each auspice has its own Rage baseline (Howl target): Ahroun 60,
  Theurge 50, Ragabash 30 (draft).
- Glyph objects come in three kinds, all 0 encumbrance, no attachment point:
  - **Consumable** (food-like): one-shot temporary buff or effect.
  - **Passive** (worn): an effect while "worn". Invisible clothing: a
    Clothing item with a dedicated body location and no model.
  - **Active** (weapon/tool): equipped in a hand; glows over the hand like a
    glove; activated for an attack or utility effect.
- Upgrade: consume a glyph of the same or higher level into a glyph to raise
  its level (level caps per stat).

## Art direction

Glyph shapes come from the official glyph pages on
[The Cyber Record](https://sites.google.com/view/thecyberrecord/glyphery/official-glyphs);
that page lists, among others, the auspice, tribe, nature (Lightning, Storm,
Fire, Water, Stone, Wind, Cold), animal (Bear, Rat, Fox, Bird, Snake) and
concept glyphs (Quick / Speed, Jump, Hidden / Conceal, Observant / Watch,
Claw, Cycle / Recurrence). Some of those PNGs carry white strokes: use ONLY
the alpha channel as a mask and tint it per gift family (below), so the
white never shows. Icon size 48 px like the radial slices; item textures
1:1 with a soft glow halo baked in.

Tint per family (draft): Ahroun/Resolve red (183,38,45 - the mod's slice
red), Theurge/Gnosis violet, Ragabash/Wits teal, Nature glyphs by element
(Lightning white-blue, Fire orange, Stone grey, Water blue, Wind pale green).

## Engine feasibility (what 42.20.2 gives us)

Checked in the engine source we hold:

- **Thrown projectile**: any weapon script with `PhysicsObject` set is thrown
  as an arc projectile by `IsoGameCharacter` (`IsoMolotovCocktail` for
  everything but `Ball`), with the weapon's fire/explosion/smoke/noise
  values applied on landing (`IsoGameCharacter.java` ~8905). A "Thunder"
  glyph can be a throwable with a custom model and no fire; the impact
  effect (damage in a radius, a flash) is our Lua/Java on the landing
  event. So a bolt projectile is feasible without new physics.
- **Lightning**: the game has storm lightning (there is an option "disable
  lightning during storms", `Core.java:4193`). The flash is a screen/ambient
  effect, not an object we can aim; a bolt visual would be our own particle
  or a brief light flash at the impact square. The `iso`/`weather` packages
  are not in our reference tree, so the exact API is unverified.
- **Glowing hand**: items have `LightStrength` / `LightDistance` and an
  activated state (`InventoryItem.isActivated/canBeActivated/getLightStrength`).
  An equipped glyph can be an activatable light source; the "glove" glow is
  a hand-attached model with an emissive texture (as our wolf sub-models
  are attached), toggled with the item's activated state.
- **Invisible clothing**: Clothing items with a body location and no
  `ClothingItem` model render nothing and still count as worn; our
  `WTAGarou.CanWear` / shift-strip rules will need a `Glyph` category that
  every form may wear and that is never stripped.
- **Spirit tracks**: Build 42 animal tracks are defined in Lua
  (`AnimalTracksDefinitions` table read by
  `zombie.characters.animals.AnimalTracksDefinitions.loadTracksDefinitions`)
  and placed per chunk (`AnimalChunk.animalTracks`); they are revealed by the
  vanilla Tracking perk. Spirit tracks can be a new "animal" type with its
  own track sprites laid by an invisible spirit mover; gating the reveal by
  **Gnosis instead of Tracking** needs either a custom perk (custom perks in
  B42 Lua: unverified) or our own reveal pass that reads Gnosis from mod
  data and toggles track visibility.

## Library (first pass - 30 glyphs)

Levels 1-5. "Base" names the Werewolf gift the mechanic paraphrases (gift
lists per auspice/tribe/rank are indexed on
[Wyrmfoe](https://www.wyrmfoe.com/werewolf-gifts/)); the effect is written
in Project Zomboid terms. Scaling stat in brackets.

### Resolve (Ahroun) - red

| Glyph | Kind | Base gift | Effect in game | Scaling |
|---|---|---|---|---|
| Steady Heart | Passive | Resist Pain | While sprinting, Rage moves toward the auspice baseline (1/s at L1, 3/s at L5). | Resolve |
| Iron Will | Passive | Inspiration | Each Resist adds +0.5 s x level to the next countdown (partly undoes the shrink). | Resolve |
| Razor Claws | Consumable | Razor Claws | Crinos/Hispo claw damage +20% x level for 10 min. | Resolve |
| Thunderfoot | Passive | (Ahroun stomp) | Crinos stomp becomes an AoE (radius 1 + 0.5 x level tiles); damage % of a stomp scales with Resolve and Strength; every zombie hit moves Rage 2 toward baseline. | Resolve + Strength |
| Troll Skin | Consumable | Troll Skin | Scratch/laceration chance -15% x level for 10 min. | Resolve |
| Silver Bane | Passive | Luna's Armor | Silver burn growth halved (L3), silver damage mult 2.0 -> 1.5 (L5). | Resolve |
| Warcry | Active | Call of the Wyld / Roar | Activated: a howl variant that pulls zombies in a 60-tile radius toward a point you aim at, not you. | Resolve |
| Sense of the Prey | Passive | Sense of the Prey | Zombies that damaged you are highlighted for 30 s x level. | Resolve |
| Unyielding | Consumable | Stoking Fury's Furnace | Sets Rage to exactly 100 and starts a countdown you may Resist for a free Rage refund of 20 on success. | - |
| Berserker's Focus | Passive | Combat Healing | Regeneration keeps running during the forced Crinos channel and the first 10 s of Crinos. | Resolve |

### Wits (Ragabash) - teal

| Glyph | Kind | Base gift | Effect in game | Scaling |
|---|---|---|---|---|
| Squirrel's Step | Passive | Hare's Leap / (Squirrel) | Every fence hop, climb, window entry or sprint-vault refunds 2% x level Endurance. | Wits |
| Blur of the Milky Eye | Consumable | Blur of the Milky Eye | Stealth: zombie sight range -20% x level for 5 min, breaks on attack. | Wits |
| Catfeet | Passive | Catfeet | No fall damage from 1 floor; footstep noise halved in Lupus. | Wits |
| Open Seal | Active | Open Seal | Activated on a locked door/window/car: opens it; costs 15 Rage; level gates car locks (L3) and padlocks (L4). | Wits |
| Scent of Running Water | Passive | Scent of Running Water | Zombies lose your scent track after 10 s x level out of sight. | Wits |
| Fast Hands | Consumable | Speed of Thought | Timed actions 25% faster for 5 min. | Wits |
| Taking the Forgotten | Active | Taking the Forgotten | Activated on a downed zombie: loot without the search action; L3 also pulls attached items. | Wits |
| Silent Pad | Passive | Silence | Hispo/Lupus running noise as walking. | Wits |
| Trickster's Coat | Passive | Persuasion | Infamy witness range -1 tile x level (Infamy Update hook). | Wits |
| Whelp's Laugh | Consumable | Reshape Object | Repairs a torn clothing item by one condition step per level. | Wits |

### Gnosis (Theurge) - violet

| Glyph | Kind | Base gift | Effect in game | Scaling |
|---|---|---|---|---|
| Spirit Sight | Passive | Sense Wyrm / Spirit Speech | Spirit tracks are revealed within 5 + 3 x level tiles (the Umbral core loop). | Gnosis |
| Mother's Touch | Active | Mother's Touch | Activated on yourself or another player: bandage-free clot + 10 health x level; 25 Rage. | Gnosis |
| Thunder | Active | Call the Storm (Wendigo) | Thrown bolt (`PhysicsObject` projectile). Impact: damage 15 x level in a 1-tile radius, flash, 40-tile noise. 20 Rage per bolt; L5 chains to one more zombie. | Gnosis |
| Master of Fire | Passive | Master of Fire | Burn wounds heal at 2x; immune to campfire ignition (L5). | Gnosis |
| Heightened Senses | Consumable | Heightened Senses | Zombie outlines through walls within 10 tiles for 2 min. | Gnosis |
| Truth of Gaia | Passive | Truth of Gaia | Health panel shows exact Wyrm Infection % and purge ETA; poisoned food flagged in tooltips. | Gnosis |
| Cocoon | Consumable | Cocoon | 60 s x level of full damage immunity while standing still; any movement ends it. | Gnosis |
| Pulse of the Invisible | Passive | Pulse of the Invisible | Spirits nearby leave a HUD compass hint (distance band only). | Gnosis |
| Umbral Tether | Active | Umbral Sight / Stepping Sideways (lite) | Activated: 5 s x level of walking through zombies without collision (no damage either way); 40 Rage. | Gnosis |
| Gift of the Spirits | Consumable | Spirit Drain | Converts 30 Rage into one Gnosis XP step; the crafting fuel loop. | - |

## Crafting loop (draft)

1. Track a spirit (Gnosis reveals its tracks; Tracking perk does not).
2. Reach the spirit: it is invisible and intangible; when within 2 tiles and
   Gnosis >= its rank, it "teaches" - you receive the glyph **recipe** (a
   recipe item or a learned recipe flag).
3. Craft at a fire or a ritual circle: recipe consumes Rage (30 x level) and
   a mundane token (a bone, a stone, a feather; the glyph page's Nature and
   Animal glyphs suggest the token) and yields the level-1 glyph.
4. Upgrade: craft glyph + glyph (same or higher level) -> glyph + 1 level.
   Cap = your stat in that family.

## Open questions for the author

- Do glyphs survive death (lore says gifts do; survival says no)?
- Are Active glyphs usable in Crinos (Palpatine hands) or only in Homid /
  Glabro? Proposal: Thunder in every hand-bearing form, others Homid/Glabro.
- Rage cost vs. Rage baseline: Theurge glyphs spend Rage; should heavy use
  drag Rage under the baseline and cost nothing else, or should there be a
  Gnosis pool too? Proposal: Rage only, three stats, no fourth pool.
