#!/bin/bash
# Hyrule Field with the grass on Qualcomm 891.14 (chain 706d0c7262fa with DM_VK_MESH_EXACT, DM_VK_CHUNK=200: 25.2 fps, GPU 34.8 ms, frame 39 ms): where the last
# 2-5 ms of GPU and the ~4 ms between the frame and the GPU go. One run with DM_VK_GPUPROF=30 DM_VK_GPUPROF_LIST=1 (every step of one frame in 30: site, draws,
# pass, time) and DM_VK_SYNCLOG fired at 260 s (a few frames of submit / GPU start / GPU end lines). The parent session's APK
# swap2-native-test-706d0c7262fa-exact.apk over the installed one (put back at the end), the library v-706d0c7262fa in the test pack. Save copy user1117, keys
# 35:A,41:A,47:A, window 250+40 s. Logs in out/zelda/prof891. folder_save and the default driver as they were.
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
R=D:/Projetos/Jogos/Android/MKWDroid; T=D:/Projetos/Jogos/Android/turnip-swap2; O=$T/out/zelda/prof891; B=/data/local/tmp/s2bench
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
drv 891.14
adb shell input keyevent KEYCODE_WAKEUP
python -I $R/dm/tools/android_bench.py --variant prof:$C,DM_VK_GPUPROF=30,DM_VK_GPUPROF_LIST=1,DM_VK_PIPE_STATS=1,DM_VK_PIPE_STATS_KEYS=3fa631a86435d3e8+edeefae4c37b0257+fed302d791a4ba43 --runs 1 --save-ref $B/0400486024DEC000-user1117 --keys 35:A,41:A,47:A   --start 250 --secs 40 --ctl "10:env DM_VK_SYNCLOG=40" --tag prof891-hf --out $O/hf 2>&1 | tail -3
grep -a -h "gpu prof: frame" $O/hf/*/log.txt | tail -3 | cut -c1-250
grep -a -h "pipeline stats" $O/hf/*/log.txt | head -12 | cut -c1-300
for d in $O/*/*/; do printf "%s parked=%s hang=%s crash=%s\n" "$d" "$(grep -a -c 'parked queue' $d/log.txt)" "$(grep -a -c 'GPU hang:' $d/log.txt)" "$(grep -a -c 'CRASH sig' $d/log.txt)"; done
echo "$SV" | grep -q ports- && adb shell "$RA 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
adb install -r "$O/before.apk" | tail -1
[ "$HAD" = yes ] || adb shell "rm -rf $ZD/$V"; adb shell "ls $ZD"
drv Turnip_Gen8_V39
adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"
adb shell input keyevent KEYCODE_HOME; rm -f "$O/before.apk"; echo "== end $(date)"
