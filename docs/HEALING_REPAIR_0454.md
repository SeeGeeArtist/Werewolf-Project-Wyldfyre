# 0.4.54: complete supernatural wound healing

## Report and diagnosis

The user reported retained glass and deep wounds in the feet. After Crinos
regeneration closed the wounds, the character looked fully healed but kept
limping through sleep, vehicle use and shifting. The user also requested a
modest healing reduction to preserve the survival-game feel.

The existing cleanup cleared visible deep-wound flags/timers but did not
clear glass, bullets or stitches. Its wound detector did not recognize these
leftovers or several orphaned timers, so they could stop progressing after
the visible wound disappeared.

The available engine reference's foot-injury calculation independently checks
glass and positive stitch time, without requiring reduced HP or a visible
deep-wound flag
([IsoGameCharacter.calculateInjurySpeed](https://raw.githubusercontent.com/Ketum-Git/PZ-Javacode/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/characters/IsoGameCharacter.java)).
That is a concrete code defect matching the report, not proof that every
possible source of the user's limp has been ruled out. The promised current
console was not available when this source-level fix was prepared.

## Fix

Completed ordinary regeneration now:

- Detects glass, bullets, stitches and nonzero scratch/cut/deep-wound/bite/
  stitch/infection timers even when HP is full or visible wound flags are off.
- Expels embedded glass and ordinary bullets.
- Removes stitches as a completed wound, then clears stitch time.
- Clears the wound flags, timers and additional wound pain after those steps.
- Keeps completion progress at 100% if an engine setter fails, logs once,
  and retries without making the character wait another whole window.

Ordering matters: native bullet removal creates a deep wound and bleeding;
native stitch removal can create a scratch or reopen a deep wound
([BodyPart methods](https://raw.githubusercontent.com/Ketum-Git/PZ-Javacode/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/characters/BodyDamage/BodyPart.java)).
The patch performs these operations before the final cleanup, not afterward.
It uses mature-stitch removal to avoid the early-removal branch, then clears
the generated scratch/timer as part of that completed supernatural repair.

No whole-body restore, movement-speed override or animation-flag reset is
used. Other injuries, exhaustion, footwear, carried loads and physical
treatment items such as splints are not erased or bypassed. A splint can
still need normal removal; this change is not an inventory auto-unequip system.

## Modest rate reduction

| Ordinary regeneration | Before | After |
|---|---:|---:|
| Crinos body-part HP per second | 2.0 | 1.6 |
| Hispo/Glabro body-part HP per second | 0.7 | 0.56 |
| Crinos wound completion | 60 seconds | 75 seconds |
| Hispo/Glabro wound completion | 180 seconds | 225 seconds |

This is 20% less HP/bleeding-taper throughput and 20% slower ordinary wound
progress, meaning completion takes 25% longer. Homid and Lupus keep vanilla
healing. Zombie bites and Wyrm Infection still take 300 seconds in Crinos or
900 in Hispo/Glabro; hidden/bandaged bite timers also keep that longer window.
Silver-burned parts remain excluded from the supernatural boost and cleanup.
The in-game Guide is updated to match.

## Existing characters and local multiplayer

A closed-looking foot with retained glass or stitch state is now detected
as an unfinished injury. It completes through the ordinary regeneration
window without reinjury, a new character or a global heal cheat.
Form changes preserve the existing cumulative wound-progress behavior.

The healing-only tick clock is now keyed by character object. Two local
characters sharing an offline online-ID sentinel cannot steal each other's
healing time. Server authority and the user-confirmed .51 HUD/network changes
are untouched.

## Verification

The full Lua/asset suite and whitespace checks passed. New tests reproduce
both feet at full HP with glass penalties and cover ordinary completion,
orphaned stitch/timer state, native-like bullet/stitch removal side effects,
existing-save recovery, failed-setter retry, silver blocking, preserved bite
windows and two actors sharing an offline ID.

The Rage/regeneration suite now passes 607 assertions; the full existing
HUD, radial, networking, combat, sound, corpse, coat and asset suites also pass.
Java source/JAR, animation XML, head model scale .675, GLB and PNG files are
unchanged. The engine reference above is 42.20.2, not a claim that the user's
42.21.0 binary was directly executed here. Live healing/movement still needs
the user's test.

## Focused playtest

1. Update server and clients, then fully restart. Expect **Lua/mod 0.4.54**
   and unchanged **Java 0.4.52**; no new JAR or model export is needed.
2. Use the affected character. Accumulate about **75 seconds in Crinos**
   or **225 seconds in Hispo/Glabro** with no silver burn on the affected part.
   Homid/Lupus pause progress rather than curing the hidden state.
3. Check that retained glass/deep-wound/stitch effects finish together and
   normal movement returns once no other movement-affecting injuries or
   equipment remain.
4. On a disposable test save, verify fresh glass wounds still need the full
   healing window, while silver burns and zombie bites are not fast-cured.
5. If limping remains, send the fresh client console and a health-panel
   screenshot showing both feet and legs. Do not reset all body damage or
   overwrite WalkInjury merely to hide the symptom.

Head-size testing can continue separately. Shove-animation work remains
explicitly deferred.
