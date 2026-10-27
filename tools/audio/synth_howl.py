"""Procedural wolf howl, synthesised from scratch (no samples).
Shape follows the previous howl's contour: 0.7 s rising glide, long held
note around 480 Hz with slow vibrato, a rough chest-break around 2.4-3.5 s,
a slow fall-off that ends about 6.5 s, and a distant-room tail to 9.4 s.
One voice only; the old file's second wolf was never wanted."""
import numpy as np, sys, wave
from scipy import signal
sr = 48000
seed = int(sys.argv[1]) if len(sys.argv) > 1 else 7
pitch = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0   # 0.85 = bigger wolf
rng = np.random.default_rng(seed)
dur = 9.393; n = int(sr*dur); t = np.arange(n)/sr

def env_points(pts):
    xs, ys = zip(*pts); return np.interp(t, xs, ys)

# --- pitch contour (Hz) ---
f0 = env_points([(0.0,285),(0.25,330),(0.5,415),(0.75,462),(1.2,478),(2.0,488),
                 (2.4,492),(3.5,502),(4.0,494),(4.5,470),(5.3,478),(5.8,500),
                 (6.1,455),(6.5,425),(6.9,400)])
vib_rate = 3.6 + 0.5*np.sin(2*np.pi*0.17*t) + 0.3*np.sin(2*np.pi*0.41*t+1)
vib_depth = env_points([(0,0.0),(0.8,0.003),(1.5,0.006),(4.5,0.007),(6.5,0.011)])
jitter = signal.lfilter([1],[1,-0.999], rng.normal(0,1,n))*0.00035  # slow wander
f0 = f0*(1 + vib_depth*np.sin(2*np.pi*np.cumsum(vib_rate)/sr) + jitter)
f0 = f0*pitch
phase = 2*np.pi*np.cumsum(f0)/sr

# --- amplitude envelope ---
amp = env_points([(0.0,0),(0.15,0.02),(0.4,0.3),(0.9,0.75),(1.3,0.9),(1.9,1.0),
                  (2.3,0.8),(2.9,0.7),(3.4,0.75),(3.9,0.8),(4.3,0.95),(4.6,0.7),
                  (5.0,0.45),(5.5,0.28),(6.0,0.17),(6.4,0.09),(6.6,0.0),(dur,0)])
tremolo = 1 + 0.08*np.sin(2*np.pi*5.3*t + 1.0)*env_points([(0,0),(1,1),(6.5,1)])
amp = amp*tremolo

# --- voice source: harmonic series with chest-break roughness ---
rough = env_points([(0,0),(2.25,0),(2.45,1),(3.45,1),(3.6,0),(dur,0)])
src = np.zeros(n)
for k in range(1, 40):
    tilt = 1.0/k**1.7
    hphase = k*phase
    # subharmonic roughness: period-tripling modulation during the break
    src += tilt*np.sin(hphase) * (1 + rough*0.55*np.cos(phase/3 + 0.7*k))
# second wolf: OFF by default (one Garou howls alone). SECOND_WOLF=1 to add it.
f0b = env_points([(0.9,330),(1.1,420),(1.4,560),(2.2,588),(3.4,596),(4.2,580),(4.9,548),(5.4,520),(5.8,500)])
f0b = f0b*(1 + 0.004*np.sin(2*np.pi*np.cumsum(3.1+0.4*np.sin(2*np.pi*0.23*t))/sr) + jitter*1.3)
phb = 2*np.pi*np.cumsum(f0b*pitch)/sr
ampb = env_points([(0,0),(0.95,0),(1.3,0.25),(1.9,0.5),(3.0,0.55),(4.2,0.5),(5.0,0.3),(5.6,0.12),(5.9,0),(dur,0)])
srcb = sum(np.sin(k*phb)/k**1.9 for k in range(1,24)); srcb = srcb/np.abs(srcb).max()*ampb
breath = rng.normal(0,1,n)
src = src/np.abs(src).max()
src += 0.035*breath*env_points([(0,0.3),(0.7,1),(5,1),(6.6,1.2)])

# --- vocal tract: three resonances, dark/distant tilt ---
def peak(x, fc, q, gain):
    b,a = signal.iirpeak(fc, q, sr); return x + gain*signal.lfilter(b,a,x)
import os
v = src.copy() + (0.42*srcb if os.environ.get('SECOND_WOLF') == '1' else 0.0)
v = peak(v,  560, 3.0, 2.2)
v = peak(v,  980, 4.0, 0.8)
v = peak(v, 1650, 5.0, 0.6)
b,a = signal.butter(3, 1900, 'low', fs=sr); v = signal.lfilter(b,a,v)
b,a = signal.butter(2, 150, 'high', fs=sr);  v = signal.lfilter(b,a,v)
v = v*amp

# --- distance: early reflections + diffuse tail (synthetic IR) ---
ir_len = int(sr*3.2); ir = rng.normal(0,1,ir_len)*np.exp(-np.arange(ir_len)/(sr*0.95))
b,a = signal.butter(2, 1100, 'low', fs=sr); ir = signal.lfilter(b,a,ir)
ir[:int(sr*0.02)] = 0; ir /= np.abs(ir).max()
for d,g in [(0.031,0.5),(0.057,0.35),(0.089,0.25),(0.134,0.18)]:
    ir[int(d*sr)] += g
wet = signal.fftconvolve(v, ir)[:n]
wet /= np.abs(wet).max()+1e-9; dry = v/(np.abs(v).max()+1e-9)
out = 0.6*dry + 0.4*wet
b,a = signal.butter(2, 2400, 'low', fs=sr); out = signal.lfilter(b,a,out)
out = out/np.abs(out).max()*0.5          # match the old file's peak
print("rms", np.sqrt((out**2).mean()), "peak", np.abs(out).max())
pcm = (np.clip(out,-1,1)*32767).astype(np.int16)
name = f'howl_{seed}' + ('' if pitch==1.0 else f'_p{pitch}')
with wave.open(name+'.wav','wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr); w.writeframes(pcm.tobytes())
