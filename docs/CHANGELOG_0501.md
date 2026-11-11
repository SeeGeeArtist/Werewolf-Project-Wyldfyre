# Werewolf: Project Wyldfyre 0.5.1

Lua-only hotfix. The Java JAR and signature are unchanged.

## Multiplayer shift visuals

- Other players can now see your model grow or shrink during a shift.
- Cancelling smoothly returns the visible model to its current form's size.
- Keeps the 75% endpoint and one-second cancellation recovery from 0.5.0.
- Shift costs, timing, Resolve progression and abilities are unchanged.

Confirmed in a hosted game on November 8: it works for other players. It
can look slightly jittery, which the author accepted. Dedicated servers are
untested.

## Raw meat can make werewolves Full

- Vanilla resets the Full timer whenever you eat food that is unsafe raw,
  so a werewolf eating raw meat never became Full.
- For werewolves, fresh raw food now counts toward Full like safe raw food.
  Cooked food still counts double, as in vanilla.
- Rotten, tainted or poisoned food is unchanged and still makes you sick.

User-confirmed on November 8: fresh raw meat produces the Full moodle,
which then disappears after about one or two minutes in the reported test.
No timer-duration tuning was requested or made.

## Daytime moonlight

- At noon the moon now pulls at a quarter of its night strength (was half).
  Dusk and dawn fall in between. Night strength is unchanged.
