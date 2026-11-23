#!/bin/bash
# Swap2-Turnip p14 in Hyrule Field, phone block 4 (turnip-swap2's queue row): storage buffers the shader never writes read through isam.
# The driver zip (out/Swap2-Turnip-2648b2059f-p14.zip: diagnostics only, mesa patch 9004) is installed in the test app as Swap2-Turnip; its options are
# Mesa debug.mesa.* properties, cleared at the end. Shader caches off in every run (debug.mesa.shader.cache.disable=true, DM_VK_PCACHE=0, DM_VK_PREWARM=0),
# so each run compiles with its own setting; A B A B, save copy user1117, keys 35:A,41:A,47:A, window 250+60 s, the foliage APK (the installed one goes back):
#   ro0    as p13
#   ro1    debug.mesa.tu.ssbo.ro.auto=1: a storage buffer no store or atomic of the shader reaches is taken as NonWritable, its loads isam (the
#          texture path) instead of ldib. Not conformant (aliasing bindings); end.png shows the picture
# The default driver goes back to Turnip_Gen8_V39, folder_save as it was.
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
R=D:/Projetos/Jogos/Android/MKWDroid; T=D:/Projetos/Jogos/Android/turnip-swap2; O=$T/out/zelda/p14; B=/data/local/tmp/s2bench
RA="run-as com.swap2native.test sh -c"
BENCH="python -I $R/dm/tools/android_bench.py"; ZIP=$T/out/Swap2-Turnip-2648b2059f-p14.zip
HF=(--save-ref $B/0400486024DEC000-user1117 --keys 35:A,41:A,47:A --start 250 --secs 60 --runs 1 --cool 60)
COLD="DM_VK_PCACHE=0,DM_VK_PREWARM=0"
mkdir -p $O
[ -f "$ZIP" ] || { echo "NOT RUN: zip missing"; exit 2; }
PROPS="debug.mesa.tu.rp.nowfi debug.mesa.ir3.cs.regs debug.mesa.shader.cache.disable debug.mesa.tu.ssbo.ro.auto"
props() { for p in $PROPS; do adb shell "setprop $p ''"; done; }
showprops() { adb shell "getprop | grep debug.mesa" ; }
drv() { adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver $1 >/dev/null 2>&1; sleep 4; adb shell am force-stop com.swap2native.test; }
adb shell am force-stop com.swap2native.test
P=$(adb shell pm path com.swap2native.test | head -1 | sed 's/package://' | tr -d '\r')
adb pull "$P" "$O/before.apk" | tail -1 || exit 1
adb install -r "$T/out/swap2-native-test-foliage.apk" | tail -1 || exit 1
SV=$(adb shell "$RA 'grep -h folder_save_0400486024DEC000 shared_prefs/launcher.xml'" | tr -d '\r'); echo "save pref before: $SV"
adb shell "$RA 'sed -i s#saves-test/ports-0400486024DEC000#saves-test/0400486024DEC000# shared_prefs/launcher.xml'"
adb push "$ZIP" /sdcard/Download/Swap2-Turnip.zip >/dev/null
adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver_zip /sdcard/Download/Swap2-Turnip.zip >/dev/null 2>&1
sleep 9; adb shell am force-stop com.swap2native.test; adb shell rm -f /sdcard/Download/Swap2-Turnip.zip
adb shell "$RA 'grep -h \"name=\\\"gpu_driver\\\"\" shared_prefs/*.xml'"
adb shell input keyevent KEYCODE_WAKEUP
props
adb logcat -c; (adb logcat -v time MESA:V '*:S' > $O/mesa.log) & LP=$!
run() {   # label, bench variant env, then property=value pairs
  local l=$1 env=$2; shift 2
  echo "== $l $(date +%T)"
  for kv in "$@"; do adb shell setprop ${kv%%=*} ${kv#*=}; done
  showprops
  adb shell log -t MESA "swap2-run $l"
  $BENCH --variant "$l:$env" "${HF[@]}" --tag p14-$l --out $O/$l 2>&1 | tail -1
  props
}
run ro0a DM_VK_FOLIAGE=3,$COLD debug.mesa.shader.cache.disable=true
run ro1a DM_VK_FOLIAGE=3,$COLD debug.mesa.shader.cache.disable=true debug.mesa.tu.ssbo.ro.auto=1
run ro0b DM_VK_FOLIAGE=3,$COLD debug.mesa.shader.cache.disable=true
run ro1b DM_VK_FOLIAGE=3,$COLD debug.mesa.shader.cache.disable=true debug.mesa.tu.ssbo.ro.auto=1
kill $LP 2>/dev/null
for f in $O/*/*/log.txt; do echo "== $f crash=$(grep -a -c 'CRASH sig' $f) hang=$(grep -a -c 'GPU hang:' $f) driver=$(grep -a -m1 -o 'Swap2-Turnip[^,;]*' $f)"; done
grep -a -h "swap2" $O/mesa.log | cut -c1-200 | tail -30
props; showprops; echo "(props above should be empty)"
echo "$SV" | grep -q ports- && adb shell "$RA 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
adb install -r "$O/before.apk" | tail -1
drv Turnip_Gen8_V39
adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"
adb shell input keyevent KEYCODE_HOME; echo "== end $(date)"
