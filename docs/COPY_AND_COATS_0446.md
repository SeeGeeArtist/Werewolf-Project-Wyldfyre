# WTAGarou: editing copy and adding coat colours

Paths below are relative to the `WTAGarou/` directory on
[`feature/cosmetic-model-swap`](https://github.com/SeeGeeArtist/Zomboid-Garou/tree/feature/cosmetic-model-swap).
The wording and new artwork are left for you to edit; 0.4.46 does not add
unfinished coat options.

## Where the strings live

| What you want to edit | File and search term |
| --- | --- |
| Trait name and tooltip | `42/media/lua/shared/Translate/EN/UI.json`: `UI_trait_Garou`, `UI_trait_GarouDesc` |
| Human / Near-Human / Berzerker / Near-Wolf / Wolf tooltip descriptions | `42/media/lua/shared/WTAGarouDefinitions.lua`: each `FormData` entry's `description` |
| Extra form tooltip text: Rage cost, drain, return form, exit lock, vehicle restriction | `42/media/lua/client/WTAGarouHUD.lua`: `formTooltip` |
| Strip, Dress and Howl tooltips | Same HUD file: `stripTooltip`, `dressTooltip`, `howlTooltip` |
| Resist, Guide and Startup button tooltips | Same HUD file: `createChildren`, search `setTooltip` |
| Startup true-form tooltips | `42/media/lua/client/WTAGarouWolfCoat.lua`: `TRUE_FORM_TIPS` |
| Moon / auspice tooltip sentence | Same startup file: `Coat.auspiceTooltip` |
| Moon names and baseline values | `WTAGarouDefinitions.lua`: `WTAGarou.Auspices` |
| Guide pages | `42/media/lua/client/WTAGarouTutorial.lua`: `T.buildPages` |

Keep translation JSON keys and internal form/trait IDs unchanged; edit the
quoted display text. JSON strings need double quotes, escaped internal
quotes (`\"`) and commas between entries, with no trailing comma.

For highlighted Lua copy use the confirmed helper:

```lua
local R = WTAGarou.Rich
return R.lead("Heading", "lore")
    .. "Normal words before"
    .. R.kw("highlighted words", "rage")
    .. "normal words after."
```

Put punctuation inside a highlighted keyword where appropriate, such as
`R.kw("Ragabash,", "lore")`. Do not remove the helper's `<SPACE>` tags or
join raw colour tags directly to words. Avoid unsupported `<B>` tags and
larger font tags in tooltips.

## Add White, Black, Red and Blue

### Create the wolf PNGs

Place these files in `common/media/textures/Body/`:

```text
WTAGarou_Wolf_White.png
WTAGarou_Wolf_Black.png
WTAGarou_Wolf_Red.png
WTAGarou_Wolf_Blue.png
```

Use an existing wolf coat as the UV/template reference. Timber is
1024 by 1024; keep the same UV layout and avoid accidental transparency.
Blue is your blue-gray coat, not a bright-blue recolour.

### Register them once

Open `42/media/lua/shared/WTAGarouWolfCoats.lua`. Add these entries INSIDE
the existing `WTAGarou.WolfCoats = { ... }` table:

```lua
    white = {label="White", path="media/textures/Body/WTAGarou_Wolf_White.png"},
    black = {label="Black", path="media/textures/Body/WTAGarou_Wolf_Black.png"},
    red   = {label="Red",   path="media/textures/Body/WTAGarou_Wolf_Red.png"},
    blue  = {label="Blue",  path="media/textures/Body/WTAGarou_Wolf_Blue.png"},
```

The on-disk folder includes `common/`, but the runtime `path` starts at
`media/`. Match filename capitalization exactly. The filename suffix must
use letters, numbers, underscores or hyphens.

No individual button, model script, registry ID or Java rebuild is needed.
The panel creates a button per registered coat, grows its two-column grid,
and keeps Timber first with other keys alphabetically sorted. Its texture
check disables a choice whose PNG is missing. The shared registry supplies
the server allowlist and the client texture mapping, so install matching
files on the host/server and every client.

### Matching Crinos body and head (updated for 0.4.49)

The wolf PNG covers Hispo, Lupus and the replacement Crinos head. Crinos still
needs a separate human-UV body atlas; do not use the wolf image on the body.
Use these in the same `common/media/textures/Body/` folder:

```text
WTAGarou_CrinosBody_White.png
WTAGarou_Wolf_White.png
```

White and Black are now shipped and registered; only add Red/Blue once authored.
Current body atlases are 256 by 256 with intentional transparency; wolf atlases
are opaque 1024 by 1024. Both sexes currently share the body atlas, with female
fit still requiring a playtest. Do not restore deleted CrinosHead or F_ files.
Each registry entry follows this pattern:

```lua
    white = {
        label="White",
        path="media/textures/Body/WTAGarou_Wolf_White.png",
        crinosBody="WTAGarou_CrinosBody_White",
        crinosHead="WTAGarou_Wolf_White",
    },
```

Those two Crinos fields are texture names WITHOUT a folder or `.png`.
Use the corresponding suffix for each colour. If you omit the fields,
Crinos deliberately falls back to Timber; if you name missing textures,
the cosmetics loader waits for assets that are not there. Add these
fields only when both files exist.

### Restart and test

1. Commit the PNGs and the Lua registry together. From `WTAGarou/`, run
   `bash tests/run.sh`.
2. Fully restart after adding art or installing the 0.4.49 Java update.
   `/garou reload` refreshes Definitions and the coat registry, but does not
   reload the Java module or reliably invalidate cached model assets.
3. Use a fresh character, or in single-player testing run
   `garou("identity reset")` and reopen Rage > Startup. This resets the
   entire identity lock, so reselect your true form and baseline too.
4. Select each new colour and inspect both wolf forms. If you added Crinos
   textures, inspect its body and head too. Save, quit and reload to check
   that the chosen coat persists.
5. For a missing choice, check the Lua entry; for a disabled button, check
   the exact PNG path/case; for Timber on Crinos, check its two mappings.

The implementation points to consult are `WTAGarouWolfCoats.lua`,
`WTAGarouWolfCoat.lua`, and `WTAGarouVisual.lua` (`refreshCrinos` and
`setWolfTexture`), plus `java/src/wtagarou/visuals/WolfCoats.java` and
`CrinosCosmetics.java` in the
[repository](https://github.com/SeeGeeArtist/Zomboid-Garou).
