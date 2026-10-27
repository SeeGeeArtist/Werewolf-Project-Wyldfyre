# Wolf animations: what exists, what is missing, and why the wolf "does things on its own"

Written for the 0.4.24 playtest follow-up, corrected in 0.4.25.
Author new clips under `common/media/anims_X/WTAGarouWolf/` with matching
embedded names. Optional mappings select them only once they are in the
loaded animation map; the explicit loader currently requests the packaged
clips only. Dropping a file into the folder is NOT a verified import or
integration workflow. Trot/gallop, attack-run and howl also need selection
wiring before normal gameplay can choose them.

## Packaged clips (present today)

| File | Used for |
|---|---|
| `Wolf_idle.glb` | standing idle, and every human node with no wolf mapping |
| `Wolf_walk.glb` | walk, and (until authored) strafe, backing up, sneak walk, turns |
| `Wolf_run.glb` | jog; tiled across `RunToStop` / `IdleToRun` transitions |
| `Wolf_run_fourx.glb` | sprint |
| `Wolf_attack.glb` | every attack / shove / stomp node |
| `Wolf_hitreaction.glb` | flinch, bite/grab reactions, knockdowns |
| `Wolf_Sit.glb` | sit down AND the held sit loop (see below) |
| `Wolf_eat.glb` | eat, drink, and the howl action (howl plays the Drink node) |
| `Wolf_death.glb` / `Wolf_dead.glb` | death hand-off (locked, working) |
| `Wolf_OnHook.glb`, `Wolf_run_V2/V3.glb` | present in the folder, not referenced by the mapping |

## Missing clips, in the order they are noticed in play

| File to author | Plays for | Falls back to today | What you see without it |
|---|---|---|---|
| `Wolf_idle_crouch.glb` | crouch / sneak idle (`Bob_SneakIdle`, `Bob_IdleCrouch`) | `Wolf_idle` (0.4.24; was `Wolf_walk`, "walks in place") | the wolf stands normally while the human would crouch |
| `Wolf_Sit_idle.glb` | held sitting pose (`...SitGround...Idle/loop` nodes) | `Wolf_Sit` | the sit-DOWN motion repeats, paws lifting at the end of each loop |
| `Wolf_getup.glb` | stand up from sit / knockdown | `Wolf_idle` | pops to standing |
| `Wolf_sneak.glb` | sneak walk / crouch walk | `Wolf_walk` | walks upright while sneaking |
| `Wolf_strafe.glb` | sideways step (`Bob_Strafe*`, Ctrl-aim movement) | `Wolf_walk` | walk cycle while the body slides sideways |
| `Wolf_walk_back.glb` | backing up | `Wolf_walk` played in reverse (0.4.64; was forward, "walk cycle while sliding backwards") | paws track the direction of travel; an authored `Wolf_walk_back` plays forward |
| `Wolf_turn.glb` | turn in place (`IdleToWalk180L/R`, `WalkToTurn180L/R`) | `Wolf_walk` | walk cycle while the body pivots |
| `Wolf_run_stop.glb` | `Bob_RunToStop` (one-shot, ~1.0 s) | `Wolf_run` tiled across the stop (0.4.24) | run cycle continues for the length of the stop |
| `Wolf_trot.glb` / `Wolf_gallop.glb` | your planned gaits | `Wolf_walk` / `Wolf_run` | - |
| `Wolf_attack_run.glb` | attack while moving | `Wolf_attack` | legs and hips freeze mid-stride, front paws slide (your "attack without strafing" note) |
| `Wolf_climb.glb` | fence / window / vault nodes | `Wolf_idle` | wolf stands still while the game moves it over the obstacle |
| `Wolf_fall.glb` | fall / collapse nodes | `Wolf_hitreaction` | short flinch instead of a fall |
| `Wolf_drink.glb` | drink nodes | `Wolf_eat` | eats instead of drinks |
| `Wolf_howl.glb` | howl (0.4.69: reachable; while `WTAGarou_Howling` is set, `WolfRuntime.beginTrack` maps the Drink/Eat clip to `Wolf_howl` when the file exists, and masks that track to `Bip01_Neck` + descendants (Head, Jaw, Ears) so the gait layer keeps the body; key only neck/head/jaw, export like `Wolf_eat.glb`: sampled LINEAR, mesh included is fine, "Reset pose bones between actions" on) | `Wolf_eat` | eats while howling (full-body action weights, unchanged) |

Not mapped at all yet (plays `Wolf_idle` with a one-line console note
`wolf clip fallback: '<node>' -> Wolf_idle`): swim, sleep/lie down, forage
sniff, ladder, vehicle enter/exit, push/pull. Send the console lines and
they get a row here.

Authoring notes that matter to the runtime:

- Cycles (walk/run/sneak/strafe/trot/gallop) must move the `Translation_Data`
  marker forward for the full clip; the stride is measured as the largest
  marker displacement from the first frame, and the movement speed of the
  character is the game's, never the clip's (`WTAGarou.WolfGait.CYCLE_SLOWDOWN`
  slows the visible cadence only).
- The timing guard currently covers transition nodes using packaged gait
  fallbacks. Authored one-shots need timing/event integration; do not assume
  they all receive the human duration. The new bite setting
  `WolfGait.ATTACK_SPEED` is separate from `CYCLE_SLOWDOWN`.
- `Wolf_Sit_idle` is a LOOP of the held pose. `Wolf_Sit` stays the sit-down
  motion.

## "Isn't the game just reading exactly what's in the wolf glb files?"

No. Three things are layered on top of the clip you authored:

1. **Track blending.** The engine's `AnimationPlayer` plays several
   `AnimationTrack`s at once and blends them per bone. Every human anim
   node (idle, walk, aim, holding an item, injured limp...) can be active
   as its own track with its own weight; the wolf only swaps the CLIP each
   track plays, not the set of tracks.
2. **Bone masks (sub-layers).** Nodes such as the hold-item, aim and
   two-handed layers carry `subLayerBoneWeights`: a mask that says "this
   track only drives the arms/upper spine". The wolf skeleton reuses the
   human bone NAMES (`Bip01_L_UpperArm`, `Bip01_Spine2` ...), so a mask
   meant for a human arm can affect a wolf foreleg. However, our adapter
   already makes gait/idle sub-layers inert and action sub-layers whole-body.
   The flashlight side-step's exact track/blend cause is NOT established.
   The previous text presented this hypothesis as a confirmed diagnosis.
3. **Root motion is separate from the clip.** The character's position is
   the game's; the `Translation_Data` marker only advises it. The derived
   wolf clips keep the wolf's rest offset unless
   `WTAGarou.WolfGait.MARKER_AT_ORIGIN` is true (you found that removing
   it cured the tilt).

So: your glb is the base layer; item-hold/aim/injury layers paint over it
with bone masks that were written for human arms; and the movement comes
from the game, not the file. Authoring the missing clips above fixes the
"wrong clip" class of artefacts (crouch, sit, strafe). The "arm layer drives
the foreleg" class needs the runtime to zero the hold/aim layer weights on
the wolf, which is a separate change (not in 0.4.24; it touches the working
mouth-carry/secondary rendering path and wants its own playtest).
