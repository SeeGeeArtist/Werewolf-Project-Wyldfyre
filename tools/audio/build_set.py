#!/usr/bin/env python3
"""Build the WTAGarou creature sound set from the 2026-10-24 recording session.

    python3 tools/audio/build_set.py <session_dir> <out_dir>

session_dir holds the raw stereo WAVs (rec20261024.zip: left = high gain,
right = low-gain safety, about 19 dB under the left). Every entry in CUTS
is (output file, source WAV, start s, end s, options); the composites
follow. Outputs are 48 kHz mono Vorbis q5 named exactly like the files
they replace. The cut list is the provenance record: everything here is
the author's own voice and foley.

v2 (second pass after the author's playtest): NO pitch or time
processing, no saturation, no synthetic layers in the voice. Each cut is
the cleanest channel (left unless it is within 3 dB of full scale, then
the right safety channel AS RECORDED, never scaled past unity), trimmed
to the performance, high-passed, lightly de-noised, gently compressed, a
touch of real room where the Crinos voice needs it, and brought to the
target loudness with a linear (static) gain. Peaks stay at or under
-2 dBTP, so the game's volume stage cannot add distortion.

v3 (third pass, author's notes on the v2 set): the voice gets its size
back the way post houses do it - a formant shift (bigger throat) a bit
larger than the pitch shift, a low shelf and a quiet sub-octave layer -
but NO room: Project Zomboid adds its own environment. Barks come from
take 01's quick roars, growls from the take-08 timestamps the author
called out, the howl is the natural wolf howl at 2:10 with a de-resonator,
the countdown is longer and faster-breathing, the bed is slower, lower
and skin-muffled with slowed snaps near the end. Lupus bark and the
footsteps are the author's own edits in the repo and are NOT rebuilt.
"""
import sys, os, json, subprocess, numpy as np
from scipy.io import wavfile
from scipy import signal

sr = 48000
HERE = os.path.dirname(os.path.abspath(__file__))
SESSION, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
TMP = os.path.join(OUT, '_raw'); os.makedirs(TMP, exist_ok=True)

_cache = {}
def load(name):
    if name not in _cache:
        p = os.path.join(SESSION, name)
        raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', p, '-f', 'f32le', '-ac', '2', '-ar', str(sr), '-'],
                             capture_output=True, check=True).stdout
        _cache[name] = np.frombuffer(raw, dtype=np.float32).reshape(-1, 2)
    return _cache[name]

def cut(name, s, e, fade=0.01, trim=True, prefer_right=False):
    """Mono float clip, peak-normalised to 0.9. Right channel when the left is hot."""
    x = load(name); a, b = int(s * sr), int(e * sr)
    L, R = x[a:b, 0], x[a:b, 1]
    y = (R if (prefer_right or np.abs(L).max() > 0.7) else L).astype(np.float64).copy()
    if trim:                      # drop leading/trailing room below peak - 38 dB, keep 40 ms of air
        hop = int(0.01 * sr); n = len(y) // hop
        env = np.sqrt((y[:n * hop].reshape(n, hop) ** 2).mean(1))
        thr = env.max() * 10 ** (-38 / 20); idx = np.where(env > thr)[0]
        if len(idx):
            a2 = max(0, (idx[0] - 4) * hop); b2 = min(len(y), (idx[-1] + 8) * hop); y = y[a2:b2]
    y /= (np.abs(y).max() + 1e-9); y *= 0.9
    n = int(fade * sr)
    if n > 0:
        y[:n] *= np.linspace(0, 1, n); y[-n:] *= np.linspace(1, 0, n)
    return y

def fade_out(y, seconds, curve=1.0):
    n = min(len(y), int(seconds * sr)); y[-n:] *= np.linspace(1, 0, n) ** curve; return y

def fade_in(y, seconds, curve=1.0):
    n = min(len(y), int(seconds * sr)); y[:n] *= np.linspace(0, 1, n) ** curve; return y

