# 0.4.23 - Wolf attachments and the harness

Zomboid shows what you wear and carry; this version starts doing the same on
the wolf forms. Hotbar items (Back, Belt Left/Right, holsters ...) and the
secondary-hand item are drawn on the wolf, pinned to the spine; a harness
stand-in appears while any of them is attached OR a container is worn (the
saddlebags hang from the harness rather than a lone strap) and disappears
only when there is neither. Take everything off and you get the bare wolf.

## What to tune (Definitions, no Java rebuild)

All of these live in `42/media/lua/shared/WTAGarouDefinitions.lua`. Edit,
then Garou testing panel -> "Reload defs" (or `/garou reload`) and shift out
of and back into a wolf form (or Wolf OFF / Wolf ON).

| Table | Purpose | Units |
|---|---|---|
| `WTAGarou.WolfSlots["Back"]` etc. | where each hotbar item sits | `offset` metres in CHARACTER space (X sideways, **Y up**, Z along the body); `rotate` degrees about the item's own axes |
| `WTAGarou.WolfSlots["secondary"]` | the secondary-hand item | same |
| `WTAGarou.WolfSlots.BONE` / `rule.bone` | wolf bone the item rides (default `Bip01_Spine2`; `Spine1` is the next joint back, `Spine3` forward) | bone name |
| `WTAGarou.WolfSlots.ENABLED` | master switch | boolean |
| `WTAGarou.Harness` | harness stand-in `rotate`/`offset`/`scale` | mesh space like `WTAGarou.Saddlebag` |
| `WTAGarou.Saddlebag.scale` | new: uniform size on top of the model script | 1.0 = as is |
| `WTAGarou.EnableHarnessVisual` | show/hide the harness stand-in | boolean |

Slot offsets are pre-multiplied (JOML `translateLocal`) so "raise the axe"
is always `offset[2]` no matter how the axe mesh is authored; the signs of
X and Z are not verified - test one axis at a time with a large value
(0.3) and read the result. The offsets scale with the body (a Hispo's axe
sits proportionally where a Lupus's does).

## Finding the real attachment names

The engine keys a hotbar item's sub-model by the LOCATION's attachment name
(`AttachedLocation.getAttachmentName()`), which is not necessarily the id
shown in the hotbar. The client resolves each `WolfSlots` key through
`player:getAttachedItems():getGroup():getLocation(id)` and pushes the rule
under both names, so `"Back"` works whether the engine calls it `Back`,
`back` or something else. If an item still does not show, the console
prints once per name:

```
[WTAGarou Java][Slot] hidden on the wolf (no WTAGarou.WolfSlots rule): attachment="..." self=... model=...
```

Copy that attachment name in as a new key. The testing panel's Status
button lists them as `hiddenAttachments=[...]` and the active rules.

## How it works

Java (`WolfRuntime.hideSubmodel`): a wolf body's sub-models are hidden by
default. Before hiding, the sub-model's `attachmentNameParent` (or
"secondary" for `character.secondaryHandModel`) is looked up in the rules.
On a hit the instance is re-parented to the rule's bone, its parent
attachment renamed `GarouSlot_<key>` so the engine falls through to the
bone instead of the human body attachment (the same trick as the jaw), and
its scale compensated like the saddlebag. Children of a visible item
(weapon parts, scopes) are left alone and follow their parent. Everything is
undone by `restoreScale`/`restoreAll`, so the original attachment name and
bone return when the wolf is off.

`MouthCarryPatch` (the `transformToParent` exit hook) then applies the
rule's offset and rotation, or the harness/saddlebag transform and scale.

Lua (`client/WTAGarouVisual.lua`): `pushWolfSlots` sends the rules before
every wolf request; `applyHarness` mirrors `applySaddlebag` (same memo,
re-entry guard and OnClothingUpdated convergence): shown when a hotbar or
secondary item is attached OR a container is worn; it also listens to
OnEquipSecondary/OnEquipPrimary. A two-handed item (same item in both hands)
does not count as secondary gear.

## Files

- `java/src/wtagarou/visuals/WolfRuntime.java` - `SlotRule`, slot/harness registries, hideSubmodel branch, `slotStatus()`
- `java/src/wtagarou/visuals/MouthCarryPatch.java` - slot/harness post-transform, scale
- `java/src/wtagarou/visuals/WTAGarouJava.java` - `setWolfSlot`, `clearWolfSlots`, `setWolfSlotsEnabled`, `setHarnessTransform`, `setSaddlebagScale`
- `42/media/lua/client/WTAGarouVisual.lua` - `pushWolfSlots`, `wolfSlotRules`, `slotAttachmentName`, `hasHotbarItem`, `applyHarness`
- `42/media/lua/client/WTAGarouWolfVoice.lua` - equip events refresh the stand-ins
- `42/media/lua/shared/WTAGarouAttachedLocations.lua` - `WTAGarou_Harness` location registered at load
- `42/media/scripts/wtagarou_items.txt` (`WolfHarnessVisual`), `wtagarou_models.txt` (`WTAGarou_Harness`)
- `common/media/models_X/WTAGarou/WTAGarou_Harness.glb`, `common/media/textures/WTAGarou/WTAGarou_Harness.png` - placeholder from `tools/build_harness.py` (two chest straps, spine and belly bands, sized from the wolf mesh bounds: 0.34 m wide, 1.53 m long); replace the files to re-skin

## Verified / unverified

Verified by tests only: Java retarget/rename/compensation/restore, offset
via `translateLocal` then item-space rotation, weapon-part passthrough,
secondary rule, disable switch, harness transform + scale, saddlebag scale;
Lua harness apply/remove/converge, rule resolution and push. Unverified in
game: the vanilla attachment names, the sign of the X/Z offset axes, whether
the placeholder GLB loads and how it sits on the wolf, the `rotate = 90 0 0`
guess in the harness model script, and whether hotbar items look right at
the default offsets. Crinos model is still open.
