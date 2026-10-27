# 0.4.22 - September 27 playtest fixes

Everything below came out of the September 27 playtest (consoles: Definitions
0.4.21, Java 0.4.20, four Resist cycles, silver neck burn, Dress from Glabro
skipping Sneakers and Socks, saddlebag retarget log x12, gait log showing
0.42 s walk cycles).

## Shipped

| Report | Change | Where to tune |
| --- | --- | --- |
| "It only ever said Burn, never Silver Burn" | Health panel draws a second line, light blue-grey: `- Silver Burn: Neck, Left Hand`. A halo text "Silver Burn: Neck" pops when a part first burns (the closest thing to a moodle without a Java moodle framework). | `client/WTAGarouHealthPanel.lua` `HP.SILVER_COLOR`, `HP.SILVER_NAME` |
| "Glabro can wear whatever Homid can wear... remove the wear blacklist" | `WTAGarou.WEAR_BLACKLIST_ENABLED = false`. Every form dresses; the shift damage rules stay as the deterrent. The old per-form lists remain as documentation and switch back on with the flag. | `shared/WTAGarouClothing.lua` top |
| "Non-Homid forms could be 15% bigger" | Glabro 1.08 -> 1.24, Crinos 1.25 -> 1.44, Hispo 1.35 -> 1.55, Lupus 1.00 -> 1.15 - each exactly 1.15x the value in the September 27 test. Lupus' `modelScale` was 1.00, not below 1: the small wolf comes from the Java body normalisation `WolfRuntime.BODY_SCALE = 0.60` that multiplies every wolf form (0.60 -> 0.69 on screen for Lupus, 0.81 -> 0.93 for Hispo). | `shared/WTAGarouDefinitions.lua` `modelScale` in each `FormData` entry |
| "Panel info text disappears too fast / doesn't wrap" | Notices last 6 s (user floor: 4 s) and wrap to the panel width, six lines. Clarified September 27: nothing had overwritten the end-of-operation notice, it just expired too soon, so newer notices simply push older ones off (no queue, no minimum hold); quick progress notices may be short-lived. Panel height 300. | `client/WTAGarouHUD.lua` `NOTICE_*` constants |
| "Colored keywords without eating the spaces" | Guide keywords are `<SPACE><RGB:..>word<RGB:1,1,1><SPACE>`; `<SPACE>` is the rich-text panel's explicit space tag. Colours per kind: form gold, war red, rage orange, action light blue, wyrm violet, silver blue-grey. | `client/WTAGarouTutorial.lua` `T.COLORS`, `T.kw` |
| "Garou don't need flashlights" | The Garou trait now grants `base:nightvision` (Cat's Eyes) with Fast Healer and Hearty Appetite. Whether a closed room is bright enough is for the playtest. | `scripts/characters/wtagarou_traits.txt` `GrantedTraits` |
| "Trait tooltip is very wide" | The description has `<LINE>` breaks after every sentence. UNVERIFIED that the trait tooltip honours `<LINE>`; if it prints literally, the fallback is `\n`. | `shared/Translate/EN/UI.json` `UI_trait_GarouDesc` |
| "Wolf movement animations half speed, keep the speed buff" | `WolfPlayerClips.cycleSlowdown` (default 2.0) multiplies the stride-matched clip clock. Movement is untouched; the paws slide a bit. | `WTAGarou.WolfGait.CYCLE_SLOWDOWN` in Definitions |
| "Saddlebags keep changing size / go tiny after re-wearing" | Java compensated each pooled `ModelInstance` once; the engine resets a reused instance to script scale (0.6), so 0.6 x FinalScale 0.6 = 0.36. Now a scale that differs from the value we wrote is compensated again (`perfRecompensated` counter). | `java/.../WolfRuntime.compensateScale` |
| "Raise the saddlebags; where do I fix that" | New `WTAGarou.Saddlebag = { rotate, offset }` in Definitions, applied on top of the model-script attachment exactly like `MouthCarry`, no rebuild. Default offset `{0, 0, 0.04}`. Base placement stays in `scripts/wtagarou_models.txt` (`model WTAGarou_Saddlebags`, attachment offset/rotate/scale) and the bone in Java (`WolfRuntime.SADDLEBAG_BONE`). | Definitions `WTAGarou.Saddlebag`; `wtagarou_models.txt` for the base |
| "Do away with the panniers container" | `WolfSaddlebag` and `WolfSaddlebag_Small` are `Obsolete = TRUE` (saves still load them), no longer granted at start. The bag mesh already shows for ANY worn container in Hispo/Lupus. | `scripts/wtagarou_items.txt`, `client/WTAGarouStartingItems.lua` |
| "Force a refresh of Definitions in-game?" | Test panel "Reload defs" / `/garou reload`: re-reads `WTAGarouDefinitions.lua` through the mod file reader + `loadstring`, rebuilds the Guide, forgets the wolf request so the next shift re-pushes MouthCarry/Saddlebag/WolfGait to Java. Falls back to `reloadLuaFile` if the reader is missing. UNVERIFIED in game. | `client/WTAGarouDebug.lua` `reloadDefinitions` |

## Turn swing ("wolf rotates around the origin and dips into the floor")

The vehicle-physics idea does not hold: `IsoPlayer` only touches vehicle
physics through `getVehicle().updatePhysics()` while seated as a driver
(IsoPlayer.java 42.20.2 lines 2347 and 4421), the character itself has no
Bullet body (Bullet is used for vehicles, thrown `IsoPhysicsObject`s and
the death ragdoll via `RagdollBuilder`), and the wolf is drawn on the real
`IsoPlayer`, so there is nothing to disable.

What the derived clips DO carry is the human clip's movement marker
(`Translation_Data`) including its deferred rotation, placed at the wolf
marker's authored rest offset. If that rest offset is not at the origin, a
turn/aim clip's rotation turns the offset into an arc - a swing around the
origin. 0.4.22 logs the offset once per wolf clip
(`[WTAGarou Java][Gait] wolf clip Wolf_run marker Translation_Data rests
at (x, y, z)`) and adds `WTAGarou.WolfGait.MARKER_AT_ORIGIN` (default
false, unchanged behaviour). If the log shows a non-zero offset, set it to
true, Reload defs, reshift, and try the Ctrl turn again. If the offset is
zero the cause is elsewhere (candidates: the human turn clips' root pitch
copied onto a wolf root with a different rest orientation). The fence and
window "rubber-band" overshoot is probably the same family - the human
climb clip's marker deltas driving a wolf whose collision box and pose do
not match - and is still open.

## Mouth carry note

`WTAGarou.MouthCarry.offset` is metres in the item's local space (Java
`xfrm.translate`). The committed `{0, 5.0, 0}` is five metres; 0.05 is
five centimetres. `rotate` is degrees.

## Deferred (asked, not started)

- Attachment points on the wolf (belt left/right beside the spine behind the
  bags, back above-right, secondary front-left): needs a per-attachment
  retarget table in `WolfRuntime.hideSubmodel` like the saddlebag one.
- Tool-less butchering in wolf forms; unarmed attacks as blade + shove in
  beast forms; Ctrl-highlight bite that slows a deer.
- Animal tracks behind a spawned deer not highlighted (vanilla
  `AnimalTracksDefinitions`, needs investigation).
- Window climb forward rubber-band.
- A real Silver Burn moodle (no B42 Lua moodle API without a framework mod).
- The user redraws `wta_resist.png`.

## Tests

`bash tests/run.sh`: 12 Lua suites green (29 / 640 / 28 / 25 / 130 / 35 /
472 / 216 / 89 / 38 / 21 / 222). `bash java/test.sh`: 6 Java suites green
(222 / 206 / 23 / 242 / 12 / 29). Nothing here proves a visual result in
game.