def place(canvas, y, at, gain=1.0):
    a = int(at * sr); b = min(len(canvas), a + len(y)); canvas[a:b] += y[:b - a] * gain

def room_ir(seconds, lowpass, decay, seed=5, predelay=0.012):
    rng = np.random.default_rng(seed); n = int(sr * seconds)
    ir = rng.normal(0, 1, n) * np.exp(-np.arange(n) / (sr * decay))
    b, a = signal.butter(2, lowpass, 'low', fs=sr); ir = signal.lfilter(b, a, ir)
    ir[:int(sr * predelay)] = 0
    return ir / np.sqrt((ir ** 2).sum())

def reverb(y, wet, seconds=1.2, lowpass=3000, decay=0.35, echoes=()):
    """Dry + convolution tail (energy-normalised) + optional discrete echoes (delay s, gain)."""
    w = signal.fftconvolve(y, room_ir(seconds, lowpass, decay))
    out = np.zeros(len(w)); out[:len(y)] += y * (1 - wet * 0.5); out += w * wet
    for d, g in echoes:
        k = int(d * sr); out[k:k + len(y)] += y * g
    return out

def write(path, y):
    wavfile.write(path, sr, np.clip(y, -1, 1).astype(np.float32))

def measure(path):
    r = subprocess.run(['ffmpeg', '-v', 'info', '-i', path, '-af', 'loudnorm=print_format=json', '-f', 'null', '-'],
                       capture_output=True, text=True).stderr
    return json.loads(r[r.rindex('{'):r.rindex('}') + 1])

def rubber(src, dst, pitch_st=0.0, tempo=1.0, formant='shifted', extra=''):
    af = (f"rubberband=pitch={2 ** (pitch_st / 12):.5f}:tempo={tempo}:formant={formant}:"
          f"pitchq=quality:transients=crisp" + (',' + extra if extra else ''))
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', src, '-af', af, dst], check=True)

def voice_fx(y, tag, formant=-5, pitch=-3, sub=0.18, shelf=4.0):
    """Bigger throat: formants down `formant` st, pitch down `pitch` st (two
    rubberband passes: shift both, then move the pitch back with formants
    preserved), low shelf, and a quiet sub-octave layer below 220 Hz."""
    a = os.path.join(TMP, f'{tag}_in.wav'); b = os.path.join(TMP, f'{tag}_f.wav'); c = os.path.join(TMP, f'{tag}_p.wav')
    write(a, y)
    rubber(a, b, formant, formant='shifted')
    rubber(b, c, pitch - formant, formant='preserved', extra=f"lowshelf=f=200:g={shelf}:width_type=q:width=0.7")
    _, main = wavfile.read(c); main = main.astype(np.float64) / 32767 if main.dtype == np.int16 else main.astype(np.float64)
    if sub > 0:
        d = os.path.join(TMP, f'{tag}_s.wav')
        rubber(a, d, -12, formant='shifted', extra='lowpass=f=220:poles=2')
        _, low = wavfile.read(d); low = low.astype(np.float64) / 32767 if low.dtype == np.int16 else low.astype(np.float64)
        n = min(len(main), len(low)); main = main[:n] + sub * low[:n] / (np.abs(low).max() + 1e-9) * np.abs(main).max()
    return main / (np.abs(main).max() + 1e-9) * 0.9

def deresonate(y, thresh_db=5.0, ratio=3.0, smooth_bins=24, attack=0.6):
    """Dynamic EQ: per STFT frame, cut bins that poke more than `thresh_db`
    above the frame's smoothed spectral envelope (resonator peaks that ride
    the pitch slide), with a little temporal smoothing."""
    f, t, Z = signal.stft(y, sr, nperseg=2048, noverlap=1536)
    mag = np.abs(Z) + 1e-9; logm = 20 * np.log10(mag)
    k = np.ones(smooth_bins) / smooth_bins
    env = np.apply_along_axis(lambda c: np.convolve(c, k, 'same'), 0, logm)
    excess = np.maximum(0, logm - env - thresh_db)
    cut = excess * (1 - 1 / ratio)
    for i in range(1, cut.shape[1]):                    # smooth over time
        cut[:, i] = np.maximum(cut[:, i], cut[:, i - 1] * attack)
    _, out = signal.istft(Z * 10 ** (-cut / 20), sr, nperseg=2048, noverlap=1536)
    return out[:len(y)]

