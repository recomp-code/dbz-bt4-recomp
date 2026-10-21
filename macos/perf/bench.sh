#!/bin/bash
# DBZ BT4 native benchmark (Mac): the offline game the launcher starts, auto-played (PS2X_AUTOSTART) into menus and a
# fight, muted, no pad. Usage: bench.sh <name> [seconds] [ini] [runner] [gsrunner]. Logs: perf/logs/<name>.log;
# CPU per process every 5 s: perf/logs/<name>.cpu. SAMPLE_AT=<s>: macOS sample of both processes then. BENCH_ENV: extra
# variables (e.g. PS2X_PACEDIAG=1, PS2X_HITCH_MS=19). Needs $DBZ_PERF/run/: runtime/ (data -> the app data's runtime/data,
# assets -> the app's, savedata/settings.toml with master_volume = 0, a card) and gshost/ (the presets).
B=${DBZ_PERF:-$HOME/NBAStreetRecomp/dbz/perf}; A=$HOME/NBAStreetRecomp/dbz/macdist/DBZ_BT4.app/Contents
NAME=${1:-bench}; SECS=${2:-150}; INI=${3:-dbz_metalfx.ini}
R=${4:-$A/Helpers/Game.app/Contents/MacOS/ps2EntryRunner}; G=${5:-$A/MacOS/pcsx2-gsrunner}
cd $B/run/runtime
export PS2X_CD_IMAGE="/Users/miguelangel/Downloads/PS2_NTSC/SLUS_219.78.DBZBT4B14REV2.iso" PS2X_GS_LIVE=1
export PS2X_GSHOST_ARGS="-ini \"$B/run/gshost/$INI\"" PS2X_GSHOST="$G"
export PS2X_LIVE_SERIAL=SLUS-21978 PS2X_LIVE_TITLE="DBZ BT4 bench" PS2X_HOST_WINDOW=1600x900
export PS2X_HALFSTEP="$A/Resources/runtime/fps60_sites.txt" PS2X_EXEDIR="$B/run/runtime" PS2X_FPS60=1
export PS2X_HOST_NOACTIVATE=1 PS2X_NO_GAMEPAD=1 PS2X_AUTOSTART=1 PS2X_AUTOSTART_LEFT=1 PS2X_FPS_LOG=1 ${BENCH_ENV}
"$R" "$B/run/runtime/data/SLUS_216.78" > "$B/logs/$NAME.log" 2>&1 &
P=$!
: > "$B/logs/$NAME.cpu"
for ((t=0; t<SECS; t+=5)); do sleep 5
  GP=$(pgrep -f "livering $P" | head -1)
  echo "$t game=$(ps -o %cpu= -p $P | tr -d ' ') host=$(ps -o %cpu= -p ${GP:-1} 2>/dev/null | tr -d ' ')" >> "$B/logs/$NAME.cpu"
  # SAMPLE_AT=<s>: 10 s of macOS sample on both processes (call trees by thread) at that point of the run
  if [ -n "$SAMPLE_AT" ] && [ $t -eq $SAMPLE_AT ]; then
    /usr/bin/sample $P 10 -mayDie -file "$B/logs/$NAME.game.sample" >/dev/null 2>&1 &
    /usr/bin/sample ${GP:-1} 10 -mayDie -file "$B/logs/$NAME.host.sample" >/dev/null 2>&1 &
  fi
done
sleep 12 # the samples (10 s) finish on their own
kill $P; sleep 2; kill -9 $P 2>/dev/null; pkill -f "livering $P"; true
