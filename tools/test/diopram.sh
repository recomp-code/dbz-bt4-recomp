#!/bin/bash
cd "$(dirname "$0")"
./dc.sh "eval (()=>{const p=Module._ps2xDbzIopRam();const u=new Uint8Array(HEAPU8.buffer,p,2097152);let s='';for(let k=0;k<u.length;k+=8192)s+=String.fromCharCode.apply(null,u.subarray(k,k+8192));return btoa(s)})()" > /dev/null
python3 -c "
import json,base64; l=[x for x in open('dctl/result.txt') if x.strip().split(' ',1)[1].startswith('\"')][-1]
open('$1','wb').write(base64.b64decode(json.loads(l.strip().split(' ',1)[1])))"
ls -la $1
