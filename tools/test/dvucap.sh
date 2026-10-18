#!/bin/bash
# ./dvucap.sh <tbpLo hex> <tbpHi hex> <out file>: arm the VU1 capture and save its text
cd "$(dirname "$0")"
./dc.sh "eval Module._ps2xVuCapArm(0x$1,0x$2)" > /dev/null
for i in $(seq 1 30); do
  ./dc.sh "eval (()=>{const s=UTF8ToString(Module._ps2xVuCap());return s.length})()" > /dev/null
  n=$(tail -1 dctl/result.txt | awk '{print $2}')
  [ "$n" != "7" ] && break; sleep 1
done
./dc.sh "eval UTF8ToString(Module._ps2xVuCap())" > /dev/null
python3 -c "
import json; l=[x for x in open('dctl/result.txt') if x.strip().split(' ',1)[1].startswith('"')][-1]
s=json.loads(l.strip().split(' ',1)[1]); open('$3','w').write(s); print(len(s))"
