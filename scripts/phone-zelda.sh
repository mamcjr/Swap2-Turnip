#!/bin/bash
# phone-zelda.sh <tag>: in the test app's library, select Zelda's card, Play, Continue on the test save; screenshot at title and in game, logcat MESA lines
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
OUT=/d/Projetos/Jogos/Android/turnip-swap2/out/zelda/$1; mkdir -p $OUT
ui() { adb shell "uiautomator dump /data/local/tmp/ui.xml >/dev/null 2>&1; cat /data/local/tmp/ui.xml" | tr '>' '\n'; }
center() { ui | grep -E "content-desc=\"$1" | head -1 | grep -oE 'bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' | grep -oE '[0-9]+' | paste -sd' ' | awk '{print int(($1+$3)/2), int(($2+$4)/2)}'; }
for i in 1 2 3 4 5; do c=$(center "The Legend of Zelda"); [ -n "$c" ] && break; adb shell input swipe 2600 620 600 620 400; sleep 1; done
echo "zelda card at $c"; adb shell input tap $c; sleep 2
ui | grep -oE 'text="The Legend of Zelda[^"]*"' | head -1
p=$(center "Jogar"); echo "play at $p"
adb logcat -c; adb shell input tap $p
for i in $(seq 1 30); do sleep 2; adb shell pidof com.swap2native.test:game >/dev/null && break; done
sleep 35; adb exec-out screencap -p > $OUT/title.png
adb shell input tap 2949 477; sleep 4; adb shell input tap 2949 477; sleep 4; adb shell input tap 2949 477
sleep ${WAIT:-80}; adb exec-out screencap -p > $OUT/game.png
adb logcat -d | grep -a "MESA\|aimapper" | head -30 > $OUT/mesa.logcat
echo "game pid: $(adb shell pidof com.swap2native.test:game)"; cat $OUT/mesa.logcat | cut -c1-260
