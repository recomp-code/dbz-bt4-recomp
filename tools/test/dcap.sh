#!/bin/bash
# cap.sh <name>: 8 s of the worklet's output from the running ctl session -> <name>.npy + analysis
cd "$(dirname "$0")"
./dc.sh "eval (async()=>{window.ps2xAudioCapture=null;ps2xAudioNode.port.postMessage('capture');for(let i=0;i<80&&!window.ps2xAudioCapture;i++)await new Promise(r=>setTimeout(r,200));const f=new Float32Array(window.ps2xAudioCapture);const b=new Uint8Array(f.buffer);let s='';for(let i=0;i<b.length;i+=8192)s+=String.fromCharCode.apply(null,b.subarray(i,i+8192));return btoa(s)})()" >/dev/null
python3 - "$1" <<'PY'
import json,base64,sys,numpy as np
line=[l for l in open('dctl/result.txt') if l.strip().split(' ',1)[1].startswith('"')][-1]
a=np.frombuffer(base64.b64decode(json.loads(line.strip().split(' ',1)[1])),dtype=np.float32)
np.save(sys.argv[1]+'.npy',a)
c=abs(a)>=0.999
runs=np.diff(np.flatnonzero(np.diff(np.r_[0,c.astype(int),0])))[::2]
spec=abs(np.fft.rfft(a*np.hanning(len(a))))**2; fr=np.fft.rfftfreq(len(a),1/48000)
band=lambda lo,hi: 10*np.log10(spec[(fr>=lo)&(fr<hi)].sum()+1e-9)
low=band(0,4000)
r=np.abs(a[2:]-2*a[1:-1]+a[:-2])
med=np.convolve(r,np.ones(256)/256,'same')
clicks=np.flatnonzero((r>0.2)&(r>10*med))
groups=len(np.unique(clicks//480)) if len(clicks) else 0
print(f"{sys.argv[1]}: peak {abs(a).max():.3f} rms {np.sqrt((a**2).mean()):.3f} clipped runs {len(runs)} clicks {groups} | 4-12k {band(4000,12000)-low:.1f} dB, 12-18k {band(12000,18000)-low:.1f} dB, 18-24k {band(18000,24000)-low:.1f} dB")
PY
