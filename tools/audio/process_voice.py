#!/usr/bin/env python3
"""Turn raw human creature-voice takes into the WTAGarou Crinos/Hispo set.

    python3 tools/audio/process_voice.py <preset> <in.wav> <out.ogg> [--dry]

Presets (ffmpeg filter chains, needs ffmpeg with rubberband):
  roar     Crinos roar/bark: -7 st pitch + formants down, chest sub-layer,
           saturation, short stone room.                 (Roar_Bark_*)
  growl    Crinos growl: -5 st, more sub, less saturation. (Growl, Shift-Start)
  stinger  Shift cues: -7 st, long room, slow swell.     (Shift, Shift-Timer)
  hispo    Big-dog voice: -3 st, light grit, no room.    (Hispo_Bark/Growl)
  foley    Footsteps etc.: -3 st, no grit, low thump.    (Fstep_*)
  howl     Own howl: -3 st with formants, faint sub, no grit; the room is
           added by build_set.py.                        (Howl)
  rustle   Channel bed: pine needles / leaves crunch, no pitch change,
           high-passed, cut to 8.0 s with a 50 ms fade-in; the game fades
           the end.                                      (formshift)

Every preset: declick, high-pass, trim silence at the ends, denoise,
loudness-normalise to the target, Vorbis q5 mono 48 kHz. `--dry` prints
the ffmpeg command instead of running it. Record raw takes at 48 kHz, 24
bit, mono, peaks around -12 dBFS, mouth 15-25 cm from the capsule.
"""
import subprocess, sys, shlex

PRESETS = {
  # (semitones, sub-layer gain, drive, room preset, target LUFS)
  "roar":    (-7, 0.35, 2.4, "stone",  -14),
  "growl":   (-5, 0.45, 1.6, "stone",  -16),
  "stinger": (-7, 0.40, 2.0, "hall",   -15),
  "hispo":   (-3, 0.15, 1.3, "none",   -15),
  "foley":   (-3, 0.30, 1.0, "none",   -17),
  "howl":    (-3, 0.10, 1.0, "none",   -17),
}
ROOMS = {  # aecho in_gain:out_gain:delays|gains - cheap, deterministic rooms
  "none":  None,
  "stone": "aecho=0.8:0.6:23|41|67|113:0.35|0.25|0.18|0.10",
  "hall":  "aecho=0.8:0.7:31|79|151|263|419:0.4|0.3|0.22|0.15|0.08",
}

def chain(preset):
    st, sub, drive, room, lufs = PRESETS[preset]
    ratio = 2 ** (st / 12)
    clean = ("adeclick,highpass=f=70,afftdn=nf=-32,"
             "silenceremove=start_periods=1:start_threshold=-45dB:"
             "stop_periods=1:stop_threshold=-45dB:stop_duration=0.35")
    # main voice: rubberband keeps length, shifts pitch AND formants (bigger animal)
    main = f"rubberband=pitch={ratio}:formant=shifted:pitchq=quality"
    # chest layer: an octave below the shifted voice, low-passed
    subl = f"rubberband=pitch={ratio/2}:formant=shifted,lowpass=f=260,volume={sub}"
    grit = (f"asoftclip=type=atan:threshold=0.5,volume={drive},asoftclip=type=tanh"
            if drive > 1.0 else "anull")
    parts = [f"[0:a]{clean},asplit=2[a][b]",
             f"[a]{main}[v]", f"[b]{subl}[s]",
             f"[v][s]amix=inputs=2:normalize=0,{grit}[m]"]
    tail = f"[m]{ROOMS[room]}[r]" if ROOMS[room] else "[m]anull[r]"
    parts.append(tail)
    parts.append(f"[r]acompressor=threshold=-18dB:ratio=3:attack=8:release=120,"
                 f"loudnorm=I={lufs}:TP=-1.5:LRA=9,aformat=channel_layouts=mono,"
                 f"aresample=48000[out]")
    return ";".join(parts)

def rustle_chain():
    return ("[0:a]adeclick,highpass=f=250,afftdn=nf=-35,"
            "silenceremove=start_periods=1:start_threshold=-40dB,"
            "atrim=0:8.0,afade=t=in:d=0.05,afade=t=out:st=7.95:d=0.05,"
            "loudnorm=I=-20:TP=-1.5:LRA=11,aformat=channel_layouts=mono,aresample=48000[out]")

def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) == 3 and args[0] == "rustle":
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", args[1], "-filter_complex", rustle_chain(),
               "-map", "[out]", "-c:a", "libvorbis", "-q:a", "5", args[2]]
        if "--dry" in sys.argv: print(" ".join(shlex.quote(c) for c in cmd)); return
        subprocess.run(cmd, check=True); print("wrote", args[2]); return
    if len(args) != 3 or args[0] not in PRESETS:
        print(__doc__); sys.exit(2)
    preset, src, dst = args
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", src,
           "-filter_complex", chain(preset), "-map", "[out]",
           "-c:a", "libvorbis", "-q:a", "5", dst]
    if "--dry" in sys.argv: print(" ".join(shlex.quote(c) for c in cmd)); return
    subprocess.run(cmd, check=True); print("wrote", dst)

if __name__ == "__main__":
    main()
