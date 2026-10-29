# Analyze the SDL disk audio output (float32 stereo interleaved, 48 kHz): stutters = 10 ms blocks much quieter
# than the median, and the main frequencies over time.
import sys, numpy as np
sr=48000
for path in sys.argv[1:]:
    x=np.fromfile(path,dtype=np.float32)[::2]; x=x[int(0.5*sr):]
    blk=480; r=np.array([np.sqrt(np.mean(x[i:i+blk]**2)) for i in range(0,len(x)-blk,blk)])
    med=np.median(r) if len(r) else 0
    win=9600; pk=[]
    for i in range(0,len(x)-win,win*3):
        sp=np.abs(np.fft.rfft(x[i:i+win]*np.hanning(win))); sp[:20]=0
        idx=np.argsort(sp)[::-1]; p=[]
        for k in idx:
            if sp[k]<0.12*sp.max(): break
            f=int(round(k*sr/win))
            if all(abs(f-q)>30 for q in p): p.append(f)
            if len(p)>=3: break
        pk.append("/".join(map(str,p)))
    print("%-22s %.1fs  drops(10ms<20%%med): %3d/%d  peaks: %s"%(path.split('/')[-1], len(x)/sr, (r<0.2*med).sum() if med>0 else -1, len(r), " ".join(pk)))
