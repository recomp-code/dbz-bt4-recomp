#!/bin/bash
# lburst.sh <tag> <start s> <count> : live story fight, a shot every ~0.5 s from <start> s after fight state 0x8 -> shots/burst_<tag>_NN.png
L=~/NBAStreetRecomp/dbz/logs/bt3mod_run.log
PS2X_HOST_NOACTIVATE=1 PS2X_NO_GAMEPAD=1 PS2X_AUTOSTART=1 bash ~/NBAStreetRecomp/dbz/native/lrun.sh >/dev/null
until grep -aq "bt3state\] 0x7" $L; do sleep 0.2; done
until grep -aq "bt3state\] 0x8" $L; do sleep 0.1; done
sleep $2
for i in $(seq -w 1 $3); do bash ~/NBAStreetRecomp/dbz/native/lshot.sh burst_$1_$i >/dev/null; done
bash ~/NBAStreetRecomp/dbz/native/stop.sh >/dev/null
