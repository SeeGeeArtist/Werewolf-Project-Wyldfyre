# WTAGarou v0.3.0 — what changed and how to test it

Every symptom you reported traced back to a real bug, not a tuning problem.
Here they are with the actual cause.

| What you saw | Why | Fixed |
|---|---|---|
| Hispo missing from the panel | `FormOrder` only listed four forms | yes |
| Transformation was instant | The server applied the form the moment it got the request; the client timed action was decoration | yes |
| Only carry capacity changed | `player:setScale()` **does not exist** in Build 42, so the size code silently did nothing | yes — via model swap |
| Panel had no close button | It was a bare `ISPanel` | yes — now a real window, plus a key |
| Howl was instant | There was no timed action for it at all | yes |
| `Q` radial never opened | It called `menu:display()` and `ISRadialMenu.getInstance()`, neither of which exist | yes |
| Controller radial dead | It wrapped `ISUseEmotesMenu`, which does not exist in B42 | yes |

## Install

Replace your existing folder:

```
/home/deck/Zomboid/mods/WTAGarou/
```

Everything is text except the PNGs and the wolf assets. Then fully quit and
relaunch the game — Zomboid caches script definitions on load.

## Your three requests

**Debug rage command.** In-game chat (`T`), or the Lua console:

```
/garou rage 100        set Rage to 100
/garou rage +25        add 25
/garou rage -40        subtract 40
/garou form Crinos     become Crinos instantly, free, ignoring cooldown
/garou shift Crinos    same but runs the real channelled transform
/garou trait           grant yourself the Garou trait on an existing save
/garou untrait         remove it
/garou infamy 50       set Infamy
/garou info            dump form, Rage, Infamy, trait state, model script
/garou help            list all of it
```

In multiplayer these are admin-gated. In single-player they always work.

**Form order.** The panel and both radials now read
`WTAGarou.FormOrder = { "Homid", "Glabro", "Crinos", "Hispo", "Lupus" }`.
Change that one table in `WTAGarouDefinitions.lua` and every UI follows.

**Free Homid and Lupus.** Both are `rageCost = 0`. Glabro 10, Crinos 25,
Hispo 15.

## Test in this order

Each step isolates one system. If a step fails, stop there — later steps
depend on it.

### 1. The trait exists

Start a new character. Look for **Garou** in the trait list at creation, 12
points, with a small gold wolf head icon.

If it is missing, `media/registries.lua` did not load. Check the exact
filename and case — Linux will not find `Registries.lua`. Then check the
console for a `CharacterTrait.register` error.

You can skip this for now with `/garou trait` on any character.

### 2. Transformation is actually channelled

Take the trait, spawn in, press **G** to open the panel. Click **Crinos**.

You should see a progress bar for about 3 seconds, and **walking should
cancel it** with no Rage spent. Let one complete and Rage should drop by 25.

This is the fix that matters most. The protocol is now
request → server reserves → client channels → confirm → server applies.
The old code applied the form on the request, which is why it felt instant.

### 3. The panel closes

**G** toggles it. There is also a close button in the title bar now, and you
can collapse and drag it.

Rebind under Options → Key Bindings → **[WTAGarou]**.

### 4. The radial opens

Press **Q**. Five form slices plus Howl. On controller, the emote radial has a
**Garou** slice that swaps the wheel out and gives you a Back slice.

### 5. Howl is cancellable

Howl from the panel or the radial. 4 seconds, cancels on movement.

### 6. Size — the experiment

**Shift to Glabro first, not Crinos.** Glabro is the same human mesh at
`scale = 1.15`, so it is the cheapest possible test of whether model scaling
works on skinned characters at all.

- Visibly bigger → scaling works, so Crinos and Hispo will too
- Identical → top-level `scale` is ignored on skinned meshes, and the fallback
  is pre-scaled mesh exports from Blender

I want to be straight about this: a top-level `scale =` is confirmed in vanilla
only on **static** models. In `models_characters.txt` it appears only inside
`attachment` blocks. It is a reasonable bet, not a verified fact.

`/garou info` prints which model script is currently forced, so you can tell
"the swap didn't happen" apart from "the swap happened but scale was ignored".

Also worth saying plainly: even when this works, it changes the **model only**.
Your tile footprint and grab range stay human. Build 42 does not expose player
collision size to Lua at all.

### 7. Lupus and Hispo look like wolves

Expect a T-posing or frozen wolf on the first try. That is the expected failure,
not a mistake — the player's AnimSet asks for human clip names like `Bob_Walk`
and the wolf folder does not have them.

`docs/ANIMATION_MAPPING.md` explains both routes out. The quick one:

```
cd ~/Zomboid/mods/WTAGarou
python3 tools/map_wolf_anims.py --dry-run
python3 tools/map_wolf_anims.py
```

Then delete the `animationPrefix = Wolf_` line from the
`animationsMesh WTAGarou_Wolf` block in `42/media/scripts/wtagarou_models.txt`.

That gets you idle/walk/run/attack/death. Everything else does nothing, which
for a wolf is mostly fine.

### 8. Hands go away as a quadruped

Shift to Lupus with a weapon equipped. Both hands should clear. Try to equip a
crowbar — refused, "You have no hands."

Then try equipping something light (under 3.0 for Lupus, 6.0 for Hispo) and it
goes to the **jaws** instead. Firearms are always refused; a wolf cannot work a
trigger. This is the Sif hook — `WTAGarou.Slots.getMouthItem(player)` returns
whatever is in there.

Containers are deliberately left alone, so a wolf keeps its backpack.

### 9. Saddlebags

`/garou rage 100`, then spawn one with the debug menu or craft **Wolf Panniers**
(2 leather strips, thread, needle). They are wearable containers on their own
body location, so they do not fight with a human backpack.

They are **invisible on the model** — that is intentional. A worn bag needs a
mesh rigged to the wearer's skeleton, and there is no wolf-rigged bag. WolfMod
ships its own saddlebag the same way.

## If nothing loads at all

Check the console log first:

```
/home/deck/Zomboid/console.txt
```

A Lua syntax error names the file and line. All 22 Lua files in this build were
verified to parse cleanly with `luac -p`, so a syntax error would mean a
transfer problem rather than a code problem.

If the mod loads but the trait is absent and every transform is denied with
"You are not Garou", that is the trait gate working correctly on a character
that does not have the trait. `/garou trait` fixes it, or flip
`WTAGarou.IGNORE_TRAIT_GATE = true` in `WTAGarouDefinitions.lua` to disable
gating entirely while you test other things.

## Known unknowns

Being explicit about what has not been proven in game:

1. Top-level `scale` on a skinned character model — the whole size plan
   rides on it
2. The trait icon path convention (`media/ui/Traits/trait_garou.png`, 18×18,
   resolved by id with the namespace stripped) came from a single secondary
   source
3. The `bone = head` mouth attachment is a guess; the real name has to come
   from opening the wolf `.glb` in Blender
4. Driving a wolf mesh from the human AnimSet is unsolved and may need a
   Blender re-rig

Everything else — the timed actions, the radial menus, the collapsable window,
the keybind registration, the trait registration pattern, the anim variables —
was checked against the Build 42.16 source and the Java API stubs.
