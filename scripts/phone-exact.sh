#!/bin/bash
# DM_VK_MESH_EXACT (the foliage's prepass and colour pass get the same depths in their compute fallback forms) against the Turnip-only flicker of Kokiri Forest
# (draws 13/17/18 of the 2026-11-21 dumps), then Hyrule Field's frame rate with the grass on Turnip V39 at DM_VK_CHUNK / DM_VK_CHUNK_PASS 200 and one GPU profile run.
# The parent session's APK swap2-native-test-706d0c7262fa-exact.apk (chain 706d0c7262fa, DM_VK_MESH_EXACT default 1, DM_VK_CHUNK default 600) over the installed
# one (put back at the end), the library v-706d0c7262fa in the test pack (pushed only if absent). Turnip V39 throughout.
# - Kokiri, save copy test1121: exact 1 / 0 / 1 / 0, one run each (window 100+30 s), an 8 s screen recording at 110 s of each, for tools/flicker.py.
# - Hyrule Field, save copy user1117 (keys 35:A,41:A,47:A, window 250+40 s as the parent's #35 at 600), all at chunk 200: exact 1 and exact 0, one run each, with
#   8 s recordings at 75 and 110 s (the scene's first seconds after the save loads, where the user saw the grass flash) and at 240 s; then one run with
#   DM_VK_GPUPROF=30 (gpu prof lines: the frame's GPU time by kind and its costliest steps).
# Logs and recordings in out/zelda/exact. folder_save and the default driver as they were.
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
R=D:/Projetos/Jogos/Android/MKWDroid; T=D:/Projetos/Jogos/Android/turnip-swap2; O=$T/out/zelda/exact; B=/data/local/tmp/s2bench
RA="run-as com.swap2native.test sh -c"; ZD=/sdcard/Switch2/Work/0400486024DEC000/test-pack/shaders; V=v-706d0c7262fa
APK=$R/android/app/out/swap2-native-test-706d0c7262fa-exact.apk; LIB=//wsl.localhost/Ubuntu-26.04/home/$USERNAME/zelda-vklib/$V
mkdir -p $O
[ -f "$APK" ] || { echo "NOT RUN: APK missing"; exit 2; }
P=$(adb shell pm path com.swap2native.test | head -1 | sed 's/package://' | tr -d '\r')
adb pull "$P" "$O/before.apk" | tail -1 || exit 1
adb shell am force-stop com.swap2native.test
adb install -r "$APK" | tail -1 || exit 1
HAD=$(adb shell "[ -f $ZD/$V/dmsh_vk.lib ] && echo yes" | tr -d '\r')
[ "$HAD" = yes ] || { [ -f "$LIB/dmsh_vk.lib" ] || { echo "library missing"; adb install -r "$O/before.apk"; exit 2; }; adb shell "mkdir -p $ZD/$V"; adb push "$LIB/inputs.tsv" "$LIB/dmsh_vk.lib" $ZD/$V/ | tail -1 || exit 1; }
adb shell "ls $ZD; df -h /sdcard | tail -1"
SV=$(adb shell "$RA 'grep -h folder_save_0400486024DEC000 shared_prefs/launcher.xml'" | tr -d '\r'); echo "save pref before: $SV"
adb shell "$RA 'sed -i s#saves-test/ports-0400486024DEC000#saves-test/0400486024DEC000# shared_prefs/launcher.xml'"
drv() { adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver $1 >/dev/null 2>&1; sleep 4; adb shell am force-stop com.swap2native.test; }
rec() { local n=$1 t0=0; shift; for t in "$@"; do sleep $((t - t0)); adb shell screenrecord --time-limit 8 --bit-rate 40000000 --size 1600x720 /sdcard/Download/ex-$n-$t.mp4; t0=$((t + 8)); done; }
pullrec() { local n=$1; shift; for t in "$@"; do adb pull /sdcard/Download/ex-$n-$t.mp4 $O/ | tail -1; adb shell rm -f /sdcard/Download/ex-$n-$t.mp4; done; }
BENCH="python -I $R/dm/tools/android_bench.py --runs 1 --cool 15"
drv Turnip_Gen8_V39
i=0
for v in exact:1 noexact:0 exact:1 noexact:0; do
  i=$((i + 1)); n=${v%%:*}-$i
  adb shell input keyevent KEYCODE_WAKEUP
  rec kokiri-$n 110 & RP=$!
  $BENCH --variant ${v%%:*}:DM_VK_MESH_EXACT=${v#*:} --secs 30 --save-ref $B/0400486024DEC000-test1121 --tag ex-kokiri-$n --out $O/kokiri-$n 2>&1 | tail -2
  wait $RP; pullrec kokiri-$n 110
done
for v in exact:1 noexact:0; do
  n=hf-${v%%:*}
  adb shell input keyevent KEYCODE_WAKEUP
  rec $n 75 110 240 & RP=$!
  $BENCH --variant ${v%%:*}:DM_VK_MESH_EXACT=${v#*:},DM_VK_CHUNK=200,DM_VK_CHUNK_PASS=200 --save-ref $B/0400486024DEC000-user1117 --keys '35:A,41:A,47:A' --start 250 --secs 40 --tag ex-$n --out $O/$n 2>&1 | tail -2
  wait $RP; pullrec $n 75 110 240
done
adb shell input keyevent KEYCODE_WAKEUP
$BENCH --variant prof:DM_VK_CHUNK=200,DM_VK_CHUNK_PASS=200,DM_VK_GPUPROF=30 --save-ref $B/0400486024DEC000-user1117 --keys '35:A,41:A,47:A' --start 250 --secs 40 --tag ex-hf-prof --out $O/hf-prof 2>&1 | tail -2
for d in $O/*/*/; do printf "%s parked=%s hang=%s\n" "$d" "$(grep -a -c 'parked queue' $d/log.txt)" "$(grep -a -c 'GPU hang:' $d/log.txt)"; done
echo "$SV" | grep -q ports- && adb shell "$RA 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
adb install -r "$O/before.apk" | tail -1
[ "$HAD" = yes ] || adb shell "rm -rf $ZD/$V"; adb shell "ls $ZD"
drv Turnip_Gen8_V39
adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"
adb shell input keyevent KEYCODE_HOME; rm -f "$O/before.apk"; echo "== end $(date)"
