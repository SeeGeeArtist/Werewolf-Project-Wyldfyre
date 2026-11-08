# Werewolf: Project Wyldfyre 0.5.0 - The Resolve Update

Lua-only update: the Java patch and its signature are unchanged from
0.4.98/0.4.99. ZombieBuddy does not ask for a new approval.

## Shift visuals

Your model gradually grows or shrinks 75% toward the next form's size
while you channel a shift. Cancelling returns it smoothly to its original
size over one second. This effect is shown in the shifting player's own
view; other players still see the normal form change on completion.

## New skill: Resolve

Resolve is a new skill in its own "Werewolf" section of the skills panel. It is
your control over the Rage.

How to train it:

- Resist the forced change into Crinos. Every third resist in a row gives
  8 XP. The other resists give 3 XP, once per minute.
- Finish your own shifts: 3 XP, or 5 XP into Crinos, once per minute.
- Forced and cancelled shifts give nothing.

What every level gives:

- The Crinos Rage window grows by 1 (see below).
- Each resist shortens the next forced-change countdown a little less:
  2 seconds at level 0, down to 1 second at level 10.
- A fed, watered Garou settles back to baseline Rage 1% faster per level
  (10% at level 10). It is never enough to stop Crinos from burning Rage.

What specific levels unlock:

| Level | Unlock |
|---|---|
| 1 | Zombie charge: sprinting in Crinos knocks down the first 3 zombies you hit |
| 2 | Roar stagger: the Q roar in Crinos pushes nearby zombies back |
| 3 | Door charge: sprinting in Crinos smashes closed wooden doors (12 Rage, 18 if locked, plus stamina) |
| 5 | Zombie charge knocks down 4 |
| 6 | Roar pushes harder |
| 8 | Zombie charge knocks down 5 |
| 10 | Roar pushes hardest |

Hover a level in the skills panel to see exactly what it gives.

Existing characters start at Resolve 0, so the zombie charge, roar stagger
and door charge must be earned again. In single player, or as an admin,
`/garou resolve <0-10>` sets the level.

## Crinos Rage window

- You can start a shift into Crinos a little short of the 55 Rage it needs
  (6 Rage short at Resolve 0, plus 1 per level). The shift takes 1 extra
  second per missing point, up to 6 seconds.
- You can start a shift out of Crinos a little above the 75 Rage lock
  (55 for Berzerker), with the same extra time.
- Glabro and Hispo still need their full 20 Rage. The Crinos cost is still 10.

## Moonlight

- Moonlight on your skin speeds up shifting: up to a quarter faster under a
  clear full moon at night, less with clouds, fog or a thinner moon. The moon
  still helps a little by day.
- Moonlight also raises your baseline Rage, by up to 15 under a clear full
  moon. A white marker on the Rage bar shows where your Rage is settling;
  the yellow marker still shows your chosen baseline.
- You count as exposed outdoors, and indoors when standing next to an open
  exterior door, an empty doorway or an open, uncovered window. Roofs and
  covered porches block it.

## Existing characters can become werewolves

- Characters without the Werewolf trait get a one-time Yes/No offer when the
  world loads. Yes adds Werewolf, Cat's Eyes, Fast Healer and Hearty Appetite
  for free (replacing Slow Healer and Light Eater) and opens Werewolf Startup.
  Other traits and learned skills are kept. No stops the offer for that
  character.
- Tested in single player and hosted games. Dedicated servers use the same
  server-side code but have not been tested yet. Server owners can turn it off with the sandbox option "Allow existing-character werewolf
  opt-in".
- `/garou trait` grants the same set of traits.

## Other changes

- Garou can eat fresh raw food without getting sick. Rotten, tainted or
  poisoned food still hurts, and raw food does not cure poisoning you
  already have.
- The Wyrm Infection line in the health panel now wraps onto extra lines
  instead of widening the whole panel (better on the Steam Deck and other
  small screens).
- "True form" is now called "Origin" everywhere.

## Fixes

- Resolve XP is now exact. The skills panel used to show a quarter of the
  award (for example 0.75 instead of 3).
- The Resolve skill name and description no longer show as raw text with
  underscores.
- Fixed console errors when standing near doorways (moonlight check) on
  Build 42.21.

## Known issues

- Some players report the Werewolf trait not appearing in character creation,
  or removing itself right after being added. This is most likely a conflict
  with another trait mod. Until it is found, use the existing-character
  offer above. If it happens to you, please send your enabled mod list.
