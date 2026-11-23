#!/bin/bash
# phone-zelda2.sh <zip> <tag>: install a Swap2-Turnip zip in the test app, start Zelda from the library, Continue, screenshots, Mesa log lines
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
OUT=/d/Projetos/Jogos/Android/turnip-swap2/out/zelda/$2; mkdir -p $OUT
node() { adb shell "uiautomator dump /data/local/tmp/ui.xml >/dev/null 2>&1; cat /data/local/tmp/ui.xml" | tr '>' '\n' | grep -E "content-desc=\"$1" | head -1 | grep -oE 'bounds="[^"]*"' | grep -oE '[0-9]+' | paste -sd' ' | awk 'NF==4 {print int(($1+$3)/2), int(($2+$4)/2)}'; }
adb shell am force-stop com.swap2native.test
adb push "$1" /sdcard/Download/Swap2-Turnip.zip >/dev/null
adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver_zip /sdcard/Download/Swap2-Turnip.zip >/dev/null 2>&1
sleep 9
c=""; for i in 1 2 3 4 5 6; do c=$(node "The Legend of Zelda"); [ -n "$c" ] && break; adb shell input swipe 2600 620 600 620 400; sleep 1; done
adb shell input tap $c; sleep 2
p=$(node "Jogar"); echo "card $c play $p"
adb logcat -c; adb shell input tap $p
sleep 40; adb exec-out screencap -p > $OUT/title.png
for k in 1 2 3; do adb shell input tap 2949 477; sleep 4; done
sleep ${WAIT:-60}; adb exec-out screencap -p > $OUT/game.png
adb logcat -d | grep -a " MESA \|MESA  *:" | head -24 > $OUT/mesa.logcat
echo "pid $(adb shell pidof com.swap2native.test:game)"; cut -c1-300 $OUT/mesa.logcat
