# 0.4.12 - Fixes from the 0.4.11 playtest

Everything below was verified only by the offline suites listed at the end.
Nothing in this document claims an in-game result; the "In game, expect"
lines are what the next playtest should look for.

## Sheet bag / hat errors: saddlebag attach recursion (fixed)

`IsoGameCharacter.setAttachedItem` fires `OnClothingUpdated`
(B42.20.2 `IsoGameCharacter.java` ~L3926). 0.4.11's
`WTAGarouWolfVoice.onClothingUpdated` -> `Visual.refreshSaddlebag` cleared
its memo and called `applySaddlebag` -> `setAttachedItem` -> the same event
-> ... until Kahlua overflowed its stack. That is the error the console
showed every time a container or hat was put on while a wolf was active.

`client/WTAGarouVisual.lua`: a weak-keyed `saddlebagBusy` guard ignores
re-entry, `hasSaddlebag()` compares the desired attachment with the actual
`getAttachedItems():getItem("WTAGarou_Saddlebags")`, so nothing is attached
twice, and `Visual.clear` always detaches. `Visual.applySaddlebag` is
exported. Test: `tests/stealth_voice_test.lua` drives `setAttachedItem` back
into `onClothingUpdated` and asserts exactly one attach / one detach.

## No saddlebag on the wolf: hidden with the human gear (fixed in Java)

