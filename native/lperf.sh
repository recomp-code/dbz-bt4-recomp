#!/bin/bash
# lperf.sh <dump> <perf frames a-b> <shot frames a-b> <variant>... : replay gsdump/<dump>.gs with gshost-dbz/test/perf/<variant>.ini,
# average GPU time over the perf frames, screenshots of the shot frames -> dbz/gsdump/perf/<variant>/ ; summary on stdout
G=~/NBAStreetRecomp/gshost-dbz; O=~/NBAStreetRecomp/dbz/gsdump/perf
dump=$1; pf=$2; sf=$3; shift 3
for v in "$@"; do
  rm -rf $O/$v; mkdir -p $O/$v
  (cd $G && PS2X_PERF_FRAMES=$pf PS2X_DUMP_FRAMES=$sf nice -n 5 ./pcsx2-gsrunner -perf -ini $G/test/perf/$v.ini -dumpdir $O/$v ~/NBAStreetRecomp/dbz/gsdump/$dump.gs > $O/$v.log 2>&1)
  echo "$v: $(grep -a 'Average GPU Time\|GPU Usage' $O/$v.log | sed 's/.*@HWSTAT@ //' | tr '\n' ' ')"
done
