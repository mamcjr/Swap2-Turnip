#!/bin/bash
# Hyrule Field, phone block 5 (turnip-swap2's queue row): Swap2-Turnip against 891.14 on equal settings, and the picture with guest storage buffers read
# through isam. The test APK from MKWDroid HEAD 83cb654 (out/swap2-native-test-main.apk: Foliage, Fog) over the installed one (which goes back at the end);
# the driver zip p15 (out/Swap2-Turnip-2648b2059f-p15.zip: diagnostics only, mesa patches 9003 and 9004) installed as Swap2-Turnip.
# One run each, save copy user1117, keys 35:A,41:A,47:A, window 250+60 s, the drivers alternating:
#   tu-ro-high   Swap2-Turnip, grass high, debug.mesa.tu.ssbo.ro.auto=1 with debug.mesa.tu.ssbo.ro.maxbind=384 (only the guest's buffers, not the mesh
#                fallback's own), shader caches off so its modules are compiled with it; screenshots 20 and 40 s into the window (the picture check)
#   891-high     891.14, grass high
#   tu-off       Swap2-Turnip as it is, grass none (DM_VK_FOLIAGE=0)
#   891-off      891.14, grass none
#   tu-off-fog   Swap2-Turnip, grass none and the volume fog off (DM_VK_DISPATCH_OFF, the profile's graphics_off volume_fog keys)
#   891-off-fog  891.14, the same
# Every debug.mesa.* property is cleared at the end; the default driver goes back to Turnip_Gen8_V39, folder_save as it was.
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
R=D:/Projetos/Jogos/Android/MKWDroid; T=D:/Projetos/Jogos/Android/turnip-swap2; O=$T/out/zelda/p15; B=/data/local/tmp/s2bench
RA="run-as com.swap2native.test sh -c"
BENCH="python -I $R/dm/tools/android_bench.py"; ZIP=$T/out/Swap2-Turnip-2648b2059f-p15.zip; APK=$T/out/swap2-native-test-main.apk
HF=(--save-ref $B/0400486024DEC000-user1117 --keys 35:A,41:A,47:A --start 250 --secs 60 --runs 1 --cool 60)
COLD="DM_VK_PCACHE=0,DM_VK_PREWARM=0"
FOG="DM_VK_DISPATCH_OFF=856424a0069b04f8+9e6b00b050e30801+6ad776ca0a3d72b4+bcb82bfa39eaca53+739ed28066f58ca3+6b65ea05fc1e816c+109fc917f6f88db5+2503f644249ad387+3044d7555ebdd427+f2e5a4e0899b3013+f01717f643536e86+9ed48d1011f1b48b+2445e600f3887bc2+5b2bb0924ecc403b+b78bb1280606e796"
mkdir -p $O
[ -f "$ZIP" ] && [ -f "$APK" ] || { echo "NOT RUN: zip or APK missing"; exit 2; }
PROPS="debug.mesa.tu.rp.nowfi debug.mesa.ir3.cs.regs debug.mesa.shader.cache.disable debug.mesa.tu.ssbo.ro.auto debug.mesa.tu.ssbo.ro.maxbind"
props() { for p in $PROPS; do adb shell "setprop $p ''"; done; }
showprops() { adb shell "getprop | grep debug.mesa" ; }
drv() { adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver $1 >/dev/null 2>&1; sleep 4; adb shell am force-stop com.swap2native.test; }
started() { local i=0; while [ -z "$(adb shell pidof com.swap2native.test:game | tr -d '\r')" ]; do i=$((i+1)); [ $i -gt 600 ] && { echo "no game process after 300 s"; return 1; }; sleep 0.5; done; echo "launch $(date +%T)"; }
adb shell am force-stop com.swap2native.test
P=$(adb shell pm path com.swap2native.test | head -1 | sed 's/package://' | tr -d '\r')
adb pull "$P" "$O/before.apk" | tail -1 || exit 1
adb install -r "$APK" | tail -1 || exit 1
SV=$(adb shell "$RA 'grep -h folder_save_0400486024DEC000 shared_prefs/launcher.xml'" | tr -d '\r'); echo "save pref before: $SV"
adb shell "$RA 'sed -i s#saves-test/ports-0400486024DEC000#saves-test/0400486024DEC000# shared_prefs/launcher.xml'"
adb push "$ZIP" /sdcard/Download/Swap2-Turnip.zip >/dev/null
adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver_zip /sdcard/Download/Swap2-Turnip.zip >/dev/null 2>&1
sleep 9; adb shell am force-stop com.swap2native.test; adb shell rm -f /sdcard/Download/Swap2-Turnip.zip
adb shell input keyevent KEYCODE_WAKEUP
props
shots() { sleep 3; started || return; sleep 270; adb exec-out screencap -p > $O/tu-ro-high-270.png; sleep 20; adb exec-out screencap -p > $O/tu-ro-high-290.png; echo "shots $(date +%T)"; }
run() {   # label, driver, bench variant env, then property=value pairs
  local l=$1 d=$2 env=$3; shift 3
  echo "== $l $d $(date +%T)"
  drv $d
  for kv in "$@"; do adb shell setprop ${kv%%=*} ${kv#*=}; done
  showprops
  $BENCH --variant "$l:$env" "${HF[@]}" --tag p15-$l --out $O/$l 2>&1 | tail -1
  props
}
shots & SP=$!
run tu-ro-high  Swap2-Turnip "DM_VK_FOLIAGE=3,$COLD" debug.mesa.shader.cache.disable=true debug.mesa.tu.ssbo.ro.auto=1 debug.mesa.tu.ssbo.ro.maxbind=384
wait $SP
run 891-high    891.14       "DM_VK_FOLIAGE=3"
run tu-off      Swap2-Turnip "DM_VK_FOLIAGE=0"
run 891-off     891.14       "DM_VK_FOLIAGE=0"
run tu-off-fog  Swap2-Turnip "DM_VK_FOLIAGE=0,$FOG"
run 891-off-fog 891.14       "DM_VK_FOLIAGE=0,$FOG"
for f in $O/*/*/log.txt; do echo "== $f crash=$(grep -a -c 'CRASH sig' $f) hang=$(grep -a -c 'GPU hang:' $f) cmdlist=$(grep -a -c 'command list changed' $f)"; grep -a -h -m2 "foliage (DM_VK_FOLIAGE\|DISPATCH_OFF" $f | cut -c1-160; done
props; showprops; echo "(props above should be empty)"
echo "$SV" | grep -q ports- && adb shell "$RA 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
adb install -r "$O/before.apk" | tail -1
drv Turnip_Gen8_V39
adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"
adb shell input keyevent KEYCODE_HOME; rm -f "$O/before.apk"; echo "== end $(date)"
