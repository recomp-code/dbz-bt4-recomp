#!/usr/bin/env python3
# dadxcmp.py <spudump.npy> <ref.npy>: align core-0 input with the reference ADX decode, SNR per 0.5 s
import sys, numpy as np
a=np.load(sys.argv[1]).astype(float); ref=np.load(sys.argv[2]).astype(float)
x=a[:,0]; r=ref[:,0]
seg=x[48000:48000*3]
n=1<<int(np.ceil(np.log2(len(r)+len(seg))))
cc=np.fft.irfft(np.fft.rfft(r,n)*np.conj(np.fft.rfft(seg,n)),n)
lag=int(np.argmax(cc)); lag=lag if lag<n//2 else lag-n; start=lag-48000; print("peak corr",cc.max()/np.sqrt((seg@seg)*(r@r)+1e-9))
print('best offset in ref (s):',start/48000.0)
L=min(len(x),len(r)-start) if start>=0 else 0
for i in range(0,L-24000,24000):
    xs=x[i:i+24000]; rs=r[start+i:start+i+24000]
    g=(xs@rs)/(rs@rs+1e-9); e=xs-g*rs
    snr=10*np.log10((xs@xs+1e-9)/(e@e+1e-9))
    print('%5.1fs gain %.3f snr %6.1f dB'%(i/48000.0,g,snr))
