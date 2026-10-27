# Putting a wolf body on a player character (Build 42)

> **Superseded by [the 0.4.4 direct-body prototype](WOLF_COMBAT_044.md).**
> Do not follow the old setup instructions below. Asset inspection disproved
> the claim that this wolf lacks Bip01 bones: Bip01_Jaw, Bip01_Head and others
> are present. The nearby B42.20.2 body-selection source also ignores
> HumanVisual's forced model for non-animal players. The old Lua-only recipe
> therefore does not implement the required player body replacement.
> The current Java adapter selects the actual body and translates wolf clips.
> Its runtime appearance remains unverified, not a solved animation system.

> Historical design notes, superseded for scaling by 0.4.1.
> Player scaling was already reported not to work through the earlier Lua/
> model-script approach. Do not repeat that approach as a new solution.
> Current scaling uses our own ZombieBuddy `Model.DrawChar` hook; see
> [JAVA_VISUALS.md](JAVA_VISUALS.md). The animation suggestions below remain
> unverified, not a working implementation or proof of engine behavior.

This is the honest, unglamorous part of the mod. Everything else in v0.3.0 is
verified against the vanilla B42 source. This is not — it needs iteration in
game, and it may need a Blender step.

## What the engine actually gives you

Lua in Build 42 **cannot**:

- rescale a live character — `IsoPlayer:setScale()` does not exist, which is
  exactly why the old `if player.setScale then` branch silently did nothing
- touch `Model` or `ModelInstance` — both are unexposed to Lua
- change the player's collision radius — `collisionSize` is a field on **animal
  definitions** only

Lua in Build 42 **can**:

```lua
local visual = player:getHumanVisual()
visual:setForceModelScript("WTAGarou_Lupus")   -- swap the whole body model
visual:setSkinTextureName("WTAGarou_Wolf")     -- swap the body texture
player:resetModelNextFrame()                   -- rebuild it
```

So size lives in the **model script**, not in Lua. `media/scripts/wtagarou_models.txt`
defines one pre-scaled model per form and `WTAGarouVisual.lua` just picks one.

### The limitation you should know about up front

This changes the **visual model only**. A Crinos will look enormous and still
occupy a human-sized tile footprint, and zombies will grab it from human range.
There is no Lua-side fix for that in B42. `WTAGarou_ReachBonus` in mod data is a
fake-out for melee range; it does not widen your hitbox.

### The other unverified bit

A top-level `scale =` is confirmed working on **static** models (vanilla
`models_clothes.txt` uses `scale = 0.33`). In vanilla `models_characters.txt`,
`scale` appears **only inside `attachment` blocks**. So a top-level `scale` on a
skinned character model is plausible but unproven.

**Test Glabro first.** It is the same human mesh at `scale = 1.15`. If Glabro
looks bigger, scaling works and Crinos/Hispo will too. If it doesn't, the
fallback is exporting pre-scaled copies of the mesh from Blender and pointing
each form's model script at its own `.glb`.

## Why the wolf will probably T-pose at first

Vanilla defines the human rig like this:

```
animationsMesh Human
{
    meshFile = Skinned/MaleBody,
    animationDirectory = Bob,
    animationDirectory = Kate,
    animationDirectory = Zombie,
}
```

No `animationPrefix`, which means the player's AnimSet asks for **fully
qualified** clip names such as `Bob_Walk`.

Compare a vanilla animal:

```
animationsMesh Deer_Doe
{
    meshFile = Skinned/DeerDoe,
    animationDirectory = Deer,
    animationPrefix = Deer_,
}
```

`animationPrefix` is **prepended** to whatever the AnimSet requests. The deer
AnimSet asks for `Idle`, the engine looks up `Deer_Idle`.

The player is not on the deer AnimSet. It is on the human one, and it will ask
for `Bob_Walk`, `Bob_Run`, and roughly a hundred other human clip names that do
not exist in `anims_X/WTAGarouWolf/`. Missing clips fail silently, which reads
in game as a wolf frozen in bind pose.

Two ways out.

