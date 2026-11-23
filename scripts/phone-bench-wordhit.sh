#!/bin/bash
# The raw memory loads' word hit live (DM_VK_RAW_WORD_HIT, vka_spv_raw_word_hit): installs the test APK built from MKWDroid 4858e7c + the halves + the word hit
# (out/swap2-native-test-wordhit.apk), then on Swap2-Turnip Hyrule Field (save copy 0400486024DEC000-user1117, one run of each variant) and Kokiri Forest (the test save,
# s2bench/0400486024DEC000-test1121, two of each), DM_VK_RAW_WORD_HIT on (its default) and off in turn, every mesh draw on; then the test APK of before back (swap2-native-test-45cedbd878f7.apk).
# The Zelda folder_save is pointed at saves-test/0400486024DEC000 and put back, the default driver back to V39. Usage: phone-bench-wordhit.sh [tag]
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
TAG=${1:-wh}; DRVS=Swap2-Turnip
adb install -r D:/Projetos/Jogos/Android/turnip-swap2/out/swap2-native-test-wordhit.apk
R=D:/Projetos/Jogos/Android/MKWDroid; B=/data/local/tmp/s2bench; S=/sdcard/Switch2/saves-test/0400486024DEC000
RA="run-as com.swap2native.test sh -c"
adb shell "[ -d $B/0400486024DEC000-test1121 ] || { mkdir -p $B/0400486024DEC000-test1121/main $B/0400486024DEC000-test1121/work && cp -r $S/. $B/0400486024DEC000-test1121/main/ && cp -r $S.work/. $B/0400486024DEC000-test1121/work/; }; ls $B/0400486024DEC000-test1121/main"
adb shell dumpsys package com.swap2native.test | grep -m2 -E 'versionName|lastUpdateTime'
adb shell am force-stop com.swap2native.test
SV=$(adb shell "$RA 'grep -h folder_save_0400486024DEC000 shared_prefs/launcher.xml'" | tr -d '\r'); echo "save pref before: $SV"
adb shell "$RA 'sed -i s#saves-test/ports-0400486024DEC000#saves-test/0400486024DEC000# shared_prefs/launcher.xml'"
for drv in $DRVS; do
  adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver $drv >/dev/null 2>&1; sleep 4; adb shell am force-stop com.swap2native.test
  adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" shared_prefs/*.xml'"
  python -I $R/dm/tools/android_bench.py --variant 'on:DM_VK_MESH_DRAWS=1' --variant 'off:DM_VK_MESH_DRAWS=1,DM_VK_RAW_WORD_HIT=0' --runs 1 --cool 45 --save-ref $B/0400486024DEC000-user1117 --keys '35:A,41:A,47:A' --start 90 --secs 60 --tag $TAG-hf-$drv 2>&1 | tail -4
  python -I $R/dm/tools/android_bench.py --variant 'on:DM_VK_MESH_DRAWS=1' --variant 'off:DM_VK_MESH_DRAWS=1,DM_VK_RAW_WORD_HIT=0' --runs 2 --cool 45 --save-ref $B/0400486024DEC000-test1121 --tag $TAG-kokiri-$drv 2>&1 | tail -4
done
adb install -r D:/Projetos/Jogos/Android/MKWDroid/android/app/out/swap2-native-test-45cedbd878f7.apk
echo "$SV" | grep -q ports- && adb shell "$RA 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver Turnip_Gen8_V39 >/dev/null; sleep 3
adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"; adb shell am force-stop com.swap2native.test; adb shell input keyevent KEYCODE_HOME; adb shell df -h /data | tail -1
