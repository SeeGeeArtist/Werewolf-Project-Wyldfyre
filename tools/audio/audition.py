#!/usr/bin/env python3
"""Export alternate takes per target, processed with the same presets as the
shipped set, so the author can audition them.

    python3 tools/audio/audition.py <session_dir> <clips_dir> <out_dir>

<clips_dir> is the session analysis output: <clips_dir>/index.csv with the
columns target,file,s,e,dur,clip and one normalised WAV per row under
<clips_dir>/<target>/<clip>. The 2026-10-24 pack also carries the howl the
author called out ("that's how you howl", 484.9-502.4 s) at full length.
"""
import csv, os, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from process_voice import chain, rustle_chain

SESSION, CLIPS, OUT = sys.argv[1:4]
PRESET = {'roar_bark': 'roar', 'roar_long': 'roar', 'growl': 'growl', 'shift_complete': 'stinger',
          'shift_start': 'growl', 'wolf_shift': 'hispo', 'timer_pieces': 'stinger', 'hispo_bark': 'hispo',
          'lupus_bark': 'hispo', 'hispo_growl': 'hispo', 'howl': 'howl', 'fsteps': 'foley', 'impacts': 'foley',
          'bone_cracks': 'foley', 'mouth': 'growl', 'bed_needles': 'rustle', 'bed_leaves': 'rustle',
          'bed_bark': 'rustle', 'fabric_creak': 'foley', 'breathing': 'growl'}
rows = list(csv.DictReader(open(os.path.join(CLIPS, 'index.csv'))))
count = 0
for target, preset in PRESET.items():
    picks = [r for r in rows if r['target'] == target][:4]
    os.makedirs(os.path.join(OUT, target), exist_ok=True)
    for i, r in enumerate(picks):
        src = os.path.join(CLIPS, target, r['clip'])
        dst = os.path.join(OUT, target, f"{target}_alt{i+1}_{r['file'].split()[0]}_{float(r['s']):.0f}s_{float(r['dur']):.1f}s.ogg")
        fc = rustle_chain() if preset == 'rustle' else chain(preset)
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', src, '-filter_complex', fc, '-map', '[out]',
                        '-c:a', 'libvorbis', '-q:a', '5', dst], check=True)
        count += 1
howl = os.path.join(SESSION, "howl 01 (yes that's me howling).wav")
if os.path.exists(howl):
    fc = chain('howl').replace('[out]', '[pre];[pre]aecho=0.8:0.6:41|97|173|281:0.35|0.25|0.18|0.1[out]')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', howl, '-filter_complex',
                    '[0:a]atrim=484.9:502.4,asetpts=PTS-STARTPTS,pan=mono|c0=9.1*c1[m];[m]' + fc[5:],
                    '-map', '[out]', '-c:a', 'libvorbis', '-q:a', '5',
                    os.path.join(OUT, 'howl', 'howl_alt0_THE_ONE_484s_17.5s.ogg')], check=True)
    count += 1
print(count, 'audition files in', OUT)
