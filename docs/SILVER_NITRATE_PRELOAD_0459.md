# Silver nitrate coatings, forge skill, sealed silver and the first-shift pop: 0.4.59

## Baseline and evidence

Follows `e49b8d2` / 0.4.58 on `feature/cosmetic-model-swap`. 0.4.58 has not
been played yet; its live checks still stand. This release adds the user's
second silver route and fixes the delay between the end of the first
Crinos/Hispo/Lupus channel and the model appearing. Everything here is
static evidence (B42.20.2 scripts and decompiled source, unit suites) plus the
live checks that would confirm it.

## Silver nitrate (the cheap, temporary route)

Chemistry the recipe leans on: NPK fertilizer supplies nitrate, a car battery
supplies sulphuric acid, nitrate + sulphuric acid is the classic nitric-acid
preparation, nitric acid dissolves silver into silver nitrate. Painted on a
steel blade, iron displaces the silver out of solution: a thin coat of
metallic silver forms while the iron underneath corrodes. That is why the
weapon loses condition, why the coat is real silver to a Garou, and why it
wears off.

| Step | Recipe | Inputs | Result |
|---|---|---|---|
| 1 | `WTAGarou_PrepareSilverNitrate` (surface craft, no skill) | 2 uses NPK Fertilizer, 1 car battery (destroyed), 1 Silver Fragments, 1 empty jar; knife, screwdriver or pliers kept | Jar of Raw Silver Nitrate |
| 2 | vanilla cooking | the jar on any lit stove, campfire or BBQ, 20 min (burns after 180) | Silver Nitrate, 4 applications |
| 3 | `WTAGarou_CoatSilverNitrate` (surface craft, no skill) | metal melee weapon (kept) + 1 application | "Silvered <name> (12)" |

Build 42 facts used: a drainable listed as `item 2 [Base.Fertilizer]` gives
up two uses (`InputScript` treats drainables without ItemCount/destroy/keep
as partial inputs); `Base.CarBattery1/2/3` are drainables with a tiny
UseDelta, so the battery slot is `mode:destroy` or it would only lose a
trickle of charge; the crafting system has no "lit fire nearby" condition, so
heat comes from the cooking system via a `Food` item with `CantEat`,
`IsCookable` and `ReplaceOnCooked`, like toast or tallow.

Coat behaviour (`WTAGarou.SilverAmmo`, `server/WTAGarouSilver.lua`):

- 12 landed hits per coat, zombie or Garou; each hit spends one charge, and a
  Garou hit burns exactly as forged silver does.
- 10% of max condition per coat, rounded, never below condition 1.
- Name shows the charges: "Silvered Machete (12)" ... "(1)"; at 0 the
  original name returns and the wielder sees "The silver has worn off your
  weapon."
- Forged "Silver" weapons refuse a coat; a coated weapon can be re-coated
  (count back to 12, condition paid again); a worn-off weapon can be forged.
- Rifles, bats and tools (hammer, tongs, file) are refused by the OnTest.

## Forge skill rule

