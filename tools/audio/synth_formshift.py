"""Procedural shift cues (no samples).
  channel : 'leaves' - a sustained dry rustle/crackle bed (8.0 s, longer than
            the 6 s BASE channel; the Lua fades it out in 200 ms at channel end)
  end     : bass whoosh with a sub drop for the completed shift (1.25 s)
python3 synth_formshift.py channel out.wav | end out.wav
Mastering: channel ~ -20 LUFS, end ~ -14 LUFS, -1 dBTP (the old files sat
at -37 and -30 LUFS, which is why the completion cue was always quiet)."""
import numpy as np, sys, wave
from scipy import signal
sr = 48000; rng = np.random.default_rng(3)

def write(path, x):
    pcm = (np.clip(x, -1, 1)*32767).astype(np.int16)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr); w.writeframes(pcm.tobytes())

def leaves(dur=8.0):
    n = int(sr*dur); t = np.arange(n)/sr; out = np.zeros(n)
    # sustained: settles in over 0.4 s, then wanders between 90 and 150 grains/s
    density = np.interp(t, [0, 0.4, 1.5, 3.0, 4.5, 6.0, 7.5, 8.0], [30, 110, 140, 95, 150, 105, 135, 120])
    p = density/sr
    hits = np.nonzero(rng.random(n) < p)[0]
    for h in hits:
        L = int(sr*rng.uniform(0.004, 0.018)); g = rng.normal(0, 1, L)*np.hanning(L)
        fc = rng.uniform(1800, 6500); b, a = signal.butter(2, [fc*0.6, min(fc*1.5, 20000)], 'band', fs=sr)
        g = signal.lfilter(b, a, g)*rng.uniform(0.3, 1.0)
        e = min(L, n-h); out[h:h+e] += g[:e]
    bed = rng.normal(0, 1, n); b, a = signal.butter(2, [900, 4000], 'band', fs=sr)
    bed = signal.lfilter(b, a, bed)*np.interp(t, [0, 0.5, dur], [0.0, 0.10, 0.12])
    out = out/np.abs(out).max()*0.7 + bed
    out *= np.interp(t, [0, 0.05, dur-0.05, dur], [0, 1, 1, 0])   # no tail: the Lua fade does the ending
    return out

def whoosh(dur=1.25):
    n = int(sr*dur); t = np.arange(n)/sr
    noise = rng.normal(0, 1, n)
    # sweeping band-pass: rises then dives, the "air" of the whoosh
    fc = np.interp(t, [0, 0.25, 0.45, 1.25], [300, 2600, 900, 120])
    out = np.zeros(n); blk = 256
    for i in range(0, n-blk, blk):
        b, a = signal.butter(2, [fc[i]*0.7, fc[i]*1.4], 'band', fs=sr)
        out[i:i+blk] = signal.lfilter(b, a, noise[max(0, i-2048):i+blk])[-blk:]
    air_env = np.interp(t, [0, 0.2, 0.42, 0.9, 1.25], [0, 0.6, 1.0, 0.25, 0])
    out = out/np.abs(out).max()*air_env
    # sub drop: 95 -> 38 Hz sine landing at the impact point
    f_sub = np.interp(t, [0, 0.4, 0.42, 1.25], [95, 95, 70, 38])
    ph = 2*np.pi*np.cumsum(f_sub)/sr
    sub = np.sin(ph)*np.interp(t, [0, 0.3, 0.42, 0.47, 1.1, 1.25], [0, 0.15, 0.3, 1.0, 0.35, 0])
    sub = np.tanh(1.6*sub)
    # impact thud + fur/body texture at the landing
    thud = rng.normal(0, 1, n); b, a = signal.butter(2, 180, 'low', fs=sr); thud = signal.lfilter(b, a, thud)
    thud *= np.exp(-np.clip(t-0.42, 0, None)*18)*(t >= 0.42)
    return 0.55*out + 0.8*sub + 0.5*thud/np.abs(thud).max()

kind, path = sys.argv[1], sys.argv[2]
x = leaves() if kind == 'channel' else whoosh()
write(path, x/np.abs(x).max()*0.9)
