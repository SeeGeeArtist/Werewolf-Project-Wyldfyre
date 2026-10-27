# 0.4.68: Crinos balance pass and the doorway rule

Requested Oct 17 after the 0.4.67 sound/body pass: a bigger Berzerker that
has to duck through doorways, smashes wooden doors and windows at a sprint,
shrugs off flinches, hits for half of what it did, pays Rage for violence
and heals a little slower. "A balanced crinos nerf/buff."

## What changed (player-facing)

| Area | Before | 0.4.68 |
|---|---|---|
| Size | 1.44x | 1.73x (+20%); same ground speed |
| Melee damage | 4x | 2x (firearms never boosted) |
| Rage on damage dealt | +0.15 x damage | -0.15 x damage (spent) |
| Exhaustion / drowsiness moodles | raised Rage (1.0 / 0.75) | drain Rage like sadness (1.0 / 0.75 at 0.03/level/s) |
| Healing | 1.6 HP/s, wounds 75 s | 1.2 HP/s, wounds 100 s (bites/Wyrm 300 s unchanged) |
| Melee flinch | every hit staggers | 85% shrugged off (crawlers included); knockdowns still 97% refused |
| Doorways | walks through | too tall: crouch to pass; jog/sprint ducks automatically |
| Closed wooden door at a sprint | stumble and fall | smashed: 8 Rage + 0.15 endurance; locked 12 Rage + 0.225 |
| Window at a sprint | stumble | smashes and climbs through; vanilla 50% glass cut |
| Cars | cannot enter | unchanged |

## The auto-duck question

Sneak in Build 42 is a toggle, not a held key: `IsoPlayer.updateSneakKey`
runs `setSneaking(!isSneaking())` on the crouch button and nothing in the
engine ever turns it back off. So an automatic duck has to be transient by
our own bookkeeping, and that is what ships:

1. A running or sprinting Crinos reaches a doorway edge. Java remembers
   whether sneak was already on, forces it on, and records the edge.
2. One tile past the edge (or after 2.5 s if the crossing stalls) the
   remembered state is restored: a player who was walking tall pops back up,
   a player who crouched on purpose stays crouched.
3. If the player presses the crouch key during the duck, the toggle is
   theirs again; Java stops managing it.

Walking upright into a doorway is refused and the HUD red line explains
"Too tall for the doorway. Crouch to pass, or jog through." The form guide
and the Berzerker tooltip carry the same rule and the door-charge costs.

## Where it lives

- Definitions: `FormData.Crinos.modelScale/meleeDamage`, `Traits.Crinos`
  (cadence 0.75/0.75/0.70/0.75, stride 1.73), `Rage.ON_DAMAGE_DEALT`,
  `Rage.SAD_MOODLES`, `Regeneration`, `Poise`, `Doorway`, `DoorCharge`,
  `WTAGarou.DoorChargeCost(locked)`.
- Server (`WTAGarouServer.lua`): `isRangedWeapon` guard in
  `applyMeleeSurplus`; `WTAGarou.SpendEndurance`; `CrinosDoorCharge` handler
  -> `DoorChargeResult {reason|nil, locked}`.
- Java (`WTAGarouVisuals.jar`): `DoorwayRuntime` + `DoorwayCollisionPatch`
  (IsoGridSquare.testCollideAdjacent) + `DoorChargePatch`
  (IsoMovingObject.checkHitWall); `PoiseRuntime` + `PoisePatch`
  (IsoGameCharacter.setHitReaction) + `PoiseWeaponHitPatch`
  (IsoPlayer.hitConsequences) + `PoiseZombieHitPatch`
  (BodyDamage.AddRandomDamageFromZombie); `WTAGarouJava.setPoise /
  setTallForm / tickDoorway / pollDoorCharge / setDoorChargeCosts /
  setDoorwayDuckRule`.
- Client: `WTAGarouVisual.lua` pushes poise and tall flags per form;
  `WTAGarouDoorway.lua` ticks Java, shows the hint, relays the charge and
  prints the result; guide/tooltip text in `WTAGarouTutorial.lua` and the
  Crinos description.

Servers need none of the Java (0.4.65 rule); a client without the agent
simply walks through doorways and stumbles at doors as before.

## Live verification list

- Crinos at 1.73x: head through lintels is expected; check the stride still
  matches the feet (`[WTAGarou Java][Stride]` line) and that the duck
  actually plays the crouch-run through a frame.
- `[WTAGarou][Doorway] upright tall form refused ...` once on the first
  refusal; the red line text; a jog through an open door, a sprint through a
  door frame with the door removed.
- Sprint into a closed wooden door: `[WTAGarou][Doorway] sprint charge into a
  wooden door (locked=...)` on the client and `[WTAGarou][DoorCharge] <name>
  smashed a ... door` on the server; the Break sound; planks on the floor;
  Rage -8/-12 on the bar; the exhaustion moodle creeping after two or three
  doors. A locked door at 11 Rage must bounce you (vanilla stumble).
- Sprint into a window: climb, broken glass, possible cut. A barricaded
  window must still stop you.
- Zombie scratches/bites on a Crinos: most land without the stagger; a
  crawler lunge should no longer break a swing. In a hosted game the filter
  runs on the client that simulates the attacking zombie; a flinch from a
  zombie owned by another client can still reach you (noted, not fixed).
- Rage falls while fighting now; check the bar does not race to 0 in a long
  brawl (0.15 x weapon damage per hit) and that taking damage still raises it.
