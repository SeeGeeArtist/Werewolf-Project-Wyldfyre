# Wolf asset diagnostics: 0.4.6

This is a diagnostic update, **not a confirmed fix for wolf rendering**.
The September 21 playtest confirmed a readable testing panel and enjoyable
fast attacks, but reported no wolf appearance.

## What the playtest established

The uploaded log from Build 42.20.4 reports Java 0.4.4 and Lua 0.4.5 loaded.
It shows `Direct wolf request=true result=pending` for both natural-size and
1.25-scale quadruped requests. Status reports the body hook observed, but
the track hook and wolf draw unobserved, followed by the old generic message
`waiting for wolf model/texture/clips`.

That establishes an asset-preflight block. It does **not** distinguish a
missing model, loading/failed texture, missing skinning data or absent
imported clips. It also does not establish that the body/animation adapter
will work after the assets become ready.

The screenshot's later Crinos status retained an earlier pending message.
Crinos currently remains a scaled human placeholder; only Hispo and Lupus
request the wolf body. The panel's `Wolf requested: true` means the global
prototype option is enabled, not that the current form has a wolf model.

## Changes

- **Automatic diagnostics:** the next wolf request logs the exact blocked
  stage under `[WTAGarou Java][WolfAssets]`, without pressing any panel button.
- **Asset resolution:** reports whether the model script and animation rig
  are registered, plus engine-resolved paths/existence for the mesh, texture
  and four required animation files. Paths are checked read-only.
- **Imported clips:** names missing required clips and lists available clip
  keys, separately from whether their files exist on disk.
- **Failure versus loading:** an engine-reported failed model/texture no longer
  masquerades as indefinite asynchronous loading. The human body remains.
- **Status honesty:** human requests report no wolf registration for that
  player and retain a separately labelled last asset check for diagnosis.
  Historical hook flags remain observations, not proof of current rendering.
- **Non-weapon guard:** ordinary inventory items do not expose the weapon
  `isRanged()` method. The log showed this with `ComboItem`; those items and
  empty hands now retain vanilla recovery without throwing. Weapon speed
  factors and the approved recovery caps are unchanged.

No model-readiness check is bypassed and no human skeleton/animation is used
as a substitute just to produce a false success. No speculative bulk asset
reload, animal proxy, global animation override or equipment change is added.
The panel layout, main HUD, channelled shift animation and scale values are
unchanged.

## Test when convenient

1. Fully quit the game, pull `feature/cosmetic-model-swap`, and approve the
   rebuilt WTAGarou Java module in ZombieBuddy if requested.
2. Verify startup says Lua `0.4.6-wolf-diagnostics` and Java `0.4.6`.
3. Shift normally to **Hispo or Lupus** and stay there for about 10 seconds.
4. Send `console.txt`. No console commands or testing-panel function test
   is necessary; the new diagnostics are automatic.
5. If you do use the panel, **Status** shows the same detailed information.

If the files are present but clips never register, the next fix belongs in
animation discovery/import. If a path or script is absent, fix that resolution
or installation problem instead. This build is intended to distinguish those
cases from one playtest rather than guess at a broad loader rewrite.

## Verification

Local tests cover each preflight branch, imported-clip versus file existence,
the actual packaged asset paths via a fixture VFS, return-to-human status,
and non-weapon/empty-hand/ranged/melee recovery behavior. The existing Java
ZombieBuddy-advice tests and Lua regression suite remain required.

The engine reference is nearby **42.20.2**, not the user's **42.20.4**:
[ModelManager loading](https://github.com/Ketum-Git/PZ-Javacode/blob/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/core/skinnedmodel/ModelManager.java),
[model asset construction](https://github.com/Ketum-Git/PZ-Javacode/blob/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/core/skinnedmodel/model/Model.java),
[ComboItem](https://github.com/Ketum-Git/PZ-Javacode/blob/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/inventory/types/ComboItem.java).
Mocked asset states and advice tests do not validate the native asset importer
or the in-game appearance.
