#!/bin/bash
P=$(cat ~/NBAStreetRecomp/dbz/native/run.pid 2>/dev/null)
# live mode: the PCSX2 GS host the runtime started (its pid is in the log)
H=$(grep -a "^\[gslive\] GS host .* pid " ${LOG:-$HOME/NBAStreetRecomp/dbz/logs/bt3mod_run.log} 2>/dev/null | tail -1 | sed 's/.* pid \([0-9]*\).*/\1/')
[ -n "$P" ] && kill $P 2>/dev/null; sleep 1; kill -9 $P 2>/dev/null
if [ -n "$H" ] && ps -p $H -o comm= 2>/dev/null | grep -q pcsx2-gsrunner; then kill $H 2>/dev/null; sleep 1; kill -9 $H 2>/dev/null; fi
echo stopped $P ${H:+host $H}
