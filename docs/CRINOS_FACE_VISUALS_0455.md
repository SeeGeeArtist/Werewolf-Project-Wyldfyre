# 0.4.55: Crinos face cosmetics and head scale 0.6

The head's current target scale is **0.6**. The previous repository value
0.675 is being replaced, not reapplied; the confirmed orientation and
zero offsets remain unchanged.

## Crinos-only visual hiding

Ready Crinos models now omit glasses/eye-slot accessories and makeup from
their render snapshots. Items stay equipped, saved makeup remains intact,
and neither protection nor inventory is changed. Returning to human form
uses the original visuals through the existing model reset.

The filter recognizes native body locations `Eyes`, `LeftEye`, `RightEye`,
`MaskEyes` and `MakeUp_*`, including typed namespace-qualified identifiers.
Unrelated slots, tattoos, medical bandages, clothing and hats are not
blanket-hidden. Unknown/missing item metadata is left unchanged.

This covers local and remote player rendering. Lupus/Hispo rendering is
not modified, and neither are the user-confirmed split-screen and voice
fixes, the .54 healing repair, or the explicitly deferred shove behavior.

## Why the ordinary head mask was insufficient

The native texture creator composes body visuals separately from worn
items and routes them through its clothing compositor
([ModelInstanceTextureCreator.java](https://raw.githubusercontent.com/Ketum-Git/PZ-Javacode/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/core/skinnedmodel/model/ModelInstanceTextureCreator.java)).
Suppressing the human head alone therefore does not remove every makeup
overlay or separate glasses model.

The new filter applies during native model population and texture
initialization only. The player's worn-item getter supplies a temporary
output list, copying remote visuals on client observers or collecting local
worn visuals otherwise
([IsoPlayer.getItemVisuals](https://raw.githubusercontent.com/Ketum-Git/PZ-Javacode/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/characters/IsoPlayer.java)).
Only that temporary snapshot is filtered. Saved HumanVisual body lists and
direct compositor input lists are copied before filtering.

This avoids missing-model warnings caused by deleting a glasses model while
leaving it in the compositor's item list. Outside rendering scope, the native
getters return the normal complete data. Nested renders and exceptions restore
the previous scope so one actor cannot hide another actor's cosmetics.
If the Crinos head is not ready, the human fallback is not stripped.

## Implementation notes

- `CrinosHeadPatch` scopes population after the real head is attached.
- `CrinosTextureScopePatch` handles every native init overload, including
  direct three-argument callers, using copied input rather than list mutation.
- `CrinosWornVisualsPatch` filters only caller-owned player visual snapshots.
- `CrinosBodyVisualsPatch` returns a filtered copy of saved body visuals.
- The texture hook uses ZombieBuddy's supported `isAdvice=true` route with
  native ByteBuddy dynamic argument assignment. The simplified wrapper does
  not expose that typing option for heterogeneous overloads.
- The ItemVisuals compile stub is excluded from the distributed JAR.

The reference engine above is 42.20.2; it is not a claim that the user's
installed 42.21.0 runtime was directly executed here.

## Verification and focused test

The full Lua/asset and Java regression suites pass. Fifty new face-visual
assertions cover local/remote snapshots, makeup preservation, human restoration,
nested renders, direct and nested compositor calls, exception cleanup, unknown
slots, and head-not-ready fallback. The asset check asserts head scale 0.6
and preserves both confirmed orientation matrices and body scales.
The updated JAR was rebuilt; GLB and PNG bytes remain untouched.

1. Fully quit, update the mod including the rebuilt `WTAGarouVisuals.jar`,
   then restart. Both Definitions and Java should report **0.4.55**.
2. Wear glasses and apply makeup in Homid. Shift to Crinos: both should be
   visually absent while still equipped/saved.
3. Shift back: the original glasses and makeup should return without
   re-equipping or reapplying them.
4. Check the head's **0.6** size and unchanged orientation.
5. If possible, observe this from a second client while another character
   stays human; only the Crinos actor should lose the face visuals.

Live appearance and restoration still require this playtest. Overwritten
old limp logs do not block it; if limping persists on .54/.55 after the normal
healing window, use a fresh console and health-panel screenshot.
