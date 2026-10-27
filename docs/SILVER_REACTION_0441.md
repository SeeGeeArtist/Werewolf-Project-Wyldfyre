# 0.4.41 — silver burn reaction

## Change contract

```text
Target: a silver burn application should be felt — a cue once per application
  (vanilla "ouch" for Homid/Glabro, Crinos growl, Hispo growl, wolf growl for
  Lupus) and a warning in the Garou panel.
Confirmed working: .39 balance/vehicle/window/picker locks; everything in .40 is
  unverified and untouched.
Observed failure: .40 playtest — "Getting silver burn doesn't elicit any
  reaction from the player. Not even an audio cue." The existing notice-log
  line and halo were not noticed; silver weapon hits had no notice at all.
Must remain untouched: burn onset/severity curve, Java damage factor, regen
  gating, weapon damage multiplier, WolfVoice pain barks.
Evidence still needed: in-game cue per form, warning visibility, whether the
  vanilla health icon reacts (not a mod behaviour).
```

## Implemented

- `WTAGarou.SilverCue` (Definitions): per-form cue, `VOICE` set, `COOLDOWN` 1 s,
  `WARNING_SECONDS` 3.
- `WTAGarou.Silver.announce(player, part)` (server/Silver): the one path for
  the contact scan's fresh parts and for every silver weapon hit on a Garou;
  dedicated server sends `SilverBurn`, otherwise calls `SilverReact` directly.
- `WTAGarou.SilverReact(player, part)` (client): notice, `HUD:flashSilverBurn`
  (red line), halo, then the cue: `player:playerVoiceSound("PainFromScratch")`
  for Homid/Glabro (native volume), `WTAGarou.Audio.play` growls for
  Crinos/Hispo/Lupus (slider x 75% cap). Rate-limited per player.
- MP caveat: the cue is played on the owner's client only; remote players do
  not hear it (no networked sound added).

## Static verification

Lua suite green: rage_engine_test (announce from scan and weapon hits, cue
table), vehicle_shift_test (client reaction per form, cooldown, server
command), channel_hud_test (warning line). Not in-game evidence.

## Smallest in-game test

Full restart; banners `Definitions loaded - version 0.4.41` and
`[WTAGarou Java] 0.4.41 loaded`. Homid: hold a silver knife bare-handed for
1 s → ouch voice, red `SILVER BURN: Hand R` on the panel, halo. Shift to
Lupus/Hispo/Crinos with a silver necklace on → one growl per fresh part.
Have a tester hit you with a silver weapon: a growl per second at most.
