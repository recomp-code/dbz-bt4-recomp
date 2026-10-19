#!/bin/bash
# run the bt3mod native runner on the BT4 mod ISO. extra env passes through. PID -> run.pid
cd ~/NBAStreetRecomp/bt3mod/${BUILD:-build}/ps2xRuntime || exit 1
mkdir -p ~/NBAStreetRecomp/dbz/native/shot
LOG=${LOG:-$HOME/NBAStreetRecomp/dbz/logs/bt3mod_run.log}
PS2X_SHOT_DIR=$HOME/NBAStreetRecomp/dbz/native/shot \
PS2X_CD_IMAGE=$HOME/Downloads/PS2_NTSC/SLUS_219.78.DBZBT4B14REV2.iso \
GRANITE_VULKAN_LIBRARY=${GRANITE_VULKAN_LIBRARY:-/opt/homebrew/lib/libvulkan.1.dylib} DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib:/usr/local/lib:/usr/lib nohup ./ps2EntryRunner $HOME/NBAStreetRecomp/bt3mod/games/bt3/work/SLUS_216.78 2>&1 \
  | awk '/No exact recompiled|\[mutex\]|guest-branch:missing|GetWindowScaleDPI/ { k=substr($0,1,60); if (++c[k] > 20) next } { print; fflush() }' > "$LOG" &
sleep 1; pgrep -n -f "ps2EntryRunner $HOME/NBAStreetRecomp/bt3mod" > ~/NBAStreetRecomp/dbz/native/run.pid
echo "pid $(cat ~/NBAStreetRecomp/dbz/native/run.pid) log $LOG"
