#!/bin/bash
# phone-try.sh <zip> <tag>: install a driver zip in the test app (it becomes the default), start Zelda, screenshot at 40 s
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
OUT=/d/Projetos/Jogos/Android/turnip-swap2/out/zelda
adb shell am force-stop com.swap2native.test
adb push "$1" /sdcard/Download/Swap2-Turnip.zip >/dev/null
adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver_zip /sdcard/Download/Swap2-Turnip.zip >/dev/null 2>&1
sleep 9
adb shell "run-as com.swap2native.test sh -c 'grep -h \"name=\\\"gpu_driver\\\"\" shared_prefs/*.xml'"
for i in 1 2; do adb shell input swipe 2600 620 600 620 400; sleep 1; done
adb shell input tap 386 620; sleep 2
adb shell "uiautomator dump /data/local/tmp/ui.xml >/dev/null 2>&1; cat /data/local/tmp/ui.xml" | grep -oE 'text="The Legend of Zelda[^"]*"' | head -1
adb logcat -c
adb shell input tap 2877 1064
sleep 40
adb exec-out screencap -p > $OUT/$2-t40.png
echo "game pid: $(adb shell pidof com.swap2native.test:game)"
adb logcat -d | grep -a "MESA\|TU_DEBUG" | head -5
