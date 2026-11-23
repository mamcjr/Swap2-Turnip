#!/bin/bash
# Baseline fps with every mesh draw on (the user's goal of 2026-11-21: 30 fps in Kokiri Forest and Hyrule Field with all mesh geometry), live in the test app:
# for each driver (default: Swap2-Turnip and Turnip_Gen8_V39) two runs in Hyrule Field (save copy 0400486024DEC000-user1117, keys 35:A,41:A,47:A, window 90+60 s)
# and two in Kokiri Forest (the test save as it is now, kept as 0400486024DEC000-test1121, the default keys, window 100+60 s), through dm/tools/android_bench.py.
# Kokiri runs last, so the test save is left as it was. The Zelda folder_save is pointed at saves-test/0400486024DEC000 and put back, the default driver back to V39.
# Usage: phone-bench-base.sh [tag] [driver ...]
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
TAG=${1:-base}; shift; DRVS=${*:-Swap2-Turnip Turnip_Gen8_V39}
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
  python -I $R/dm/tools/android_bench.py --variant 'mesh:DM_VK_MESH_DRAWS=1' --runs 2 --cool 45 --save-ref $B/0400486024DEC000-user1117 --keys '35:A,41:A,47:A' --start 90 --secs 60 --tag $TAG-hf-$drv 2>&1 | tail -4
  python -I $R/dm/tools/android_bench.py --variant 'mesh:DM_VK_MESH_DRAWS=1' --runs 2 --cool 45 --save-ref $B/0400486024DEC000-test1121 --tag $TAG-kokiri-$drv 2>&1 | tail -4
done
echo "$SV" | grep -q ports- && adb shell "$RA 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver Turnip_Gen8_V39 >/dev/null; sleep 3
adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"; adb shell am force-stop com.swap2native.test; adb shell input keyevent KEYCODE_HOME; adb shell df -h /data | tail -1
