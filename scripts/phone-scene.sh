#!/bin/bash
# phone-scene.sh <driver folder name> <tag>: Zelda in the test app on that driver, Continue on the test save, wait for the scene,
# then 12 raw screen captures (no touches) for frame-to-frame comparison
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
OUT=/d/Projetos/Jogos/Android/turnip-swap2/out/zelda/$2; mkdir -p $OUT
adb shell am force-stop com.swap2native.test
adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver "$1" >/dev/null 2>&1
sleep 9
adb shell "run-as com.swap2native.test sh -c 'grep -h \"name=\\\"gpu_driver\\\"\" shared_prefs/*.xml'"
for i in 1 2; do adb shell input swipe 2600 620 600 620 400; sleep 1; done
adb shell input tap 386 620; sleep 2
adb shell input tap 2877 1064
for i in $(seq 1 30); do sleep 2; adb shell pidof com.swap2native.test:game >/dev/null && break; done
sleep 30; adb shell input tap 2949 477; sleep 4; adb shell input tap 2949 477
sleep ${WAIT:-90}
adb exec-out screencap -p > $OUT/scene.png
for i in $(seq -w 1 12); do adb exec-out screencap > $OUT/raw$i.bin; done
L=$(adb shell "ls -t /sdcard/Android/data/com.swap2native.test/files/logs/*.log | head -1" | tr -d '\r'); adb exec-out cat "$L" > $OUT/run.log
echo "pid $(adb shell pidof com.swap2native.test:game) log $(wc -l < $OUT/run.log)"
