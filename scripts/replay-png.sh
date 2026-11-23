#!/bin/bash
# replay-png.sh <driver folder name> <tag> [KEY=VAL ...]: replays the Kokiri capture twice with nxreplay on that driver and the given switches,
# pulls the second replay's picture to out/zelda/rp/<tag>.png, prints the replay lines
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
drv=$1; tag=$2; shift 2; envs="$*"
C=/storage/emulated/0/Switch2/Work/0400486024DEC000/captures
adb shell "cd /data/local/tmp/nxreplay && rm -rf o_$tag && mkdir -p o_$tag && $envs DM_TEMP=/data/local/tmp/nxreplay/temp DM_VK_DRIVER=/data/local/tmp/nxreplay/drv/$drv LD_LIBRARY_PATH=. ./nxreplay $C/kokiri.nvncap --warm 2 --out /data/local/tmp/nxreplay/o_$tag > o_$tag.log 2>&1"
mkdir -p /d/Projetos/Jogos/Android/turnip-swap2/out/zelda/rp
adb pull /data/local/tmp/nxreplay/o_$tag/kokiri.nvncap.replay2.png "D:/Projetos/Jogos/Android/turnip-swap2/out/zelda/rp/$tag.png" >/dev/null 2>&1
adb shell "grep -a 'pixels differ\|nxreplay:' /data/local/tmp/nxreplay/o_$tag.log; rm -rf /data/local/tmp/nxreplay/o_$tag /data/local/tmp/nxreplay/o_$tag.log" | cut -c1-120
