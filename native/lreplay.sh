#!/bin/bash
# lreplay.sh <dump name> <frames a-b> <variant>... : replay ~/NBAStreetRecomp/dbz/gsdump/<dump>.gs in pcsx2-gsrunner with
# gshost-dbz/test/<variant>.ini (screenshots at internal resolution) -> dbz/gsdump/out/<variant>/<dump>_frameN.png
G=~/NBAStreetRecomp/gshost-dbz; O=~/NBAStreetRecomp/dbz/gsdump/out
dump=$1; frames=$2; shift 2
for v in "$@"; do
  mkdir -p $O/$v; mkdir -p $O/$v
  sed 's/^ScreenshotSize = .*/ScreenshotSize = 1/' $G/test/$v.ini > $G/test/_replay_$v.ini
  (cd $G && PS2X_DUMP_FRAMES=$frames nice -n 5 ./pcsx2-gsrunner -ini $G/test/_replay_$v.ini -dumpdir $O/$v ~/NBAStreetRecomp/dbz/gsdump/$dump.gs > $O/$v.log 2>&1)
  echo "$v: $(ls $O/$v | wc -l) frames"
done
