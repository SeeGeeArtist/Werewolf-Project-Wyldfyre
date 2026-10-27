# 0.4.45 - Baseline Rage (auspices), renames, cheats, /garou commands

Oct 7 request. Static verification only; nothing below is confirmed in game.

## Baseline Rage

- `WTAGarou.Auspices` (Definitions): Ragabash / New Moon / 30, Theurge /
  Crescent Moon / 40, Philodox / Half Moon / 50, Galliard / Gibbous Moon /
  60, Ahroun / Full Moon / 70.
- Werewolf Startup panel: a "Baseline Rage" row (buttons 30 40 50 60 70)
  between the coats and Confirm. Tooltip: "<Moon> Werewolf. As a
  <Auspice>, rage value gravitates to <n> when you're healthy and happy."
  with the moon, auspice and number highlighted.
- Confirm needs a coat AND a baseline; the Are-you-sure dialog names all
  three; the server stores `d.auspice`, `d.auspiceLocked = true` next to
  `identityLocked`. A character locked before 0.4.45 is prompted once and
  can confirm only the baseline (true form / coat stay locked). Reset
  identity (`/garou identity reset`) clears the baseline too.
- `WTAGarou.BaselineRage(d)`: the locked auspice's value, else 50
  (`Rage.BASELINE_DEFAULT`). `Rage.START` is 50. `Howl.TARGET_RAGE` and
  `Rage.HOWL_CENTER` were removed; the server HowlTick, the radial label
  and the new Howl tooltip all use the baseline.

## Contentment drift (replaces the Well Fed pull)

`WTAGarou.ContentPullPerSecond(hungry, thirsty, wellFed, form)` with
`R = Rage.CONTENT_PULL_PER_SECOND = 0.30` (the old well-fed rate):

| state | multiplier | per second |
| --- | --- | --- |
| hungry and thirsty | 0 | 0 |
| one of the two moodles missing | 0.75 | 0.225 |
| neither moodle (fed and watered) | 1.5 | 0.45 |
| ... plus Well Fed | 2.0 | 0.60 |

- Applies in every form unless `Rage.CONTENTMENT.SKIP_FORMS[form]`.
  Crinos burns 1/s, so fed and watered it nets -0.55/s below the baseline
  (-0.40/s with Well Fed) and -1.45/s above it. The old pull did the same
  at 0.30 per Well Fed level; set `SKIP_FORMS = { Crinos = true }` if the
  war form should burn at its full rate.
- Paused while Rage >= `CONTENTMENT.PAUSE_ABOVE` (95, the countdown's
  cancel line) so the confirmed 100-Rage countdown and Resist cycle are
  unchanged.

## Rich text

Build 42's `ISRichTextPanel:paginate` splits on plain spaces, cuts a token
at the first `>` and treats any token containing `<` and `>` as a command.
So `<RGB:..> Homid <RGB:..> Human` renders "HomidHuman" and
`a<SPACE><RGB>Wyrm<RGB><SPACE>b` renders "a b" with both words gone. Rule:
every tag stands alone between spaces and `<SPACE>` marks a visible gap.
`WTAGarou.Rich.kw(text, kind)` / `Rich.lead(text, kind)` / `Rich.tidy` /
`Rich.plain` implement it; HUD tooltips, Startup tooltips and the Guide
use them. `tests/rich_text_test.lua` ports the vanilla tokenizer and
renders every string.

## Names

Trait "Werewolf" (description opens "You are Garou: a werewolf..."),
panel "Rage", "Werewolf Startup" (footer: "Reopen later: Rage panel >
Startup."), "Werewolf Guide", "Werewolf Cheats", keybind category
"Werewolf", "Toggle Rage panel", denial "You are not a werewolf.".
The Startup panel's right-click world entry is gone; the Rage panel has a
sixth right-column button "Startup" under Guide (panel 324 tall).

## Werewolf Cheats and /garou

- World entry only when `isClient()` and `isAdmin()` (multiplayer admin
  role). Everyone else: `/garou cheats` (alias `panel`).
- Lua debug console (-debug): `DebugConsolePatch` (ZombieBuddy, on
  `UIDebugConsole.ProcessCommand`) rewrites a line starting with `/garou`
  into `garou("...")` before `LuaCompiler.loadstring` sees it. Plain Lua
  (`garou("rage 100")`, `WTAGarouInfo()`) still works.
- Multiplayer chat: vanilla `ISChat:onCommandEntered` forwards every `/`
  line with `SendCommandToServer`, which is why `/garou` never reached the
  `OnAddMessage` hook. `WTAGarou.Debug.wrapChat()` wraps the handler (and
  re-points the live text entry on game start) so `/garou ...` runs on the
  client and is swallowed. Single player has no chat box: use the console.

## Smallest in-game test

Full restart. Banners: `[WTAGarou] Definitions loaded - version 0.4.45`
and `[WTAGarou Java] 0.4.45 loaded`.
1. Rage panel titled "Rage" with a Startup button under Guide; hover Howl
   ("baseline of 50"), Human ("Homid Human form" with a gap).
2. Startup: pick a baseline, hover each number, confirm; `/garou info`
   in the console prints `auspice=... baseline=...`.
3. Eat and drink until no Hungry / Thirst moodle; `/garou rage 20`; Rage
   should climb about 0.45/s toward the baseline (0.60/s when Well Fed).
4. Multiplayer: type `/garou cheats` in chat; no "unknown command".
