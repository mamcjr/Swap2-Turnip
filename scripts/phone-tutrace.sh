#!/bin/bash
# Swap2-Turnip in Hyrule Field, phone block 2 (turnip-swap2's queue row): where the GPU's frame goes, pass by pass, and what the autotuner picks.
# The driver zip p10 (out/Swap2-Turnip-2648b2059f-p10.zip: patch 9002, u_trace's output gated by the property debug.mesa.gpu.traces.on) is installed
# in the test app as Swap2-Turnip. Mesa reads its options from debug.mesa.* properties when the environment has none (src/util/os_misc.c), which
# reach the driver although the app loads it before it sets the game's environment.
# T) one run (save copy user1117, keys 35:A,41:A,47:A, window 250+60 s) with MESA_GPU_TRACES=print_csv into the app's files/ut.csv, printed only from
#    270 to 280 s, and TU_DEBUG=perf (logcat tag MESA into out/zelda/tutrace/mesa.log).
# A) the autotuner's algorithms, one run each, no tracing: default (bandwidth), prefer_gmem, prefer_sysmem, profiled (TU_AUTOTUNE_ALGO).
# Every debug.mesa.* property is cleared at the end; the default driver goes back to Turnip_Gen8_V39, folder_save as it was.
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
R=D:/Projetos/Jogos/Android/MKWDroid; T=D:/Projetos/Jogos/Android/turnip-swap2; O=$T/out/zelda/tutrace; B=/data/local/tmp/s2bench
RA="run-as com.swap2native.test sh -c"; F=/sdcard/Android/data/com.swap2native.test/files
BENCH="python -I $R/dm/tools/android_bench.py"; ZIP=$T/out/Swap2-Turnip-2648b2059f-p10.zip
HF=(--save-ref $B/0400486024DEC000-user1117 --keys 35:A,41:A,47:A --start 250 --secs 60 --runs 1 --cool 60)
mkdir -p $O
[ -f "$ZIP" ] || { echo "NOT RUN: zip missing"; exit 2; }
props() { for p in debug.mesa.gpu.traces debug.mesa.gpu.tracefile debug.mesa.gpu.traces.on debug.mesa.tu.debug debug.mesa.tu.autotune.algo; do adb shell "setprop $p ''"; done; }
showprops() { adb shell "getprop | grep debug.mesa" ; }
started() { local i=0; while [ -z "$(adb shell pidof com.swap2native.test:game | tr -d '')" ]; do i=$((i+1)); [ $i -gt 600 ] && { echo "no game process after 300 s"; return 1; }; sleep 0.5; done; echo "launch $(date +%T)"; }
drv() { adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver $1 >/dev/null 2>&1; sleep 4; adb shell am force-stop com.swap2native.test; }
# Block #53 lost adb at its restore (18:15): the foliage APK stayed installed and folder_save may be left on the HF copy. Put both back first.
adb shell am force-stop com.swap2native.test
# The installed APK (swap2-native-test-ports-5b27, md5 7e61d408) no longer takes the test pack (No pack found: built for an older chain), so the runs
# use the foliage APK (main tree, chain 706d, the host of block #53's V39 measurements) and the original goes back at the end.
adb install -r "D:/Projetos/Jogos/Android/turnip-swap2/out/swap2-native-test-foliage.apk" | tail -1 || exit 1
adb shell "$RA 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
SV=$(adb shell "$RA 'grep -h folder_save_0400486024DEC000 shared_prefs/launcher.xml'" | tr -d '\r'); echo "save pref before: $SV"
adb shell "$RA 'sed -i s#saves-test/ports-0400486024DEC000#saves-test/0400486024DEC000# shared_prefs/launcher.xml'"
adb shell am force-stop com.swap2native.test
adb push "$ZIP" /sdcard/Download/Swap2-Turnip.zip >/dev/null
adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver_zip /sdcard/Download/Swap2-Turnip.zip >/dev/null 2>&1
sleep 9; adb shell am force-stop com.swap2native.test; adb shell rm -f /sdcard/Download/Swap2-Turnip.zip
adb shell "$RA 'grep -h \"name=\\\"gpu_driver\\\"\" shared_prefs/*.xml'"
adb shell input keyevent KEYCODE_WAKEUP
echo "== T trace $(date +%T)"
props; adb shell rm -f $F/ut.csv
adb shell setprop debug.mesa.gpu.traces print_csv; adb shell setprop debug.mesa.gpu.tracefile $F/ut.csv
adb shell setprop debug.mesa.gpu.traces.on 0; adb shell setprop debug.mesa.tu.debug perf
showprops
adb logcat -c; (adb logcat -v time MESA:V '*:S' > $O/mesa.log) & LP=$!
gate() { sleep 3; started || return; sleep 270; adb shell setprop debug.mesa.gpu.traces.on 1; echo "trace on $(date +%T)"; sleep 10; adb shell setprop debug.mesa.gpu.traces.on 0; echo "trace off $(date +%T)"; }
gate & GP=$!
$BENCH --variant trace:DM_VK_FOLIAGE=3 "${HF[@]}" --tag tu-trace --out $O/trace 2>&1 | tail -1
wait $GP; kill $LP 2>/dev/null
adb shell ls -la $F/ut.csv; adb pull $F/ut.csv $O/ut.csv | tail -1; adb shell rm -f $F/ut.csv
props
for a in default prefer_gmem prefer_sysmem profiled; do
  echo "== A $a $(date +%T)"
  [ $a = default ] || adb shell setprop debug.mesa.tu.autotune.algo $a
  showprops
  $BENCH --variant $a:DM_VK_FOLIAGE=3 "${HF[@]}" --tag tu-$a --out $O/$a 2>&1 | tail -1
  props
done
for f in $O/*/*/log.txt; do echo "== $f crash=$(grep -a -c 'CRASH sig' $f) hang=$(grep -a -c 'GPU hang:' $f) driver=$(grep -a -m1 -o 'Swap2-Turnip[^,;]*' $f)"; done
props; showprops; echo "(props above should be empty)"
echo "$SV" | grep -q ports- && adb shell "$RA 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
adb install -r "D:/Projetos/Jogos/Android/turnip-swap2/out/zelda/foliage1/before.apk" | tail -1
drv Turnip_Gen8_V39
adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"
adb shell input keyevent KEYCODE_HOME; echo "== end $(date)"
