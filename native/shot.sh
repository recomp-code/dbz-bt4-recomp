#!/bin/bash
# shot.sh <name> : ask the runner for the composited window -> ~/NBAStreetRecomp/dbz/shots/<name>.png
D=~/NBAStreetRecomp/dbz/native/shot
rm -f $D/shot.png; touch $D/shot.req
for i in $(seq 1 100); do [ -f $D/shot.png ] && break; sleep 0.1; done
[ -f $D/shot.png ] && mv $D/shot.png ~/NBAStreetRecomp/dbz/shots/$1.png && echo "saved $1.png" || echo "no shot"
