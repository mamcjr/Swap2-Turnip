#!/bin/bash
# Out-of-range buffer reads A/B: capture Kokiri frame 4500 on 891.14 (test save), replay it on 891.14 with and without DM_VK_ROBUST_DIAG=1 and on Swap2-Turnip with and
# without DM_VK_BUF_WHOLE=1, with the nxreplay / libnxhost.so of replay-build; logs to out/zelda/rb_*.log; clean up
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
T=D:/Projetos/Jogos/Android/turnip-swap2; P=/data/local/tmp/nxreplay
F=/storage/emulated/0/Android/data/com.swap2native.test/files; C=/storage/emulated/0/Switch2/Work/0400486024DEC000/captures
RA="run-as com.swap2native.test sh -c"
adb push $T/replay-build/nxreplay $T/replay-build/libnxhost.so $P/ >/dev/null && adb shell chmod 755 $P/nxreplay
adb exec-out "run-as com.swap2native.test tar c -C files/gpu_drivers Swap2-Turnip" > $T/replay-stage/drv/Swap2-Turnip.tar
adb push $T/replay-stage/drv/Swap2-Turnip.tar $P/drv/ >/dev/null; adb shell "cd $P/drv && tar xf Swap2-Turnip.tar && rm Swap2-Turnip.tar"
adb shell am force-stop com.swap2native.test
adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver 891.14 >/dev/null 2>&1; sleep 4; adb shell am force-stop com.swap2native.test
SV=$(adb shell "$RA 'grep -h folder_save_0400486024DEC000 shared_prefs/launcher.xml'" | tr -d '\r'); echo "save pref before: $SV"
adb shell "$RA 'sed -i s#saves-test/ports-0400486024DEC000#saves-test/0400486024DEC000# shared_prefs/launcher.xml'"
adb shell "mkdir -p $C; echo DM_NVN_CAPTURE=4500:1:$C/kokiri.nvncap > $F/env-0400486024DEC000.txt"
adb logcat -c; adb shell am start -n com.swap2native.test/com.swap2native.test.Launch -e title_id 0400486024DEC000 >/dev/null
sleep 40; for k in 1 2 3; do adb shell input tap 2949 477; sleep 4; done
for i in $(seq 1 50); do sleep 10; l=$(adb logcat -d | grep -a "DM_NVN_CAPTURE: frame [0-9]*: [0-9]* submits" | tail -1 | cut -c60-200); [ -n "$l" ] && { echo "capture: $l"; break; }; done
adb shell am force-stop com.swap2native.test; adb shell rm -f $F/env-0400486024DEC000.txt
echo "$SV" | grep -q ports- && adb shell "$RA 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
run() { # name, driver, env
  echo "== $1"
  adb shell "cd $P && $3 DM_TEMP=$P/temp DM_VK_DRIVER=$P/drv/$2 LD_LIBRARY_PATH=. ./nxreplay $C/kokiri.nvncap --warm 2 --no-png > rb_$1.log 2>&1; echo exit \$?; grep -a -e 'pixels differ' -e MATCH rb_$1.log | head -6 | cut -c1-160"
  adb pull $P/rb_$1.log "$T/out/zelda/rb_$1.log" >/dev/null
}
run q891 891.14 ""
run q891-robust 891.14 "DM_VK_ROBUST_DIAG=1"
run tu-whole Swap2-Turnip "DM_VK_BUF_WHOLE=1"
run tu Swap2-Turnip ""
adb shell "rm -f $C/kokiri.nvncap $C/kokiri.nvncap.live.png; rmdir $C 2>/dev/null; rm -rf $P/drv/Swap2-Turnip $P/rb_*.log"
adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver Turnip_Gen8_V39 >/dev/null; sleep 3
adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"; adb shell am force-stop com.swap2native.test; adb shell input keyevent KEYCODE_HOME; adb shell df -h /data | tail -1
