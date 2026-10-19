#!/bin/bash
# lbatch.sh name... : run lqshot.sh with gshost-dbz/test/<name>.ini for each name; summary -> dbz/logs/lbatch_<name>.txt
for n in "$@"; do
  HOLD=30 PS2X_GSHOST_ARGS="-ini $HOME/NBAStreetRecomp/gshost-dbz/test/$n.ini $HOSTEXTRA" bash ~/NBAStreetRecomp/dbz/native/lqshot.sh $n > ~/NBAStreetRecomp/dbz/logs/lbatch_$n.txt 2>&1
  sleep 3
done
echo batch done
