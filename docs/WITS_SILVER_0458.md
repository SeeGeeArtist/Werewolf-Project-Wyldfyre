# Wits first slice, paws and the guitar bite: 0.4.58

## Baseline and evidence

This follows commit `eb24bdb` / .57 on `feature/cosmetic-model-swap` and the
mod rename to "Werewolf: Project Wyldfyre" (mod id stays `WTAGarou`).
The user's October 13 playtest confirms .57: makeup hides and restores,
headwear fits, and the hidden-head patches are gone. Those behaviours are
locked. The same report added five requests, all addressed here:

1. Hispo's attack ran "super fast" only while holding an electric guitar.
2. Quadruped forms may hold guns but must not fire or reload them (any reload action).
3. Disable crafting and mechanic work (siphoning etc.) for wolves, gracefully.
4. Metis may leave Crinos below 55 Rage instead of 35; update the tooltip.
5. Craftable silver-tipped ammunition and silvered forged weapons with instant Silver Burn.

Nothing in this release has been played live yet. Everything below is static
evidence (source reading, unit suites) plus the exact live checks that would
confirm it.

## 1. Guitar bite timing

Cause, from the pzwiki item script and vanilla combat code: the electric guitar
is `BaseSpeed 1.1`, `TwoHandWeapon`, `SwingAnim Heavy`. Vanilla multiplies
CombatSpeed by 1.1 x 1.2 for a heavy two-hander, the Skully "Heavy" table in
`WTAGarouCombatTiming` pushed that to its 1.51 cap, and the Java
`CombatRuntime` heavy recovery cap of 4 shortened recovery further. The wolf
body plays one fixed-length derived `Wolf_attack` clip, so all of that became a
machine-gun bite. Any other weapon class used different factors and looked
normal; human forms were never affected because the human swing clips scale.

Fix, both sides:

- Lua `Timing.biteSpeed(base, weapon, character)` divides the weapon class
  factor (BaseSpeed x 0.77 one-handed two-hander x 1.2 heavy two-hander) back
  out, applies the generic 1.10 and caps at 1.11. Used only for quadrupeds.
- Java `CombatRuntime`: `WolfRuntime.active(character) ? JAWS_CAP : cap(type)`
  with `JAWS_CAP = 12`. Human-form caps stay 12/12/1/8/4.

Hypothesis to confirm live: a sledgehammer (also `Heavy`) reproduced the same
bug before .58 and does not after.

## 2 and 3. Paw guard

`client/WTAGarouPawGuard.lua` (`WTAGarou.Paws`) wraps `isValid` on the vanilla
timed actions below so `ISTimedActionQueue` drops them for Hispo/Lupus with a
HUD denial line. Firing itself was already swallowed by `JawsAttackPatch`
(`IsoPlayer.pressedAttack` for ranged weapons while the wolf body is active),
which covers keyboard and controller since both go through that one entry.

| Reason | Paths |
|---|---|
| `paws_firearm` | ISReloadWeaponAction, ISRackFirearm, ISInsertMagazine, ISEjectMagazine, ISLoadBulletsInMagazine, ISUnloadBulletsFromFirearm, ISUnloadBulletsFromMagazine, ISRemoveBullet, WTAGarouLoadSilverAction, `ISFirearmRadialMenu.checkWeapon`, `ISReloadWeaponAction.BeginAutomaticReload` |
| `paws_craft` | ISHandcraftAction, ISCraftAction, ISCraftAnimAction, ISGenericCraftStart, ISStartCraftProcessorAction, ISBuildIsoEntity, ISBuildAction, ISDismantleAction, ISFixAction, ISFixGenerator, ISRepairClothing, `ISEntityUI.OpenHandcraftWindow/OpenBuildWindow` |
| `paws_mechanic` | vehicle part install/uninstall/repair, ISTakeGasolineFromVehicle, ISRefuelFromGasPump, ISOpenMechanicsUIAction and the rest of the mechanics family |

Graceful valve: `WTAGarou.Paws.RECIPE_WHITELIST` (recipe name -> true).
It ships empty on purpose: every vanilla recipe checked needs a hand tool or
fine manipulation, and the user's own conclusion was "switch to Homid". If a
recipe is whitelisted later, the crafting window opens for paws and only that
recipe passes; mechanics are never unlocked by the whitelist. Crinos keeps its
thumbs; the only Crinos restriction remains vehicle seats.

## 4. Metis exit line

`CRINOS_LOCK_ABOVE_BERSERKER` 35 -> 55 in `shared/WTAGarouDefinitions.lua`
(fallback too). Tooltip in `WTAGarouWolfCoat.lua` now reads "but will not let
you out above 55 Rage." Other breeds keep 75.

