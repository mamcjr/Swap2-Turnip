#!/bin/bash
# Swap2-Turnip p13 in Hyrule Field, phone block 3 (turnip-swap2's queue row): what barriers' wait-for-idles and ir3's register use cost.
# The driver zip p13 (out/Swap2-Turnip-2648b2059f-p13.zip: diagnostics only, mesa patch 9003) is installed in the test app as Swap2-Turnip; its options
# are Mesa debug.mesa.* properties (src/util/os_misc.c), cleared at the end (they would reach com.swap2native too).
# One run each, save copy user1117, keys 35:A,41:A,47:A, window 250+60 s, the foliage APK (the test pack's host; the installed APK goes back at the end):
#   base     p13 as it is (its wait-for-idle counts go to logcat, tag MESA, every 3000 submissions)
#   nowfi    debug.mesa.tu.rp.nowfi=1: barriers inside render passes emit no wait-for-idle (a bound on their cost; the picture may break: end.png)
#   cold0    the shader caches off (debug.mesa.shader.cache.disable=true, DM_VK_PCACHE=0, DM_VK_PREWARM=0): every pipeline compiled again, the control
#   regs32   as cold0 with debug.mesa.ir3.cs.regs=32: compute shaders capped at 32 full vec4 registers (6 waves instead of 4, spilling the rest)
#   regs24   the same at 24 (8 waves)
# The default driver goes back to Turnip_Gen8_V39, folder_save as it was.
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
R=D:/Projetos/Jogos/Android/MKWDroid; T=D:/Projetos/Jogos/Android/turnip-swap2; O=$T/out/zelda/p11; B=/data/local/tmp/s2bench
RA="run-as com.swap2native.test sh -c"
BENCH="python -I $R/dm/tools/android_bench.py"; ZIP=$T/out/Swap2-Turnip-2648b2059f-p13.zip
HF=(--save-ref $B/0400486024DEC000-user1117 --keys 35:A,41:A,47:A --start 250 --secs 60 --runs 1 --cool 60)
COLD="DM_VK_PCACHE=0,DM_VK_PREWARM=0"
mkdir -p $O
[ -f "$ZIP" ] || { echo "NOT RUN: zip missing"; exit 2; }
PROPS="debug.mesa.tu.rp.nowfi debug.mesa.ir3.cs.regs debug.mesa.shader.cache.disable"
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
  $BENCH --variant "$l:$env" "${HF[@]}" --tag p11-$l --out $O/$l 2>&1 | tail -1
  props
}
run base   DM_VK_FOLIAGE=3
run nowfi  DM_VK_FOLIAGE=3 debug.mesa.tu.rp.nowfi=1
run cold0  DM_VK_FOLIAGE=3,$COLD debug.mesa.shader.cache.disable=true
run regs32 DM_VK_FOLIAGE=3,$COLD debug.mesa.shader.cache.disable=true debug.mesa.ir3.cs.regs=32
run regs24 DM_VK_FOLIAGE=3,$COLD debug.mesa.shader.cache.disable=true debug.mesa.ir3.cs.regs=24
kill $LP 2>/dev/null
for f in $O/*/*/log.txt; do echo "== $f crash=$(grep -a -c 'CRASH sig' $f) hang=$(grep -a -c 'GPU hang:' $f) driver=$(grep -a -m1 -o 'Swap2-Turnip[^,;]*' $f)"; done
grep -a -h "swap2" $O/mesa.log | cut -c1-200 | tail -30
props; showprops; echo "(props above should be empty)"
echo "$SV" | grep -q ports- && adb shell "$RA 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
adb install -r "$O/before.apk" | tail -1
drv Turnip_Gen8_V39
adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"
adb shell input keyevent KEYCODE_HOME; echo "== end $(date)"
