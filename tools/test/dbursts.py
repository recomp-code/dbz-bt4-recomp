#!/usr/bin/env python3
# dbursts.py <spudump.npy> <ref.npy> <offset s> [seconds]: exact-match check of core0 input vs gain*mid(ref)
import sys, numpy as np
a=np.load(sys.argv[1]).astype(np.float64); ref=np.load(sys.argv[2]).astype(np.float64)
start=int(round(float(sys.argv[3])*48000)); T=float(sys.argv[4]) if len(sys.argv)>4 else 5.5
g=a[:int(T*48000),0]; r=(ref[start:start+len(g),0]+ref[start:start+len(g),1])/2
gg=(g@r)/(r@r); e=g-gg*r
bad=np.flatnonzero(np.abs(e)>40); groups=[]
for i in bad:
    if groups and i-groups[-1][1]<64: groups[-1][1]=i
    else: groups.append([i,i])
print('gain %.4f residual rms %.1f, error bursts %d'%(gg,np.sqrt((e**2).mean()),len(groups)), [(round(s/48000,3),t-s+1) for s,t in groups[:10]])
