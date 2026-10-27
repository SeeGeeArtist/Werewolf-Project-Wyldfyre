# Garou testing panel

Added in Lua/mod version **0.4.5-test-panel** on `feature/cosmetic-model-swap`.
The Java module remains **0.4.4**; this update does not change or rebuild it.

## Open without the console

Load a test save, right-click the ground, and select **Garou testing panel**.
Neither Steam's `-debug` launch option nor the Lua console is required.
The panel starts closed and opens toward the right of the screen, separately
from the main Garou HUD. Drag its title bar to move it; closing and reopening
remembers its position for that character.

Alternatives:

- In chat: `/garou panel`.
- In the Lua console: `WTAGarouToggleTestPanel()`.

The panel targets the primary local player. In multiplayer, opening and
using it requires a nonempty elevated access level, matching the existing
server-side debug-command restriction. It does not grant permissions or
bypass the server. Secondary split-screen characters are not supported.

## Controls

- **Normal shift:** all five forms, using the existing channel, Rage costs,
  cooldown and server approval. The permanent `nil, nil` animation contract
  is unchanged.
- **Instant form:** all five forms, bypassing the channel, cost and cooldown.
  Existing form gear restrictions still apply and may drop forbidden items.
  Instant and normal buttons are disabled during a shift/howl, preventing
  the testing panel from changing form under an active channel.
- **Rage:** set to 0, 50 or 100, or subtract/add 25.
- **Wolf ON/OFF:** enable/retry or disable the direct-player wolf prototype.
  These change the visual setting, not the gameplay form. OFF remains
  available during a channel as an emergency visual escape.
- **Status:** display the Java module's diagnostic text in the panel and
  print it to `console.txt`. Missing Java and bridge errors are displayed.
- **Player info:** print the existing form/Rage/Infamy/scale diagnostics.
- **Trace panic / Stop trace:** start the existing read-only 60-second
  panic trace or stop it early. Detailed samples remain in `console.txt`.
- **Grant Garou:** add the trait for a non-Garou test character.
- **Reset HUD:** use the existing main-HUD position reset.

The top of the panel shows current form, Rage, configured scale, trait,
requested wolf toggle, Java API presence and channel state. A requested
toggle or available Java API does **not** prove a wolf was rendered.
The result box shows the latest command feedback, shift acknowledgement,
completion or denial. Use the mouse wheel over the panel to scroll long
diagnostic output. It is a latest-result view, not a persistent log viewer.
While it is open, debug messages go here instead of spilling over the compact
main HUD; console logging remains enabled.

## Suggested first test

1. Use a disposable save and open the panel from the ground context menu.
2. Grant Garou if necessary; set Rage to 100.
3. Click **Hispo** under **Instant form** to isolate the model adapter.
4. Click **Status**, then instant **Homid** to check restoration.
5. Repeat with Lupus; verify movement and melee attacks yourself.
6. Test **Normal shift** separately to verify channelled transformation.
7. If visuals break, click **Wolf OFF**; choose instant **Homid** if you also
   want to restore the gameplay form.

## Verification and limitations

Lua 5.1 tests exercise actual button callbacks, all form routes, server-command
payloads, permissions, active-channel guards, missing/throwing Java, output
wrapping/scrolling, independent saved placement, death, and server feedback.
The pre-existing shift/HUD/scale/combat regression suite remains required.

These are mocked UI/engine tests, not an in-game screenshot or visual test.
Native font scaling, context-menu integration and the wolf prototype's
appearance still need a real game run. No Java model, animation, combat or
main-HUD behavior is changed in this release.
