#!/bin/bash
P=$(cat ~/NBAStreetRecomp/dbz/native/run.pid 2>/dev/null); [ -n "$P" ] && kill $P 2>/dev/null; sleep 1; kill -9 $P 2>/dev/null; echo stopped $P
