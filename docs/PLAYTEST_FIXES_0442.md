# 0.4.42 — Oct 6 playtest fixes

## Change contract

```text
Target: ground-grab corpse offset direction, tail wag during corpse pickup /
  put-down, 5 s cooldown on standing Q roar knockback, Hispo/Lupus melee reach
  +30%, picker named "Garou Startup".
Confirmed working (user, .41): silver burn cue per form (human grunt, wolf growl,
  no per-second repeat), wolf true form keeps clothing, reversed wolf drag walk,
  trunk drag-out corpse offset, corpse stow / put-down, vehicle impact sound,
  mod audio follows the SFX slider, Reset identity (after reopening).
Must remain untouched: shoulder-grip offset result, drag gait, stow path,
  completed-shift burst, roar noise radius, melee damage/speed, gear/coats.
Evidence still needed: in game.
```

## Evidence (Oct 6 console)

```text
[Drag] clip 'Bob_PickUp_Person_OnBackLegs' -> Wolf_eat
[Grapple] node forward offset -0.700 in state PlayerDraggingCorpse; wolf extra 1.00 applied
[Drag] clip 'Bob_IdleDrag_PersonLegs' -> Wolf_idle
[Grapple] node forward offset -0.300 ...; wolf extra 1.00 applied   <- ground grab: corpse behind
[Drag] clip 'Bob_Cont_DragOut' -> Wolf_idle
[Grapple] node forward offset 0.300 ...; wolf extra 1.00 applied    <- trunk: correct
```

The node offset is measured along the grapple axis, which flips with the grip
(legs vs shoulders). Adding a positive metre to -0.30 moved the body to the
wolf's back; the extra now follows the node's sign (-0.30 -> -1.30,
+0.30 -> +1.30). A node at ~0 reuses the last sign seen for that character.

## Implemented

- `WolfGrappleRuntime.direction` / `offsetForward`: sign-following extra.
- `WolfPlayerClips.derivePoseOnly(..., tailBones)`: `Bip01_Tail`, `Bip01_Tail1`
  hold their first Wolf_eat key at 0 and at the clip end (cache key suffix `pt`).
- `CrinosBurstServer.onRoar`: `CrinosShiftBurst.ROAR_COOLDOWN` (5 s) gates the
  stagger only; MP noise and the Java Callout voice still fire each press; the
  250 ms flood guard stays. Console: `knockback cooling down (Xs left)`.
- `MeleeRangePatch` (OnExit of `HandWeapon.getRangeMod(IsoGameCharacter)`) +
  `MeleeRangeRuntime`: x`WolfMelee.RANGE_MULT[form]` (Hispo/Lupus 1.3) for
  non-ranged weapons of a flagged character. CombatManager melee targeting uses
  `getMaxRange() * getRangeMod(chr)` (calcValidTargets, calculateHitListWeapon,
  CalcHitListWindow). The MP anti-cheat distance check floors at 5 tiles.
  Logged once: `[WTAGarou Java][Melee] range mod ...`.
- Picker: `Coat.TITLE = "Garou Startup"` for the window, the context entry and
  the footer tip.

## Smallest in-game test

Full restart; banners `Definitions loaded - version 0.4.42` and
`[WTAGarou Java] 0.4.42 loaded`. Hispo: grab a corpse from the ground → it
trails in front at the head, tail still while lifting; take one from a trunk →
still correct. Crinos: Q twice within 5 s → second roar is heard but does not
stagger (console line). Lupus: bite a zombie from slightly further than before.
Right-click world → "Garou Startup...".
