# Crinos headwear and makeup: 0.4.56

## Change contract

- **Target:** restore makeup outside Crinos and fit rigid head accessories to the smaller head.
- **Confirmed working:** user approves Crinos head orientation and scale **0.6**; makeup disappears in Crinos; split-screen ownership works.
- **Observed failure:** makeup does not visibly return in human forms. The uploaded October 12 console loads Java/Lua .55, mounts the head at 0.6, and records Crinos cosmetics being disabled on return to Glabro.
- **Untouched:** head GLB, every coat PNG, head script/rotations/scale, form body scale, healing tuning, split-screen routing, voice/knockback cooldowns, wolf harness/carry, and deferred shove work.
- **Evidence still needed:** live makeup restoration and actual fit of representative hats, earrings, and glasses on both sexes, including a remote multiplayer character.

## Implemented

### Makeup restoration

The old body map could outlive its character's Crinos profile. Clearing the
profile requested a model reset but left face filtering and fur composition
eligible on that body until native recycling reached `ModelInstance.reset`.
The previous restoration fixture used a fresh body, missing this case.

Body registrations now contain a weak owner reference. Disabling or changing
the profile immediately invalidates that character's registrations, and every
ownership query checks the current profile. Model and texture refreshes are
requested together. Another character using the same coat remains independent.
The existing native-reset hook remains in place.

This repairs a demonstrated source/fixture lifetime gap; the log does not
prove it was the sole cause of the user's visible failure. Saved makeup is
still only read and copied, never deleted/reapplied by the mod. A new
`[CrinosMakeup]` transition message reports the number of saved makeup entries,
so a follow-up log can distinguish missing saved data from stale rendering.
This does not invent makeup that has already been removed by some other path.

### Head-worn accessories

Rigid clothing mounted to `Bip01_Head` is contracted by **0.6** about the
animated head pivot after native attachment placement:

```text
corrected position = head pivot + 0.6 * (original position - head pivot)
```

This scales both geometry and its distance from the head pivot, rather than
shrinking each object in place while leaving it hovering. Native item scale,
shared model scripts, and animation bones are untouched. The correction is
recomputed from the native matrix each time, so rebuilds do not compound it.
Both the ordinary render matrix and the instanced shader copy are updated.

Glasses/eye-slot visuals are no longer hidden. Hats, earrings, and glasses
using native rigid head attachments qualify; the Crinos head, hair, weapons,
other body gear, and skinned clothing do not. Skinned hoods and unusual
modded attachment layouts are deliberately left native, not claimed supported.
Scaling alone does not reshape a human hat or glasses to match a wolf muzzle.

Entering Crinos retains head-only Hat, FullHat, Bandana, Headband, Mask,
MaskEyes, and MaskFull clothing. Lupus/Hispo still drop these without damage.
Body clothing still tears/drops, SweaterHat retains its prior policy, and
manual Strip/Dress remains available.

## Static verification

- Full Lua syntax, gameplay fixtures, and asset/package suites.
- Full Java build and advice/ownership regression suite.
- 53 Crinos cosmetic/compositor assertions.
- 69 face-visual assertions, including same-body restoration before recycling, repeated shifts, remote visual snapshots, nested scopes, and exception cleanup.
- 37 headwear retention/other-form clothing assertions.
- 2,128 numerical headwear checks using real JOML 1.10.5 arithmetic and actual woven ZombieBuddy advice, with synthetic animated bones and native-shaped matrix helpers. Includes rotated/scaled parents, multiple head poses, repeated rebuilds, shader publication, normal-form restoration, and per-character isolation.

The external test-only JOML dependency is not packaged in the mod. Run the
numerical suite with `JOML_JAR=/path/to/joml.jar bash WTAGarou/java/test.sh`.
The engine reference is B42.20.2; these are not a boot of the user's B42.21
runtime and do not establish visual correctness or multiplayer acceptance.

## Focused live test

1. Update `feature/cosmetic-model-swap`, fully exit the game, and restart.
   Approve the changed Java supplement if ZombieBuddy asks. Confirm both
   Definitions and Java banners say **0.4.56**.
2. Start in Homid or Glabro with visible makeup, a hat, glasses, and earrings.
   Note which items are worn before shifting.
3. Shift to Crinos. The head must remain at its approved size/orientation;
   makeup should hide; rigid head accessories should contract toward the
   head without disappearing. The hat should stay equipped.
4. Turn the head, crouch, and equip/remove one accessory to trigger a rebuild.
   Accessories must not shrink further on successive rebuilds.
5. Return to Glabro, then Homid. Makeup should return without reapplication;
   accessories should have their normal size and placement.
6. Repeat, then check another player independently. Prioritize an online
   client/remote observer; a split-screen pass is additional coverage.

If makeup still fails, include the console's `[CrinosMakeup]` lines. If an
accessory does not scale, provide its item name and a screenshot, along with
any `[CrinosHeadwear]` message. No new Blender export is needed.
