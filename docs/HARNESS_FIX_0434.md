# Harness render hook correction, 0.4.34

Follow-up playtest: the corrected hook does run, but the harness is still
invisible. The new diagnostics show its mesh/texture exist while skin data
is null. Keep the hook correction; [0.4.35 fixes the earlier cache load
order](HARNESS_CACHE_0435.md), which this patch did not address.

## Change contract

- Target: `feature/cosmetic-model-swap`, following 5eb667b.
- Confirmed by latest user playtest: saddlebags are visible; neither Black nor
  Camo harness is visible. A regular fork could not be attached to a belt.
- Must remain untouched: authored GLB/PNGs, saddlebag/cargo transforms, belt
  eligibility, gameplay, coat/gear persistence and previous working systems.
- Evidence still needed: harness visibility, fit/deformation, Black/Camo,
  form scaling, save/reload and multiplayer on the corrected build.

## Diagnosis and implementation

The uploaded console confirms Java and Lua 0.4.33 on PZ 42.21.0. It lists the
harness patch class, but never logs successful skinned-harness preparation.
A loader's patch-discovery message is not proof that advice executes correctly.

The previously supplied private engine JAR was inspected locally, not copied
into this repository. Its base AnimatedModelInstanceRenderData has:

- `initModel(ModelInstance, parentData)`: assigns the instance, allocates the
  palette, and calls `initMatrixPalette()`.
- `init()`: takes no arguments and publishes the palette already built.
- The world ModelInstanceRenderData override calls base `initModel` first,
  then caches the instance's model and texture.

The .33 hook incorrectly targeted `init` while asking for argument zero.
That was our integration error, masked by a fixture with the obsolete method
shape. Version .34 hooks `initModel` on entry, before both skin-palette creation
and the world renderer's model/texture cache. It keeps the harness's own skin
data and the wolf animator; no rigid mount or asset regeneration is introduced.
This is a confirmed API defect, not proof that it was the only visibility fault.

Bounded diagnostics now distinguish the hook being reached, Lua carrier
attachment, unexpected scripts, pending assets, missing skin/texture/animator,
and success. A static loaded model is rejected rather than rendered incorrectly.
The remaining visibility failures no longer silently collapse to false.

## Verification

The fixture reproduces the no-argument publisher, two-argument initializer and
world subclass cache ordering. It uses actual ZombieBuddy advice translation.
Additional local engine checks validate the signature/order in bytecode and
weave the advice into the supplied engine class without booting the game.

```bash
bash WTAGarou/java/build.sh
bash WTAGarou/tests/run.sh
PZ_JAR=/path/to/projectzomboid.jar JAVA_GAME=java bash WTAGarou/java/test.sh
git diff --check
```

PZ_JAR is optional and private. JAVA_GAME must support the supplied engine;
JAVAP_GAME may override the javap executable used for bytecode inspection.
Without PZ_JAR, public CI runs fixtures and assets, not real-engine checks.
All of these are implementation checks, not confirmation of a visible harness.

Local results: complete Lua/asset suite and Java integration suite passed,
including 24 harness assertions, supplied-engine signature/order checks,
actual advice weaving into the supplied class bytes, and 404 numerical JOML
attachment checks. The rebuilt .34 JAR contains no engine or test classes.
Authored assets and all model scripts are byte-for-byte unchanged.

## Smallest next playtest

1. Update the branch's mod files, including the rebuilt Java JAR. Fully exit
   and restart PZ; approve the changed JAR through ZombieBuddy if prompted.
   Confirm both startup banners say 0.4.34.
2. Enter Lupus wearing the same container that already produces saddlebags.
   No belt tool is needed to trigger the harness.
3. Switch Wolf Gear Black/Camo. Walk and turn; then test Hispo.
4. If absent, send the fresh console and a screenshot. Look for
   `[WTAGarou][Harness] carrier attached`,
   `[WTAGarou Java][Harness] initModel hook reached`,
   `waiting: ...`, and `skinned WTAGarou_Harness...`.
   Leave the old Harness offsets and authored GLB unchanged for this test.

## Fork versus belt test

The [PZ Wiki fork page](https://pzwiki.net/wiki/Fork) documents the ordinary
dining fork's attachment type removal in Build 42 and shows its Screwdriver
attachment declaration commented out. This is documented B42 behavior, not an
inspection of the installed 42.21 item script; failure with that item alone
does not establish a broken mod belt.

Test a worn belt with a screwdriver, knife, or wrench instead. The existing
WTAGarou test panel's Gear kit adds a wrench and meat cleaver to inventory,
plus bags; it does not equip items or provide a belt. It has not been changed.
The [belt/suspenders attachment documentation](https://pzwiki.net/wiki/ALICE_Belt_and_Suspenders)
also distinguishes the garden Hand Fork from the regular dining Fork.
