#!/usr/bin/env python3
# dgaps.py <spudump.npy>: dropouts (zero runs) and exact repeats in the core 0 ADMA input and the output
import sys, numpy as np, collections
a=np.load(sys.argv[1]).astype(np.int32)
for name,x in (('in0',a[:,0]),('out',a[:,4])):
    act=np.abs(x)>32
    z=(x==0).astype(int); d=np.diff(np.r_[0,z,0]); st=np.flatnonzero(d==1); en=np.flatnonzero(d==-1); L=en-st
    big=[(int(s),int(l)) for s,l in zip(st,L) if l>=200 and s>0 and s+l<len(x)]
    print(f"{name}: rms {np.sqrt((x.astype(float)**2).mean()):.0f} peak {abs(x).max()} active {act.mean():.2f} zero-gaps>=200 {len(big)} {[(s/48000.0, l) for s,l in big[:8]]}")
