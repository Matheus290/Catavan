# seekan.py <ref.wav> <raw> <first> <step> <samples per fetch>: offset of each fetch vs where it should be
import sys, wave, numpy as np
w = wave.open(sys.argv[1]); ref = np.frombuffer(w.readframes(w.getnframes()), np.int16).reshape(-1, 2)[:, 0] / 32768.0
x = np.fromfile(sys.argv[2], np.float32)[::2]; first = int(sys.argv[3]); step = int(sys.argv[4]); n = int(sys.argv[5])
res = []
for i in range(len(x) // n):
    b = x[i * n:(i + 1) * n]; p = first + i * step; exp = p * 1600
    lo = max(0, exp - 9600); seg = ref[lo:exp + n + 9600]
    c = np.correlate(seg, b[:1600], 'valid'); k = int(np.argmax(c))
    q = c[k] / (np.linalg.norm(b[:1600]) * np.linalg.norm(seg[k:k + 1600]) + 1e-9)
    res.append((p, lo + k - exp, round(float(q), 2)))
print(' '.join('%d:%+d(q%.2f)' % r for r in res[:24]))
