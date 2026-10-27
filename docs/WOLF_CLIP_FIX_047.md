# Wolf clip loading and multiplayer visuals: 0.4.7

## Confirmed blocker

The September 21 console from **0.4.6 / Build 42.20.4** first reports a
loading texture, then:

```text
model/texture/skinning ready;
missing clips=[Wolf_idle, Wolf_walk, Wolf_run, Wolf_attack];
clip count=0; available=[]
```

All four animation files, the mesh and texture resolve to existing files,
and both the model script and animation rig are present. The texture did
finish loading; the persistent blocker is the empty imported animation map.
This explains why the safety check retained the human body. The log alone
does not explain why automatic discovery/import left that map empty.

## Targeted loading change

Java 0.4.7 explicitly requests the nine clips used by the wolf adapter from
the packaged `WTAGarouWolf` directory through the normal ModelManager
animation loader. It registers them under the active WTAGarou mod, using
the actual wolf rig and ordinary asynchronous import callbacks.

- A loading asset is queued once, not every frame or once per character.
- A cached READY asset can reinstall its expected clip if the target map
  was emptied without another asset-completion callback.
- A cached asset bound to another skeleton is reimported against the wolf
  skeleton, not relabelled with incompatible bone indices.
- The model and animation rig must share skinning data before importing.
- Missing/failed required clips keep the human body and produce an error.
- No readiness bypass, fake clips, human skeleton substitution, global
  animation reload or animal/mount proxy is used.

Expected diagnostic progression is:

```text
[WolfClips] explicit wolf clips ready=0/9 ... queued this pass=9
[WolfClips] explicit wolf clips ready=9/9 ...
[WolfAssets] model, texture, skinning and required clips ready
Direct wolf request=true result=wolf
```

Counts can differ with cached assets or asynchronous completion; only the
four core idle/walk/run/attack clips gate activation, while unfinished optional
actions retain the existing idle fallback. Registration
success still needs visible confirmation of the actual wolf and its motion.

Implementation follows the available nearby engine reference:
[ModelManager.loadAnim and registration](https://github.com/Ketum-Git/PZ-Javacode/blob/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/core/skinnedmodel/ModelManager.java),
[AnimationAssetManager callbacks](https://github.com/Ketum-Git/PZ-Javacode/blob/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/core/skinnedmodel/model/AnimationAssetManager.java),
and [targeted AssetManager reload](https://github.com/Ketum-Git/PZ-Javacode/blob/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/asset/AssetManager.java).
That reference is 42.20.2; native behavior on 42.20.4 needs the playtest.

## Solo and multiplayer paths

**Solo:** keeps the existing local server-authoritative form-change path,
using the new clip loader on the same actual player.

**Multiplayer:** adds a distinct observer visual path. The previous client
sent a `TransformBroadcast` command, but the main server handler did not
implement a corresponding usable form-visual broadcast.

The new server module reads confirmed player states, polls once per second,
and broadcasts a full visual snapshot when they change. A ten-second
heartbeat supplies late joiners with existing forms. Snapshot data includes
online ID, username, form, Garou state and alive state, not client-chosen
model scripts, sizes, Rage values or inventory.

Each client applies validated snapshots only to remote players, with:

- sequence checks against older/malformed snapshots;
- ID plus username matching to avoid assigning a disconnected player's
  wolf to somebody who reuses that online ID;
- stream-in catch-up and stream-out/disconnect cleanup;
- return-to-human, trait loss, death and vehicle-state handling;
- visual state kept separately from remote gameplay mod data;
- no override of the local player's gameplay, action queue or inventory.

Dedicated servers do not need to load the client Java renderer. The server
needs the updated WTAGarou Lua mod; **every viewing client needs matching
WTAGarou assets and the approved ZombieBuddy Java module**.

This is a multiplayer visual implementation with local simulation coverage,
**not a verified live multiplayer release**. Combat authority, balance,
latency and the rest of the mod still need real multiplayer testing.

## Test sequence

1. Fully quit and pull `feature/cosmetic-model-swap`.
2. Approve the rebuilt Java module in ZombieBuddy if prompted.
3. Confirm Lua `0.4.7-wolf-clips` and Java `0.4.7` at startup.
4. In a disposable solo save, shift to **Lupus** and wait up to ten seconds.
   Check standing, walking, running, attacking and returning to Homid.
5. Send a screenshot or short video plus `console.txt`, whether or not
   the visible result succeeds. The loader diagnostics are automatic.
6. After solo works, test with two clients: have A change form while B
   watches; reverse roles, return to Homid, then join while someone is
   already a wolf. Allow up to ten seconds for initial snapshot catch-up.

The existing **Wolf OFF** panel control remains an escape; it disables the
wolf prototype on that viewing client, not another player's gameplay form.
Hispo uses the same wolf mesh at 1.25 scale. Crinos is still a scaled human
placeholder, not a newly implemented war-form mesh.

## Preserved behavior and verification

The literal `nil, nil` shift animation, action-layer suppression, approved
scale factors, HUD placement, testing-panel layout and melee speed tuning
remain unchanged. Reference mods and bundled wolf assets are unmodified.

Verification includes:

- Lua syntax and the existing channel/HUD/panel/combat tests;
- a multiplayer simulation covering authority, stale packets, late/streamed
  peers, form restoration, vehicle/death handling and local-player isolation;
- Java tests for empty clip maps, async/idempotent loading, cached ready clips,
  mismatched skeleton reimport, failed imports and inactive-mod safeguards;
- existing real ZombieBuddy advice translation tests.

The loader tests use engine API fixtures and simulated importer completion.
They do not run the native GLB importer, render the game, or replace a
two-client playtest. Root-motion alignment, clip blending and human gameplay
events on wolf clips remain prototype risks even once the mesh appears.
