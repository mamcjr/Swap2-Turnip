#!/bin/bash
# The fix APK (vka_pso.c linked_retire: the linked pipelines an optimized one replaced, destroyed) in ordinary play: Kokiri Forest from the save copy test1121
# with the camera turning (the parent session's camera keys), the device's own pipeline cache and prewarm list (as a player has them), DM_VK_HOSTMEM=1,
# DM_VK_CHUNK=200; on Turnip V39 and on 891.14, one run each, window 100+60 s: no crash or hang, and how many linked pipelines a run destroys. The installed APK is put back at the end; the library v-706d0c7262fa is in the test pack. Logs in out/zelda/leak.
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
R=D:/Projetos/Jogos/Android/MKWDroid; T=D:/Projetos/Jogos/Android/turnip-swap2; O=$T/out/zelda/leak2; B=/data/local/tmp/s2bench
RA="run-as com.swap2native.test sh -c"; ZD=/sdcard/Switch2/Work/0400486024DEC000/test-pack/shaders; V=v-706d0c7262fa
A0=$R/android/app/out/swap2-native-test-706d0c7262fa-exact.apk; A1=$T/out/swap2-native-test-fix.apk
mkdir -p $O
[ -f "$A1" ] || { echo "NOT RUN: an APK is missing"; exit 2; }
adb shell "[ -f $ZD/$V/dmsh_vk.lib ]" || { echo "NOT RUN: library $V not in the test pack"; exit 2; }
P=$(adb shell pm path com.swap2native.test | head -1 | sed 's/package://' | tr -d '\r')
adb pull "$P" "$O/before.apk" | tail -1 || exit 1
SV=$(adb shell "$RA 'grep -h folder_save_0400486024DEC000 shared_prefs/launcher.xml'" | tr -d '\r'); echo "save pref before: $SV"
drv() { adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver $1 >/dev/null 2>&1; sleep 4; adb shell am force-stop com.swap2native.test; }
KEYS='35:A*6/4,104:RLeft~2.5,107:RRight~5,113:RLeft~2.5,117:RUp~1.5,119:RDown~3,123:RUp~1.5,130:RLeft~2.5,133:RRight~5,139:RLeft~2.5,143:RUp~1.5,145:RDown~3,149:RUp~1.5'
E=DM_VK_HOSTMEM=1,DM_VK_CHUNK=200,DM_VK_CHUNK_PASS=200
for d in Turnip_Gen8_V39 891.14; do
  for a in fix:$A1; do
    tag=${a%%:*}; apk=${a#*:}
    adb shell am force-stop com.swap2native.test; adb install -r "$apk" | tail -1 || exit 1
    adb shell "$RA 'sed -i s#saves-test/ports-0400486024DEC000#saves-test/0400486024DEC000# shared_prefs/launcher.xml'"
    drv $d; adb shell input keyevent KEYCODE_WAKEUP
    python -I $R/dm/tools/android_bench.py --variant $tag:$E --runs 1 --keys "$KEYS" --start 100 --secs 60 --save-ref $B/0400486024DEC000-test1121 --tag leak-$d-$tag --out $O/$d-$tag 2>&1 | tail -2
  done
done
for f in $O/*/*/log.txt; do echo "== $f crash=$(grep -a -c 'CRASH sig' $f) hang=$(grep -a -c 'GPU hang:' $f)"; grep -a "driver host memory" $f | tail -1 | cut -c1-260; grep -a -o "libraries [0-9].*waiting" $f | tail -1; grep -a "malloc in use" $f | tail -1 | cut -c1-120; done
echo "$SV" | grep -q ports- && adb shell "$RA 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
adb install -r "$O/before.apk" | tail -1
drv Turnip_Gen8_V39
adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"
adb shell input keyevent KEYCODE_HOME; rm -f "$O/before.apk"; echo "== end $(date)"
