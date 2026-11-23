#!/bin/bash
# Subgroup stages: capture Kokiri frame 4500 on 891.14 (test save), replay on 891.14 as is and on Swap2-Turnip with DM_VK_SUBGROUP_STAGES masks (which stages keep
# subgroups; the others run one-lane subgroups); logs to out/zelda/sg_<label>.log; clean up
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
T=D:/Projetos/Jogos/Android/turnip-swap2; P=/data/local/tmp/nxreplay
F=/storage/emulated/0/Android/data/com.swap2native.test/files; C=/storage/emulated/0/Switch2/Work/0400486024DEC000/captures
RA="run-as com.swap2native.test sh -c"
F0=$(adb shell df -k /data | tail -1 | awk '{print $4}' | tr -d ''); echo "free at start: ${F0} KiB"
[ "${F0:-0}" -ge 9961472 ] || { echo "NOT RUN: under 9.5 GB free for an ~8 GB capture"; exit 2; }
adb push $T/replay-build-head/nxreplay $T/replay-build-head/libnxhost.so $P/ >/dev/null && adb shell chmod 755 $P/nxreplay
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
for v in "891.14 base -" "Swap2-Turnip base -" "Swap2-Turnip fc 0x30" "Swap2-Turnip c 0x20" "Swap2-Turnip f 0x10" "Swap2-Turnip none 0" "Swap2-Turnip base2 -"; do
  set -- $v; drv=$1; lab=$1-$2; E=""; [ "$3" != "-" ] && E="DM_VK_SUBGROUP_STAGES=$3"
  echo "== $lab $E"
  adb shell "cd $P && $E DM_TEMP=$P/temp DM_VK_DRIVER=$P/drv/$drv LD_LIBRARY_PATH=. ./nxreplay $C/kokiri.nvncap --warm 1 --no-png > sg_$lab.log 2>&1; grep -a 'pixels differ' sg_$lab.log | head -2; grep -a 'subgroup shaders (' sg_$lab.log | cut -c1-260"
  adb pull $P/sg_$lab.log "$T/out/zelda/sg_$lab.log" >/dev/null; adb shell rm -f $P/sg_$lab.log
done
adb shell "rm -f $C/kokiri.nvncap $C/kokiri.nvncap.live.png; rmdir $C 2>/dev/null"
adb shell "rm -rf $P/drv/Swap2-Turnip"
adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver Turnip_Gen8_V39 >/dev/null; sleep 3
adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"; adb shell am force-stop com.swap2native.test; adb shell input keyevent KEYCODE_HOME; adb shell df -h /data | tail -1
