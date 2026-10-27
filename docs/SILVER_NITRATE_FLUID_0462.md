# 0.4.62: silver nitrate as a fluid, coatable-weapon tag, charge meter

Answers the October 14 playtest of 0.4.61 (coated saucepan test). Shifting
near 0/100 Rage was confirmed good and is untouched.

## What you reported, what it was

| Report | Cause | Fix |
| --- | --- | --- |
| "2 bags of fertilizer is overkill" | The recipe line `item 2 [Base.Fertilizer]` is two **uses** of one drainable bag (a bag has eight), not two bags. The debug kit handed out two bags because of a wrong comment in `WTAGarouDebug.lua`. | Kit gives one bag (and leather gloves). Recipe unchanged: a quarter bag. |
| "left me with an empty jar" | The vessel was consumed and a separate jar *item* was created. | The vessel is kept and filled with 1.0 L of Raw Silver Nitrate fluid. Jars and beer bottles hold 1.0 L, a drinking glass 0.2 L. |
| Long tooltip, no line breaks; "general warning" on hover; 1092 console lines `Missing arguments for "Tooltip_WTAGarou_SilverNitrate"` | The tooltip text contained `%`, which the translator reads as a format specifier. | The nitrate items and `Tooltip.json` are gone. The fluid shows vanilla's fluid tooltip (name, poison warning). |
| "cart before the horse" (crafting menu said the nitrate needs a silver item) | Two recipes shared one requirement list in the UI. | Stage 1 (Mix Raw Silver Nitrate) needs fragments, fertilizer, battery, vessel, tool. Stage 2 is not a recipe: heat. Stage 3 (Coat) needs a weapon and any container with finished nitrate. |
| "Kept item: anything from foil to a light bulb" / "cleaver in my hand acts like I don't have it" | The weapon slot was `tags[HasMetal;...]`; HasMetal is on foil, cans and bulbs, and the crafting window lists tag matches without asking our OnTest. `flags[IsNotWorn]` also rejects **equipped** items (`InputScript`: `!isWorn() && !isEquipped()`). | New `wtagarou:coatable` tag, added by Java at item load to every non-ranged weapon script with metal (minus forge tools, materials and silver items). Both weapon slots use it; `IsNotWorn` removed. |
| Coated pan burned a bare hand | Intended: a charged coat is silver on the surface. | Gloves in the kit; guide says so. |
| "no UI indication that it has been silvered" | The `Silvered X (n)` rename exists, but a saucepan is a fluid container and `InventoryItem.getName()` returns the **fluid container's** UI name for those, so the rename was invisible on the pan (and never saved: `customName` flag). | Tooltip strip under every silvered weapon: `Silver coat: 7 of 12 hits left` or `Forged silver: ...`. Renames now set `customName`. |
| "a meter of charges" | Same. | Same strip; the name on non-container weapons still carries `(n)`. |
| "transferable liquid, like bleach" | — | Done: two fluids, Hazardous, poison like bleach (Deadly past 0.2 L, 10% dilution per litre). Pour between any fluid containers; drink it and vanilla poisons you. |
| "cook like tainted water, then pour into a different container" | Vanilla boils tainted water inside `InventoryItem.update` only for `Cookable` items (pots, kettles); a jar's heat never rises. | `NitrateHeatPatch` reads the **container's** temperature (lit campfire/barbecue/fireplace 1.8, stove ≥ 2.0) and finishes the raw mix at vanilla's tainted-water rate, so a jar or bottle works. |

## How it plays now

1. **Mix Raw Silver Nitrate** (counter or table, no skill): 1 Silver Fragments,
   fertilizer (two uses, a quarter bag), 1 car battery (destroyed), an empty
   **glass** fluid container (kept, filled), a knife/screwdriver/pliers (kept).
2. Put the vessel **inside** a lit campfire, barbecue, fireplace or a running
   stove, exactly like a pot of tainted water, and at the same pace
   (vanilla's rate constants, scaled by the item's time multiplier). Raw
   Silver Nitrate becomes Silver Nitrate in the same vessel; you can watch
   the fluid name change.
3. **Coat Weapon with Silver Nitrate** (counter or table, no skill): one
   metal melee weapon (equipped is fine) and any container holding at least
   0.2 L of Silver Nitrate. Five coats per litre. The vessel stays; empty
   after the last pour.
4. The coat eats 10% of max condition, burns Garou for 12 landed hits,
   burns a **bare** Garou hand while charged, then wears off. Hover the
   weapon for the meter.

