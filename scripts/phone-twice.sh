#!/bin/bash
# phone-twice.sh <installed driver folder> <tag>: Zelda on that driver, Continue, then DM_VK_MESH_TWICE=1 through ctl.txt for ${SECS:-40} s:
# every task/mesh fallback dispatch that writes no guest memory runs twice and is compared (vka_mesh.inc). Saves the log lines.
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
F=/storage/emulated/0/Android/data/com.swap2native.test/files
OUT=/d/Projetos/Jogos/Android/turnip-swap2/out/zelda/twice-$2; mkdir -p $OUT
node() { adb shell "uiautomator dump /data/local/tmp/ui.xml >/dev/null 2>&1; cat /data/local/tmp/ui.xml" | tr '>' '\n' | grep -E "content-desc=\"$1" | head -1 | grep -oE 'bounds="[^"]*"' | grep -oE '[0-9]+' | paste -sd' ' | awk 'NF==4 {print int(($1+$3)/2), int(($2+$4)/2)}'; }
adb shell am force-stop com.swap2native.test
adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver "$1" >/dev/null 2>&1
sleep 6
c=""; for i in 1 2 3 4 5 6; do c=$(node "The Legend of Zelda"); [ -n "$c" ] && break; adb shell input swipe 2600 620 600 620 400; sleep 1; done
adb logcat -c
adb shell input tap $c; sleep 2
p=$(node "Jogar"); echo "card $c play $p"
[ -n "$p" ] && adb shell input tap $p
sleep 40; for k in 1 2 3; do adb shell input tap 2949 477; sleep 4; done
sleep ${WAIT:-75}
adb exec-out screencap -p > $OUT/before.png
adb shell "echo 'env DM_VK_MESH_TWICE=1' >> $F/ctl.txt"
sleep ${SECS:-40}
adb shell "echo 'env DM_VK_MESH_TWICE=0' >> $F/ctl.txt"
sleep 3
adb exec-out screencap -p > $OUT/after.png
adb logcat -d | grep -a "task/mesh twice\|checked by a second run\|DM_VK_MESH_TWICE\|DEVICE_LOST\|\[vk\] device" | cut -c19- > $OUT/twice.log
echo "pid $(adb shell pidof com.swap2native.test:game)"; grep "dispatches checked" $OUT/twice.log | tail -2 | cut -c40-200; grep "differ between" $OUT/twice.log | grep -o "twice: [a-z]* [0-9a-f]*" | sort | uniq -c | sort -rn | head -8
