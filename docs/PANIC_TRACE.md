# Frightened moodle: diagnostic playtest

Version: **0.4.3-panic-trace**, branch `feature/cosmetic-model-swap`.
This release does not claim to fix the reported moodle flicker. It adds
the missing measurements needed to investigate without altering panic.

## What the current evidence says

The supplied 0.4.2 console has no WTAGarou exception matching the reported
flicker, but it contains no raw panic or panic-moodle values either.
It does contain unrelated startup errors; this is not a claim that the
entire log is error-free. The user confirms Hispo Rage text remains
visible and the reduced visual scales look believable.

The WTAGarou code audit found no explicit panic setter or panic-moodle
reset. The negative-moodle Rage calculation reads moodle levels; healing
adjusts wound/bleeding timers. That does not rule out indirect effects or
an engine interaction, and it is not proof that vanilla is responsible.

“Frightened” is a level of the Panic moodle, rather than a separate Fear
stat, according to [PZwiki's Panic documentation](https://pzwiki.net/wiki/Panic).
That general documentation is not proof of the cause in B42.20.4.

## Capture the next occurrence

1. Pull this branch and restart the game. Check for
   `Definitions loaded - version 0.4.3-panic-trace`.
2. Shortly before reproducing the flicker, type this in chat:

   ```text
   /garou panictrace 60
   ```

   Or use the Lua debug console:

   ```lua
   WTAGarouPanicTrace(60)
   ```

3. Reproduce the flicker and note the form and whether zombies are in view.
   If safe, compare stationary behavior against turning to look away and
   back, without changing medication or other conditions mid-comparison.
4. Send `console.txt`. Lines prefixed `[WTAGarou][PanicTrace]` contain the
   elapsed real time, form, Rage, raw panic/stress, corresponding moodle
   levels, and the body's panic-increase value when exposed.
5. Tracing stops automatically. `/garou panictrace 0` stops it early.

The trace reads every client tick while active, logs moodle/form transitions
and a one-second heartbeat, accepts 1-120 seconds, and caps output at 600
sample lines. It also stops on death or player replacement. It is off
by default and never writes stats, moodle levels, or Rage. Unavailable
APIs produce `nil`, not zero. Client samples cannot guarantee capture of
changes that happen and reverse between callbacks or establish causation.

If raw panic and its moodle level drop together, investigate what changes
the underlying panic. If the reported icon disappears while the logged
level remains nonzero, investigate UI/engine timing rather than artificially
holding panic high. A follow-up engine-level trace may still be needed.

## Panel adjustment and preserved behavior

The default is 16 pixels farther left: `(144, 0)` at 1920px screen width,
or `(90, 0)` at 1280px width. Coordinates remain screen-clamped.
Unversioned saves at the old exact default migrate once; custom positions
and pin state are retained. Old saves do not record whether an exact-default
position was manually chosen, so that case cannot be distinguished.
After a resolution change, use `/garou hudreset` if the saved old default
is not recognized. This command intentionally resets placement.

Shift code, Rage drawing, gameplay stats, and the Java JAR are unchanged.
Scale remains Homid/Lupus 1.00, Glabro 1.08, and Crinos/Hispo 1.25.
Literal `nil, nil` shifting and suppression of the default action pose
remain covered by the regression suite.

## Verification

Run `bash WTAGarou/tests/run.sh` from the repository root. Version 0.4.3
passes Lua 5.1 syntax checks and 600 mock assertions: 28 visual, 544
channel/HUD, and 28 panic-trace. Git whitespace checks also pass.
The assistant has not run this build inside Project Zomboid; runtime
API availability and the actual moodle symptom require the next playtest.
