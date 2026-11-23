#!/bin/bash
# Where the task/mesh fallback's ~10 ms go in Hyrule Field with the grass (Turnip V39, chain 706d0c7262fa with DM_VK_MESH_EXACT, DM_VK_CHUNK=200): DM_VK_MESH_DIAG_STAGE
# (incomplete pictures, measuring only) 1 = the controller and the pass breaks only, 2 = also the task/mesh compute (no pulling draw), 3 = the emulated draws dropped
# before they end the pass, against the full fallback; plus DM_VK_MESH_DRAWS=0. Differences of GPU p50: full - 2 = the pulling draws, 2 - 1 = the compute, 1 - 3 =
# the controller and the pass breaks, 3 vs MESH_DRAWS=0 = what is left. The parent session's APK swap2-native-test-706d0c7262fa-exact.apk over the installed one
# (put back at the end), the library v-706d0c7262fa in the test pack (pushed only if absent). Save copy user1117, keys 35:A,41:A,47:A, window 250+40 s, one run each.
# Logs in out/zelda/stage. folder_save and the default driver as they were.
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
R=D:/Projetos/Jogos/Android/MKWDroid; T=D:/Projetos/Jogos/Android/turnip-swap2; O=$T/out/zelda/stage2; B=/data/local/tmp/s2bench
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
C=DM_VK_CHUNK=200,DM_VK_CHUNK_PASS=200
drv Turnip_Gen8_V39
adb shell input keyevent KEYCODE_WAKEUP
python -I $R/dm/tools/android_bench.py --variant s2:$C,DM_VK_MESH_DIAG_STAGE=2 --variant s1:$C,DM_VK_MESH_DIAG_STAGE=1 --variant s3:$C,DM_VK_MESH_DIAG_STAGE=3 \
  --variant nomesh:$C,DM_VK_MESH_DRAWS=0 --runs 1 --cool 20 --save-ref $B/0400486024DEC000-user1117 --keys 35:A,41:A,47:A --start 250 --secs 40 --tag stage-hf --out $O/hf 2>&1 | tail -8
for d in $O/*/*/; do printf "%s parked=%s hang=%s crash=%s\n" "$d" "$(grep -a -c 'parked queue' $d/log.txt)" "$(grep -a -c 'GPU hang:' $d/log.txt)" "$(grep -a -c 'CRASH sig' $d/log.txt)"; done
echo "$SV" | grep -q ports- && adb shell "$RA 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
adb install -r "$O/before.apk" | tail -1
[ "$HAD" = yes ] || adb shell "rm -rf $ZD/$V"; adb shell "ls $ZD"
drv Turnip_Gen8_V39
adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"
adb shell input keyevent KEYCODE_HOME; rm -f "$O/before.apk"; echo "== end $(date)"
