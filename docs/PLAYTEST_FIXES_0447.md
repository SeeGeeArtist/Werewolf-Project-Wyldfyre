# 0.4.47: Steam Deck title and controller menus

**Superseded title fix:** Oct 8 Deck testing found the Static text helper
throws on nonexistent scroll getters, hiding the HUD body too. See
[0.4.48 correction](PLAYTEST_FIXES_0448.md); controller changes below remain.

## Change contract

- Target: October 7 late Steam Deck playtest.
- Confirmed working: real copied mod folder restores the Werewolf trait;
  official ZombieBuddy 2.3.4 loads Java 0.4.46. Expanded Rage title displays.
- Observed failures: collapsed title disappears; nested controller Shift
  instantly chooses Lupus; keyboard-mapped grip opener loses visible controls;
  later radial access fails. Latest console also records an AtomUI label
  exception during ISReadABook.displayPrintMedia / setJoypadFocus.
- Must remain untouched: art, gear, corpses, transformation rules, identity,
  auspices, balance, insulation, howl audio, wording the user is editing.
- Evidence still needed: actual Deck display, repeated native wheel
  selection/cancel, printed-media focus recovery and multiplayer playtest.

## Implemented

- Rage title: drawTextCentreStatic bypasses only the ordinary helper's
  collapsed-window guard, without reopening the window or disabling body
  clipping. Retains two-pass bold-style lettering and strict red <25/>75.
- Social / D-pad down: native emotes plus Howl, Strip, Dress. Wardrobe slices
  remain in fixed positions with a zero count when unavailable; existing
  actions safely handle nothing to strip/dress. No nested Shift or Resist.
- Map / D-pad right: native map, minimap, zones and guide entries plus five
  form choices and Resist. Existing eligibility/server validation, costs,
  entry requirements and active Resist countdown remain.
- Input: no standalone forms keybind/listener. Optional Rage toggle defaults
  to unbound under WTAGarou_ToggleRagePanel; the old saved ToggleHUD key and
  alternate key no longer dispatch. Other action keybindings are unchanged.
- Callback actor: native wheels pass their owning player into the existing
  request/wardrobe entry points; callers without an actor still use getPlayer.
- Focus compatibility: the original ISAtomUIJoypad.toString runs in pcall,
  falling back to the harmless label AtomUI if native diagnostic formatting
  throws. No changes to focus transfer, window lifetime or controller input.

## Evidence and verification

The attached Deck log's lines 993-1011 show the AtomUI diagnostic exception.
This is confirmed evidence of a focus-transfer failure while opening printed
media, not proof that every earlier radial symptom shared that cause.

The Lua reference inspected is community vanilla **42.20.2**, not a supplied
42.21 Lua installation. Its ordinary centered-text helper explicitly returns
when isCollapsed while the Static helper does not
([ISUIElement](https://github.com/Project-Zomboid-Community-Modding/ProjectZomboid-Vanilla-Lua/blob/8a906692ac56f9d40c078d654eea6c70491cbc62/client/ISUI/ISUIElement.lua)).
The map builder owns positioning, focus and DPadRight release
([ISDPadWheels](https://github.com/Project-Zomboid-Community-Modding/ProjectZomboid-Vanilla-Lua/blob/8a906692ac56f9d40c078d654eea6c70491cbc62/client/ISUI/ISDPadWheels.lua)).
The radial removes itself before calling a selected command
([ISRadialMenu](https://github.com/Project-Zomboid-Community-Modding/ProjectZomboid-Vanilla-Lua/blob/8a906692ac56f9d40c078d654eea6c70491cbc62/client/ISUI/ISRadialMenu.lua)).
The supplied 42.21 Java UIElement supports the font-aware DrawTextCentre call.

Tests: all Lua syntax and repository Lua/asset regressions; realistic
collapsed-helper suppression; 49 direct-menu assertions including correct
actor, old-button release rejection, repeated cancel and vanilla gates;
AtomUI exception reproduction and fallback. Optional reference execution:

```sh
WTAGAROU_VANILLA_LUA=/path/to/reference \
  lua5.1 tests/channel_hud_test.lua .
lua5.1 tests/native_radial_reference_test.lua . /path/to/reference
```

The reference directory needs ISUIElement.lua, ISRadialMenu.lua,
ISEmoteRadialMenu.lua and ISDPadWheels.lua. Engine rendering is stubbed:
these checks prove Lua routing, not actual Deck rendering/input.

## Minimal Deck retest

1. Fully quit, pull the branch, refresh the real installed WTAGarou copy.
   Definitions must say 0.4.47. The unchanged Java banner says 0.4.46.
   Do not install another JAR.
2. Collapse Rage, move the pointer away, then let Rage change. Verify visible
   live counter, white at 25/75 and red below/above those thresholds.
3. D-pad down: verify native emotes and Howl/Strip/Dress, no Shift submenu.
4. D-pad right: select a non-Lupus form deliberately. Exactly that one request
   should start after release. Verify Resist and the native map still work.
5. Alternate both wheels and cancel with B/X several times. Controls should
   return. Check native keyboard/mouse social access and HUD form buttons.
6. Read/close printed media, then repeat both wheels. If controls fail, attach
   a fresh console and describe whether failure began before or after reading.
7. Check Options: no forms-radial binding; Rage toggle unbound. Assign a new
   Rage key only if desired. Existing unrelated bindings remain.
