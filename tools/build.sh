#!/bin/bash
# Builds the DBZ copy of Play! (GS/VU libs) and then the wasm runner.
set -e
export BINARYEN_CORES=4 EMCC_CORES=4  # wasm-opt and the LTO link otherwise take every core
cd ~/NBAStreetRecomp/dbz/play-dbz && nice -n 19 cmake --build build_wasm --target gsh_opengl Framework_OpenGl PlayCore app_shared -j4 > ~/NBAStreetRecomp/dbz/logs_play_build.txt 2>&1 || { grep -m5 -A3 "error:" ~/NBAStreetRecomp/dbz/logs_play_build.txt; exit 1; }
cd ~/NBAStreetRecomp/PS2Recomp-dbz && nice -n 19 cmake --build out/build-wasm --target ps2EntryRunner -j4 > ~/NBAStreetRecomp/dbz/wasm_build.log 2>&1 || { grep -m5 -A5 "error" ~/NBAStreetRecomp/dbz/wasm_build.log; exit 1; }
echo build ok