### Option A — rename the wolf clips to human clip names (no Blender)

Cheap, fast, ugly. Copy `Wolf_walk.glb` to `Bob_Walk.glb`, `Wolf_run.glb` to
`Bob_Run.glb`, and so on, inside `anims_X/WTAGarouWolf/`, then drop the
`animationPrefix` line from the `animationsMesh WTAGarou_Wolf` block.

`tools/map_wolf_anims.py` does the copying for you and lists which human clips
have no wolf equivalent.

What you get: locomotion looks right, and everything unmapped (aiming,
climbing, the whole weapon tree) does nothing. For a wolf that mostly runs,
bites and dies, that is survivable.

Caveat: the clips are bound to the **wolf** skeleton, and the human AnimSet also
drives IK and aim targets on `Bip01_*` bones that the wolf rig does not have.
Those requests fail silently. This is why Option A is a prototype, not a
shipping answer.

### Option B — a custom AnimSet (the real fix)

Copy `media/AnimSets/raccoon/` as a starting point rather than `player/`.
`WolfPredator` uses `a.animset = "raccoon"` for exactly the reason you spotted:
the raccoon state machine handles a quadruped turning in place, which is the
thing that looks most obviously wrong when you drive a wolf with a bipedal
AnimSet.

Then keep `animationPrefix = Wolf_` and let the AnimSet ask for bare names
(`idle`, `walk`, `run`, `attack`), which is what the existing clip filenames
already are.

The catch: the player's state machine is chosen by the engine, not by the model
script, so pointing a *player* at an animal AnimSet is the part that needs
experimenting. If it turns out the player AnimSet cannot be swapped, Option B
becomes "re-rig the wolf mesh to the human skeleton in Blender", which is real
work but makes every human animation apply to the wolf automatically.

## Clip inventory

Available in `anims_X/WTAGarouWolf/` (from WolfMod):

| Clip | Obvious human counterpart |
|---|---|
| `Wolf_idle` | `Bob_Idle` |
| `Wolf_walk` | `Bob_Walk` |
| `Wolf_run` | `Bob_Run` |
| `Wolf_run_V2`, `Wolf_run_V3`, `Wolf_run_fourx` | sprint variants |
| `Wolf_attack` | melee swing |
| `Wolf_hitreaction` | hit reaction |
| `Wolf_death`, `Wolf_dead` | death / corpse |
| `Wolf_eat` | eating |
| `Wolf_Sit` | sitting on ground |
| `Wolf_OnHook` | butchering; irrelevant for a player |

There is no wolf climb, vault, aim, reload or door-opening clip, and there
never will be — a wolf should not be doing those things anyway, so the missing
clips double as a design constraint.

## The mouth attachment point

`model WTAGarou_Lupus` declares:

```
attachment mouth
{
    offset = 0.0 0.0 0.35,
    rotate = 0.0 0.0 0.0,
    scale = 0.8,
    bone = head,
}
```

`bone = head` is a **guess**. Open `models_X/Skinned/WTAGarou_Wolf.glb` in
Blender, look at the armature, and use the real bone name — the human names
(`Bip01_Head`) will not resolve on this rig. Once the name is right, tune
`offset` in small steps; the units are metres in model space.

`WTAGarou.Slots.getMouthItem(player)` returns whatever is currently in the jaws,
which is the hook for rendering at this point and for the Sif-style
weapon-in-mouth attack.

## Asset naming

Everything is prefixed `WTAGarou_` on purpose. WolfMod already defines
`model Wolf` and `animationsMesh Wolf` in `module Base`, and two mods defining
the same name in the same module conflict. The mesh, texture and animation
folder were renamed for the same reason:

| Was (collided with WolfMod) | Now |
|---|---|
| `models_X/Skinned/Wolf.glb` | `models_X/Skinned/WTAGarou_Wolf.glb` |
| `textures/Body/Wolf.png` | `textures/Body/WTAGarou_Wolf.png` |
| `anims_X/Wolf/` | `anims_X/WTAGarouWolf/` |
