#!/bin/bash
# dramdump.sh <out.bin>: EE RAM (32 MB) of the running session
cd "$(dirname "$0")"; rm -f "$1"
for i in 0 1 2 3 4 5 6 7; do
./dc.sh "eval (()=>{const b=Module._ps2xDbzRam()+$i*4194304;const u=new Uint8Array(HEAPU8.buffer,b,4194304);let s='';for(let k=0;k<u.length;k+=8192)s+=String.fromCharCode.apply(null,u.subarray(k,k+8192));return btoa(s)})()" > /dev/null
python3 -c "
import json,base64,sys; l=[x for x in open('dctl/result.txt') if x.strip().split(' ',1)[1].startswith('\"')][-1]
open('$1','ab').write(base64.b64decode(json.loads(l.strip().split(' ',1)[1])))"
done
ls -la "$1"
