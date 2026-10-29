import sys, numpy as np
sr=48000
for path in sys.argv[1:]:
    x=np.fromfile(path, dtype=np.float32)
    win=4800
    freqs=[]
    for i in range(0,len(x)-win+1,win):
        sp=np.abs(np.fft.rfft(x[i:i+win]*np.hanning(win)))
        sp[:int(100*win/sr)]=0
        if '_mix' in path:
            sp[int(4800*win/sr):]=0   # ignore the 5 kHz track (and its multiples) for the step frequency
        freqs.append(int(round(np.argmax(sp)*sr/win)))
    runs=[]
    for k,f in enumerate(freqs):
        if not runs or abs(runs[-1][0]-f)>20: runs.append([f,round(k*0.1,1)])
    # per 10 ms block, how many are (nearly) silent after the first 0.2 s
    blk=480
    r=[np.sqrt(np.mean(x[i:i+blk]**2)) for i in range(int(0.2*sr),len(x)-blk,blk)]
    silent=sum(1 for v in r if v<0.05)
    extra=''
    if '_mix' in path:
        # second track: 5 kHz, times the speed when the pitch follows it (file r_mix_<speed>_<preserve>)
        parts=path.split('/')[-1][:-4].split('_')
        target=5000*(float(parts[2]) if parts[3]=='0' else 1.0)
        sp=np.abs(np.fft.rfft(x[sr:sr+win]*np.hanning(win))); b=int(target*win/sr)
        extra=' 2nd track (%d Hz) present: %s'%(target, bool(np.max(sp[b-3:b+4])>0.1*np.max(sp)))
    print(path.split('/')[-1], runs[:6], 'silent 10ms blocks:', silent, 'of', len(r), extra)
