# 0.4.73: follow-ups to the 0.4.72 notes (October 18)

## Nitrate range

Tiles are the one-metre ground squares, and 6 of them was far too tight.
The scanner is now two passes: a DISCOVERY walk of the squares within 15 m
of each local player about every 2 s that remembers every container holding
raw nitrate (hot or not), and the simulation itself, which runs on the
remembered containers twice a second with no distance limit for as long as
this client still has their chunk loaded. Put the jar in the oven, walk off,
come back later. Only when nobody running the mod has the area loaded does
the cooking pause (vanilla ovens pause in unloaded chunks as well). Console:
`[WTAGarou][Silver] watching a stove with raw silver nitrate (...)`, then
the warming / server lines from 0.4.72. `/garou silver` status now reads
`N container(s) watched, N vessel(s) warming, N report(s) sent`.

## The growl before she died

Not silver. Silver hits on another player never reached her client in
0.4.71 (0.4.72 relays them), and neither console has a silver line. The
Crinos has no pain growl either (only Lupus/Hispo yelp on damage;
`WolfSounds.PAIN_TYPES`). `WTAGarou_CrinosGrowl` plays for exactly two
things: the crouched Q callout, and the silver-burn cue. So either she was
crouched and pressed Q, or what you heard was the forced shift sound when
death reset her form. From 0.4.72 on a silver hit will log `burned by
silver` on her console and `silver hit relayed to <name>` on the server.

## Health pool per form

Vanilla recomputes overall health from the body parts every tick (100 minus
the weighted part damage) and dies at 0, so the pool cannot simply be a
bigger number. Instead every ACUTE hit is scaled before it reaches a part
(`BodyPart.AddDamage`, the funnel for weapon and bullet hits, bites,
scratches, lacerations, falls, vehicle impacts): Java `ToughnessRuntime`,
Lua `WTAGarou.DamageIntake` registered per form on the local client.

| form | intake | effective pool |
|---|---|---|
| Homid, Lupus | 1.00 | 100 |
| Glabro, Hispo | 0.65 | ~154 |
| Crinos | 0.40 | 250 |

A point-blank shotgun on a player is about 5 pellets x Rand(2, 2.5) x 15
with head/neck x4 and upper torso x2 (`BodyDamage.DamageFromWeapon`),
roughly 235 on an average spread: a healthy Crinos is left standing with
little health, and two head pellets still kill. Bleeding, deep wounds,
infection and hunger are not scaled, so the mauled Crinos still bleeds out
at human speed and still needs bandages; the Crinos regeneration from 0.4.68
is what buys the "few more seconds". Ranged hit reactions stay vanilla
(Poise never filters them), so the stagger from the blast is unchanged; a
guaranteed knockdown from heavy firearm hits is not added here.

Players own their own BodyDamage in multiplayer, so this runs on the struck
player's client; both machines in the test run the Java agent.
`java/test/ToughnessTest.java`, `tests/definitions_reload_test.lua`.
