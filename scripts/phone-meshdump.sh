#!/bin/bash
# phone-meshdump.sh "<draws>": capture Zelda's Kokiri frame 4500 on 891.14, replay it on 891.14 and Swap2-Turnip with DM_VK_MESH_DUMP=<draws>,
# pull the dumps to out/zelda/meshdump/<driver>, delete the capture, restore Turnip_Gen8_V39 as the test app's default
set -u
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
DRAWS=$1; T=D:/Projetos/Jogos/Android/turnip-swap2; P=/data/local/tmp/nxreplay
F=/storage/emulated/0/Android/data/com.swap2native.test/files; C=/storage/emulated/0/Switch2/Work/0400486024DEC000/captures
adb push $T/replay-build/nxreplay $T/replay-build/libnxhost.so $P/ >/dev/null && adb shell chmod 755 $P/nxreplay
adb exec-out "run-as com.swap2native.test tar c -C files/gpu_drivers Swap2-Turnip" > $T/replay-stage/drv/Swap2-Turnip.tar
adb push $T/replay-stage/drv/Swap2-Turnip.tar $P/drv/ >/dev/null; adb shell "cd $P/drv && tar xf Swap2-Turnip.tar && rm Swap2-Turnip.tar"
adb shell "mkdir -p $C; echo DM_NVN_CAPTURE=4500:1:$C/kokiri.nvncap > $F/env-0400486024DEC000.txt"
node() { adb shell "uiautomator dump /data/local/tmp/ui.xml >/dev/null 2>&1; cat /data/local/tmp/ui.xml" | tr '>' '\n' | grep -E "content-desc=\"$1" | head -1 | grep -oE 'bounds="[^"]*"' | grep -oE '[0-9]+' | paste -sd' ' | awk 'NF==4 {print int(($1+$3)/2), int(($2+$4)/2)}'; }
adb shell am force-stop com.swap2native.test; adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver 891.14 >/dev/null 2>&1; sleep 6
c=""; for i in 1 2 3 4 5 6; do c=$(node "The Legend of Zelda"); [ -n "$c" ] && break; adb shell input swipe 2600 620 600 620 400; sleep 1; done
adb logcat -c; adb shell input tap $c; sleep 2; p=$(node "Jogar"); [ -n "$p" ] && adb shell input tap $p
sleep 40; for k in 1 2 3; do adb shell input tap 2949 477; sleep 4; done
for i in $(seq 1 50); do sleep 10; l=$(adb logcat -d | grep -a "DM_NVN_CAPTURE: frame [0-9]*: [0-9]* submits" | tail -1 | cut -c60-300); [ -n "$l" ] && { echo "capture: $l"; break; }; done
adb shell am force-stop com.swap2native.test; adb shell rm -f $F/env-0400486024DEC000.txt
for drv in 891.14 Swap2-Turnip; do
  adb shell "cd $P && rm -rf md_$drv && mkdir -p md_$drv && DM_VK_MESH_DUMP=$DRAWS DM_VK_MESH_DUMP_DIR=$P/md_$drv DM_TEMP=$P/temp DM_VK_DRIVER=$P/drv/$drv LD_LIBRARY_PATH=. ./nxreplay $C/kokiri.nvncap --warm 2 --no-png > md_$drv.log 2>&1; grep -a 'pixels differ\|nxreplay:\|task/mesh dump' md_$drv.log | head -5; du -sh md_$drv"
  mkdir -p $T/out/zelda/meshdump/$drv; adb pull $P/md_$drv/. "$T/out/zelda/meshdump/$drv" >/dev/null; adb pull $P/md_$drv.log "$T/out/zelda/meshdump/$drv.log" >/dev/null
  adb shell "rm -rf $P/md_$drv $P/md_$drv.log"
done
adb shell "rm -f $C/kokiri.nvncap $C/kokiri.nvncap.live.png; rmdir $C 2>/dev/null; rm -rf $P/drv/Swap2-Turnip"
adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver Turnip_Gen8_V39 >/dev/null; sleep 3
adb shell run-as com.swap2native.test sh -c "'grep -h \"name=\\\"gpu_driver\\\"\" shared_prefs/*.xml'"; adb shell am force-stop com.swap2native.test; adb shell input keyevent KEYCODE_HOME; adb shell df -h /data | tail -1
