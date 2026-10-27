# 0.4.53: Crinos head facing-only correction

The user confirmed the .52 head is now upright but still faces backward.
This small follow-up preserves the upright axis and reverses facing; it does
not change head size, neck offset, body scale or any mesh/texture bytes.

## Exact change

Apply a 180-degree turn about the fitted head-local X axis, which is the up
axis after .52's correction. The two existing attachment modes become:

| Engine mode | Attachment | Script rotation XYZ |
|---|---|---|
| Direct self attachment | `mount_direct` | `180 0 -90` |
| Inverted self attachment | `mount` | `0 0 90` |

The regression test calculates the effective matrices in both modes. It
requires that the .52 up vector is unchanged and the forward vector is
negated, in addition to the existing proper-rotation and scale checks.
Head scale remains **0.5**, offset remains **0 0 0**, and Java continues
selecting the correct mode without any new runtime code.

The user did not confirm the final head size or neck fit yet, so those
remain open rather than being declared solved.

## Shove status

The user confirms the empty-handed attack still shoves. No animation change
is included here. The .52 read-only `CrinosAttackDiag` output is needed to
distinguish missing node loading, false eligibility or different native
node/state selection. Existing diagnostics remain active for the first
two local empty-handed Crinos swings per session.

## Install and retest

Fully quit, pull the branch and update the installed model script and Lua.
After restarting, expect **Definitions/mod 0.4.53 and Java 0.4.52**. The
unchanged Java version is intentional; no new JAR or Blender export is needed
when updating from .52.

Check the head from the front and side. Make two empty-handed standing
attacks and send the fresh `console.txt` if the shove persists, including
the `[WTAGarou][CrinosAttackDiag]` lines.

The full Lua/asset regression suite and whitespace checks passed. Java
source/JAR, client behavior, animation nodes, server code and all art remain
byte-identical to .52. Live facing, neck fit and attack behavior still need
user verification.
