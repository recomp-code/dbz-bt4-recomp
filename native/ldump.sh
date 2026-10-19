#!/bin/bash
# ldump.sh <name> [secs after fight state 0x8, default 10] : live run (PS2X_AUTOSTART story fight) that also records the
# GS stream as a PCSX2 dump, cut at that moment -> ~/NBAStreetRecomp/dbz/gsdump/<name>.gs (replay: lreplay.sh)
L=~/NBAStreetRecomp/dbz/logs/bt3mod_run.log
D=~/NBAStreetRecomp/dbz/gsdump; rm -f $D/$1.gs $D/$1.cut
PS2X_GS_DUMP=$D/$1.gs PS2X_GS_DUMP_UNTIL=$D/$1.cut PS2X_HOST_NOACTIVATE=1 PS2X_NO_GAMEPAD=1 PS2X_AUTOSTART=1 bash ~/NBAStreetRecomp/dbz/native/lrun.sh >/dev/null
until grep -aq "bt3state\] 0x7" $L; do sleep 0.2; done
until grep -aq "bt3state\] 0x8" $L; do sleep 0.1; done
sleep ${2:-10}
touch $D/$1.cut
until grep -aq "closing dump" $L; do sleep 0.2; done
bash ~/NBAStreetRecomp/dbz/native/lshot.sh live_dump_$1 >/dev/null
grep -a "closing dump" $L
bash ~/NBAStreetRecomp/dbz/native/stop.sh >/dev/null
ls -la $D/$1.gs