"Any skill requirement for forging vanilla weapons should also apply to
forging silver ones." `WTAGarou_SilverWeapon` keeps `SkillRequired =
Blacksmith:1` as the floor the crafting window enforces; its OnTest also
checks the player's Blacksmith level against `S.FORGE_LEVELS`, derived from
the B42.20.2 recipe scripts by following each weapon back to its
Forge-tagged blade/head recipe (assembly mappers included). Examples:
Machete 9, Sword 9, Wood Axe 8, Crude Sword 8, Shortsword 7, Axe 6,
Hunting Knife 5, Kitchen Knife 4, Meat Cleaver 4, Hatchet 4, Small Knife 1.
Loot-only twins (Base.Machete, Base.Axe, Base.HuntingKnife, Katana as a
sword...) inherit; weapons vanilla cannot forge (crowbar, pipes) use the
floor. The nitrate recipes ask for no skill.

## Sealed silver: exceptions to the name rule

A Garou carrying a glass jar of silver nitrate does not burn. Contact scans
now use `contactSilver(item)` = silver AND NOT sealed; sealed means the
`WTAGarouSealedSilver` tag or a type in `S.SEALED_TYPES` (both jars). Silver
rounds inside a gun or magazine were already not contact silver (the gun's
mod data count is not the `WTAGarou_Silver` flag). Held or worn bare silver,
silver rounds in the hand, forged or coated weapons in the hand: still burn.
Weapon hits ignore the exemption on purpose.

## Guide and Steam notes

- Werewolf Guide page 6, "Silver: the hunters' edge": fragments, rounds,
  forged silver and its skill rule, silver nitrate, the glass exception.
- `mod.info` description now ends with the hunters' edge sentence; the full
  Workshop draft is [STEAM_DESCRIPTION.md](STEAM_DESCRIPTION.md).
- `Translate/EN/Recipes.json` names every WTAGarou recipe; `Tooltip.json`
  holds the two jar tooltips.

## First-shift model pop

Cause, from `WolfRuntime.setWolf` and `CrinosCosmetics.set`: both ask
`ModelManager.getLoadedModel` / `Texture.getSharedTexture` for the first
time when the first shift completes, get "pending" while the engine loads
asynchronously, and Lua re-asked only once per second (60 attempts). The
player is already in the scaled human body with clothes stripped during that
wait.

Fix: `WTAGarouJava.preloadForms(body, head, wolfTexturePath)` warms the wolf
model and clips (`WolfRuntime.preload`), the Crinos head model and the coat's
body/head textures (`CrinosCosmetics.preload`) without mounting anything;
`Visual.preload(player, coat)` calls it from every `Visual.refresh` (so from
OnCreatePlayer and whenever the coat changes) and polls every 0.1 s until
"ready", logging `[WTAGarou][Preload] wolf + Crinos assets ready (N s)`. The
pending retry for the real requests is now 0.1 s with a 60 s give-up instead
of 1 s and 60 attempts. If the engine evicts the assets after a long Homid
stretch the fast retry still bounds the pop to about a tenth of a second.

## Static verification

- Lua `tests/run.sh` exit 0, 30 PASS: silver_ammo_test 119 (forge levels,
  skill gate, nitrate scripts, coat apply/spend/wear/re-coat, condition
  floor), rage_engine_test 633 (sealed-silver contact exemption, coat spend
  on hits, worn-off message), crinos_cosmetics_test 45 (0.1 s retry, 60 s
  give-up, preload polling), wyrm_tutorial_test 89 (guide page 6).
- Java `build.sh` + `test.sh` exit 0, 20 PASS; CrinosCosmeticsTest covers
  `preload` and `preloadForms` (pending/ready/failed, no character touched).

## Live checks that would confirm this

1. Restart; console shows the 0.4.59 banners (Lua and Java) and a
   `[WTAGarou][Preload] ... ready` line within a few seconds of spawning.
2. Fresh character: first Crinos and first Hispo channel end straight on the
   model, no underwear frame. Then the same after ten minutes in Homid.
3. Counter: Prepare Silver Nitrate consumes 2 fertilizer uses, the battery
   and the jar, keeps the tool. Cook the raw jar on a stove: Silver Nitrate
   with 4 uses. Coat a machete: "Silvered Machete (12)", condition down 10%.
4. Hit zombies: count falls per landed hit; at 0 the name reverts and the HUD
   says the silver wore off. Hit a Garou with a coated weapon: Silver Burn.
5. Garou holding the jar: no contact burn; holding a Silver Knife: burn.
6. Blacksmith 3 cannot forge silver into a machete (recipe greys out on the
   weapon), can into a Small Knife; Blacksmith 9 can do the machete.
7. Guide page 6 reads correctly on the Deck; recipe names appear as
   "Prepare Silver Nitrate" etc. in the crafting window (if they still show
   `WTAGarou_...`, the Recipes.json key form is wrong and only the file needs
   fixing).
