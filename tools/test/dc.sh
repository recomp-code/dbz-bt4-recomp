#!/bin/bash
# ./dc.sh "key Enter" "snap /path.png" ... : sends commands to dctl.mjs and waits for each one
cd "$(dirname "$0")"; touch dctl/result.txt
for c in "$@"; do
  n=$(wc -l < dctl/result.txt 2>/dev/null || echo 0)
  echo "$c" >> dctl/cmd.txt
  until [ "$(wc -l < dctl/result.txt)" -gt "$n" ]; do sleep 0.3; done
  tail -1 dctl/result.txt
done