def encode(y, out_name, lufs, hp=60, denoise=-40, comp=True, tp=-2.0, limit=True):
    """Clean chain, then a STATIC gain to the target loudness and a transparent
    peak limiter at `tp` (or, with limit=False, a gain that keeps peaks under
    `tp` even if the target is not reached). Clips too short to measure are
    peak-normalised to `tp`. Vorbis q5 mono."""
    raw = os.path.join(TMP, out_name.replace('.ogg', '.wav')); write(raw, y)
    pre = f"highpass=f={hp}:poles=2,afftdn=nf={denoise}:nr=8"
    if comp: pre += ",acompressor=threshold=-14dB:ratio=2:attack=12:release=160:makeup=1"
    mid = os.path.join(TMP, out_name.replace('.ogg', '_pre.wav'))
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', raw, '-af', pre, '-ar', str(sr), '-ac', '1', mid], check=True)
    m = measure(mid)
    i_in, tp_in = float(m['input_i']), float(m['input_tp'])
    if not np.isfinite(i_in):
        gain = tp - tp_in                                  # too short for LUFS: peak-normalise
    else:
        gain = lufs - i_in
        if not limit: gain = min(gain, tp - tp_in)
    af = f"volume={gain:.2f}dB"
    if limit and np.isfinite(i_in) and tp_in + gain > tp:
        af += f",alimiter=limit={10 ** (tp / 20):.3f}:attack=3:release=80:level=false"
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', mid, '-af', af + ',aresample=48000',
                    '-c:a', 'libvorbis', '-q:a', '5', os.path.join(OUT, out_name)], check=True)
    print('wrote', out_name)

RB1 = "crinos roar bark 01.wav"; RB8 = "crinos roar bark 08.wav"; RB7 = "crinos roar bark 07.wav"
SH = "crinos shift 01.wav"; SS = "crinos shift start 01.wav"; WS = "wolf shift start voice 01.wav"
BB = "crinos breathing bed 01.wav"; HB = "hispo bark 02.wav"; LB = "lupus bark 01.wav"; HG = "hispo growl 01.wav"
HOWL = "howl 01 (yes that's me howling).wav"; FS = "foley fsteps 01.wav"
FB = "foley formshift channel bed & impacts 01.wav"; BC = "foley bone cracks 01.wav"

CRINOS = dict(formant=-5, pitch=-3, sub=0.18, shelf=4.0)     # the fanged muskox
HISPO  = dict(formant=-3, pitch=-2, sub=0.10, shelf=3.0)     # big, but a wolf

