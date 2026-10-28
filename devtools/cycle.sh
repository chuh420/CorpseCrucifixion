#!/usr/bin/env bash
S="$(dirname "$(readlink -f "$0")")"
MODLUA=~/Zomboid/Workshop/CorpseCrucifixion/Contents/mods/CorpseCrucifixion/42/media/lua/client/CorpseCrucifixion
cp "$S/CorpseCrucifixionDebugTest.lua" "$MODLUA/"
C=~/Zomboid/console.txt
pkill -x ProjectZomboid6; for i in $(seq 1 30); do pgrep -x ProjectZomboid6 >/dev/null || break; sleep 1; done; sleep 3
touch ~/Zomboid/Lua/pzc_autotest.txt
: > ~/Zomboid/Lua/pzc_cmd.lua
(setsid steam -applaunch 108600 -debug >/dev/null 2>&1 &)
for i in $(seq 1 200); do [ $C -nt ~/Zomboid/Lua/pzc_autotest.txt ] && grep -q "game loading took" $C && break; sleep 2; done
grep -q "game loading took" $C || { echo "load timeout"; exit 1; }
sleep 8
addr=$(hyprctl clients -j | python3 -I -c 'import json,sys; print(next(c["address"] for c in json.load(sys.stdin) if c["class"]=="Project Zomboid"))')
hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null
sleep 1
for attempt in 1 2 3; do
  $S/mouse.sh click 960 540
  for i in $(seq 1 45); do grep -q "\[PZC test\] ready" $C && break 2; sleep 2; done
done
sleep 3
$S/mouse.sh move 1900 200
sleep 1
grim $S/shot_${1:-x}.png
grep "\[PZC test\]" $C | sed 's/.*\[PZC test\]/[PZC]/'
