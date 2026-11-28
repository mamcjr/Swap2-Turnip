#!/bin/bash
# Castle Town, Turnip's shuffle cost (2026-11-27): Swap2-Turnip as shipped against Swap2-Turnip-shfl (the shipping patches + 0005: ir3's arbitrary-index shuffle
# also serves its lanes by absolute source lane, a movs a pass), with the library of chain b103fbe53956 (the foliage culling's shuffles are instructions there).
# The driver is put into the test app's files/gpu_drivers/Swap2-Turnip-shfl (run-as). Runs A B A B, each with the save copy user1127, a 10 s recording for
# tools/flicker.py and the window's fps and GPU time.
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
R=D:/Projetos/Jogos/Android/MKWDroid; T=D:/Projetos/Jogos/Android/turnip-swap2; O=$T/out/zelda/burgoshfl-$(date +%m%d-%H%M); B=/data/local/tmp/s2bench
RA="run-as com.swap2native.test sh -c"; TP=/sdcard/Switch2/Work/0400486024DEC000/test-pack
APK=$R/android/app/out/swap2-native-test.apk; BENCH="python -I $R/dm/tools/android_bench.py"; ZIP=$T/out/rel/Swap2-Turnip-shfl-2648b2059f-0005.zip
START=${START:-250}; KEYS=${KEYS:-175:A,181:A,187:A}
mkdir -p $O
adb shell "[ -f $TP/shaders/v-b103fbe53956/dmsh_vk.lib ]" || { echo "NOT RUN: the b103 library is not in the test pack"; exit 2; }
P=$(adb shell pm path com.swap2native.test | head -1 | sed 's/package://' | tr -d '\r')
adb pull "$P" "$(cygpath -w $O/before.apk)" | tail -1 || exit 1
adb shell am force-stop com.swap2native.test
adb install -r "$(cygpath -w $APK)" | tail -1 || exit 1
adb push "$(cygpath -w $ZIP)" /data/local/tmp/shfl.zip | tail -1
adb shell "cd /data/local/tmp && rm -rf shfl && mkdir shfl && cd shfl && unzip -q ../shfl.zip && chmod 644 *"
adb shell "$RA 'rm -rf files/gpu_drivers/Swap2-Turnip-shfl && mkdir -p files/gpu_drivers/Swap2-Turnip-shfl && cp /data/local/tmp/shfl/* files/gpu_drivers/Swap2-Turnip-shfl/ && ls -la files/gpu_drivers/Swap2-Turnip-shfl'"
adb shell "rm -rf /data/local/tmp/shfl /data/local/tmp/shfl.zip"
SV=$(adb shell "$RA 'grep -h folder_save_0400486024DEC000 shared_prefs/launcher.xml'" | tr -d '\r')
adb shell "$RA 'sed -i s#saves-test/ports-0400486024DEC000#saves-test/0400486024DEC000# shared_prefs/launcher.xml'"
drv() { adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver $1 >/dev/null 2>&1; sleep 4; adb shell am force-stop com.swap2native.test; }
started() { local i=0; while [ -z "$(adb shell pidof com.swap2native.test:game | tr -d '\r')" ]; do i=$((i+1)); [ $i -gt 600 ] && return 1; sleep 0.5; done; }
rec() {
  sleep 3; started || return; sleep $((START + 15))
  adb shell screenrecord --time-limit 10 --bit-rate 20000000 --size 1600x720 /sdcard/Download/shfl.mp4; sleep 1
  adb pull /sdcard/Download/shfl.mp4 "$(cygpath -w $O/$1.mp4)" >/dev/null; adb shell rm -f /sdcard/Download/shfl.mp4
  adb exec-out screencap -p > $O/$1.png; echo "rec $1 $(date +%T)"
}
(while [ ! -f $O/.done ]; do adb shell input keyevent KEYCODE_WAKEUP; sleep 20; done) &
n=0
# The first run of a driver with no pipeline cache of its own compiles for minutes (Turnip's boot hold): DRVS starts with a warm-up of the new driver.
for d in ${DRVS:-Swap2-Turnip-shfl Swap2-Turnip Swap2-Turnip-shfl Swap2-Turnip Swap2-Turnip-shfl}; do
  adb get-state >/dev/null 2>&1 || { echo "STOPPED: the phone left adb before run $((n+1))"; break; }
  n=$((n+1)); t=$n-$d; drv $d
  rec $t & SP=$!
  $BENCH --variant "b:DM_VK_MESH_DRAWS=1" --runs 1 --cool 60 --drain 10 --pack $TP --save-ref $B/0400486024DEC000-user1127 --keys $KEYS --start $START --secs 50 --tag $t --out $O/run-$t 2>&1 | tail -1
  wait $SP
done
touch $O/.done
adb shell am force-stop com.swap2native.test
# RESTORE_PORTS=1: a restart after a run that changed it and could not put it back
if [ -n "${RESTORE_PORTS:-}" ] || echo "$SV" | grep -q ports-; then adb shell "$RA 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"; fi
adb install -r "$(cygpath -w $O/before.apk)" && rm -f $O/before.apk || echo "NOT RESTORED: the previous test APK stays in $O/before.apk"
drv Swap2-Turnip; adb shell input keyevent KEYCODE_HOME
for r in $O/run-*; do
  t=${r##*/run-}; l=$(ls $r/*/log.txt | head -1)
  echo "== $t: $(grep -a -m1 'custom GPU driver: ' $l | grep -o 'gpu_drivers/[^/]*' | head -1)"
  echo "   fps $(grep -a '\[vk\] fps:' $l | tail -9 | head -8 | grep -o 'fps: [0-9.]*' | cut -d' ' -f2 | tr '\n' ' ') | GPU $(grep -a '\[longframe\]' $l | tail -4 | grep -o 'GPU [0-9.]* ms' | cut -d' ' -f2 | tr '\n' ' ')"
  python $T/tools/flicker.py $O/$t.mp4 $O/$t 2>&1 | tail -1
done
echo "== end $(date) -> $O"