## 5. Silver ammunition and silvered weapons (Wits W1-W4, first slice)

Vanilla B42 already provides `Base.SilverScrap` ("Silver Fragments"),
silver jewellery tagged `TinySilverScrap` and silverware tagged
`SmallSilverScrap`; the vanilla strip recipe is 20:1. Ours is cheaper:

| Recipe | Inputs | Output |
|---|---|---|
| WTAGarou_StripSilverJewellery | 4 `TinySilverScrap` items + pliers (kept) | 1 Silver Fragments |
| WTAGarou_StripSilverware | 1 `SmallSilverScrap` item | 1 Silver Fragments |
| WTAGarou_SilverShotgunShells | 6 shells + 1 fragments + pliers | 6 silver shells |
| WTAGarou_SilverTip9mm / 45 / 44 / 38 / 223 / 308 / 556 | 10 rounds + 1 fragments + file + pliers | 10 silver rounds |
| WTAGarou_SilverWeapon | metal melee weapon (kept, renamed) + 2 fragments + charcoal + hammer + tongs, at a forge, Blacksmith 1 | "Silver <name>", mod-data flag |

Items (`scripts/silver_items.txt`): eight `WTAGarou.Silver*` rounds with
vanilla icons/world models and `Tags = Ammo;WTAGarouSilverAmmo`; the existing
SilverKnife/SilverMachete stay.

Loading (`shared/WTAGarouSilverAmmo.lua`, `client/WTAGarouSilverLoad.lua`):
right-click a tube/cylinder gun or a magazine -> "Load silver rounds (n)".
Loads are homogeneous: a weapon with ordinary rounds inside refuses silver
(`silver_mixed_load`) and vice versa (vanilla reload refused while silver
sits inside). Magazine guns load through the magazine. Counts live in mod
data (`WTAGarou_SilverAmmo` number; the Test Panel's boolean `true` still means
unlimited debug silver), chamber state in `WTAGarou_SilverChamber`. Seven
vanilla reload/rack/insert/eject/unload paths are wrapped so counts follow the
rounds, and unloading hands silver items back, not ordinary ones.

Burn (`server/WTAGarouSilver.lua`): `OnWeaponSwing` flags the shot
(`WTAGarou_SilverShot`) before vanilla consumes the round; the hit handler
reads that flag, so ordinary rounds left in a formerly silver gun never burn.
Located burn: the Java `SilverHitPatch` records the body-part index chosen by
`BodyDamage.applyDamageFromWeapon`; the Lua side queues the hit and resolves it
next tick on that part. No record inside 250 ms means the clothing stopped the
hit, and silver burns wounds, not coats, so nothing burns. Without the Java
supplement the pre-.58 random-part burn remains. Silvered melee weapons use the
same `WTAGarou_Silver` flag path as the SilverKnife.

Not in this slice: multiplayer synchronisation of silver counts/chamber state
(W6 gate), mixed magazines (W7), the Hunter trait (W5).

## Static verification

- Lua: `bash WTAGarou/tests/run.sh` exit 0, 30 PASS lines, including new
  `silver_ammo_test.lua` (78 checks: catalogue, loading, shots, magazines, forge
  callbacks, the seven wrappers) and `paw_guard_test.lua` (52 checks: lockouts,
  whitelist, bite-speed normalisation); `rage_engine_test.lua` 622 checks now
  cover the located burn and per-shot flag; version/tooltip/lock-line checks
  updated to 0.4.58 / 55.
- Java: `build.sh` + `test.sh` exit 0, including new `SilverHitTest` and the
  updated `WolfCombatTest` (wolf-active -> every weapon type caps at 12).

## Live checks that would confirm this

1. Full restart; console shows the 0.4.58 banners from both Lua and Java.
2. Hispo with an electric guitar, then a sledgehammer: bite cadence matches bare jaws.
3. Hispo/Lupus holding a shotgun and a pistol: reload key, rack, radial,
   right-click reload options and "Load silver rounds" all produce the
   paws_firearm HUD line; crafting window, build window and siphoning produce
   paws_craft / paws_mechanic. Homid and Crinos unchanged.
4. Metis Crinos can shift out at 55 Rage or below, not at 56; tooltip says 55.
5. Craft fragments, silver shells and silver 9mm; load a shotgun and a 9mm
   magazine; shoot a Garou: SILVER BURN lands on the wounded part, ordinary
   rounds do not burn; unload returns silver rounds.
6. Forge a machete at a forge with 2 fragments, charcoal, hammer, tongs:
   "Silver Machete", hits burn instantly.
