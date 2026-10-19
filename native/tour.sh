#!/bin/bash
# tour.sh <prefix> <count> <interval_s> : periodic shots named <prefix>_<i>_<state>
L=~/NBAStreetRecomp/dbz/logs/bt3mod_run.log
for i in $(seq -w 1 $2); do
  sleep $3
  st=$(grep -a "bt3state\]" $L | tail -1 | awk '{print $2"_"$3}')
  fps=$(grep -a "^\[fps\]" $L | tail -1 | awk '{print $2}')
  bash ~/NBAStreetRecomp/dbz/native/shot.sh ${1}_${i}_${st} >/dev/null
  echo "$i $st $fps"
done
