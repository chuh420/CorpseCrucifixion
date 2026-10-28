#!/usr/bin/env bash
C=~/Zomboid/console.txt
before=$(grep -c "\[PZC test\] cmd" $C)
printf '%s\n-- %s\n' "$1" "$(date +%s%N)" > ~/Zomboid/Lua/pzc_cmd.lua
for i in $(seq 1 30); do now=$(grep -c "\[PZC test\] cmd" $C); [ "$now" -gt "$before" ] && break; sleep 0.5; done
grep "\[PZC test\] cmd" $C | tail -1 | sed 's/.*\[PZC test\] //'
