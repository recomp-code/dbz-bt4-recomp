#!/bin/bash
# dsurvey.sh <tag> [extra url params]: fight with scripted inputs, a canvas shot every 0.5 s -> dctl/sv_<tag>_NNN.png
cd "$(dirname "$0")"
TAG=$1; EXTRA=$2
rm -f dctl/sv_${TAG}_*.png
./dfight.sh "http://localhost:8091/?online=0&scale=1&fsr=1&fps=auto$EXTRA" > /dev/null || exit 1
S=$PWD/dctl
n=0
shot() { ./dc.sh "snap $S/sv_${TAG}_$(printf %03d $n).png" > /dev/null; n=$((n+1)); }
seq_inputs=("hold KeyW 800" "key KeyZ" "key KeyZ" "key KeyZ" "key KeyZ" "hold KeyV 1200" "key KeyV" "hold ArrowUp 600" "key KeyX" "hold KeyE 400" "key KeyZ" "key KeyZ" "hold KeyS 800" "hold KeyQ 1000" "key KeyV" "key KeyV" "hold KeyD 700" "key KeyZ" "key KeyZ" "key KeyZ" "key KeyZ" "key KeyZ")
for i in $(seq 0 79); do
  in=${seq_inputs[$((i % ${#seq_inputs[@]}))]}
  ./dc.sh "$in" > /dev/null
  shot
done
echo "$n shots"
