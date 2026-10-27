# Creature voice recording guide (Crinos / Hispo replacement set)

**Status 2026-10-24: DONE.** The session (`rec20261024.zip`, 24 WAVs, kept
off-repo) replaced all 20 files in 0.4.84; `tools/audio/build_set.py
<session_dir> <out_dir>` rebuilds the set from it and is the record of
which take went where. Alternates are in the audition pack sent to the
author. Notes for a re-record: the left (high-gain) channel clipped on
nearly every roar, so the right (safety, about -19 dB) channel was used;
the rustle/needle takes landed about 25 dB under the voice (the shipped
bed is two of them layered over the procedural bed to keep hiss down);
`crinos roar bark 02-06.wav` are byte-identical copies of `01` (the
author did not cut between takes; 01, 07 and 08 hold the material).
Second pass (0.4.85): the processing presets in `process_voice.py` were
written for an unprocessed human voice and made the resonator takes
robotic and peaky; `build_set.py` now ships the takes nearly raw (EQ,
light denoise, 2:1 compression, a touch of room, static gain, -2 dBTP).

Why: every `WTAGarou_*.ogg` except the howl and the Hispo growl was taken
from Werewolf: The Apocalypse - Earthblood, the howl from an Epidemic
Sound track, and the Hispo growl is a pitched Tame-able Wolves growl. Neither can ship
publicly (`workshop/THIRD_PARTY_ASSETS.md`, groups `earthblood` and
`epidemic-sound`). Every file below is replaced one-for-one by the same
file name, so no script or Lua changes.

Processing is done afterwards by `tools/audio/process_voice.py`, which
pitches the voice down with its formants (bigger throat), adds a chest
layer an octave lower, saturation and a room. Record a human performance;
do not try to sound low. Growl in your natural chest register and let the
chain do the size. Over-the-top is right: the chain tames, it never adds
energy that is not in the take.

## Rig

- RODE VideoMic (shotgun, battery powered) into the PC mic/line input.
  Pad: use the -10 dB setting if roars clip; high-pass switch OFF (we
  filter later). Record 48 kHz, 24-bit, mono, in Audacity or Reaper.
  Set gain so the loudest roar peaks around -6 dBFS; everything else
  lands near -12. Watch the clip light on a test roar first.
- Distance 15-25 cm, mic aimed at your mouth from slightly below or to
  the side (plosives from roars go straight forward; off-axis takes
  avoid the pops, the shotgun pattern keeps the room out).
- Resonator (the Old Yeller trick): a glass vase, large jar or lantern
  chimney held over the mouth adds a hollow body resonance. Aim the mic
  at the open end of the glass, not at your face. Try with and without.
- Reverb shield: a box or clothes basket lined with a folded duvet or
  moving blanket over the head and mic; towels on the desk under the
  mic. The aim is only to kill early reflections from the desk, monitor
  and wall; a closet full of coats works as well. Do not seal yourself
  in - breath noise between takes is cut anyway.
- Noise floor: record 5 s of room tone with your mouth shut at the
  start of the session; the denoiser uses it. PC fans off or moved.

## Take list (record 3 takes of each, keep them in one file per line)

Durations are the current files, for feel; a little longer is fine, the
chain trims silence. File names are what the replacement must be called.

| File | Length | Performance |
|---|---|---|
| `WTAGarou_Crinos_Roar_Bark.ogg` | 1.8 s | hard explosive bark from the chest, "RAH", cut short |
| `..._Roar_Bark_02.ogg` .. `_06.ogg` | 1.2-1.5 s | five different short barks/roars; vary the vowel (ah, uh, ow), one with a snarl on the end |
| `..._Roar_Bark_07.ogg` | 4.5 s | one long roar that rises then breaks into a growl (dropped 0.4.87 with _04.._06: three barks are enough) |
| `WTAGarou_Crinos_Growl.ogg` | 3.4 s | sustained low growl, teeth together, slight rise and fall |
| `WTAGarou_Crinos_Shift-Start.ogg` | 5.9 s | strained breathing turning into a growl; plays quietly under the roar, so dynamics matter more than volume |
| `WTAGarou_Crinos_Shift.ogg` | 5.8 s | the completion: pained groan building to a full roar; record separately 5-6 bone cracks (celery stalk, knuckles, wet twig) to layer |
| `WTAGarou_Crinos_Shift-Timer.ogg` | 11.3 s | the forced-change countdown: panting that gets faster, two snarls, ending in a short roar; length should stay close to 11 s |
| `WTAGarou_Crinos_Fstep_01.ogg`, `_02.ogg` | 0.56 s | foley, not voice: heel of the hand on a leather cushion, or a stomp on carpet; two different ones |
| `WTAGarou_Hispo_Bark_01.ogg` | 0.8 s | big-dog bark, "WUFF", tongue forward |
| `WTAGarou_Hispo_Growl_01.ogg` | 2.7 s | currently the Tame-able Wolves growl pitched down, which reads as a small dog. Your own: dog growl, higher and rougher than the Crinos one, processed with the `hispo` preset |
| `Wolf_Mod_Bark_01.ogg` (Lupus bark) | 0.7 s | the Freylith bark opens with a 0.3 s growl; a trimmed version (bark only) is the quick fix, or record a sharp "WUFF" and run it through `hispo` with pitch -1 |
| `WTAGarou_Howl.ogg` | 9.4 s | optional: a human howl, rising glide then a long held note with a slow fall; pitched -3 st it beats the synthesised one. Otherwise the synth stays |
| `WTAGarou_formshift.ogg` (channel bed) | 8.0 s | foley: a sustained crunch of pine needles and dry leaves, hands working a pile at a steady pace for 12+ s, no pauses. The game cuts it at the variable channel end with a 200 ms fade into the completion cue, so there is no ending to perform. `rustle` preset trims to 8 s |
| `WTAGarou_formshift_02.ogg` (completion) | 1.3 s | Earthblood too. Procedural whoosh + sub drop for now (`synth_formshift.py end`); optional: one sharp crunch/snap to layer on the impact |

Also record, once: 10 s of room tone; 10 s of continuous breathing
(used under the shift cues); a few throat clicks and lip smacks.

## Delivering

Export each line of the table as a 48 kHz 24-bit mono WAV named after
the target file (`Roar_Bark_03_take2.wav` etc.), zip them, attach. The
processing presets are `roar`, `growl`, `stinger`, `hispo`, `foley`; the
chain is deterministic so a re-take drops in without touching the rest.

## Levels (measured 2026-10-24)

The old files were wildly uneven: Crinos roars and the Hispo bark at
-9 to -11 LUFS, the howl -18, the channel cue -37 and the completion
whoosh -30 LUFS with 13 dB of unused headroom. That, not the script
`volume=`, is why the completion cue never cut through. Replacement
targets: roars -14, growls -16, shift stingers -15, completion whoosh
-14, channel rustle -20, howl -19, all at -1 to -1.5 dBTP. Script
volumes stay as they are; re-balance in game afterwards if needed.
