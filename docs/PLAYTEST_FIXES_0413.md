# 0.4.13 / 0.4.14 - answers to the 0.4.12 playtest

Source: the full 0.4.12 console (1691 lines, from startup) and the playtest
notes. Every item below says what the console showed, what changed, and what
is still unverified in game. Nothing here was verified visually by tooling.

## What the console showed

- `[WTAGarou Java] 0.4.12 loaded`, `Definitions loaded - version 0.4.12`,
  mod name "Werewolf: The Zomboid Apocalypse".
- Load error: `java.io.IOException: unsupported interlace method` for
  `WTAGarou\42\icon.png`. The icon is an interlaced (Adam7) PNG; the engine's
  PNG reader does not support interlacing. Re-save it with interlacing off
  (Photoshop: PNG options -> Interlace: None; GIMP: untick "Interlacing
  (Adam7)"). Tooling does not touch this file.
- Repeated stack, on load and on every clothing change:
  `RuntimeException: no such location "WTAGarou_Saddlebags"` from
  `AttachedItems.getItem` <- `hasSaddlebag` <- `refreshSaddlebag` <-
  `WTAGarouWolfVoice.onClothingUpdated`. The location was registered lazily
  inside the attach path, after the first query.
- Rage: `engine alive: form=Homid rage=50.0 regen/s=0.3` at frame 1;
  `full Rage in Homid; Crinos countdown 10s started` while eating;
  `Crinos depleted; forced Homid`; per-wound regen lines for Glabro and
  Hispo (`closed 1 wound(s) older than 180s`). The engine is working.
- `[Perf]`: wolf draws 60/s (one per frame), hidden sub-model draws
  240-430/s, track starts 0-45/s, derived clips built 0 after warm-up,
  rig enforcements 0 on every line (the creation hook configured the rig:
  `wolf rig configured from onAnimPlayerCreated`).
- `sound stop ignored: no active entry owner=-1 reason=character_death`
  repeated many times after the death: noise only.

## Fixes

### Saddlebag: registration and placement

- `shared/WTAGarouAttachedLocations.lua` registers `WTAGarou_Saddlebags` in
  the `Human` attached-location group at load (both sides), and
  `hasSaddlebag` refuses to query an unregistered location. The stack is
  gone by construction; covered by `tests/stealth_voice_test.lua`, whose
  `getAttachedItems():getItem` mock now throws for unregistered locations
  exactly like `AttachedLocationGroup.checkValid`.
- Why the bag drew as a black slab under the wolf: the engine resolves a
  sub-model's transform in `AnimatedModelInstanceRenderData.transformToParent`
  by looking the parent attachment up on the BODY instance's model script.
  Under the direct Java wolf that script is still `MaleBody`/`FemaleBody`
  (`HumanVisual.getModelScript`), which has no `WTAGarou_Saddlebags`
  attachment, and the instance had no `parentBoneName` either, so the bag
  got the body transform only: character origin, on the floor. The
  attachments on `model WTAGarou_Lupus/Hispo` are never consulted.
- Fix: `WolfRuntime.hideSubmodel` sets `parentBoneName = Bip01_Spine2` on
  any sub-model attached at a `WTAGarou_` attachment (the engine then applies
  that bone's transform), and the offset/rotation moved to the SELF
  attachment on `model WTAGarou_Saddlebags` (same id), which the engine
  applies after the bone. Spine2 is the mid-back bone of the bundled wolf
  GLB (`Bip01_Spine -> Spine1 -> Spine2 -> Spine3 -> Neck`). Covered by
  `java/test/WolfCombatTest.java` (draw + re-parent, human gear untouched).
- Unverified in game: the offset `0.0 0.08 -0.05`, rotation `90 0 180` and
  whether the bag texture resolves (black could also be a missing texture,
  though `common/media/textures/WTAGarou/WTAGarou_Saddlebags.png` exists).
  The perf line now prints `saddlebag retargets=N` (1 per model rebuild).

### Mouth carry (experimental)

- The primary-hand model, previously hidden with the rest of the human gear
  on a wolf, is drawn with `parentBoneName = Bip01_Jaw` when
  `WTAGarou.EnableMouthCarry` is true (default). The item's own hand
  attachment (`Bip01_Prop1`) is no longer found, so the mesh sits at the jaw
  bone origin in jaw-bone axes; orientation is unverified and may need a
  per-item offset later. Secondary-hand gear stays hidden. Perf line:
  `mouth-carry retargets=N`. Set `WTAGarou.EnableMouthCarry = false` to
  return to hidden.

### Java `TraitsRuntime` (new)

Registered from the client visual refresh (`Visual.applyTraits`) per form
from `WTAGarou.Traits`; all four funnels are in the pinned B42.20.2 source.

| Funnel | Patch | Effect |
| --- | --- | --- |
| `IsoPlayer.updateFootInjuries()` | `FootInjuryPatch` (skip) | Glabro/Crinos/Hispo/Lupus never scratch or cut their feet barefoot. Homid unchanged. |
| `IsoPlayer.updateMovementRates()` | `MovementRatePatch` (exit) | `WalkSpeed` x walk/run/sprint/sneak multiplier for the current gait; `RunSpeed` x run/sprint. |
| `IsoGameCharacter.getTurnDelta()` | `TurnDeltaPatch` (exit) | Return value x form turn multiplier (IsoPlayer's override calls super). |
| `BodyDamage.JustAteFood(Food[, float])` | `RawMeatPatch` (enter/exit) | For a Garou eating uncooked `DangerousUncooked` food the `POISON` stat is restored to its pre-meal value. Rotten food, real poison, cooked food unchanged. |

Multipliers (first guesses, tune from the playtest):

| Form | walk | run | sprint | sneak | turn | paws |
| --- | --- | --- | --- | --- | --- | --- |
| Homid | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | no |
| Glabro | 1.10 | 1.10 | 1.10 | 1.10 | 1.00 | yes |
| Crinos | 1.20 | 1.20 | 1.15 | 1.20 | 1.00 | yes |
| Hispo | 1.30 | 1.25 | 1.15 | 2.00 | 1.30 | yes |
| Lupus | 1.40 | 1.35 | 1.25 | 2.40 | 1.60 | yes |

Notes:
- `IsoGameCharacter.setSpeedMod` (used by `applyFormBuffs` since 0.3.x) is
  read only by zombie code in B42.20.2. It never moved a player; the
  `fd.moveSpeed` values had no effect. The call stays for compatibility,
  the comment now says so.
- Going shoeless costs 15% speed in `updateSpeedModifiers`; the multipliers
  above are applied on top of that, so a wolf's effective gain is smaller
  than the table suggests. The variables are capped at 1.0 by vanilla
  BEFORE our multiplier, so values above 1 do speed the character up.
- Speed variables also scale clip playback, so the wolf gaits will animate
  faster. Unverified: whether the sneak clip at x2.4 looks acceptable.
- Turn: the wolf gets no animation-driven rotation (0.4.8), which is why it
  felt slower than a human at the same native rate. 1.6/1.3 are guesses.
- Multiplayer: these funnels run where `updateMovementRates`/`JustAteFood`
  run. On a dedicated server the server-side loop is untouched unless the
  jar is loaded there too. Single player is the target of this playtest.
- Covered by `java/test/TraitsTest.java` (38 checks with real ZombieBuddy
  advice on engine-shaped fixtures) and `tests/stealth_voice_test.lua`
  (per-form requests, no re-send on unchanged form).

### Smaller fixes

- Crinos requires 55 Rage (was 60). Definitions, tests, HUD tooltip
  (derived), docs.
- Garou panel hides when the player is dead (`prerender` and
  `OnPlayerDeath`); `OnGameStart` reopens it for the next character.
- Pain bark rate-limited to one per `WolfSounds.PAIN_COOLDOWN` (0.8 s). A
  grab/bite raises `OnPlayerGetDamage` every frame; 0.4.12 stacked dozens
  of barks and the emitter culled them into silence.

## Explained, not changed

- Rage reaching 100 in Homid while eating: in 0.4.13 Homid regenerated
  +0.30/s by design (50 -> 100 in under three minutes) and every negative
  moodle added on top. **Changed in 0.4.14** at the author's request: Rage is
  situational. Homid, Glabro, Hispo and Lupus have no passive rate; Crinos
  alone ticks (-1/s). Moodles, damage and howling are the only other movers.
- The persistent Sad moodle: nothing in WTAGarou touches unhappiness or
  boredom (grep: only the panic trace reads stress). Unhappiness in B42
  comes from food (`UnhappyChange` on the item, raw/bland food and the
  Unhappy modifier when eating without utensils), boredom indoors, wetness
  and reading nothing. It drains Rage via `SAD_MOODLES` as designed.
- "No shifting sound": none is defined yet. Name the asset(s) and when
  they should play (start of channel / completion / per form).

## Still open from this playtest

- Hispo eating: head scaling and the odd action pose. Rig enforcements
  stayed at 0, so this is not twist/counter-rotation; suspect the derived
  `Wolf_eat` clip or the human eat clip's bone scale on a sub-layer.
- Window climb rubber-band in Hispo/Lupus (deferred movement of the climb
  clip vs. the derived player-motion clip).
- Momentary rotation around the origin when jogging and turning hard with
  Ctrl in Lupus/Hispo.
- Saddlebag offsets, mouth-carry orientation, speed/turn values: tune from
  the 0.4.13 console and footage.

## Test counts at this version

Java: 222 / 186 / 23 / 198 / 12 / 29 / 38 (ScaleTest, WolfCombatTest,
WolfClipLoaderTest, WolfPlayerClipsTest, StabilityTest, StealthTest,
TraitsTest). Lua: 28 / 571 / 28 / 25 / 123 / 35 / 77 / 108; asset contract
151. All passing locally. None of them verifies a rendered frame.

## 0.4.14 (same playtest, follow-up)

- `Rage.REGEN_PER_SECOND` = Homid 0, Glabro 0, Hispo 0, Lupus 0, Crinos -1.
  Previously +0.30 / -0.30 / -0.60 / +0.15 / -1.00. Consequences: a calm
  Homid no longer drifts to a forced Crinos; Glabro and Hispo can be held
  as long as you like; Lupus no longer creeps up. Rage still rises with
  negative moodles (Panic x2, Angry x1.5, others 0.5-1.0 at 0.08/level/s),
  +0.75 per hit taken, +0.20 per hit dealt; falls with Unhappy/Bored; Well
  Fed and howling pull toward 60.
- The Java jar is unchanged from 0.4.13 (its banner still says 0.4.13);
  Lua Definitions print 0.4.14.
- `tests/rage_engine_test.lua`: 86 assertions (30 s hold per non-Crinos
  form, update-path calm Homid, panic from the update path).
