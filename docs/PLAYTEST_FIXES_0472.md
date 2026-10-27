# 0.4.72: October 18 hosted multiplayer test (0.4.71)

Confirmed in that test and locked: shifting in hosted multiplayer, the
ctrl+click claw swing (now plays), the 0.4.71 HUD/legwear changes.

## Raw silver nitrate never cooked in multiplayer: root cause

Both consoles show the silver kit granted and then nothing: no nitrate line
at all, and the Java status at kit time reads "InventoryItem.update seen, 0
conversion ticks". The vessel was red (hot) in the oven and in the microwave
for 30 game minutes and stayed raw.

The 0.4.66 design made the client's Java the multiplayer authority, hooked
on `InventoryItem.update`. That hook cannot fire for a jar in an oven on a
client. `IsoCell.update` (decompile, B42.20.2) runs `ProcessItems` only

```java
if (!GameClient.client && !GameServer.server            // single player
    || GameServer.server && now - lastServerItemsUpdate > 5000L)   // server, every 5 s
```

and the only other caller of `InventoryItem.update` on a client is
`IsoGameCharacter.recursiveItemUpdater`, which updates `IUpdater` items in
the player's own bags (radios, alarm clocks). World containers are the
server's job, and the hosted child server has no Java. So in multiplayer the
feature had no engine to run on.

## Fix: the client simulates in Lua and reports

No Java on either side (rule 0.4.65) and the client never touches the item
(rule 0.4.66). Shared math in `WTAGarouSilverAmmo.lua` (`S.Sim`, in game
minutes): a vessel warms from 1.0 to the 1.6 boil point in 5 minutes inside
a running oven/microwave or a lit fire (`ItemContainer.getTemprature()`
reads the stove/barbecue/fireplace state, which is synced to clients), then
finishes 0.1 L per minute. A one-litre jar is done in about 15 game minutes
of oven time. `simWarm`, `simConvert` are pure functions; one step is capped
at 10 minutes so a pause or lag spike cannot finish a jar in one tick.

`WTAGarouNitrateSync.lua` (client, multiplayer only): about twice a second
it walks the squares within 6 tiles of each local player, every container of
every object there (`getContainerCount/getContainerByIndex`, legacy
`getContainer`), and every item with raw nitrate. A vessel is tracked once
it sits in something warmer than cold and followed while it cools. When
0.05 L has finished (or the vessel is done) it sends one `NitrateCooked
{item, raw, done}` with absolute litres, the command 0.4.66 already had. A
report in flight is not repeated until the client's copy of the item
reflects it (the server's `sendItemStats`) or 3 s pass, so a stale read can
never re-raw the mix. Console: `[WTAGarou][Silver] nitrate vessel warming in
a stove (temp 2.00): 1.00 L raw, 0.00 L done` once per vessel.

`WTAGarouNitrateServer.lua`: applies the report as before (`applyNitrateReport`
refuses anything that adds raw or changes the total) and now owns the pace:
per vessel at most `nitrateAllowance(minutes since the last accepted
report)` = 1.5x rate + 0.05 L slack; a faster report is clamped, not
refused, so two clients watching one oven cannot double it. Console:
`[WTAGarou][Silver] nitrate warmed on the server: 0.050 L finished`.

`/garou silver` status now prints the scanner line: `nitrate MP
simulation: client scanner on, N vessel(s) tracked, N report(s) sent`.
Single player is unchanged (Java frame simulation). The Java status string
no longer claims the client is the MP authority.

What to test: jar in a running oven or microwave, stay within 6 tiles, watch
the console for the "vessel warming" line, then the server "warmed" lines;
the tooltip litres should move within a game minute of the boil point.

## Silver hits on another player did not register

No `burned by silver` on either console because `OnWeaponHitCharacter`
fires on the ATTACKER's client where the other player is a network proxy;
burning its body parts changes nothing on her machine. Players own their
own BodyDamage in multiplayer, so 0.4.72 relays the hit:

- attacker client: silver weapon/round hit on a remote player sends
  `SilverHit {target onlineID, damage}` (and still spends a coat charge);
- server: checks the attacker's primary-hand item is silver or firing
  silver, the target exists and is within 40 tiles, then sends
  `SilverHitRelay {damage}` to her client; logs `silver hit relayed to
  <name>`;
- her client: `S.applyRelayedHit` burns a random part through the usual
  `burnHit/announce` (growl, HUD notice, halo) and applies the Garou damage
  multiplier to her own body.

A hit on yourself (or anything in single player) takes the direct path as
before. `tests/rage_engine_test.lua` covers client/server/struck-client.

The point-blank shotgun death itself is vanilla damage; a Crinos has no
extra health pool, only the flinch/poise rules.

## Unarmed contact audio and blood

- Crinos unarmed hits (attack button and spacebar shove alike) play the
  vanilla `ZombieScratch` event; Lupus and Hispo unarmed hits play
  `ZombieBite`. The stomp (`isAimAtFloor`) keeps vanilla audio. Both are
  the events `BodyDamage` plays when a zombie lands them; unknown events
  fail closed with one console line.
- Those hits now fling blood (`Attack.flingBlood`): vanilla bare hands never
  do, because `BareHands` has no `SplatBloodOnNoDeath` and
  `IsoGameCharacter.Hit` skips `splatBlood` for them. Crinos: 3 floor splats
  plus a torn bloody scratch decal on the zombie; Hispo 2 and Lupus 1 splat
  with a plain blood decal. Scaled by the BloodLevel sandbox option (None =
  nothing, Ultra = triple). Attacker's client only, like the vanilla
  no-death splat.
- The claw swing's `m_SpeedScale` goes from 0.80 to 1.25 (both the shove
  and shoveAim nodes) because it read slow.

## Noted, not changed

- Zombies dying after a knockdown: the Crinos melee surplus
  (`WTAGarouServer.lua`, 2x melee) takes their health below zero on the hit;
  the engine then kills a knocked-down zombie whose health is gone when it
  reaches the floor. Expected with 2x melee.
- Wolf-born corpse looked Hispo-sized: `TrueFormCorpse.size` sets the corpse
  atlas model to the 0.6 body normalization with no form factor, which
  should be slightly SMALLER than a live Lupus (0.6 x 1.15). A larger corpse
  suggests the size step did not run for a corpse created from a remote
  player's death packet. Needs a screenshot and a single-player comparison
  before touching it.
- Respawn far away: vanilla spawn-point selection; faction/safehouse spawn
  is the vanilla way to respawn near each other.
