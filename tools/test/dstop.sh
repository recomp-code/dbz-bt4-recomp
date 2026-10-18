#!/bin/bash
cd "$(dirname "$0")"
[ -f dctl/node.pid ] && kill -9 $(cat dctl/node.pid) 2>/dev/null
[ -f dctl/pid.txt ] && kill -9 $(cat dctl/pid.txt) 2>/dev/null
rm -f dctl/node.pid dctl/pid.txt; echo stopped
