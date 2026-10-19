#!/bin/bash
# lqshot.sh <tag> : qshot2.sh for the live (PCSX2 GS host) build: Dragon History fight intro -> live_<tag>_[a-d].png
L=~/NBAStreetRecomp/dbz/logs/bt3mod_run.log
PS2X_HOST_NOACTIVATE=${PS2X_HOST_NOACTIVATE:-1} PS2X_NO_GAMEPAD=1 PS2X_AUTOSTART=1 bash ~/NBAStreetRecomp/dbz/native/lrun.sh >/dev/null
until grep -aq "bt3state\] 0x7" $L; do sleep 0.2; done
until grep -aq "bt3state\] 0x8" $L; do sleep 0.1; done
sleep 4
for t in ${SHOTS:-a b c d}; do
  sleep 1.5
  bash ~/NBAStreetRecomp/dbz/native/lshot.sh live_${1}_$t >/dev/null
done
if [ -n "$QUICK" ]; then bash ~/NBAStreetRecomp/dbz/native/stop.sh >/dev/null; exit 0; fi
sleep ${HOLD:-12}
bash ~/NBAStreetRecomp/dbz/native/lshot.sh live_${1}_e >/dev/null
sleep 4
bash ~/NBAStreetRecomp/dbz/native/lshot.sh live_${1}_f >/dev/null
echo "cpu% runtime/host: $(ps -o %cpu= -p $(cat ~/NBAStreetRecomp/dbz/native/run.pid)) / $(ps -o %cpu= -p $(pgrep -f 'pcsx2-gsrunner -live' | head -1))"
grep -a "^\[fps\]" $L | tail -10 | awk '{print $2}' | tr '\n' ' '; echo
grep -a "internal fps" $L | tail -8
grep -a "^\[gslive\]" $L | tail -3
[ -n "$KEEP" ] || bash ~/NBAStreetRecomp/dbz/native/stop.sh >/dev/null
