# 0.4.79: Oct 21 playtest fixes (panel, sniffer, silver weapons, health panel)

Source: the Oct 21 report, panel screenshot and three hosted-server consoles
(`coop-console-2/3/4.txt`).

## What the server consoles say

All three end with `Host user disconnected, stopping the server`: the
SERVER did not crash in any of the three incidents (silver knife equip,
couch, silver machete equip). The HOST CLIENT went down and the child server
shut itself down. The server consoles hold no mod error for those moments.
The client console (`~/Zomboid/console.txt` on the hosting PC, or
`console.txt` next to the coop console) is the one that holds the crash and
the invisible-model state; it is still needed.

What the server log did show: `[WTAGarou] SeeGeeArtist took a hit in
Glabro: 0.3 part health refunded` every sweep for minutes, i.e. the
toughness refund was treating burn ticks as hits (fixed below).

## Fixes

1. **Silver Knife / Silver Machete (the equip crashes).** Both were Build 41
   item definitions (`StaticModel`, `WorldStaticModel`, no `WeaponSprite`,
   no sounds or animation fields). They are now line-for-line copies of the
   42.20 vanilla HuntingKnife / Machete with the forged model and icon,
   silver name and the `WTAGarouSilver` tag. Equipping a weapon with no
   WeaponSprite is the most likely cause of the hard crash; confirm with the
   client console. The normal path to a silver weapon is unchanged ("Forge
   Silver onto Weapon" coats a vanilla weapon).
2. **Rage panel.** Four log lines by default; resizable in both axes with
   the vanilla corner and bottom-edge handles (minimum 300 wide / two log
   lines; the size is saved with the position, layout version 3). The two
   button columns share the width; the log takes the height. The status
   line between the meter and the buttons is gone and the buttons start at
   `top + 42`: "Changing to Human... press Esc to stop.", "Howling... run
   or press Esc to stop.", every denial ("The Rage will not let you go
   yet.") and "Not Garou" are log lines; the Berzerker countdown is on the
   Resist button and in the log. "new below" is a scroll-to-bottom icon
   (rect-drawn down arrow with a base line; lit yellow while unread entries
   wait, grey when merely scrolled back; click jumps to the newest line).
   Infamy is hidden (`WTAGarou.HUD.SHOW_INFAMY`). Baseline bracket: 2 px
   line with 3 px ticks rising 4 px at both ends (a down-bracket).
3. **"You smell silver" never showed over the head.** Build 42's
   `HaloTextHelper` has no `getColorRGB` and no 3-argument `addText`; the
   coloured halos were silently skipped. `WTAGarou.Halo(player, text, r, g,
   b)` calls the real `addText(player, text, separator, r, g, b)` (0-255)
   with `addBadText` as the fallback; the burn halo and the scent halo both
   use it.
4. **Sniffer spam (a line every three game minutes).** The scent clock
   reset on any single clean 2-second sniff, so a step behind a door frame
   counted as "walked back into it". Now the smell must be gone for
   `SCENT_CLEAR` (20 s) before the contact is over, and two warnings are
   never closer than `SCENT_MIN_GAP` (30 s); the 60 s repeat while it
   lingers stays. It was never one notice per item: one sniff, one notice.
5. **Air through doors and windows.** "Open to the same air" was "same
   room". It is now the engine's own line test (`LosUtil.lineClear`):
   Clear and ClearThroughOpenDoor pass; ClearThroughWindow passes only when
   the window on the line is open or smashed; closed doors and walls block.
   So yes, Zomboid does compute sight through open doors and windows and
   the sniffer now uses it (same floor only).
6. **Toughness refund leak.** A drop that continues sweep after sweep on
   the same part is damage over time (burn, silver burn, heavy bleed) and
   is refunded on the first sweep only (`snap.streak`). The per-sweep
   console line goes quiet.
7. **Health panel: silver burn under the body part.** A silver burn is a
   vanilla burn flagged in `d.silverBurns`, so the part's own "- Burned" /
   "- Burned (Needs Cleaning)" line becomes "- Silver Burn (...)" in the
   silver colour (same doDrawItem shadow as the lodged lines). When vanilla
   draws no burn line (bandaged) a "- Silver Burn (bandaged)" line is added
   under the part. The summary line at the top is gone (`HP.SUMMARY_LINE`).
8. **Witnesses / Infamy dormant.** `WTAGarou.Delirium.ENABLED = false`:
   the client scanner sends nothing, the server ignores WitnessTick and
   DeliriumReport, the panel hides Infamy. Players are never witnesses even
   when it is switched back on (`PLAYERS_WITNESS = false`): two friends
   shifting with PvP on raised each other's Infamy. Existing Infamy values
   are left in place (hidden, no effect).
9. **Scatter option missing.** Causes could not be confirmed without the
   client console, so three things changed: Silver Fragments
   (`Base.SilverScrap`, the item the user actually tried) scatter a tile
   too (one unit a tile; the server takes the item by id, pickup gives a
   fragment back; filings still drain 5 uses on the client and come back as
   filings); the options also sit on the inventory right-click menu of the
   fragments / filings item (acting on the square you stand on); and the
   world-menu handler reports its first failure as
   `[WTAGarou][Scatter] ... failed:` instead of vanishing. "Pick up
   scattered silver" is the pickup label.
10. **Recipe and tooltip wording.** "Forge Silver onto Weapon"; the coated
    weapon's line reads "Silver-Clad: burns werewolves, prevents healing."

## Answers

- **Firefighter axe refused by the forge recipe.** Not a bug in the item
  list: each weapon asks for the Blacksmith level vanilla asks to forge it
  (`WTAGarou.SilverAmmo.FORGE_LEVELS`: pocket knife 1 ... Axe 6, Machete 9).
  Below that level the weapon is rejected as an input, and vanilla's panel
  shows a rejected input as "missing" rather than "level too low". That is
  why the pocket knife worked at a low level and the axe did not.
- **Fence climbing offset per form.** Not a flat offset: the climb
  animations start on the ground and the model scale (1.65 Crinos) scales
  the whole arc, so the hands land 65% too high. The honest fix is a
  state-gated correction in the Java visuals layer: while the player is in
  the climb-over-fence / climb-over-wall states, compress the vertical
  component of the root motion by 1/scale, driven by the animation's
  progress. The animation data can be read (the climb tracks and their
  timing are in the vanilla anim assets), so this is feasible, but it rides
  with the next Java build, not this Lua one.

## Follow-up (0.4.80)

The client console arrived: the equip crash and the invisible model are
the per-frame `ScriptManager.getItemName` NPE on the B41 weapon
definition (fix 1 above). The climb correction shipped as the Java hook
in `docs/CLIMB_COMPRESSION_0480.md`.

## Still needed from the playtest

- The CLIENT console for: the silver knife equip, the couch sit, the silver
  machete equip, and the session with the invisible model.
