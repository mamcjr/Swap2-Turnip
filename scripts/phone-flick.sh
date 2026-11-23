#!/bin/bash
# phone-flick.sh <installed driver folder> <tag>: Zelda from the library on that driver, Continue, then a 6 s screen recording
# of the still scene (Link standing where the save puts him) for tools/flicker.py; also the Mesa/driver log lines.
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
OUT=/d/Projetos/Jogos/Android/turnip-swap2/out/zelda/flick-$2; mkdir -p $OUT
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
adb shell screenrecord --time-limit ${SECS:-6} --bit-rate 40000000 --size 1600x720 /sdcard/Download/flick.mp4
adb pull /sdcard/Download/flick.mp4 "$(cygpath -w $OUT)/flick.mp4" >/dev/null && adb shell rm /sdcard/Download/flick.mp4
adb exec-out screencap -p > $OUT/after.png
adb logcat -d | grep -a "Using IMapper\|aimapper:\|\[vk\] device\|driver:\|longframe\] frame\|DEVICE_LOST" | tail -4 | cut -c1-220 > $OUT/log.txt
echo "pid $(adb shell pidof com.swap2native.test:game)"; cat $OUT/log.txt