`WolfRuntime.hideSubmodel` skipped `DrawChar` for every sub-model whose
`model != wolf`, which is how hair and clothing vanish on the wolf, but the
saddlebag is a static sub-model attached by `ModelManager.addStatic` with
`attachmentNameParent = "WTAGarou_Saddlebags"`, so it was hidden too.
Sub-models whose `attachmentNameParent` starts with `WTAGarou_` are now
drawn. Test: `WolfCombatTest` ("saddlebag attached at a WTAGarou_ attachment
is drawn on the wolf" / "gear on a human attachment stays hidden").

In game, expect: a saddlebag model on the wolf's spine while a worn container
(backpack, sheet sling, satchel...) is equipped in Lupus/Hispo. The model is
the experimental `WTAGarou_Saddlebags` static; its fit is unverified.

## Wounds vanishing instantly (fixed)

0.4.11 `Regenerate` cleared every wound flag on every update once the form
had been held `CLEAR_WOUNDS_AFTER` seconds (Crinos 60 s). After a minute in
Crinos every new bite or scratch disappeared the tick it landed and the
health bar barely moved; that is what the playtest saw.

`server/WTAGarouServer.lua` now stamps each body part's wound when first
seen (`regenClock[id].wounds[bodyPartType]`) and clears it only once THAT
wound is `CLEAR_WOUNDS_AFTER` seconds old. Existing wounds are stamped on
the priming call (form entry). `WTAGarou.HasWound(bp)` is the shared
detector (bleeding, scratched, cut, deep wound, bitten, wound infection,
zombie-infected part, burn, fracture). Log:
`[WTAGarou][Regen] Crinos closed N wound(s) older than 60s`.
Health regeneration (2 HP/s per part in Crinos) and the rate-based zombie
infection cure are unchanged. Tests: `tests/rage_engine_test.lua` (fresh bite
survives, closes 60 s after first seen; a fracture elsewhere keeps its own
clock).

Not changed: death while being eaten. Zombies feeding on a knocked-down
player kill through the engine's own path regardless of body-part health;
Crinos stability (0.97) is the intended defence, not regeneration.

## Rage not moving in single player (rescheduled)

The engine's tick lived only in `Events.OnTick` over `getOnlinePlayers()`.
The playtest showed no Homid rise, no Crinos drain and no countdown at
100 Rage, while the `OnPlayerUpdate` regeneration in the same file kept
logging. `IsoPlayer.update` raises `OnPlayerUpdate` only for local
(non-remote) players (`assert !GameServer.server` on that branch), so:

- single player / hosted: `rageUpdate(player)` runs from `OnPlayerUpdate`;
- dedicated server: the `OnTick` sweep over `getOnlinePlayers()` remains;
- both are throttled to `RAGE_TICK_SECONDS` (0.5 s) per player and share
  `rageTick`, `refundEndurance`, `RageSync` and `applyFormBuffs`.

One-time log `[WTAGarou][Rage] engine alive: form=... rage=... regen/s=...`
proves the path runs; `[WTAGarou][Rage] full Rage in <form>; Crinos
countdown 10s started` marks the countdown. `WTAGarou.RageTick` and the new
`WTAGarou.RageUpdate` are exported for tests. Tests:
`tests/rage_engine_test.lua` (update-path drain, throttle, Homid rise,
countdown; server path ignores `OnPlayerUpdate` and drains from `OnTick`).

Design reminder: Homid Rage RISES (+0.30/s) by design; only Glabro/Hispo/
Lupus/Crinos drain (Crinos -1.0/s).

## Wolf rotation, wobble and independent head (Java, hypothesis)

`IsoGameCharacter.onAnimPlayerCreated` (B42.20.2 L1760) installs human
twist bones (`Bip01_Pelvis..Bip01_Head`, rotated toward the target
direction) and a `Bip01` counter-rotation bone (forces the root to the human
rest yaw, a quarter turn off the wolf's). Those match the three symptoms:
head moving on its own, the body swinging round the origin while turning,
and the 90-degree twist with a slow wobble during attacks. `WolfRigPatch`
already cleared them on creation, but no log ever proved it ran.

- `WolfRuntime.enforceRig` re-checks `twistBones`,
  `reparentedBoneBindings` and `counterRotationBone` on every wolf track
  start and strips them if present (three field reads when clean). Logs
  once: `[WTAGarou Java] wolf rig enforced from the track hook (...)`;
  `configureRig` logs once when the creation hook does run. `status()`
  reports `rig hook=` and `rig enforcements from track=`.
- Sub-layer masks (`AnimLayer` sub-layers pass
  `params.subLayerBoneWeights = node.subStateBoneWeights`; an empty list
  means the track moves nothing): a masked sub-layer that maps to a GAIT or
  idle clip (`Wolf_idle`, `Wolf_walk`, `Wolf_run*`) is made inert (a head or
  upper-body layer replaying the walk at its own phase is the other
  "independent head" candidate); a masked sub-layer that maps to an ACTION
  (attack, hit reaction, eat, sit, death) takes the whole body with one
  `AnimBoneWeight("Bip01", 1.0)` (descendants included; the unskinned
  `Translation_Data` marker is not a descendant, so the base layer keeps the
  travel). Root layers (null/empty mask) pass through. Contract change from
  0.4.9's "retain masks where bones exist"; `WolfPlayerClips.weights` is
  kept for reference and tests.

Tests: `WolfCombatTest` (re-dirtied rig stripped once, clean rig costs no
enforcement, gait/action/root mask policy, `AnimBoneWeight` shape) and
`WolfPlayerClipsTest`. In game, expect: no 90-degree flip on attack, no
swing around the origin while turning, head following the body. If any
symptom remains, the console `rig enforced`/`rig configured` lines and
`[Perf]` lines below are the evidence to send.

## 6-8 fps in Lupus (not identified; instrumented)

Reviewed and ruled out from the code: derived clips are cached
(`WolfPlayerClips.CACHE`), `play()` runs only on node start, clothing events
are not per-frame, `ModelManager.Reset` is not per-frame, Lua hooks are
light. The cause is still unknown. While any wolf is registered the Java
side now prints, every ~5 s:

```
[WTAGarou Java][Perf] 5.0s: wolf draws=N (x/s) hidden submodel draws=N (x/s)
  track starts=N (x/s) live tracks max=N derived clips built=N
  seating lookups=N spot checks=N rig enforcements=N
```

`derived clips built` should be 0 after the first seconds; `track starts`
should be a handful per second; `live tracks max` should be small
(single digits). Anything else points at the culprit.

## Rage cost tooltip

`client/WTAGarouHUD.lua` `formTooltip`: the Rage line uses `<SIZE:medium>`
instead of the `<H1>` header face (colours unchanged).

## Strip button (new)

`client/WTAGarouStrip.lua`: `WTAGarou.RequestStrip()` /
`WTAGarou.Strip.queue(player)` queue one vanilla `ISUnequipAction:new(player,
item, 50)` for every item `WTAGarou.Clothing.stripCandidates(player)`
returns (worn, not held, not shift-safe; outermost first). Nothing is
damaged or dropped; each piece is channelled in turn exactly like the
inventory's "Unequip". Blocked while channelling a shift or dead. The Garou
panel has a `Strip` button left of `Howl`; the radial offers `Strip / N
item(s)` only while something applies. Tests: `tests/stealth_voice_test.lua`.

## Mod icon

`42/mod.info` now has `icon=icon.png`. The PNG is author-supplied and not in
the repo (same as `poster.png`); drop it in `WTAGarou/42/` next to
`mod.info`.

## Follow-ups (not started)

- Wolf pelt picker: enumerate `common/media/textures/Body/WTAGarou_Wolf*.png`
  at load and offer them at character creation / first shift.
- ZombieBuddy signing helper (`java/sign.sh`), key kept out of the repo.

## Verification

Offline only, in this sandbox:

- `bash WTAGarou/java/build.sh` and `bash WTAGarou/java/test.sh`: 222 /
  182 / 23 / 198 / 12 / 29 assertions.
- `bash WTAGarou/tests/run.sh`: 28 / 567 / 28 / 25 / 123 / 35 / 77 / 92
  Lua assertions and 151 asset/package assertions.

Unverified in game: saddlebag render and fit, rotation/head/wobble fixes,
fps, the Rage engine actually ticking, countdown growl, per-wound
regeneration feel, Strip button behaviour with real `ISUnequipAction`
walking rules, the `<SIZE:medium>` tooltip size.