Fluid in a vessel never burns on contact (any fluid container that is not
itself coated or forged is exempt). A Silvered Saucepan with water in it
still burns through its coat.

## Chemistry note

Silver nitrate (AgNO₃) is a white crystalline solid; it is made by dissolving
silver in nitric acid, which gives an aqueous solution, and heating drives
the reaction and boils off the water and nitrogen oxides. "Raw" here is the
cold silver-in-acid mix, "finished" the hot, settled solution. The game
fiction is defensible either way; the fluid is called a solution.

## Why the tag had to be Java

B42 `craftRecipe` inputs filter by item name or tag only; there is no "is a
weapon" filter (`InputScript` parses `item/uses/fluid/energy`, `tags[]`,
`categories[]` for fluids, `flags[]`, `mode:`). Tags live in a mutable set on
each script item and are indexed once by `ItemTags.Init` after item scripts
load, before recipes resolve their `tags[]` at `OnPostWorldDictionaryInit`.
`CoatableTagPatch` hooks that exit: for every script with `ItemType weapon`,
`!isRanged()`, `metalValue > 0` or `HasMetal`, not Tongs/File/Hammer/
ClubHammer, not a Material (spear heads), not named silver, it adds the tag
and indexes the item. Rule and advice are unit-tested (`CoatableTagTest`).

## Two latent bugs this uncovered

- `ItemTag.get(ResourceLocation.of(x))` is a plain registry lookup: a tag
  used in a script but never registered (`WTAGarouSilverAmmo`,
  `WTAGarouSealedSilver`) was **null** in-game. `registries.lua` now
  registers `wtagarou:silverammo` and `wtagarou:coatable`.
- `ItemTag:toString()` is `base:hasmetal` (namespaced, lower case), so every
  `tostring(tag) == "HasMetal"` comparison in our Lua only ever matched the
  test stubs. Both comparison sites normalise the id now, and the stubs test
  the namespaced form too.

## Files

- `42/media/scripts/silver_fluids.txt` (new), `silver_items.txt` (nitrate
  items removed, `wtagarou:silverammo`), `silver_recipes.txt` (both weapon
  slots, prepare/coat rewritten).
- `42/media/registries.lua` (two tags), `lua/shared/Translate/EN/Fluids.json`
  (new), `Tooltip.json` (removed), `Recipes.json` (recipe name).
- `lua/shared/WTAGarouSilverAmmo.lua` (`tagKey`, `hasAnyTag`, `rename`,
  `isFilledFluidContainer`, `tooltipLine`, `OnTestCoatInput`,
  `OnCoatWeapon`), `lua/server/WTAGarouSilver.lua` (`tagKey`,
  `contactExempt`), `lua/client/WTAGarouSilverTooltip.lua` (new),
  `WTAGarouDebug.lua` (kit, status prints), `WTAGarouTutorial.lua` page 6,
  `WTAGarouTestPanel.lua` label.
- Java: `CoatableTagRuntime/Patch`, `NitrateHeatRuntime/Patch`,
  `WTAGarouJava.nitrateStatus/coatableStatus/coatableCount`, banner 0.4.62;
  tests `CoatableTagTest` (27), `NitrateHeatTest` (20) with registry/fluid
  stubs. Rebuild and reinstall `WTAGarouVisuals.jar`.
- Lua suites 30 PASS (silver_ammo 153, rage_engine 655, wyrm_tutorial 90),
  Java 23 PASS.

## What to check live (42.21, Steam Deck, outside debug)

1. `/garou silver`: one fertilizer bag, gloves, jar; console prints
   `coatable tag: ItemTags.Init seen, N of M item scripts tagged` (N should
   be well over a hundred) and `nitrate heat: ...`.
2. Mix: the jar comes back as `Jar (Raw Silver Nitrate)`, 1.0 L; the
   fertilizer bag loses two uses; the battery is gone.
3. Put the jar into a lit campfire's (or running stove's) container and
   leave it, as you would tainted water in a pot; the fluid turns into
   `Silver Nitrate` at the same pace. Pour some into a glass.
4. Coat recipe: the weapon list shows only real weapons; the cleaver in
   hand is accepted; the jar or glass is the other input and loses 0.2 L.
5. Hover the weapon: the strip under the tooltip shows `12 of 12`. Hit
   zombies, watch it count down; the name on a non-container weapon counts
   too. Bare hand burns while charged, not after.
6. Drinking the nitrate poisons (vanilla). Known open: no silver burn from
   drinking it as a Garou yet; say if you want that.
