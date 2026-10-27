# 0.4.48: restore the Rage panel draw path

## Change contract

- Target: Oct 8 Deck regression: only child command buttons remain visible.
- Confirmed working: expanded counter in .46; real copied installation.
- Observed failure: .47 drawTextCentreStatic throws a nil-call error at
  ISUIElement.lua:1338, called by drawRageTitle:562 and prerender:504.
- Must remain untouched: .47 controller wheels, bindings, focus compatibility,
  all gameplay/balance, user copy, assets and Java.
- Evidence still needed: live expanded and collapsed rendering on the Deck.

## Cause and narrow correction

The normal drawTextCentre helper returns when collapsed. The Static helper
chosen in .47 bypasses that guard, but calls undefined getScrollX/getScrollY.
The actual methods are getXScroll/getYScroll. The title is drawn before the
meter/body labels, so that exception prevents them from being drawn; child
buttons have their own drawing path and remain.

The .47 integration test mistakenly supplied the nonexistent aliases, masking
the bug. Those stubs are removed. No vanilla helpers or UI classes are patched.
Our title calls self.javaObject:DrawTextCentre directly with UIFont.Small,
compensating offsets with the native getXScroll/getYScroll methods. These
signatures are present in the supplied 42.21 UIElement class. Collapse state,
stencil, font, bold-style offset and red thresholds are unchanged.

The available vanilla reference contains the failing helper and actual getter
names ([ISUIElement, 42.20.2 reference](https://github.com/Project-Zomboid-Community-Modding/ProjectZomboid-Vanilla-Lua/blob/8a906692ac56f9d40c078d654eea6c70491cbc62/client/ISUI/ISUIElement.lua)).
The new Deck console confirms that same helper fails at line 1338 in the user's
runtime; this is not inferred solely from the older reference.

## Verification

- Full Lua syntax and Lua/asset suite passed.
- 672 channel/HUD assertions passed, both with mocks and with the supplied
  vanilla Lua helpers; native drawing calls are recorded, not rendered.
- Actual .47 HUD code plus corrected harness reproduces the same missing
  getScrollX stack at ISUIElement:1338 / drawRageTitle:562 / prerender:504.
- Tests require expanded meter and labels after title drawing, collapsed
  live counter, unchanged collapse flag and correct scroll compensation.
- Java, art, balance and controller modules are byte-for-byte unchanged.
- Still unverified: actual Deck rendering. Do not call this live-confirmed.

## Retest

Fully quit, pull feature/cosmetic-model-swap and refresh the real installed
WTAGarou copy. Definitions/mod version is 0.4.48; Java stays 0.4.46 with no JAR
replacement. Verify expanded meter, labels and title first. Then collapse,
move the cursor away, and verify the live counter remains. Reopen and confirm
the meter returns. If it fails, send a fresh console.
