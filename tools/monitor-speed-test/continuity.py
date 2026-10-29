# continuity.py <source.wav> <output float32 stereo raw> <speed> [t0_s] [t1_s]  (times from the first sound)
# For each 20 ms output block, finds where it sits in the source resampled by `speed` (noise source:
# sharp correlation). Prints jumps: + = skipped audio, - = repeated/overlapping audio.
import sys, wave, numpy as np
from numpy.fft import rfft, irfft
src_w = wave.open(sys.argv[1]); sr = src_w.getframerate()
src = np.frombuffer(src_w.readframes(src_w.getnframes()), np.int16).reshape(-1, src_w.getnchannels())[:, 0] / 32768.0
out = np.fromfile(sys.argv[2], np.float32)[::2]
speed = float(sys.argv[3]); t0 = float(sys.argv[4]) if len(sys.argv) > 4 else 0.3
t1 = float(sys.argv[5]) if len(sys.argv) > 5 else t0 + 12
if speed < 0: src = src[::-1]
ref = np.interp(np.arange(0, len(src) - 1, abs(speed)), np.arange(len(src)), src)
nz = np.nonzero(np.abs(out) > 1e-3)[0]; out = out[nz[0] + int(t0 * sr):]
blk = 960

def search(b, lo, hi):
    lo = max(0, lo); hi = min(len(ref), hi + blk)
    seg = ref[lo:hi]; N = 1 << int(np.ceil(np.log2(len(seg) + blk)))
    c = irfft(rfft(seg, N) * np.conj(rfft(b, N)), N)[:len(seg) - blk]
    k = int(np.argmax(c))
    return lo + k, c[k] / (np.linalg.norm(b) * np.linalg.norm(seg[k:k + blk]) + 1e-9)

events = []; prev = None; n = 0; bad = 0; qs = []
for i in range(0, min(len(out), int((t1 - t0) * sr)) - blk, blk):
    b = out[i:i + blk]
    if np.sqrt(np.mean(b ** 2)) < 1e-3:
        events.append((t0 + i / sr, 'silence')); continue
    n += 1
    if prev is not None:
        k, q = search(b, prev - sr, prev + sr)   # +-1 s of sped-up audio around the expected place
    if prev is None or q < 0.5:
        k, q = search(b, 0, len(ref))
    qs.append(q)
    if q < 0.5:
        bad += 1; events.append((t0 + i / sr, 'nomatch q=%.2f' % q)); prev = None; continue
    if prev is not None and abs(k - prev - blk) > 2:
        d = k - prev - blk
        events.append((t0 + i / sr, 'jump %+d samples (%+.1f ms)' % (d, d / sr * 1000)))
    prev = k
print('blocks %d, no-match %d, events %d, median q %.2f' % (n, bad, len(events), float(np.median(qs)) if qs else 0))
for t, e in events[:30]:
    print('  %6.2fs %s' % (t, e))
