# 0.4.98: Java patches missing when the mod loads at startup

## What broke

First Workshop build on a Steam Deck: Lupus and Hispo showed only hair
and the harness, Crinos kept the human body under the wolf head and legs.
Same jar worked from the local `Zomboid/mods` folder and on the PC.

## Cause

ZombieBuddy applies our `@Patch` advice in one pass when it loads the jar.
Classes already loaded are retransformed; classes loaded later are patched
on load. A class the JVM first loads *while* another class is being
retransformed (the verifier pulls in IsoGameCharacter's field and method
types) falls into neither group: ByteBuddy's circularity lock skips it, and
it stays unpatched for the whole session.

Local copy: the mod loaded on the second mod pass, after the main menu,
when ModelManager, HumanVisual, AnimationPlayer and friends were already
loaded. Workshop copy on the Deck: the mod loaded on the first pass during
startup, before those classes existed. Console evidence (Deck, 0.4.97):
43 of 64 advices applied; `ModelManager.getBodyModel` (wolf body swap),
`HumanVisual.getBodyVisuals` (Crinos body texture), `AnimationPlayer.play`,
`ModelInstance.reset` and 17 others never logged `patching ...`.

## Fix

`Main.main` (which ZombieBuddy calls before it scans for patches) now loads
every patch target class, without initialising it, so all 30 targets are in
the retransform pass. The target list is read from our own `@Patch`
annotations; `PatchTargetsTest` keeps the fallback list equal to it.

Console line to look for: `[WTAGarou Java] 0.4.98 loaded; patch targets
preloaded=30/30`. If a number is lower, the names follow.

## Also in 0.4.98

PawGuard refusals are throttled (flash twice a second, log once per 10 s).
Vanilla re-queues a refused reload every frame, so a wolf holding an empty
gun wrote 11,000 console lines in one session.
