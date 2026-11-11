# Werewolf: Project Wyldfyre 0.5.2

Lua-only hotfix. The Java JAR and signature are unchanged.

## Humans stay human in multiplayer

Reported November 9: a human (non-werewolf) player's clothes fell off a few
times while she was only walking around a hosted game.

Cause: the server ran the Rage engine for every online player, werewolf or
not. A human's hidden Rage could climb to 100 from stress, panic or pain,
start the Crinos countdown and force a Crinos shift. The forced shift
tore and dropped her clothes. Several other server paths (hit Rage, melee
bonus, damage refund, healing, some shift commands) also skipped the
trait check.

Now, for anyone without the Werewolf trait:

- No Rage gain or drift, no countdown, no forced shift, no clothes strip.
- No melee bonus, damage refund or werewolf healing.
- The server ignores every werewolf command from them (shift, howl, roar,
  door charge, resist, witness reports). Admin debug commands still work.
- A human save that already holds leftover werewolf state (a Crinos form,
  Rage, a pending shift or countdown, form buffs) is reset to normal once,
  and the server log prints a `[WTAGarou][Human]` line when it happens.
- Clients also ignore a shift or countdown message for a human, in case an
  older server sends one.

Clothes that were already torn are not repaired.

Not yet playtested. Test: host a game, have the human player walk around
for ten minutes, and check that her clothes stay on and the server log shows
at most one `[WTAGarou][Human]` line for her.

## Flat melee bonus

User request, November 9: form damage bonuses are now a flat amount added to
each landed melee hit, armed or unarmed, instead of a multiplier.

| Form | New bonus per hit | Old armed / unarmed |
|---|---|---|
| Glabro | +0.5 | +0.5 / +0.8 |
| Crinos | +1.0 | +1.0 / +7.0 |
| Hispo | +0.75 | +0.75 / +1.65 |
| Lupus | +0.15 | +0.15 / +0.27 |

The old multiplier never scaled the real hit: it read a weapon damage
function that does not exist in Build 42.21, so it always counted the hit as
1. The flat unarmed bonus (Crinos +6) was added before the multiplier, so a
Crinos claw took about 7 extra health. Vanilla zombies have about 1.8 to 2.1
health (tough ones 3.5 to 3.8), which is why Crinos killed everything in one
claw. Firearms still get no bonus. The Garou Guide now says "+1 melee
damage per hit" for Crinos.

Not yet playtested. Test: in Crinos, claw a normal zombie; it should usually
take more than one hit.

## Resolve unlocks moved down one level

User request, November 10:

| Resolve | Before | Now |
|---|---|---|
| 0 | nothing | zombie charge (3 zombies) |
| 1 | zombie charge | roar stagger |
| 2 | roar stagger | door charge |
| 3 | door charge | per-level passives only |

The later steps stay where they were: the zombie charge knocks down 4 at
level 5 and 5 at level 8, and the roar pushes harder at 6 and 10. The skill
tooltip, Garou Guide, Crinos description and door denial text match.
Auspices do not grant starting Resolve yet (that is still a roadmap item),
so every character starts at 0.

Not yet playtested. Test: on a Resolve 0 character, sprint into zombies in
Crinos (they should fall), press Q (no stagger), then `/garou resolve 2`
and sprint into a wooden door.

## Unchanged

Werewolf Rage, shifting, costs, timings, Resolve and all other confirmed
behavior.
