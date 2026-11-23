#!/bin/bash
# The raw global memory lookup hints (chain d0f45109564e: vk_android_spv.py _hint_start, vka_gmem.h; Banana Native's 2 MiB chunk hints) live, Turnip V39: the hinted
# library with the host's hints (default) against the same library with DM_VK_GMEM_HINTS=0 (every hint word 0: each lookup searches its 13 steps, as on chain 706d).
# The test APK swap2-native-test-hint.apk (also DM_VK_MESH_EXACT and DM_VK_CHUNK 200 by default) over the installed one (put back at the end), the library
# v-d0f45109564e pushed into the test pack (removed at the end unless it was there).
# - Hyrule Field, save copy user1117 (keys 35:A,41:A,47:A, window 250+40 s): hints / nohints A B A B, then one run with hints and DM_VK_GPUPROF=30 (the mesh
#   fallback's compute steps against today's profile without hints, out/zelda/exact/hf-prof).
# - Kokiri Forest, save copy test1121 (window 100+30 s): hints / nohints one run each.
# Every end.png is the picture to compare (a wrong hint would draw geometry from another pool). Logs in out/zelda/hint. folder_save and the default driver as they were.
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
R=D:/Projetos/Jogos/Android/MKWDroid; T=D:/Projetos/Jogos/Android/turnip-swap2; O=$T/out/zelda/hint; B=/data/local/tmp/s2bench
RA="run-as com.swap2native.test sh -c"; ZD=/sdcard/Switch2/Work/0400486024DEC000/test-pack/shaders; V=v-d0f45109564e
APK=$T/out/swap2-native-test-hint.apk; LIB=//wsl.localhost/Ubuntu-26.04/home/$USERNAME/hint-vklib/$V
mkdir -p $O
[ -f "$APK" ] && [ -f "$LIB/dmsh_vk.lib" ] && [ -f "$LIB/inputs.tsv" ] || { echo "NOT RUN: APK or library missing"; exit 2; }
P=$(adb shell pm path com.swap2native.test | head -1 | sed 's/package://' | tr -d '\r')
adb pull "$P" "$O/before.apk" | tail -1 || exit 1
adb shell am force-stop com.swap2native.test
adb install -r "$APK" | tail -1 || exit 1
HAD=$(adb shell "[ -f $ZD/$V/dmsh_vk.lib ] && echo yes" | tr -d '\r')
[ "$HAD" = yes ] || { adb shell "mkdir -p $ZD/$V"; adb push "$LIB/inputs.tsv" "$LIB/dmsh_vk.lib" $ZD/$V/ | tail -1 || exit 1; }
adb shell "ls $ZD; df -h /sdcard | tail -1"
SV=$(adb shell "$RA 'grep -h folder_save_0400486024DEC000 shared_prefs/launcher.xml'" | tr -d '\r'); echo "save pref before: $SV"
adb shell "$RA 'sed -i s#saves-test/ports-0400486024DEC000#saves-test/0400486024DEC000# shared_prefs/launcher.xml'"
drv() { adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver $1 >/dev/null 2>&1; sleep 4; adb shell am force-stop com.swap2native.test; }
BENCH="python -I $R/dm/tools/android_bench.py --cool 20"
HF="--save-ref $B/0400486024DEC000-user1117 --keys 35:A,41:A,47:A --start 250 --secs 40"
drv Turnip_Gen8_V39
adb shell input keyevent KEYCODE_WAKEUP
$BENCH --variant hints: --variant nohints:DM_VK_GMEM_HINTS=0 --runs 2 $HF --tag hint-hf --out $O/hf 2>&1 | tail -6
adb shell input keyevent KEYCODE_WAKEUP
$BENCH --variant prof:DM_VK_GPUPROF=30 --runs 1 $HF --tag hint-hf-prof --out $O/hf-prof 2>&1 | tail -2
adb shell input keyevent KEYCODE_WAKEUP
$BENCH --variant hints: --variant nohints:DM_VK_GMEM_HINTS=0 --runs 1 --secs 30 --save-ref $B/0400486024DEC000-test1121 --tag hint-kokiri --out $O/kokiri 2>&1 | tail -3
for d in $O/*/*/; do printf "%s parked=%s hang=%s crash=%s\n" "$d" "$(grep -a -c 'parked queue' $d/log.txt)" "$(grep -a -c 'GPU hang:' $d/log.txt)" "$(grep -a -c 'CRASH sig' $d/log.txt)"; done
echo "$SV" | grep -q ports- && adb shell "$RA 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
adb install -r "$O/before.apk" | tail -1
[ "$HAD" = yes ] || adb shell "rm -rf $ZD/$V"; adb shell "ls $ZD"
drv Turnip_Gen8_V39
adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"
adb shell input keyevent KEYCODE_HOME; rm -f "$O/before.apk"; echo "== end $(date)"
