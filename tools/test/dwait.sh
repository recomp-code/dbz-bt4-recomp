#!/bin/bash
# ./dwait.sh <pattern> [timeout s]: waits until the session's game.log matches
cd "$(dirname "$0")"; t=0; lim=${2:-120}
until grep -q "$1" dctl/game.log 2>/dev/null; do sleep 2; t=$((t+2)); [ $t -ge $lim ] && { echo timeout; exit 1; }; done; echo found
