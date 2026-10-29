import sys, numpy as np
S=sys.argv[1]; sr=48000
lines=[l.split() for l in open(S+"/kd/steps.log") if l[:1].isdigit()]
x=np.fromfile(S+"/kd/audio.raw",dtype=np.float32)[::2]
blk=480
r=np.array([np.sqrt(np.mean(x[i:i+blk]**2)) for i in range(0,len(x)-blk,blk)])
nz=np.nonzero(r>0.01)[0]; start=nz[0]*blk/sr
t_play=float([l for l in lines if l[1]=='monitor_play'][0][0])
def lab(t):
    cur='?'
    for l in lines:
        if float(l[0])-t_play<=t: cur=l[1]
    return cur
win=12000
for t0 in np.arange(start, len(x)/sr-0.5, 0.5):
    i=int(t0*sr); seg=x[i:i+win]
    rr=r[i//blk:(i+win)//blk]; med=np.median(rr)
    drops=int((rr<0.2*med).sum()) if med>0.01 else -1
    sp=np.abs(np.fft.rfft(seg*np.hanning(len(seg)))); sp[:20]=0
    idx=np.argsort(sp)[::-1]; pk=[]
    for k in idx:
        if sp[k]<0.2*sp.max(): break
        f=int(round(k*sr/len(seg)))
        if all(abs(f-q)>30 for q in pk): pk.append(f)
        if len(pk)>=4: break
    print("%6.1fs %-22s rms %.3f drops %3d peaks %s"%(t0-start, lab(t0-start), float(np.sqrt(np.mean(seg**2))), drops, "/".join(map(str,pk))))
