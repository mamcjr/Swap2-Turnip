#!/bin/bash
# Hyrule Field on chain 4eb05e585fb0 (Turnip V39, the default driver): where the ~5 ms a frame between the GPU's 28 ms and the 33.5 ms frame goes.
# The 4eb0 test APK over the installed one (put back at the end); android_bench.py with the save copy user1117, keys 35:A,41:A,47:A, window 90+60 s,
# variants base and chunk (DM_VK_CHUNK=200, DM_VK_CHUNK_PASS=200: the GPU starts sooner on a submission's parts), A B A B A B; a SYNCLOG of 60 waits
# 20 s into each window (live control line). Logs in out/zelda/hfsync. folder_save and the default driver as they were.
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
R=D:/Projetos/Jogos/Android/MKWDroid; T=D:/Projetos/Jogos/Android/turnip-swap2; O=$T/out/zelda/hfsync; B=/data/local/tmp/s2bench
RA="run-as com.swap2native.test sh -c"
mkdir -p $O
P=$(adb shell pm path com.swap2native.test | head -1 | sed 's/package://' | tr -d '\r')
adb pull "$P" "$O/before.apk" | tail -1 || exit 1
adb shell dumpsys package com.swap2native.test | grep -m1 lastUpdateTime
adb shell am force-stop com.swap2native.test
adb install -r "$R/android/app/out/swap2-native-test-4eb0.apk" | tail -1 || exit 1
adb shell "ls /sdcard/Switch2/Work/0400486024DEC000/test-pack/shaders"
SV=$(adb shell "$RA 'grep -h folder_save_0400486024DEC000 shared_prefs/launcher.xml'" | tr -d '\r'); echo "save pref before: $SV"
adb shell "$RA 'sed -i s#saves-test/ports-0400486024DEC000#saves-test/0400486024DEC000# shared_prefs/launcher.xml'"
adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver Turnip_Gen8_V39 >/dev/null 2>&1; sleep 4; adb shell am force-stop com.swap2native.test
python -I $R/dm/tools/android_bench.py --variant 'base:' --variant 'chunk:DM_VK_CHUNK=200,DM_VK_CHUNK_PASS=200' --runs 3 --cool 30 \
  --save-ref $B/0400486024DEC000-user1117 --keys '35:A,41:A,47:A' --start 90 --secs 60 --ctl '20:env DM_VK_SYNCLOG=60' --tag hfsync --out $O/bench 2>&1 | tail -12
echo "$SV" | grep -q ports- && adb shell "$RA 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
adb install -r "$O/before.apk" | tail -1
adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver Turnip_Gen8_V39 >/dev/null 2>&1; sleep 4; adb shell am force-stop com.swap2native.test
adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"
adb shell input keyevent KEYCODE_HOME; rm -f "$O/before.apk"; echo "== end $(date)"
