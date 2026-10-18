#!/bin/bash
# ./dstart.sh [url] : starts a headless dctl session (kills only the previous DBZ session's own PIDs)
cd "$(dirname "$0")"
[ -f dctl/node.pid ] && kill -9 $(cat dctl/node.pid) 2>/dev/null
[ -f dctl/pid.txt ] && kill -9 $(cat dctl/pid.txt) 2>/dev/null
sleep 1
mkdir -p dctl; rm -f dctl/game.log dctl/console.log
nohup node dctl.mjs "${1:-http://localhost:8091/?online=0}" > dctl/node.log 2>&1 &
echo $! > dctl/node.pid
echo "started node pid $(cat dctl/node.pid)"
