#!/bin/bash
# spudump.sh <name>: from the running ctl session, fetch the SPU2 debug capture (8 s x 8 int16) -> <name>.npy
cd "$(dirname "$0")"
./dc.sh "eval (()=>{const p=Module._ps2xSpu2Dump();const b=new Uint8Array(HEAPU8.buffer,p,48000*8*16).slice();let s='';for(let i=0;i<b.length;i+=8192)s+=String.fromCharCode.apply(null,b.subarray(i,i+8192));return btoa(s)})()" >/dev/null
python3 - "$1" <<'PY'
import json,base64,sys,numpy as np
line=[l for l in open('dctl/result.txt') if l.strip().split(' ',1)[1].startswith('"')][-1]
a=np.frombuffer(base64.b64decode(json.loads(line.strip().split(' ',1)[1])),dtype=np.int16).reshape(-1,8)
np.save(sys.argv[1]+'.npy',a); print(sys.argv[1], a.shape, 'peak in0', abs(a[:,0]).max(), 'in1', abs(a[:,2]).max(), 'out', abs(a[:,4]).max())
PY
