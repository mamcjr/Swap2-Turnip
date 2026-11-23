#!/bin/bash
# DM_VK_CHUNK=200 / DM_VK_CHUNK_PASS=200 (default 600) before it becomes the default: Kokiri Forest on Turnip V39 and Hyrule Field on Qualcomm 891.14, on chain
# 706d0c7262fa (4eb05e585fb0 plus the 8,192-entry raw global memory table). The parent session's test APK and Zelda library of that chain over the installed APK
# (put back at the end), the library pushed beside the others in the Zelda test pack (removed at the end). android_bench.py, variants base and chunk A B A B:
# Kokiri from the save copy test1121 (default keys and window), Hyrule Field from user1117 (keys 35:A,41:A,47:A, window 250+60 s: after the point where the
# foliage went). Each run's overflow / parked wait / GPU hang lines counted. Then the foliage's white flashes: 8 s screen recordings at 140 s and 240 s after the start
# (outside the measured window) in Hyrule Field's first 891.14 run and in one Hyrule Field run on Turnip V39, for tools/flicker.py (is it Turnip's, or ours?).
# Logs and recordings in out/zelda/gm. folder_save and the default driver as they were.
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
R=D:/Projetos/Jogos/Android/MKWDroid; T=D:/Projetos/Jogos/Android/turnip-swap2; O=$T/out/zelda/gm; B=/data/local/tmp/s2bench
RA="run-as com.swap2native.test sh -c"; ZD=/sdcard/Switch2/Work/0400486024DEC000/test-pack/shaders; V=v-706d0c7262fa
APK=$R/android/app/out/swap2-native-test-706d0c7262fa.apk; LIB=//wsl.localhost/Ubuntu-26.04/home/$USERNAME/zelda-vklib/$V
mkdir -p $O
[ -f "$APK" ] && [ -f "$LIB/dmsh_vk.lib" ] && [ -f "$LIB/inputs.tsv" ] || { echo "NOT RUN: APK or library missing"; exit 2; }
P=$(adb shell pm path com.swap2native.test | head -1 | sed 's/package://' | tr -d '\r')
adb pull "$P" "$O/before.apk" | tail -1 || exit 1
adb shell dumpsys package com.swap2native.test | grep -m1 lastUpdateTime
adb shell am force-stop com.swap2native.test
adb install -r "$APK" | tail -1 || exit 1
HAD=$(adb shell "[ -f $ZD/$V/dmsh_vk.lib ] && echo yes" | tr -d '\r')
[ "$HAD" = yes ] || { adb shell "mkdir -p $ZD/$V"; adb push "$LIB/inputs.tsv" "$LIB/dmsh_vk.lib" $ZD/$V/ | tail -1 || exit 1; }
adb shell "ls $ZD; df -h /sdcard | tail -1"
SV=$(adb shell "$RA 'grep -h folder_save_0400486024DEC000 shared_prefs/launcher.xml'" | tr -d '\r'); echo "save pref before: $SV"
adb shell "$RA 'sed -i s#saves-test/ports-0400486024DEC000#saves-test/0400486024DEC000# shared_prefs/launcher.xml'"
VAR="--variant base: --variant chunk:DM_VK_CHUNK=200,DM_VK_CHUNK_PASS=200 --runs 2 --cool 20"
rec() { for t in 140 240; do sleep $((t - ${2:-0})); adb shell screenrecord --time-limit 8 --bit-rate 40000000 --size 1600x720 /sdcard/Download/gm-$1-$t.mp4; set -- $1 $((t + 8)); done; }
pullrec() { for t in 140 240; do adb pull /sdcard/Download/gm-$1-$t.mp4 $O/ | tail -1; adb shell rm -f /sdcard/Download/gm-$1-$t.mp4; done; }
drv() { adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver $1 >/dev/null 2>&1; sleep 4; adb shell am force-stop com.swap2native.test; }
drv Turnip_Gen8_V39
python -I $R/dm/tools/android_bench.py $VAR --secs 45 --save-ref $B/0400486024DEC000-test1121 --tag gm-kokiri-V39 --out $O/kokiri-V39 2>&1 | tail -6
drv 891.14
rec hf891 & RP=$!
python -I $R/dm/tools/android_bench.py $VAR --save-ref $B/0400486024DEC000-user1117 --keys '35:A,41:A,47:A' --start 250 --secs 60 --tag gm-hf-891 --out $O/hf-891 2>&1 | tail -6
wait $RP; pullrec hf891
drv Turnip_Gen8_V39
rec hfV39 & RP=$!
python -I $R/dm/tools/android_bench.py --variant base: --runs 1 --save-ref $B/0400486024DEC000-user1117 --keys '35:A,41:A,47:A' --start 250 --secs 60 --tag gm-hf-V39 --out $O/hf-V39 2>&1 | tail -6
wait $RP; pullrec hfV39
for d in $O/kokiri-V39/*/ $O/hf-891/*/ $O/hf-V39/*/; do printf "%s overflow=%s parked=%s hang=%s\n" "$d" "$(grep -a -c 'placed segments: raw global' $d/log.txt)" "$(grep -a -c 'parked queue' $d/log.txt)" "$(grep -a -c 'GPU hang:' $d/log.txt)"; done
echo "$SV" | grep -q ports- && adb shell "$RA 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
adb install -r "$O/before.apk" | tail -1
[ "$HAD" = yes ] || adb shell "rm -rf $ZD/$V"; adb shell "ls $ZD"
drv Turnip_Gen8_V39
adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"
adb shell input keyevent KEYCODE_HOME; rm -f "$O/before.apk"; echo "== end $(date)"
