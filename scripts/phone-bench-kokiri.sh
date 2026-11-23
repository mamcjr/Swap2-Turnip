#!/bin/bash
# Kokiri Forest by driver: the test save (0400486024DEC000-test1121, Link's porch), one run with every mesh draw on and one with a GPU profile of one frame in 300
# (DM_VK_GPUPROF_DRAWS: the costliest draws and the time by mesh shader), for each driver (default 891.14, Turnip_Gen8_V39, Swap2-Turnip), through android_bench.py.
# The Zelda folder_save is pointed at saves-test/0400486024DEC000 and put back, the default driver back to V39.
# Usage: phone-bench-kokiri.sh [tag] [driver ...]
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
TAG=${1:-base}; shift; DRVS=${*:-891.14 Turnip_Gen8_V39 Swap2-Turnip}
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
  python -I $R/dm/tools/android_bench.py --variant 'mesh:DM_VK_MESH_DRAWS=1' --variant 'prof:DM_VK_MESH_DRAWS=1,DM_VK_GPUPROF=300,DM_VK_GPUPROF_DRAWS=1' --runs 1 --cool 45 --save-ref $B/0400486024DEC000-test1121 --tag $TAG-kokiri-$drv 2>&1 | tail -4
done
echo "$SV" | grep -q ports- && adb shell "$RA 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver Turnip_Gen8_V39 >/dev/null; sleep 3
adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"; adb shell am force-stop com.swap2native.test; adb shell input keyevent KEYCODE_HOME; adb shell df -h /data | tail -1
