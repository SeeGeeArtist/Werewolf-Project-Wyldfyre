# Werewolf: Outbreak 0.4.29: Crinos shift burst

## Behavior

A successfully completed shift into Crinos issues a single, non-damaging,
360-degree native stagger to eligible zombies in a 1.5-tile radius.
Both voluntary shifts and completed Rage-forced shifts use it. This is an
explicit close-range tuning radius, not a promise to match every held
weapon's melee reach.

The burst uses the native hit-reaction state/event machinery, with an outward
hit direction and no forced coordinate movement. It does not call weapon
Hit, deal damage, award XP/Rage, guarantee a knockdown, or apply to players.
Native displacement/animation, particularly for prone, climbing or grappling
zombies, still needs observation in the game.

Filtering excludes:

- Dead zombies and human NPCs recognized by the existing Bandit/Garou adapters.
- Zombies on another floor.
- Zombies outside the radius.
- Zombies separated by collision barriers, including closed doors/windows.

Missing collision APIs fail closed rather than allowing through-wall hits.

## Trigger and multiplayer safety

Only the server's successful TransformConfirm path, after applying the form,
triggers the effect. Cancelled/failed shifts, requests, duplicate confirms,
save loading and visual refresh do not trigger it.

For testing, the existing admin/solo Instant Form button also triggers a
burst when entering Crinos from another form. Repeated Crinos clicks while
already Crinos do nothing.

There is no burst-request command accepting client targets or radius.
The server selects nearby eligible zombies and handles server-owned ones.
It broadcasts selected client-owned zombie IDs; clients apply only to zombies
they currently own, with radius/barrier checks and packet deduplication.
Normal native zombie state replication is then responsible for observers.
Ownership handoffs and latency can still produce missed reactions; the
network path has fixture coverage but has NOT been playtested in multiplayer.

## Tuning

In `42/media/lua/shared/WTAGarouDefinitions.lua`:

```lua
WTAGarou.CrinosShiftBurst = {
    ENABLED = true,
    RADIUS = 1.5,
    HIT_FORCE = 1.0,
}
```

Radius is bounded to 0.25..3 tiles; native hit force to 0.1..2.
No extra channel, cost or cooldown was added. The existing shift rules stay.

## Coat picker

The initial position is 12 pixels below the Garou panel, with at least a
40-pixel inset from the viewport's left edge. Moving the Garou panel to the
left edge no longer puts the picker there. If the HUD is farther right, the
picker follows that x, subject to a right-screen margin. It remains draggable.

## Verification and next test

The code follows the exposed APIs in the supplied PZ 42.21 JAR:
IsoZombie stagger/hit flags and reportEvent("wasHit"), IsoGameCharacter
direction setters, and LosUtil.lineClearCollide with closed doors included.
No new Java hooks were needed; the bundled JAR version is updated and retains
the preceding silver/visual fixes.

The burst fixture tests all quadrants, radius edge, same-floor and barrier
filters, human NPC exclusion, unchanged health and coordinates, config-off,
server-selected target IDs, ownership gates, malformed packets and replay.
The full shift suite tests forced/voluntary completion, cancellation and
duplicate confirmation. These are not an in-game animation test.

Pull the branch once to receive both 0.4.28 and 0.4.29, then fully restart.
In a disposable save, surround a healthy Garou with a few standing zombies
and complete a Crinos shift. Check that they recoil outward only at
completion; try cancelling, shifting near a closed door, and moving the HUD
to the left edge before reopening the coat chooser.

Console diagnostic: `[WTAGarou][CrinosBurst] completed Crinos shift; ...`.
The log reports local pushes separately from network target count.
