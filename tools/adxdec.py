#!/usr/bin/env python3
# adxdec.py <file.adx> <out.npy> [seconds]: reference CRI ADX (type 3) decoder -> int16 [n,ch]
import sys, struct, math, numpy as np
d=open(sys.argv[1],'rb').read()
assert d[0:2]==b'\x80\x00'
off=struct.unpack('>H',d[2:4])[0]; enc=d[4]; bs=d[5]; bits=d[6]; ch=d[7]
rate,total=struct.unpack('>II',d[8:16]); hp=struct.unpack('>H',d[16:18])[0]
secs=float(sys.argv[3]) if len(sys.argv)>3 else 30
nmax=min(total,int(rate*secs))
a=math.sqrt(2)-math.cos(2*math.pi*hp/rate); b=math.sqrt(2)-1; c=(a-math.sqrt((a+b)*(a-b)))/b
c1=int(c*8192); c2=int(c*c*-4096)
pos=off+4; spf=(bs-2)*8//bits
out=np.zeros((nmax,ch),np.int16); h1=[0]*ch; h2=[0]*ch; n=0
while n<nmax:
    for k in range(ch):
        blk=d[pos:pos+bs]; pos+=bs
        scale=struct.unpack('>H',blk[0:2])[0]+1
        for i in range(spf):
            if n+i>=nmax: break
            byte=blk[2+i//2]; nib=(byte>>4) if i%2==0 else (byte&15)
            if nib>=8: nib-=16
            s=nib*scale + ((c1*h1[k]+c2*h2[k])>>12)
            s=max(-32768,min(32767,s))
            h2[k]=h1[k]; h1[k]=s; out[n+i,k]=s
    n+=spf
np.save(sys.argv[2],out); print('rate',rate,'ch',ch,'samples',n,'coef',c1,c2)
