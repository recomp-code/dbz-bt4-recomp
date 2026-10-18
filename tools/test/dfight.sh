#!/bin/bash
# ./dfight.sh [url] : boot -> skip intro -> title -> New game (no save) -> Duel -> 1P Simple -> fight
# Snapshots go to dctl/f_*.png
cd "$(dirname "$0")"
./dstart.sh "${1:-http://localhost:8091/?online=0&scale=1&fsr=1&fps=auto}"
./dwait.sh run:threads 200 || exit 1
S=$PWD/dctl
step() { sleep "$1"; shift; ./dc.sh "$@" > /dev/null; }
step 50 "key Enter"                       # skip intro video
step 12 "snap $S/f_01_title.png" "key Enter"
step 6 "snap $S/f_02_menu.png" "key KeyX"  # Nueva Partida
step 6 "key KeyX"                          # create save? No
step 6 "key ArrowLeft" "key KeyX"          # start without saving? Si
step 9 "snap $S/f_03_main.png" "key ArrowDown" "key ArrowDown" "key ArrowDown" "key KeyX"   # Duelo
step 8 "key KeyX"                          # 1 Jugador
step 8 "key KeyX"                          # Simple
step 10 "snap $S/f_04_select.png"
for i in 1 2 3 4 5 6 7 8; do step 5 "key KeyX"; done
# MAPR=<n>: ArrowRight presses at the map screen (stage choice)
for k in $(seq 1 ${MAPR:-0}); do step 1 "key ArrowRight"; done
step 3 "snap $S/f_05_map.png" "key KeyX"
step 25 "snap $S/f_06_fight.png"
step 10 "snap $S/f_07_fight.png"
echo done
