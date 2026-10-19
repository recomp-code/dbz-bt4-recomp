#!/bin/bash
# lshot.sh <name> : ask the PCSX2 GS host (live mode) for its own rendered frame -> ~/NBAStreetRecomp/dbz/shots/<name>.png
D=~/NBAStreetRecomp/dbz/native/shot
rm -f $D/$1.png; echo "$1.png" > $D/host.req
for i in $(seq 1 100); do [ -s $D/$1.png ] && break; sleep 0.1; done
sleep 0.3
[ -s $D/$1.png ] && mv $D/$1.png ~/NBAStreetRecomp/dbz/shots/$1.png && echo "saved $1.png" || echo "no shot"
