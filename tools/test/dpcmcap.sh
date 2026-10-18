#!/bin/bash
cd "$(dirname "$0")"
./dc.sh "eval (()=>{const p=Module._ps2xDbzPcmCap();const n=new Uint32Array(HEAPU8.buffer,p,1)[0];const b=new Uint8Array(HEAPU8.buffer,p+4,n*2).slice();let s='';for(let i=0;i<b.length;i+=8192)s+=String.fromCharCode.apply(null,b.subarray(i,i+8192));return btoa(s)})()" >/dev/null
python3 - "$1" <<'PY'
import json,base64,sys,numpy as np
line=[l for l in open('dctl/result.txt') if l.strip().split(' ',1)[1].startswith('"')][-1]
a=np.frombuffer(base64.b64decode(json.loads(line.strip().split(' ',1)[1])),dtype=np.int16)
np.save(sys.argv[1]+'.npy',a); print(sys.argv[1],len(a))
PY
