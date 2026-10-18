#!/bin/bash
# Re-runs the recompiler into a temp dir and copies only changed files into the runner dir
# (keeps ninja incremental). Usage: tools/recomp.sh
set -e
D=~/NBAStreetRecomp/dbz; R=~/NBAStreetRecomp/PS2Recomp-dbz/ps2xRuntime
T=$D/recomp_out; rm -rf $T; mkdir -p $T
sed "s|^output = .*|output = \"$T\"|" $D/config/config.toml > $D/config/config_tmp.toml
nice -n 19 ~/NBAStreetRecomp/PS2Recomp-dbz/out/build-tools/ps2xRecomp/ps2_recomp $D/config/config_tmp.toml > $D/recomp.log 2>&1
tail -2 $D/recomp.log
n=0
for f in $T/*.cpp; do b=$(basename $f); if ! cmp -s $f $R/src/runner/$b; then cp $f $R/src/runner/$b; n=$((n+1)); fi; done
for h in ps2_recompiled_functions.h ps2_recompiled_stubs.h; do cmp -s $T/$h $R/include/$h || { cp $T/$h $R/include/$h; echo "header $h changed"; }; done
# generated files that no longer exist
for f in $R/src/runner/*_0x*.cpp; do b=$(basename $f); [ -f $T/$b ] || { rm $f; echo "removed $b"; }; done
echo "changed files: $n"
