# WTAGarou 0.4.25: targeted fixes and pause-ready backlog

This patch follows the September 27, 8:33 PM playtest report and its
0.4.24 console. It does not claim in-game verification of visual fixes.
The previous release's confident explanation of harness resizing was
premature: the latest playtest still reproduces it.

## Implemented

- **Carry balance:** Glabro base carry 14, Hispo base carry 17. The vanilla
  Strength-7 multiplier is 1.92, yielding displayed 26 and 32 before
  moodle penalties and other vanilla modifiers. Strength and moodles still
  matter; these are not globally fixed capacities.
- **Shift cost:** Glabro costs 20 Rage, matching Hispo. Crinos unchanged.
- **Bite timing:** `WolfGait.ATTACK_SPEED = 1.5`, independent of
  `CYCLE_SLOWDOWN = 1.2`. Derived attack clips take two thirds of their
  authored duration. Attack clips bypass stride matching and gait
  slowdown; other clip timing paths remain unchanged. Damage, recovery
  hooks and gameplay hit-event code are unchanged.
  Raw fallback playback when human motion data is unavailable still uses
  the original clip; current fixture coverage is of the derived path.
- **Stale Berzerker text:** confirmed completion clears both countdown
  and channel display. The HUD also clears a stale countdown when the
  confirmed form is already Crinos.
- **Attachment preparation:** retargeting and script-based compensation
  now run before `AnimatedModelInstanceRenderData.transformToParent`
  builds the matrix. Previously preparation happened at `DrawChar`, after
  the engine had already baked scale and bone placement. Tests cover the
  first transform before any draw, owner lookup through the body parent,
  and the same transform after an engine reset. This addresses a verified
  ordering flaw, not every possible cause of harness/saddlebag distortion.
- **Temporary props:** on wolves, overridden timed-action hand models
  (reading/eating/crafting) are hidden rather than interpreted as equipped
  mouth/secondary cargo. Actions and inventory are untouched. Normal
  equipped items retain the mouth/harness rules when no override is active.
  This is a conservative visual mitigation, not a new wolf reading pose.
- **Chair tilt:** the log names `Bob_Seated_SitDown` with deferred bone
  `Bip01`. Copying human marker frames onto that skinned root can replace
  the wolf's root orientation. Chair-root nodes now keep the authored wolf
  pose and use the unskinned `Translation_Data` marker with deferred
  rotation off. Native seating-offset queries still use human data.
  Chair height/alignment and the sit-loop animation remain unverified.
- **Reload error:** `/garou reload` used a nonlocal `player`, which can
  resolve to the engine's unrelated global table. It now calls
  `getPlayer()`. A failed visual refresh is reported rather than swallowed
  after the definitions load.

## Pain observation

The reference engine's `BodyPart.getAdditionalPain(true)` includes
`stiffness / 3.5`. Minor muscle strain can therefore accompany the Pain
moodle without another visible wound. This log does not capture every
body part's pain components, so it does not prove strain was the only
cause. No pain suppression, silver healing or muscle-strain immunity was
added.

## Verification

Local Java build, all seven Java suites (including TraitsTest), all twelve
Lua suites, and git whitespace checks are required for this patch. The
fixtures check timing math, parameter restoration, transformation order,
temporary prop classification, reload player identity, HUD cleanup, and
balance definitions. They do not render a native frame or prove correct
appearance in game. CI outcome is attached to the pushed commit.

## Next test, whenever convenient

- Pick up/equip/unequip an item while the harness is visible; compare before
  and after without wolf-off/on. Still-changing size remains a live bug.
- Read/eat in Hispo: the temporary prop should be absent, action functional.
  Then equip a real secondary item; it should return to the harness mount.
- Sit on a chair and stand up. Check side-roll separately from seat height.
- Bite in both wolf forms; gait pace should be unchanged.
- Complete a forced Crinos shift and check the countdown disappears.
- At Strength 7 without carry penalties, verify Glabro 26, Hispo 32;
  Glabro shift cost 20. A full restart is needed for the changed Java JAR.

## Deferred, not lost

- Harness/saddlebag sizing and placement still need native rendering
  confirmation. Saddlebags were reaching the draw path in this console;
  their invisibility is not explained merely by missing draw calls.
- `belt_left_screwdriver` and `wrench_right` were hidden as unmatched
  attachment names. A broader, verified hotbar alias mapping is pending.
- Foreleg side-step with held items, standing-attack paw slide, sit-loop
  paws, and missing crouch/sneak/strafe/backward/get-up/climb clips remain.
  `Wolf_attack_run` alone is not a proven fix for a standing-attack slide.
- Optional clip import and selection need verification, not just files
  dropped in a folder. See the corrected
  [wolf animation list](WOLF_ANIMATION_LIST.md).
- Preserve current direct-IsoPlayer body loading, death handoff, literal
  `nil, nil` shifting, and the author's attachment tuning. No model mesh,
  author sound, reference mod, Crinos model or future Infamy/Umbral feature
  was changed.