# --- single takes: (out, source, start, end, target LUFS, high-pass Hz, voice fx or None)
CUTS = [
 # Crinos roar barks: take 01's quick roars (the author's call; "02-06" are copies of 01).
 # The author re-processes these in Audacity; the script's versions are the fallback.
 ("WTAGarou_Crinos_Roar_Bark.ogg",    RB1,  44.24,  45.30, -14, 50, CRINOS),
 ("WTAGarou_Crinos_Roar_Bark_02.ogg", RB1,  39.55,  40.69, -14, 50, CRINOS),
 ("WTAGarou_Crinos_Roar_Bark_03.ogg", RB1,  55.62,  56.94, -14, 50, CRINOS),
 # (0.4.87: three barks are enough - _04.._07 dropped; the take-07 long roar was 1:16.02-1:18.40)
 # Growl: take 08 at 3:05 (the author's pick)
 ("WTAGarou_Crinos_Growl.ogg",        RB8, 185.30, 187.60, -16, 50, CRINOS),
 # Crinos channel voice: strained breath into a growl, full take (the client fades it on channel end)
 ("WTAGarou_Crinos_Shift-Start.ogg",  SS,   63.98,  65.80, -16, 50, CRINOS),
 # Hispo barks: take 08 at 1:53 and the two warmed-up barks the author flagged as Hispo
 ("WTAGarou_Hispo_Bark_01.ogg",       RB8, 113.59, 114.10, -15, 70, HISPO),
 ("WTAGarou_Hispo_Bark_02.ogg",       RB8,  59.18,  59.82, -15, 70, HISPO),
 ("WTAGarou_Hispo_Bark_03.ogg",       RB8,  65.96,  66.63, -15, 70, HISPO),
 # Hispo growl: take 08 at 4:08 (the author's pick)
 ("WTAGarou_Hispo_Growl_01.ogg",      RB8, 248.10, 250.55, -16, 70, HISPO),
]
for out, src, s, e, lufs, hp, fx in CUTS:
    y = cut(src, s, e)
    if fx: y = voice_fx(y, out[:-4], **fx)
    encode(y, out, lufs, hp=hp)

# --- Shift completion: 700 ms less build, straight into the roar (shift 01 @ 85.3 s), bone cracks low under
#     the build, the roar DRY, then a quiet distant howl (the deep take) trailing off down the well.
roar = cut(SH, 85.34, 88.00, 0.02); roar = fade_out(roar, 0.4); roar = voice_fx(roar, 'shift_roar', **CRINOS)
cracks = cut(BC, 141.0, 142.6, 0.01); cracks *= 0.18
tail = cut(HOWL, 600.5, 603.8, 0.05, trim=False); tail = fade_in(tail, 0.4); tail = fade_out(tail, 2.2, 1.3)
tail = reverb(tail, wet=0.7, seconds=4.0, lowpass=1400, decay=1.3, echoes=((0.23, 0.30), (0.47, 0.18), (0.71, 0.10)))
tail *= 0.07 / (np.abs(tail).max() + 1e-9)
canvas = np.zeros(int((len(roar) / sr + 4.5) * sr)); place(canvas, roar, 0); place(canvas, cracks, 0.1); place(canvas, tail, len(roar) / sr - 0.6)
encode(canvas, "WTAGarou_Crinos_Shift.ogg", -15, hp=50, comp=False)

# --- Forced-shift countdown (12.5 s): heavy Crinos breathing deep down a well. Breathing sped up 20 %
#     (pitch kept), more chest, slow fade in, slow fade out to silence.
write(os.path.join(TMP, 'breath_in.wav'), cut(BB, 50.0, 66.0, 0.1, trim=False))
rubber(os.path.join(TMP, 'breath_in.wav'), os.path.join(TMP, 'breath_fast.wav'), 0.0, tempo=1.2, extra='lowshelf=f=180:g=6:width_type=q:width=0.7')
_, breath = wavfile.read(os.path.join(TMP, 'breath_fast.wav')); breath = breath.astype(np.float64); breath /= (np.abs(breath).max() + 1e-9)
well = reverb(breath, wet=0.65, seconds=4.0, lowpass=1400, decay=1.3, echoes=((0.23, 0.30), (0.47, 0.18), (0.71, 0.10)))
well = well[:int(12.5 * sr)]
t = np.arange(len(well)) / sr
well *= np.interp(t, [0, 4.0, 8.0, 12.0, 12.5], [0, 1, 1, 0, 0])
encode(well, "WTAGarou_Crinos_Shift-Timer.ogg", -19, hp=60, comp=False, tp=-3, limit=False)

# --- Channel bed (8 s): the leaves/box crunch slowed 15 % and lowered with it, a gentle low-pass
#     ("wrapped in skin"), quick fade in/out, slowed leaf and bark snaps in the last 2.5 s.
leaves_take = cut(FB, 239.0, 249.0, 0.0, trim=False); box_take = cut(FB, 898.5, 908.5, 0.0, trim=False)
write(os.path.join(TMP, 'bed_in.wav'), leaves_take + 0.6 * box_take)
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', os.path.join(TMP, 'bed_in.wav'),
                '-af', f'asetrate={int(sr * 0.85)},aresample={sr},lowpass=f=2800:poles=1', os.path.join(TMP, 'bed_slow.wav')], check=True)
