#!/bin/bash
# lrun.sh : run.sh with the PCSX2 GS host as the renderer (build-live, PS2X_GS_LIVE=1). Extra env passes through.
export BUILD=${BUILD:-build-live}
export PS2X_GS_LIVE=1
export PS2X_GSHOST=${PS2X_GSHOST:-$HOME/NBAStreetRecomp/gshost-dbz/pcsx2-gsrunner}
export PS2X_GSHOST_ARGS=${PS2X_GSHOST_ARGS:--ini $HOME/NBAStreetRecomp/gshost-dbz/dbz.ini}
export PS2X_LIVE_SERIAL=SLUS-21978
export PS2X_HOST_WINDOW=${PS2X_HOST_WINDOW:-1280x720}
export PS2X_FPS_LOG=${PS2X_FPS_LOG:-1}
exec bash ~/NBAStreetRecomp/dbz/native/run.sh