_, bed = wavfile.read(os.path.join(TMP, 'bed_slow.wav')); bed = bed.astype(np.float64)[:8 * sr]; bed /= (np.abs(bed).max() + 1e-9)
for k, (at, src_t) in enumerate([(5.6, 192.6), (6.2, 306.68), (6.8, 108.96), (7.3, 301.7)]):
    snap = cut(FB, src_t - 0.05, src_t + 0.45, 0.005)
    write(os.path.join(TMP, f'snap{k}.wav'), snap)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', os.path.join(TMP, f'snap{k}.wav'),
                    '-af', f'asetrate={int(sr * 0.7)},aresample={sr},lowpass=f=2500', os.path.join(TMP, f'snap{k}_s.wav')], check=True)
    _, sn = wavfile.read(os.path.join(TMP, f'snap{k}_s.wav')); sn = sn.astype(np.float64); sn /= (np.abs(sn).max() + 1e-9)
    place(bed, sn, at, 0.6)
bed = fade_in(bed, 0.06); bed = fade_out(bed, 0.15)
encode(bed, "WTAGarou_formshift.ogg", -24, hp=150, denoise=-34, comp=False, limit=True)

# --- Completion whoosh (1.6 s): a low, noise-based swell that lands on the author's rock-on-towel impact
rng = np.random.default_rng(11); n = int(1.6 * sr); tt = np.arange(n) / sr
noise = rng.normal(0, 1, n)
fc = np.interp(tt, [0, 0.42, 1.6], [900, 220, 90])             # the band slides DOWN as it lands
sw = np.zeros(n); blk = 480
for i in range(0, n, blk):
    b, a = signal.butter(2, [max(30, fc[i] * 0.5), fc[i] * 1.6], 'band', fs=sr)
    sw[i:i + blk] = signal.lfilter(b, a, noise[max(0, i - 4800):i + blk])[-min(blk, n - i):]
sw *= np.interp(tt, [0, 0.38, 0.5, 1.6], [0, 1, 0.5, 0]) ** 1.2
thump = np.sin(2 * np.pi * 52 * tt) * np.exp(-tt / 0.18); thump = np.roll(thump, int(0.40 * sr)); thump[:int(0.40 * sr)] = 0
imp = cut(FB, 989.64, 991.14, 0.005)
canvas = np.zeros(n); place(canvas, sw / (np.abs(sw).max() + 1e-9), 0, 0.8); place(canvas, thump, 0, 0.5); place(canvas, imp, 0.40, 0.55)
canvas = fade_out(canvas, 0.3)
encode(canvas, "WTAGarou_formshift_02.ogg", -15, hp=40, comp=False, limit=False)

# --- Howl: the natural wolf howl at 2:10 (130.6-139.0 s, right channel as recorded), a dynamic EQ to
#     tame the resonator peaks riding the slide, and only a little distance. The big deep take
#     (597-610 s) is kept as an alternate for a later Crinos/Hispo-specific howl.
h = cut(HOWL, 130.6, 139.2, 0.05); h = fade_out(h, 1.0, 1.3); h = deresonate(h)
encode(reverb(h, wet=0.12, seconds=2.0, lowpass=2500, decay=0.6), "WTAGarou_Howl.ogg", -19, hp=80, comp=False, tp=-3, limit=True)
hb = cut(HOWL, 597.2, 609.7, 0.05); hb = fade_out(hb, 1.5, 1.5); hb = deresonate(hb)
encode(reverb(hb, wet=0.12, seconds=2.0, lowpass=2500, decay=0.6), "ALT_WTAGarou_Howl_big.ogg", -19, hp=60, comp=False, tp=-3, limit=True)
